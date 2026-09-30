function Set-iTunesTrackRating {
    <#
    .SYNOPSIS
        Sets the rating on one or more iTunes tracks.
    .DESCRIPTION
        Sets the Rating attribute on each supplied track, skipping any track whose
        rating already matches. Accepts values either as user stars, 1 to 5, or
        as the 0-100 values iTunes stores internally. Accepts pipeline input.
    .PARAMETER Tracks
        The tracks to change. Accepts pipeline input. Defaults to the tracks currently selected in iTunes.
    .PARAMETER Rating
        The rating to set: 0 to 5 stars, or 0, 20, 40, 60, 80 or 100. Required.
    .EXAMPLE
        Get-iTunesSelectedTracks | Set-iTunesTrackRating -Rating 5
    .NOTES
        A value below 20 is multiplied by 20, so 5 stars becomes 100.
        The comparison is against the stored 0-100 value, so passing 100 and passing 5 both skip a track that is already at 100.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true,
            ValueFromPipelinebyPropertyName=$true)]
        [ValidateNotNullOrEmpty()]
        [System.Object[]]
        $Tracks = (Get-iTunesSelectedTracks),

        [Parameter(Mandatory=$true)]
        [ValidateSet(0,1,2,3,4,5,20,40,60,80,100)]
        [int]
        $Rating
    )

    BEGIN {
    }

    PROCESS {
        # Correct "user star" values 1-5 to the range 20-100. Done per pipeline
        # object rather than once up front, so a track never sees an already
        # multiplied rating.
        $EffectiveRating = if($Rating -lt 20){ $Rating * 20 } else { $Rating }

        foreach($Track in $Tracks){
            # Only write where the stored value differs, so repeated runs do not
            # touch tracks that do not need changing.
            if($Track.Rating -ne $EffectiveRating){
                Set-iTunesTrackData -Tracks $Track -Attribute Rating -Value $EffectiveRating
            }
        }
    }

    END {
    }
}

