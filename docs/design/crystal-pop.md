# Crystal Pop — UIX-C design

Implemented on `work`, baseline `ce789c8b62c1bd535e3667348c38bce1ba368615`. This gate contains one visual treatment, not the UIX-E theme selector.

## Rendering and palette

Original, procedurally generated Blockora graphics; no third-party visual assets or asset downloads. Five shared 64×64 RGBA tiles use 14% rounded corners, a light-to-dark gradient, top highlight, subtle inner border, and soft shadow. Mint, amber, ocean blue, berry and cyan retain stable existing piece render keys. Background #101c38, panels #1a2b49, board #233655, empty cells #283b5b, white text and #a9bad7 secondary text provide separation. Valid/invalid placement also retains check/cross marks; color and audio supplement visual information.

Five textures are generated once, before gameplay, and shared across board, tray, ghost, preview and clear flash. Cell spacing uses one geometry helper. No custom shader, external texture resource, per-particle node or per-frame texture creation is used. Raw cached pixel storage is 81,920 bytes, excluding image copies and graphics-driver overhead.

## Stable colors and save isolation

Piece colors come from existing render keys, never gameplay RNG. Confirmed placement events include the accepted origin; domain placement, scoring and fairness remain unchanged. Separate `crystal_cells_classic_v1` and `crystal_cells_relax_v1` records store a game-snapshot fingerprint and 64 cell colors. Clearing removes the unique row/column union, including intersections once. Duplicate confirmed events do not replay effects or write colors again.

Core Classic/Relax saves and schemas remain unchanged. Exact colors survive ordinary save/resume. Legacy saves do not contain piece-history colors: deterministic coordinate-based colors are used for occupied cells. Missing, corrupt, incompatible or stale visual records receive the same fallback without rewriting valid game data. Game and visual records are separate writes: interruption between writes or visual-storage failure can cause fallback colors on resume, without changing the valid game state.

## Layout and feedback

The board and fixed-height compact tray form a vertically centered group; unused height no longer stretches the tray. Tray cell scale is capped at 32 pixels. Pause is compact, with its established touch target retained. Existing fullscreen, safe-area and responsive conversion remain intact.

A stable, input-transparent overlay receives confirmed clear events. One/two/three-plus lines use 8/12/16 bounded analytic sparkles and a 200/220 ms flash; double and multi clears show DOUBLE CLEAR / AMAZING captions. Row-plus-column clears count both, but intersecting cells flash once. At most one effect group runs. A later accepted placement, pause, navigation, restart, backgrounding or layout interruption cancels stale feedback. Layout changes relocate active feedback to current board geometry. Audio continues through the existing manager.

Reduce Motion is independently persisted: a short static fade replaces particles, pickup scaling is disabled, and invalid returns are immediate. The existing drag pipeline retains its fixed gesture offset, latest-pointer rendering once per frame, direct current-pointer release and synthetic/multitouch protection.

## Acceptance limits

Headless event, pixel, geometry and lifecycle validation is recorded in `docs/testing/uix-c-verification.md`. Android GPU frame timing, actual screen composition, system insets, large-font readability, touch comfort and audible quality remain deferred to owner device validation at UIX-F.
