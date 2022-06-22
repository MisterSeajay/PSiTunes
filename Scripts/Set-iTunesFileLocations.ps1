[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(ValueFromPipeline)]$Tracks,
    [Parameter()][string]$Album,
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

    if($Replace -match "[<>:""/\\|?*]"){
        throw("Illegal replacement character for file name")
    }

    switch($PSCmdlet.ParameterSetName){
        "File" {
            return ($File -replace "[<>:""/\\|?*]", $Replace)
        }

        "Path" { 
            $PathElements = $Path -split("\\")
            $Cleaned = @()
            foreach($Element in $PathElements){
                if($Element -match("^\w:$")){
                    $Cleaned += $Element
                } else {
                    $Cleaned += $Element -replace ("[<>:""/\\|?*]", $Replace)
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
    $SearchStrategies += $SearchName -replace '[(\[][^()\[\]]+([)\]]|$)', '*'
    #$SearchStrategies += $SearchName -replace ':', '-' -replace '\.', '_'
    #$SearchStrategies += $SearchName -replace '''', '_'
    #$SearchStrategies += $SearchName -replace '[.:]', '-'
    #$SearchStrategies += $SearchName + ".mp3"
    #$SearchStrategies += $SearchName + ".m4a"
    #$SearchStrategies += $SearchName + ".m4p"
    $SearchStrategies = $SearchStrategies | Select-Object -Unique

    foreach($Strategy in $SearchStrategies){
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
            Where-Object {($_.Directory | Split-Path -Leaf) -match ($Track.Album -replace "[<>:""/\\|?*.'\[\]]", ".")}

        # Write-Debug "$($MissingTrackFile.Count) hits for: ""*$Strategy*"" in $([regex]::Escape($Track.Album))"

        # If more than one found, filter for those also matching the track number as well
        if($MissingTrackFile.Count -gt 1){
            $MissingTrackFile = $MissingTrackFile |
                Where-Object {$_.Name -match [regex]::Escape($Track.TrackNumber)}
        }

        if($MissingTrackFile.Count -eq 1) {
            return $MissingTrackFile.FullName
        }        
    }

    if(-not $script:SkipErrors){
        Write-Debug "Searching '$RootPath' for:`n$($SearchStrategies | Out-String)"
    }
    Write-Error "Found $($MissingTrackFile.Count) files matching $($SearchName)"
}

function moveiTunesFile{
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory)]$Track,
        [Parameter(Mandatory)][string]$CurrentPath,
        [Parameter(Mandatory)][string]$DesiredPath
    )

    $DesiredParent = cleanIllegalFileCharacters (Split-Path -Parent $DesiredPath).trim("\")

    if(-not (Test-Path $DesiredParent)){
        New-Item -ItemType Directory -Path (Split-Path $DesiredParent -Parent) -Name (Split-Path $DesiredParent -Leaf) -Force | Out-Null
    }

    Move-Item -LiteralPath $CurrentPath $DesiredPath

    if($PSCmdlet.ShouldProcess("$DesiredPath", "Update Track location")){
        $Track.Location = $DesiredPath
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
        
        Write-Host "processAlbum: Processing $($Album.Name)"
        
        foreach($Disc in ($DiscStart..$DiscCount)){
            $DiscTracks = $AlbumTracks | Where-Object{$_.DiscNumber -eq $Disc} | Sort-Object TrackNumber
            foreach($Track in $DiscTracks){
                Write-Verbose "processAlbum: Processing Disc $Disc of $DiscCount`: '$($Track.Name)'"

                $CurrentPath = $Track.location

                if([string]::IsNullOrWhiteSpace($CurrentPath) -or `
                    -not (Test-Path -LiteralPath $CurrentPath -ErrorAction SilentlyContinue)){
                        $CurrentPath = $null
                }

                $DesiredPath = `
                    if($Track.Compilation){
                        ($RootPath, "Compilations", $Track.Album, (Format-iTunesFileName -Track $Track -DiscCount $DiscCount)) -join("\")
                    } else {
                        ($RootPath, $Track.AlbumArtist, $Track.Album, (Format-iTunesFileName -Track $Track -DiscCount $DiscCount)) -join("\")
                    }
                
                $DesiredPath = cleanIllegalFileCharacters -Path $DesiredPath

                if($DesiredPath -ne $CurrentPath){
                    try {
                        if(-not ($CurrentPath -or (Test-Path -LiteralPath $DesiredPath))){
                            $Action = "Search for file; move it to desired location & update track"
                            $CurrentPath = findMissingTrackFile -Track $Track -Root $RootPath
                            if($CurrentPath){
                                moveiTunesFile $Track $CurrentPath $DesiredPath
                            } else {
                                throw("Failed to find unique file for $($Track.Name)")
                            }
                        } elseif(-not $CurrentPath) {
                            $Action = "Update location; existing file is missing or unknown"
                            if($PSCmdlet.ShouldProcess("$DesiredPath", "Update Track location")){
                                $Track.Location = $DesiredPath
                            }                    
                        } elseif(-not (Test-Path -LiteralPath $DesiredPath)){
                            $Action = "Move file; no file exists at the expected location"
                            moveiTunesFile $Track $CurrentPath $DesiredPath
                        } elseif($CurrentPath -match "C:.Users.cjj1977.Music") {
                            $Action = "Refresh location to match new base path"
                            if($PSCmdlet.ShouldProcess("$($Track.Album) - $($Track.Name)", "Update Track location")){
                                $Track.Location = $DesiredPath
                            } else {
                                Write-Debug "FILE: $DesiredPath"
                            }
                        } elseif(Test-Path -LiteralPath $DesiredPath){
                            # Do nothing; a file is already at the desired location
                        }
                    }
                    catch {
                        Write-Debug "CURRENT PATH: $CurrentPath"
                        Write-Debug "DESIRED PATH: $DesiredPath"
                        Write-Warning "ATTEMPTED: $Action"
                        if(-not $SkipErrors){
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

Import-Module ../PSiTunes.psd1 -Force -Verbose:$False

$ErrorActionPreference = "Stop"

if($Tracks){
    $AllAlbums = $Tracks | Group-Object AlbumArtist, Album
} elseif($Album){
    $AllTracks = Search-iTunesLibrary -Album $Album -ExactMatch
    $AllAlbums = $AllTracks | Group-Object AlbumArtist, Album
} else {
    Write-Verbose "Reading the iTunes library"
    $AllTracks = $iTunesLibrary.Tracks
    Write-Warning "Grouping all tracks by AlbumArtist, Album. This can take a while..."
    $AllAlbums = $AllTracks | Group-Object AlbumArtist, Album
}

$AllAlbums | processAlbum -RootPath $RootPath