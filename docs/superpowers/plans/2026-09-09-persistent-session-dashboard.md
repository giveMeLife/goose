# Persistent Right-Side Session Dashboard Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an always-visible 34-column live session dashboard to interactive CLI sessions, falling back safely to the existing responsive bottom status line in narrow or unsupported terminals.

**Architecture:** Introduce a focused dashboard module under `session/` that owns terminal geometry, dashboard state, ANSI save/restore redraws, and pure layout formatting. `CliSession` supplies dynamic session/provider/usage data at response lifecycle boundaries while the existing output/spinner paths delegate terminal writes through the dashboard coordinator. The dashboard is opt-in only when the TTY has at least 120 columns; all other output modes retain the current line-based CLI behavior.

**Tech Stack:** Rust, `console::{Term, measure_text_width}`, ANSI CSI cursor commands, `indicatif::MultiProgress`, `rustyline`, Goose `SessionManager` usage ledger.

**Spec:** `docs/superpowers/specs/2026-09-09-persistent-session-dashboard-design.md`

## Global Constraints

- Dashboard width is exactly 34 columns including its border.
- Activate only for stdout TTY at widths >=120; otherwise retain the responsive bottom status line.
- Dashboard remains visible during input, response streaming, tool calls, and subagent work.
- Never use the terminal alternate screen; retain ordinary scrollback.
- Cost entries must display `model / provider`, include the session tree, sort descending by cost, show at most three, then `+N more`.
- Preserve JSON and stream-JSON output exactly; dashboard is disabled there.
- If cursor positioning cannot be safely used, disable dashboard and use the existing bottom status line.

---

### Task 1: Create the pure dashboard layout and responsive activation logic

**Files:**
- Create: `crates/goose-cli/src/session/dashboard.rs`
- Modify: `crates/goose-cli/src/session/mod.rs:module declarations`
- Test: `crates/goose-cli/src/session/dashboard.rs` test module

**Interfaces:**
- Produces: `pub const DASHBOARD_WIDTH: usize = 34`.
- Produces: `pub fn dashboard_enabled(is_tty: bool, terminal_width: usize) -> bool`.
- Produces: `DashboardSnapshot` with `model`, `provider`, `context_tokens`, `context_limit`, `status`, optional `ttft_secs`, optional `tps`, optional `cost`, and `cost_breakdown`.
- Produces: `pub fn format_dashboard_lines(snapshot: &DashboardSnapshot) -> Vec<String>`; every line is visible-width <=34.

- [ ] **Step 1: Write failing activation and layout tests**

```rust
#[test]
fn dashboard_requires_tty_and_120_columns() {
    assert!(!dashboard_enabled(false, 200));
    assert!(!dashboard_enabled(true, 119));
    assert!(dashboard_enabled(true, 120));
}

#[test]
fn dashboard_lines_are_exactly_bounded_by_panel_width() {
    let snapshot = DashboardSnapshot::working(
        "openai/gpt-5.6-sol",
        "openrouter",
        10_000,
        1_000_000,
    );
    let lines = format_dashboard_lines(&snapshot);

    assert_eq!(lines.first().unwrap(), "┌─ goose session ───────────────┐");
    assert_eq!(lines.last().unwrap(), "└───────────────────────────────┘");
    assert!(lines.iter().all(|line| measure_text_width(line) <= DASHBOARD_WIDTH));
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib dashboard_requires_tty_and_120_columns
```

Expected: compile failure because module/types/functions do not exist.

- [ ] **Step 3: Implement `dashboard.rs` as a pure layout module**

1. Define the 34-column constants and `dashboard_enabled` as `is_tty && terminal_width >= 120`.
2. Define `DashboardStatus::{Waiting, Working, Streaming, Complete}` and `DashboardSnapshot` with constructor helpers.
3. Build a fixed border and bounded inner rows. Use existing status token formatting semantics: active tokens/context limit/percentage; semantic text without ANSI styling in the pure layout function.
4. Use `measure_text_width` and a `fit_cell(value, width)` helper that ellipsizes text without splitting UTF-8.
5. Include fixed rows for model, provider, context, meter, status, TTFT, TPS, cost, and cost breakdown; omit unavailable metric values rather than displaying fabricated values.

