# Resolve Pipeline Input

Shared procedure for pipeline skills that consume a prior-phase document. Callers pass:
- `phase` — the canonical phase name: `requirements`, `spec`, or `plan`
- `label` — human-readable name for prompts (e.g., "requirements doc", "spec", "plan")

The phase maps to a numbered file in the current feature folder:

| phase          | feature-folder file       | legacy folder         |
|----------------|---------------------------|-----------------------|
| `requirements` | `01_requirements.md`      | `{docs_path}/requirements/` |
| `spec`         | `02_spec.md`              | `{docs_path}/specs/`        |
| `plan`         | `03_plan.md`              | `{docs_path}/plans/`        |

Try resolution steps in order. Stop at the first hit. Always echo the resolved path on a single line before proceeding — this is the user's only chance to catch a wrong pick.

## Step 1: Explicit argument

If the user passed an argument to the slash command:
- If it resolves to an existing file path, use it. Echo: `Using: <path>`
- Otherwise treat the argument as inline content. Echo: `Using inline <label> from argument`

Proceed. Skip remaining steps.

## Step 2: Current feature folder

If a current feature folder is set (per `_shared/pipeline-setup.md` Section 0 — `settings.current_feature`), check for the numbered file for this `phase`:
- Found: echo `Using: <path>` and proceed.
- Not found: continue to Step 3.

## Step 3: Conversation history

Scan this session for any file written, edited, or read earlier that matches the feature-folder file or the legacy `{docs_path}/{phase}/` location. If one or more exist, pick the most recently touched. Echo: `Using from this session: <path>`

Proceed. Skip remaining steps. Do not prompt — the echo is the confirmation; the user can interrupt if wrong.

## Step 4: Legacy folder picker (fallback)

List files in legacy `{docs_path}/{phase_legacy}/` sorted by mtime (newest first), keeping up to 3. (`phase_legacy` per the table above: `requirements`, `specs`, `plans`.)

- **0 files:** Report `No {label} found in current feature folder or {docs_path}/{phase_legacy}/` and ask the user to provide a path or inline content. Do not proceed until provided.
- **1 file:** Skip the list. Echo: `Using legacy: <path>` and proceed.
- **2–3 files:** Present a numbered list:

  ```
  Recent {label}s in {docs_path}/{phase_legacy}/ (legacy):
    [1] <path>  (modified <mtime>)
    [2] <path>  (modified <mtime>)
    [3] <path>  (modified <mtime>)
  Pick one [default 1]:
  ```

  On confirmation (including empty input → 1), echo: `Using legacy: <path>` and proceed.
