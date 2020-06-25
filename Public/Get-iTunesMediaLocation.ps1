function Get-iTunesMediaLocation{
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $XmlLibrary = (Get-iTunesXmlLibrary)
    )

    $LocalPath = cleanLocalUri $XmlLibrary."Music Folder"

    return $LocalPath
}