
function Get-iTunesFileLocations {
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