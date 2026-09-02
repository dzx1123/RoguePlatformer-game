param(
    [string]$GodotExecutable = 'D:\Godot\Godot_v4.7.2-stable_win64.exe',
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release'
)

$ErrorActionPreference = 'Stop'
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).Path
$buildDirectory = Join-Path $projectRoot 'build\windows-verify'
$executablePath = Join-Path $buildDirectory 'MoonEclipseCorridor.exe'
$exportLog = Join-Path $buildDirectory 'export.log'
$runtimeLog = Join-Path $buildDirectory 'launch-smoke.log'
New-Item -ItemType Directory -Path $buildDirectory -Force | Out-Null

if (-not (Test-Path -LiteralPath $GodotExecutable -PathType Leaf)) {
    throw "Godot executable not found: $GodotExecutable"
}

$exportFlag = if ($Configuration -eq 'Release') { '--export-release' } else { '--export-debug' }
$exportArguments = @(
    '--headless',
    '--path', $projectRoot,
    '--log-file', $exportLog,
    $exportFlag,
    '"Windows Desktop"',
    $executablePath
)
$exportProcess = Start-Process -FilePath $GodotExecutable -ArgumentList $exportArguments -WindowStyle Hidden -Wait -PassThru
if ($exportProcess.ExitCode -ne 0) {
    $exportText = if (Test-Path -LiteralPath $exportLog) { Get-Content -Raw -LiteralPath $exportLog } else { '' }
    throw "Godot export failed with exit code $($exportProcess.ExitCode):`n$exportText"
}
if (-not (Test-Path -LiteralPath $executablePath -PathType Leaf)) {
    throw "Export did not create $executablePath"
}

$launchArguments = @(
    '--headless',
    '--rendering-method', 'gl_compatibility',
    '--quit-after', '120',
    '--log-file', $runtimeLog
)
$process = Start-Process -FilePath $executablePath -ArgumentList $launchArguments -WindowStyle Hidden -Wait -PassThru
if ($process.ExitCode -ne 0) {
    throw "Exported game exited with code $($process.ExitCode)"
}
if (-not (Test-Path -LiteralPath $runtimeLog -PathType Leaf)) {
    throw 'Exported game did not produce a launch log.'
}
$runtimeText = Get-Content -Raw -LiteralPath $runtimeLog
if ($runtimeText -match '(?m)^ERROR:') {
    throw "Exported game log contains an engine error:`n$runtimeText"
}

$artifact = Get-Item -LiteralPath $executablePath
Write-Output "Windows build verified: $($artifact.FullName) ($($artifact.Length) bytes)"
