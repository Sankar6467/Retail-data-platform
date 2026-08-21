"""
Central configuration for the ingestion framework. All secrets come from
environment variables (never hardcoded) - populate a local .env file
(see .env.example) which python-dotenv loads automatically."""
import os
from dataclasses import dataclass

from dotenv import load_dotenv

load_dotenv()


@dataclass(frozen=True)
class SnowflakeConfig:
    account: str
    user: str
    password: str
    role: str
    warehouse: str
    database: str
    schema: str

    @classmethod
    def from_env(cls) -> "SnowflakeConfig":
        required = ["SNOWFLAKE_ACCOUNT", "SNOWFLAKE_USER", "SNOWFLAKE_PASSWORD",
                    "SNOWFLAKE_ROLE", "SNOWFLAKE_WAREHOUSE", "SNOWFLAKE_DATABASE"]
        missing = [v for v in required if not os.getenv(v)]
        if missing:
            raise EnvironmentError(
                f"Missing required environment variables: {', '.join(missing)}. "
                f"Copy .env.example to .env and fill in your trial account details."
            )
        return cls(
            account=os.environ["SNOWFLAKE_ACCOUNT"],
            user=os.environ["SNOWFLAKE_USER"],
            password=os.environ["SNOWFLAKE_PASSWORD"],
            role=os.environ["SNOWFLAKE_ROLE"],
            warehouse=os.environ["SNOWFLAKE_WAREHOUSE"],
            database=os.environ["SNOWFLAKE_DATABASE"],
            schema=os.getenv("SNOWFLAKE_SCHEMA", "RAW"),
        )


# Retry/backoff behaviour for transient Snowflake connection errors
MAX_RETRIES = 3
RETRY_BACKOFF_SECONDS = 5

# Per-table ingestion contract: source file -> target table -> required (non-null) columns
TABLE_CONTRACTS = {
    "customers.csv": {
        "target_table": "RAW.CUSTOMERS",
        "required_columns": ["customer_id", "email", "signup_date"],
        "unique_key": "customer_id",
    },
    "products.csv": {
        "target_table": "RAW.PRODUCTS",
        "required_columns": ["product_id", "sku", "unit_price"],
        "unique_key": "product_id",
    },
    "stores.csv": {
        "target_table": "RAW.STORES",
        "required_columns": ["store_id", "store_name"],
        "unique_key": "store_id",
    },
    "orders.csv": {
        "target_table": "RAW.ORDERS",
        "required_columns": ["order_id", "customer_id", "order_date"],
        "unique_key": "order_id",
    },
    "order_items.csv": {
        "target_table": "RAW.ORDER_ITEMS",
        "required_columns": ["order_item_id", "order_id", "product_id", "quantity"],
        "unique_key": "order_item_id",
    },
    "inventory_snapshots.csv": {
        "target_table": "RAW.INVENTORY_SNAPSHOTS",
        "required_columns": ["snapshot_date", "store_id", "product_id"],
        "unique_key": None,  # composite grain, no single-column PK
    },
}
