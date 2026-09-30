function Get-iTunesXmlLibraryTracks {
    <#
    .SYNOPSIS
        Returns the tracks described in the iTunes library XML.
    .DESCRIPTION
        Returns one object per track from the parsed library XML, with file
        locations converted from file:// URIs to local paths. Tracks of type URL
        are omitted, since they have no file on disk.
    .PARAMETER XmlLibrary
        The parsed library XML to read. Defaults to the output of Get-iTunesXmlLibrary.
    .EXAMPLE
        Get-iTunesXmlLibraryTracks
    .NOTES
        URL tracks are excluded because they have no local file.
        This is much faster than iterating the library through automation, and is the way to get every track on a large library.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [System.Object]
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