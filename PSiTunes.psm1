###################################################################################################
# Load external functions
###################################################################################################

$FunctionsRoot = Join-Path $PSScriptRoot "Functions"

$Functions = Get-ChildItem -Path $FunctionsRoot *.ps1

foreach($Function in $Functions){
  . $Function.FullName
}

###################################################################################################
# Internal functions
###################################################################################################

function formatiTunesTrackInfo {
  [CmdletBinding()]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [System.Object[]]
    $Tracks = (Get-iTunesSelectedTracks),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $ShowAlbum = $true,

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $ShowTrackDatabaseId
  )

  BEGIN {
  }

  PROCESS {

    foreach($Track in $Tracks){
      if($ShowTrackDatabaseId){
        $FormattedTrackInfo = "[{0}] - " -f $Track.TrackDatabaseId
      } 
      
      $FormattedTrackInfo+= "{0} [{1}]" -f $Track.Artist,$Track.Name
      
      if($ShowAlbum){
        $FormattedTrackInfo+= " {0}" -f $Track.Album
      }

      Write-Output $FormattedTrackInfo
    }
  }

  END {
  }
}

function startiTunesApplication {
  if(-not $iTunesApplication){
    $GLOBAL:iTunesApplication = New-Object -ComObject iTunes.Application
  }
  
  return $iTunesApplication
}

###################################################################################################
# Exported functions
###################################################################################################

function Get-iTunesLibrary {
  if(-not $iTunesApplication){
    $iTunesApplication = startiTunesApplication
  }
  
  return $iTunesApplication.LibraryPlaylist
}

function Get-iTunesLibraryGenres {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [System.Object]$iTunesLibrary = $(Get-iTunesLibrary)
  )
  
  if(-not $iTunesLibrary){
    Write-Error "No Library object provided"
    return $null
  }
  
  # Build list of (non-blank) genres in the Library as an array. We assume that there will
  # always be a genre called "Compilations"
  $Genres = @()
  $Genres+= "Compilations"
  $iTunes.LibraryPlaylist.Tracks | ?{($_.Compilation -eq $false) -and ($_.Genre -ne $null)} `
    | Group-Object Genre | %{$Genres+= $_.Name}
  
  return $Genres
}

function Get-iTunesPlaylist {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(Mandatory=$true)]
      [System.String]$Name = ".",
    [System.Management.Automation.SwitchParameter]$ExactMatch = $false
  )
  
  if(-not $iTunesApplication){
    $iTunesApplication = startiTunesApplication
  }
  
  if($ExactMatch){
    $iTunesPlaylist = $iTunesApplication.Sources.Item(1).Playlists | ?{$_.Name -eq $Name}
  } else {
    $iTunesPlaylist = $iTunesApplication.Sources.Item(1).Playlists | ?{$_.Name -match $Name}
  }
  
  return $iTunesPlaylist
}

function Get-iTunesPlaylistTracks {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [System.Object]$Playlist
  )
  
  if(-not $Playlist){
    $Playlist = Get-iTunesPlaylist
  }
  
  return $Playlist.Tracks
}

function Get-iTunesDuplicatedTracks {
  [CmdletBinding()]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [System.Object[]]
    $Tracks = (Get-iTunesSelectedTracks)
  )

  Write-Verbose "Searching for duplicates over $($Tracks.Count) tracks"

  return ($Tracks |
    Where-Object {$_.Grouping -notmatch "Sync"} |
    Group-Object -Property Artist,Name |
    Where-Object {$_.Count -gt 1}).Name
}

function Get-iTunesSelectedTracks {
  if(-not $iTunesApplication){
    Write-Error "iTunes not loaded"
    return $false
  } else {
    $iTunesSelectedTracks = $iTunesApplication.SelectedTracks
    
    if(-not $iTunesSelectedTracks){
      Write-Warning "No tracks selected"
      return $null
    } else {
      return $iTunesSelectedTracks
    }
  }
}

function Search-iTunesLibrary {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ParameterSetName="Library",
      Mandatory=$true)]
    [System.String]
    $Search,
    
    [Parameter( 
      ParameterSetName="Track")]
    [System.String]
    $AlbumName = "",
    
    [Parameter(
      ParameterSetName="Track")]
    [System.String]
    $ArtistName = "",
    
    [Parameter(
      ParameterSetName="Track")]
    [System.String]
    $TrackName = "",
    
    [Parameter()]
    [System.Int32]
    $SearchType = 0,
    
    [Parameter()]
    [System.Object]
    $iTunesLibrary = $(Get-iTunesLibrary)
  )
  
  if(($SearchType -lt 0) -or ($SearchType -gt 5)){
    Write-Error "Invalid search type: $SearchType"
    return $null
  }
  
  if($PsCmdlet.ParameterSetName -eq "Track"){
    $Search = "$ArtistName $AlbumName $TrackName"
  }
   
  # Run search
  $SearchString = $Search.Trim() -replace '  ',' '
  
  if($SearchString){
    $SearchReults = $iTunesLibrary.Search($SearchString, $SearchType)
  } else {
    Write-Error "Search string is empty"
    return $null
  }
  
  # Create a list of tracks from the search results
  $Tracks = @()
  $SearchReults | %{$Tracks += $_}
  
  # Filter results if a "track" search was used
  $Tracks = $Tracks | ?{`
    ($_.Artist -match $ArtistName) -and `
    ($_.Album -match $AlbumName) -and `
    ($_.Name -match $TrackName)}
    
  # Return the list of tracks as an array
  return $Tracks
}

