function Set-iTunesTrackRating {
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
        # time updating names that don't need to change.
        if(-not($Track.Genre -cmatch $Genre)){
            Set-iTunesTrackData -Attribute Genre -Value $Genre
        }
    }
}

