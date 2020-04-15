Set-StrictMode -Version 2

###################################################################################################
# Dot-source functions

$PrivateFunctions = Join-Path $PSScriptRoot "Private"
$PublicFunctions = Join-Path $PSScriptRoot "Public"

foreach($Folder in @($PrivateFunctions,$PublicFunctions)){
    $Functions = Get-ChildItem -Path $Folder *.ps1

    foreach($Function in $Functions){
        . $Function.FullName
    }
}

###################################################################################################
# iTunes search constants as an enum
<#
    ITPlaylistSearchFieldAll = 0        # Search all fields of each track.
    ITPlaylistSearchFieldVisible = 1    # Search only the fields with columns that are currently visible in the display for the playlist. 
                                        # Note that song name, artist, album, and composer will always be searched, even if these columns are not visible.
    ITPlaylistSearchFieldArtists = 2    # Search only the artist field of each track (IITTrack::Artist).
    ITPlaylistSearchFieldAlbums = 3     # Search only the album field of each track (IITTrack::Album).
    ITPlaylistSearchFieldComposers = 4  # Search only the composer field of each track (IITTrack::Composer).
    ITPlaylistSearchFieldSongNames = 5  # Search only the song name field of each track (IITTrack::Name).
#>
enum SearchTypes {
    ITPlaylistSearchFieldAll = 0
    ITPlaylistSearchFieldVisible = 1
    ITPlaylistSearchFieldArtists = 2
    ITPlaylistSearchFieldAlbums = 3
    ITPlaylistSearchFieldComposers = 4
    ITPlaylistSearchFieldSongNames = 5
}

###################################################################################################
# Set paths for iTunes music and the new "shared music" location
$GLOBAL:iTunesRoot = "D:\iTunes\iTunes Media\Music\"

###################################################################################################
# Start iTunes Application
Start-iTunes

###################################################################################################
# Load the iTunes Library object
$GLOBAL:iTunesLibrary = Get-iTunesLibrary