[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    $KnownTracks = $null
)

Import-Module ../psiTunes.psd1

function getTracksWithKnownLocation {
    [CmdletBinding()]
    param(
    )

    return ($iTunesLibrary.Tracks | Where-Object {$null -ne $_.Location})
}

function compareTagsAttributes {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $Track
    )

    $MetaData = Get-FileMetaData $Track.Location

    $SimpleMetaData = $MetaData | Get-SimpleAttributes

    $SimpleAttributes = $Track | Get-SimpleAttributes

    $Diff = Compare-Object $SimpleMetaData $SimpleAttributes

    if($Diff){
        return [PSCustomObject]@{
            Id = $Track.Id
            Name = $Track.Name
            Artist = $Track.Artist
            AlbumArtist = $Track.AlbumArtist
            Genre = $Track.Genre
            mp3Name = $MetaData.Name
            mp3Artist = $MetaData.Artist
            mp3AlbumArtist = $MetaData.AlbumArtist
            mp3Genre = $MetaData.Genre
        }
    }
}

if(-not $KnownTracks){
    $KnownTracks = getTracksWithKnownLocation
}

if($PSCmdlet.ShouldProcess("$($KnownTracks.Count) tracks","compareTagsAttributes")){
    $Count = 0
    foreach($Track in $KnownTracks){
        $Count++
        Write-Progress -Activity "compareTagsAttributes" -Status "$Count/$($KnownTracks.Count)" `
            -PercentComplete ([math]::floor($Count/$KnownTracks.Count))

        $IsDifferent = compareTagsAttributes -Track $Track
        if($IsDifferent){
            Write-Output $IsDifferent
            break
        }
    }

    Write-Progress -Activity "compareTagsAttributes" -Complete
}