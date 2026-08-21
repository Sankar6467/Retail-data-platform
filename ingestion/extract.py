"""Extraction stage: reads a source CSV into a dataframe."""

import pandas as pd

def extract_csv(path: str) -> pd.DataFrame:
    """
    Read source file exactly as received.
    Data type conversions should happen in dbt staging models,
    not in the RAW ingestion layer.
    """
    return pd.read_csv(path, dtype=str)