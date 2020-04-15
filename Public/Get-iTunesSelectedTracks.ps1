function Get-iTunesSelectedTracks {
    if(-not $iTunesApplication){
        Write-Error "iTunes not loaded"
        return $false
    } else {
        $iTunesSelectedTracks = $iTunesApplication.SelectedTracks
        
        if(-not $iTunesSelectedTracks){
            Write-Warning "No tracks selected"
            return $null
        } else {
            return $iTunesSelectedTracks
        }
    }
}
