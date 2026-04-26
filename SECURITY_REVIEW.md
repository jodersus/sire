# Security Review: Sire Repository Cleanup Operation

## Findings

### 1. Deploy Keys (`.deploy_key`, `.deploy_key.pub`)
- **Status**: Present in commits `3eba06e` and `66b917d`
- `66b917d` removed them from working tree but NOT from git history
- **Risk**: HIGH — private key is permanently in git history
- **Current working tree**: Already removed (confirmed)

### 2. Hardcoded Token (`REDACTED_TOKEN`)
- **Status**: Present in commit `4fa08b6` ("Integración completa...")
- **Files affected in history**:
  - `src/ui/main.ts` — line 18: `const ACCESS_TOKEN = 'REDACTED_TOKEN'`
  - `docs/ui/main.js` — line 14: `const ACCESS_TOKEN = 'REDACTED_TOKEN'`
- **Current working tree**:
  - `src/ui/main.ts` still has fallback: `(window as any).__SIRE_TOKEN__ || 'REDACTED_TOKEN'`
  - `docs/ui/main.js` still has hardcoded token
- **Risk**: MEDIUM-HIGH — auth token exposed in git history and current build output

### 3. Other Potential Secrets
- Commit `f90d660` ("deploy: add docs/ folder for GitHub Pages") — no secrets detected in message or files
- No other `-S` searches found additional tokens/passwords in commit messages

## Evaluation of Proposed Operation

```bash
# Step 1 — INCOMPLETE
git filter-repo --path .deploy_key --path .deploy_key.pub --invert-paths
# ❌ DOES NOT remove the hardcoded REDACTED_TOKEN token from src/ui/main.ts and docs/ui/main.js

# Step 2 — CORRECT (but only effective after filter-repo is complete)
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# Step 3 — QUESTIONABLE
git remote add origin-new git@github.com:jodersus/sire.git
# The remote likely already exists as "origin". Adding a new remote is unnecessary.

# Step 4 — CORRECT in principle
# Force push is required after history rewrite
```

## Required Changes

**NOT APROBADO** — operation incomplete and potentially dangerous.

### Issues:
1. **Incomplete cleanup**: `git filter-repo` must ALSO remove the token `REDACTED_TOKEN` from all files where it appears in history
2. **Current working tree still exposed**: `docs/ui/main.js` contains the hardcoded token RIGHT NOW
3. **Remote naming**: Adding `origin-new` is unnecessary confusion; use existing `origin` or replace it

### Corrected Operation:

```bash
# BEFORE any git filter-repo — fix the working tree first:
# 1. Remove hardcoded fallback from src/ui/main.ts
# 2. Rebuild docs/ so docs/ui/main.js gets regenerated without the token
# 3. Commit those fixes

# Then run git filter-repo with ALL sensitive paths:
git filter-repo \
  --path .deploy_key \
  --path .deploy_key.pub \
  --path-glob '*/main.ts' \
  --path-glob '*/main.js' \
  --invert-paths

# Wait — that would delete the ENTIRE files, not just the token lines.
# git filter-repo doesn't support line-level removal natively.
```

### Better Approach — Two Options:

**Option A: Complete purge (recommended for maximum security)**
```bash
# 1. First, fix current code to remove ALL traces of the token
#    - Edit src/ui/main.ts to remove fallback to 'REDACTED_TOKEN'
#    - Regenerate docs/ui/main.js (or delete docs/ and rebuild)
#    - Commit these changes

# 2. Use git filter-repo to remove ONLY the deploy key files
#    (these are standalone files, easy to purge completely)
git filter-repo --path .deploy_key --path .deploy_key.pub --invert-paths

# 3. For the token in source files — since it's embedded in code,
#    use git-filter-repo with --replace-text to rewrite the token
#    (or accept that the auth system itself needs redesign)

# 4. Clean reflog and GC
git reflog expire --expire=now --all && git gc --prune=now --aggressive

# 5. Force push to existing origin
git push origin main --force
```

**Option B: Nuclear option (if deploy key was used for anything critical)**
- Rotate the deploy key on GitHub (already done: "Nueva deploy key probada y funciona")
- The old key in history is useless if revoked/removed from GitHub
- For `REDACTED_TOKEN` token: it's a client-side auth check, not a server secret
  - Risk is lower but still exists if someone scans the repo

## Recommendation

1. **Fix working tree NOW**: Remove `|| 'REDACTED_TOKEN'` from `src/ui/main.ts`, rebuild `docs/`
2. **Purge deploy keys from history**: `git filter-repo --path .deploy_key --path .deploy_key.pub --invert-paths`
3. **For the token**: Since it's embedded in code (not a standalone secret file), options are:
   - Use `git filter-repo --replace-text` to replace `REDACTED_TOKEN` with something harmless
   - Or accept the risk (it's a client-side pseudo-auth, not a real secret)
4. **Clean and force push**: reflog expire + gc + force push to `origin`

## Final Verdict

**NOT APROBADO as proposed.**

The proposed operation:
- ✅ Correctly targets the deploy key files
- ✅ Correctly uses `--invert-paths` (delete these paths, keep everything else)
- ✅ reflog + gc is correct
- ❌ **Misses the hardcoded `REDACTED_TOKEN` token** in `src/ui/main.ts` and `docs/ui/main.js`
- ❌ **Current working tree still contains the token** in compiled output
- ❌ Unnecessary `origin-new` remote (just use `origin`)

**Required fixes before approval:**
1. Remove token from current working tree and rebuild docs/
2. Add `--replace-text` for `REDACTED_TOKEN` OR explicitly accept the residual risk
3. Use `origin` not `origin-new` for the remote