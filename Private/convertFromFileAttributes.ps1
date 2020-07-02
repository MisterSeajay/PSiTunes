function convertFromFileAttributes {
    [CmdletBinding()]
    [OutputType([MusicFileInfo])]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $InputObject
    )

    BEGIN {
        $AllowedAttributes = @(
            "FullName"
            "Title"
            "Album"
            "Artist"
            "Contributing Artists"
            "AlbumArtist"
            "Authors"
            "Compilation"
            "Genre"
            "Categories"
            "Track"
            "TrackNumber"
            "#"
            "Disc"
            "Year"
            "Comments"
            "Location"
            "Bit rate"
        )
    }

    PROCESS {       
        $InputObject = $InputObject | Select-Object $AllowedAttributes

        $Compilation = ($InputObject.Compilation, ($InputObject.FullName -match "(compilation|various artist)")) | Select-Object -First 1

        if($InputObject.FullName -match "Disc\s*(\d+)"){
            $Disc = $Matches[1]
        } elseif($InputObject.Album -match "Various \(.+\)") {
            $Disc = $null
        } else {
            $Disc = 1
        }

        $CleanedData = [PSCustomObject]@{
            Name = [string]$InputObject.Title
            Album = [string]$InputObject.Album
            Artist = [string](($InputObject.Artist, $InputObject."Contributing artists") | Select-Object -First 1)
            AlbumArtist = if($Compilation){"Various Artists"} `
                else {[string](($InputObject.AlbumArtist, $InputObject.Authors) | Select-Object -First 1)}
            Compilation = [bool]$Compilation
            Composer = $null # Unknown
            Genre = [string]$InputObject.Genre
            Grouping = [string]$InputObject.Categories
            TrackNumber = [int](($InputObject.Track, $InputObject.TrackNumber, $InputObject."#") | Select-Object -First 1)
            TrackCount = $null # Unknown
            DiscNumber = [int]$Disc
            DiscCount = $null # Unknown
            Year = [int]$InputObject.Year
            Comment = [string]$InputObject.Comments
            Location = [string]$InputObject.FullName
            BitRate = [int]($InputObject."Bit rate" -replace ('\D',''))
        }
        
        try {
            $MusicFileInfo = $CleanedData -as [MusicFileInfo]
        } catch {
            Write-Error "Unable to convert $($InputObject.Fullname) to [MusicFileInfo]"
        }

        return $MusicFileInfo
    }

    END {}
}