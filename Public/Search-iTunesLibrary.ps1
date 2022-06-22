function Search-iTunesLibrary {
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName="Library")]
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
        
        [Parameter(
            ParameterSetName="Track",
            ValueFromPipelineByPropertyName)]
        [int]
        $TrackNumber,

        [Parameter(ParameterSetName="Track")]
        [switch]
        $ExactMatch,

        [Parameter(ParameterSetName="Track")]
        [switch]
        $MatchAll,
        
        [Parameter()]
        [ITPlaylistSearchField]
        $SearchType = [ITPlaylistSearchField]::ITPlaylistSearchFieldVisible,
        
        [Parameter()]
        [System.Object]
        $iTunesLibrary = $(Get-iTunesLibrary)
    )
    
    $SearchString = if($PsCmdlet.ParameterSetName -eq "Track"){
        @(  (cleanSearchString $Artist), 
            (cleanSearchString $Album),
            (cleanSearchString $Name)
        ) -join " "
    } else {
        cleanSearchString $Search
    }
    
    if([string]::IsNullOrWhiteSpace($SearchString)){
        Write-Warning "Search-iTunesLibrary: Search string is empty after cleaning"
        Write-Debug "Search-iTunesLibrary: ""$Search"""
        return $null
    }

    if($PsCmdlet.ShouldProcess($SearchString, "Search")){
        $SearchResults = @($iTunesLibrary.Search($SearchString, $SearchType))
    } else {
        $SearchResults = @()
    }
    
    if(-not $SearchResults){
        Write-Debug "Search-iTunesLibrary: returned no results for $SearchString"
        return $null
    }

    if($PsCmdlet.ParameterSetName -eq "Track"){
        if($ExactMatch){
            try {
                $SearchResults = $SearchResults | Where-Object { `
                    ($_.Genre -notin ("Podcast"))} | Where-Object { `
                    ($Artist -in @($_.Artist, $_.AlbumArtist, "")) -and `
                    ($Album -in @($_.Album, "")) -and `
                    ($Name -in @($_.Name, ""))
                }
            }
            catch {
                Write-Debug ($SearchResults | Out-String)
                throw
            }

        } elseif($MatchAll){
            foreach($Token in ((cleanSearchString $Artist) -split('\s+'))){
                $SearchResults = $SearchResults |
                    Where-Object {$_.Artist -match [regex]::Escape($Token)}
            }

            foreach($Token in ((cleanSearchString $Album) -split('\s+'))){
                $SearchResults = $SearchResults |
                    Where-Object {$_.Album -match [regex]::Escape($Token)}
            }

            foreach($Token in ((cleanSearchString $Name) -split('\s+'))){
                $SearchResults = $SearchResults |
                    Where-Object {$_.Name -match [regex]::Escape($Token)}
            }

        } else {
            $Artist = cleanSearchString $Artist -IgnoreNonAlphaNumeric
            $Album = cleanSearchString $Album -IgnoreNonAlphaNumeric
            $Name = cleanSearchString $Name -IgnoreNonAlphaNumeric

            $SearchResults = $SearchResults | Where-Object {`
                ($_.Artist -match $Artist) -and `
                ($_.Album -match $Album) -and `
                ($_.Name -match $Name)
            }
        }

        if($TrackNumber){
            $SearchResults = $SearchResults |
                Where-Object {$_.Tracknumber -eq $TrackNumber}        
        }
    }

    return $SearchResults
}
