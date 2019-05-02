function Get-iTunesPlaylistTracks {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [System.Object]$Playlist
  )
  
  if(-not $Playlist){
    $Playlist = Get-iTunesPlaylist
  }
  
  return $Playlist.Tracks
}
