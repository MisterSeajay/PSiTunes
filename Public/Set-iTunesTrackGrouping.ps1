function Set-iTunesTrackGrouping {
    <#
    .SYNOPSIS
        Adds and removes grouping tags on iTunes tracks.
    .DESCRIPTION
        Maintains the semicolon-separated Grouping field of each supplied track.
        Tags can be added and removed, and the track''s genre can optionally be
        included as tags as well. Tags are de-duplicated and sorted, and a track
        whose grouping already matches is left alone. Accepts pipeline input.
    .PARAMETER Tracks
        The tracks to change. Accepts pipeline input. Defaults to the tracks currently selected in iTunes.
    .PARAMETER Add
        Semicolon-separated tags to add.
    .PARAMETER Remove
        Semicolon-separated tags to remove.
    .PARAMETER IncludeGenre
        Also add the track's genre, split on spaces, as grouping tags.
    .EXAMPLE
        Get-iTunesSelectedTracks | Set-iTunesTrackGrouping -Add "Rip;2026"
    .EXAMPLE
        Get-iTunesPlaylistTracks -Playlist "Chillout" | Set-iTunesTrackGrouping -Remove "OldTag" -IncludeGenre
    .NOTES
        The grouping value is rewritten in full, sorted and de-duplicated, so existing tags are reordered.
        Both Add and Remove may contain several tags, separated by semicolons.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true)]
        [System.Object]
        $Tracks = (Get-iTunesSelectedTracks),

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Add,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Remove,

        [Parameter()]
        [switch]
        $IncludeGenre
    )

    BEGIN {
    }

    PROCESS {
        foreach($Track in $Tracks){
            if($Add){
                Write-Debug "Set-iTunesTrackGrouping: Adding: $Add"
            }

            if($Remove){
                Write-Debug "Set-iTunesTrackGrouping: Removing: $Remove"
            }

            # Copy existing grouping tags into new ArrayList
            $GroupingTags = New-Object -TypeName System.Collections.ArrayList
            foreach($GroupingTag in $Track.Grouping.Split(";")){
                if($GroupingTag -ne $Remove `
                        -and -not [string]::IsNullOrWhiteSpace($GroupingTag)){
                    [void]$GroupingTags.Add($GroupingTag)
                }
            }

            # Add new tags to grouping tags
            foreach($GroupingTag in $Add.Split(";")){
                if($GroupingTag -notin $GroupingTags `
                        -and -not [string]::IsNullOrWhiteSpace($GroupingTag)){
                    [void]$GroupingTags.Add($GroupingTag)
                }
            }

            if($IncludeGenre){
                # Copy genre into grouping tags
                $GenreTags = ($Track.Genre).Split(" ")
                foreach($GenreTag in $GenreTags){
                    if($GenreTag -notin $GroupingTags `
                            -and -not [string]::IsNullOrWhiteSpace($GenreTag)){
                        [void]$GroupingTags.Add($GenreTag)
                    }
                }
            }

            $NewGrouping = ($GroupingTags | Sort-Object -Unique) -join ";"
            $NewGrouping = $NewGrouping.Trim(";")

            if($Track.Grouping -ne $NewGrouping){
                # Write-Debug "Set-iTunesTrackGrouping: New Grouping is '$NewGrouping'"
                Set-iTunesTrackData -Tracks $Track -Attribute Grouping -Value $NewGrouping
            } else {
                Write-Debug "Set-iTunesTrackGrouping: No change"
            }
        }
    }

    END{
    }
}
