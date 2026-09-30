function Sync-iTunesTrackData {
    <#
    .SYNOPSIS
        Copies metadata across duplicate iTunes tracks.
    .DESCRIPTION
        Takes two or more copies of the same track and makes their metadata agree.
        Each track is given the merged set of grouping tags from all of them, with
        unwanted tags such as B-Side and Sync removed, and is given the highest
        play count, latest play date and highest rating found across the group. A
        group is expected to be one artist and one song; a group that is not warns
        and is left alone unless Force is used.
    .PARAMETER Tracks
        The tracks to synchronise. Accepts pipeline input. Defaults to the tracks currently selected in iTunes.
    .PARAMETER SyncPlayedData
        Accepted for compatibility with Sync-iTunesPlaylistTracks. Play data is always synchronised.
    .PARAMETER FirstSync
        Sum the play counts across the group rather than taking the maximum, for the run that builds the initial sync.
    .PARAMETER Force
        Synchronise even when the group does not share a single artist and song.
    .EXAMPLE
        Get-iTunesSelectedTracks | Sync-iTunesTrackData
    .EXAMPLE
        Sync-iTunesTrackData -Tracks $tracks -FirstSync
    .NOTES
        Needs at least two tracks; warns and returns otherwise.
        Tags matching B-Side, Female, NoPlaylist, Purchased, Re-rip, SP or Sync are stripped from the merged grouping.
        This rewrites the Grouping field of every track in the group, so the tags are reordered and de-duplicated.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true)]
        [System.Object[]]
        $Tracks = (Get-iTunesSelectedTracks),

        [Parameter()]
        [switch]
        $SyncPlayedData,

        [Parameter()]
        [switch]
        $FirstSync,

        [Parameter()]
        [switch]
        $Force
    )

    if((-not $Tracks) -or ($Tracks.Count -lt 2)){
        Write-Warning "Sync-iTunesTrackData: Minimum 2 tracks needed for sync"
        return $null
    } elseif(-not $Force -and @($Tracks |
                Select-Object Artist,@{Label="ShortName";Expression={($_.Name.ToLower() -replace "\[.+\]","").Trim()}} |
                Sort-Object Artist,ShortName | Get-Unique -AsString).Count -gt 1){
        Write-Warning "Sync-iTunesTrackData: Name and Artist does not match for all tracks"
        Write-Debug ($Tracks | Select-Object -Property Name,Artist -Unique | Out-String)
        return $null
    } else {
        Write-Debug "Sync-iTunesTrackData: $($Tracks.Count) tracks"
    }

    # Gather all tags from each track
    $CombinedGroupings = $Tracks.Grouping -join ";"
    # Strip out tags that we don't want to include in the merge
    $UnwantedTagsRegex = "\b(B-Side|Female|NoPlaylist|Purchased|Re-rip|SP|Sync)\b"
    $CombinedGroupings = $CombinedGroupings -replace ($UnwantedTagsRegex,"")
    # Clean up string
    $CombinedGroupings = $CombinedGroupings -replace (";{2,}",";")
    $CombinedGroupings = $CombinedGroupings.Trim(";")

    $AddNoPlaylist = 0

    if($FirstSync){
        $PlayedCount = [Int32]($Tracks | Measure-Object -Property PlayedCount -Sum).Sum
    } else {
        $PlayedCount = [Int32]($Tracks | Measure-Object -Property PlayedCount -Maximum).Maximum
    }

    if($PlayedCount -eq 0){
        $PlayedDate = [DateTime]"1899-12-30"
    } else {
        $PlayedDate = [DateTime]($Tracks | Measure-Object -Maximum -Property PlayedDate).Maximum
    }

    $MaxRating = [Int32]($Tracks | Measure-Object -Maximum -Property Rating).Maximum

    $SortedTracks = $Tracks |
        Sort-Object @{e={$_.Grouping-match "rip"}; descending=$false}, Compilation, `
            @{e="Bitrate";descending=$true}, Year, Album

    foreach($Track in $SortedTracks){

        Write-Verbose "Sync-iTunesTrackData: Updating GROUPING for $(formatiTunesTrackInfo -Track $Track)"

        #######################################################################
        # Merge the grouping tags to each track
        #
        # If the AddNoPlaylist switch has been set (after the first run of this
        # loop) we add that tag, else we ensure that the tag is removed in case
        # it was set previously.
        #
        # After the first run through the list of tracks we set this flag to
        # ensure the rest of the list get the "NoPlaylist" tag added in their
        # grouping field.

        if($AddNoPlaylist){
            Set-iTunesTrackGrouping -Track $Track -Add "$CombinedGroupings;NoPlaylist;Sync"
        } else {
            Set-iTunesTrackGrouping -Track $Track -Add "$CombinedGroupings;Sync" -Remove "NoPlaylist"
        }

        $AddNoPlaylist = 1

        #######################################################################
        # Update other Metadata

        $Track | Set-iTunesTrackData -Attribute PlayedCount -Value $PlayedCount

        $Track | Set-iTunesTrackData -Attribute PlayedDate -Value $PlayedDate

        $Track | Set-iTunesTrackData -Attribute Rating -Value $MaxRating
    }
}
