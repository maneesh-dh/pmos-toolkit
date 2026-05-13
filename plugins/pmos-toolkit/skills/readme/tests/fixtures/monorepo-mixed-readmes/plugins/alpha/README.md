# alpha

A marketplace fixture used by /readme integration tests for compose-audit-scaffold and cross-file-rule evaluation.

Used to verify R4 (duplicate hero-line — this hero matches the root's) and R3
(this package carries its own Install section, divergent from root, so the
warn-with-override path fires rather than a blocker).

## Install

```sh
# Divergent from root — installs as a CDN bundle instead of git-clone.
curl -L https://example.com/alpha.tgz | tar xz
```

<!-- intentionally omits a link-up to root to fire R2 -->
