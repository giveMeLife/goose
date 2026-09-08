# Adaptive goose banner color design

## Goal
Render the custom ASCII goose with a body color that matches the active CLI theme and an orange beak.

## Behavior
- In `Theme::Dark`, render the body white and the `>` beak orange.
- In `Theme::Light`, render the body black and the `>` beak orange.
- In `Theme::Ansi`, render the body white and the `>` beak orange.
- Preserve the selected compact Joan Stark art exactly, including spaces and punctuation. The `jgs` signature remains omitted from terminal output; its attribution remains in the source comment.
- Determine colors at render time using the existing `output::get_theme()` API, so `/t light` and `/t dark` affect subsequent banner rendering without adding configuration.

## Implementation boundary
- Change only `crates/goose-cli/src/session/output.rs`.
- Replace whole-block styling with line-by-line rendering: print the beak line as indentation + orange `>` + body-colored remainder; print all other lines in the body color.
- Keep session metadata styling unchanged.

## Verification
- Add pure unit coverage for mapping `Theme` to the selected body color behavior if it can be expressed without terminal capture.
- Run `cargo fmt`, the relevant `goose-cli` unit tests, `cargo clippy -p goose-cli --all-targets -- -D warnings`, and `cargo build --release -p goose-cli`.
