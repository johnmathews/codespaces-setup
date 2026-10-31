---
plan: cache-fix
units:
  - id: W1
    title: Cap the cache size
---

# Improvement plan

## Non-goals

- Not replacing the cache library.

## W1: Cap the cache size

- **ID:** W1
- **Acceptance criteria:** `test_cache_evicts_at_cap` passes.

## Constraints the user set

- Dependencies: no new packages. (A closing section is not part of W1.)
