param(
    [int]$Frames = 2,
    [switch]$VerboseLog
)

$ErrorActionPreference = "Stop"

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent $scriptDir
$projectRoot = Join-Path $repoRoot "src"
$godotPath = "G:\03_Software\IDEs\Godot_v4.6-stable_win64\Godot_v4.6-stable_win64.exe"
$logPath = Join-Path $repoRoot "godot_validate.log"
$errorPatterns = @("ERROR", "SCRIPT ERROR", "Parse Error", "Parser Error")

if (-not (Test-Path $godotPath)) {
    Write-Error "Godot executable not found: $godotPath"
}

function Get-ValidationErrors {
    param([string]$Path)
    if (-not (Test-Path $Path)) {
        return @()
    }
    return Select-String -Path $Path -Pattern $errorPatterns
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

# Check main scene log for errors.
$errors = Get-ValidationErrors $logPath
if ($errors) {
    Write-Output "ERRORS_FOUND:"
    $errors | ForEach-Object { Write-Output $_.Line }
    exit 1
}

# Parse every script directly. Booting only the main scene does not catch scripts
# that are loaded later through NPC panels, chests, or generated scene nodes.
$scriptFiles = Get-ChildItem -Path (Join-Path $projectRoot "scripts") -Filter "*.gd" | Sort-Object Name
foreach ($scriptFile in $scriptFiles) {
    $scriptPath = "res://scripts/$($scriptFile.Name)"
    $scriptResult = & $godotPath "--headless" "--path" $projectRoot "--check-only" "--script" $scriptPath 2>&1
    if ($LASTEXITCODE -ne 0 -or ($scriptResult -match "ERROR|SCRIPT ERROR|Parse Error|Parser Error")) {
        Write-Output "SCRIPT_CHECK_FAILED: $scriptPath"
        $scriptResult | ForEach-Object { Write-Output $_ }
        exit 1
    }
}
Write-Output ("script_check_count=" + $scriptFiles.Count)

# Load every scene briefly so scene resources and _ready paths are covered.
$sceneFiles = Get-ChildItem -Path (Join-Path $projectRoot "scenes") -Filter "*.tscn" | Sort-Object Name
foreach ($sceneFile in $sceneFiles) {
    $scenePath = "res://scenes/$($sceneFile.Name)"
    $sceneName = [System.IO.Path]::GetFileNameWithoutExtension($sceneFile.Name)
    $sceneLogPath = Join-Path $repoRoot ("godot_validate_scene_" + $sceneName + ".log")
    Remove-Item -LiteralPath $sceneLogPath -ErrorAction SilentlyContinue

    & $godotPath "--headless" "--path" $projectRoot $scenePath "--quit-after" $Frames "--log-file" $sceneLogPath 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
        Write-Output "SCENE_CHECK_FAILED: $scenePath"
        if (Test-Path $sceneLogPath) {
            Get-Content $sceneLogPath
        }
        exit 1
    }

    $sceneErrors = Get-ValidationErrors $sceneLogPath
    if ($sceneErrors) {
        Write-Output "SCENE_ERRORS_FOUND: $scenePath"
        $sceneErrors | ForEach-Object { Write-Output $_.Line }
        exit 1
    }

    Remove-Item -LiteralPath $sceneLogPath -ErrorAction SilentlyContinue
}
Write-Output ("scene_check_count=" + $sceneFiles.Count)
Write-Output "OK - no errors"
