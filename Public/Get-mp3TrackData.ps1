function Get-mp3TrackData {
    [CmdletBinding()]
    param(
        [Parameter(
            ValueFromPipeline=$true)]
        [string]
        $Path,

        [switch]
        $MatchITunesAttribues
    )

    $TagLibFile = [TagLib.File]::Create((Resolve-Path $Path))
    
    if($MatchITunesAttribues){
      return ([PSCustomObject]@{
        Name = $TagLibFile.Tag.Title
        Album = $TagLibFile.Tag.Album
        Artist = $TagLibFile.Tag.FirstArtist
        AlbumArtist = $TagLibFile.Tag.AlbumArtists -join ("; ")
        Compilation = ($TagLibFile.Tag.FirstAlbumArtist -match "various")
        Composer = $TagLibFile.Tag.JoinedComposers -join ("; ")
        Genre = $TagLibFile.Tag.FirstGenre
        Grouping = $TagLibFile.Tag.Genres -join ("; ")
        Track = $TagLibFile.Tag.Track
        TrackCount = $TagLibFile.Tag.TrackCount
        Disc = $TagLibFile.Tag.Disc
        DiscCount = $TagLibFile.Tag.DiscCount
        Year = $TagLibFile.Tag.Year
      })
    } else {
        return $TagLibFile.Tag
    }
}
    