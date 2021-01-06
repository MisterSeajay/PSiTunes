function Sync-iTunesTrackData {
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
