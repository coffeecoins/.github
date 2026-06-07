# Contributing Guide

## Table of Contents

1. [Branching Model](#branching-model)
2. [Branch Naming](#branch-naming)
3. [Commit Conventions](#commit-conventions)
4. [Pull Request Process](#pull-request-process)
5. [Code Review Guidelines](#code-review-guidelines)
6. [Local Setup](#local-setup)

---

## Branching Model

```
main         Production releases. Tagged with semantic versions. Never push directly.
rc           Release candidate / pre-production. Hotfixes merge here before main.
staging      Created fresh from develop at the start of each release cycle.
             Merged to rc when release testing passes. Auto-deleted after merge.
develop      Integration branch. All feature/fix/chore branches merge here.

feature/*    New functionality. Branched from develop.
fix/*        Bug fixes. Branched from develop.
hotfix/*     Critical production fixes. Branched from rc.
             Must be merged to BOTH rc AND develop.
chore/*      Maintenance (deps, refactors, tooling). Branched from develop.
docs/*       Documentation only. Branched from develop.
test/*       Test additions or updates. Branched from develop.
release/*    Long-lived branches for maintaining older major versions (e.g. release/1.x).
```

### Flow

```
develop ──→ staging ──→ rc ──→ main (tagged release)
                         ↑
hotfix/* ────────────────┘ (also synced back to develop automatically via PR)
```

### Staging Lifecycle

Staging is ephemeral:
- **Created**: via the "Create Staging from Develop" workflow (Actions tab) or manually from develop
- **Deleted**: automatically when merged to rc

---

## Branch Naming

| Type     | Pattern                                     | Example                        |
|----------|---------------------------------------------|--------------------------------|
| feature  | `feature/<TICKET-ID>-<short-description>`   | `feature/PROJ-123-add-oauth`   |
| fix      | `fix/<TICKET-ID>-<short-description>`       | `fix/PROJ-456-null-pointer`    |
| hotfix   | `hotfix/<TICKET-ID>-<short-description>`    | `hotfix/PROJ-789-auth-bypass`  |
| chore    | `chore/<short-description>`                 | `chore/update-dependencies`    |
| docs     | `docs/<short-description>`                  | `docs/api-auth-reference`      |
| test     | `test/<short-description>`                  | `test/auth-integration-suite`  |
| release  | `release/<major>.x`                         | `release/1.x`                  |

Rules:
- `<TICKET-ID>` follows your tracker format: Jira (`PROJ-123`), GitHub Issues (`123`), etc.
- `<short-description>` is lowercase, hyphen-separated, max 50 characters
- No uppercase, no underscores, no special characters

---

## Commit Conventions

This project uses [Conventional Commits](https://www.conventionalcommits.org).

### Format

```
<type>(<optional-scope>): <subject>

[optional body]

[optional footer]
BREAKING CHANGE: <description>
```

### Types

| Type       | When to use                                    |
|------------|------------------------------------------------|
| `feat`     | A new feature                                  |
| `fix`      | A bug fix                                      |
| `hotfix`   | A critical production fix                      |
| `chore`    | Maintenance, dependency updates, tooling       |
| `docs`     | Documentation only                             |
| `style`    | Formatting, missing semicolons — no logic change |
| `refactor` | Code restructuring without feature/fix change  |
| `perf`     | Performance improvements                       |
| `test`     | Adding or updating tests                       |
| `ci`       | CI/CD configuration changes                    |
| `build`    | Build system or external dependency changes    |
| `revert`   | Reverts a previous commit                      |

### Examples

```
feat(auth): add OAuth2 login with Google
fix(cart): prevent duplicate items on fast double-click
hotfix(payments): correct rounding error in tax calculation
chore(deps): update axios to 1.7.2
docs(api): add authentication endpoint reference
feat!: redesign user session model

BREAKING CHANGE: session tokens are now JWT; existing sessions will be invalidated
```

### Rules

- Subject line: max 72 characters, lowercase, no period at end
- Body: wrap at 72 characters, explain *why* not *what*
- Breaking changes: add `!` after type/scope AND include `BREAKING CHANGE:` footer
- Commit message is validated locally by a git hook — it will be rejected if it doesn't conform

### Semantic Versioning Mapping

| Commit type           | Version bump |
|-----------------------|-------------|
| `fix`, `hotfix`       | patch        |
| `feat`                | minor        |
| `BREAKING CHANGE`     | major        |

---

## Pull Request Process

### Before Opening a PR

- [ ] Branch name follows the naming convention
- [ ] All commits follow Conventional Commits format
- [ ] Tests pass locally
- [ ] No secrets or credentials in code
- [ ] Self-reviewed the diff

### PR Title

PR titles must follow the same Conventional Commits format as commit messages.
The PR title becomes the squash-merge commit message, so it must be accurate.

```
feat(auth): add OAuth2 login with Google
```

### Target Branch

| Your branch  | Merge into  |
|--------------|-------------|
| `feature/*`  | `develop`   |
| `fix/*`      | `develop`   |
| `chore/*`    | `develop`   |
| `docs/*`     | `develop`   |
| `test/*`     | `develop`   |
| `hotfix/*`   | `rc`        |
| `staging`    | `rc`        |
| `rc`         | `main`      |

### After Merging

- `hotfix/*` → A PR to `develop` is auto-created for sync. Review and merge it.
- `staging` → The staging branch is auto-deleted.
- `rc` → The release workflow tags the commit and generates the CHANGELOG.

---

## Code Review Guidelines

### As an Author

- Keep PRs small and focused — one logical change per PR
- Write a clear description explaining *why*, not just *what*
- Respond to all review comments before requesting re-review

### As a Reviewer

- Review within 1 business day
- Distinguish blocking issues from suggestions (prefix suggestions with `nit:`)
- Approve only when all blocking issues are resolved
- Focus on correctness, security, and maintainability — not style (linters handle style)

---

## Local Setup

### Requirements

- [Lefthook](https://github.com/evilmartians/lefthook): `brew install lefthook`
- [Gitleaks](https://github.com/gitleaks/gitleaks): `brew install gitleaks` (for pre-commit secret scanning)

### Install Hooks

```bash
lefthook install
```

This installs:
- `commit-msg` — validates commit message against Conventional Commits
- `pre-commit` — runs secret detection (gitleaks)

### Bypassing Hooks (Emergency Only)

```bash
# Skip hooks — only for genuine emergencies, not convenience
LEFTHOOK=0 git commit -m "..."
```

All commits are re-validated in CI regardless of local hook status.
