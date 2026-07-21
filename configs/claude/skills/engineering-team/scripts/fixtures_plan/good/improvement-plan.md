---
plan: fix-the-widget
units:
  - id: W1
    title: Add input validation
  - id: W2
    title: Fix the null dereference
---

# Improvement plan

## Non-goals

- Not refactoring the auth module — separate plan.

## W1: Add input validation

- **ID:** W1
- **Priority:** High
- **Risk:** Low
- **Size:** S
- **Files (footprint):** `src/widget.py`, `tests/test_widget.py`
- **Acceptance criteria:** `test_widget_rejects_empty` passes.

## W2: Fix the null dereference

- **ID:** W2
- **Priority:** Medium
- **Risk:** Low
- **Size:** S
- **Files (footprint):** `src/widget.py`
- **Acceptance criteria:** no crash on null input; `test_null` passes.
