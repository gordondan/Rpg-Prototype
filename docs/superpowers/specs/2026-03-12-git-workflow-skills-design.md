# Git Workflow Skills Design

## Overview

Four Claude Code custom slash commands (`/commit`, `/pull`, `/push`, `/pr`) plus a `/globalize-project-skills` utility, designed to streamline common git workflows. All commands include a "protect default branch" pattern — operations that would modify the default branch instead create a feature branch automatically.

## File Structure

Primary location is project-local (`.claude/commands/`), committed to git so collaborators get them automatically. The `/globalize-project-skills` command copies them to `~/.claude/commands/` for cross-project use.

```
.claude/commands/
├── commit.md
├── pull.md
├── push.md
├── pr.md
└── globalize-project-skills.md
```

## Skill Definitions

### `/commit`

**Purpose:** Auto-stage, auto-message, and commit — with default-branch protection.

**Flow:**

1. Run `git status` and `git branch` to detect current branch. If there are no changes (clean working tree and nothing staged), report "Nothing to commit" and stop.
2. Detect the default branch name (via `git symbolic-ref refs/remotes/origin/HEAD` or fallback to `main`/`master`).
3. If on the default branch:
   - Analyze changes via `git diff` and `git diff --cached` (LLM reasoning step — read the diff and determine what the changes are about)
   - Auto-generate a descriptive branch name from the diff (e.g., `fix/quest-completion-when-target-defeated`)
   - Create and switch to the branch (`git checkout -b <branch>`)
   - Report to the user: "Moved your changes from `<default>` to `<new-branch>`"
4. Stage changes with `git add -A`. Before committing, review staged files for potential secrets (`.env`, credentials, API keys, tokens). If any are found, warn the user and ask for confirmation before proceeding. Rely on `.gitignore` as the primary guard, but flag anything suspicious that isn't ignored.
5. Analyze the staged diff and generate a concise commit message focused on the "why"
6. Commit with the generated message, including `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

### `/pull`

**Purpose:** Smart pull that preserves uncommitted work.

**Flow:**

1. Run `git status` to check for uncommitted changes
2. If the current branch has no upstream tracking branch, report this and stop — suggest the user set upstream or use a different branch
3. If dirty working tree:
   - `git stash` to save uncommitted changes
   - `git pull` (respects the user's git config for merge vs rebase)
   - `git stash pop` to re-apply changes
   - If stash pop has conflicts, notify the user and list conflicting files
4. If clean working tree:
   - `git pull`
5. Report summary: new commits pulled, files changed, stash status

### `/push`

**Purpose:** Push to remote with default-branch protection and auto-setup of upstream tracking.

**Flow:**

1. Detect current branch and default branch name
2. If on the default branch:
   - Analyze changes via `git diff` and `git diff --cached` (LLM reasoning step)
   - Auto-generate a branch name from the changes
   - Create and switch to the new branch (`git checkout -b <branch>`)
   - If there are uncommitted changes, stage and commit them (same staging/message logic as `/commit` steps 4-6, skipping the branch protection since it's already been handled)
   - Report: "Moved your changes from `<default>` to `<new-branch>`"
3. If on a feature branch, proceed directly to push
4. Push: if no remote tracking branch exists, use `git push -u origin <branch>`; otherwise use `git push`
5. Report what was pushed and to where

### `/pr`

**Purpose:** Auto-create a GitHub pull request with generated title and description.

**Flow:**

1. Detect default branch name. If on the default branch, warn the user and stop — they should use `/commit` or `/push` first to get onto a feature branch. (This diverges from `/commit` and `/push` which auto-create branches because a PR inherently needs an existing branch with commits to compare against.)
2. Check if a PR already exists for this branch via `gh pr view`. If so, report the existing PR URL and stop.
3. If the branch has unpushed commits or no upstream, push first (same logic as `/push` step 4)
4. Analyze all changes relative to the default branch via `git log <default>..HEAD` and `git diff <default>...HEAD`
5. Auto-generate:
   - PR title: short, under 70 characters
   - PR body with `## Summary` (bullet points) and `## Test plan` (checklist)
   - Footer: `Generated with [Claude Code](https://claude.com/claude-code)`
6. Create PR with `gh pr create --title "..." --body "..."`
7. Return the PR URL to the user

### `/globalize-project-skills`

**Purpose:** Copy project-local commands to the global `~/.claude/commands/` directory.

**Flow:**

1. Scan all `.md` files in the project's `.claude/commands/` directory
2. For each file, check if `~/.claude/commands/<filename>` already exists
3. If a conflict exists, show a diff between project and global versions and ask the user to overwrite, skip, or rename
4. Copy non-conflicting files and user-approved overwrites to `~/.claude/commands/`
5. Report what was copied, skipped, or overwritten

**Known limitation:** This is a one-way sync (project -> global). If you customize the global version, there is no mechanism to sync changes back to the project.

## Shared Patterns

### Default-Branch Detection

All commands that need to know the default branch use `git symbolic-ref refs/remotes/origin/HEAD` to detect it, falling back to `main` then `master` if that fails. This supports repositories using either convention.

### Default-Branch Protection

Used by `/commit` and `/push`. When on the default branch:

1. Analyze the diff to understand what changed (LLM reasoning step)
2. Generate a branch name using the branch naming rules below
3. Create and switch to the branch
4. Report the branch move to the user
5. Proceed with the original operation

`/pr` diverges: it stops with a warning instead of auto-creating a branch, because a PR needs an existing branch with committed history.

### Branch Name Generation

Branch names are auto-generated from the diff content (LLM reasoning step):

- Prefix: `feature/`, `fix/`, or `chore/` based on the nature of changes
- Suffix: short kebab-case summary of the change (3-6 words max)
- Example: `fix/quest-completion-when-target-defeated`

### Commit Message Generation

- Analyze staged diff (LLM reasoning step)
- Summarize the "why" not the "what"
- 1-2 sentences, concise
- Always append `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

### Secrets Safeguard

Before committing, scan staged files for patterns that suggest secrets (`.env`, `credentials`, `api_key`, `token`, `secret`). If found, warn the user and ask for confirmation. `.gitignore` is the primary guard; this is a secondary check.

## Implementation Notes

- Each skill is a standalone markdown file containing a prompt
- Skills use Claude Code's built-in tools (Bash for git commands, Read for file inspection)
- No external dependencies beyond `git` and `gh` (GitHub CLI)
- The `gh` CLI must be authenticated for `/pr` to work
- "LLM reasoning step" means Claude reads the relevant data and reasons about it to produce the output — there is no programmatic heuristic
