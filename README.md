# Workspace

## Configuration

- [Claude Code settings](.claude/settings.json)

claude and gi token taken from environemtn variable and not stored in the container

`git remote set-url origin https://x-access-token:${GH_TOKEN_FAMILY}@github.com/pushq/familyInterviewer.git`
[System.Environment]::SetEnvironmentVariable("GH_TOKEN_FAMILY", "github_pat", "User")
