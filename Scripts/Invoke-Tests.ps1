<#
.SYNOPSIS
    Runs the Pester tests and PSScriptAnalyzer for PSiTunes.
.DESCRIPTION
    The gate for a commit or a CI job. Exits non-zero if a test fails, if a test
    file cannot be parsed, or if PSScriptAnalyzer reports an Error.

    PSScriptAnalyzer runs at -Severity Error only. That is a deliberate starting
    threshold, not a considered one: the code currently has 0 errors and 66
    warnings, so gating on warnings would fail on the existing baseline. Per
    AGENTS.md 1.8, a threshold nobody has agreed to is not a gate, so the
    warning count is recorded in TODO.md rather than silently fixed or silently
    raised. Lowering the gate to Warning is a decision, not a side effect.

    The test run has been observed failing, so this gate has been seen red:
    sabotaging Private/convertToCapitalizedWords.ps1 gives 21 passed and 2
    failed with a non-zero exit, and a test file that cannot be parsed gives a
    failed container, which FailedCount alone would not catch.
.PARAMETER Path
    The test path to run. Defaults to the Tests folder at the repository root.
.PARAMETER Output
    Pester output verbosity: None, Normal, Detailed or Diagnostic.
.PARAMETER SkipAnalyzer
    Run only the tests. Useful while iterating on a change that is known to trip
    the analyzer, since the analyzer result is not a test failure.
.EXAMPLE
    .\Invoke-Tests.ps1
    Runs the tests and the analyzer, and reports a combined result.
.EXAMPLE
    .\Invoke-Tests.ps1 -SkipAnalyzer
    Runs only the tests.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]
    $Path,

    [Parameter()]
    [ValidateSet('None','Normal','Detailed','Diagnostic')]
    [string]
    $Output = 'Normal',

    [Parameter()]
    [switch]
    $SkipAnalyzer
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot

$problems = [System.Collections.Generic.List[string]]::new()

###################################################################################################
# Pester

if(-not $Path){
    $Path = Join-Path $RepoRoot 'Tests'
}

$pester = Get-Module -ListAvailable -Name Pester |
    Where-Object { $_.Version -ge [version]'5.0.0' } |
    Sort-Object Version -Descending |
    Select-Object -First 1

if(-not $pester){
    # Skipping silently would be indistinguishable from passing, so this is an
    # error rather than a warning. See AGENTS.md 1.8.
    Write-Error "Pester 5 or later is not installed, so the suite cannot run."
    Write-Error "Install it with: Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser"
    $problems.Add("Pester 5 or later is not installed. Nothing was tested.")
}
else {
    Write-Verbose "Using Pester $($pester.Version)"
    Import-Module Pester -MinimumVersion 5.0.0 -Force

    $configuration = New-PesterConfiguration
    $configuration.Run.Path = $Path
    # PassThru is not the default. Without it Invoke-Pester returns $null, every
    # count is $null, and a failing suite reports as a pass.
    $configuration.Run.PassThru = $true
    $configuration.Output.Verbosity = $Output

    try {
        $result = Invoke-Pester -Configuration $configuration
    }
    catch {
        Write-Error "Invoke-Pester failed to run: $($_.Exception.Message)"
        $problems.Add("Invoke-Pester failed to run: $($_.Exception.Message)")
        $result = $null
    }

    if($null -eq $result){
        $problems.Add("Invoke-Pester returned nothing. A null result cannot be told apart from a pass.")
    }
    else {
        # All three counters. A file that cannot be parsed reports a failed
        # container, not a failed test, so FailedCount alone reads 0 for a suite
        # that never ran.
        $failures = $result.FailedCount + $result.FailedContainersCount + $result.FailedBlocksCount

        Write-Host ("Tests: {0}  Passed: {1}  Failed: {2}  Skipped: {3}" -f `
            $result.TotalCount, $result.PassedCount, $result.FailedCount, $result.SkippedCount)

        if($result.FailedContainersCount -gt 0 -or $result.FailedBlocksCount -gt 0){
            Write-Host ("Container or block failures: {0} containers, {1} blocks" -f `
                $result.FailedContainersCount, $result.FailedBlocksCount) -ForegroundColor Red
            Write-Host "A test file that cannot be parsed reports a failed container, not a failed test." -ForegroundColor Yellow
        }

        if($failures -gt 0){
            $problems.Add("$failures test problem(s) found.")
        }

        if($result.TotalCount -eq 0){
            $problems.Add("No tests ran. A suite that collects nothing has verified nothing.")
        }
    }
}

###################################################################################################
# PSScriptAnalyzer

if($SkipAnalyzer){
    Write-Warning "PSScriptAnalyzer was skipped. That is not the same as it passing."
}
else {
    if(-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)){
        Write-Error "PSScriptAnalyzer is not installed, so the analyzer gate cannot run."
        $problems.Add("PSScriptAnalyzer is not installed. Nothing was analyzed.")
    }
    else {
        Import-Module PSScriptAnalyzer -ErrorAction Stop

        $analyzerPaths = @(
            Join-Path $RepoRoot 'Public'
            Join-Path $RepoRoot 'Private'
            Join-Path $RepoRoot 'Classes'
            Join-Path $RepoRoot 'Tests'
            Join-Path $RepoRoot 'Scripts'
            Join-Path $RepoRoot 'PSiTunes.psm1'
        ) | Where-Object { Test-Path -LiteralPath $_ }

        $findings = @()
        foreach($analyzerPath in $analyzerPaths){
            $findings += @(Invoke-ScriptAnalyzer -Path $analyzerPath -Recurse -Severity Error)
        }

        if($findings.Count -eq 0){
            Write-Host "PSScriptAnalyzer: 0 errors." -ForegroundColor Green
        }
        else {
            Write-Host "PSScriptAnalyzer: $($findings.Count) error(s)." -ForegroundColor Red
            $findings | ForEach-Object {
                Write-Host ("  {0}:{1}  {2}  [{3}]" -f `
                    (Split-Path $_.ScriptName -Leaf), $_.Line, $_.Message, $_.RuleName)
            }
            $problems.Add("$($findings.Count) PSScriptAnalyzer error(s).")
        }
    }
}

###################################################################################################
# Result

Write-Host ""
if($problems.Count -gt 0){
    Write-Host "FAILED:" -ForegroundColor Red
    foreach($problem in $problems){
        Write-Host "  - $problem" -ForegroundColor Red
    }
    exit 1
}

Write-Host "PASSED: tests and analyzer." -ForegroundColor Green
exit 0
