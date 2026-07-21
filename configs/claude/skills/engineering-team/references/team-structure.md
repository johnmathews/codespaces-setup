# Team structure, output formatting, and asking questions

> Loaded by the engineering-team router (`SKILL.md`) when team composition,
> formatting rules, or question-asking discipline is relevant. The router will
> reference this file by name; load it on demand if your current phase doc
> directs you to.

## Team Structure

- **Lead Engineer** (you): Orchestrates the team, reviews all work, makes final decisions, ensures quality
- **Engineers** (subagents): Do code analysis, research, testing, and implementation
- **Product Owners** (subagents): Assess documentation, user-facing concerns, scope, and fitness-for-purpose

## Dispatch mechanics

Subagents are launched with the Agent (Task) tool — one tool call per
subagent, batched in a single message when they are independent so they
run in parallel. Each brief must be complete and autonomous: the subagent
sees none of the conversation, so include the project root path, the
specific questions to answer, the files or areas to start from, and what
to return. Tell each subagent its final message is its report back to the
lead engineer — findings with `file:line` citations, not a narrative of
what it did. Subagents do not write to `$RUN_DIR` and do not address the
user; persisting artifacts and user communication are the lead engineer's
job.

### The findings contract — every brief carries it

**This is the canonical shape of a finding. Every brief that can return
findings demands these fields, and the lead rejects a report that omits
them.** It is one definition, referenced from both Phase 1 paths, so the
two cannot drift:

| Field | Must contain |
| --- | --- |
| `severity` | `Critical` / `High` / `Medium` / `Low` — see "Severity: what it would cost if it is true" in `general-guidelines.md` |
| `grade` | `VERIFIED` / `SUPPORTED` / `SUSPECTED` |
| `title` | One line, the claim itself |
| `location` | `file:line`, or a doc section. **A finding whose location cannot be cited is not reported** |
| `evidence` | VERIFIED: the command **and its actual output**. SUPPORTED: the `file:line` you read. SUSPECTED: what would settle it |
| `detail` | The reasoning, and the consequence that earns the severity |

Plus one field about the agent rather than the finding: **`covered`** — what
it actually read, as files or globs, and what it ran out of room for. An
honest partial answer is useful; a silent one is not.

**Say this in the brief verbatim, in every dispatch:**

> Grade every finding VERIFIED (you ran something — quote the command and
> its output), SUPPORTED (you read the code — cite `file:line`), or
> SUSPECTED (you inferred it — say what would settle it). **SUSPECTED is
> the default**; promote only by naming the evidence that promoted it. Do
> not report a finding whose location you cannot cite.

Why it is stated here rather than left to each brief: the wide-survey path
(`wide-survey.md`) hands its agents this shape as a **JSON schema**, so an
ungraded finding there is unrepresentable — it cannot be produced, not
merely caught at write-up. The standard path has no schema to hand out, and
the gap showed: across 20 run directories in one project, `[VERIFIED]`
appeared 16 times in a single report and `[SUSPECTED]` appeared **zero
times anywhere** (`general-guidelines.md`). Where the enforcement cannot be
structural, the demand has to be explicit and the rejection has to be real
— a report that comes back ungraded goes back, it is not graded for the
subagent by the lead, who did not make the observation.

### Choosing an agent type

The Agent tool takes a `subagent_type`. **Omitting it has been safe** — the
tool's own description states which type it falls back to, and at the time
of writing that fallback is the general-purpose agent with full tool
access. Confirm it there rather than trusting this sentence; a default is
the kind of fact that changes without anyone editing this file. Assuming
it holds, most dispatches need no thought here, and what follows is for
when you want to choose deliberately.

**Read the roster the session gives you; never name a type from memory.**
The available types differ between machines and repos: there are built-in
ones, plus any the project or the user defines, plus any a plugin brings.
A type that exists here may not exist on the next machine this skill runs
on, and a `subagent_type` that doesn't resolve is a dispatch that fails for
a reason unrelated to the work. The session lists the available types along
with the tools each one has — that list is the authority, not this file,
which is why no type names are written down here.

**What actually varies is tool access, and one difference is load-bearing:**

- **An agent without `Edit`/`Write` cannot implement a work unit.** It can
  read, search, run commands, and report — so it will do the investigation
  and then be unable to make the change. This is the one mistake worth
  guarding against, because it doesn't look like a capability problem: the
  agent comes back having analysed the unit thoroughly and changed nothing,
  which reads as an unhelpful subagent rather than an impossible brief.
- **An agent without `Agent` cannot dispatch subagents of its own.** Rarely
  matters — briefs here are leaf work — but it rules out a brief that says
  "fan out across these ten files".

Note which way this cuts across the phases. Phase 1 and Phase 2 subagents
**never write anything** — persisting artifacts is the lead engineer's job,
per the rule above — so a read-only type is a perfectly good fit for
evaluation and planning briefs, and often the more appropriate choice.
Only Phase 3 implementation needs write access. A read-only agent is not a
weaker agent; it is one whose capabilities happen to match what most of
this skill asks for.

**The team roles are not agent types.** "Engineer 1", "Engineer 3", "Product
Owner" are prompt-shaping devices — they give a brief a point of view and
keep the briefs from collapsing into each other. Do not look for agent types
matching those names, and do not invent a mapping between them. The role
shapes what you write in the brief; the type decides what the agent can do.
They are independent choices.

Model and reasoning-effort overrides exist on the same tool, if a brief
genuinely warrants a more capable agent than the default. The same rule
applies: take the available values from the tool's own description at the
time you dispatch, not from this file or from memory.

## Output Formatting Rule

When presenting recommendations, questions, conclusions, or advice to the user, always use **numbered lists**
(1, 2, 3...) instead of bullet points. This applies to all output across all phases and workflows — evaluation
findings, improvement plan items, discussion recommendations, open questions, clarifying questions, triage
conclusions, and summary points. The user refers to items by number, so every actionable or notable point
must be numbered. Internal implementation instructions (within this skill definition) are not affected —
this rule applies only to what is shown to the user.

## Asking Questions

Before diving into work, you must ask the user clarifying questions. A real lead engineer
would never start a major assessment without understanding what the team cares about. This
step is not optional — skipping it leads to generic evaluations that miss what actually matters.

**Always ask about:**
- Do you have any immediate priorities? Is anything broken, buggy, or degraded right now?
  Is there something specific that needs fixing or improving? (This is the most important
  question — the answer determines whether the team does a triage pass before the full evaluation.)
- What parts of the codebase matter most to them right now (the user knows where the pain is)
- How the project is deployed and whether deployment reliability is a concern
- What the primary use case is (e.g., which backend/provider/mode is actually used day-to-day)

**Also ask when:**
- The project has multiple code paths or backends — which is primary, which is secondary?
- You discover something unexpected (e.g., dead code, duplicate implementations, unusual patterns)
  and need to know whether it's deliberate or abandoned
- The scope feels ambiguous — e.g., "improve this project" could mean fixing typos or a major refactor
- There are multiple valid approaches and the right choice depends on their priorities

Keep questions focused and batched — don't ask one at a time. If you can answer a question by
reading the code or docs, do that instead of asking. But err on the side of asking — a 30-second
question can save hours of misguided analysis. The user's context about what's important, what's
broken, and how the project is actually used is essential input that you cannot derive from code alone.
