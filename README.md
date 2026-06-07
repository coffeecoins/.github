# coffeecoins/.github

This is the **organization-level GitHub configuration repository** for [CoffeeCoins](https://github.com/coffeecoins).

It serves three purposes:
1. **Org-wide defaults** — community health files that apply automatically to every repository in the org unless overridden locally
2. **Reusable workflows** — shared CI/CD pipeline components that product repos call instead of copy-pasting workflow code
3. **Operational scripts** — automation for provisioning new repositories with the org's standards

> This repo is **public** by requirement — GitHub only applies community health files and reusable workflows from a public `.github` repo.

---

## Contents

```
.github/
├── workflows/
│   ├── reusable-lint.yml            # MegaLinter — language-agnostic linting
│   ├── reusable-sast.yml            # CodeQL + Semgrep — static analysis
│   ├── reusable-secret-scan.yml     # Gitleaks — secret detection
│   ├── reusable-release.yml         # semantic-release — versioning + changelog
│   └── reusable-deploy.yml          # Parameterised deployment
ISSUE_TEMPLATE/
│   ├── bug_report.yml               # Structured bug report form
│   ├── feature_request.yml          # Feature request form
│   └── security_disclosure.yml      # Redirects to private disclosure channel
scripts/
│   └── apply-branch-protection.sh  # Provisions branch protection on any repo
profile/
│   └── README.md                    # Org profile shown at github.com/coffeecoins
CONTRIBUTING.md                      # Org-wide contributing guide (branching, commits, PRs)
CODE_OF_CONDUCT.md                   # Contributor Covenant 2.1
PULL_REQUEST_TEMPLATE.md             # Default PR template for all repos
SECURITY.md                          # Security policy and vulnerability disclosure
```

### How org-wide defaults work

GitHub automatically applies the files at the root of this repo to any repository in `coffeecoins` that does **not** have its own copy. This means:

- A new repo gets `PULL_REQUEST_TEMPLATE.md`, issue templates, `SECURITY.md`, `CONTRIBUTING.md`, and `CODE_OF_CONDUCT.md` for free
- A repo that needs to override any of these simply creates its own copy locally — the local copy takes precedence

---

## Reusable Workflows

Reusable workflows allow product repos to consume shared CI logic without duplicating it. Each workflow is called with `uses:` and accepts typed inputs and secrets.

> **Plan requirement:** Calling reusable workflows from private repositories requires **GitHub Team** or higher.

### `reusable-lint.yml` — MegaLinter

Runs [MegaLinter](https://megalinter.io) across all supported languages and formats.

```yaml
jobs:
  lint:
    uses: coffeecoins/.github/.github/workflows/reusable-lint.yml@main
    with:
      validate-all: false        # true = scan all files, false = only changed files
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
```

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `validate-all` | boolean | `false` | Scan all files (use on scheduled runs) or only changed files (use on PRs) |

---

### `reusable-sast.yml` — CodeQL + Semgrep

Runs [CodeQL](https://codeql.github.com) and [Semgrep](https://semgrep.dev) for static application security testing.

```yaml
jobs:
  sast:
    uses: coffeecoins/.github/.github/workflows/reusable-sast.yml@main
    with:
      languages: "javascript,python"     # CodeQL language list
      semgrep-rules: "p/owasp-top-ten p/cwe-top-25 p/security-audit"
    secrets:
      semgrep-token: ${{ secrets.SEMGREP_APP_TOKEN }}   # optional
```

| Input | Type | Default | Description |
|-------|------|---------|-------------|
| `languages` | string | `javascript,python` | Comma-separated [CodeQL languages](https://docs.github.com/en/code-security/code-scanning/automatically-scanning-your-code-for-vulnerabilities-and-errors/about-code-scanning-with-codeql#supported-languages-and-frameworks) |
| `semgrep-rules` | string | `p/owasp-top-ten p/cwe-top-25 p/security-audit` | Space-separated Semgrep rule sets |

**Supported CodeQL languages:** `javascript`, `python`, `go`, `java`, `ruby`, `csharp`, `cpp`, `swift`

---

### `reusable-secret-scan.yml` — Gitleaks

Scans the full commit history for secrets and credentials using [Gitleaks](https://github.com/gitleaks/gitleaks).

```yaml
jobs:
  secrets:
    uses: coffeecoins/.github/.github/workflows/reusable-secret-scan.yml@main
    secrets:
      github-token: ${{ secrets.GITHUB_TOKEN }}
      gitleaks-license: ${{ secrets.GITLEAKS_LICENSE }}   # optional, for Gitleaks Pro
```

---

### `reusable-release.yml` — Semantic Release

Runs [semantic-release](https://semantic-release.gitbook.io) to automatically version, tag, generate a changelog, and create a GitHub Release based on [Conventional Commits](#commit-conventions).

```yaml
jobs:
  release:
    uses: coffeecoins/.github/.github/workflows/reusable-release.yml@main
    secrets:
      release-token: ${{ secrets.RELEASE_TOKEN }}
```

> A `RELEASE_TOKEN` PAT (with `repo` + `workflow` scopes) is required so the release commit can trigger downstream workflows. The default `GITHUB_TOKEN` cannot trigger new workflow runs.

---

### `reusable-deploy.yml` — Deployment

A thin parameterised wrapper that runs a deploy command inside a named GitHub Environment (which can have approval gates and environment secrets configured in repo settings).

```yaml
jobs:
  deploy:
    uses: coffeecoins/.github/.github/workflows/reusable-deploy.yml@main
    with:
      environment: "production"
      deploy-command: "kubectl apply -f k8s/production/"
    secrets:
      deploy-token: ${{ secrets.DEPLOY_TOKEN }}
```

| Input | Type | Required | Description |
|-------|------|----------|-------------|
| `environment` | string | ✅ | GitHub Environment name (`development`, `staging`, `pre-production`, `production`) |
| `deploy-command` | string | ✅ | Shell command to execute for deployment |

---

## Provisioning a New Repository

### Step 1 — Create the repo from the template

In the GitHub UI: **New repository → Repository template → `coffeecoins/repository-template`**

Or via CLI:

```bash
gh repo create coffeecoins/<repo-name> \
  --template coffeecoins/repository-template \
  --private \
  --description "<description>"
```

### Step 2 — Apply branch protection

```bash
cd /path/to/coffeecoins-dot-github   # this repo, cloned locally
./scripts/apply-branch-protection.sh <repo-name>
```

This applies the following protection rules in one shot:

| Branch | Rules applied |
|--------|--------------|
| `main` | 1 reviewer, CODEOWNERS, dismiss stale reviews, linear history, no force push, no deletion, all 9 status checks required, enforce on admins |
| `rc` | 1 reviewer, CODEOWNERS, dismiss stale reviews, linear history, no force push, no deletion, 8 status checks required, enforce on admins |
| `develop` | 1 reviewer, dismiss stale reviews, no force push, no deletion, 7 status checks required |

> The org-level branch naming ruleset is already active across all repos — the script detects this and skips re-creation.

### Step 3 — Enable secret scanning

```bash
gh api repos/coffeecoins/<repo-name> \
  --method PATCH \
  -f 'security_and_analysis[secret_scanning][status]=enabled'

gh api repos/coffeecoins/<repo-name> \
  --method PATCH \
  -f 'security_and_analysis[secret_scanning_push_protection][status]=enabled'
```

### Step 4 — Configure repo-specific settings

| File | What to update |
|------|---------------|
| `.github/CODEOWNERS` | Replace `@coffeecoins/maintainers` with actual GitHub usernames or teams |
| `.github/dependabot.yml` | Uncomment the package ecosystem(s) your repo uses |
| `.github/workflows/ci.yml` | Replace the test placeholder with your language's test command and coverage tool |
| `.github/workflows/deploy.yml` | Add your cloud provider authentication and deploy command |
| `.releaserc.yml` | Add `release/1.x` etc. entries if maintaining multiple major versions |
| `vars.CODEQL_LANGUAGES` | Set this GitHub Actions variable in the repo to your language(s) |

### Step 5 — Configure GitHub Environments

In **repo Settings → Environments**, create four environments and configure approval gates:

| Environment | Approval required | Linked branch |
|-------------|------------------|---------------|
| `development` | No | `develop` |
| `staging` | No | `staging` |
| `pre-production` | Yes | `rc` |
| `production` | Yes | `main` |

---

## Branching Model

All repositories in this org follow a single branching model:

```
main         Production releases. Tagged with semantic versions. Never commit directly.
rc           Release candidate. Maps to pre-production environment. Hotfixes target here.
staging      Ephemeral. Cut from develop at the start of a release cycle.
             Auto-deleted after merging to rc.
develop      Integration branch. All feature/fix/chore branches merge here.
```

### Flow

```
develop ──→ staging ──→ rc ──→ main
                         ↑
              hotfix/* ──┘ (also auto-synced back to develop)
```

### Branch naming

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feature/<TICKET-ID>-<description>` | `feature/PROJ-123-add-oauth` |
| Fix | `fix/<TICKET-ID>-<description>` | `fix/PROJ-456-null-pointer` |
| Hotfix | `hotfix/<TICKET-ID>-<description>` | `hotfix/PROJ-789-auth-bypass` |
| Chore | `chore/<description>` | `chore/update-dependencies` |
| Docs | `docs/<description>` | `docs/api-reference` |
| Test | `test/<description>` | `test/auth-integration` |
| Release | `release/<major>.x` | `release/1.x` |

`<TICKET-ID>` supports Jira-style (`PROJ-123`) and GitHub Issues-style (`123`) formats.

This pattern is enforced org-wide by the **branch-naming-conventions** ruleset (visible at [org settings → Rules](https://github.com/organizations/coffeecoins/settings/rules)).

---

## Commit Conventions

All commits must follow [Conventional Commits](https://www.conventionalcommits.org):

```
<type>(<optional-scope>): <subject>

[optional body]

[optional footer]
BREAKING CHANGE: <description>
```

**Allowed types:** `feat` `fix` `hotfix` `chore` `docs` `style` `refactor` `perf` `test` `ci` `build` `revert`

**Enforcement layers:**
- Local: `lefthook` + `.githooks/validate-commit-msg` (in each repo)
- CI: `commitlint` job in `ci.yml`
- PR merge: PR title must also follow the convention (enforced by `amannn/action-semantic-pull-request`)

**Semantic version mapping:**

| Commit | Bump |
|--------|------|
| `fix:`, `hotfix:` | patch — `1.0.0 → 1.0.1` |
| `feat:` | minor — `1.0.0 → 1.1.0` |
| `feat!:` or `BREAKING CHANGE:` | major — `1.0.0 → 2.0.0` |

---

## Security & Compliance

### Controls in place

| Control | Implementation |
|---------|---------------|
| Secret detection (pre-commit) | Gitleaks via `lefthook` git hook |
| Secret scanning (repo) | GitHub Secret Scanning + push protection |
| SAST | CodeQL (PR + weekly) + Semgrep (weekly) |
| DAST | OWASP ZAP — triggered on `rc` pipeline (configured per repo) |
| Dependency vulnerabilities | Dependabot alerts + auto-PRs |
| Container scanning | Trivy (weekly security scan, if Dockerfile present) |
| IaC scanning | Checkov (weekly security scan, if Terraform present) |
| License compliance | `license-checker` / `pip-licenses` / `go-licenses` on every PR |
| Supply chain | GitHub Actions pinned to version tags; Dependabot updates them to SHA pins |
| Branch protection | Required reviewers, no force push, required status checks on all protected branches |
| Separation of duties | All merges to `main` and `rc` require a reviewer other than the author |
| Signed commits | Enforced at org level for `main` and `rc` (configurable per repo) |
| Audit trail | GitHub org audit log enabled |

### Compliance targets

- **SOC2 Type II** — change management (CC8.1), access control (CC6.x), vulnerability management (CC9.1), audit trail (CC7.2)
- **ISO 27001** — A.9 access control, A.12 operations, A.12.6 vulnerability management, A.14 secure development
- **GDPR** — data flow documentation in ADRs, PII classification in PR template checklist, responsible disclosure via `SECURITY.md`

---

## Maintaining This Repo

Changes to this repository affect **every repository in the org**. Treat it with the same care as production infrastructure.

- All changes require a PR — no direct commits to `main`
- PRs must follow [Conventional Commits](#commit-conventions)
- Changes to reusable workflows should be tested in a product repo on a branch before merging

### Adding a new reusable workflow

1. Create `.github/workflows/reusable-<name>.yml` with `on: workflow_call:` trigger
2. Document inputs and secrets in this README under [Reusable Workflows](#reusable-workflows)
3. Update the relevant product repo's workflow to call it

### Updating the branch protection script

The script at `scripts/apply-branch-protection.sh` is the source of truth for branch protection configuration. After any change:

1. Test against a non-critical repo first: `./scripts/apply-branch-protection.sh <test-repo>`
2. Re-apply to all existing repos that should pick up the change

---

## Related

| Resource | Link |
|----------|------|
| Repository template | [coffeecoins/repository-template](https://github.com/coffeecoins/repository-template) |
| Org settings | [github.com/organizations/coffeecoins/settings](https://github.com/organizations/coffeecoins/settings) |
| Org rulesets | [github.com/organizations/coffeecoins/settings/rules](https://github.com/organizations/coffeecoins/settings/rules) |
| Security advisories | [github.com/orgs/coffeecoins/security](https://github.com/orgs/coffeecoins/security) |
