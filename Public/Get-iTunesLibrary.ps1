function Get-iTunesLibrary {
    if(-not (Get-Variable | Where-Object {$_.Name -eq "iTunesApplication"})){
        Start-iTunes
    }
    
    return $iTunesApplication.LibraryPlaylist
}