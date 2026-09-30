function Set-iTunesTrackGenre {
    <#
    .SYNOPSIS
        Sets the genre on one or more iTunes tracks.
    .DESCRIPTION
        Sets the Genre attribute on each supplied track, skipping any track whose
        genre already matches, so that repeated runs do not write to tracks that
        do not need changing. Accepts pipeline input.
    .PARAMETER Tracks
        The tracks to change. Accepts pipeline input. Defaults to the tracks currently selected in iTunes.
    .PARAMETER Genre
        The genre to set. Required.
    .EXAMPLE
        Get-iTunesSelectedTracks | Set-iTunesTrackGenre -Genre "Ambient"
    .NOTES
        The comparison is case-sensitive, so a track already set to the same genre in different casing is still updated.
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
        [ValidateNotNullOrEmpty()]
        [string]
        $Genre
    )

    foreach($Track in $Tracks){
        # Run a case-sensitive match to see if we need to change anything, as we don't want to waste
        # time updating names that don't need to change.
        if(-not($Track.Genre -cmatch $Genre)){
            Set-iTunesTrackData -Track $Track -Attribute Genre -Value $Genre
        }
    }
}

