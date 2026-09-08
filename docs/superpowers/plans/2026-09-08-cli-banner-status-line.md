# Unified CLI Banner and Status Line Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Goose's duplicate startup and context displays with one custom startup banner and one accurate post-response status line.

**Architecture:** The session builder will no longer render the stock `display_session_info` banner. `CliSession` will retain immutable startup metadata and pass it to the custom ASCII banner at interactive-session entry. The existing post-response hook will render a single best-effort status line sourced from `SessionMetadata.usage.total_tokens`, matching the legacy bar's active-context source.

**Tech Stack:** Rust, `rustyline`, `indicatif`, `console`, Goose session metadata and provider usage types.

**Spec:** `docs/superpowers/specs/2026-09-08-cli-banner-status-design.md`

## Global Constraints

- Preserve `SessionStart` hook emission but do not render its banner payload.
- Do not render the custom status line in JSON, stream-JSON, or non-terminal output modes.
- Use `SessionMetadata.usage.total_tokens` for active-context display; never substitute `accumulated_usage.total_tokens`.
- TTFT must include responses that begin with a tool request.
- TPS/cost are optional and must be omitted if provider data is unavailable.

---

### Task 1: Keep startup metadata and render only the custom banner

**Files:**
- Modify: `crates/goose-cli/src/session/mod.rs:CliSession, CliSession::interactive`
- Modify: `crates/goose-cli/src/session/builder.rs:build_session`
- Modify: `crates/goose-cli/src/session/output.rs:display_goose_banner`
- Test: `crates/goose-cli/src/session/output.rs` unit-test module

**Interfaces:**
- Consumes: builder values `effective_provider_name`, `effective_model_name`, `session_id`, `session_config.resume`.
- Produces: `output::display_goose_banner(version/model/provider/session state/id/cwd)` that is the only startup banner renderer.

- [ ] **Step 1: Write a failing pure rendering test**

Add a pure helper such as `format_goose_banner_details(...) -> String` and assert it includes the provider, model, session state, ID, and directory:

```rust
#[test]
fn goose_banner_details_include_session_metadata() {
    let details = format_goose_banner_details(
        "1.48.0",
        "openrouter",
        "openai/gpt-5.6-sol",
        "new session",
        "20260908_9",
        "/Users/example/project",
    );

    assert!(details.contains("openrouter"));
    assert!(details.contains("openai/gpt-5.6-sol"));
    assert!(details.contains("new session"));
    assert!(details.contains("20260908_9"));
    assert!(details.contains("/Users/example/project"));
}
```

- [ ] **Step 2: Run the new test to verify it fails**

