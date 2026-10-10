$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Set-Location $PSScriptRoot
$workspacePath = $PSScriptRoot.Replace('\', '/')
$bridgePath = (Join-Path $PSScriptRoot 'figma-mcp-bridge').Replace('\', '/')
$targetRemote = 'https://github.com/StupnikovAleksandr/customization-figma-mcp-bridge.git'
function Invoke-Git {
    param([string[]]$GitArgs)
    & git -c "safe.directory=$workspacePath" @GitArgs
    if ($LASTEXITCODE -ne 0) { throw "Git failed: $($GitArgs -join ' ')" }
}

if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot '.git'))) {
    Invoke-Git -GitArgs @('init')
}
Invoke-Git -GitArgs @('branch', '-M', 'main')
$remotes = @(Invoke-Git -GitArgs @('remote'))
if ($remotes -contains 'origin') {
    $currentRemote = Invoke-Git -GitArgs @('remote', 'get-url', 'origin')
    if ($currentRemote -ne $targetRemote) { throw 'origin points to another repository. Update it explicitly before publishing.' }
} else {
    Invoke-Git -GitArgs @('remote', 'add', 'origin', $targetRemote)
}

# Add workspace files without turning the upstream checkout into a gitlink.
Invoke-Git -GitArgs @('add', '--all', '--', '.', ':!figma-mcp-bridge')
$sourceFiles = @()
if (Test-Path -LiteralPath (Join-Path $PSScriptRoot 'figma-mcp-bridge/.git')) {
    $bridgeFiles = @(& git -c "safe.directory=$bridgePath" -C $bridgePath -c core.quotepath=false ls-files --cached --others --exclude-standard)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to list upstream source files.' }
    $sourceFiles = @($bridgeFiles | ForEach-Object { 'figma-mcp-bridge/' + $_ })
} else {
    Invoke-Git -GitArgs @('add', '--all', '--', 'figma-mcp-bridge')
}
for ($offset = 0; $offset -lt $sourceFiles.Count; $offset += 50) {
    $last = [Math]::Min($offset + 49, $sourceFiles.Count - 1)
    Invoke-Git -GitArgs (@('add', '--') + @($sourceFiles[$offset..$last]))
}

$stagedPaths = @(Invoke-Git -GitArgs @('diff', '--cached', '--name-only'))
if ($stagedPaths | Where-Object { $_ -match '(^|/)(audit-[^/]*|reports|\.local|node_modules|dist|\.npm-cache|\.playwright-mcp)/|(^|/)\.env($|\.)|\.local\.json$' }) {
    throw 'Unexpected private or generated files in the index. Review git diff --cached before publishing.'
}
$entries = @(Invoke-Git -GitArgs @('ls-files', '--stage', '--', 'figma-mcp-bridge'))
if ($entries | Where-Object { $_ -match '^160000 ' }) { throw 'Bridge was staged as a gitlink; source files must be included instead.' }
Invoke-Git -GitArgs @('diff', '--cached', '--stat')
if ($stagedPaths.Count -gt 0) {
    & git -c "safe.directory=$workspacePath" rev-parse --verify --quiet HEAD | Out-Null
    $commitMessage = if ($LASTEXITCODE -eq 0) { 'Update audit workspace and documentation' } else { 'first commit' }
    Invoke-Git -GitArgs @('commit', '-m', $commitMessage)
}
Invoke-Git -GitArgs @('push', '-u', 'origin', 'main')
