# Colored Responsive Status Line Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render one colorized status line that fits the terminal width without wrapping.

**Architecture:** Build ordered `StatusSegment` values containing plain text, semantic color, and required/optional priority. Measure visible ASCII width, retain required icon/model/context segments, then remove optional segments from right to left until the joined line fits. Render the retained segments with `console` styles.

**Tech Stack:** Rust, `console::Term`, `console::Style`.

**Spec:** `docs/superpowers/specs/2026-09-08-colored-responsive-status-line-design.md`

## Global Constraints

- Retain icon, model, and context in every fitted line.
- Drop optional segments right-to-left: cost, TPS, TTFT, provider.
- Model truncation is the final fallback; never wrap.
- TTFT thresholds: green <3s, yellow 3–6s, red >6s.
- Limit changes to `crates/goose-cli/src/session/output.rs`.

---

### Task 1: Build and test pure responsive segment selection

**Files:**
- Modify: `crates/goose-cli/src/session/output.rs:render_session_status_line`
- Test: `crates/goose-cli/src/session/output.rs` test module

**Interfaces:**
- Produces: `status_line_text_for_width(width: usize, model: &str, provider: &str, total_tokens: usize, context_limit: usize, tps: Option<f64>, ttft: Option<f64>, cost: Option<f64>) -> Vec<StatusSegment>`.
- `StatusSegment` stores plain `text`, a semantic `StatusColor`, and `required: bool`.

- [ ] **Step 1: Write failing width-selection tests**

```rust
#[test]
fn status_line_drops_optional_segments_before_wrapping() {
    let segments = status_line_text_for_width(
        45, "openai/gpt-5.6-sol", "openrouter", 10_000, 1_000_000,
        Some(42.8), Some(0.41), Some(0.0031),
    );
    let text = join_status_segments(&segments);

    assert!(text.contains("openai/gpt-5.6-sol"));
    assert!(text.contains("10k/1.00M (1%)"));
    assert!(!text.contains("$0.0031"));
    assert!(!text.contains("42.8 tps"));
}

#[test]
fn status_line_ttft_colors_follow_thresholds() {
    assert_eq!(ttft_status_color(2.9), StatusColor::Green);
    assert_eq!(ttft_status_color(3.0), StatusColor::Yellow);
    assert_eq!(ttft_status_color(6.0), StatusColor::Yellow);
    assert_eq!(ttft_status_color(6.1), StatusColor::Red);
}
```

- [ ] **Step 2: Run tests and verify they fail**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib 'status_line_drops_optional_segments_before_wrapping'
```

Expected: compile failure because the helpers/types are undefined.

- [ ] **Step 3: Implement pure segment construction and fitting**

Use text `" │ "` between segments. Build this order: orange `🪿` (required), cyan model (required), mauve provider (optional), context (required), green TPS (optional), threshold-colored TTFT (optional), peach cost (optional). While the joined width exceeds `width.saturating_sub(2)`, remove the rightmost non-required segment. If the required line still exceeds the width, truncate the model with `…` to the remaining available width while preserving icon and context.

- [ ] **Step 4: Run focused tests**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib status_line_
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add crates/goose-cli/src/session/output.rs
git commit -m "feat(cli): fit status line to terminal width"
```

### Task 2: Render segment colors and verify

**Files:**
- Modify: `crates/goose-cli/src/session/output.rs:render_session_status_line`

**Interfaces:**
- Consumes: `status_line_text_for_width(...) -> Vec<StatusSegment>`.
- Produces: one styled `println!` within the current terminal width.

- [ ] **Step 1: Render colors using `console::Term::stdout().size().1`**

In `render_session_status_line`, obtain width with `Term::stdout().size().1 as usize`; build fitted segments; then emit `"  "`, each styled segment, and dim separators without inserting newlines until the final `println!`. Map colors: orange `Color256(208)`, cyan, magenta, blue, green, yellow, red, peach `Color256(216)`, and dim separators.

- [ ] **Step 2: Run verification**

```bash
source bin/activate-hermit
cargo fmt --check
cargo test -p goose-cli --lib status_line_
cargo clippy -p goose-cli --all-targets -- -D warnings
cargo build --release -p goose-cli
```

Expected: all succeed.

- [ ] **Step 3: Manually verify and push**

```bash
goose session -n colored-status-smoke-test
git add crates/goose-cli/src/session/output.rs
git commit -m "style(cli): colorize response status line"
git push origin feat/at-autocomplete
```

Verify the normal line has all semantic colors. Resize Ghostty below the normal line width and verify it drops cost, TPS, TTFT, then provider without wrapping.
