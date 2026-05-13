"""survey-analyse helper package — per-question-type stats + ingest + cleaning + PII.

Pure-stdlib Python except `openpyxl` (used only when ingesting .xlsx/.xls).
Each module exposes pure functions returning JSON-serializable dicts; each
ships a `--selftest` CLI for known-answer regression.

Modules are imported lazily by callers (per-run analysis.py and tests/) —
this __init__ stays empty to avoid the `python3 -m helpers.<mod> --selftest`
double-import RuntimeWarning."""
