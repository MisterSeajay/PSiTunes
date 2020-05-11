function Get-SimpleAttributes {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $Track
    )

    BEGIN {}

    PROCESS {
        return [PSCustomObject]@{
            TrackDatabaseID = $Track.TrackDatabaseID
            Name = $Track.Name
            Artist = $Track.Artist
            AlbumArtist = $Track.AlbumArtist
            Genre = $Track.Genre
            Location = $Track.Location
        }
    }

    END {}
}