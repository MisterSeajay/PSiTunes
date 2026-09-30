function Set-iTunesTrackData {
    <#
    .SYNOPSIS
        Sets a single attribute on one or more iTunes tracks.
    .DESCRIPTION
        Writes one attribute to each supplied track. This is the low-level command
        the other Set-iTunesTrack* commands build on; use it when you need to set
        an attribute they do not cover. Accepts pipeline input.
    .PARAMETER Tracks
        The tracks to change. Accepts pipeline input.
    .PARAMETER Attribute
        The name of the attribute to set, for example Name or Rating.
    .PARAMETER Value
        The value to set. Must be an integer, a string or a DateTime.
    .EXAMPLE
        Get-iTunesSelectedTracks | Set-iTunesTrackData -Attribute "Comment" -Value "ripped 2026"
    .NOTES
        The value must be an Int, String or DateTime; anything else is rejected at parameter binding.
        Writes to iTunes immediately, so this cannot be undone from PowerShell.
        This command does not release the COM references it is given. Iterating a large track collection without releasing each track leaks handles, which shows up later as iTunes refusing new automation calls.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true)]
        [System.Object[]]
        $Tracks,

        [Parameter()]
        [string]
        $Attribute,

        [Parameter()]
        [ValidateScript({$_.GetType() -in ([Int],[String],[DateTime])})]
        $Value
    )

    BEGIN {
    }

    PROCESS {
        foreach($Track in $Tracks){
            if($PSCmdlet.ShouldProcess((formatiTunesTrackInfo -Track $Track),"Set $Attribute")){
                Write-Debug "Set-iTunesTrackData: Set $Attribute to $Value [$($Value.GetType().FullName)]"
                $Track.$Attribute = $Value
            } else {
                Write-Debug "Set-iTunesTrackData: Set $Attribute to $Value [$($Value.GetType().FullName)]"
            }
        }
    }

    END {
    }
}