Run:

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib goose_banner_details_include_session_metadata
```

Expected: compilation failure because `format_goose_banner_details` does not exist.

- [ ] **Step 3: Add startup metadata to `CliSession` and the custom renderer**

1. Add a small `SessionDisplayInfo` struct to `session/mod.rs` containing `provider`, `model`, `session_id`, `resume`, and `cwd`.
2. Pass that struct from `build_session` into `CliSession::new`; update all constructor tests/callers with deterministic values.
3. Change `display_goose_banner` to accept the display info (or explicit fields), use the pure formatter, and print the jgs art plus two metadata lines.
4. In `CliSession::interactive`, call only `display_goose_banner`; retain `emit_hook_with_banners(...)` but bind its return to `_banners` and do not call any stock banner renderer.
5. Remove the `output::display_session_info(...)` call from `build_session`. Delete `display_session_info` and `display_banner` if no call sites remain.

Expected rendered structure:

```text
       \_\_
     >(' )
       )/
      /(
     /  \`----/
jgs  \\  ~=- /
   ~^~^~^~^~^~^~^

  🪿 goose v1.48.0 │ new session │ openrouter │ openai/gpt-5.6-sol
     20260908_9 │ /Users/example/project
```

- [ ] **Step 4: Run focused tests**

Run:

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib goose_banner_details_include_session_metadata
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add crates/goose-cli/src/session/mod.rs crates/goose-cli/src/session/builder.rs crates/goose-cli/src/session/output.rs
git commit -m "feat(cli): replace stock startup display with custom goose banner"
```

### Task 2: Make the unified status line use active context and per-turn telemetry

**Files:**
- Modify: `crates/goose-cli/src/session/mod.rs:run_interactive, process_agent_response, display_session_status`
- Modify: `crates/goose-cli/src/session/output.rs:render_session_status_line`
- Test: `crates/goose-cli/src/session/output.rs` unit-test module

**Interfaces:**
- Consumes: `SessionMetadata.usage.total_tokens`, resolved context limit, current model/provider, optional `ProviderUsage`, `run_started`, and `first_token_at`.
- Produces: `render_session_status_line(model, provider, total_tokens, context_limit, tokens_per_second, ttft_secs, session_cost)`.

- [ ] **Step 1: Write failing pure tests for formatting and active-context behavior**

Extract a pure formatter such as `format_session_status_line(...) -> String`. Add tests:

```rust
#[test]
fn status_line_shows_active_context_model_and_provider() {
    let line = format_session_status_line(
        "openai/gpt-5.6-sol",
        "openrouter",
        10_000,
        1_000_000,
        Some(42.8),
        Some(0.41),
        Some(0.0031),
    );

    assert!(line.contains("openai/gpt-5.6-sol"));
    assert!(line.contains("openrouter"));
    assert!(line.contains("10k/1.00M (1%)"));
    assert!(line.contains("42.8 tps"));
    assert!(line.contains("ttft 0.41s"));
    assert!(line.contains("$0.0031 sesión"));
}

#[test]
fn status_line_omits_unavailable_turn_metrics() {
    let line = format_session_status_line("model", "provider", 0, 128_000, None, None, None);

    assert!(!line.contains("tps"));
    assert!(!line.contains("ttft"));
    assert!(!line.contains("sesión"));
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run:

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib status_line_
```

Expected: compilation failure because the pure formatter does not exist.

- [ ] **Step 3: Implement the single status line**

1. Remove `self.display_context_usage().await?` from the interactive input loop. This removes the old context bar.
2. In `display_session_status`, read exactly:

```rust
let total_tokens = self
    .get_session()
    .await
    .ok()
    .and_then(|metadata| metadata.usage.total_tokens)
    .unwrap_or(0) as usize;
```

Do not fall back to `metadata.accumulated_usage.total_tokens`.
3. Resolve provider from the active session/provider configuration, not an unrelated global value when a session-level override exists.
4. Derive TPS from optional output tokens and provider `elapsed_ms`, falling back to local response elapsed time only when output tokens are supplied.
5. Derive TTFT from provider stats when present, otherwise from `first_token_at`; this timestamp must already be set on text **or** `MessageContent::ToolRequest`.
6. Have `render_session_status_line` use the pure formatter and then color only the bar. It must display model, provider, active tokens/context limit/percentage, optional TPS, optional TTFT, optional total cost.
7. Keep the early returns for JSON/stream-JSON and non-terminal output.

- [ ] **Step 4: Run focused tests**

Run:

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib status_line_
cargo test -p goose-cli --lib session::input::tests
cargo test -p goose-cli --lib session::completion
```

Expected: all pass.

- [ ] **Step 5: Commit Task 2**

```bash
git add crates/goose-cli/src/session/mod.rs crates/goose-cli/src/session/output.rs
git commit -m "feat(cli): show one accurate response status line"
```

### Task 3: Validate the complete terminal experience and publish it

**Files:**
- Modify: no expected source changes

**Interfaces:**
- Consumes: Tasks 1 and 2.
- Produces: a release binary at `target/release/goose` and an updated `origin/feat/at-autocomplete` branch.

- [ ] **Step 1: Format and lint**

Run:

```bash
source bin/activate-hermit
cargo fmt --check
cargo clippy -p goose-cli --all-targets -- -D warnings
```

Expected: both exit with code 0.

- [ ] **Step 2: Build the release binary**

Run:

```bash
source bin/activate-hermit
cargo build --release -p goose-cli
```

Expected: successful build. `~/.local/bin/goose` remains a symlink to this output.

- [ ] **Step 3: Perform manual terminal verification**

Run:

```bash
goose session -n banner-status-smoke-test
```

Verify visually:

1. Only the large cyan jgs ASCII goose appears at startup; no small `__( O)>` stock goose and no separate hook banner appears.
2. Its metadata contains session state, provider, model, session ID, and current directory.
3. After a response, exactly one status line appears; the legacy standalone context bar is absent.
4. The status line token count and percentage agree with the session's active `usage.total_tokens`, and includes TPS/TTFT when the provider reports usage.

- [ ] **Step 4: Push commits to the fork**

Run:

```bash
git push origin feat/at-autocomplete
```

Expected: branch published at `https://github.com/giveMeLife/goose/tree/feat/at-autocomplete`.
