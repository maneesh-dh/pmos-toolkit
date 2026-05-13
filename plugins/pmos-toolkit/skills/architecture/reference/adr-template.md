# ADR-{NNNN}: {title}

**Status:** Proposed
**Date:** {date}
**Triggered by:** /architecture audit (rule: {rule_id}, severity: {severity})

## Context

<1–3 paragraphs — what the rule is and where it fires. Replace this
placeholder with the human-authored context: why this rule exists in the
project's `principles.yaml`, what the offending code does, and what
risk it carries.>

## Decision

<1 paragraph — placeholder for human to fill in. The audit cannot make
the call for you: either the offending code is the intentional exception
(record the rationale + scope) or the rule wins (track the cleanup task).>

## Consequences

<1 paragraph — placeholder. Spell out what changes for future
contributors: is this a one-off exemption (add a row to `principles.yaml ::
exemptions:`?) or a precedent that should reshape the rule itself?>

## Suppresses

- rule: {rule_id}
  file: {file}
  line: {line}
