---
plan: export-checks
units:
  - id: W1
    title: Keep export column order
  - id: W2
    title: Verify the nightly job reads the new format
---

# Improvement plan

## Non-goals

- Not changing the export format.

## W1: Keep export column order

ID: W1
Depends on: nothing

### Acceptance criteria

`test_export_keeps_column_order` passes and the CSV header matches `docs/export.md`.

## W2: Verify the nightly job reads the new format

| Field | Value |
| --- | --- |
| **ID** | W2 |
| **Dependencies** | W1 |
| **How it goes red** | the job logs `KeyError: 'amount'` |
