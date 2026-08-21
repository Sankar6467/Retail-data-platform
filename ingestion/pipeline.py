"""
Main ingestion pipeline: for each configured source file, extract -> validate
-> load -> audit-log, with per-file error isolation (one bad file does not
stop the others) and a non-zero exit code if any file fails outright.

Usage:
    python pipeline.py --data-dir ../data
    python pipeline.py --data-dir ../data --only customers.csv,orders.csv
"""
import argparse
import logging
import os
import sys
from datetime import datetime, timezone

from config import TABLE_CONTRACTS, SnowflakeConfig
from extract import extract_csv
from snowflake_client import SnowflakeClient, TransientConnectionError, new_batch_id
from validation import validate_dataframe

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)-7s | %(name)s | %(message)s",
)
logger = logging.getLogger("pipeline")


def process_file(client: SnowflakeClient, database: str, data_dir: str,
                  file_name: str, contract: dict, batch_id: str) -> bool:
    """Returns True on success (including partial success with quarantined rows)."""
    path = os.path.join(data_dir, file_name)
    target_table = contract["target_table"]
    schema, table = target_table.split(".")
    started_at = datetime.now(timezone.utc)

    if not os.path.exists(path):
        logger.error("Source file not found: %s", path)
        client.insert_run_log(database, batch_id, file_name, target_table, started_at,
                               datetime.now(timezone.utc), "FAILED", 0, 0, 0,
                               "source file not found")
        return False

    try:
        df = extract_csv(path)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Extraction failed for %s", file_name)
        client.insert_run_log(database, batch_id, file_name, target_table, started_at,
                               datetime.now(timezone.utc), "FAILED", 0, 0, 0, str(exc))
        return False

    try:
        result = validate_dataframe(df, contract["required_columns"], contract["unique_key"])
    except ValueError as exc:
        # Missing required columns entirely -> fatal for this file, nothing loads
        logger.error("Validation contract violation for %s: %s", file_name, exc)
        client.insert_run_log(database, batch_id, file_name, target_table, started_at,
                               datetime.now(timezone.utc), "FAILED", len(df), 0, len(df), str(exc))
        return False

    valid_df = result.valid_rows.copy()
    valid_df["_source_file"] = file_name
    valid_df["_batch_id"] = batch_id

    rows_loaded = 0
    load_error = None
    try:
        rows_loaded = client.load_dataframe(valid_df, database, schema, table)
    except Exception as exc:  # noqa: BLE001
        logger.exception("Load failed for %s -> %s", file_name, target_table)
        load_error = str(exc)

    if result.rows_rejected:
        client.insert_rejected_records(database, batch_id, file_name, target_table, result.rejected_rows)
        logger.warning("%s: %d row(s) quarantined into AUDIT.REJECTED_RECORDS", file_name, result.rows_rejected)

    finished_at = datetime.now(timezone.utc)
    if load_error:
        status = "FAILED"
    elif result.rows_rejected:
        status = "PARTIAL"
    else:
        status = "SUCCESS"

    client.insert_run_log(database, batch_id, file_name, target_table, started_at, finished_at,
                           status, result.rows_read, rows_loaded, result.rows_rejected, load_error)

    logger.info("%s -> %s | read=%d loaded=%d rejected=%d status=%s",
                file_name, target_table, result.rows_read, rows_loaded, result.rows_rejected, status)
    return status != "FAILED"


def run(data_dir: str, only: list[str] | None) -> int:
    cfg = SnowflakeConfig.from_env()
    batch_id = new_batch_id()
    logger.info("Starting ingestion run batch_id=%s", batch_id)

    files_to_process = only or list(TABLE_CONTRACTS.keys())
    overall_success = True

    try:
        with SnowflakeClient(cfg) as client:
            for file_name in files_to_process:
                contract = TABLE_CONTRACTS.get(file_name)
                if not contract:
                    logger.error("No ingestion contract defined for %s - skipping", file_name)
                    overall_success = False
                    continue
                ok = process_file(client, cfg.database, data_dir, file_name, contract, batch_id)
                overall_success = overall_success and ok
    except TransientConnectionError:
        logger.exception("Aborting run: could not establish a Snowflake connection")
        return 2

    logger.info("Ingestion run complete batch_id=%s overall_success=%s", batch_id, overall_success)
    return 0 if overall_success else 1


def main():
    parser = argparse.ArgumentParser(description="Retail ingestion framework")
    default_data_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "data")
    parser.add_argument("--data-dir", default=default_data_dir, help="Directory containing source CSV files")
    parser.add_argument("--only", default=None, help="Comma-separated list of files to process (default: all)")
    args = parser.parse_args()

    only = [f.strip() for f in args.only.split(",")] if args.only else None
    sys.exit(run(args.data_dir, only))


if __name__ == "__main__":
    main()
