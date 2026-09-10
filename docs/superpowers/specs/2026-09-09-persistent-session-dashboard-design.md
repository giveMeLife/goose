# Persistent right-side session dashboard design

## Goal
Show a live, always-visible 34-column session dashboard on the right of interactive Goose CLI sessions, with a responsive fallback to the existing single-line status renderer in narrower terminals.

## Activation and fallback

- The dashboard activates only when stdout is a TTY and its width is at least 120 columns.
- It reserves 34 columns on the right, including its border; normal transcript output and the prompt must remain within the remaining width.
- On terminal resize below 120 columns, hide the dashboard and use the existing responsive bottom status line.
- When resized back to 120 columns or more, redraw the panel from current session state.

## Content and live states

The dashboard remains visible while waiting for input, while the user types, while responses stream, during tool calls, and while subagents work.

It displays:

```text
┌─ goose session ───────────────┐
│ model    glm-5.2              │
│ provider huawei_maas          │
│ ───────────────────────────── │
│ context  11k / 1.00M    1%    │
│          ━╌╌╌╌╌╌╌╌╌╌           │
│ status   working… ⠋           │
│ ttft     2.47s                │
│ tps      31.8                 │
│ cost     $0.0083              │
│ ── cost by model ──────────── │
│ glm-5.2 / huawei_maas $0.0021│
│ gpt-5.6-sol / openrouter     │
│                     $0.0062  │
└───────────────────────────────┘
```

- At response start, status becomes `working…` with a spinner.
- On first model output, display live TTFT.
- On usage events and response completion, refresh context, TPS, total cost, and the cost breakdown.
- Model/provider must reflect session-level `/model --provider ...` switches.
- The cost breakdown aggregates known costs by provider/model across the current session tree, including subagent child sessions. Every entry displays the **model followed by its provider** (for example, `glm-5.2 / huawei_maas`), so identical model names from different providers remain distinguishable. Entries sort descending by cost and show at most three; remaining entries are summarized as `+N more`.

## Rendering architecture

- Implement a dedicated terminal layout manager rather than interleaving raw cursor movement with `rustyline` and `indicatif` output.
- It owns the right-side region, tracks terminal dimensions, and redraws it using ANSI cursor save/restore plus clear-line operations.
- Existing transcript output, progress bars, and readline prompts must be wrapped through one width-aware output path when dashboard mode is enabled. The wrapped path reserves the right-side width and restores the cursor/prompt after each dashboard redraw.
- Do not use the terminal alternate screen: normal shell scrollback remains available.
- If reliable cursor positioning cannot be maintained for a given output mode, dashboard mode must be disabled and the existing bottom status line used.

## Colors

Keep the established CLI palette: orange Goose/status accent, cyan model, mauve provider, semantic green/yellow/red context and TTFT, green TPS, peach cost, and dim separators/labels.

## Scope and verification

- Likely code boundaries: `crates/goose-cli/src/session/output.rs` for dashboard state/layout/rendering and `crates/goose-cli/src/session/mod.rs`/`input.rs` for lifecycle and readline integration.
- Add pure tests for width activation, line fitting, live-state formatting, and three-entry cost breakdown ordering.
- Manually test in Ghostty at >=120 and <120 columns, while typing, streaming a response, tool calls, subagent activity, `/model --provider` switching, and window resizing.
- Run `cargo fmt`, targeted `goose-cli` tests, `cargo clippy -p goose-cli --all-targets -- -D warnings`, and `cargo build --release -p goose-cli`.