- [ ] **Step 4: Run focused tests**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib dashboard_
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add crates/goose-cli/src/session/dashboard.rs crates/goose-cli/src/session/mod.rs
git commit -m "feat(cli): add session dashboard layout"
```

### Task 2: Aggregate session-tree costs by model and provider

**Files:**
- Modify: `crates/goose/src/session/session_manager.rs`
- Modify: `crates/goose/src/session/mod.rs` or existing public session types as needed
- Test: `crates/goose/src/session/session_manager.rs` test module

**Interfaces:**
- Produces: public `ModelProviderCost { model: String, provider: String, cost: f64 }`.
- Produces: `SessionManager::get_session_cost_breakdown(&self, session_id: &str) -> Result<Vec<ModelProviderCost>>`.
- Consumed by: CLI dashboard snapshot loader.

- [ ] **Step 1: Write a failing storage test**

Create a parent session and child session, record ledger entries with model/provider data, then assert:

```rust
let rows = manager.get_session_cost_breakdown(&parent_id).await?;
assert_eq!(
    rows,
    vec![
        ModelProviderCost { model: "gpt-5.6-sol".into(), provider: "openrouter".into(), cost: 0.0062 },
        ModelProviderCost { model: "glm-5.2".into(), provider: "huawei_maas".into(), cost: 0.0021 },
    ]
);
```

The expected order is cost descending and includes the child session.

- [ ] **Step 2: Run it and verify it fails**

```bash
source bin/activate-hermit
cargo test -p goose get_session_cost_breakdown --lib
```

Expected: compile failure because the method/type does not exist.

- [ ] **Step 3: Implement recursive aggregation**

1. Reuse the existing `WITH RECURSIVE tree(id)` session-tree query pattern from `get_session_usage_totals`.
2. Query `usage_ledger` rows joined to their sessions. Use the ledger model field and session provider name, grouping by both model and provider.
3. Sum non-null costs, exclude unknown/no-cost rows, return descending cost order.
4. Do not infer cost from token counts; only report known ledger costs.

- [ ] **Step 4: Run focused session-manager tests**

```bash
source bin/activate-hermit
cargo test -p goose get_session_cost_breakdown --lib
```

Expected: PASS.

- [ ] **Step 5: Commit Task 2**

```bash
git add crates/goose/src/session/session_manager.rs crates/goose/src/session/mod.rs
git commit -m "feat(session): aggregate costs by model and provider"
```

### Task 3: Implement the terminal dashboard manager

**Files:**
- Modify: `crates/goose-cli/src/session/dashboard.rs`
- Test: `crates/goose-cli/src/session/dashboard.rs` test module

**Interfaces:**
- Produces: `pub struct SessionDashboard` with `new`, `is_active`, `refresh`, `clear`, and `handle_resize` methods.
- Consumes: `DashboardSnapshot` and `console::Term::stdout().size()`.
- Guarantees: all dashboard cursor operations save and restore the user/transcript cursor position.

- [ ] **Step 1: Add failing state-transition tests**

```rust
#[test]
fn resize_switches_between_dashboard_and_fallback() {
    let mut dashboard = SessionDashboard::for_test(true, 140);
    assert!(dashboard.is_active());

    dashboard.handle_resize_for_test(119);
    assert!(!dashboard.is_active());

    dashboard.handle_resize_for_test(120);
    assert!(dashboard.is_active());
}

#[test]
fn cost_breakdown_keeps_three_highest_entries_then_summary() {
    let lines = format_cost_breakdown(&[
        cost("a", "p", 4.0), cost("b", "p", 3.0), cost("c", "p", 2.0), cost("d", "p", 1.0),
    ]);
    assert!(lines.iter().any(|line| line.contains("a / p")));
    assert!(lines.iter().any(|line| line.contains("c / p")));
    assert!(lines.iter().any(|line| line.contains("+1 more")));
}
```

- [ ] **Step 2: Run tests to verify failure**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib resize_switches_between_dashboard_and_fallback
```

Expected: failure because `SessionDashboard` state helpers are absent.

- [ ] **Step 3: Implement controlled ANSI redraws**

1. Store activation state, terminal width/height, last rendered panel height, and last `DashboardSnapshot`.
2. On `refresh`, re-read dimensions. If disabled, clear the previously reserved right-side panel and return inactive.
3. For active rendering, save cursor (`ESC 7`), move to each row's right-panel column (`ESC[{row};{col}H`), clear to end of line, print that dashboard line, then restore cursor (`ESC 8`) and flush stdout.
4. Use screen-relative bottom anchoring (`terminal_height - panel_height + 1`) so it remains visually at the bottom while normal scrollback continues.
5. `clear` must erase every previously rendered dashboard row, restore cursor, and flush.
6. Keep ANSI rendering isolated in this manager; formatters must not emit ANSI controls.

