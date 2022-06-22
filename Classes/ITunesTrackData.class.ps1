###################################################################################################
# iTunes constants as enums
#region

enum ITPlaylistKind {
    ITPlaylistKindUnknown = 0           # Unknown playlist kind.
    ITPlaylistKindLibrary               # Library playlist (IITLibraryPlaylist).
    ITPlaylistKindUser                  # User playlist (IITUserPlaylist).
    ITPlaylistKindCD                    # CD playlist (IITAudioCDPlaylist).
    ITPlaylistKindDevice                # Device playlist.
    ITPlaylistKindRadioTuner            # Radio tuner playlist.
}

enum ITPlaylistRepeatMode {
    ITPlaylistRepeatModeOff = 0         # Play playlist once.
    ITPlaylistRepeatModeOne             # Repeat song.
    ITPlaylistRepeatModeAll             # Repeat playlist.
}

enum ITPlaylistSearchField {
    ITPlaylistSearchFieldAll = 0        # Search all fields of each track.
    ITPlaylistSearchFieldVisible        # Search {name, artist, album, composer} PLUS the fields with columns that are currently visible in the playlist. 
    ITPlaylistSearchFieldArtists        # Search only the artist field of each track (IITTrack::Artist).
    ITPlaylistSearchFieldAlbums         # Search only the album field of each track (IITTrack::Album).
    ITPlaylistSearchFieldComposers      # Search only the composer field of each track (IITTrack::Composer).
    ITPlaylistSearchFieldSongNames      # Search only the song name field of each track (IITTrack::Name).
}

enum ITRatingKind {
    ITRatingKindUser = 0                # User-specified rating.
    ITRatingKindComputed                # iTunes-computed rating. 
}

enum ITSourceKind {
    ITSourceKindUnknown = 0
    ITSourceKindLibrary
    ITSourceKindIPod
    ITSourceKindAudioCD
    ITSourceKindMP3CD
    ITSourceKindDevice
    ITSourceKindRadioTuner
    ITSourceKindSharedLibrary
}

enum ITTrackKind {
    ITTrackKindUnknown = 0              # Unknown track kind.
    ITTrackKindFile                     # File track (IITFileOrCDTrack).
    ITTrackKindCD                       # CD track (IITFileOrCDTrack).
    ITTrackKindURL                      # URL track (IITURLTrack).
    ITTrackKindDevice                   # Device track.
    ITTrackKindSharedLibrary            # Shared library track.
}

enum ITVideoKind {
    ITVideoKindNone = 0                 # Not a video track, or unknown video track kind.
    ITVideoKindMovie                    # Movie video track.
    ITVideoKindMusicVideo               # Music video track.
    ITVideoKindTVShow                   # TV show video track. 
}

#endregion
###################################################################################################

###################################################################################################
# Classes
# These are replicas of the types of (COM) object exposed by iTunes. The difference between these
# and the COM objects are that the classes defined below don't support the many methods.
#region

Class iTunesObjectInfo {
    [string]$Name           # Title of the track/playlist/etc.
    [int]$Index
    [int]$sourceID
    [int]$playlistID
    [int]$trackID
    [int]$TrackDatabaseID
}

<# Don't need to implement these yet...
Class iTunesSourceInfo : ITObject {
    [ITSourceKind]$Kind;
    [int]$Capacity;
    [int]$FreeSpace;
    [ITPlaylistCollection]$Playlists;
}

Class iTunesPlaylistInfo : ITObject {
    [ITPlaylistKind]$Kind;
    [ITSource]$Source;
    [int]$Duration;
    [bool]$Shuffle;
    [int]$Size
    [ITPlaylistRepeatMode]$SongRepeat;
    [string]$Time;          # MM:SS
    [bool]$Visible;
    [ITTrackCollection]$Tracks;
}
#>

Class iTunesTrackInfo : iTunesObjectInfo {
    [ITTrackKind]$Kind;
    [__ComObject]$Playlist
    [string]$Album;         # Name of the album the track is a part of
    [string]$Artist;        # Name of the artist for this track, aka "contributing artist"
    [int]$BitRate;
    [int]$BPM
    [string]$Comment        # Free text description of this track
    [bool]$Compilation;     # Is this track part of a "various artists" compilation album?
    [string]$Composer;      # Name of the artist(s) who wrote the song, etc.
    [datetime]$DateAdded
    [int]$DiscCount;        # Total number of discs for the album the track is a part of
    [int]$DiscNumber;       # Disc number for the album the track is a part of
    [int]$Duration
    [bool]$Enabled
    [string]$EQ
    [int]$Finish
    [string]$Genre;         # Genre of music the track falls into.
    [string]$Grouping;      # List of keywords/tags for the track.
    [string]$KindAsString
    [datetime]$ModificationDate
    [int]$PlayedCount
    [datetime]$PlayedDate
    [int]$PlayOrderIndex
    [int]$Rating
    [int]$SampleRate
    [int]$Size
    [int]$Start
    [string]$Time;          # Length of track (MM:ss or HH:MM:ss).
    [int]$TrackCount;       # Total number of tracks on the album the track is a part of
    [int]$TrackNumber;      # Track number for the album the track is a part of
    [int]$VolumeAdjustment
    [int]$Year;             # Year the track was released
    [__ComObject]$Artwork
}

# ITFileOrCDTrack
Class iTunesFileOrCDTrackInfo : iTunesTrackInfo {
    [string]$Location;      # Path to file on disk
    [bool]$Podcast
    [bool]$RememberBookmark
    [bool]$ExcludeFromShuffle
    [string]$Lyrics
    [string]$Category
    [string]$Description
    [string]$LongDescription
    [int]$BookmarkTime
    [ITVideoKind]$VideoKind
    [int]$SkippedCount
    [datetime]$SkippedDate
    [bool]$PartOfGaplessAlbum
    [string]$AlbumArtist;   # Name of the artist for the whole album that this track is a part of
    [string]$Show
    [int]$SeasonNumber
    [string]$EpisodeID
    [int]$EpisodeNumber
    [int]$Size64High
    [int]$Size64Low
    [bool]$Unplayed
    [string]$SortAlbum
    [string]$SortAlbumArtist
    [string]$SortArtist
    [string]$SortComposer
    [string]$SortName
    [string]$SortShow
    [int]$AlbumRating
    [int]$AlbumRatingKind
    [ITRatingKind]$RatingKind
    [__ComObject]$Playlists
    [datetime]$ReleaseDate
}

Class iTunesTrackData : iTunesFileOrCDTrackInfo {
    # Constructor
    iTunesTrackData($InputObject) {
        foreach($prop in $InputObject.PSObject.Properties.Name){
            try {
                $this.$prop = $InputObject.$prop
            } catch {
                Write-Warning "Failed to set $prop on new object"
            }
        }
    }
    
    [bool]Exists() {        # Does the file exist at the location specified?
        return ((Test-Path -LiteralPath $this.Location -ErrorAction "SilentlyContinue") -eq $true)
    }
}

#endregion
###################################################################################################
