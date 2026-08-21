"""
Validation stage: checks a raw dataframe against its table contract before
it's allowed to load. Rows that fail are split out (quarantined), not
silently dropped, and never block rows that pass.
"""
from dataclasses import dataclass, field

import pandas as pd


@dataclass
class ValidationResult:
    valid_rows: pd.DataFrame
    rejected_rows: pd.DataFrame  # includes a "_validation_error" column
    errors: list[str] = field(default_factory=list)

    @property
    def rows_read(self) -> int:
        return len(self.valid_rows) + len(self.rejected_rows)

    @property
    def rows_valid(self) -> int:
        return len(self.valid_rows)

    @property
    def rows_rejected(self) -> int:
        return len(self.rejected_rows)


def validate_dataframe(df: pd.DataFrame, required_columns: list[str],
                        unique_key: str | None) -> ValidationResult:
    """
    Applies structural checks in order: missing required columns (fatal,
    fails the whole file), then row-level checks (null required fields,
    duplicate keys) which quarantine only the offending rows.
    """
    missing_cols = [c for c in required_columns if c not in df.columns]
    if missing_cols:
        raise ValueError(f"Source file is missing required column(s): {missing_cols}")

    working = df.copy()
    working["_validation_error"] = ""

    # Rule 1: required columns must not be null/blank
    for col in required_columns:
        is_bad = working[col].isna() | (working[col].astype(str).str.strip() == "")
        working.loc[is_bad, "_validation_error"] += f"{col} is null/blank; "

    # Rule 2: unique key must not be duplicated within the file
    if unique_key and unique_key in working.columns:
        dup_mask = working[unique_key].duplicated(keep="first")
        working.loc[dup_mask, "_validation_error"] += f"duplicate {unique_key} within file; "

    is_rejected = working["_validation_error"] != ""
    rejected_rows = working[is_rejected].copy()
    valid_rows = working[~is_rejected].drop(columns=["_validation_error"]).copy()

    errors = []
    if len(rejected_rows) > 0:
        errors.append(f"{len(rejected_rows)} row(s) failed validation and were quarantined")

    return ValidationResult(valid_rows=valid_rows, rejected_rows=rejected_rows, errors=errors)
