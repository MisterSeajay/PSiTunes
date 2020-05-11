function stripPath {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Position = 0, Mandatory)]
        [string]
        $FullName,

        [Parameter(Position = 1)]
        [string]
        $RootPath = (Get-Location)
    )

    return ($FullName -replace "$([Regex]::Escape($RootPath))\\","")
}