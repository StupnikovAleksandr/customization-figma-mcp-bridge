$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
# Called only by the local Node launcher. Never run this script to display secrets.
try {
    $devCredential = Import-Clixml -LiteralPath (Join-Path $PSScriptRoot '.local/dev-credential.xml')
    if ($devCredential -isnot [System.Management.Automation.PSCredential]) { throw 'Invalid credential file.' }
    @{
        username = $devCredential.UserName
        password = $devCredential.GetNetworkCredential().Password
    } | ConvertTo-Json -Compress
} catch {
    [Console]::Error.WriteLine('Unable to decrypt Basic Auth credentials. Run configure-basic-auth.ps1 as the current Windows user.')
    exit 1
}
