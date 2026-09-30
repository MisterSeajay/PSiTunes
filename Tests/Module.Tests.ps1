<#
.SYNOPSIS
    Structural tests for the exported commands.
.DESCRIPTION
    These check the module's shape rather than its behaviour, so they need no
    iTunes and no library. They parse the files under Public/ directly instead
    of importing the module, because importing runs PSiTunes.psm1, which starts
    iTunes.

    The help test is the one AGENTS.md 1.8 asks for: a public function losing
    its help block, its .SYNOPSIS, or a .PARAMETER entry should fail the build.
    All 23 commands currently pass, so the test starts green; the point is that
    a new undocumented parameter fails from now on.

    Two AST details from AGENTS.md 1.4 bite here and are handled explicitly:
    GetHelpContent() returns $null on the file-level ScriptBlockAst and must be
    called on the FunctionDefinitionAst, and the parser upper-cases the help
    parameter keys while that dictionary is case-sensitive on lookup.
#>

BeforeAll {
    $script:TestFile = $PSCommandPath
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $script:TestFile)
    $script:PublicFolder = Join-Path $script:RepoRoot 'Public'
    $script:Manifest = Join-Path $script:RepoRoot 'PSiTunes.psd1'

    if(-not (Test-Path -LiteralPath $script:PublicFolder)){
        throw "Cannot find the Public folder at '$script:PublicFolder'."
    }

    # Parse each file once and keep the function AST, so the tests do not re-parse.
    $script:Functions = @{}
    Get-ChildItem -Path $script:PublicFolder -Filter '*.ps1' -File | ForEach-Object {
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile(
            $_.FullName, [ref]$null, [ref]$errors)

        # Assert the file parses, so a syntax error is never reported as a
        # missing-help failure.
        if(@($errors).Count -gt 0){
            throw "$($_.Name) has $($errors.Count) parse error(s): $(@($errors)[0].Message)"
        }

        $functionAst = $ast.Find({
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
        }, $true)

        if($functionAst){
            $script:Functions[$_.BaseName] = $functionAst
        }
    }
}

