# /commit — Smart Commit

You are executing the `/commit` command. Follow these steps exactly:

## Step 1: Check for changes

Run `git status` and `git branch --show-current`.

If the working tree is clean and nothing is staged, report "Nothing to commit." and stop.

## Step 2: Detect the default branch

Run `git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null` to get the default branch name (extract just the branch name after the last `/`). If that fails, check if `main` or `master` exists with `git branch --list main master` and use whichever exists. Default to `main` if neither is found.

## Step 3: Default-branch protection

If the current branch IS the default branch:

1. Run `git diff` and `git diff --cached` to see all changes
2. Analyze the changes and generate a descriptive branch name:
   - Prefix: `feature/`, `fix/`, or `chore/` based on the nature of changes
   - Suffix: short kebab-case summary (3-6 words max)
   - Example: `fix/quest-completion-when-target-defeated`
3. Run `git checkout -b <generated-branch-name>`
4. Tell the user: "Moved your changes from `<default-branch>` to `<new-branch>`"

## Step 4: Stage changes

Run `git add -A`.

Then run `git diff --cached --name-only` and review the list of staged files. Look for filenames containing: `.env`, `credentials`, `api_key`, `token`, `secret`, `password`, `private_key`. If any suspicious files are found that are NOT in `.gitignore`, warn the user and ask for confirmation before proceeding. If the user declines, run `git reset HEAD <file>` to unstage the suspicious file(s) before continuing.

## Step 5: Generate commit message

Run `git diff --cached` to see the full staged diff. Analyze the changes and write a concise commit message (1-2 sentences) that focuses on the "why" — the purpose of the change, not a list of what changed.

## Step 6: Commit

Create the commit using a HEREDOC for the message:

```
git commit -m "$(cat <<'EOF'
<your generated message>

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>
EOF
)"
```

Run `git status` after to verify success. Report the commit hash and message to the user.
