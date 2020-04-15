function formatiTunesTrackInfo {
  [CmdletBinding()]
  param(
    [Parameter(
      ValueFromPipeline=$true,
      ValueFromPipelinebyPropertyName=$true)]
    [System.Object[]]
    $Tracks = (Get-iTunesSelectedTracks),

    [Parameter()]
    [switch]
    $ShowAlbum = $true,

    [Parameter()]
    [switch]
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