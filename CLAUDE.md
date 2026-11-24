# Isrotel devcontainer

## Pull the latest changes before working on code

Whenever work on code starts (reading, changing or reviewing it, a bug, a feature, a PR), bring these repos up to date:

- always `Isrotel.Umb/` and `Isrotel.Services/` (`/workspace/Isrotel.Umb`, `/workspace/Isrotel.Services` in the devcontainer), whichever repo the work is in;
- also the repo the work or its PR is in, when it's another one.

In each repo:

1. `git fetch --all --prune`.
2. If the current branch tracks a remote and the working tree is clean, `git pull --ff-only`.
3. If the working tree has uncommitted changes, or the pull can't fast-forward, don't stash, reset or merge: tell the user what's there and ask how to proceed.
4. For new work (a bug fix or feature), branch from the latest remote base branch, not from whatever is checked out locally:
   - repos with `versions/v_N` branches (`Isrotel.Umb`, `Isrotel.Services`, `Isrotel.Sunclub`, `Isrotel.Sceduler`): the highest `origin/versions/v_N`;
   - other repos: the remote default branch (e.g. `origin/main`, `origin/master`).
5. `Isrotel.Umb`: work in the main checkout (`Isrotel.Umb/`), never in a separate worktree. The local IIS site `dev.isrotel.co.il` (127.0.0.1 in the hosts file) serves `Isrotel.Umb/Isrotel.UWeb`, so only the main checkout can be tested there. After switching branches, rebuild `Isrotel.UWeb/Isrotel.UWeb.csproj` in Debug.

Say which branch and commit you're working from.

The local dev site (the English `dev.isrotel.com`, startup failures, Git on Windows, browser quirks): `isrotel-workspace/project/knowledge-base/uweb-mapping/local-dev-site.md`.

## Session title for Azure DevOps work items and PRs

When the user gives a link to an Azure DevOps work item (`dev.azure.com/Isrotel/.../_workitems/edit/<id>`) or a pull request (`.../_git/<repo>/pullrequest/<id>`), or the session's work is about one, rename this session with `set_session_title` (`session_id: "self"`) as soon as you know the item's title:

- work item (task, bug, user story, feature): `<id> - <short title>`, e.g. `9010 - Agent request passthrough to legacy agents`;
- pull request: `PR <id> - <short title>`, e.g. `PR 4703 - Code review`.

The short title is the item's title in ADO (or the PR's), trimmed to a few words in English; read it with the Azure DevOps tools, don't guess it. Several items in one session: name the main one. A fork or side session keeps the same title with a suffix that says what it does (`8504 - Bug (fork)`). Don't rename a session whose title the user set by hand unless they ask.

## The vault is the home

Whatever folder this session started in, and whichever tool runs it (the desktop app on Windows or VS Code in the devcontainer), the results of the work go to the vault in `isrotel-workspace/`, under `isrotel-workspace/project/vault-conventions.md`: a dated section in this month's journal, `current-focus.md` when state changed, an ADR per decision, `#task` lines, knowledge-base updates. Do it without being asked.

- A session that started in `isrotel-workspace/` follows its own `CLAUDE.md` (save after every response).
- Any other session (code, Azure DevOps, Claude Docs or Artifacts) writes to the vault once, when its piece of work ends. Work kept in Claude (Docs, Artifacts, chat-only results) comes in through the vault's `pull-claude-work-sync` skill.
- Before writing, run `git status` in `isrotel-workspace/`. If it shows changes this session didn't make, another session is writing: tell the user what's there and ask before writing.
- Never commit in the vault; the user reviews and commits.