function Set-iTunesTrackData {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [System.Object[]]
    $Tracks,
    
    [Parameter()]
    [System.String]
    $Attribute,

    [Parameter()]
    [ValidateScript({$_.GetType() -in [System.Int32],[System.String]})]
    $Value
  )

  BEGIN {
  }

  PROCESS {
    Write-Verbose "Updating $Attribute on $(formatiTunesTrackInfo -Track $Track)"

    foreach($Track in $Tracks){
      if($PSCmdlet.ShouldProcess($Attribute,"Set attribute")){
        $Track.$Attribute = $Value
      }
    }
  }

  END {
  }
}
    
function Set-iTunesTrackGenre {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [System.Object[]]
    $Tracks = (Get-iTunesSelectedTracks),

    [Parameter(
      Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Genre
  )
  
  foreach($Track in $Tracks){
    # Run a case-sensitive match to see if we need to change anything, as we don't want to waste
    # time updating names that don't need to change.
    if(-not($Track.Genre -cmatch $Genre)){
      Set-iTunesTrackData -Track $Track -Attribute Genre -Value $Genre
    }
  }
}

function Set-iTunesTrackGrouping {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [System.Object]
    $Track = (Get-iTunesSelectedTracks),

    [Parameter(
      Mandatory=$true,
      ParameterSetName="Add")]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Add,

    [Parameter(
      Mandatory=$true,
      ParameterSetName="Remove")]
    [ValidateNotNullOrEmpty()]
    [System.String]
    $Remove
  )

  BEGIN {
  }
  
  PROCESS {
    # Get the current list of items in the Grouping field, or the Genre if it isn't set
    if ($Add -and ($Track.Grouping -match "\b$Add\b")) {
      Write-Debug "NO CHANGE: Grouping already contains $Add"
      return

    } elseif ($Remove -and ($Track.Grouping -notmatch "\b$Remove\b")) {
      Write-Debug "NO CHANGE: Grouping already doesn't contain $Remove"
      return

    } elseif ($Track.Grouping){
      $GroupingTags = ($Track.Grouping).Split(";") | ?{$_ -ne $Remove}

    } else {
      # If there isn't a Grouping already, just set it to ""
      $GroupingTags = ""
    }
    
    # Add the genre, splitting multi-word genres and removing non-alphabertic characters
    $GenreTags = ($Track.Genre).Split(" ") -replace '\W',''
    
    foreach($GenreTag in $GenreTags){
      if($Track.Grouping -notmatch "\b$GenreTag\b"){
        Write-Debug "Adding Genre ($GenreTag) to Grouping Tags"
        $GroupingTags+= $GenreTag
      }
    }
    
    if($Add){
      Write-Debug "Adding $Add to Grouping Tags"
      $GroupingTags+= $Add
    }
    
    # Update the track Grouping field
    Set-iTunesTrackData -Tracks $Track -Attribute Grouping -Value ($GroupingTags -join ";")
  }
  
  END{
  }
}

