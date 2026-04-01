# Workspace

## Configuration

- [Claude Code settings](.claude/settings.json)

## Defences

- All of them set in the dockerfile and devcontainer.json so the .devContainer folder is set to readonly, claude wont be able to modify files from withtin the wsl contianer

- GH pat token taken from environment variable and not stored in the container, the token should give permission to modify only sepecific repo not all your GH repos so the communication
  `git remote set-url origin https://x-access-token:${GH_TOKEN_FAMILY}@github.com/pushq/familyInterviewer.git`

- Container cannot use any ssh from windows

## Requires

- Docker desktop

- [System.Environment]::SetEnvironmentVariable("GH_TOKEN_FAMILY", "github_pat", "User")

- before starting the devcontainer in devcontainer.json file
  change the `https://oauth2:${GH_PAT_FAMILY}@{PUT_YOUR_GH_REPO_URL_HERE}.git` , for example `https://oauth2:${GH_PAT_FAMILY}@github.com/pushqin/mytestrepo.git`
