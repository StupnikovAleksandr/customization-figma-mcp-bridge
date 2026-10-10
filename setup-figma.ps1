$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$taskRoot = $PSScriptRoot
$repo = Join-Path $taskRoot 'figma-mcp-bridge'
$nodeExe = (Get-Command node.exe -ErrorAction Stop).Source
$npmExe = (Get-Command npm.cmd -ErrorAction Stop).Source
$codexExe = (Get-Command codex.cmd -ErrorAction Stop).Source
function Invoke-Checked {
    param([string]$Executable, [string[]]$Arguments)
    & $Executable @Arguments
    if ($LASTEXITCODE -ne 0) { throw "Command failed ($LASTEXITCODE): $Executable $($Arguments -join ' ')" }
}
$nodeVersionText = & $nodeExe --version
if ($LASTEXITCODE -ne 0) { throw 'Unable to read Node.js version.' }
if ($nodeVersionText -notmatch '^v(\d+)\.') { throw "Unexpected Node.js version: $nodeVersionText" }
if ([int]$Matches[1] -lt 20) { throw 'Node.js 20 or newer is required.' }
foreach ($part in @('server', 'plugin')) {
    Push-Location (Join-Path $repo $part)
    try {
        Invoke-Checked -Executable $npmExe -Arguments @('install', '--no-audit', '--no-fund')
        if ($part -eq 'plugin') { Invoke-Checked -Executable $npmExe -Arguments @('run', 'typecheck') }
        Invoke-Checked -Executable $npmExe -Arguments @('run', 'build')
    } finally { Pop-Location }
}
$browserDir = Join-Path $taskRoot 'browser-tools'
New-Item -ItemType Directory -Path $browserDir -Force | Out-Null
Push-Location $browserDir
try {
    if (-not (Test-Path 'package.json')) {
        '{"name":"local-figma-browser-tools","private":true}' | Set-Content 'package.json' -Encoding ASCII
    }
    Invoke-Checked -Executable $npmExe -Arguments @('install', '--save-exact', '@playwright/mcp', '--no-audit', '--no-fund')
    $previousNodeOptions = $env:NODE_OPTIONS
    try {
        $nodeHelp = & $nodeExe --help
        if ($nodeHelp -match '--use-system-ca') {
            $env:NODE_OPTIONS = ($previousNodeOptions + ' --use-system-ca').Trim()
        }
        Invoke-Checked -Executable $nodeExe -Arguments @((Join-Path $browserDir 'node_modules\@playwright\mcp\cli.js'), 'install-browser', 'chrome-for-testing')
    } finally { $env:NODE_OPTIONS = $previousNodeOptions }
} finally { Pop-Location }
$codexDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
$configPath = Join-Path $codexDir 'config.toml'
if (Test-Path -LiteralPath $configPath) {
    Copy-Item -LiteralPath $configPath -Destination ($configPath + '.before-figma-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bak')
}
Invoke-Checked -Executable $codexExe -Arguments @('mcp', 'add', 'figma-bridge', '--', $nodeExe, (Join-Path $repo 'server\dist\index.js'))
# Preserve an existing browser integration instead of replacing its settings.
$existingConfig = if (Test-Path $configPath) { Get-Content -Raw -LiteralPath $configPath } else { '' }
if ($existingConfig -notmatch '(?m)^\[mcp_servers\.playwright\]') {
    Invoke-Checked -Executable $codexExe -Arguments @('mcp', 'add', 'playwright', '--', $nodeExe, (Join-Path $browserDir 'node_modules\@playwright\mcp\cli.js'), '--browser', 'chromium')
} else { Write-Host 'Existing playwright MCP configuration preserved.' }
Invoke-Checked -Executable $nodeExe -Arguments @((Join-Path $taskRoot 'verify-figma.mjs'))
Invoke-Checked -Executable $codexExe -Arguments @('mcp', 'list')
Write-Host ''
Write-Host 'Setup complete. Restart Codex, then import this manifest in Figma Desktop:'
Write-Host (Join-Path $repo 'plugin\manifest.json')
