# Git Workflow Skills Design

## Overview

Four Claude Code custom slash commands (`/commit`, `/pull`, `/push`, `/pr`) plus a `/globalize-project-skills` utility, designed to streamline common git workflows. All commands include a "protect main" pattern — operations that would modify main instead create a feature branch automatically.

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

**Purpose:** Auto-stage, auto-message, and commit — with main-branch protection.

**Flow:**

1. Run `git status` and `git branch` to detect current branch
2. If on `main`:
   - Analyze changes via `git diff` and `git diff --cached`
   - Auto-generate a descriptive branch name from the diff (e.g., `feature/add-route-3-wilderness`)
   - Create and switch to the branch (`git checkout -b <branch>`)
3. Stage all changes with `git add -A`
4. Analyze the staged diff and generate a concise commit message focused on the "why"
5. Commit with the generated message, including `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

### `/pull`

**Purpose:** Smart pull that preserves uncommitted work.

**Flow:**

1. Run `git status` to check for uncommitted changes
2. If dirty working tree:
   - `git stash` to save uncommitted changes
   - `git pull` to fetch and merge
   - `git stash pop` to re-apply changes
   - If stash pop has conflicts, notify the user and list conflicting files
3. If clean working tree:
   - `git pull`
4. Report summary: new commits pulled, files changed, stash status

### `/push`

**Purpose:** Push to remote with main-branch protection and auto-setup of upstream tracking.

**Flow:**

1. Detect current branch
2. If on `main`:
   - Analyze changes via `git diff` and `git diff --cached`
   - Auto-generate a branch name from the changes
   - Create and switch to the new branch (`git checkout -b <branch>`)
   - If there are uncommitted changes, stage and commit them (same logic as `/commit`)
3. If on a feature branch, proceed directly to push
4. Check if remote tracking branch exists — if not, push with `-u origin <branch>`
5. `git push`
6. Report what was pushed and to where

### `/pr`

**Purpose:** Auto-create a GitHub pull request with generated title and description.

**Flow:**

1. If on `main`, warn the user and stop — they should use `/commit` or `/push` first
2. If the branch has unpushed commits or no upstream, push first (same logic as `/push`)
3. Analyze all changes relative to main via `git log main..HEAD` and `git diff main...HEAD`
4. Auto-generate:
   - PR title: short, under 70 characters
   - PR body with `## Summary` (bullet points) and `## Test plan` (checklist)
   - Footer: `Generated with [Claude Code](https://claude.com/claude-code)`
5. Create PR with `gh pr create --title "..." --body "..."`
6. Return the PR URL to the user

### `/globalize-project-skills`

**Purpose:** Copy project-local commands to the global `~/.claude/commands/` directory.

**Flow:**

1. Scan all `.md` files in the project's `.claude/commands/` directory
2. For each file, check if `~/.claude/commands/<filename>` already exists
3. If a conflict exists, show a diff between project and global versions and ask the user to overwrite, skip, or rename
4. Copy non-conflicting files and user-approved overwrites to `~/.claude/commands/`
5. Report what was copied, skipped, or overwritten

## Shared Patterns

### Main-Branch Protection

Used by `/commit` and `/push`. When on `main`:

1. Analyze the diff to understand what changed
2. Generate a branch name: `feature/<short-kebab-description>` (e.g., `feature/fix-quest-completion-logic`)
3. Create and switch to the branch
4. Proceed with the original operation

### Branch Name Generation

Branch names are auto-generated from the diff content:

- Prefix: `feature/`, `fix/`, or `chore/` based on the nature of changes
- Suffix: short kebab-case summary of the change (3-6 words max)
- Example: `fix/quest-completion-when-target-defeated`

### Commit Message Generation

- Analyze staged diff
- Summarize the "why" not the "what"
- 1-2 sentences, concise
- Always append `Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>`

## Implementation Notes

- Each skill is a standalone markdown file containing a prompt
- Skills use Claude Code's built-in tools (Bash for git commands, Read for file inspection)
- No external dependencies beyond `git` and `gh` (GitHub CLI)
- The `gh` CLI must be authenticated for `/pr` to work