- [ ] **Step 4: Run focused tests**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib 'resize_switches_between_dashboard_and_fallback|cost_breakdown_keeps_three_highest_entries_then_summary'
```

Expected: PASS.

- [ ] **Step 5: Commit Task 3**

```bash
git add crates/goose-cli/src/session/dashboard.rs
git commit -m "feat(cli): render persistent session dashboard"
```

### Task 4: Integrate dashboard lifecycle, response telemetry, and fallback output

**Files:**
- Modify: `crates/goose-cli/src/session/mod.rs:CliSession, interactive, run_interactive, process_agent_response, display_session_status`
- Modify: `crates/goose-cli/src/session/output.rs:render_session_status_line` only if fallback API must accept dashboard state
- Modify: `crates/goose-cli/src/session/input.rs` only if editor redraw hooks are required
- Test: `crates/goose-cli/src/session/mod.rs` test module

**Interfaces:**
- Consumes: `SessionDashboard`, current session metadata, current provider/model config, provider usage, `get_session_cost_breakdown`.
- Produces: continuously refreshed dashboard for supported interactive terminal sessions; existing bottom status line otherwise.

- [ ] **Step 1: Add a failing lifecycle-state test**

Extract a pure `dashboard_snapshot_for_phase` helper and test:

```rust
#[test]
fn dashboard_snapshot_transitions_from_working_to_complete() {
    let working = dashboard_snapshot_for_phase(/* status=Working, no usage */);
    assert_eq!(working.status, DashboardStatus::Working);
    assert!(working.ttft_secs.is_none());

    let complete = dashboard_snapshot_for_phase(/* status=Complete, usage */);
    assert_eq!(complete.status, DashboardStatus::Complete);
    assert_eq!(complete.ttft_secs, Some(2.47));
    assert_eq!(complete.tps, Some(31.8));
}
```

- [ ] **Step 2: Run it and verify it fails**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib dashboard_snapshot_transitions_from_working_to_complete
```

Expected: failure because lifecycle integration/helper is absent.

- [ ] **Step 3: Wire dashboard into the interactive lifecycle**

1. Create `SessionDashboard` at interactive-session entry only for text TTY mode and render an initial `Waiting` snapshot before first `readline` call.
2. Refresh it before calling `input::get_input`, after each completed response, and after `/model` succeeds.
3. At `process_agent_response` start, set `Working`; on first text or tool-request output, set `Streaming` and live TTFT; on `AgentEvent::Usage`, update available usage metrics; after stream completion, set `Complete` with current context/total cost/cost breakdown.
4. Reuse the existing current-session provider lookup so `/model --provider` changes are immediately visible.
5. Load the cost breakdown asynchronously after usage updates. If it fails, preserve the rest of the dashboard and show no breakdown rows.
6. When `SessionDashboard::is_active()` is true, do not call `render_session_status_line`; when false, retain it unchanged.
7. Clear the dashboard before printing the session-closed message.

- [ ] **Step 4: Coordinate prompt/spinner redraws**

1. Ensure dashboard redraws only use save/restore cursor operations and never write into the left transcript region.
2. Before any prompt read, call dashboard refresh; after any known normal `println!` branch that can move the cursor during interactive mode, refresh dashboard at the next safe event boundary.
3. Keep `McpSpinners` as transcript output; do not put them inside the dashboard. Dashboard refreshes occur after their update calls, so the right panel is repainted if needed.
4. If `rustyline` redraw collision is observed in manual validation, disable dashboard while `get_input` owns the terminal and immediately restore it after input returns; retain bottom status fallback only if this cannot produce a stable panel.

- [ ] **Step 5: Run focused CLI tests**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib dashboard_
cargo test -p goose-cli --lib status_provider_prefers_current_session_provider
cargo test -p goose-cli --lib session::completion
```

Expected: PASS.

- [ ] **Step 6: Commit Task 4**

```bash
git add crates/goose-cli/src/session/mod.rs crates/goose-cli/src/session/output.rs crates/goose-cli/src/session/input.rs
 git commit -m "feat(cli): update persistent dashboard during session work"
```

### Task 5: End-to-end validation and publish the customized fork

**Files:**
- Modify: no expected source changes

**Interfaces:**
- Consumes: Tasks 1–4.
- Produces: a release binary at `target/release/goose` and published fork `main`.

- [ ] **Step 1: Run required quality checks**

```bash
source bin/activate-hermit
cargo fmt --check
cargo test -p goose-cli --lib dashboard_
cargo test -p goose --lib get_session_cost_breakdown
cargo clippy --all-targets -- -D warnings
cargo build --release -p goose-cli
```

Expected: all commands exit 0.

- [ ] **Step 2: Manually validate Ghostty dashboard mode**

```bash
goose session -n dashboard-smoke-test
```

At >=120 columns confirm the 34-column right panel remains visible while waiting, typing, streaming, tools, and subagents; check `working…`, TTFT, TPS, context, and cost refresh. Switch provider/model using `/model --provider openrouter <model>` and verify model/provider update. Run a subagent and verify cost breakdown includes `model / provider` rows. Resize to <120 and confirm only the bottom responsive status line is used; resize back and confirm panel returns.

- [ ] **Step 3: Commit remaining changes and push `main`**

```bash
git status --short
git push origin main
```

Expected: implementation available at `https://github.com/giveMeLife/goose`.
