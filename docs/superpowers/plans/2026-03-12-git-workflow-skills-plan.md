# Git Workflow Skills Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create 5 Claude Code custom slash commands for streamlined git workflows with default-branch protection.

**Architecture:** Each command is a standalone markdown prompt file in `.claude/commands/`. The prompts instruct Claude Code how to execute the git workflow when the user invokes the slash command. No code, no scripts — just prompt files.

**Tech Stack:** Claude Code custom commands (markdown), git, gh CLI

**Spec:** `docs/superpowers/specs/2026-03-12-git-workflow-skills-design.md`

---

## Chunk 1: Core Commands

### Task 1: Create `.claude/commands/` directory and `/commit` command

**Files:**
- Create: `.claude/commands/commit.md`

- [ ] **Step 1: Create the commit command file**

Write `.claude/commands/commit.md` with the following prompt content:

```markdown
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
```

- [ ] **Step 2: Verify the file exists**

Run: `ls .claude/commands/commit.md`

- [ ] **Step 3: Commit**

```bash
git add .claude/commands/commit.md
git commit -m "feat: add /commit custom command for smart commits with branch protection"
```

---

### Task 2: Create `/pull` command

**Files:**
- Create: `.claude/commands/pull.md`

- [ ] **Step 1: Create the pull command file**

Write `.claude/commands/pull.md` with the following prompt content:

```markdown
# /pull — Smart Pull

You are executing the `/pull` command. Follow these steps exactly:

## Step 1: Check for uncommitted changes and upstream

Run `git status --porcelain` and `git branch --show-current`.

Then check if the branch has an upstream: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`

If there is no upstream, report: "This branch has no upstream tracking branch. Set one with `git branch --set-upstream-to=origin/<branch>` or use `git pull origin <branch>`." Then stop.

If there ARE uncommitted changes (status output is non-empty):
1. Run `git stash` and note the stash message
2. Run `git pull`
3. Run `git stash pop`
4. If `git stash pop` fails with conflicts, run `git status` and report the conflicting files to the user. Tell them to resolve conflicts manually.

If there are NO uncommitted changes:
1. Just run `git pull`

## Step 2: Report summary

Run `git log --oneline -5` to show recent commits. Report:
- How many new commits were pulled (if any)
- Whether stash was applied cleanly (if applicable)
- Any conflicts that need manual resolution
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/pull.md
git commit -m "feat: add /pull custom command for smart pull with stash handling"
```

---

### Task 3: Create `/push` command

**Files:**
- Create: `.claude/commands/push.md`

- [ ] **Step 1: Create the push command file**

Write `.claude/commands/push.md` with the following prompt content:

```markdown
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
4. Run `git checkout -b <generated-branch-name>`
5. Tell the user: "Moved your changes from `<default-branch>` to `<new-branch>`"
6. If there are uncommitted changes:
   - Run `git add -A`
   - Review staged files for secrets (`.env`, `credentials`, `api_key`, `token`, `secret`, `password`, `private_key`). Warn if found and ask for confirmation. If the user declines, run `git reset HEAD <file>` to unstage the suspicious file(s).
   - Generate a commit message from the diff (concise, focus on "why")
   - Commit with `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>` appended

## Step 3: Push

Check if a remote tracking branch exists: `git rev-parse --abbrev-ref @{upstream} 2>/dev/null`

- If NO upstream exists: run `git push -u origin <current-branch>`
- If upstream exists: run `git push`

## Step 4: Report

Report what was pushed: branch name, number of commits, and the remote URL.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/push.md
git commit -m "feat: add /push custom command with branch protection and upstream auto-setup"
```

---

### Task 4: Create `/pr` command

**Files:**
- Create: `.claude/commands/pr.md`

- [ ] **Step 1: Create the pr command file**

Write `.claude/commands/pr.md` with the following prompt content:

```markdown
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
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/pr.md
git commit -m "feat: add /pr custom command for auto-creating pull requests"
```

---

## Chunk 2: Utility Command and Final Commit

### Task 5: Create `/globalize-project-skills` command

**Files:**
- Create: `.claude/commands/globalize-project-skills.md`

- [ ] **Step 1: Create the globalize command file**

Write `.claude/commands/globalize-project-skills.md` with the following prompt content:

```markdown
# /globalize-project-skills — Copy Project Commands to Global

You are executing the `/globalize-project-skills` command. Follow these steps exactly:

## Step 1: Find project commands

Run `ls .claude/commands/*.md 2>/dev/null` to list all command files in the project's `.claude/commands/` directory.

If none are found, report "No project commands found in `.claude/commands/`." and stop.

Exclude `globalize-project-skills.md` itself from the list of files to copy (it would be redundant to globalize this utility).

## Step 2: Ensure global directory exists

Run `mkdir -p ~/.claude/commands`

## Step 3: Check for conflicts

For each project command file, check if `~/.claude/commands/<filename>` already exists.

If it exists, run `diff .claude/commands/<filename> ~/.claude/commands/<filename>` to compare them.

- If files are identical: skip (already up to date)
- If files differ: show the diff to the user and ask whether to **overwrite**, **skip**, or **rename** (save as `<filename>-project.md`)

## Step 4: Copy files

Copy all non-conflicting files and user-approved overwrites to `~/.claude/commands/` using `cp`.

## Step 5: Report

List what was done:
- Files copied (new)
- Files skipped (identical or user chose to skip)
- Files overwritten (user approved)
- Files renamed (user chose rename)

Note: This is a one-way sync (project -> global). If you later customize the global version, changes will not sync back to the project.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/commands/globalize-project-skills.md
git commit -m "feat: add /globalize-project-skills command to copy project commands globally"
```

---

### Task 6: Final verification

- [ ] **Step 1: Verify all files exist**

Run: `ls -la .claude/commands/`

Expected output should show all 5 files:
- `commit.md`
- `pull.md`
- `push.md`
- `pr.md`
- `globalize-project-skills.md`

- [ ] **Step 2: Verify git history**

Run: `git log --oneline -6`

Should show 5 task commits plus the spec commits.
