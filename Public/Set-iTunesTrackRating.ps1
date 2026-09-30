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

    # Correct "user star" values 1-5 to the range 20-100
    if($Rating -lt 20){
        $Rating = $Rating * 20
    }

    foreach($Track in $Tracks){
        # Run a case-sensitive match to see if we need to change anything, as we don't want to waste
        # time updating tracks that don't need to change.
        if(-not($Track.Rating -eq $Rating)){
            Set-iTunesTrackData -Tracks $Track -Attribute Rating -Value $Rating
        }
    }
}

