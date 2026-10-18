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

function Invoke-Git {
    param([Parameter(ValueFromRemainingArguments = $true)][string[]]$GitArguments)
    & git @GitArguments
    if ($LASTEXITCODE -ne 0) {
        throw "Git failed (exit $LASTEXITCODE): git $($GitArguments -join ' ')"
    }
}

function Test-GitAncestor {
    param([string]$Ancestor, [string]$Descendant)
    & git merge-base --is-ancestor $Ancestor $Descendant
    if ($LASTEXITCODE -gt 1) {
        throw 'Unable to compare local and remote history.'
    }
    return ($LASTEXITCODE -eq 0)
}

Get-Command git -ErrorAction Stop | Out-Null
Push-Location -LiteralPath $PSScriptRoot
try {
    $repoRoot = Invoke-Git rev-parse --show-toplevel
    if ((Resolve-Path -LiteralPath $repoRoot).Path -ne (Get-Location).Path) {
        throw 'github.ps1 must be in the repository root.'
    }

    $branch = Invoke-Git symbolic-ref --quiet --short HEAD
    foreach ($state in 'MERGE_HEAD', 'CHERRY_PICK_HEAD', 'REVERT_HEAD', 'rebase-merge', 'rebase-apply') {
        $statePath = Invoke-Git rev-parse --git-path $state
        if (Test-Path -LiteralPath $statePath) {
            throw 'Finish or abort the current Git operation before syncing.'
        }
    }

    Write-Host 'Fetching origin...'
    Invoke-Git fetch origin
    # --quiet returns 1 when this branch has not been pushed yet.
    & git show-ref --verify --quiet "refs/remotes/origin/$branch"
    $remoteStatus = $LASTEXITCODE
    if ($remoteStatus -gt 1) {
        throw 'Unable to inspect the remote branch.'
    }
    if ($remoteStatus -eq 0) {
        if (-not (Test-GitAncestor "origin/$branch" HEAD)) {
            if (Test-GitAncestor HEAD "origin/$branch") {
                Invoke-Git merge --ff-only "origin/$branch"
            }
            else {
                throw 'Local and remote branches have diverged. Reconcile them before syncing.'
            }
        }
    }

    Invoke-Git add --all
    & git diff --cached --quiet
    $diffStatus = $LASTEXITCODE
    if ($diffStatus -eq 1) {
        Invoke-Git commit -m $Message
    }
    elseif ($diffStatus -eq 0) {
        Write-Host 'No local changes to commit.'
    }
    else {
        throw 'Unable to inspect staged changes.'
    }

    # A normal push rejects conflicting remote updates; never force-push.
    Invoke-Git push --set-upstream origin $branch
    Write-Host "Synced $branch with origin."
}
finally {
    Pop-Location
}
