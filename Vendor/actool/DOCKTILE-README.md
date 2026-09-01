# Vendored: viraptor/actool 2.2.4 (commit e7a65f308dea3aa25cf885d2ae33a0caec4448bb)
Cleanroom Rust reimplementation of Apple's actool for Icon Composer `.icon` documents.
Cargo.toml declares `license = "MIT"`; upstream has no LICENSE file (issue to file upstream).
Local changes: see git log for this directory. Defect fixes carry fixture tests in tests/.
Do NOT update from upstream without re-running the fixture tests AND the manual Dock matrix.

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
