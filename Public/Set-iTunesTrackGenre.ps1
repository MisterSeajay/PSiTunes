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

