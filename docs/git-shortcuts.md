# Git Shortcuts Cheat Sheet

Custom Claude Code slash commands for streamlined git workflows.

## Commands

| Command | What it does |
|---------|-------------|
| `/commit` | Stage all changes, generate a commit message, and commit |
| `/pull` | Pull with automatic stash/unstash of uncommitted work |
| `/push` | Push to remote with upstream auto-setup |
| `/pr` | Create a GitHub PR with auto-generated title and description |
| `/globalize-project-skills` | Copy these commands to `~/.claude/commands/` for use in all projects |

## `/commit`

Stages everything, generates a commit message from the diff, and commits.

**Main-branch protection:** If you're on `main`/`master`, it auto-creates a feature branch from the diff before committing.

```
/commit
```

- Auto-stages all changes
- Scans for secrets before committing
- Generates a "why"-focused commit message
- Adds `Co-Authored-By` trailer

## `/pull`

Pulls latest changes, preserving any uncommitted work.

```
/pull
```

- If you have uncommitted changes: stashes, pulls, then pops the stash
- If stash pop conflicts: reports the conflicting files
- Respects your git config (merge vs rebase)

## `/push`

Pushes the current branch to remote.

**Main-branch protection:** If you're on `main`/`master`, it auto-creates a feature branch, commits any uncommitted changes, then pushes.

```
/push
```

- Auto-creates upstream tracking if needed (`-u origin <branch>`)
- Commits uncommitted changes if on the default branch

## `/pr`

Creates a GitHub pull request for the current branch.

```
/pr
```

- Pushes unpushed commits first if needed
- Auto-generates PR title and description from commits/diff
- Reports the PR URL
- Requires `gh` CLI to be authenticated

**Note:** Won't work from `main` — use `/commit` or `/push` first to get on a feature branch.

## `/globalize-project-skills`

Copies all project commands to your global `~/.claude/commands/` directory so they work in every project.

```
/globalize-project-skills
```

- Shows diffs for conflicting files
- Asks before overwriting
- One-way sync: project -> global only
