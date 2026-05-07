param(
    [int]$Frames = 2,
    [switch]$VerboseLog
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Join-Path (Split-Path -Parent $scriptDir) "src"
$godotPath = "G:\03_Software\IDEs\Godot_v4.6-stable_win64\Godot_v4.6-stable_win64.exe"
$logPath = Join-Path (Split-Path -Parent $scriptDir) "godot_validate.log"

if (-not (Test-Path $godotPath)) {
    Write-Error "Godot executable not found: $godotPath"
}

$arguments = @(
    "--headless"
    "--path", $projectRoot
    "--quit-after", $Frames
    "--log-file", $logPath
)

if ($VerboseLog) {
    $arguments += "--verbose"
}

$duration = Measure-Command {
    & $godotPath @arguments 2>&1 | Out-Null
}

Write-Output ("validate_ms=" + [math]::Round($duration.TotalMilliseconds, 2))
Write-Output ("frames=" + $Frames)
Write-Output ("log=" + $logPath)

# Check log for errors
if (Test-Path $logPath) {
    $errors = Select-String -Path $logPath -Pattern "ERROR|SCRIPT ERROR|Parse Error" -SimpleMatch
    if ($errors) {
        Write-Output "ERRORS_FOUND:"
        $errors | ForEach-Object { Write-Output $_.Line }
        exit 1
    } else {
        Write-Output "OK - no errors"
    }
}
