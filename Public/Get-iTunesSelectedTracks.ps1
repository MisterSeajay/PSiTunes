function Get-iTunesSelectedTracks {
    <#
    .SYNOPSIS
        Returns the tracks currently selected in iTunes.
    .DESCRIPTION
        Returns the tracks the user has selected in the iTunes window. Several
        commands default to this, so it is usually worth piping a specific set of
        tracks in rather than relying on the selection.
    .EXAMPLE
        Get-iTunesSelectedTracks
    .EXAMPLE
        Get-iTunesSelectedTracks | Set-iTunesTrackRating -Rating 5
    .NOTES
        Writes an error and returns $false if iTunes is not running.
        Warns and returns $null if nothing is selected.
    #>
    [CmdletBinding()]
    [OutputType([System.__ComObject])]
    param()

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
