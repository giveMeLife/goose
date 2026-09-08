# Colored responsive status-line design

## Goal
Make the single post-response CLI status line visually scannable, Catppuccin-friendly, and guaranteed to remain on one terminal row.

## Information and color hierarchy
The normal status line contains, in priority order:

```text
🪿 │ model │ provider │ context bar + used/limit (percentage) │ TPS │ TTFT │ cost
```

- Goose icon: terminal orange (`Color::Color256(208)`).
- Model: cyan.
- Provider: magenta/mauve (`Color::Magenta`).
- Separators: dim.
- Context bar and percentage: green below 50%, yellow from 50% through 84%, red from 85%.
- Context token text: blue.
- TPS: green.
- TTFT: green below 2 seconds, yellow from 2 seconds through 5 seconds, red above 5 seconds.
- Cost: peach/orange (`Color::Color256(216)`).

## Responsive behavior
- Obtain terminal width from `console::Term::stdout().size().1`.
- Never wrap the status line. Render only segments that fit within the available width.
- Always retain: goose icon, model, and context `used/limit (percentage)`.
- Drop optional segments from the right in this order: cost, TPS, TTFT, provider.
- If still too wide, truncate the model with an ellipsis while retaining the full context segment.
- Render no output when stdout is not a terminal or output format is JSON/stream-JSON, as the existing caller already enforces.

## Scope and verification
- Change only `crates/goose-cli/src/session/output.rs`.
- Keep the existing data collection in `CliSession::display_session_status` unchanged.
- Extract pure segment construction and width-fitting helpers for unit tests.
- Run `cargo fmt`, focused `goose-cli` tests, `cargo clippy -p goose-cli --all-targets -- -D warnings`, and `cargo build --release -p goose-cli`.
