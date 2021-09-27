function Set-iTunesTrackGrouping {
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
