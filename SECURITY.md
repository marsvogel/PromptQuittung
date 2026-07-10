# Security Policy

PromptQuittung reads the session token of the locally installed Cursor IDE, so security reports are taken seriously.

## Reporting a vulnerability

Please report vulnerabilities privately via [GitHub Private Vulnerability Reporting](https://github.com/marsvogel/PromptQuittung/security/advisories/new) — do **not** open a public issue for security problems.

You can expect an initial response within a week. Once a fix is released, the vulnerability will be disclosed in the release notes.

## Scope

Relevant areas include, but are not limited to:

- Handling of the Cursor session token (read from `state.vscdb`, sent only to `cursor.com`, never logged)
- The network layer (`CursorUsageClient`)
- The release pipeline (GitHub Actions workflow, published ZIP)

## Supported versions

Only the [latest release](https://github.com/marsvogel/PromptQuittung/releases/latest) is supported.
