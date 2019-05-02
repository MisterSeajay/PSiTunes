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
    Write-Debug $SearchString
    $SearchResults = $iTunesLibrary.Search($SearchString, $SearchType)
  } else {
    Write-Error "Search string is empty"
    return $null
  }
  
  if(-not $SearchResults){
    Write-Warning "Search returned no results"
    return $null
  }
  # Create a list of tracks from the search results
  $Tracks = @()
  $SearchResults | %{$Tracks += $_}
  
  # Filter results if a "track" search was used
  $Tracks = $Tracks | Where-Object {`
    ($_.Artist -match $ArtistName) -and `
    ($_.Album -match $AlbumName) -and `
    ($_.Name -match $TrackName)}
    
  # Return the list of tracks as an array
  return $Tracks
}
