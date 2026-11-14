param(
    [switch]$BuildOnly,
    [string]$Device
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$projectParent = Split-Path -Parent $projectRoot
$projectName = Split-Path -Leaf $projectRoot
$driveName = $null
if (-not ('WellSpentBuildDrives' -as [type])) {
    Add-Type @'
using System.Runtime.InteropServices;
using System.Text;
public static class WellSpentBuildDrives {
    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    public static extern uint QueryDosDevice(string name, StringBuilder target, int size);
}
'@
}

# Keep this mapping after the command: Flutter caches absolute build paths.
# Reuse our existing mapping and never replace another drive's mapping.
foreach ($candidate in @('V', 'W', 'X', 'Y', 'Z')) {
    # Query the Unicode API; subst.exe text output can garble Korean paths.
    $target = New-Object System.Text.StringBuilder 32768
    $length = [WellSpentBuildDrives]::QueryDosDevice("${candidate}:", $target, $target.Capacity)
    if ($length -gt 0 -and $target.ToString().StartsWith('\??\')) {
        $mappedParent = $target.ToString().Substring(4)
        if ($mappedParent.TrimEnd('\') -ieq $projectParent.TrimEnd('\')) {
            $driveName = $candidate
            break
        }
    }
}
if (-not $driveName) {
    foreach ($candidate in @('V', 'W', 'X', 'Y', 'Z')) {
        if (-not (Get-PSDrive -Name $candidate -ErrorAction SilentlyContinue)) {
            & subst.exe "${candidate}:" $projectParent
            if ($LASTEXITCODE -ne 0) { throw 'Could not create the build drive.' }
            $driveName = $candidate
            break
        }
    }
}
if (-not $driveName) { throw 'No free build drive is available in V: through Z:.' }

$buildRoot = "${driveName}:\$projectName"
if ($buildRoot -match '[^\x00-\x7F]') { throw 'The project folder name must contain ASCII characters only.' }
Write-Host "Android project path: $buildRoot"
Push-Location -LiteralPath $buildRoot
try {
    if ($BuildOnly) {
        & flutter build apk --debug
    } elseif ($Device) {
        & flutter run -d $Device
    } else {
        & flutter run
    }
    $commandExit = $LASTEXITCODE
} finally {
    Pop-Location
}
exit $commandExit
