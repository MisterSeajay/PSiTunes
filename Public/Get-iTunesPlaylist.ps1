function Get-iTunesPlaylist {
    <#
    .SYNOPSIS
        Finds an iTunes playlist by name.
    .DESCRIPTION
        Searches the user''s playlists in the running iTunes application and returns
        the ones whose name matches. By default the name is treated as a regular
        expression, so "Chill" matches "Chillout" and "Chill Mix"; use ExactMatch to
        require the whole name to match.
    .PARAMETER Name
        The playlist name to look for, or a regular expression matching it. Defaults to ".", which matches every playlist.
    .PARAMETER ExactMatch
        Require the playlist name to match exactly rather than as a regular expression.
    .EXAMPLE
        Get-iTunesPlaylist -Name "Chillout" -ExactMatch
    .EXAMPLE
        Get-iTunesPlaylist -Name "^Chill"
    .NOTES
        More than one playlist can match, so the result may be a collection rather than a single playlist.
        Only the first source (the user's own playlists) is searched; the library is not.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name = ".",

        [Parameter()]
        [switch]$ExactMatch = $false
    )

    if($ExactMatch){
        $iTunesPlaylist = $iTunesApplication.Sources.Item(1).Playlists | ?{$_.Name -eq $Name}
    } else {
        $iTunesPlaylist = $iTunesApplication.Sources.Item(1).Playlists | ?{$_.Name -match $Name}
    }

    return $iTunesPlaylist
}

