# Git Commands – Beginner Reference for Infrastructure Engineers
> Focus: Using Git to manage Terraform files and infrastructure scripts safely as a team.

---

## What is Git and Why Do You Need It?

When you write Terraform files, you are writing **code that controls real infrastructure** — servers, networks, storage. Git is a tool that:
- Saves every version of your files (like a detailed "undo history")
- Lets your team share and review changes before applying them
- Gives you a full audit trail of **who changed what, and when**

Think of it as **change control for your code**, the same way you raise a change request before touching production servers.

---

## One-Time Setup (Do This First, Ever)

```bash
git config --global user.name "Your Name"
git config --global user.email "you@company.com"
```
**Why:** Git stamps every change you make with your name and email. Without this, your commits are anonymous — unacceptable in a team audit trail.

---

## Section 1 — Starting a Project

### `git init`
```bash
git init
```
**What it does:** Turns any folder on your machine into a Git-tracked repository.  
**When to use:** Only once, when starting a brand-new project from scratch.  
**Example:** You create a folder called `azure-infra` for your Terraform files. Run `git init` inside it to start tracking.

---

### `git clone`
```bash
git clone https://github.com/your-org/azure-infra.git
```
**What it does:** Downloads a copy of an existing remote repository to your local machine.  
**When to use:** When joining a project that already exists — your most common starting point in a team.  
**Example:** Your senior engineer already set up the repo. You clone it to start working.

---

## Section 2 — Checking What's Happening

### `git status`
```bash
git status
```
**What it does:** Shows you which files have been changed, added, or deleted since the last save point.  
**When to use:** Run this constantly — before and after every action. It is your "where am I" command.  
**Think of it as:** Checking your change request list before submitting it.

---

### `git log`
```bash
git log
git log --oneline        # compact view — one line per change
```
**What it does:** Shows the full history of all saved changes, with author, date, and message.  
**When to use:** When you need to audit what changed, or find a previous working version.  
**Example:** "When did we add the NSG rule for port 443?" — run `git log` to find out.

---

### `git diff`
```bash
git diff
git diff main.tf         # see changes in a specific file only
```
**What it does:** Shows the exact line-by-line differences between your current edits and the last saved version.  
**When to use:** Before saving (committing) your work, to double-check you haven't introduced mistakes.  
**Think of it as:** A final review before signing off on a change.

---

## Section 3 — Saving Your Work

### `git add`
```bash
git add main.tf                 # stage one specific file
git add variables.tf outputs.tf # stage multiple files
git add .                       # stage ALL changed files in the folder
```
**What it does:** Marks files as "ready to be saved." Git calls this staging.  
**When to use:** After editing files, before running `git commit`.  
**Important:** `git add` does NOT save anything yet. It only prepares files for saving.

---

### `git commit`
```bash
git commit -m "Add storage account for audit logs in East US"
```
**What it does:** Permanently saves the staged files as a checkpoint in history.  
**When to use:** After `git add`, when your change is complete and tested locally.  
**The message matters:** Write a clear description of WHAT you changed and WHY. Bad: `"update"`. Good: `"Add NSG rule to allow HTTPS from corp IP range"`.  
**Think of it as:** Closing and signing a change record.

---

## Section 4 — Working with Remote Repos (GitHub / Azure DevOps)

### `git push`
```bash
git push origin main           # push your main branch
git push origin feature/nsg-rules  # push a feature branch
```
**What it does:** Uploads your local commits to the remote repository (GitHub, Azure DevOps, etc.) so the team can see them.  
**When to use:** After committing, when you are ready to share your work or raise a Pull Request.

---

### `git pull`
```bash
git pull
```
**What it does:** Downloads the latest changes from the remote repo and merges them into your local copy.  
**When to use:** At the start of every working session, before you touch any files.  
**Why it matters:** If a colleague pushed changes overnight and you don't pull first, your files are out of date — and you risk overwriting their work.

---

