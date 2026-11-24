$ErrorActionPreference = "Continue"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$root = Split-Path -Parent $PSScriptRoot
Push-Location $root

try {
    function Resolve-GodotExe {
        $pkgRoot = Join-Path $env:LOCALAPPDATA "Microsoft\WinGet\Packages"
        if (Test-Path $pkgRoot) {
            $candidates = Get-ChildItem -Path $pkgRoot -Directory -Filter "GodotEngine.GodotEngine_*" -ErrorAction SilentlyContinue
            foreach ($dir in $candidates) {
                $directExe = Get-ChildItem -Path $dir.FullName -Recurse -Filter "Godot_*win64.exe" -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -notlike "*console*.exe" } |
                    Select-Object -First 1
                if ($directExe) {
                    return $directExe.FullName
                }
            }
            foreach ($dir in $candidates) {
                $consoleExe = Get-ChildItem -Path $dir.FullName -Recurse -Filter "*console*.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
                if ($consoleExe) {
                    return $consoleExe.FullName
                }
            }
        }
        foreach ($cmdName in @("godot", "godot4", "godot_console")) {
            $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
            if ($cmd) {
                return $cmd.Source
            }
        }
        throw "Godot executable not found."
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

    function Invoke-Godot {
        param(
            [Parameter(Mandatory = $true)][string]$Executable,
            [Parameter(Mandatory = $true)][string]$WorkingDir,
            [Parameter(Mandatory = $true)][string[]]$Arguments,
            [int]$TimeoutSeconds = 120
        )

        $formattedArgs = ($Arguments | ForEach-Object {
            if ($_ -match '[\s"]') {
                '"' + ($_ -replace '"', '\"') + '"'
            } else {
                $_
            }
        }) -join ' '

        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $Executable
        $psi.Arguments = $formattedArgs
        $psi.WorkingDirectory = $WorkingDir
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

        $proc = New-Object System.Diagnostics.Process
        $proc.StartInfo = $psi
        [void]$proc.Start()

        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
        if (-not $exited) {
            try {
                $proc.Kill()
                [void]$proc.WaitForExit(3000)
            }
            catch {
            }
            throw "[FAIL] Godot timed out after ${TimeoutSeconds}s ($formattedArgs)"
        }

        $proc.WaitForExit()
        $stdout = $stdoutTask.Result
        $stderr = $stderrTask.Result

        $parts = @()
        if (-not [string]::IsNullOrEmpty($stdout)) {
            $parts += $stdout.TrimEnd("`r", "`n")
        }
        if (-not [string]::IsNullOrEmpty($stderr)) {
            $parts += $stderr.TrimEnd("`r", "`n")
        }
        $combined = $parts -join "`n"

        return [PSCustomObject]@{
            ExitCode = $proc.ExitCode
            StdOut   = $stdout
            StdErr   = $stderr
            Combined = $combined
        }
    }

    $godot = Resolve-GodotExe
    $gdlint = Resolve-Gdlint
    $reportsDir = Join-Path $root "reports"
    New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null
    $runLog = Join-Path $root "run.log"
    $gutXml = Join-Path $reportsDir "gut_results.xml"

    Write-Host "Using Godot: $godot"
    Write-Host "Using gdlint: $gdlint"

    Write-Host "`n[1/4] Godot headless --import..."
    $importRes = Invoke-Godot -Executable $godot -WorkingDir $root -Arguments @("--headless", "--path", ".", "--import") -TimeoutSeconds 120
    if (-not [string]::IsNullOrEmpty($importRes.Combined)) {
        ($importRes.Combined -split "\r?\n") | ForEach-Object { Write-Host $_ }
    }
    if ($importRes.ExitCode -ne 0) {
        Write-Error "[FAIL] Godot --import exited with code $($importRes.ExitCode)"
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
    $smokeRes = Invoke-Godot -Executable $godot -WorkingDir $root -Arguments @("--headless", "--path", ".", "--quit-after", "300") -TimeoutSeconds 60
    ($smokeRes.Combined -split "\r?\n") | Set-Content -Encoding UTF8 $runLog
    $smokeExit = $smokeRes.ExitCode
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
    $gutRes = Invoke-Godot -Executable $godot -WorkingDir $root -Arguments @(
        "--headless",
        "--path", ".",
        "-s", "addons/gut/gut_cmdln.gd",
        "-gdir=res://tests/gut",
        "-gexit",
        "-gcompact_mode",
        "-gjunit_xml_file=reports/gut_results.xml"
    ) -TimeoutSeconds 120
    if (-not [string]::IsNullOrEmpty($gutRes.Combined)) {
        ($gutRes.Combined -split "\r?\n") | ForEach-Object { Write-Host $_ }
    }
    $gutExit = $gutRes.ExitCode
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
