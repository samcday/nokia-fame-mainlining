#!/bin/bash
# add-worktree.sh - Create a worktree with submodules properly set up
#
# Creates a new worktree of this repo, then processes every submodule from
# .gitmodules identically: run git -C <submod> worktree add from the
# existing checkout.  Since every submodule has a gitdir: pointer (whether
# it points to a canonical-repo worktree or to .git/modules/), git -C
# resolves to the right backend automatically -- no re-clones needed.
#
# Usage: ./scripts/add-worktree.sh <branch> [path]
#   branch - branch name for the new worktree (also used for submodules)
#   path   - target directory (default: ../nokia-fame-<branch>)

set -u

BRANCH="${1:?Usage: $0 <branch> [path]}"
MAIN_WT="$(git rev-parse --show-toplevel)"

if [ -n "${2:-}" ]; then
	NEW_PATH="$2"
else
	NEW_PATH="$(dirname "$MAIN_WT")/nokia-fame-$BRANCH"
fi

# Make NEW_PATH absolute so submodule worktree-add paths are reliable.
if [[ "$NEW_PATH" != /* ]]; then
	NEW_PATH="$(pwd)/$NEW_PATH"
fi

echo "=== Creating main worktree ==="
echo "  Path:   $NEW_PATH"
echo "  Branch: $BRANCH"
if git worktree add -b "$BRANCH" "$NEW_PATH" 2>/dev/null; then
	echo "  -> New branch '$BRANCH' created from HEAD"
elif git worktree add "$NEW_PATH" "$BRANCH" 2>/dev/null; then
	echo "  -> Existing branch '$BRANCH' checked out"
elif git worktree remove "$NEW_PATH" 2>/dev/null && \
	git worktree add "$NEW_PATH" "$BRANCH" 2>/dev/null; then
	echo "  -> Existing branch '$BRANCH' checked out (cleared stale registration)"
else
	echo "  FAILED: could not create main worktree" >&2
	exit 1
fi

echo ""
echo "=== Setting up submodules ==="

submodules=$(git config --file "$MAIN_WT/.gitmodules" \
	--get-regexp '^submodule\..*\.path$' | awk '{print $2}')

for submod in $submodules; do
	echo ""
	echo "--- $submod ---"

	submod_gitfile="$MAIN_WT/$submod/.git"

	if [ ! -f "$submod_gitfile" ]; then
		echo "  SKIP: .git file not found in main worktree"
		continue
	fi

	# Create a sibling worktree from the submodule's repo.
	# Every submodule has a gitdir: pointer (worktree or .git/modules/),
	# so git -C resolves to the right backend automatically.
	if git -C "$MAIN_WT/$submod" worktree add \
		-b "$BRANCH" "$NEW_PATH/$submod" HEAD 2>/dev/null; then
		echo "  -> New branch '$BRANCH' created from HEAD"
	elif git -C "$MAIN_WT/$submod" worktree add \
		"$NEW_PATH/$submod" "$BRANCH" 2>/dev/null; then
		echo "  -> Existing branch '$BRANCH' checked out"
	elif git -C "$MAIN_WT/$submod" worktree remove \
		"$NEW_PATH/$submod" 2>/dev/null && \
		git -C "$MAIN_WT/$submod" worktree add \
		"$NEW_PATH/$submod" "$BRANCH" 2>/dev/null; then
		echo "  -> Existing branch '$BRANCH' checked out (cleared stale registration)"
	elif git -C "$MAIN_WT/$submod" worktree add --detach \
		"$NEW_PATH/$submod" HEAD 2>/dev/null; then
		echo "  -> Detached HEAD (branch '$BRANCH' not found in this repo)"
	else
		echo "  FAILED: could not create worktree"
	fi
done

echo ""
echo "=== Done: $NEW_PATH ==="
