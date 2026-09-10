# Session `/usage` command design

## Goal
Add an interactive `/usage` command that renders a colorized, complete usage and cost report for the current session tree.

## Command behavior

`/usage` accepts no arguments. It prints a report containing:

1. **Session total**
   - accumulated known cost;
   - total, input, output, cache-read, and cache-write tokens;
   - active context tokens and context limit with percentage;
   - number of descendant subagent sessions.
2. **Last response in the current CLI process**
   - TTFT, TPS, output tokens, and elapsed generation time when known;
   - otherwise, `unavailable in this CLI session`.
3. **Cost and token breakdown by model / provider**
   - every entry labels the source as `model / provider`;
   - includes known cost, percentage of known session cost, input, output, total, cache-read, and cache-write tokens;
   - aggregates the root session and all descendant subagent sessions;
   - orders entries by known cost descending, then total tokens descending for entries with unknown/equal cost.

## Data and accuracy

- Totals and per-model values come from persisted session usage and ledger data, never inferred from provider pricing at render time.
- Include a provider/model group even when its cost is unknown if token usage is known; render cost as `unknown` and omit its percentage.
- Include all session-tree descendants, so delegated subagents contribute to the same report.
- Store last-response performance values in `CliSession` after every completed response. `/usage` does not fabricate historic TTFT/TPS when a session is resumed.

## Rendering and colors

Use normal terminal output (no persistent dashboard or cursor control):

- cyan: title, section headers, model;
- mauve/magenta: provider;
- peach/orange: costs;
- blue: token counts;
- teal: cache values;
- green/yellow/red: context percentage and TTFT using existing thresholds (<3s, 3–6s, >6s);
- green: TPS and total-session indicator;
- dim: labels, separators, unavailable/unknown values.

The report may span multiple lines and must remain readable in narrow terminals by using one metric group per line rather than relying on a fixed-width table.

## Scope

- CLI command parsing/help: `crates/goose-cli/src/session/input.rs` and `crates/goose-cli/src/session/mod.rs`.
- Store current-process last-turn metrics: `crates/goose-cli/src/session/mod.rs`.
- Report formatting/rendering: `crates/goose-cli/src/session/output.rs`.
- Session-tree grouped usage query and public type: `crates/goose/src/session/session_manager.rs` and any required public session API re-export.

## Verification

- Unit-test command parsing, grouped session-tree aggregation, sorting, unknown-cost handling, and pure report formatting.
- Test last-turn unavailable and available formatting.
- Run `cargo fmt`, relevant `goose` and `goose-cli` tests, `cargo clippy --all-targets -- -D warnings`, and `cargo build --release -p goose-cli`.
- Manually run `/usage` after a regular response, after a provider/model switch, and after a subagent run.
