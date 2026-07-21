---
plan: fix-generics
units:
  - id: W1
    title: Fix Optional<Config> handling
  - id: W2
    title: Make Repository<Foo> null-safe
---

# Improvement plan

## Non-goals

- Not changing the public API.

## W1: Fix Optional<Config> handling

- **ID:** W1
- **Acceptance criteria:** `test_optional_config` passes.

## W2: Make Repository<Foo> null-safe

- **ID:** W2
- **Acceptance criteria:** `test_repo_null` passes.
