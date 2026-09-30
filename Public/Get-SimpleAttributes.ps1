function Get-SimpleAttributes {
    <#
    .SYNOPSIS
        Projects a track down to a small set of common attributes.
    .DESCRIPTION
        Returns a new object carrying just the attributes most scripts need from a
        track, dropping the rest. Useful for formatting and for comparing tracks
        without dragging the whole automation object along.
    .PARAMETER Track
        The track to project. Accepts pipeline input.
    .EXAMPLE
        Get-iTunesSelectedTracks | Get-SimpleAttributes | Format-Table
    .NOTES
        Returns TrackDatabaseID, Name, Artist, AlbumArtist, Genre and Location, and nothing else.
    #>
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