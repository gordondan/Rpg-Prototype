# /pull — Smart Pull

You are executing the `/pull` command. Follow these steps exactly:

## Step 1: Check for uncommitted changes and upstream

Run `git status --porcelain` and `git branch --show-current`.

Then check if the branch has an upstream: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`

If there is no upstream, report: "This branch has no upstream tracking branch. Set one with `git branch --set-upstream-to=origin/<branch>` or use `git pull origin <branch>`." Then stop.

If there ARE uncommitted changes (status output is non-empty):
1. Run `git stash push -m "auto-stash before pull"`
2. Run `git pull`
3. If `git pull` fails with merge conflicts, run `git status` and report the conflicting files. Tell the user to resolve the pull conflicts first — do NOT attempt `git stash pop`. Stop here.
4. If pull succeeded, run `git stash pop`
5. If `git stash pop` fails with conflicts, run `git status` and report the conflicting files to the user. Tell them to resolve conflicts manually.

If there are NO uncommitted changes:
1. Just run `git pull`

## Step 2: Merge main into current branch

Skip this step if the current branch IS main.

1. Run `git fetch origin main`
2. Check if there are new commits on main that aren't in the current branch: `git log HEAD..origin/main --oneline`
3. If there are no new commits, report "Already up to date with main." and skip to Step 3.
4. If there are new commits, run `git merge origin/main`
5. If the merge fails with conflicts, run `git status` and report the conflicting files. Tell the user to resolve the merge conflicts manually. Stop here.

## Step 3: Report summary

Run `git log --oneline -5` to show recent commits. Report:
- How many new commits were pulled (if any)
- Whether stash was applied cleanly (if applicable)
- Any conflicts that need manual resolution
