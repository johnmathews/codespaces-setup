# Sitrep: a DoD checklist instead of a Done list

The sitrep's first section, "Definition of done", is now **DoD**. Instead of a
sentence it is a checklist, one bullet per item, so it can be read at a glance.

- **Items come from `done_when:`**, which stays one line in `run.yaml` with its
  items separated by `;`. A YAML list would have broken `check_run.py`, which
  reads the field as one value. The line still reads as a sentence where Phase 3
  quotes it in a brief.
- **Each bullet has a mark:** ✅ met, ⬜ not yet (with a count when partly met),
  ❌ blocked or not possible as things stand, with the reason. The marks are
  worked out again from evidence for every sitrep and never stored, because a
  stored tick goes stale.
- **"Done" became "Also done"**, which is shown only when it has something in it.
  It holds finished work no DoD item covers, such as a side fix. The checklist
  already shows the rest, so a full Done list would repeat it. It moved below
  "Still to do", since it is the least urgent section.
- **Emoji are rationed:** the three marks are the only ones in a sitrep, so they
  stand out.

The rules live in `references/status-updates.md` §3; the `sitrep` skill reads
them from there.
