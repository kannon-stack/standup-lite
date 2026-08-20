# Run in Cursor's integrated terminal (not the agent shell)
# 1. Sign in to GitHub
gh auth login --hostname github.com --git-protocol https --web

# 2. Create the repo and push
Set-Location $PSScriptRoot
gh repo create standup-lite --org agk-builds --public --source=. --remote=origin --push --description "A tiny async standup board — test whether written updates can replace the daily meeting."
