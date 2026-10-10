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
# git add does not reliably descend into another working tree. Store each
# selected source blob in the parent repository and explicitly index its path.
# The nested checkout and its .git metadata remain untouched.
$sourceModes = @{}
if ($sourceFiles.Count -gt 0) {
    $bridgeEntries = @(& git -c "safe.directory=$bridgePath" -C $bridgePath -c core.quotepath=false ls-files --stage)
    if ($LASTEXITCODE -ne 0) { throw 'Unable to read upstream file modes.' }
    foreach ($entry in $bridgeEntries) {
        if ($entry -match '^(100644|100755) [0-9a-f]+ 0\t(.+)$') {
            $sourceModes['figma-mcp-bridge/' + $Matches[2]] = $Matches[1]
        } else { throw "Unsupported upstream index entry: $entry" }
    }
}
foreach ($sourcePath in $sourceFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PSScriptRoot $sourcePath) -PathType Leaf)) {
        throw "Source file is missing from disk: $sourcePath"
    }
    $blobHash = Invoke-Git -GitArgs @('hash-object', '-w', "--path=$sourcePath", '--', $sourcePath)
    if ($blobHash -notmatch '^[0-9a-f]{40,64}$') { throw "Invalid Git blob hash for $sourcePath" }
    $fileMode = if ($sourceModes.ContainsKey($sourcePath)) { $sourceModes[$sourcePath] } else { '100644' }
    Invoke-Git -GitArgs @('update-index', '--add', '--cacheinfo', "$fileMode,$blobHash,$sourcePath")
}

# An empty bridge index is also invalid, even when no gitlink was added.
$requiredFiles = @(
    'figma-mcp-bridge/LICENSE.md',
    'figma-mcp-bridge/server/package.json',
    'figma-mcp-bridge/server/package-lock.json',
    'figma-mcp-bridge/server/tsconfig.json',
    'figma-mcp-bridge/server/src/index.ts',
    'figma-mcp-bridge/server/src/tools.ts',
    'figma-mcp-bridge/plugin/manifest.json',
    'figma-mcp-bridge/plugin/package.json',
    'figma-mcp-bridge/plugin/package-lock.json',
    'figma-mcp-bridge/plugin/src/main/code.ts',
    'figma-mcp-bridge/plugin/src/ui/App.tsx',
    'browser-tools/start-playwright.mjs',
    'setup-figma.ps1',
    'verify-figma.mjs',
    'skills/figma-site-audit/SKILL.md',
    'skills/figma-site-audit/assets/compare.html'
)
$indexedFiles = @(Invoke-Git -GitArgs @('-c', 'core.quotepath=false', 'ls-files'))
$missingFiles = @(($requiredFiles + $sourceFiles) | Sort-Object -Unique | Where-Object { $indexedFiles -cnotcontains $_ })
if ($missingFiles.Count -gt 0) {
    throw ('Publication stopped: required source files are missing from the index: ' + ($missingFiles -join ', '))
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
