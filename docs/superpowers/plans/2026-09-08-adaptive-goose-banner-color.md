# Adaptive Goose Banner Color Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the compact ASCII goose white in dark/ANSI themes, black in light theme, and its beak orange in every theme.

**Architecture:** Keep the banner source art unchanged. In `output.rs`, select a body `console::Color` from the existing thread-local `Theme`, then print the beak line in three literal pieces: body-colored indentation, orange `>`, and body-colored remainder. All remaining art lines are printed using the body color.

**Tech Stack:** Rust, `console`, existing `Theme` and `get_theme()` APIs.

**Spec:** `docs/superpowers/specs/2026-09-08-adaptive-goose-banner-color-design.md`

## Global Constraints

- `Theme::Dark` and `Theme::Ansi` use a white body; `Theme::Light` uses a black body.
- The `>` character in the selected compact art is orange in every theme.
- Preserve spaces and all ASCII punctuation in the selected art exactly.
- Change only `crates/goose-cli/src/session/output.rs`.

---

### Task 1: Add adaptive banner rendering

**Files:**
- Modify: `crates/goose-cli/src/session/output.rs:Theme, display_goose_banner`
- Test: `crates/goose-cli/src/session/output.rs` test module

**Interfaces:**
- Consumes: `get_theme() -> Theme` and the `GOOSE_ASCII` constant.
- Produces: `goose_banner_body_color(theme: Theme) -> console::Color` and a `display_goose_banner(...)` which renders a body in the selected color and `>` in orange.

- [ ] **Step 1: Write the failing mapping test**

Add this test to the existing `output.rs` test module:

```rust
#[test]
fn goose_banner_body_color_matches_cli_theme() {
    assert_eq!(goose_banner_body_color(Theme::Dark), console::Color::White);
    assert_eq!(goose_banner_body_color(Theme::Light), console::Color::Black);
    assert_eq!(goose_banner_body_color(Theme::Ansi), console::Color::White);
}
```

- [ ] **Step 2: Run it and verify it fails**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib goose_banner_body_color_matches_cli_theme
```

Expected: compilation failure because `goose_banner_body_color` is undefined.

- [ ] **Step 3: Implement the mapping and segment the beak line**

Add the pure mapping:

```rust
fn goose_banner_body_color(theme: Theme) -> console::Color {
    match theme {
        Theme::Light => console::Color::Black,
        Theme::Dark | Theme::Ansi => console::Color::White,
    }
}
```

In `display_goose_banner`, obtain `let body_color = goose_banner_body_color(get_theme());`. Iterate through `GOOSE_ASCII.lines()` and specially render exactly the line beginning with four spaces then `>`, using:

```rust
print!("{}", style("    ").color(body_color));
print!("{}", style(">").color(console::Color::Color256(208)));
println!("{}", style("(' )").color(body_color));
```

Print every other literal line with `println!("{}", style(line).color(body_color));`. Keep the blank leading line if the raw string carries one, so current vertical spacing is unchanged.

- [ ] **Step 4: Run focused test**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib goose_banner_body_color_matches_cli_theme
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add crates/goose-cli/src/session/output.rs
git commit -m "style(cli): adapt goose banner colors to theme"
```

### Task 2: Verify and publish

**Files:**
- Modify: no expected source changes

**Interfaces:**
- Consumes: Task 1.
- Produces: release binary with adaptive banner rendering and an updated fork branch.

- [ ] **Step 1: Run required checks**

```bash
source bin/activate-hermit
cargo fmt --check
cargo test -p goose-cli --lib goose_banner_
cargo clippy -p goose-cli --all-targets -- -D warnings
cargo build --release -p goose-cli
```

Expected: every command succeeds.

- [ ] **Step 2: Manual terminal check**

```bash
goose session -n adaptive-banner-smoke-test
```

Verify the body is white with an orange `>` in the current dark theme. Then start a light-theme session (or select `/t light` before starting a new session) and verify the body is black with the same orange `>`.

- [ ] **Step 3: Push the fork branch**

```bash
git push origin feat/at-autocomplete
```

Expected: the commit appears at `https://github.com/giveMeLife/goose/tree/feat/at-autocomplete`.
