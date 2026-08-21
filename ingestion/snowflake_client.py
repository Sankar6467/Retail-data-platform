"""
Thin wrapper around the Snowflake Python connector: connection with retry,
bulk load via write_pandas, and small helpers for audit logging.
"""
import logging
import time
import uuid

import pandas as pd
import snowflake.connector
from snowflake.connector.pandas_tools import write_pandas

from config import MAX_RETRIES, RETRY_BACKOFF_SECONDS, SnowflakeConfig

logger = logging.getLogger(__name__)


class TransientConnectionError(Exception):
    """Raised after retries are exhausted trying to reach Snowflake."""


class SnowflakeClient:
    def __init__(self, cfg: SnowflakeConfig):
        self.cfg = cfg
        self._conn = None

    def __enter__(self) -> "SnowflakeClient":
        self._conn = self._connect_with_retry()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        if self._conn is not None:
            self._conn.close()

    def _connect_with_retry(self):
        last_exc = None
        for attempt in range(1, MAX_RETRIES + 1):
            try:
                logger.info("Connecting to Snowflake (attempt %d/%d)...", attempt, MAX_RETRIES)
                return snowflake.connector.connect(
                    account=self.cfg.account,
                    user=self.cfg.user,
                    password=self.cfg.password,
                    role=self.cfg.role,
                    warehouse=self.cfg.warehouse,
                    database=self.cfg.database,
                    schema=self.cfg.schema,
                    client_session_keep_alive=True,
                )
            except Exception as exc:  # noqa: BLE001 - genuinely need to catch any connector error here
                last_exc = exc
                logger.warning("Connection attempt %d failed: %s", attempt, exc)
                if attempt < MAX_RETRIES:
                    time.sleep(RETRY_BACKOFF_SECONDS * attempt)  # exponential-ish backoff
        raise TransientConnectionError(
            f"Could not connect to Snowflake after {MAX_RETRIES} attempts"
        ) from last_exc

    def load_dataframe(self, df: pd.DataFrame, database: str, schema: str, table: str) -> int:
        """Bulk-loads a dataframe via write_pandas (PUT + COPY INTO under the hood)."""
        if df.empty:
            return 0
        success, num_chunks, num_rows, _ = write_pandas(
            conn=self._conn,
            df=df,
            table_name=table,
            database=database,
            schema=schema,
            auto_create_table=False,
            quote_identifiers=False,
        )
        if not success:
            raise RuntimeError(f"write_pandas reported failure loading into {schema}.{table}")
        return num_rows

    def execute(self, sql: str, params: tuple | dict | None = None):
        with self._conn.cursor() as cur:
            cur.execute(sql, params)
            return cur.fetchall()

    def insert_run_log(self, database: str, batch_id: str, source_file: str, target_table: str,
                        started_at, finished_at, status: str, rows_read: int, rows_loaded: int,
                        rows_rejected: int, error_message: str | None):
        self.execute(
            f"""
            INSERT INTO {database}.AUDIT.INGESTION_RUN_LOG
                (batch_id, source_file, target_table, started_at, finished_at,
                 status, rows_read, rows_loaded, rows_rejected, error_message)
            VALUES (%(batch_id)s, %(source_file)s, %(target_table)s, %(started_at)s, %(finished_at)s,
                    %(status)s, %(rows_read)s, %(rows_loaded)s, %(rows_rejected)s, %(error_message)s)
            """,
            {
                "batch_id": batch_id, "source_file": source_file, "target_table": target_table,
                "started_at": started_at, "finished_at": finished_at, "status": status,
                "rows_read": rows_read, "rows_loaded": rows_loaded, "rows_rejected": rows_rejected,
                "error_message": error_message,
            },
        )

    def insert_rejected_records(self, database: str, batch_id: str, source_file: str,
                                 target_table: str, rejected_df: pd.DataFrame):
        if rejected_df.empty:
            return
        import json
        with self._conn.cursor() as cur:
            for _, row in rejected_df.iterrows():
                error = row.get("_validation_error", "unknown")
                record = row.drop(labels=["_validation_error"], errors="ignore").to_dict()
                cur.execute(
                    f"""
                    INSERT INTO {database}.AUDIT.REJECTED_RECORDS
                        (batch_id, source_file, target_table, raw_record, validation_error)
                    SELECT %(batch_id)s, %(source_file)s, %(target_table)s,
                           PARSE_JSON(%(raw_record)s), %(validation_error)s
                    """,
                    {
                        "batch_id": batch_id, "source_file": source_file, "target_table": target_table,
                        "raw_record": json.dumps(record, default=str), "validation_error": error,
                    },
                )


def new_batch_id() -> str:
    return f"batch_{uuid.uuid4().hex[:12]}"
