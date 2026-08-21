"""Extraction stage: reads a source CSV into a dataframe with light type parsing."""
import pandas as pd

DATE_COLUMNS = {
    "signup_date", "created_at", "updated_at", "order_date", "open_date", "snapshot_date",
}


def extract_csv(path: str) -> pd.DataFrame:
    df = pd.read_csv(path, dtype=str)  # read everything as string first; casting is a staging/dbt concern
    for col in df.columns:
        if col in DATE_COLUMNS:
            df[col] = pd.to_datetime(df[col], errors="coerce")
    return df
