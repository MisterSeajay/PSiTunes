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
            Compilation = ($InputObject.FirstAlbumArtist -match "various")
            Composer = $InputObject.JoinedComposers -join ("; ")
            Genre = $InputObject.FirstGenre
            Grouping = $InputObject.Genres -join ("; ")
            Track = $InputObject.Track
            TrackCount = $InputObject.TrackCount
            Disc = $InputObject.Disc
            DiscCount = $InputObject.DiscCount
            Year = $InputObject.Year
            Comment = $InputObject.Comment
        })
    }

    END {}
}


<#
        switch($InputFormat){
            "Explorer" {
                if($_.Album -match "Disc\s*(\d+)"){
                    $Disc = $Matches[1]
                  } else {
                    $Disc = 1
                  }
          
                  [PSCustomObject]@{
                    AlbumArtist = $_.Authors
                    Album = $_.Album
                    "Track Title" = $_.Title
                    "Track Artist" = $_."Contributing Artists"
                    Year = $_.Year
                    Genre = $_.Genre
                    Conductor = $_.Conductors
                    Rating = $_.Rating
                    Comments = $_.Comments
                    Track = $_."#"
                    Disc = $Disc
                    Length = $_.Length
                    Bitrate = $_."Bit rate"
                    FileName = $_.Name
                    FilePath = $_.Fullname
                    FileSize = $_.Size
                  }
          
            }


if($_.Album -match "Disc\s*(\d+)"){
    $Disc = $Matches[1]
  } else {
    $Disc = 1
  }

  [PSCustomObject]@{
    "Album Artist" = $_.Authors
    "Album Title" = $_.Album
    "Track Title" = $_.Title
    "Track Artist" = $_."Contributing Artists"
    Year = $_.Year
    Genre = $_.Genre
    Conductor = $_.Conductors
    Rating = $_.Rating
    Comments = $_.Comments
    Track = $_."#"
    Disc = $Disc
    Length = $_.Length
    Bitrate = $_."Bit rate"
    FileName = $_.Name
    FilePath = $_.Fullname
    FileSize = $_.Size
  }
#>