Describe 'Public folder structure' {

    It 'found a function in every file under Public' {
        $files = @(Get-ChildItem -Path $script:PublicFolder -Filter '*.ps1' -File)
        $files.Count | Should -BeGreaterThan 0
        $script:Functions.Count | Should -Be $files.Count -Because 'one function per file, per AGENTS.md 1.2'
    }

    It 'names every file after the function it contains' {
        foreach($name in $script:Functions.Keys){
            $expectedName = $name
            $script:Functions[$name].Name | Should -Be $expectedName
        }
    }

    It 'gives every public function an approved verb' {
        # AGENTS.md 1.2: the verb must come from the Get-Verb list. Written as a
        # filter over -Verb rather than Get-Verb -Name, which does not exist in
        # Windows PowerShell 5.1 and is a binding error rather than an empty
        # result there.
        $approved = @(Get-Verb -Verb * | ForEach-Object { $_.Verb })

        $problems = [System.Collections.Generic.List[string]]::new()
        foreach($file in $script:Functions.Keys){
            $functionName = $script:Functions[$file].Name
            $verb = $functionName -split '-', 2 | Select-Object -First 1
            if($verb -notin $approved){
                $problems.Add("$functionName : verb '$verb' is not in the Get-Verb list")
            }
        }

        ($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
    }
}

Describe 'comment-based help' {

    It 'binds a help block to every public function' {
        $problems = [System.Collections.Generic.List[string]]::new()
        foreach($file in $script:Functions.Keys){
            $help = $script:Functions[$file].GetHelpContent()
            if(-not $help){
                $problems.Add("$file : no help block bound to the function")
            }
        }

        ($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
    }

    It 'gives every public function a synopsis, a description and an example' {
        $problems = [System.Collections.Generic.List[string]]::new()
        foreach($file in $script:Functions.Keys){
            $help = $script:Functions[$file].GetHelpContent()
            if(-not $help){ continue }

            if([string]::IsNullOrWhiteSpace($help.Synopsis)){
                $problems.Add("$file : .SYNOPSIS is empty")
            }
            if([string]::IsNullOrWhiteSpace($help.Description)){
                $problems.Add("$file : .DESCRIPTION is empty")
            }
            if(@($help.Examples).Count -lt 1){
                $problems.Add("$file : no .EXAMPLE")
            }
        }

        ($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
    }

    It 'documents every declared parameter, and documents nothing that is not declared' {
        $problems = [System.Collections.Generic.List[string]]::new()

        foreach($file in $script:Functions.Keys){
            $functionAst = $script:Functions[$file]
            $help = $functionAst.GetHelpContent()
            if(-not $help){ continue }

            $declared = @($functionAst.Body.ParamBlock.Parameters |
                ForEach-Object { $_.Name.VariablePath.UserPath })

            # The parser upper-cases these keys, so normalise both sides.
            $documented = @($help.Parameters.Keys | ForEach-Object { $_.ToLower() })

            foreach($parameter in $declared){
                if($parameter.ToLower() -notin $documented){
                    $problems.Add("$file : parameter `$$parameter has no .PARAMETER entry")
                }
            }

            foreach($parameter in $documented){
                if($parameter -notin @($declared | ForEach-Object { $_.ToLower() })){
                    $problems.Add("$file : .PARAMETER $parameter is documented but not declared")
                }
            }
        }

        ($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
    }
}

Describe 'parameter binding' {

    It 'declares CmdletBinding on every public function' {
        $problems = [System.Collections.Generic.List[string]]::new()
        foreach($file in $script:Functions.Keys){
            $attributes = $script:Functions[$file].Body.ParamBlock.Attributes
            $hasCmdletBinding = $attributes |
                Where-Object { $_.TypeName.Name -eq 'CmdletBinding' }

            if(-not $hasCmdletBinding){
                $problems.Add("$file : no [CmdletBinding()] on the function's attribute list")
            }
        }

        ($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
    }

    It 'gives every public parameter a type' {
        # An untyped parameter becomes [object], which pushes casts downstream.
        $problems = [System.Collections.Generic.List[string]]::new()
        foreach($file in $script:Functions.Keys){
            $parameters = $script:Functions[$file].Body.ParamBlock.Parameters
            foreach($parameter in $parameters){
                $attributes = $parameter.Attributes |
                    Where-Object { $_ -is [System.Management.Automation.Language.TypeConstraintAst] }

                if(-not $attributes){
                    $problems.Add("$file : parameter `$$($parameter.Name.VariablePath.UserPath) has no type constraint")
                }
            }
        }

        ($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
    }
}

Describe 'module manifest' {

    BeforeAll {
        $script:ManifestData = Import-PowerShellDataFile -LiteralPath $script:Manifest
    }

    It 'exports exactly the functions found in Public' {
        $exported = @($script:ManifestData.FunctionsToExport)
        $onDisk = @($script:Functions.Values | ForEach-Object { $_.Name } | Sort-Object)

        $exported.Count | Should -Be $onDisk.Count
        Compare-Object ($exported | Sort-Object) $onDisk | Should -BeNullOrEmpty
    }

    It 'does not use a wildcard for FunctionsToExport' {
        # A wildcard matches on name shape, so a private helper ever named
        # Verb-Noun would be exported by accident.
        $script:ManifestData.FunctionsToExport | Should -Not -Be '*'
        $script:ManifestData.FunctionsToExport | Should -Not -Be '*-*'
    }

    It 'passes Test-ModuleManifest' {
        { Test-ModuleManifest -Path $script:Manifest -ErrorAction Stop } | Should -Not -Throw
    }

    It 'has a LicenseUri that does not name a deleted branch' {
        $licenseUri = $script:ManifestData.PrivateData.PSData.LicenseUri
        $licenseUri | Should -Not -BeNullOrEmpty
        $licenseUri | Should -Not -Match '/blob/master/' -Because 'the default branch is main and master no longer exists'
    }
}
