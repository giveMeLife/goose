# Dynamic Status Provider and Fork Installation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Update the status line after a `/model --provider` switch and document installation of this fork's `main` as `goose`.

**Architecture:** Status rendering will resolve its provider from fresh session metadata, falling back to immutable startup display metadata when absent. README will add a fork-specific source-build block after the official CLI installer without modifying official install instructions.

**Tech Stack:** Rust, Goose `SessionMetadata`, Markdown.

**Spec:** `docs/superpowers/specs/2026-09-09-dynamic-status-provider-install-design.md`

## Global Constraints

- Startup banner retains initial provider metadata.
- Status line reads current `SessionMetadata.provider_name`, with fallback to the startup provider.
- README targets the fork's `main` and installs `goose` through `~/.local/bin/goose` symlink.

---

### Task 1: Resolve the status provider from current session metadata

**Files:**
- Modify: `crates/goose-cli/src/session/mod.rs:CliSession::display_session_status`
- Test: `crates/goose-cli/src/session/mod.rs` test module or a pure local helper test

**Interfaces:**
- Consumes: `self.get_session().await -> Result<SessionMetadata>` and `self.display_info.provider`.
- Produces: provider name passed to `output::render_session_status_line`.

- [ ] **Step 1: Add a failing pure fallback test**

Extract `status_provider_name(current: Option<String>, startup: &str) -> String` and test:

```rust
#[test]
fn status_provider_prefers_current_session_provider() {
    assert_eq!(
        status_provider_name(Some("openrouter".to_string()), "huawei_maas"),
        "openrouter"
    );
    assert_eq!(status_provider_name(None, "huawei_maas"), "huawei_maas");
}
```

- [ ] **Step 2: Run the test and verify it fails**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib status_provider_prefers_current_session_provider
```

Expected: compile failure because the helper is absent.

- [ ] **Step 3: Implement provider selection and use one metadata read**

Implement the helper with `current.unwrap_or_else(|| startup.to_string())`. In `display_session_status`, fetch `SessionMetadata` once, derive active context tokens and current `provider_name` from it, then pass that provider string to the renderer. Do not change `SessionDisplayInfo`, which remains dedicated to the startup banner.

- [ ] **Step 4: Run focused test**

```bash
source bin/activate-hermit
cargo test -p goose-cli --lib status_provider_prefers_current_session_provider
```

Expected: PASS.

- [ ] **Step 5: Commit Task 1**

```bash
git add crates/goose-cli/src/session/mod.rs
git commit -m "fix(cli): refresh status provider after model switch"
```

### Task 2: Document customized-fork installation

**Files:**
- Modify: `README.md:Get started`

**Interfaces:**
- Produces: `## Install this customized CLI` documentation immediately after official CLI installation.

- [ ] **Step 1: Add README instructions**

Add this section after the official `curl` installer code block:

```markdown
## Install this customized CLI

This fork's `main` branch includes personal CLI enhancements: `@` fuzzy file and
subagent completion, terminal UI customizations, response usage telemetry, and
additional canonical model metadata.

```bash
git clone https://github.com/giveMeLife/goose.git
cd goose
source bin/activate-hermit
cargo build --release -p goose-cli

mkdir -p ~/.local/bin
ln -sfn "$PWD/target/release/goose" ~/.local/bin/goose
```

Make sure `~/.local/bin` is in your shell's `PATH`, then verify:

```bash
goose --version
goose session
```

The `goose` command is a symlink to your local release build. After updating or
changing this fork, rebuild with `cargo build --release -p goose-cli`; the
command will use the rebuilt binary automatically.
```

- [ ] **Step 2: Verify Markdown placement and commands**

```bash
sed -n '35,95p' README.md
```

Expected: official installer remains intact; fork section follows it and commands reference `main` by default.

- [ ] **Step 3: Commit Task 2**

```bash
git add README.md
git commit -m "docs: add customized CLI install instructions"
```

### Task 3: Validate and publish

**Files:**
- Modify: no expected source changes

- [ ] **Step 1: Run verification**

```bash
source bin/activate-hermit
cargo fmt --check
cargo test -p goose-cli --lib status_provider_prefers_current_session_provider
cargo clippy -p goose-cli --all-targets -- -D warnings
cargo build --release -p goose-cli
```

Expected: all succeed.

- [ ] **Step 2: Push main**

```bash
git push origin main
```

Expected: fixes and README appear in `https://github.com/giveMeLife/goose`.
