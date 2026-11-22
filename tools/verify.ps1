$ErrorActionPreference = "Continue"

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

try {
    function Resolve-GodotConsole {
        $pkgRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
        if (Test-Path $pkgRoot) {
            $candidates = Get-ChildItem -Path $pkgRoot -Directory -Filter "GodotEngine.GodotEngine_*" -ErrorAction SilentlyContinue
            foreach ($dir in $candidates) {
                $consoleExe = Get-ChildItem -Path $dir.FullName -Recurse -Filter "*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($consoleExe) {
                    return $consoleExe.FullName
                }
            }
        }
        foreach ($cmdName in @("godot_console", "godot", "godot4")) {
            $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
            if ($cmd) {
                return $cmd.Source
            }
        }
        throw "Godot console executable not found."
    }

    function Resolve-Gdlint {
        $cmd = Get-Command "gdlint" -ErrorAction SilentlyContinue
        if ($cmd) {
            return $cmd.Source
        }
        $localBin = Join-Path $env:USERPROFILE ".local\bin\gdlint.exe"
        if (Test-Path $localBin) {
            return $localBin
        }
        throw "gdlint executable not found."
    }

    $godot = Resolve-GodotConsole
    $gdlint = Resolve-Gdlint
    $reportsDir = Join-Path $root "reports"
    New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
    $runLog = Join-Path $root "run.log"
    $gutXml = Join-Path $reportsDir "gut_results.xml"

    Write-Host "Using Godot: $godot"
    Write-Host "Using gdlint: $gdlint"

    Write-Host "`n[1/4] Godot headless --import..."
    & $godot --headless --path $root --import 2>&1 | ForEach-Object { "$_" }
    if ($LASTEXITCODE -ne 0) {
        Write-Error "[FAIL] Godot --import exited with code $LASTEXITCODE"
        exit 1
    }
    Write-Host "[PASS] Godot --import completed."

    Write-Host "`n[2/4] Running gdlint on scripts, scenes, tests..."
    $lintTargets = @("scripts", "scenes", "tests") | Where-Object { Test-Path (Join-Path $root $_) }
    if ($lintTargets.Count -gt 0) {
        & $gdlint @lintTargets 2>&1 | ForEach-Object { "$_" }
        if ($LASTEXITCODE -ne 0) {
            Write-Error "[FAIL] gdlint failed with code $LASTEXITCODE"
            exit 1
        }
    }
    Write-Host "[PASS] gdlint passed with 0 errors."

    Write-Host "`n[3/4] Running headless smoke test (--quit-after 300)..."
    & $godot --headless --path $root --quit-after 300 2>&1 | ForEach-Object { "$_" } | Set-Content -Encoding UTF8 $runLog
    $smokeExit = $LASTEXITCODE
    $errorHits = Select-String -Path $runLog -Pattern "SCRIPT ERROR|^ERROR:" -CaseSensitive
    if ($smokeExit -ne 0 -or $errorHits) {
        if ($errorHits) {
            Write-Host "Detected errors in run.log:"
            $errorHits | ForEach-Object { Write-Host $_.Line }
        }
        Write-Error "[FAIL] Headless smoke test failed (exit=$smokeExit)."
        exit 1
    }
    Write-Host "[PASS] Headless smoke test clean (0 SCRIPT ERROR / ERROR lines)."

    Write-Host "`n[4/4] Running GUT headless unit tests..."
    if (Test-Path $gutXml) {
        Remove-Item $gutXml -Force
    }
    & $godot --headless --path $root -s "addons/gut/gut_cmdln.gd" "-gdir=res://tests/gut" "-gexit" "-gcompact_mode" "-gjunit_xml_file=reports/gut_results.xml" 2>&1 | ForEach-Object { "$_" }
    $gutExit = $LASTEXITCODE
    if ($gutExit -ne 0) {
        Write-Error "[FAIL] GUT exited with code $gutExit"
        exit 1
    }
    if (-not (Test-Path $gutXml)) {
        Write-Error "[FAIL] GUT JUnit report missing: $gutXml"
        exit 1
    }

    $xmlRaw = Get-Content -Path $gutXml -Raw -Encoding UTF8
    [xml]$xmlDoc = $xmlRaw
    $suiteNode = $xmlDoc.testsuites
    if (-not $suiteNode) {
        $suiteNode = $xmlDoc.testsuite
    }
    $totalTests = [int]($suiteNode.tests)
    $totalFailures = [int]($suiteNode.failures)
    $totalErrors = [int]($suiteNode.errors)

    Write-Host "GUT JUnit summary: tests=$totalTests failures=$totalFailures errors=$totalErrors"
    if ($totalTests -lt 1 -or $totalFailures -ne 0 -or $totalErrors -ne 0) {
        Write-Error "[FAIL] GUT verification failed (tests=$totalTests, failures=$totalFailures, errors=$totalErrors)."
        exit 1
    }
    Write-Host "[PASS] All $totalTests GUT unit tests passed."
    exit 0
}
finally {
    Pop-Location
}