### `git fetch`
```bash
git fetch
```
**What it does:** Downloads the latest info from the remote repo but does NOT change your local files.  
**When to use:** When you want to check what's changed remotely before deciding to merge it in.  
**Difference from `git pull`:** Fetch = look but don't touch. Pull = look and apply.

---

## Section 5 — Branches (The Core of Safe Teamwork)

### `git branch`
```bash
git branch                     # list all branches
git branch feature/nsg-rules   # create a new branch
git branch -d feature/nsg-rules # delete a branch after merging
```
**What it does:** Branches let you work on a change in isolation, without touching the main production copy until it is reviewed.  
**Think of it as:** Working on a copy of the change request — the original is untouched until your copy is approved.

---

### `git checkout`
```bash
git checkout main                   # switch to the main branch
git checkout feature/nsg-rules      # switch to a feature branch
git checkout -b feature/storage-fix # create AND switch to a new branch in one step
```
**What it does:** Switches you between branches.  
**When to use:** Always create and switch to a new branch before starting any new piece of work. Never work directly on `main`.

---

### `git merge`
```bash
git checkout main
git merge feature/nsg-rules
```
**What it does:** Combines a finished branch back into main after review.  
**When to use:** After a Pull Request is approved. In most teams this is done via the GitHub/DevOps UI, not the command line.

---

## Section 6 — Fixing Mistakes

### `git restore`
```bash
git restore main.tf
```
**What it does:** Discards all unsaved edits to a file and reverts it to the last committed version.  
**When to use:** You made a mess of a file and want to start fresh from the last clean version.  
**Warning:** This is permanent for that file. Use with care.

---

### `git revert`
```bash
git revert abc1234    # abc1234 is the commit ID from git log
```
**What it does:** Creates a new commit that undoes a specific previous commit — without deleting history.  
**When to use:** Something broke in production. You need to roll back a change safely while keeping a full audit trail.  
**This is the safe, team-friendly undo.**

---

### `git stash`
```bash
git stash           # save your in-progress work temporarily
git stash pop       # bring it back
```
**What it does:** Temporarily shelves your uncommitted changes so you can switch tasks cleanly.  
**When to use:** You are mid-change on a feature and need to urgently switch to a different branch (e.g., hotfix needed). Stash your work, fix the urgent issue, then `git stash pop` to resume.

---

## Everyday Workflow — What a Normal Day Looks Like

```
1. git pull                          → get latest changes from team
2. git checkout -b feature/my-change → create your own branch
3. (edit your Terraform files)
4. git status                        → check what changed
5. git diff                          → review your changes line by line
6. git add .                         → stage your files
7. git commit -m "clear message"     → save your checkpoint
8. git push origin feature/my-change → upload to remote repo
9. Open a Pull Request in GitHub/DevOps for peer review
10. After approval → branch gets merged to main
```

---

## Quick Reference Table

| Command | Purpose | When to Run |
|---|---|---|
| `git config` | Set your name/email | Once, on first setup |
| `git clone` | Download existing repo | When joining a project |
| `git pull` | Get latest team changes | Start of every session |
| `git status` | See what has changed | Constantly |
| `git diff` | See exact line changes | Before every commit |
| `git checkout -b` | Create and switch to new branch | Before any new change |
| `git add` | Stage files for saving | After editing |
| `git commit -m` | Save a checkpoint with message | After staging |
| `git push` | Upload to remote repo | After committing |
| `git log --oneline` | View change history | For auditing |
| `git stash` | Temporarily shelve changes | When context-switching |
| `git restore` | Discard file edits | When you want to undo local mess |
| `git revert` | Safely undo a past commit | When rolling back in production |

---

## Key Rules to Never Break

1. **Never work directly on `main`.** Always create a branch.
2. **Always `git pull` before starting work.** Stale files cause conflicts.
3. **Write meaningful commit messages.** Your future self and your team will thank you.
4. **Commit small and often.** One logical change per commit — easier to review and revert.
5. **Never commit secrets.** No passwords, API keys, or connection strings in your Terraform files or Git history.
