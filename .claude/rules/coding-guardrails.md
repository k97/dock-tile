# Coding Guardrails

Always-on; the preventive half of the plan/diff gates.

- **Think before coding** — state assumptions and the simpler alternative before the first edit; ask only when readings differ materially.
- **Simplicity first** — the minimum code that solves the request; no speculative options, abstractions for one call site, or handling for cases that can't occur.
- **Surgical changes** — touch only what the request requires; no drive-by reformatting, refactors, or comment edits; clean up only orphans you created. After replacing a caller, grep the callee — on 2026-10-14 an orphan survived a commit titled for cleaning them up. After changing a behaviour, grep its old description too (code comments, test names, translator comments): on 2026-10-22 three lines still said "falls back to the glyph face" after the commit that removed that fallback. Grep the old behaviour's WORDS, not just its names: on 2026-10-31 (third miss) a grep for "in-place|Remove from Dock FIRST" left two comments saying install "removes its entry early".
- **Goal-driven** — done means verified (the `## Verification` commands in CLAUDE.md), not written; report failures verbatim.
