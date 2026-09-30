function Get-iTunesMediaLocation{
    <#
    .SYNOPSIS
        Returns the local path of the iTunes music folder.
    .DESCRIPTION
        Reads the "Music Folder" key from the iTunes library XML and converts the
        file:// URI it contains into a local Windows path. The module uses this to
        work out where the media lives instead of assuming a drive letter.
    .PARAMETER XmlLibrary
        The library XML to read. Defaults to the XML of the running iTunes application.
    .EXAMPLE
        Get-iTunesMediaLocation
    .NOTES
        Returns $null if the library XML has no "Music Folder" key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        $XmlLibrary = (Get-iTunesXmlLibrary)
    )

    $LocalPath = cleanLocalUri $XmlLibrary."Music Folder"

    return $LocalPath
}