# Dynamic status provider and customized-install design

## Goals

1. Make the post-response status line reflect the provider currently active after `/model --provider ...` changes.
2. Document how to install this customized fork's `main` branch as the user's `goose` command.

## Dynamic provider

- Preserve `SessionDisplayInfo.provider` as startup-banner metadata; the startup banner intentionally describes the session at creation time.
- In `CliSession::display_session_status`, obtain the provider name from the current session metadata (`self.get_session().await?.provider_name`) after a response completes.
- If session metadata has no provider name, fall back to the existing startup provider. This keeps the status renderer best-effort and avoids suppressing an otherwise valid status line.
- Continue reading model configuration and context limit from the active provider/session as currently implemented.

## README installation guide

- Add a clearly marked `## Install this customized CLI` subsection immediately after the standard CLI install snippet in `README.md`.
- State that the instructions clone the fork's `main` branch and build the customized CLI from source.
- Provide exact commands to clone `https://github.com/giveMeLife/goose.git`, activate Hermit, build the release `goose-cli`, and create `~/.local/bin/goose` as a symlink to `target/release/goose`.
- Explain that `~/.local/bin` must be present in `PATH`, provide `goose --version` and `goose session` verification commands, and explain that future release rebuilds update the symlinked command automatically.
- Briefly identify included enhancements: `@` fuzzy file/subagent completion, terminal UI customizations, usage telemetry, and additional canonical model metadata.

## Verification

- Add a unit test for provider-selection behavior if a pure helper is introduced; otherwise cover the fallback logic through the closest existing session test infrastructure.
- Run `cargo fmt`, focused `goose-cli` tests, `cargo clippy -p goose-cli --all-targets -- -D warnings`, and `cargo build --release -p goose-cli`.
