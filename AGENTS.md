# Agent Guidelines for the Stromer Project

These rules apply to all AI coding agents (Codex, Cursor, Claude Code) working
in this repository. They override generic defaults.

## Communication

- **Always answer in German.** Code, comments, and identifiers stay in English.
- When uncertain, ask. Do not guess. Mark unresolved points as
  `// OPEN QUESTION: ...` in code or `OPEN QUESTION:` in Markdown.
- No filler text, no apologies, no "I'll now do X" preambles. Just do it or
  ask.

## Workflow Rules

### 1. Documentation First (HIGHEST PRIORITY)

Before writing any code that touches an external protocol, API, framework, or
hardware interface:

1. Read the relevant primary sources (official spec PDFs, vendor docs,
   Apple/SwiftUI documentation).
2. Read at least one reference implementation if available.
3. Produce a Markdown spec under `docs/` summarizing the relevant subset.
4. Wait for user review of the spec before implementation.

This rule has no exceptions. "I already know this API" is not a valid reason
to skip the doc step. Training data is often outdated.

### 2. Phased Tasks

When a task is structured in phases (Phase 1, Phase 2, ...), do not run ahead.
At the end of each phase:

- Open a PR with only that phase's deliverables.
- Stop and ask: "Phase X abgeschlossen. Soll ich mit Phase Y beginnen?"

Never combine phases into a single PR unless explicitly told to.

### 3. PR Discipline

- One concern per PR. No drive-by refactors.
- Commit messages in English, imperative mood ("Add X", not "Added X").
- If the repo has no remote, create the files anyway and report that the PR
  could not be opened.

## Code Style

### Swift

- Swift 5.9+ minimum, target iOS 17+ unless stated otherwise.
- **No force unwraps (`!`) or force tries (`try!`)** outside of test code.
- **No `print` statements in production code.** Use a typed result/error.
- All public types and functions get `///` doc comments.
- Prefer `Data` over `[UInt8]` at API boundaries.
- Prefer `Sendable` and structured concurrency where it makes sense.
- Use Apple frameworks before pulling in third-party dependencies. Justify
  every external dependency in the PR description.

### Project Structure

- Reusable logic goes into Swift Packages under `Packages/`, not into the app
  target.
- App target depends on packages, never the other way around.

## Security

- **Never commit secrets, API keys, or device-specific encryption keys.**
- Victron advertisement keys belong in iOS Keychain only. Test vectors with
  example keys are fine because they are public in the upstream Python repo.
- `.env`, `secrets.plist`, `victron-keys.json` are gitignored. Do not bypass.

## Testing

- Every new parser, decoder, or protocol handler ships with unit tests.
- When porting logic from a reference implementation, port its test vectors
  1:1 first, then add edge cases.
- Tests must be runnable in CI without hardware.

## Out of Scope

Unless explicitly requested in the task:

- No UI changes when the task is about parsing or networking.
- No analytics, telemetry, or crash reporters.
- No user-facing copy changes.