function Set-iTunesTrackName {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(ParameterSetName="Normalize")]
    [System.Object]
    $Tracks,

    [Parameter(ParameterSetName="Normalize")]
    [System.Management.Automation.SwitchParameter]
    $Normalize,

    [Parameter(ParameterSetName="Set")]
    [System.Int32]
    $TrackIndex,

    [Parameter(ParameterSetName="Set")]
    [System.String]
    $Name,

    [Parameter(ParameterSetName="Set")]
    [System.Object]
    $iTunesLibrary = $iTunesLibrary   # Uses global variable if set
  )
  
  BEGIN {
  }


  PROCESS {
    switch ($PsCmdlet.ParameterSetName){
      "Normalize" {
        if(-not $Tracks -or $Tracks.Count -lt 1){
          Write-Error "Nothing to normalize"
          return $null
        }
      }

      "Set"       {
        $Tracks = $iTunesLibrary.Tracks | ?{$_.Index -eq $TrackIndex}
      
        if(-not $Tracks){
          Write-Error "Track not found with index $TrackIndex"
          return $null
        }
      }  
    }
  
    ##############################################################################################
    # Prepare the new track name in a hash table
  
    $NewNames = @{}
    
    foreach($Track in $Tracks){
      if($NewNames."$($Track.Index)"){
        Write-Error "Track $($Track.Index) ($($Track.Name)) already encountered."
      } else {
        # Create a new entry in the hash table with the current track name
        $NewNames."$($Track.Index)" = $Track.Name
      
        # Update entry, replace 2x single quotes with 1x double quote
        $NewNames."$($Track.Index)" = $NewNames."$($Track.Index)" -replace "''",'"'
      
        # Update entry, capitalizing the first letter of each word
        $NewNames."$($Track.Index)" = ConvertTo-CapitalizedWords $NewNames."$($Track.Index)"
      }
    }
    
    ##############################################################################################
    # Update any track names that need to be changed
  
    foreach($Track in $Tracks){
      # Run a case-sensitive match to see if we changed anything, as we don't want to waste time
      # updating names that don't need to change.
      if(Compare-Object $Track.Name $NewNames."$($Track.Index)" -CaseSensitive){
        Set-iTunesTrackData -Tracks $Track -Attribute Name -value ($NewNames."$($Track.Index)")
      }
    }
  }

  END {
  }
}

function Set-iTunesTrackRating {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [System.Object[]]
    $Tracks = (Get-iTunesSelectedTracks),

    [Parameter(
      Mandatory=$true)]
    [ValidateSet(0,1,2,3,4,5,20,40,60,80,100)]
    [System.Int32]
    $Rating
  )
  
  # Correct "user star" values 1-5 to the range 20-100
  if($Rating -lt 20){
    $Rating = $Rating * 20
  }

  foreach($Track in $Tracks){
    # Run a case-sensitive match to see if we need to change anything, as we don't want to waste
    # time updating names that don't need to change.
    if(-not($Track.Genre -cmatch $Genre)){
      Set-iTunesTrackData -Attribute Genre -Value $Genre
    }
  }
}

function Sync-iTunesPlaylistTracks {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [ValidateNotNullOrEmpty()]
    [Alias("SyncPlaylist")]
    [System.String]
    $Name = "Sync (All)",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.Object[]]
    $SyncTracks = (Get-iTunesPlaylist -Name $Name -ExactMatch).Tracks
  )
  
  # Make a summary list of each distinct Artist and Track Name combination
  $SyncSummary = $SyncTracks | Select-Object Name,Artist -Unique
  
  foreach($Item in $SyncSummary){
    # Get the tracks matching this "item" in the SyncSummary (Artist and Track Name combination)
    $Tracks = $SyncTracks | ?{($_.Name -eq $Item.Name) -and ($_.Artist -eq $Item.Artist)}
    
    # Only attempt to update entries in the SynchronizationList where there are more than one
    # tracks with the same Name and Artist.
    if($Tracks.Count -gt 1){
      Write-Verbose "Synchronizing $($Item.Artist) - $($Item.Name)"
      
      $UpdatedTracks = Set-iTunesTrackPlayedData -Tracks $Tracks -SyncPlayedData
    }
  }
}

