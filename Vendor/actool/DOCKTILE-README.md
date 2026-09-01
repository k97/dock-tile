# Vendored: viraptor/actool 2.2.4 (commit e7a65f308dea3aa25cf885d2ae33a0caec4448bb)
Cleanroom Rust reimplementation of Apple's actool for Icon Composer `.icon` documents.
Cargo.toml declares `license = "MIT"`; upstream has no LICENSE file (issue to file upstream).
Local changes: see git log for this directory. Defect fixes carry fixture tests in tests/.
Do NOT update from upstream without re-running the fixture tests AND the manual Dock matrix.

## Deliberate deviations from the vendored tree

Two changes, both about **agent-instruction auto-loading**, neither touching the Rust build:

1. **`.claude/` — REMOVED.** It carried a `settings.json` declaring PreToolUse/PostToolUse command
   hooks plus three executable shell scripts under `hooks/`, and `commands/`/`skills/` instruction
   files for upstream's own decision-graph workflow (`deciduous`). Vendoring executable hooks that
   would run against this repo is not something we want.
2. **`CLAUDE.md` — RENAMED to `UPSTREAM-NOTES.md`** (content verbatim, a pure `git mv`). A nested
   `CLAUDE.md` **auto-loads into any agent session working in this directory**, which turned
   upstream's "Decision Graph Workflow … THIS IS MANDATORY" section into instructions in our
   context — the same hijack class as the `.claude/` directory above, and doubly wrong once (1)
   deleted the slash commands it advertises. Renaming rather than deleting keeps 100% of its
   genuinely valuable `.car` parity documentation while removing the auto-load behaviour. **Do not
   trim or rewrite its content** — verbatim preserves its provenance value.

An upstream-provenance diff must therefore exclude `target/`, `DOCKTILE-README.md` and `.claude/`,
and account for the rename:

```
diff -r -x target -x DOCKTILE-README.md -x .claude -x UPSTREAM-NOTES.md \
  <upstream-checkout> Vendor/actool
diff <upstream-checkout>/CLAUDE.md Vendor/actool/UPSTREAM-NOTES.md   # must be identical
```

Note: upstream's tag is `2.2.4` (no `v` prefix) — the brief said `v2.2.4`, but no such tag
exists; `2.2.4` is upstream's latest release tag and is what was vendored.

## Verified working invocation (Task 5 must use this verbatim)

Built binary: `Vendor/actool/target/release/docktile-actool` (renamed from the crate's own
`actool` binary — `[[bin]] name = "actool"` in `Cargo.toml`).

```
Vendor/actool/target/release/docktile-actool docs/icon-spike-fixtures/devtile-fix.icon \
  --compile "$OUT" --app-icon devtile-fix \
  --output-partial-info-plist "$OUT/partial.plist" \
  --platform macosx --target-device mac --minimum-deployment-target 15.0
```

This matches the CLI surface printed by `docktile-actool --help` and the usage already recorded
in [docs/icon-spike-fixtures/README.md](../../docs/icon-spike-fixtures/README.md) for Apple's own
`actool` — the OSS tool's flags are a superset/match of Apple's for this invocation, no
translation needed.

Smoke-tested 2026-09-01: produces `$OUT/Assets.car` containing `IconImageStack` renditions (see
`xcrun assetutil --info`). The compiled fixture renders the wrong glyph appearance in the Dock —
this is the documented compiler defect fixed in Task 2, not a toolchain/invocation problem.
