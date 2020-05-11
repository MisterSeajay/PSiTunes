function convertFromTagLibProperties {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    BEGIN {}

    PROCESS {
        return ([PSCustomObject]@{
            Name = $InputObject.Title
            Album = $InputObject.Album
            Artist = $InputObject.FirstArtist
            AlbumArtist = $InputObject.AlbumArtists -join ("; ")
            Compilation = [bool]($InputObject.FirstAlbumArtist -match "various")
            Composer = $InputObject.JoinedComposers -join ("; ")
            Genre = $InputObject.FirstGenre
            Grouping = $InputObject.Genres -join ("; ")
            TrackNumber = [int]$InputObject.Track
            TrackCount = [int]$InputObject.TrackCount
            DiscNumber = [int]$InputObject.Disc
            DiscCount = [int]$InputObject.DiscCount
            Year = [int]$InputObject.Year
            Comment = $InputObject.Comment
            Location = $InputObject.FullName
        })
    }

    END {}
}