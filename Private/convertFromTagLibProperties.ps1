function convertFromTagLibProperties {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $InputObject
    )

    BEGIN {}

    PROCESS {
        try {
            $MusicFileInfo = [PSCustomObject]@{
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
                Location = $InputObject.Location
                BitRate = $InputObject.BitRate
            } -as [MusicFileInfo]
        } catch {
            Write-Warning "convertFromTagLibProperties: Failed to convert InputObject to [MusicFileInfo] type"
            Write-Error $_.Exception.Message
        }

        Write-Output $MusicFileInfo
    }

    END {}
}