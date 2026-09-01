# Vendored: viraptor/actool 2.2.4 (commit e7a65f308dea3aa25cf885d2ae33a0caec4448bb)
Cleanroom Rust reimplementation of Apple's actool for Icon Composer `.icon` documents.
Cargo.toml declares `license = "MIT"`; upstream has no LICENSE file (issue to file upstream).
Local changes: see git log for this directory. Defect fixes carry fixture tests in tests/.
Do NOT update from upstream without re-running the fixture tests AND the manual Dock matrix.

## Deliberate deviations from the vendored tree

Three changes: two about **agent-instruction auto-loading** (neither touches the Rust build), one
a real **source fix** to a defect in the compiler itself.

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
3. **`src/car.rs` + `src/icon_bundle.rs` — DEFECT-2 FIX**, plus new
   `tests/docktile_appearance.rs` (3 tests) guarding it. Fixed a real bug in the vendored compiler:
   it built each IconGroup's layer list once, outside the per-appearance loop, so
   `hidden-specializations` was never consulted and every appearance shipped a byte-identical
   IconGroup with both glyph layers visible — the glyph rendered wrong in every style except by
   coincidence. See "Layer ordering and the defect-2 fix" below for the full account (root cause,
   evidence, and the `.rev()` behaviour this fix introduced). This is a genuine upstream-quality
   fix, not an auto-load exclusion — it changes what the compiler outputs, and the upstream PR /
   missing-LICENSE issue mentioned above still needs filing.

An upstream-provenance diff must therefore exclude `target/`, `DOCKTILE-README.md`, `.claude/`,
and `CLAUDE.md` (present upstream, renamed away here — without excluding it too, a plain `diff -r`
reports a spurious `Only in <upstream-checkout>: CLAUDE.md`, which is expected and accounted for
by the rename, not a real gap):

```
diff -r -x target -x DOCKTILE-README.md -x .claude -x CLAUDE.md -x UPSTREAM-NOTES.md \
  <upstream-checkout> Vendor/actool
diff <upstream-checkout>/CLAUDE.md Vendor/actool/UPSTREAM-NOTES.md   # must be identical
```

That diff will still show real differences at `src/car.rs`, `src/icon_bundle.rs`, and an
`Only in Vendor/actool/tests: docktile_appearance.rs` line — both are deviation 3 above, not a
gap in this recipe.

Note: upstream's tag is `2.2.4` (no `v` prefix) — the brief said `v2.2.4`, but no such tag
exists; `2.2.4` is upstream's latest release tag and is what was vendored.

## Layer ordering and the defect-2 fix (`.rev()` — critical, read before touching layer order)

`icon_bundle.rs`'s `resolve_group_layers` (used by `build_icon_car`) collects each IconGroup's
visible layer references and calls `.rev()` on the collected `Vec` before returning it — storing
layers in **reverse document order**. That `.rev()` is the *entire* fix for defect 2 (the vendored
compiler previously built one layer list per group, outside the per-appearance loop, so
`hidden-specializations` was never resolved and both glyph layers shipped visible in every
appearance — see the fix commit `47f1e7a`). Fixing the visibility bug did not by itself fix the
*order* the layers are stored in once more than one layer is visible in a group; ordering is a
separate, unverified-by-us fact about Apple's own format, and the following is the **only**
evidence we have for it.

**The evidence.** With only two glyph layers (our product's model: exactly one of `glyph-light` /
`glyph-dark` visible per appearance), layer order inside a group is moot — there is only one
visible layer to place. To determine the real ordering rule, a **synthetic three-layer** `.icon`
bundle was compiled with **Apple's own `actool`** (Xcode 26.6, bundle-version 24765, macOS 26.6.2)
and its output CSI was decoded by hand. Result: Apple stores the layers as **doc2, doc1, doc0** —
reverse of the document's own layer order (a "painter's" back-to-front convention, matching the
group-level ordering the crate already applied elsewhere). The middle, unspecialized layer stayed
visible in every appearance, as expected. This is the *only* observation of Apple's ordering
behaviour for a group with more than one simultaneously-visible layer; no other fixture or probe
exercises it.

**Why this matters going forward.** For DockTile's actual tiles today (2 layers, exactly 1 visible
per appearance) this `.rev()` is a provable no-op — order is unobservable with one visible layer.
It only has teeth for a **future** icon model with 2+ layers simultaneously visible in the same
appearance (e.g. a background accent layer plus a glyph layer both shown at once). If that ever
happens, this three-layer probe is the sole justification that Apple wants reverse-document order,
and it should be re-verified with a probe matching the new shape before being trusted further —
don't assume it generalizes from a synthetic 3-layer test to an arbitrary N.

## Known follow-up, not fixed here: `emit_variant_axis`

`icon_bundle.rs`'s `emit_variant_axis` (attr-24 duplicate-rendition axis) disagrees with Xcode
26.6: probing Apple's own `actool` with eight constructed `.icon` shapes produced **no** attr-24
axis in any case, contradicting the crate's documented six-fixture rule. This is the source of the
14-vs-7 `Icon Image` / 2-vs-1 `PackedImage` rendition-count difference from Apple's output — a
**separate mechanism** from defect 2 above, with no observed rendering impact (the full Dock
appearance matrix is indistinguishable from Apple's own car with the axis still emitting). Left
alone deliberately: fixing it needs the crate's un-vendored `third_party/` fixtures (which may
reflect an older Xcode toolchain) to avoid regressing parity for other consumers. Treat this as an
open, separate defect if it is ever picked up again — do not conflate it with defect 2.

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
`xcrun assetutil --info`). At the time of this smoke test the compiled fixture rendered the wrong
glyph appearance in the Dock — a compiler defect (documented above as "defect 2"), not a
toolchain/invocation problem. That defect was fixed in commit `47f1e7a`; the fixture now renders
the correct glyph per appearance, verified against Apple's own `actool` output.
