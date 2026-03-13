# /pr — Auto-Create Pull Request

You are executing the `/pr` command. Follow these steps exactly:

## Step 1: Detect branches

Run `git branch --show-current` to get the current branch.

Detect the default branch: run `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null` and extract the branch name after the last `/`. If that fails, check `git branch --list main master` and use whichever exists. Default to `main`.

If the current branch IS the default branch, warn the user: "You're on the default branch. Use `/commit` or `/push` first to create a feature branch with your changes." Then stop.

## Step 2: Check for existing PR

Run `gh pr view --json url 2>/dev/null`.

If a PR already exists, report: "A PR already exists for this branch: <url>" and stop.

## Step 3: Ensure branch is pushed

Check for unpushed commits: `git log @{upstream}..HEAD 2>/dev/null`
Check for upstream: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`

- If no upstream: run `git push -u origin <current-branch>`
- If there are unpushed commits: run `git push`

## Step 4: Analyze changes

Run these commands to understand the full scope of changes:
- `git log <default-branch>..HEAD --oneline` for commit history
- `git diff <default-branch>...HEAD` for the full diff

## Step 5: Generate PR content

Based on the analysis, generate:

**Title:** Short, under 70 characters, summarizing the overall change.

**Body:** Using this format:
```
## Summary
- <bullet point 1>
- <bullet point 2>
- <bullet point 3>

## Test plan
- [ ] <test step 1>
- [ ] <test step 2>

🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

## Step 6: Create the PR

Run:
```
gh pr create --title "<title>" --body "$(cat <<'EOF'
<generated body>
EOF
)"
```

Report the PR URL to the user.
