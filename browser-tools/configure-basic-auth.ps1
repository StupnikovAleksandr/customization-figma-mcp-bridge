param([switch]$SkipRegistration)
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$privateDir = Join-Path $PSScriptRoot '.local'
New-Item -ItemType Directory -Path $privateDir -Force | Out-Null
$sitePath = Join-Path $privateDir 'dev-site.json'
if (-not (Test-Path -LiteralPath $sitePath)) {
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'dev-site.example.json') -Destination $sitePath
}
Write-Host 'Enter the dev stand Basic Auth credentials. The URL can be configured later.'
$devLogin = Read-Host 'Basic Auth login'
if ([string]::IsNullOrWhiteSpace($devLogin)) { throw 'Login must not be empty.' }
$devPassword = Read-Host 'Basic Auth password' -AsSecureString
if ($devPassword.Length -eq 0) { throw 'Password must not be empty.' }
$devCredential = New-Object System.Management.Automation.PSCredential($devLogin, $devPassword)
$devCredential | Export-Clixml -LiteralPath (Join-Path $privateDir 'dev-credential.xml') -Encoding UTF8
Write-Host 'Credentials saved using Windows DPAPI (current Windows user on this PC).'

if (-not $SkipRegistration) {
    $nodeExe = (Get-Command node.exe -ErrorAction Stop).Source
    $codexExe = (Get-Command codex.cmd -ErrorAction Stop).Source
    # Codex updates only this MCP entry; keep a backup of the existing settings.
    $configDir = if ($env:CODEX_HOME) { $env:CODEX_HOME } else { Join-Path $env:USERPROFILE '.codex' }
    $configPath = Join-Path $configDir 'config.toml'
    if (Test-Path -LiteralPath $configPath) {
        Copy-Item -LiteralPath $configPath -Destination ($configPath + '.before-basic-auth-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.bak')
    }
    & $codexExe mcp add playwright -- $nodeExe (Join-Path $PSScriptRoot 'start-playwright.mjs')
    if ($LASTEXITCODE -ne 0) { throw 'MCP registration failed. Credentials are saved; rerun this script to retry.' }
    Write-Host 'Playwright MCP registered. Restart Codex to load the new connection.'
}
Write-Host ('Set the dev URL in: ' + $sitePath)
Write-Host 'Until the URL is set, Playwright runs without Basic Auth.'
