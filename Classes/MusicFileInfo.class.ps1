Class MusicFileInfo {
    [string]$Name;          # Title of the track
    [string]$Album;         # Name of the album the track is a part of
    [string]$Artist;        # Name of the artist for this track, aka "contributing artist"
    [string]$AlbumArtist;   # Name of the artist for the whole album that this track is a part of
    [string]$Comment        # Free text description of this track
    [bool]$Compilation;     # Is this track part of a "various artists" compilation album?
    [string]$Composer;      # Name of the artist(s) who wrote the song, etc.
    [string]$Genre;         # Genre of music the track falls into.
    [string]$Grouping;      # List of keywords/tags for the track.
    [string]$Time;          # Length of track (MM:ss or HH:MM:ss).
    [int]$TrackNumber;      # Track number for the album the track is a part of
    [int]$TrackCount;       # Total number of tracks on the album the track is a part of
    [int]$DiscNumber;       # Disc number for the album the track is a part of
    [int]$DiscCount;        # Total number of discs for the album the track is a part of
    [int]$Year;             # Year the track was released
    [string]$Location;      # Path to file on disk
    [string]$FullName;
    [int]$BitRate;
    MusicFileInfo($InputObject) {
        foreach($prop in $InputObject.PSObject.Properties.Name){
            try {
                $this.$prop = $InputObject.$prop
            } catch {
                Write-Warning "Failed to set $prop on new MusicFileInfo object"
                Write-Debug ($InputObject | Format-List | Out-String)
                Write-Error $_.Message.ToString()
            }
        }
    }
    [bool]Exists() {        # Does the file exist at the location specified?
        return ((Test-Path -LiteralPath $this.Location -ErrorAction "SilentlyContinue") -eq $true)
    }
    [string]ToString() {
        return ($this.Path, $this.FullName, $this.Location | Select-Object -First 1)
    }
    [string]Path() {
        return $this.Location
    }
}