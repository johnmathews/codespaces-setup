# Evaluation report — fixture

> Purpose
>
> A minimal, structurally valid report. This one must stay green.

## 1. Executive summary

A one-module tool whose documented workflow crashes on first use.

## 2. Findings index

| ID | Severity | Grade | Finding | Location |
| --- | --- | --- | --- | --- |
| F1 | Critical | [VERIFIED] | Documented workflow crashes on first use | `a.py:12` |
| F2 | Medium | [SUSPECTED] | Concurrent writes may drop an entry | `b.py:6-14` |

## 3. Findings in detail

### F1 Documented workflow crashes on first use

- **Severity:** Critical — the only documented path does not run.
- **Grade:** [VERIFIED] — ran the README's own example.
- **Location:** `a.py:12`
- **Disconfirming check:** if false, `total` would print a number after one `add`. It does not.

```console
$ python3 a.py total
TypeError: unsupported operand type(s) for +: 'int' and 'str'
```

### F2 Concurrent writes may drop an entry

- **Severity:** Medium — a silently lost record.
- **Grade:** [SUSPECTED] — settled by two interleaved writes under a loop.
- **Location:** `b.py:6-14`
- **Disconfirming check:** if false, both entries survive 100 interleaved runs.

## 4. Test suite results

`pytest` — 0 tests collected.

## 5. Project overview

One module, no dependencies.

## 6. Strengths

`load()` and `save()` do one thing each.

## 7. Weaknesses

See F1 — the documented workflow does not run.

## 8. NFR register

| Requirement | Where stated | How enforced |
| --- | --- | --- |
| No secrets in VCS | `README.md` | **prose only** |

**Un-gated code inventory:** none — the repo has no CI at all.

**NFRs absent rather than unenforced:** no accessibility requirement (no UI).

## 9. Onboarding assessment

Could not tell where state is stored without reading `b.py`.

## 10. Assessment dimensions

- **Simplicity:** 4/5 — one module, no indirection beyond `load`/`save`.

## 11. Dependency audit

No manifest and no third-party imports; stdlib only. Checked by reading both files.

## 12. Gap analysis

No tests of any kind.

## 13. Architectural assessment

Direct file IO is the right call at this size; a database would be overhead.

## 14. Methodology and limitations

Fixture for `check_report.py`. Nothing was actually evaluated.
