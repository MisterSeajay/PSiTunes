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
    [string]
    $Add,

    [Parameter(
      Mandatory=$true,
      ParameterSetName="Remove")]
    [ValidateNotNullOrEmpty()]
    [string]
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
