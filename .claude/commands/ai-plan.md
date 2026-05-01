---
name: ai-plan
description: Research a task and write an ai-plan file. Always stops after writing the plan — never executes code. Use /doit <plan-name> to execute.
---

# /ai-plan — Research, Plan, Stop

**Usage**: `/ai-plan <plan-name>`

`<plan-name>` is the kebab-case output filename (e.g. `add-ovs-wave`, `fix-rocky-preseed`).
After you provide the name, this skill asks what you want to accomplish, then researches
and writes the plan.

**What this skill does**: asks for the task, reads the codebase, writes
`infra/_framework-pkg/_docs/ai-plans/<plan-name>.md`, surfaces open questions,
then **stops**. No code is written. No infrastructure files are changed.

**To execute the plan**: `/doit <plan-name>`

---

## Step 1 — Read the screwups log

Read `infra/_framework-pkg/_docs/ai-screw-ups/README.md` in full before doing anything else.

---

## Step 2 — Get the plan name and task description

**If `$ARGUMENTS` is empty**: ask the user:
> What should the plan be named? (kebab-case, e.g. `add-ovs-wave`)

**If `$ARGUMENTS` is provided**: treat it as `<plan-name>`. Then ask the user:
> What do you want to accomplish with plan `<plan-name>`?

Wait for the user's task description before continuing. Do not proceed to Step 3 until
you have both a plan name and a task description.

---

## Step 3 — Explore the codebase

Read all files relevant to the task. This is the research phase — be thorough.

For each area of the codebase the task will touch:
- Read the current code/config
- Read related docs in `infra/<pkg>/_docs/`
- Identify what exists vs. what needs to be added/changed
- Understand dependencies, naming conventions, and patterns used elsewhere

Do NOT skip this step. A plan written without reading the code will be wrong.

---

## Step 4 — Write the plan file

Create `infra/_framework-pkg/_docs/ai-plans/<plan-name>.md` with this structure:

```markdown
# Plan: <Task Title>

## Objective
<One paragraph: what this plan achieves and why.>

## Context
<Key findings from code exploration — what exists, what's missing, relevant constraints.>

## Open Questions
<List any decisions that need user input BEFORE executing. If none, write "None — ready to proceed.">

## Files to Create / Modify

### `path/to/file` — <create|modify>
<Exact description of what to write or change. Include code snippets where the change is non-trivial.
Be specific enough that a fresh Claude instance with no prior context can execute this correctly.>

### `path/to/other` — <create|modify>
...

## Execution Order
<Numbered list of which files to touch in what order, and why (dependencies between steps).>

## Verification
<How to confirm the plan was executed correctly — commands to run, outputs to check.>
```

Write the plan to disk using the Write tool. Commit it:

```bash
git add infra/_framework-pkg/_docs/ai-plans/<plan-name>.md
git commit -m "ai-plan(<plan-name>): write implementation plan

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

---

## Step 5 — Review the plan for correctness

Re-read the plan against the actual code. Check:

- Every file path in the plan actually exists (for modifications) or has a valid parent directory
- Naming conventions match the rest of the codebase (wave names, YAML keys, HCL patterns)
- Dependencies are correct (e.g. Terraform deps, wave ordering)
- No hardcoded values that should come from config
- No steps that violate CLAUDE.md rules (no DB edits, no skipping tests, etc.)

Fix any issues in the plan file before proceeding.

---

## Step 6 — Surface open questions and stop

Check the "Open Questions" section of the plan. Present them to the user clearly:

> **Questions before I proceed:**
> 1. ...
> 2. ...

**STOP HERE regardless.** Do not execute any code. Do not modify any infrastructure files.

If there are no open questions, say:

> **No open questions. Plan is complete.**
>
> Plan: `infra/_framework-pkg/_docs/ai-plans/<plan-name>.md`
> Run `/doit <plan-name>` to execute.

If there are open questions, say:

> **Plan written. Waiting on answers before execution.**
>
> Plan: `infra/_framework-pkg/_docs/ai-plans/<plan-name>.md`
> Answer the questions above, then run `/doit <plan-name>` to execute.

---

**This skill never executes code.** Execution is always a separate, explicit `/doit` invocation.
