function Sync-iTunesTrackData {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ValueFromPipeline=$true)]
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
  }
  elseif(@($Tracks |
      Select-Object Artist,@{Label="ShortName";Expression={$_.Name.ToLower() -replace "\[.+\]",""}} |
      Sort-Object Artist,ShortName | Get-Unique -AsString).Count -gt 1){
    Write-Warning "Name and Artist does not match for all tracks"
    Write-Debug ($Tracks | Select Name,Artist -Unique | Out-String)
    return $null
  }
  else {
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
  }
  else {
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

    $PlayedCount = [Int]$PlayedCount
    try {
      $Track | Set-iTunesTrackData -Attribute PlayedCount -Value $PlayedCount
    }
    catch {
      throw
    }

    $PlayedDate = [DateTime]$PlayedDate
    try {
      $Track | Set-iTunesTrackData -Attribute PlayedDate -Value $PlayedDate
    }
    catch {
      throw
    }

    $MaxRating = [Int]$MaxRating
    try {
      $Track | Set-iTunesTrackData -Attribute Rating -Value $MaxRating
    }
    catch {
      throw
    }
  }
}
