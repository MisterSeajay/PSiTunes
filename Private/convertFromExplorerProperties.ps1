function convertFromExplorerProperties {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    BEGIN {}

    PROCESS {
        $Compilation = ($InputObject.Fullname -match "(compilation|various artist)")

        if($InputObject.Fullname -match "Disc\s*(\d+)"){
          $Disc = $Matches[1]
        } else {
          $Disc = 1
        }

        return ([PSCustomObject]@{
            Name = $InputObject.Title
            Album = $InputObject.Album
            Artist = $InputObject."Contributing artists"
            AlbumArtist = if($Compilation){"Various Artists"} else {$InputObject.Authors}
            Compilation = $Compilation
            Composer = $null # Unknown
            Genre = $InputObject.Genre
            Grouping = $InputObject.Categories
            Track = $InputObject."#"
            TrackCount = $null # Unknown
            Disc = $Disc
            DiscCount = $null # Unknown
            Year = $InputObject.Year
            Comment = $InputObject.Comments
        })
    }

    END {}
}