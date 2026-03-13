# /push — Smart Push

You are executing the `/push` command. Follow these steps exactly:

## Step 1: Detect current and default branch

Run `git branch --show-current` to get the current branch.

Detect the default branch: run `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null` and extract the branch name after the last `/`. If that fails, check `git branch --list main master` and use whichever exists. Default to `main`.

## Step 2: Default-branch protection

If the current branch IS the default branch:

1. Run `git diff` and `git diff --cached` to analyze uncommitted changes, and `git log origin/<default-branch>..HEAD` to check for committed-but-unpushed changes. If there are no changes of any kind (no diff, no unpushed commits), report "Nothing to push." and stop.
2. Generate a branch name:
   - Prefix: `feature/`, `fix/`, or `chore/` based on the nature of changes
   - Suffix: short kebab-case summary (3-6 words max)
3. Run `git checkout -b <generated-branch-name>`
4. Tell the user: "Moved your changes from `<default-branch>` to `<new-branch>`"
5. If there are uncommitted changes:
   - Run `git add -A`
   - Review staged files for secrets (`.env`, `credentials`, `api_key`, `token`, `secret`, `password`, `private_key`). Warn if found and ask for confirmation. If the user declines, run `git reset HEAD <file>` to unstage the suspicious file(s).
   - Generate a commit message from the diff (concise, focus on "why")
   - Commit with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` appended

## Step 3: Update documentation

Before pushing, run the `/update-docs` workflow to sync `docs/game-objects/` with any code changes. This ensures documentation stays current with every push.

- Check recently changed files against the doc mapping in `/update-docs`
- If any game object docs need updating, update them and commit
- If no docs need updating, move on silently

## Step 4: Push

Check if a remote tracking branch exists: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`

- If NO upstream exists: run `git push -u origin <current-branch>`
- If upstream exists: run `git push`

## Step 5: Report

Report what was pushed: branch name, number of commits, and the remote URL.
