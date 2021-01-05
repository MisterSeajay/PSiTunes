function Set-iTunesTrackGrouping {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true)]
        [System.Object]
        $Track = (Get-iTunesSelectedTracks),

        [Parameter(
            Mandatory=$true,
            ParameterSetName="Add")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Add,

        [Parameter(
            Mandatory=$true,
            ParameterSetName="Remove")]
        [ValidateNotNullOrEmpty()]
        [string]
        $Remove
    )

    BEGIN {
    }
    
    PROCESS {
        # Get the current list of items in the Grouping field, or the Genre if it isn't set
        if ($Add -and ($Track.Grouping -match "\b$Add\b")) {
            Write-Debug "Set-iTunesTrackGrouping: Grouping already contains $Add (No Change)"
            return

        } elseif ($Remove -and ($Track.Grouping -notmatch "\b$Remove\b")) {
            Write-Debug "Set-iTunesTrackGrouping: Grouping doesn't contain $Remove (No Change)"
            return

        }
        
        $GroupingTags = New-Object -TypeName System.Collections.ArrayList
        
        foreach($GroupingTag in $Track.Grouping){
            if($GroupingTag -ne $Remove){
                [void]$GroupingTags.Add($GroupingTag)
            }
        }
        
        Write-Debug "Set-iTunesTrackGrouping: Existing grouping:`n$($GroupingTags | Out-String)"
        
        # Add the genre, splitting multi-word genres and removing non-alphabertic characters
        $GenreTags = ($Track.Genre).Split(" ") -replace ('\W','')
        
        foreach($GenreTag in $GenreTags){
            if($GenreTag -notin $GroupingTags){
                Write-Debug "Set-iTunesTrackGrouping: Adding Genre ($GenreTag) to Grouping Tags"
                [void]$GroupingTags.Add($GenreTag)
            }
        }

        if($Add){
            Write-Debug "Set-iTunesTrackGrouping: Adding $Add to Grouping Tags"
            [void]$GroupingTags.Add($Add)
        }
        
        $NewGrouping = $GroupingTags -join ";"
        Write-Debug "Set-iTunesTrackGrouping: New Grouping is '$NewGrouping'"

        # Update the track Grouping field
        Set-iTunesTrackData -Tracks $Track -Attribute Grouping -Value $NewGrouping
    }
    
    END{
    }
}
