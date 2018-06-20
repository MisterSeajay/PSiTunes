###################################################################################################
# Load external functions
###################################################################################################

Set-StrictMode -Version 2

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
  [CmdletBinding(SupportsShouldProcess)]
  param()
  
  if($PSCmdlet.ShouldProcess("iTunes.Application","New-Object")){
    try {
      $GLOBAL:iTunesApplication = New-Object -ComObject iTunes.Application
    }
    catch {
      if(Get-Process | ?{$_.Name -eq "iTunes"}) {
        Write-Warning "Unable to connect to running iTunes application"
      }

      $GLOBAL:iTunesApplication = $null
    }
  }
}

###################################################################################################
# Exported functions
###################################################################################################

function Get-iTunesLibrary {
  if(-not (Get-Variable | ?{$_.Name -eq "iTunesApplication"})){
    startiTunesApplication
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
      ValueFromPipeline=$true)]
    [System.Object[]]
    $Tracks,
    
    [Parameter()]
    [System.String]
    $Attribute,

    [Parameter()]
    [ValidateScript({$_.GetType() -in ([Int],[String],[DateTime])})]
    $Value
  )

  BEGIN {
  }

  PROCESS {
    Write-Verbose "Updating $Attribute on $(formatiTunesTrackInfo -Track $Track)"

    foreach($Track in $Tracks){
      if($PSCmdlet.ShouldProcess($Attribute,"Set attribute")){
        Write-Debug "Set $Attribute to $Value [$($Value.GetType().FullName)]"
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
      ValueFromPipeline=$true)]
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
    [Alias("SyncPlaylist","Name")]
    [System.String]
    $Playlist = "Sync (All)"
  )
  
  $SyncTracks = (Get-iTunesPlaylist -Name $Playlist -ExactMatch).Tracks

  Write-Debug "$($SyncTracks.Count) track to synchronize from $Playlist"

  # Make a summary list of each distinct Artist and Track Name combination
  $SyncSummary = $SyncTracks | Select-Object Artist,Name | Sort-Object Artist,Name | Get-Unique -AsString
  
  Write-Debug "$($SyncSummary.Count) distinct Artist-Song combinations"

  foreach($Track in $SyncSummary){
    # Get the tracks matching this "item" in the SyncSummary (Artist and Track Name combination)
    $Tracks = $SyncTracks | ?{($_.Name -eq $Track.Name) -and ($_.Artist -eq $Track.Artist)}
    
    # Check whether we need to synchronize this Artist-Song combination
    $PlayedCount = $Tracks.PlayedCount | Measure-Object -Maximum -Minimum

    if($PlayedCount.Maximum -eq $PlayedCount.Minimum){
      Write-Verbose "$($Track.Artist) - $($Track.Name) is already in-sync; skipping"
      continue
    }

    # Only attempt to update entries in the SynchronizationList where there are more than one
    # tracks with the same Name and Artist.
    if($Tracks.Count -gt 1){
      if($PSCmdlet.ShouldProcess("$($Track.Artist) - $($Track.Name)","Set-iTunesTrackPlayedData")){
        Write-Verbose "Synchronizing $($Track.Artist) - $($Track.Name)"

        try {
          $UpdatedTracks = Sync-iTunesTrackData -Tracks $Tracks -SyncPlayedData
        }
        catch {
          throw
          break
        }
      }
    } else {
      Write-Warning "Only 1 entry found for $($Track.Artist) - $($Track.Name)"
    }
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
startiTunesApplication

###################################################################################################
# Load the iTunes Library object
$GLOBAL:iTunesLibrary = Get-iTunesLibrary