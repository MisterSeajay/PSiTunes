function Get-iTunesLibrary {
    <#
    .SYNOPSIS
        Returns the iTunes library playlist.
    .DESCRIPTION
        Returns the LibraryPlaylist object from the running iTunes application. This
        is a live automation object rather than a snapshot, so it is only valid
        while iTunes is running and reflects the library as it changes.
    .EXAMPLE
        Get-iTunesLibrary
    .EXAMPLE
        (Get-iTunesLibrary).Tracks.Count
    .NOTES
        Importing the module already starts iTunes and populates $iTunesLibrary, so calling this is only necessary if you need the object in a fresh scope.
        The returned object is a COM reference. Do not hold on to it after iTunes has exited.
    #>
    [CmdletBinding()]
    [OutputType([System.__ComObject])]
    param()

    if(-not (Get-Variable | Where-Object {$_.Name -eq "iTunesApplication"})){
        Start-iTunes
    }

    return $iTunesApplication.LibraryPlaylist
}