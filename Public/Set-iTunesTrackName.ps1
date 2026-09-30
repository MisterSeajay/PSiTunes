function Set-iTunesTrackName {
    <#
    .SYNOPSIS
        Renames or normalises the names of iTunes tracks.
    .DESCRIPTION
        In the Normalize mode, rewrites the Name of each supplied track by replacing
        doubled single quotes with a single double quote and capitalising each
        word. In the Set mode, changes the name of the track at a given library
        index. Tracks whose name already matches are left alone.
    .PARAMETER Tracks
        The tracks to normalise. Accepts pipeline input.
    .PARAMETER Normalize
        Normalise the names of the supplied tracks.
    .PARAMETER TrackIndex
        The library index of the track to rename.
    .PARAMETER Name
        The new name for the track at TrackIndex.
    .PARAMETER iTunesLibrary
        The library to look the track up in. Defaults to the global set when the module was imported.
    .EXAMPLE
        Get-iTunesPlaylistTracks -Playlist "Chillout" | Set-iTunesTrackName -Normalize
    .EXAMPLE
        Set-iTunesTrackName -TrackIndex 42 -Name "New name"
    .NOTES
        iTunesLibrary falls back to the module global of the same name. A caller who has a different $iTunesLibrary in scope silently changes which library is modified; pass it explicitly if that matters.
        This rewrites the Name field only, not the file name on disk.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ParameterSetName="Normalize")]
        [System.Object]
        $Tracks,

        [Parameter(ParameterSetName="Normalize")]
        [switch]
        $Normalize,

        [Parameter(ParameterSetName="Set")]
        [int]
        $TrackIndex,

        [Parameter(ParameterSetName="Set")]
        [string]
        $Name,

        [Parameter(ParameterSetName="Set")]
        [System.Object]
        $iTunesLibrary = $iTunesLibrary   # Uses global variable if set
    )

    BEGIN {
    }

    PROCESS {
        switch ($PsCmdlet.ParameterSetName){
            "Normalize" {
                if(-not $Tracks -or $Tracks.Count -lt 1){
                    Write-Error "Nothing to normalize"
                    return $null
                }
            }

            "Set" {
                $Tracks = $iTunesLibrary.Tracks | ?{$_.Index -eq $TrackIndex}

                if(-not $Tracks){
                    Write-Error "Track not found with index $TrackIndex"
                    return $null
                }
            }
        }

        ##############################################################################################
        # Prepare the new track name in a hash table

        $NewNames = @{}

        foreach($Track in $Tracks){
            if($NewNames."$($Track.Index)"){
                Write-Error "Track $($Track.Index) ($($Track.Name)) already encountered."
            } else {
                # Create a new entry in the hash table with the current track name
                $NewNames."$($Track.Index)" = $Track.Name

                # Update entry, replace 2x single quotes with 1x double quote
                $NewNames."$($Track.Index)" = $NewNames."$($Track.Index)" -replace "''",'"'

                # Update entry, capitalizing the first letter of each word
                $NewNames."$($Track.Index)" = convertToCapitalizedWords $NewNames."$($Track.Index)"
            }
        }

        ##############################################################################################
        # Update any track names that need to be changed

        foreach($Track in $Tracks){
            # Run a case-sensitive match to see if we changed anything, as we don't want to waste time
            # updating names that don't need to change.
            if(Compare-Object $Track.Name $NewNames."$($Track.Index)" -CaseSensitive){
                Set-iTunesTrackData -Tracks $Track -Attribute Name -value ($NewNames."$($Track.Index)")
            }
        }
    }

    END {
    }
}
