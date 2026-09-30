function Format-iTunesFileName{
    <#
    .SYNOPSIS
        Builds a file name for a track from its metadata.
    .DESCRIPTION
        Produces a file name from a track's artist, name, disc and track numbers,
        and extension, capitalising each word and replacing characters that are
        illegal in a file name. The naming pattern depends on the number of discs:
        no disc number for a single-disc album, a zero-padded track number for a
        multi-disc album, and a disc-track prefix otherwise.
    .PARAMETER Track
        The track to build a name for. Accepts pipeline input. The artist, name, disc and track numbers, and extension are read from the track unless the corresponding parameter is supplied.
    .PARAMETER DiscNumber
        The disc number to use. Only read from the track when Track is supplied and DiscNumber is not bound.
    .PARAMETER TrackNumber
        The track number to use. Only read from the track when Track is supplied and TrackNumber is not bound.
    .PARAMETER TrackArtist
        The artist name to use. Only read from the track when Track is supplied and TrackArtist is not bound.
    .PARAMETER TrackName
        The track name to use. Only read from the track when Track is supplied and TrackName is not bound.
    .PARAMETER DiscCount
        The number of discs the album has. A value of 0 produces "Artist - Name", 1 produces "01 Name", and anything else produces "1-01 Name". Read from the track when Track is supplied and DiscCount is not bound.
    .PARAMETER FileExtension
        The file extension, without a dot. Read from the track Location when Track is supplied and FileExtension is not bound; if that is unavailable it is derived from the track Kind.
    .EXAMPLE
        Get-iTunesSelectedTracks | Format-iTunesFileName
    .EXAMPLE
        Format-iTunesFileName -TrackArtist "The Beatles" -TrackName "help" -FileExtension "mp3"
    .NOTES
        Throws if no file extension can be determined, because a name without one is not usable.
        Characters that are illegal in a file name are replaced with an underscore.
    #>
    [CmdletBinding(DefaultParameterSetName="ByTrack")]
    [OutputType([string])]
    param(
        [Parameter(ParameterSetName="ByTrack", ValueFromPipeline)]$Track,

        [Parameter(ParameterSetName="ByMetaData", Mandatory)][int]$DiscNumber,
        [Parameter(ParameterSetName="ByMetaData", Mandatory)][int]$TrackNumber,
        [Parameter(ParameterSetName="ByMetaData", Mandatory)][string]$TrackArtist,
        [Parameter(ParameterSetName="ByMetaData", Mandatory)][string]$TrackName,

        [Parameter()][int]$DiscCount = 1,
        [Parameter()][string]$FileExtension = $null
    )

    BEGIN {
    }

    PROCESS {
        if($Track){
            try {
                if($PSBoundParameters.Keys -notcontains "DiscCount"){
                    # Override default value of 1 with whatever is set in the Track meta
                    $DiscCount = $Track.DiscCount
                }
                $DiscNumber = $Track.DiscNumber
                $TrackNumber = $Track.TrackNumber
                $TrackArtist = $Track.Artist
                $TrackName = $Track.Name
            }
            catch {
                Write-Warning "Error processing Track metadata"
                Write-Debug "$($Track | Format-List Disc*,Track*,Album*,Artist,Name | Out-String)"
                throw
            }

            if($PSBoundParameters.Keys -notcontains "FileExtension"){
                try {
                    if(-not [string]::IsNullOrWhiteSpace($Track.Location)){
                        $FileExtension = ($Track.Location -as [System.IO.FileInfo]).Extension
                    }
                }
                catch {
                    Write-Warning ("Unable to convert file location to FileInfo for {0} - {1}" -f $TrackArtist, $TrackName)
                }

                try {
                    if([string]::IsNullOrWhiteSpace($FileExtension)){
                        $FileExtension = getFileExtenstionFromKind $Track.KindAsString
                    }
                }
                catch {
                    Write-Warning ("Unable to convert KindAsString for {0} - {1}" -f $TrackArtist, $TrackName)
                }
            }
        }

        if([string]::IsNullOrWhiteSpace($FileExtension)){
            throw("No file extension for {0} - {1}" -f $TrackArtist, $TrackName)
        }

        # Replace illegal file characters with an underscore
        $TrackName = ($TrackName -replace "[<>:""/\\|?*]", "_")

        switch([int]$DiscCount){
            0 {
                $FileName = "{0} - {1}.{2}" -f $TrackArtist, (convertToCapitalizedWords($TrackName)), $FileExtension.ToLower().trim(".")
                break
            }

            1 {
                $FileName = "{0:00} {1}.{2}" -f $TrackNumber, (convertToCapitalizedWords($TrackName)), $FileExtension.ToLower().trim(".")
                break
            }

            default {
                $FileName = "{0}-{1:00} {2}.{3}" -f $DiscNumber, $TrackNumber, (convertToCapitalizedWords($TrackName)), $FileExtension.ToLower().trim(".")
            }
        }

        Write-Output $FileName
    }

    END {
    }
}
