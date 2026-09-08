# Goose banner metadata design

## Goal
Make the session metadata under the custom Goose ASCII banner compact, scannable, and visually consistent with the selected theme.

## Layout
Render these three lines below the ASCII art:

```text
  goose · v1.48.0
  ● huawei_maas / glm-5.2 · new session
  20260908_15 · ~/proyectos_personales/goose
```

- Use `~/` when the current directory is below the user's home directory; otherwise use the absolute path.
- Keep the current session ID and the existing state values (`new session`, `resuming`) intact.

## Colors and hierarchy
- `goose`: body color for the active theme, bold.
- Version, provider, separators, session ID, and path: dim/secondary.
- Model: cyan.
- Active-session dot: green.
- State: terminal orange (`Color256(208)`), matching the beak.

## Scope
- Change only `crates/goose-cli/src/session/output.rs`.
- Retain the ASCII art and its adaptive body/beak colors unchanged.
- Use pure formatting/path helpers where practical and test their output.

## Verification
- Add unit coverage for the compact path formatter and text metadata content.
- Run `cargo fmt`, focused `goose-cli` tests, `cargo clippy -p goose-cli --all-targets -- -D warnings`, and `cargo build --release -p goose-cli`.
