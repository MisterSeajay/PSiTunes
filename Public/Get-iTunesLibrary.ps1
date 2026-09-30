function Get-iTunesLibrary {
    [CmdletBinding()]
    [OutputType([System.__ComObject])]
    param()

    if(-not (Get-Variable | Where-Object {$_.Name -eq "iTunesApplication"})){
        Start-iTunes
    }

    return $iTunesApplication.LibraryPlaylist
}