function Get-iTunesXmlLibrary {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([xml])]
    param(
        [Parameter()]
        $Path = $iTunesApplication.LibraryXMLPath
    )

    if($PSCmdlet.ShouldProcess($Path,"Get-Content")){
        [xml]$iTunesLibraryXml = Get-Content -Raw -LiteralPath $Path
    } else {
        $iTunesLibraryXml = $null
    }

    $ItunesLibraryXML.plist | Foreach-Object {
        if($_.PSObject.Properties.Name -contains "dict"){
            Write-Output (New-Object PSObject (parsePlistDict $_.dict))
        }
    }
}