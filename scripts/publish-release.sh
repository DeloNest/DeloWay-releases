#!/usr/bin/env bash
# ==============================================================================
# DeloWay Automated Release Publisher
# Pushes the latest code and releases to:
#   1. Private Source: git@github.com:DeloNest/DeloWay.git
#   2. Public Releases: git@github.com:DeloNest/DeloWay-releases.git
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_DIR"

TAG="$1"
CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  DeloWay Release Publisher"
echo "  Branch: $CURRENT_BRANCH"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 1. Pre-flight Theme Check
echo "▶ Running Monochrome Pre-flight Check..."
if ! ./scripts/check-theme.sh; then
    echo "✖ Theme check failed! Aborting release." >&2
    exit 1
fi

# 2. Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "✖ You have uncommitted changes. Please commit or stash them first." >&2
    git status -s
    exit 1
fi

# 3. Ensure remotes exist
if ! git remote get-url origin >/dev/null 2>&1; then
    echo "✖ Remote 'origin' is missing." >&2
    exit 1
fi

if ! git remote get-url release >/dev/null 2>&1; then
    echo "ℹ Adding 'release' remote pointing to git@github.com:DeloNest/DeloWay-releases.git..."
    git remote add release git@github.com:DeloNest/DeloWay-releases.git
fi

# 4. Push to Private Source (origin)
echo "▶ Pushing to Private Source (DeloNest/DeloWay)..."
git push origin "$CURRENT_BRANCH"

# 5. Push to Public Releases (release)
echo "▶ Pushing to Public Releases (DeloNest/DeloWay-releases)..."
git push release "$CURRENT_BRANCH":master

# 6. Push tag if supplied
if [ -n "$TAG" ]; then
    echo "▶ Creating and pushing tag: $TAG..."
    git tag -a "$TAG" -m "Release $TAG" || true
    git push origin "$TAG" || true
    git push release "$TAG" || true
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✔ Release published successfully to DeloNest/DeloWay-releases!"
echo "  Users will now receive this update in Settings -> Updates."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