function Sync-iTunesTrackData {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [System.Object[]]
    $Tracks = (Get-iTunesSelectedTracks),

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $SyncPlayedData,

    [Parameter()]
    [System.Management.Automation.SwitchParameter]
    $FirstSync
  )
  
  if((-not $Tracks) -or ($Tracks.Count -lt 2)){
    Write-Warning "Minimum 2 tracks needed for sync"
    return $null

  } elseif(($Tracks | Select Name,Artist -Unique).Count -gt 1){
    Write-Warning "Name and Artist does not match for all tracks"
    Write-Debug ($Tracks | Select Name,Artist -Unique | Out-String)
    return $null

  } else {
    Write-Verbose "$($PsCmdlet.ParameterSetName) data on $($Tracks.Count) tracks"
  }
  
  $PlayedDate = ($Tracks | Measure-Object -Maximum -Property PlayedDate).Maximum
      
  $MaxRating = [Int32]($Tracks | Measure-Object -Maximum -Property Rating).Maximum
      
  # NB: Unless the FirstSync switch has been used, we make an assumption that the least-
  # played track in the list is a low-water mark, i.e. it has not been played since the last
  # sync, so we can use that mark when calculating how many times the other tracks have been
  # played.
      
  if($FirstSync){
    $MinPlayed = 0
  } else {
    $MinPlayed = ($Tracks | Measure-Object -Property PlayedCount -Minimum).Minimum
  }
        
  # We work out how many times each track was played over this minimum count. We will also
  # take the opportunity to add the "Sync" tag to the Grouping field so we can more-easily
  # find tracks which have been synchronised in this way in the future and finally, we will
  # add a "NoPlaylist" tag to remove duplicate tracks from smart playlists (for which we
  # will make some effort to ensure the earliest version of the track is the "master").
      
  $PlayedCount = $MinPlayed
  $AddNoPlaylist = 0
      
  foreach($Track in ($Tracks | Sort-Object Compilation,Year,Album)){

    ###########################################################################################
    # Work out total PlayedCount: Add the number of additional times this track has been played

    if($Track.PlayedCount -gt $MinPlayed){
        $PlayedCount+= ($Track.PlayedCount - $MinPlayed)
    }
        
    ###########################################################################################
    # Add "Sync" tag to the Grouping field to enable future re-syncs

    Set-iTunesTrackGrouping -Track $Track -Add "Sync"
        
    ###########################################################################################
    # Ensure that only one version of this song is added to smart playlists
    # 
    # If the AddNoPlaylist switch has been set (after the first run of this loop) we add
    # that tag, else we ensure that the tag is removed in case it was set previously.
        
    if($AddNoPlaylist){
        Set-iTunesTrackGrouping -Track $Track -Add "NoPlaylist"
    } else {
        Set-iTunesTrackGrouping -Track $Track -Remove "NoPlaylist"
    }
        
    # After the first run through the list of tracks we set this flag to ensure the rest
    # of the list get the "NoPlaylist" tag added in their grouping field.
        
    $AddNoPlaylist = 1
  }
      
  if($PlayedCount -eq 0){
    $PlayedDate = "1899-12-30"
  }
  
  #################################################################################################
  # Synchronize track data

  foreach($Track in $Tracks){
    $Track | Set-iTunesTrackData -Attribute PlayedCount -Value $PlayedCount
    $Track | Set-iTunesTrackData -Attribute PlayedDate -Value $PlayedDate
    $Track | Set-iTunesTrackData -Attribute Rating -Value $MaxRating
  }
}

###################################################################################################
# Define variables
###################################################################################################

###################################################################################################
# iTunes search constants as hash table

$GLOBAL:SearchType = @{}
$SearchType.ITPlaylistSearchFieldAll = 0        # Search all fields of each track.
$SearchType.ITPlaylistSearchFieldVisible = 1    # Search only the fields with columns that are currently visible in the display for the playlist. 
                                                # Note that song name, artist, album, and composer will always be searched, even if these columns are not visible.
$SearchType.ITPlaylistSearchFieldArtists = 2    # Search only the artist field of each track (IITTrack::Artist).
$SearchType.ITPlaylistSearchFieldAlbums = 3     # Search only the album field of each track (IITTrack::Album).
$SearchType.ITPlaylistSearchFieldComposers = 4  # Search only the composer field of each track (IITTrack::Composer).
$SearchType.ITPlaylistSearchFieldSongNames = 5  # Search only the song name field of each track (IITTrack::Name).

###################################################################################################
# Set paths for iTunes music and the new "shared music" location
$iTunesRoot = "S:\iTunes\iTunes Media\Music\"
$SharedRoot = "S:\Music\"

###################################################################################################
# Start iTunes Application
if(-not (Get-Process | ?{$_.Name -eq "iTunes"})){
  Write-Warning "Starting iTunes"
  $GLOBAL:iTunesApplication = startiTunesApplication
}

###################################################################################################
# Load the iTunes Library object
$GLOBAL:iTunesLibrary = Get-iTunesLibrary

###################################################################################################
# Analyze library
# $GLOBAL:iTunesGenres = Get-iTunesGenres -iTunesLibrary $iTunesLibrary
