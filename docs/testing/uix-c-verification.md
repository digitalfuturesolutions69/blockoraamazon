# UIX-C automated verification — 2026-10-12

## Repository and scope

Repository: digitalfuturesolutions69/blockora; branch: work. Local and remote HEAD: `ce789c8b62c1bd535e3667348c38bce1ba368615` (equal). Baseline was clean. No staging, commit, push, signing change, domain-rule change, Daily/Retention development or UIX-D/E implementation. Final working tree intentionally contains 5 modified and 12 new files, listed below. Controller changes add only confirmed-placement presentation metadata. Existing core save schemas, package configuration and Fair Play contracts remain unchanged.

## Automated results

All commands source `/workspace/toolchains/blockora-env.sh`. Baseline `bash tools/test.sh` passed before implementation. Final runs:

| Runner | Assertions/checks | Failures | Exit |
|---|---:|---:|---:|
| Foundation | 35 | 0 | 0 |
| Classic unit | 6,623 | 0 | 0 |
| Fair Play unit | 27,578 | 0 | 0 |
| Touchscreen | 89 | 0 | 0 |
| Lifecycle | 8 | 0 | 0 |
| Audio instrumentation | 187 | 0 | 0 |
| Responsive/safe-area | 4,682 | 0 | 0 |
| Drag/continuity | 564 | 0 | 0 |
| Crystal Pop visual integration | 3,271 | 0 | 0 |
| Classic smoke simulation | 25,990 | 0 | 0 |
| Fair Play smoke simulation | 19,468 | 0 | 0 |
| Relax unit | 2,175 | 0 | 0 |
| Relax input/navigation | 1,039 | 0 | 0 |
| Relax 10,000-session simulation | 5,472,836 | 0 | 0 |
| Relax process persistence | 4 | 0 | 0 |
| Classic 10,000-session simulation | 2,357,854 | 0 | 0 |
| Fair Play 10,000-session simulation | 1,972,676 | 0 | 0 |
| Randomized Fair Play 1,000-session simulation | 113,678 | 0 | 0 |
| **Total final checks** | **10,008,757** | **0** | **0** |

Primary commands: `bash tools/test.sh`, `bash tools/test_relax.sh`, `bash tools/test_extended.sh`. Evidence logs: `/tmp/blockora-uix-c-final-ui.txt`, `/tmp/blockora-uix-c-final-relax.txt`, `/tmp/blockora-uix-c-final-extended.txt`, each with corresponding `.exit` containing 0. No SCRIPT ERROR, parse error, unexpected ERROR, crash or leaked-object warning in final test logs. Persistence fault injection deliberately kills one child process; its parent verifier passes. Earlier repetitions are excluded from totals. During development an incorrectly typed malformed-color test fixture was corrected to an untyped array matching real JSON decoding; its initial failures are not counted as PASS.

Visual tests exercise cached pixel gradients/rounded alpha/contrast, 24 shape colors, persistent cell colors, corrupt visual records, storage failure, Classic/Relax isolation, real application clears of 1/2/3 lines and simultaneous row+column, event deduplication, input-transparent stable overlay ownership, 1,000 bounded effect cycles, reduced-motion persistence and cleanup. Responsive tests cover 8 configurations and 1,024 injected placements; drag tests cover 20,000 same-cell motions and 40 rapid placements. Existing strict malformed game-save handling remains protected. Valid Classic/Relax sessions and deterministic continuation pass; visual records cannot overwrite game or audio records.

## Simulations and fairness

Relax seeds 0..9999: 10,000 completed sessions, 860,313 moves, 290,958 fresh trays, zero fairness violations, 527 existing-generator repairs, zero sampler fallbacks. Deterministic replay and save/resume continuation pass. Score min/median/p95/max: 45/418/949/2557, mean 466.9988. Session moves min/median/p95/max: 16/77/167/440, mean 86.0313.

Extended Classic: 10,000 sessions, 260,575 moves. Extended Fair Play: 10,000 sessions, 262,968 moves, 91,900 eligible trays, zero violations, 627 repairs, zero fallbacks, 10,000 successful replays. Randomized Fair Play: 1,000 sessions, 14,897 moves, 5,399 eligible trays, zero violations, 48 repairs, zero fallbacks, 1,000 successful replays. No gameplay RNG was consumed by visual effects.

