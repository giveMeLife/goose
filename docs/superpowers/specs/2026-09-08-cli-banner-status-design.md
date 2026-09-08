# CLI banner and status-line design

## Goal
Show one intentional startup banner and one accurate post-response status line in the personal Goose fork.

## Startup banner
- The builder must stop calling the stock `output::display_session_info` renderer.
- Session-start hooks will still be emitted, but their banner payload will not be rendered.
- `CliSession::interactive` will render only the custom Joan Stark (jgs) ASCII goose banner.
- The custom banner will display version, session state (`new session` or `resuming`), provider, model, session ID, and current directory. It receives these immutable startup details from `CliSession` rather than re-reading global configuration.

## Post-response status line
- Remove the existing `display_context_usage` call from the interactive input loop, so the legacy context bar is never rendered.
- Keep one status line after a completed response.
- Source context tokens from `SessionMetadata.usage.total_tokens`, the same field used by the existing legacy context renderer. Do not use `accumulated_usage`, which is a historical/session-total counter and does not represent the model's active context.
- Show: model, effective provider, `current_tokens/context_limit`, percentage and colored bar, TPS and TTFT for the just-completed response when available, and total session cost when available.
- Do not render in JSON or stream-JSON modes, or when stdout is not a terminal.

## Error handling
- The status line is best-effort. If model/session/provider metadata is unavailable, skip the line rather than failing the response.
- TPS remains absent when a provider supplies no output-token usage. TTFT falls back to the timestamp of the first streamed model output, including tool calls.

## Tests and verification
- Add focused pure rendering tests for token/percentage formatting as practical.
- Run `cargo fmt`, `cargo build --release -p goose-cli`, relevant `goose-cli` tests, and `cargo clippy -p goose-cli --all-targets -- -D warnings`.
