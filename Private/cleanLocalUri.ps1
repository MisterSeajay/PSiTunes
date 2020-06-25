function cleanLocalUri {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [uri]
        $Uri
    )

    $LocalPath = $Uri.LocalPath -replace [regex]::Escape("file://localhost/"),""
    $LocalPath = $LocalPath -replace [regex]::Escape("\\localhost\"),""
    return $LocalPath
}