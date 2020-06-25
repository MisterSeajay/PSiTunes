function Get-iTunesXmlLibraryTracks {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        $XmlLibrary = (Get-iTunesXmlLibrary)
    )

    $Tracks = New-Object -TypeName System.Collections.ArrayList

    foreach($Track in $XmlLibrary.Tracks.Keys){
        $obj = [PSCustomObject]$XmlLibrary.Tracks["$Track"]
        if($obj.Location){
            $obj.Location = cleanLocalUri $obj.Location
        }
        if($obj."Track Type" -ne "URL"){
            [void]$Tracks.Add($obj)
        }
    }

    return $Tracks
}