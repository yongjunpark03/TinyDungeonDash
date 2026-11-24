param(
    [switch]$Gpu
)

$ErrorActionPreference = "Stop"
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
        }
        foreach ($cmdName in @("godot", "godot4", "godot_console")) {
            $cmd = Get-Command $cmdName -ErrorAction SilentlyContinue
            if ($cmd) {
                return $cmd.Source
            }
        }
        throw "Godot executable not found."
    }

    $godot = Resolve-GodotExe
    $reportsDir = Join-Path $root "reports"
    New-Item -ItemType Directory -Force -Path $reportsDir | Out-Null

    $argsList = @()
    if (-not $Gpu) {
        $argsList += "--headless"
    }
    $argsList += @("--path", ".", "-s", "scripts/cli_benchmark_runner.gd")

    $formattedArgs = ($argsList | ForEach-Object {
        if ($_ -match '[\s"]') {
            '"' + ($_ -replace '"', '\"') + '"'
        } else {
            $_
        }
    }) -join ' '

    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $godot
    $psi.Arguments = $formattedArgs
    $psi.WorkingDirectory = $root
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $psi.StandardErrorEncoding = [System.Text.Encoding]::UTF8

    Write-Host "Running Godot CLI benchmark ($godot)..."
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $psi
    [void]$proc.Start()

    $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
    $stderrTask = $proc.StandardError.ReadToEndAsync()
    $exited = $proc.WaitForExit(180000)
    if (-not $exited) {
        try {
            $proc.Kill()
            [void]$proc.WaitForExit(3000)
        }
        catch {
        }
        throw "[FAIL] Benchmark timed out after 180s."
    }

    $proc.WaitForExit()
    $stdout = $stdoutTask.Result
    $stderr = $stderrTask.Result

    if (-not [string]::IsNullOrEmpty($stdout)) {
        ($stdout -split "\r?\n") | ForEach-Object { Write-Host $_ }
    }
    if (-not [string]::IsNullOrEmpty($stderr)) {
        ($stderr -split "\r?\n") | ForEach-Object { Write-Host $_ }
    }

    if ($proc.ExitCode -ne 0) {
        throw "[FAIL] Benchmark runner exited with code $($proc.ExitCode)."
    }

    $reportMd = Join-Path $reportsDir "benchmark_report.md"
    $reportJson = Join-Path $reportsDir "benchmark_results.json"
    if (-not (Test-Path $reportMd) -or -not (Test-Path $reportJson)) {
        throw "[FAIL] Benchmark report artifacts were not generated."
    }

    Write-Host "`n[PASS] Benchmark report saved to: $reportMd"
    exit 0
}
finally {
    Pop-Location
}
