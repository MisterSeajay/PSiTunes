function Get-iTunesLibraryXml {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([xml])]
    param(
        [Parameter()]
        $Path = $iTunesApplication.LibraryXMLPath
    )

    if($PSCmdlet.ShouldProcess($Path,"Get-Content")){
        [xml]$iTunesLibraryXml = Get-Content $Path -Raw
    } else {
        $iTunesLibraryXml = $null
    }

    if($iTunesLibraryXml){
        New-Object PSObject (parsePlistDict $iTunesLibraryXml.plist.dict)
    }
}
