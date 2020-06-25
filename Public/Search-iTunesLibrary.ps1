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
        [ITPlaylistSearchField]
        $SearchType = [ITPlaylistSearchField]::ITPlaylistSearchFieldAll,
        
        [Parameter()]
        [System.Object]
        $iTunesLibrary = $(Get-iTunesLibrary)
    )
    
    if($PsCmdlet.ParameterSetName -eq "Track"){
        $Search = "$Artist $Album $Name"
    }
    
    # Clean up search string
    $SearchString = $Search
    $SearchString = $SearchString -replace '[\[(][^\[)]+[\])]','' # Remove text in brackets
    $SearchString = $SearchString -replace '[\W-[ ]]','' # Remove punctuation except for spaces
    $SearchString = $SearchString -replace '\s{2,}',' '  # Remove unnecessarily wide spaces
    $SearchString = $SearchString.trim()

    if($SearchString){
        $SearchResults = @($iTunesLibrary.Search($SearchString, $SearchType))
    } else {
        Write-Error "Search string is empty"
        return $null
    }
    
    if(-not $SearchResults){
        Write-Debug "Search returned no results for $SearchString"
        return $null
    } else {
        Write-Debug "Search returned $($SearchResults.Count) result(s)"
    }

    # Create a list of tracks from the search results
    $Tracks = @()
    $SearchResults | Foreach-Object {$Tracks += $_}
    
    # Filter results if a "track" search was used
    $Tracks = $Tracks | Where-Object {`
        ($_.Artist -match $Artist) -and `
        ($_.Album -match $Album) -and `
        ($_.Name -match $Name)}
      
    # Return the list of tracks as an array
    return $Tracks
}
