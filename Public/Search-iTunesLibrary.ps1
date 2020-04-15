function Search-iTunesLibrary {
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [Parameter(
      ParameterSetName="Library",
      Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [string]
    $Search,
    
    [Parameter( 
      ParameterSetName="Track",
      ValueFromPipelineByPropertyName)]
    [string]
    $Album = "",
    
    [Parameter(
      ParameterSetName="Track",
      ValueFromPipelineByPropertyName)]
    [string]
    $Artist = "",
    
    [Parameter(
      ParameterSetName="Track",
      ValueFromPipelineByPropertyName)]
    [string]
    $Name = "",
    
    [Parameter()]
    [SearchTypes]
    $SearchType = [SearchTypes]::ITPlaylistSearchFieldAll,
    
    [Parameter()]
    [System.Object]
    $iTunesLibrary = $(Get-iTunesLibrary)
  )
  
  if($PsCmdlet.ParameterSetName -eq "Track"){
    $Search = "$Artist $Album $Name"
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
    ($_.Artist -match $Artist) -and `
    ($_.Album -match $Album) -and `
    ($_.Name -match $Name)}
    
  # Return the list of tracks as an array
  return $Tracks
}
