# widget-cli

widget-cli is a command-line tool that converts widget files between formats and validates their structure.

Use it when you need to migrate widgets between v1 and v2 schemas, or when an automated build needs schema validation without booting the full editor.

## How to install

```bash
brew install widget-cli
```

Verify with `widget-cli --version`.

## How to convert widgets

```bash
widget-cli convert input.widget output.widget --to v2
```

The tool reads HTML and MD attachments embedded in the widget manifest and round-trips them faithfully. Conversion is idempotent — re-running on a v2 output is a no-op.

## How to troubleshoot

If conversion fails, run with `--debug` to see the per-step trace. Common issues:

- **Stale schema cache** — clear with `widget-cli cache clear`.
- **Missing dependency** — `widget-cli doctor` reports the offending tool.
- **Manifest drift** — see [docs/manifest.md](docs/manifest.md) for the canonical shape.

## How to contribute

See [CONTRIBUTING.md](CONTRIBUTING.md) for branch conventions and the test matrix.

The project uses worktrees for parallel feature work and subagent dispatch for the heavier conversion paths.

## License

MIT — see [LICENSE](LICENSE).
