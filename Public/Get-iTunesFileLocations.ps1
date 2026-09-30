
function Get-iTunesFileLocations {
    <#
    .SYNOPSIS
        Reads the file locations of every track from the iTunes library XML.
    .DESCRIPTION
        Reads the iTunes library XML and returns one object per track, each with a
        Track ID and a Location. The XML stores both keys in a single flat
        dictionary, so they are interleaved and matched up here rather than read
        separately.
    .PARAMETER iTunesLibraryXml
        The library XML to read. Defaults to the XML of the running iTunes application.
    .EXAMPLE
        Get-iTunesFileLocations
    .NOTES
        Reading the library XML does not require walking the library through automation, so this is much faster than iterating iTunesLibrary.Tracks on a large library.
        Returns objects, not strings, so the result can be filtered or sorted.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([psobject])]
    param(
        [Parameter()]
        [System.Xml.XmlDocument]
        $iTunesLibraryXml = (Get-iTunesLibraryXML)
    )

    try {
        $iTunesLibraryDict = $iTunesLibraryXml.plist.dict.dict.dict
    } catch {
        $iTunesLibraryDict = $iTunesLibraryXml.plist[1].dict.dict.dict
        #Write-Warning ($iTunesLibraryXml.plist[1] | Format-List | Out-String)
        #return $null
    }

    $XmlCount = $iTunesLibraryDict.Count
    $Counter = 0

    $iTunesFileLocations = $iTunesLibraryDict | Foreach-Object {
        $Counter++
        Write-Progress -Activity "Reading XML dictionary" `
            -CurrentOperation "$Counter of $XmlCount" `
            -PercentComplete [math]::floor($XmlCount/$Counter)

        $ht=@{}

        $_.SelectNodes('key') | Where-Object {$_.'#text' -in ("Track ID","Location")} |
            Foreach-Object { $ht[$_.'#text'] = $_.NextSibling.'#text' }

        New-Object psobject -Property $ht
    }

    Write-Progress -Activity "Reading XML dictionary" -Completed

    return $iTunesFileLocations
}