param([Parameter(Mandatory = $true)][string]$ClientPath)
$ErrorActionPreference = 'Stop'
# Run with WoW closed. Keep the original files and never replace newer settings.
$accountPath = Join-Path (Resolve-Path -LiteralPath $ClientPath).Path 'WTF/Account'
if (-not (Test-Path -LiteralPath $accountPath -PathType Container)) {
    throw 'No WTF/Account directory found in the supplied WoW client directory.'
}
Get-ChildItem -LiteralPath $accountPath -Directory | ForEach-Object {
    $savedPath = Join-Path $_.FullName 'SavedVariables'
    $oldPath = Join-Path $savedPath 'InkTrail.lua'
    $newPath = Join-Path $savedPath 'CraftTrail.lua'
    if ((Test-Path -LiteralPath $oldPath -PathType Leaf) -and -not (Test-Path -LiteralPath $newPath)) {
        $settings = [IO.File]::ReadAllText($oldPath)
        $settings = [regex]::Replace($settings, '(?m)^InkTrailDB(?=\s*=)', 'CraftTrailDB')
        [IO.File]::WriteAllText($newPath, $settings, [Text.UTF8Encoding]::new($false))
        Write-Output 'Migrated saved window settings for one account; original preserved.'
    }
}
