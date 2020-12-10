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
        $DataFromTagLib = $DataFromTagLib |
            Add-Member -MemberType NoteProperty -Name Location -Value $TagLibFile.Name -PassThru |
            Add-Member -MemberType NoteProperty -Name MediaType -Value $TagLibFile.Properties.MediaTypes -PassThru |
            Add-Member -MemberType NoteProperty -Name BitRate -Value $TagLibFile.Properties.AudioBitRate -PassThru
        Write-Output $DataFromTagLib
    }

    END {}
}
