import os
import sys

import pandas as pd

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from validation import validate_dataframe  # noqa: E402


def test_all_valid_rows_pass_through():
    df = pd.DataFrame({
        "customer_id": ["C1", "C2"],
        "email": ["a@x.com", "b@x.com"],
        "signup_date": ["2024-01-01", "2024-01-02"],
    })
    result = validate_dataframe(df, ["customer_id", "email", "signup_date"], "customer_id")
    assert result.rows_valid == 2
    assert result.rows_rejected == 0


def test_missing_required_column_raises():
    df = pd.DataFrame({"customer_id": ["C1"]})
    try:
        validate_dataframe(df, ["customer_id", "email"], "customer_id")
        assert False, "expected ValueError"
    except ValueError as exc:
        assert "email" in str(exc)


def test_null_required_field_is_quarantined_not_dropped():
    df = pd.DataFrame({
        "customer_id": ["C1", "C2"],
        "email": ["a@x.com", None],
    })
    result = validate_dataframe(df, ["customer_id", "email"], "customer_id")
    assert result.rows_valid == 1
    assert result.rows_rejected == 1
    assert result.rows_read == 2  # nothing silently dropped
    assert "email is null/blank" in result.rejected_rows.iloc[0]["_validation_error"]


def test_duplicate_unique_key_quarantines_the_later_row():
    df = pd.DataFrame({
        "customer_id": ["C1", "C1"],
        "email": ["a@x.com", "b@x.com"],
    })
    result = validate_dataframe(df, ["customer_id", "email"], "customer_id")
    assert result.rows_valid == 1
    assert result.rows_rejected == 1
    assert result.valid_rows.iloc[0]["email"] == "a@x.com"  # first occurrence kept


def test_blank_string_is_treated_as_null():
    df = pd.DataFrame({
        "customer_id": ["C1", "C2"],
        "email": ["a@x.com", "   "],
    })
    result = validate_dataframe(df, ["customer_id", "email"], "customer_id")
    assert result.rows_valid == 1
    assert result.rows_rejected == 1
