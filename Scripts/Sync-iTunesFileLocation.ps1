[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]
    $iTunesMediaPath = "D:\iTunes\iTunes Media",

    [Parameter()]
    [string]
    $WindowsMediaPath = "S:\Music\Ripped",

    [Parameter()]
    [switch]
    $UseLocalMedia
)

Import-Module C:\Scripts\PowerShell\psiTunes

function getFilesWithHyphens {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]
        $Path = (Get-Location)
    )

    Get-ChildItem -Path $Path *.mp3 -Recurse |
        Where-Object {$_.Name -match "^\d+-\D"} |
        Select-Object -ExpandProperty Fullname
}

function getWindowsMediaFiles {
    [CmdletBinding()]
    param(
        $Path = (Get-Location),
        $LimitArtists = 1
    )

    $IgnoredFolders = @(
        "Amazon Music"
        "iTunes"
        "Playlists"
        "Various Artists"
    ) -join ("|")

    $Folders = Get-ChildItem -Path $Path -Directory |
        Where-Object {$_.Name -notmatch $IgnoredFolders} |
        Select-Object -ExpandProperty Fullname -First $LimitArtists

    foreach($Folder in $Folders){
        Get-ChildItem -Path $Folder *.mp3 -Recurse |
            Select-Object -ExpandProperty Fullname
    }
}

function getDataFromFile {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [string]
        $Fullname,

        [Parameter(Position=1)]
        [string]
        $Path = (Get-Location)
    )
    
    BEGIN {}

    PROCESS {
        $Data = ($Fullname -replace "$([Regex]::Escape($Path))\\","") -split('\\')
        [PSCustomObject]@{
            File = $Fullname
            Artist = $Data[0]
            Album = $Data[1]
            TrackNumber = $Data[2] -replace '^(\d+).*','$1'
            Name = $Data[2] -replace '^\d+-(.+)','$1'
        }
    }

    END {}
}

function findFileDataMatchingTrack {
    param(
        $FileData,
        $iTunesTrack
    )

    $TrimmedAlbum = ($iTunesTrack.Album -replace '(^the|the$)',"").Trim(" ,")
    $TrimmedArtist = ($iTunesTrack.Artist -replace '(^the|the$)',"").Trim(" ,")

    $MatchingFile = $FileData | Where-Object{`
        ($_.Album -match $TrimmedAlbum) -and `
        ($_.Artist -match $TrimmedArtist) -and `
        ([int]$_.TrackNumber -eq [int]$iTunesTrack.TrackNumber)}
    
    if($MatchingFile.Count -gt 1){
        $Warning = "Multiple matches for"
    } elseif($MatchingFile){
        return $MatchingFile.File
    } else {
        $Warning = "Could not find File matching iTunes entry for"
    }

    $Warning+= ": $($iTunesTrack.Artist) "
    $Warning+= "~ $($iTunesTrack.Album) "
    $Warning+= "~ $($iTunesTrack.TrackNumber)"
    Write-Warning $Warning

    return $null
}

function updateMediaLocation {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline)]
        $FileData,

        [Parameter(Mandatory)]
        [string]
        $Source,

        [Parameter(Mandatory)]
        [string]
        $Destination
    )

    BEGIN {}

    PROCESS {
        $OldLocation = $FileData.File
        $NewLocation = $FileData.File -replace [Regex]::Escape($Source),$Destination
        
        $NewFolder = New-Item (Split-Path $NewLocation -Parent) -ItemType Directory -Force
        
        $NewName = (Split-Path $FileData.File -Leaf) -replace '(\d+)-(.+)','$1 $2'

        $NewLocation = Join-Path $NewFolder $NewName
        
        if($PSCmdlet.ShouldProcess($FileData.File,"Update FileData")){
            $FileData.File = $NewLocation
            Write-Debug "Moving file from: $OldLocation"
            Write-Warning "Moving file to: $NewLocation"
        }
        
        Move-Item -LiteralPath $OldLocation -Destination $NewLocation

        if(-not (Test-Path -LiteralPath $NewLocation)){
            Write-Warning "Failed to move $OldLocation"
        } else {
            # Move any album art
            Get-ChildItem -Path (Split-Path $OldLocation -Parent) *.jpg |
                Foreach-Object {
                    Write-Debug "Moving $($_.FullName) to $NewFolder"
                    Move-Item -LiteralPath $_.FullName -Destination $NewFolder
                }

            Write-Output $FileData
        }
    }

    END {
    }
}

###############################################################################
# Initialize variables

$iTunesMusicPath = Join-Path $iTunesMediaPath "Music"

Set-Location $iTunesMusicPath

###############################################################################
# Find files to merge into iTunes

if($UseLocalMedia){
    $Files = getFilesWithHyphens $iTunesMusicPath
    $FileData = $Files | getDataFromFile -Path $iTunesMusicPath
    Write-Verbose "Processing $($FileData.Count) files"

} else {
    $Files = getWindowsMediaFiles -Path $WindowsMediaPath
    $FileData = $Files | getDataFromFile -Path $WindowsMediaPath
    Write-Verbose "Processing $($FileData.Count) files"

    $FileData = $FileData | updateMediaLocation -Source $WindowsMediaPath -Destination $iTunesMusicPath
}

###############################################################################
# Find matching track in iTunes and update the file location

foreach($Artist in ($FileData.Artist | Select-Object -Unique)){

    foreach($Album in (($FileData | ?{$_.Artist -eq $Artist}).Album | Select-Object -Unique)){
        
        Write-Verbose "Finding matching items in iTunes library"
        $TrimmedArtist = ($Artist -replace "the","").Trim(" ,.")
        $iTunesTracks = Search-iTunesLibrary -AlbumName $Album -ArtistName $TrimmedArtist

        if(-not $iTunesTracks){
            continue
        }

        Write-Verbose "Matching up iTunes tracks to new file"

        foreach($iTunesTrack in $iTunesTracks){
            $Location = findFileDataMatchingTrack -FileData $FileData -iTunesTrack $iTunesTrack

            if($Location -and $PSCmdlet.ShouldProcess($iTunesTrack.Name,"Update File Location")){
                Write-Debug $Location
                $iTunesTrack.Location = $Location
            }
        }
    }
}