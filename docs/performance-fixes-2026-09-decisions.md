# Performance fixes, September 2026 — decisions made without asking

Every judgement call taken while executing
[the plan](superpowers/plans/2026-09-19-performance-fixes.md) against
[the baseline](performance-baseline-2026-09.md), on branch `perf/2026-09-fixes`. The plan ran
autonomously, so this is the record of what was decided on your behalf and what it costs if a
decision was wrong. Reverse anything here.

## Decisions that shaped the work

**Worked in the main checkout, not a worktree.** This repo has a documented incident where a second
worktree's build product was resolved by Launch Services and "repaired" live helper bundles into an
older format, restarting the Dock on every launch. Every measurement step and all three live dev
helpers are bound to the main checkout's build path. The cost is that unrelated uncommitted website
edits sit beside the work; mitigated by staging only explicit paths and never `git add -A`.

**Split each task's verification by how disruptive it is.** Code, unit tests and commits ran without
interruption. Anything that restarts your Dock, seizes your pointer, or needs ten minutes of genuine
idle was deferred to a single announced batch rather than performed silently. Two reasons: a
measurement taken while you are typing is invalid anyway, and seizing the pointer without warning is
startling in a way no measurement justifies. The cost is weaker per-task attribution for those
numbers. The batch is written up in the plan's workspace as `deferred-batch-runbook.md`.

**Ran the whole-branch review before the deferred batch, not after.** The plan puts it last, but the
three remaining tasks are blocked on you being present rather than on any available work, and leaving
eight tasks of concurrency-adjacent changes unreviewed for an unknown number of days was the larger
risk. The cost is that when the batch lands and Task 6 adds code, that diff needs its own review pass.

**Ran the tile-selection re-measurement early**, since it needed neither pointer control nor a Dock
restart, only a reversible config swap.

## Decisions that fixed something the plan got wrong

**Five defects in the measurement harness were upheld and fixed** before any of it was trusted: the
production-Dock check read through a preference cache that can return stale data, a Dock re-seat was
invisible to it because the changing field was not extracted, the launch timer printed a plausible
number on timeout, the input tool posted an unchecked mouse-up after aborting, and one script lacked a
guard its siblings had. A measurement instrument that reports a plausible figure on failure poisons
every comparison downstream.

**Rejected checksumming the whole Dock plist** in favour of extracting specific fields. The Dock
rewrites that file constantly for unrelated reasons, so a whole-file checksum would have cried wolf
every run and been ignored, which is worse than the gap it closes.

**Three test guards were rewritten because they could not fail.** One asserted an exact callback count
that the first half of the scenario could satisfy on its own, so it would have passed against the
broken code it was written to catch. One compared two values that both collapsed to zero under exactly
the regression it targeted. One never exercised the branch its own documentation claimed to cover.

## Mistakes I made, and what they cost

**I prescribed a plist conversion command without running it.** It fails outright on the Dock plist,
which contains binary bookmark blobs, so the production-Dock check silently degraded to "unreadable".
Caught by running the script myself rather than trusting the report.

**I gave an implementer the wrong checksum**, conflating the digest of the whole fingerprint output
with the digest of the config file. It blocked a task at its safety gate, correctly. Same root cause
as the previous item: I handed over an exact value I had not executed myself. The rule now is that any
checksum, path, flag or command in a dispatch gets run once by me before it goes out.

**I committed a false conclusion into the baseline document.** A re-measurement looked like a
six-fold regression, so I had it written up as "regressed, not fixed". It was not a regression: the
pre-branch code measures slower still, and the older figure it was compared against is not
reproducible. The correction is its own commit rather than a quiet amendment, because the wrong claim
was committed. I had checked that the two numbers used the same tool and treated that as sufficient.
Same tool is not the same measurement.

**I claimed three test guards were fixed while listing two**, and left the most important one
untouched. A reviewer caught it. Twice in this run I described my own work in terms the artifact did
not support, and both times a reviewer rather than I caught it.

**I introduced one regression, found in re-review.** Widening a concurrency guard to cover helper
regeneration also widened its refusal onto the Dock-removal path, where the return value already meant
"nothing to remove". A hide requested during a migration would have marked a tile hidden while its
Dock entry stayed put, which is the desync this codebase has shipped before. It now reports refusal as
an error, which both callers already handle.

## Left deliberately undone

**No `MARKETING_VERSION` bump.** It is a release step, and shipping without it means no existing
user's tile receives any of this work, because a helper is a copy of the main app and regenerates only
on a version mismatch. This is the release gate.

**The icon compiler's off-main execution is unguarded.** Its other risks are prevented by the return
type and a compile-time annotation, or surface as a hang rather than a failed assertion. Writing a
test that passes either way would have repeated the mistake the finding was about. A reviewer noted
that injecting the dispatch queue would make it assertable in about two lines, which is the right move
if that code is touched again.

**The tile-selection hang is untouched.** It costs 0.8 to 1.2 seconds of blocked main thread, three to
five times past Apple's hang threshold. This branch improved it by roughly a third, and the remaining
cost is pre-existing, SwiftUI view-diffing work. The leading suspect is that the tile editor rebuilds
a whole popover panel on every selection. That is a hypothesis and needs its own spec.

**Minor items left as follow-ups:** the Dock watcher's deallocation closes its descriptor without
cancelling its dispatch source; one file logs through `print` rather than the diagnostics log; the
harness exits zero on an unreadable Dock plist, which is fine for eyeballing and wrong as a CI gate;
and one error string is absent from the string catalog exactly as its neighbour already is.

## One accepted residual risk

The Dock-watcher replace test counts asynchronous filesystem events. A late event from the first
replacement, arriving after the poll observed it, could in theory satisfy the second assertion on its
own. This is inherent to counting such events; the polling design narrows the window compared with the
fixed sleeps it replaced, and no false pass appeared across the runs. Judged not worth a more
elaborate design.
