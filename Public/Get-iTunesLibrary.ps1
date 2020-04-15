function Get-iTunesLibrary {
    if(-not (Get-Variable | ?{$_.Name -eq "iTunesApplication"})){
        startiTunesApplication
    }
    
    return $iTunesApplication.LibraryPlaylist
}