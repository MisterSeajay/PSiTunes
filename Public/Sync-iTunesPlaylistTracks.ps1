function Sync-iTunesPlaylistTracks {
    <#
    .SYNOPSIS
        Synchronises duplicate tracks in a sync playlist.
    .DESCRIPTION
        Looks for artist and name combinations that appear more than once in a
        synchronisation playlist, and copies the highest play count across to
        every copy, so that the same track always shows the same play count and
        play date whichever entry is scrolled to. Combinations that are already in
        step are skipped.
    .PARAMETER Playlist
        The synchronisation playlist to process. Accepts pipeline input. Defaults to "Sync (All)", matched exactly.
    .EXAMPLE
        Sync-iTunesPlaylistTracks
    .EXAMPLE
        Sync-iTunesPlaylistTracks -Playlist "Sync (Podcasts)"
    .NOTES
        Warns about any artist and name combination found only once; that usually means a sync playlist entry is missing its partner.
        Changes play counts and play dates in the library, not the files on disk.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true,
            ValueFromPipelinebyPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [Alias("SyncPlaylist","Name")]
        [string]
        $Playlist = "Sync (All)"
    )

    $SyncTracks = (Get-iTunesPlaylist -Name $Playlist -ExactMatch).Tracks

    Write-Debug "$($SyncTracks.Count) track to synchronize from $Playlist"

    # Make a summary list of each distinct Artist and Track Name combination
    $SyncSummary = $SyncTracks | Select-Object Artist,Name | Sort-Object Artist,Name | Get-Unique -AsString

    Write-Debug "$($SyncSummary.Count) distinct Artist-Song combinations"

    foreach($Track in $SyncSummary){
        # Get the tracks matching this "item" in the SyncSummary (Artist and Track Name combination)
        $Tracks = $SyncTracks | ?{($_.Name -eq $Track.Name) -and ($_.Artist -eq $Track.Artist)}

        # Check whether we need to synchronize this Artist-Song combination
        $PlayedCount = $Tracks.PlayedCount | Measure-Object -Maximum -Minimum

        if($PlayedCount.Maximum -eq $PlayedCount.Minimum){
            Write-Verbose "$($Track.Artist) - $($Track.Name) is already in-sync; skipping"
            continue
        }

        # Only attempt to update entries in the SynchronizationList where there are more than one
        # tracks with the same Name and Artist.
        if($Tracks.Count -gt 1){
            if($PSCmdlet.ShouldProcess("$($Track.Artist) - $($Track.Name)","Set-iTunesTrackPlayedData")){
                Write-Verbose "Synchronizing $($Track.Artist) - $($Track.Name)"

                try {
                    $UpdatedTracks = Sync-iTunesTrackData -Tracks $Tracks -SyncPlayedData
                }
                catch {
                    throw
                    break
                }
            }
        } else {
            Write-Warning "Only 1 entry found for $($Track.Artist) - $($Track.Name)"
        }
    }
}
