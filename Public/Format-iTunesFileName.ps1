function Format-iTunesFileName{
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
