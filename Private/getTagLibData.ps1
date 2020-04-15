function getTagLibData {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string]
        $Path
    )

    $TagLibFile = [TagLib.File]::Create((Resolve-Path -LiteralPath $Path))
    Write-Output $TagLibFile.Tag
    # $TagLibFile.Close()
}
    