---
name: artifact
description: Generate, refine, and update structured PM/eng artifacts (PRD, Experiment Design Doc, Engineering Design Doc, Discovery Doc) from existing context plus targeted gap-filling questions. Each artifact passes through a reviewer-subagent + auto-apply loop (max 2 iters) governed by per-section eval criteria. Ships with 4 built-in templates and 4 writing-style presets (Concise, Tabular, Narrative, Executive); users can author their own at ~/.pmos/artifacts/. Use when the user says "draft a PRD", "create an experiment design", "write a design doc", "generate a discovery doc", "/artifact", or names an artifact type to produce.
user-invocable: true
argument-hint: "[ | <type> [--tier lite|full] [--preset <slug>] | create <type> [...] | refine <path> | update <path> | template add|list|remove [<slug>] | preset add|list|remove [<slug>]]"
---

# /artifact

<!-- TODO Tasks 8–15 fill in body -->
