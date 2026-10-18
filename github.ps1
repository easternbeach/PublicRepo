<#
.SYNOPSIS
Syncs this repository with its GitHub origin remote.
.DESCRIPTION
Fetches remote updates, fast-forwards when possible, stages all local changes
(including new files and deletions, except ignored files), commits, and pushes.
Stops if branches have diverged or incoming updates would overwrite local changes.
Requires Git, a configured Git identity, and access to origin.
.EXAMPLE
.\github.ps1 -Message "Update scripts"
#>
[CmdletBinding()]
param(
    [string]$Message = "Sync local changes $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz')"
)

$ErrorActionPreference = 'Stop'

# 1. Check that Git is installed, then work from this script's folder.
# Git errors must be checked explicitly using $LASTEXITCODE.
Get-Command git -ErrorAction Stop | Out-Null
Push-Location -LiteralPath $PSScriptRoot
try {
    # 2. Confirm this script is in the repository root and a branch is checked out.
    $repoRoot = & git rev-parse --show-toplevel
    if ($LASTEXITCODE -ne 0) { throw 'This folder is not a Git repository.' }
    if ((Resolve-Path -LiteralPath $repoRoot).Path -ne (Get-Location).Path) {
        throw 'github.ps1 must be in the repository root.'
    }

    $branch = & git symbolic-ref --quiet --short HEAD
    if ($LASTEXITCODE -ne 0) { throw 'Check out a branch before syncing.' }

    # 3. Stop if an earlier merge, rebase, or similar operation is unfinished.
    foreach ($state in 'MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply') {
        $statePath = & git rev-parse --git-path $state
        if ($LASTEXITCODE -ne 0) { throw 'Unable to inspect the repository state.' }
        if (Test-Path -LiteralPath $statePath) {
            throw 'Finish or abort the current Git operation before syncing.'
        }
    }

    # 4. Download the latest remote history without changing local files yet.
    Write-Host 'Fetching origin...'
    & git fetch origin
    if ($LASTEXITCODE -ne 0) { throw 'Fetching from origin failed.' }
    # --quiet returns 1 when this branch has not been pushed yet.
    & git show-ref --verify --quiet "refs/remotes/origin/$branch"
    $remoteStatus = $LASTEXITCODE
    if ($remoteStatus -gt 1) {
        throw 'Unable to inspect the remote branch.'
    }
    if ($remoteStatus -eq 0) {
        # 5. Check whether we already have all remote commits.
        # For these comparisons: 0 means yes, 1 means no, anything else is an error.
        & git merge-base --is-ancestor "origin/$branch" HEAD
        $remoteIncluded = $LASTEXITCODE
        if ($remoteIncluded -gt 1) { throw 'Unable to compare local and remote history.' }

        if ($remoteIncluded -eq 1) {
            & git merge-base --is-ancestor HEAD "origin/$branch"
            $localIncluded = $LASTEXITCODE
            if ($localIncluded -gt 1) { throw 'Unable to compare local and remote history.' }

            if ($localIncluded -eq 0) {
                # Move forward to the remote version. Git stops if local edits would be overwritten.
                & git merge --ff-only "origin/$branch"
                if ($LASTEXITCODE -ne 0) { throw 'Unable to apply remote updates. Check the Git output above.' }
            }
            else {
                throw 'Local and remote branches have diverged. Reconcile them before syncing.'
            }
        }
    }

    # 6. Stage all local changes, including new files and deletions.
    # Files excluded by .gitignore remain ignored.
    & git add --all
    if ($LASTEXITCODE -ne 0) { throw 'Staging local changes failed.' }

    # 7. Create a commit only when staged changes exist.
    & git diff --cached --quiet
    $diffStatus = $LASTEXITCODE
    if ($diffStatus -eq 1) {
        & git commit -m $Message
        if ($LASTEXITCODE -ne 0) { throw 'Committing local changes failed.' }
    }
    elseif ($diffStatus -eq 0) {
        Write-Host 'No local changes to commit.'
    }
    else {
        throw 'Unable to inspect staged changes.'
    }

    # 8. Upload local commits and set this branch to track the matching origin branch.
    # A normal push rejects conflicting remote updates; never force-push.
    & git push --set-upstream origin $branch
    if ($LASTEXITCODE -ne 0) { throw 'Pushing to origin failed. Local commits are still saved.' }
    Write-Host "Synced $branch with origin."
}
finally {
    # Return to the folder you were in before running this script, even after an error.
    Pop-Location
}
