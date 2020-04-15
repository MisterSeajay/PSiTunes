function Find-iTunesDuplicatedTracks {
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
