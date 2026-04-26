#!/bin/bash
# pre-commit security scan for sire
# Run this before every commit to prevent secret leakage

set -e

echo "🔒 Security pre-commit scan..."

# Patterns that must never be committed
FORBIDDEN_PATTERNS=(
    "BEGIN.*PRIVATE KEY"
    "BEGIN.*OPENSSH PRIVATE KEY"
    "ssh-ed25519.*sire"
    "ssh-rsa.*sire"
    "deploy_key"
    "deploy_key.pub"
    "cfut_"
    "api_token"
    "api_key"
    "secret_key"
    "password.*=.*[^*]"
    "token.*=.*[^*]"
)

# Check staged files
STAGED=$(git diff --cached --name-only)

if [ -z "$STAGED" ]; then
    echo "No staged files."
    exit 0
fi

ERRORS=0
for file in $STAGED; do
    if [ ! -f "$file" ]; then
        continue
    fi
    for pattern in "${FORBIDDEN_PATTERNS[@]}"; do
        if grep -i -n "$pattern" "$file" 2>/dev/null; then
            echo "❌ SECURITY VIOLATION in $file: pattern '$pattern'"
            ERRORS=$((ERRORS + 1))
        fi
    done
done

# Check .gitignore coverage
if git diff --cached --name-only | grep -q "\.deploy_key"; then
    echo "❌ .deploy_key is staged. Remove immediately."
    ERRORS=$((ERRORS + 1))
fi

if git diff --cached --name-only | grep -q "\.key"; then
    echo "⚠️  .key file staged. Review manually."
fi

if [ $ERRORS -gt 0 ]; then
    echo ""
    echo "🚫 COMMIT BLOCKED: $ERRORS security violations found."
    echo "Fix before committing."
    exit 1
fi

echo "✅ Security scan passed."
exit 0
