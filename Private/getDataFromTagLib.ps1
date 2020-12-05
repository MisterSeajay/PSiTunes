function getDataFromTagLib {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string]
        $Path
    )

    BEGIN {}

    PROCESS {
        $TagLibFile = [TagLib.File]::Create((Resolve-Path -LiteralPath $Path))
        $DataFromTagLib =  $TagLibFile.Tag
        $DataFromTagLib = $DataFromTagLib | Add-Member -MemberType NoteProperty -Name Location -Value $Path -PassThru
        Write-Output $DataFromTagLib
    }

    END {}
}
    