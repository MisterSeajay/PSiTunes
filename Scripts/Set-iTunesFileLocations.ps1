[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ValueFromPipeline)]$Tracks,
    [Parameter()][string]$Album,
    [Parameter()][string]$PathSearch,
    [Parameter()][string]$RootPath = $iTunesRoot,
    [Parameter()][switch]$ExactMatch = $false,
    [Parameter()][switch]$SkipErrors = $false
)

###############################################################################
# helper functions
#region

function cleanIllegalFileCharacters {
    [CmdletBinding(DefaultParameterSetName="Path")]
    param(
        [Parameter(Mandatory, ParameterSetName="Path", Position=0)][string]$Path,
        [Parameter(Mandatory, ParameterSetName="File", Position=0)][string]$File,
        [Parameter()][string]$Replace = "_"
    )
    $IllegalCharacters = "[<>:""/\\|?*]"

    if($Replace -match $IllegalCharacters) {
        throw("cleanIllegalFileCharacters: Illegal replacement character for file name")
    }

    switch($PSCmdlet.ParameterSetName) {
        "File" {
            return ($File -replace $IllegalCharacters, $Replace)
        }

        "Path" {
            $PathElements = $Path -split("\\")
            $Cleaned = @()
            foreach($Element in $PathElements) {
                if($Element -match("^\w:$")) {
                    $Cleaned += $Element
                } else {
                    $Cleaned += $Element -replace ($IllegalCharacters, $Replace)
                }
            }
            return ($Cleaned -join ("\") -replace ("\\+", "\"))
        }
    }
}

function findMissingTrackFile {
    param (
        [Parameter(ValueFromPipeline)]$Track,
        [Parameter(Mandatory)][string]$RootPath
    )

    $SearchName = $Track.Name -replace "[<>:""/\\|?*.'\[\]]", "*"

    # Make a list of variant file name patterns that we will loop through to find a match
    $SearchStrategies = @()
    $SearchStrategies += "{0}-{1:00} {2}" -f $Track.DiscNumber, $Track.TrackNumber, $SearchName
    $SearchStrategies += "{0}-{1:00}*{2}" -f $Track.DiscNumber, $Track.TrackNumber, $SearchName
    $SearchStrategies += "{0:00} -* {1}" -f $Track.TrackNumber, $SearchName
    $SearchStrategies += "{0:00} * {1}" -f $Track.TrackNumber, $SearchName
    $SearchStrategies += "{0:00} {1}" -f $Track.TrackNumber, $SearchName
    $SearchStrategies += "?? {0}" -f $SearchName
    $SearchStrategies += $SearchName -replace '[(\[][^()\[\]]+([)\]]|$)', '*'
    #$SearchStrategies += $SearchName -replace ':', '-' -replace '\.', '_'
    #$SearchStrategies += $SearchName -replace '''', '_'
    #$SearchStrategies += $SearchName -replace '[.:]', '-'
    #$SearchStrategies += $SearchName + ".mp3"
    #$SearchStrategies += $SearchName + ".m4a"
    #$SearchStrategies += $SearchName + ".m4p"
    $SearchStrategies = $SearchStrategies | Select-Object -Unique

    foreach($Strategy in $SearchStrategies) {
        # Shorten track names, 24 characters looks about right?
        try {
            $ShortStrategy = $Strategy.Substring(0, 24)
        }
        catch {
            $ShortStrategy = $Strategy
        }
        finally {
            $Strategy = $ShortStrategy.trim(" *") -replace("\*+", "*") -replace("\s+\*+", " *")
        }

        # Find ALL possible files under the root path matching the track and album name
        $MissingTrackFile = Get-ChildItem -Path $RootPath -Recurse -File "*$Strategy*" |
            Where-Object {($_.Directory | Split-Path -Leaf) -match ([regex]::Escape($Track.Album))}

        # Write-Debug "$($MissingTrackFile.Count) hits for: ""*$Strategy*"" in $([regex]::Escape($Track.Album))"

        # If more than one found, filter for those also matching the track number as well
        if($MissingTrackFile.Count -gt 1) {
            $MissingTrackFile = $MissingTrackFile |
                Where-Object {$_.Name -match [regex]::Escape($Track.TrackNumber)}
        }

        if($MissingTrackFile.Count -eq 1) {
            return $MissingTrackFile.FullName
        }
    }

    if($script:SkipErrors) {
        Write-Warning "Found $($MissingTrackFile.Count) files matching $($SearchName)"
    } else {
        Write-Debug "Searching '$RootPath' for:`n$($SearchStrategies | Out-String)"
        Write-Error "Found $($MissingTrackFile.Count) files matching $($SearchName)"
    }
}

function moveiTunesFile {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]$Track,
        [Parameter(Mandatory)][string]$CurrentPath,
        [Parameter(Mandatory)][string]$DesiredPath
    )

    if($DesiredPath -ne (cleanIllegalFileCharacters $DesiredPath)) {
        throw("moveiTunesFile: DesiredPath must not contain illegal characters")
    }

    $DesiredParent = (Split-Path -Parent $DesiredPath).trim("\")

    if(-not (Test-Path $DesiredParent)) {
        New-Item -ItemType Directory -Path (Split-Path $DesiredParent -Parent) -Name (Split-Path $DesiredParent -Leaf) -Force | Out-Null
    }

    # Write-Debug "moveiTunesFile: Updating`n`t$CurrentPath to`n`t$DesiredPath"

    if($PSCmdlet.ShouldProcess("$CurrentPath", "Move-Item")) {
        Move-Item -LiteralPath $CurrentPath -Destination $DesiredPath
    } else {
        # Stop here in ShouldProcess mode...
        return
    }

    if(Test-Path -LiteralPath $DesiredPath) {
        # Move successful; update Track details
        $Track.Location = $DesiredPath
        # Write-Debug "moveiTunesFile: Track Location updated to $($Track.Location)"
    } else {
        Write-Error "File missing at expected location: '$DesiredPath'"
        throw("moveiTunesFile: Failed to move file")
    }
}

#endregion
###############################################################################

###############################################################################
# main functions
#region

function processAlbum {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline)]$Album,
        [Parameter(Mandatory)][string]$RootPath
    )

    BEGIN {
    }

    PROCESS {
        $AlbumTracks = $Album.Group
        $DiscStart = [int]($AlbumTracks | Measure-Object -Minimum DiscNumber | Select-Object -ExpandProperty Minimum)
        $DiscCount = [int]($AlbumTracks | Measure-Object -Maximum DiscNumber | Select-Object -ExpandProperty Maximum)

        Write-Verbose "processAlbum: Processing $($Album.Name)"

        foreach($Disc in ($DiscStart..$DiscCount)) {
            $DiscTracks = $AlbumTracks | Where-Object{$_.DiscNumber -eq $Disc} | Sort-Object TrackNumber
            foreach($Track in $DiscTracks) {
                $CurrentPath = $Track.Location

                if([string]::IsNullOrWhiteSpace($CurrentPath)) {
                    $CurrentPath = $null
                } elseif(-not (Test-Path -LiteralPath $CurrentPath)) {
                    $CurrentPath = $null
                } else {
                    # Write-Debug "processAlbum: File found:`n`t'$CurrentPath'"
                }

                $DesiredPath = `
                    if($Track.Album -match "^Various \([\w ]+\)$") {
                        $UsualName = Format-iTunesFileName -Track $Track -DiscCount 0
                        $NoTrackNumber = $UsualName -replace '^\d+[ -]+', ''
                        ($RootPath, "Compilations", $Track.Album, $NoTrackNumber) -join("\")
                    } elseif($Track.Compilation) {
                        ($RootPath, "Compilations", $Track.Album, (Format-iTunesFileName -Track $Track -DiscCount $DiscCount)) -join("\")
                    } else {
                        ($RootPath, $Track.AlbumArtist, $Track.Album, (Format-iTunesFileName -Track $Track -DiscCount $DiscCount)) -join("\")
                    }

                $DesiredPath = cleanIllegalFileCharacters -Path $DesiredPath

                if($DesiredPath -ne $CurrentPath) {
                    try {
                        if(-not $CurrentPath) {
                            if(Test-Path -LiteralPath $DesiredPath) {
                                # File location is missing but a file exists at the desired location
                                $Action = "Update location; existing file is missing or unknown"
                                if($PSCmdlet.ShouldProcess("$DesiredPath", "Update Track location")) {
                                    $Track.Location = $DesiredPath
                                }
                            } else {
                                # Neither CurrentPath or DesiredPath exist; try searching for the file
                                $Action = "Search for file; move it to desired location & update track"
                                $FoundPath = findMissingTrackFile -Track $Track -Root $RootPath
                                if($FoundPath) {
                                    moveiTunesFile $Track $FoundPath $DesiredPath
                                } else {
                                    throw("Failed to find unique file for $($Track.Name)")
                                }
                            }
                        } elseif(-not (Test-Path -LiteralPath $DesiredPath)) {
                            # File exists and can be moved to the new location
                            $Action = "Move file; no file exists at the desired location"
                            # Write-Debug "processAlbum: $Action"
                            moveiTunesFile $Track $CurrentPath $DesiredPath
                        } elseif($CurrentPath -notlike "$RootPath*") {
                            # File path uses legacy location; refresh to new base path
                            $Action = "Refresh location to match new base path"
                            # Write-Debug "processAlbum: $Action"
                            if($PSCmdlet.ShouldProcess("$DesiredPath", "Update Track location")) {
                                $Track.Location = $DesiredPath
                            } else {
                                Write-Debug "FILE: $DesiredPath"
                            }
                        } elseif(Test-Path -LiteralPath $DesiredPath) {
                            # Do nothing; a file is already at the desired location
                            # $Action = "Do nothing"
                            Write-Debug "processAlbum: $Action"
                        }
                    }
                    catch {
                        Write-Debug "ATTEMPTED TO: $Action"
                        Write-Debug "CURRENT PATH: $CurrentPath"
                        Write-Debug "DESIRED PATH: $DesiredPath"
                        if(-not $SkipErrors) {
                            Write-Output $Track
                            throw
                        } else {
                            Write-Warning $_.Exception.Message.ToString()
                        }
                    }
                }
            }
        }
    }

    END {
    }
}

#endregion
###############################################################################

# Find the module relative to the script's location.
$ModulePath = Join-Path $PSScriptRoot '..\PSiTunes.psd1' | Resolve-Path -ErrorAction SilentlyContinue
if ($ModulePath) {
    if (Get-Module -Name PSiTunes) {
        # Module is already loaded, so force a reload to pick up any changes.
        Import-Module $ModulePath -Force -Verbose:$False
    } else {
        # Module is not loaded, so a standard import is sufficient.
        Import-Module $ModulePath -Verbose:$False
    }
} else {
    Write-Error "Could not find the PSiTunes module. Please ensure 'Set-iTunesFileLocations.ps1' is in a 'Scripts' subfolder of the PSiTunes module."
    exit 1
}

$ErrorActionPreference = "Stop"

if($Tracks) {
    $AllAlbums = $Tracks | Group-Object AlbumArtist, Album
} elseif($Album) {
    Write-Verbose "Searching the iTunes library..."
    $AllTracks = Search-iTunesLibrary -Album $Album -ExactMatch
} elseif($PathSearch) {
    Write-Verbose "Filtering the iTunes library by Location..."
    $AllTracks = $global:iTunesLibrary.Tracks | Where-Object { $_.Location -match [regex]::Escape($PathSearch) }
} else {
    Write-Verbose "Filtering the iTunes library by Media Kind..."
    $AllTracks = $global:iTunesLibrary.Tracks | Where-Object { $_.Kind -eq 1 } # ITTrackKindFile
}

if($AllTracks) {
    Write-Debug "Found $($AllTracks.Count) tracks"
    Write-Warning "Grouping all tracks by AlbumArtist, Album. This can take a while..."
    $AllAlbums = $AllTracks | Group-Object AlbumArtist, Album
}

$AllAlbums | processAlbum -RootPath $RootPath