## Performance observations

Cloud CPU/filesystem measurements, not Android FPS: five-tile cold generation 18,165 µs; 1,000 warm renderer constructions mean 1.726 µs, p95 2 µs. Five cached tiles remain bounded at 81,920 raw pixel bytes; image and GPU overhead are additional. Effect stress retains bounded resources and no per-particle nodes. Rendering uses cached textures; no texture generation or blocking asset load during drag.

Relax simulation: 211,015 ms, maximum generation 9,365 µs. Dedicated generation p95/max 522/3,193 µs; load 915/2,125 µs; save 243/48,248 µs (filesystem tail spike). 1,000 mode switches including four scene frames each: p95 27,633 µs, max 31,089 µs. Memory samples stabilize from 34,874,653 to 35,632,709 bytes. These are CPU and harness observations; GPU draw-call cost, native frame pacing and Android touch latency remain unmeasured.

## Local Android build

Exactly one final `bash tools/build_android.sh` run, exit 0. Debug APK package/SDK/permission/signature verifier and unsigned test AAB bundletool/SDK/portrait/permission/plugin verifier pass. Target SDK 36 and existing Android configuration unchanged. No artifacts uploaded or transferred.

| Output | Bytes | SHA-256 |
|---|---:|---|
| `builds/blockora-debug.apk` | 84,985,458 | `825a5e4cc9f2219730797d52c27aba1fd7b9fd03256300007e4f5ac2f496c449` |
| `builds/blockora-test.aab` | 32,534,288 | `506eb53aaf24cf9581f6694bc551639b138105b6a7448572f5b1ccd0906ae0e8` |

Build log `/tmp/blockora-uix-c-android.txt`, exit `/tmp/blockora-uix-c-android.exit`. ADB daemon connection was unavailable; no installation or physical-device validation was performed. Builds/caches remain ignored and excluded from the proposed source changes. No hosted CI was triggered.

## Manifest and hygiene

First five paths are modified tracked files; remaining twelve are new, including five legitimate Godot UID files.

- `scripts/application/classic_controller.gd`
- `scripts/application/relax_controller.gd`
- `scripts/presentation/classic_app.gd`
- `scripts/presentation/puzzle_surface.gd`
- `tools/test.sh`
- `scripts/infrastructure/visual_state_store.gd`
- `scripts/infrastructure/visual_state_store.gd.uid`
- `scripts/presentation/clear_feedback.gd`
- `scripts/presentation/clear_feedback.gd.uid`
- `scripts/presentation/crystal_block_renderer.gd`
- `scripts/presentation/crystal_block_renderer.gd.uid`
- `scripts/presentation/crystal_palette.gd`
- `scripts/presentation/crystal_palette.gd.uid`
- `tests/integration/run_visual_tests.gd`
- `tests/integration/run_visual_tests.gd.uid`
- `docs/design/crystal-pop.md`
- `docs/testing/uix-c-verification.md`


Final `git diff --check` passes; the limited credential/signing-file scan passes across 236 Git candidate files. The scanner detects common private-key/token patterns and forbidden signing files, not every possible credential format. No APK/AAB/cache/import artifact is included. No files are staged.

## Deferred UIX-F device acceptance and risks

DEVICE VALIDATION DEFERRED TO UIX-F. Check real Android board/tray readability and proportions, rounded highlights and persistent multicolor after restart, large fonts and system insets, ghost continuity at different finger positions, real multitouch/release, one clear effect and SFX per transaction, rapid placements, reduced motion, pause/background/resume, low-end frame pacing, audio synchronization/crackle/volume and battery/thermal behavior. Do not label physical drag smoothness, audio quality or Android FPS PASS from these headless results. AdMob runtime and Play Billing transactions were not tested.

Legacy game saves lack original piece-color history and therefore use documented deterministic fallback. Separate game/visual writes can lose exact colors across a crash window or visual I/O failure; valid gameplay remains loadable. Real GPU performance and final Android visual acceptance remain outstanding. Owner review is required before commit, push or UIX-D; this gate stops here.
