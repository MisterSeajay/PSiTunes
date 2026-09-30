function Get-iTunesPlaylistTracks {
    <#
    .SYNOPSIS
        Returns the tracks in an iTunes playlist.
    .DESCRIPTION
        Returns the tracks of the supplied playlist. If no playlist is supplied,
        finds one by name, which means a playlist whose name matches a regular
        expression.
    .PARAMETER Playlist
        The playlist to read. Defaults to the first playlist found by Get-iTunesPlaylist.
    .EXAMPLE
        Get-iTunesPlaylistTracks -Playlist (Get-iTunesPlaylist -Name "Chillout" -ExactMatch)
    .NOTES
        Returns live automation objects, not a snapshot.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [System.Object]$Playlist
    )

    if(-not $Playlist){
        $Playlist = Get-iTunesPlaylist
    }

    return $Playlist.Tracks
}
