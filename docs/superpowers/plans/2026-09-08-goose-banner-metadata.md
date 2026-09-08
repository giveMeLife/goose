# Compact Goose Banner Metadata Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the dense banner metadata with a three-line hierarchy that highlights model and session state.

**Architecture:** `output.rs` will keep metadata text construction in a pure helper and render each semantic fragment with its specified `console` style. A small path helper will replace the home-directory prefix with `~`, while leaving paths outside the home directory absolute.

**Tech Stack:** Rust, `console`, `std::path`.

**Spec:** `docs/superpowers/specs/2026-09-08-goose-banner-metadata-design.md`

## Global Constraints

- Keep the ASCII art and its adaptive body/beak colors unchanged.
- Render three metadata lines: product/version; active provider/model/state; session ID/path.
- State uses `Color::Color256(208)`, model uses cyan, dot green, product bold body color, all supporting text dim.
- Collapse a home-relative path to `~/...`; retain an outside-home path as-is.
- Change only `crates/goose-cli/src/session/output.rs`.

---

### Task 1: Add pure compact-path and metadata content helpers

**Files:**
- Modify: `crates/goose-cli/src/session/output.rs:format_goose_banner_details`
- Test: `crates/goose-cli/src/session/output.rs` test module

**Interfaces:**
- Produces: `compact_banner_path(path: &str, home: &str) -> String`.
- Produces: `format_goose_banner_details(version, provider, model, state, session_id, cwd) -> [String; 3]` or an equivalent testable representation of exactly three lines.

- [ ] **Step 1: Add failing helper tests**

```rust
#[test]
fn compact_banner_path_replaces_home_prefix() {
    assert_eq!(
        compact_banner_path("/Users/example/projects/goose", "/Users/example"),
        "~/projects/goose"
    );
    assert_eq!(
        compact_banner_path("/tmp/goose", "/Users/example"),
        "/tmp/goose"
    );
}

#[test]
fn banner_metadata_contains_three_compact_lines() {
    let lines = format_goose_banner_details(
        "1.48.0", "huawei_maas", "glm-5.2", "new session",
        "20260908_15", "/Users/example/projects/goose",
    );

    assert_eq!(lines[0], "goose · v1.48.0");
    assert_eq!(lines[1], "● huawei_maas / glm-5.2 · new session");
    assert_eq!(lines[2], "20260908_15 · ~/projects/goose");
}
```

- [ ] **Step 2: Run tests and verify they fail**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib 'compact_banner_path_replaces_home_prefix'
```

Expected: failure because the helper does not exist or metadata still returns one string.

- [ ] **Step 3: Implement the pure helpers**

Implement `compact_banner_path` with `strip_prefix(home)`, returning `~` for an exact home match and `~{suffix}` otherwise. Get the home directory from `std::env::var("HOME")` in the presentation function; pure tests pass the home explicitly. Make `format_goose_banner_details` return exactly the strings used by the design.

- [ ] **Step 4: Run focused tests**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib 'compact_banner_path_replaces_home_prefix'
cargo test -p goose-cli --lib 'banner_metadata_contains_three_compact_lines'
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add crates/goose-cli/src/session/output.rs
git commit -m "refactor(cli): format compact goose banner metadata"
```

### Task 2: Render semantic colors and validate

**Files:**
- Modify: `crates/goose-cli/src/session/output.rs:display_goose_banner`

**Interfaces:**
- Consumes: the pure three-line metadata representation from Task 1 and `goose_banner_body_color(get_theme())`.
- Produces: colorized metadata below the unchanged ASCII art.

- [ ] **Step 1: Render the three semantic lines**

Replace the single dim metadata `println!` with three lines:

```rust
println!("  {} {} {}", style("goose").fg(body_color).bold(), style("·").dim(), style(format!("v{}", version)).dim());
println!("  {} {} {} {} {} {}", style("●").green(), style(provider).dim(), style("/").dim(), style(model).cyan(), style("·").dim(), style(state).fg(Color::Color256(208)));
println!("  {} {} {}", style(session_id).dim(), style("·").dim(), style(compact_path).dim());
```

Use the values returned by the helper rather than duplicating its text logic. Preserve the existing blank line after metadata.

- [ ] **Step 2: Run all required checks**

```bash
source bin/activate-hermit
cargo fmt --check
cargo test -p goose-cli --lib goose_banner_
cargo clippy -p goose-cli --all-targets -- -D warnings
cargo build --release -p goose-cli
```

Expected: all commands succeed.

- [ ] **Step 3: Manually verify in Ghostty**

```bash
goose session -n banner-metadata-smoke-test
```

Verify the banner shows only the selected ASCII goose followed by the three designed metadata lines; `new session` is orange, model cyan, dot green, and project path begins with `~/`.

- [ ] **Step 4: Commit and push**

```bash
git add crates/goose-cli/src/session/output.rs
git commit -m "style(cli): polish goose banner metadata"
git push origin feat/at-autocomplete
```
