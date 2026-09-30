function Find-iTunesDuplicatedTracks {
    <#
    .SYNOPSIS
        Finds duplicated tracks in a set of iTunes tracks.
    .DESCRIPTION
        Groups the supplied tracks by artist and name and returns the name of every
        group that has more than one member. Tracks whose Grouping field matches
        "Sync" are excluded, so synchronisation copies of a track are not reported
        as duplicates of the original.
    .PARAMETER Tracks
        The tracks to examine. Accepts pipeline input. Defaults to the tracks currently selected in iTunes.
    .EXAMPLE
        Find-iTunesDuplicatedTracks -Tracks (Get-iTunesPlaylistTracks -Playlist "Chillout")
    .EXAMPLE
        Get-iTunesSelectedTracks | Find-iTunesDuplicatedTracks
    .NOTES
        Returns the name of each duplicated group, not the tracks themselves.
        Duplicate is determined by artist and name only. Two different releases of the same song by the same artist are reported as duplicates.
    #>
    [CmdletBinding()]
    param(
        [Parameter(
            ValueFromPipeline=$true,
            ValueFromPipelinebyPropertyName=$true)]
        [System.Object[]]
        $Tracks = (Get-iTunesSelectedTracks)
    )

    Write-Verbose "Searching for duplicates over $($Tracks.Count) tracks"

    return ($Tracks |
        Where-Object {$_.Grouping -notmatch "Sync"} |
        Group-Object -Property Artist,Name |
        Where-Object {$_.Count -gt 1}).Name
}
