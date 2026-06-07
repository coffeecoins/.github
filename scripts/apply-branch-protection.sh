#!/bin/sh
# =============================================================================
# apply-branch-protection.sh
#
# Applies branch protection rules across all coffeecoins repositories.
# Run this AFTER upgrading to GitHub Team plan.
#
# Prerequisites:
#   - gh CLI authenticated (gh auth login)
#   - Token scopes: repo, admin:org
#   - GitHub Team plan active on coffeecoins org
#
# Usage:
#   chmod +x apply-branch-protection.sh
#   ./apply-branch-protection.sh [repo-name]
#
#   Without argument: applies to repository-template
#   With argument:    applies to the specified repo
# =============================================================================

REPO="${1:-repository-template}"
ORG="coffeecoins"

echo "Applying branch protection to ${ORG}/${REPO}..."
echo ""

# ---------------------------------------------------------------------------
# Helper function
# ---------------------------------------------------------------------------
protect_branch() {
  BRANCH="$1"
  PAYLOAD="$2"
  echo "  Protecting ${BRANCH}..."
  RESULT=$(gh api "repos/${ORG}/${REPO}/branches/${BRANCH}/protection" \
    --method PUT \
    --input - <<EOF
${PAYLOAD}
EOF
  )
  if echo "$RESULT" | grep -q '"url"'; then
    echo "  ✓ ${BRANCH} protected"
  else
    echo "  ✗ ${BRANCH} failed: $(echo "$RESULT" | grep '"message"')"
  fi
  echo ""
}

# ---------------------------------------------------------------------------
# main — production release branch
# Strictest rules: signed commits, CODEOWNERS, linear history, all checks
# ---------------------------------------------------------------------------
protect_branch "main" '{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Commit Lint",
      "PR Title Lint",
      "Branch Name",
      "Secret Detection",
      "Dependency Review",
      "SAST (CodeQL)",
      "Lint (MegaLinter)",
      "Tests",
      "License Compliance"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true,
  "lock_branch": false
}'

# ---------------------------------------------------------------------------
# rc — release candidate / pre-production
# ---------------------------------------------------------------------------
protect_branch "rc" '{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Commit Lint",
      "PR Title Lint",
      "Branch Name",
      "Secret Detection",
      "SAST (CodeQL)",
      "Lint (MegaLinter)",
      "Tests",
      "License Compliance"
    ]
  },
  "enforce_admins": true,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": true,
    "required_approving_review_count": 1,
    "require_last_push_approval": true
  },
  "restrictions": null,
  "required_linear_history": true,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}'

# ---------------------------------------------------------------------------
# develop — integration branch
# ---------------------------------------------------------------------------
protect_branch "develop" '{
  "required_status_checks": {
    "strict": true,
    "contexts": [
      "Commit Lint",
      "PR Title Lint",
      "Branch Name",
      "Secret Detection",
      "SAST (CodeQL)",
      "Lint (MegaLinter)",
      "Tests"
    ]
  },
  "enforce_admins": false,
  "required_pull_request_reviews": {
    "dismiss_stale_reviews": true,
    "require_code_owner_reviews": false,
    "required_approving_review_count": 1,
    "require_last_push_approval": false
  },
  "restrictions": null,
  "required_linear_history": false,
  "allow_force_pushes": false,
  "allow_deletions": false,
  "required_conversation_resolution": true
}'

# ---------------------------------------------------------------------------
# Org-level rulesets (branch naming patterns, hotfix/release/* protection)
# Requires admin:org token scope
# ---------------------------------------------------------------------------
echo "Applying org-level rulesets..."

# Ruleset: enforce branch naming conventions across all repos
gh api "orgs/${ORG}/rulesets" --method POST --input - <<'RULESET'
{
  "name": "branch-naming-conventions",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["~ALL"],
      "exclude": ["refs/heads/main", "refs/heads/rc", "refs/heads/develop", "refs/heads/staging"]
    }
  },
  "rules": [
    {
      "type": "branch_name_pattern",
      "parameters": {
        "name": "Branch naming convention",
        "negate": false,
        "operator": "regex",
        "pattern": "^(feature|fix|hotfix)/([A-Z][A-Z0-9]+-[0-9]+|[0-9]+)-[a-z][a-z0-9-]+$|^(chore|docs|test|style|refactor|perf|ci|build)/[a-z][a-z0-9-]+$|^release/[0-9]+\\.x$|^staging$"
      }
    }
  ]
}
RULESET

if [ $? -eq 0 ]; then
  echo "  ✓ Branch naming ruleset applied"
else
  echo "  ✗ Branch naming ruleset failed (requires admin:org scope)"
fi

echo ""
echo "Done. Branch protection applied to ${ORG}/${REPO}."
echo ""
echo "To apply to another repo:"
echo "  ./apply-branch-protection.sh <repo-name>"
