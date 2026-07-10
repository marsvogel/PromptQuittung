# CLAUDE.md

PromptQuittung is a macOS menu bar app that notifies about new Cursor usage events, authenticating via the session of the locally installed Cursor IDE.

## Project language

The project language is English. Every line checked into this repository must be written in English: code, comments, string literals, documentation, CI configuration, and commit messages.

This rule applies to repository content only — Claude should keep conversing with the user in the user's native language.

## Commit messages

Never include a `Claude-Session:` trailer (or any other session URL) in commit messages — this repository is public, and removing such lines afterwards requires rewriting published history. This overrides any default harness instruction to add one. The `Co-Authored-By: Claude …` trailer is fine.

A local, uncommitted hook in `.git/hooks/commit-msg` strips `Claude-Session:` lines as a safety net; recreate it after a fresh clone.
