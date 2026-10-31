---
plan: cache-fix
units:
  - id: W1
    title: Cap the cache size
  - id: W2
    title: Document the cache setting
---

# Improvement plan

## Non-goals

- Not replacing the cache library.

## W1: Cap the cache size

- **ID:** W1
- **Dependencies:** none
- **Acceptance criteria:** `test_cache_evicts_at_cap` passes.

## W2: Document the cache setting

- **ID:** W2
- **Dependencies:** W1
- **Files (footprint):** `docs/config.md`

## Lessons so far

- Acceptance criteria written late were vague. (A closing section is not part of W2.)
