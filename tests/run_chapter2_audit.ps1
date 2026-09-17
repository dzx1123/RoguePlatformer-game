$ErrorActionPreference = 'Stop'
$projectRoot = 'D:\Godot\RoguePlatformer-game'
$enginePath = 'D:\Godot\Godot_v4.7.2-stable_win64.exe'
$checks = @('chapter2_design_smoke', 'chapter2_slice_smoke', 'chapter2_mid_smoke', 'chapter2_full_smoke', 'chapter2_route_smoke', 'chapter2_retry_smoke', 'chapter2_checkpoint_smoke', 'chapter2_entry_smoke', 'chapter2_game_entry_smoke', 'chapter2_controls_smoke', 'forge_ember_smoke', 'forge_guard_smoke', 'forge_beetle_smoke', 'forge_overseer_smoke', 'chapter2_platform_smoke')
$results = @()
foreach ($check in $checks) {
    $logPath = Join-Path $projectRoot "test_output/audit_$check.log"
    $process = Start-Process -FilePath $enginePath -ArgumentList '--headless', '--path', $projectRoot, '--script', "res://tests/$check.gd", '--log-file', $logPath -WindowStyle Hidden -PassThru
    $finished = $process.WaitForExit(240000)
    if (-not $finished) { Stop-Process -Id $process.Id }
    $log = if (Test-Path -LiteralPath $logPath) { [IO.File]::ReadAllText($logPath) } else { '' }
    $passed = $finished -and $process.ExitCode -eq 0 -and $log.Contains("${check}: PASS") -and -not $log.Contains('SCRIPT ERROR:')
    $results += [pscustomobject]@{test=$check; passed=$passed; log=$logPath}
    Write-Output "${check}: $passed"
}
$results | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $projectRoot 'test_output/chapter2_audit.json') -Encoding utf8
if ($results.Where({-not $_.passed}).Count -gt 0) { exit 1 }
