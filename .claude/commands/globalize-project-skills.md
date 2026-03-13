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
