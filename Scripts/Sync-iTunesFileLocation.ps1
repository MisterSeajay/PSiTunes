[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]
    $iTunesMediaPath = "D:\iTunes\iTunes Media",

    [Parameter()]
    [string]
    $SourcePath = (Get-Location),

    [Parameter()]
    [switch]
    $UseiTunesMedia
)

Import-Module S:\PowerShell\psiTunes -Force

function getFilesWithHyphens {
    [CmdletBinding()]
    param(
        [Parameter(Position=0)]
        [string]
        $Path = (Get-Location)
    )

    Get-ChildItem -Path $Path *.mp3 -Recurse |
        Where-Object {$_.Name -match "^\d+-\D"} |
        Select-Object -ExpandProperty FullName
}

function getWindowsMediaFiles {
    [CmdletBinding()]
    param(
        $Path = (Get-Location),
        $LimitArtists = 1
    )

    $IgnoredFolders = @(
        "Amazon Music"
        "Audible"
        "iTunes"
        "Playlists"
    ) -join ("|")

    $Folders = @(Get-ChildItem -LiteralPath $Path -Directory |
        Where-Object {$_.Name -notmatch $IgnoredFolders} |
        Select-Object -ExpandProperty FullName -First $LimitArtists
    )

    $Folders += $Path

    foreach($Folder in $Folders){
        Get-ChildItem -LiteralPath $Folder *.mp3 -File -Recurse |
            Select-Object -ExpandProperty FullName
    }
}

function generateSearchString {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        $MetaData
    )

    ("{0} {1}" -f $MetaData.Album, $MetaData.Name) -replace "[(\[][^)\]]+[)\]]",""
}

function getTargetPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [Alias("FileData")]
        $MetaData,

        [Parameter()]
        [string]
        $iTunesMediaPath = "D:\iTunes\iTunes Media",

        [Parameter()]
        [string]
        $MediaType = "Music"
    )

    $RootPath = Join-Path $iTunesMediaPath $MediaType

    if($MetaData.Compilation){
        $ArtistFolder = Join-Path $RootPath "Compilations"
        $Filename = "{0}-{1:d2} - {2} - {3}" -f $MetaData.DiscNumber, $MetaData.TrackNumber, $MetaData.Artist, $MetaData.Name
    } else {
        $ArtistFolder = Join-Path $RootPath $MetaData.AlbumArtist -replace "\[[^\]]+\]",""
        $Filename = "{0}-{1:d2} - {2}" -f $MetaData.DiscNumber, $MetaData.TrackNumber, $MetaData.Artist, $MetaData.Name
    }

    $AlbumFolder = Join-Path $ArtistFolder.trim() $MetaData.Album

    if(-not (Test-Path -LiteralPath $AlbumFolder)){
        New-Item -Path $AlbumFolder -ItemType Directory -ErrorAction Stop  | Out-Null
    }

    $TargetPath = Join-Path $AlbumFolder $Filename.Trim(" -")

    $TargetPath+=($MetaData.Location -as [System.IO.FileInfo]).Extension

    return $TargetPath
}

function refineSearchResults {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        $MetaData,

        [Parameter(ValueFromPipeline)]
        $Results
    )

    BEGIN {}

    PROCESS {
        $Album = $MetaData.Album -replace "[(\[][^)\]]+[)\]]",""
        $Name = $MetaData.Name -replace "[(\[][^)\]]+[)\]]",""

        $Results | Where-Object {$_.Album -match $Album.trim() `
            -and $_.Name -match $Name.trim() `
            -and $_.TrackNumber -eq $MetaData.TrackNumber}
    }
    
    END {}
}

###############################################################################
# Initialize variables

$iTunesMusicPath = Join-Path $iTunesMediaPath "Music"

###############################################################################
# Extract metadata from files to merge into iTunes

if($UseiTunesMedia){
    $Files = getFilesWithHyphens $iTunesMusicPath
    $FileData = $Files | Get-FileMetadata -RootPath $iTunesMusicPath
} else {
    $Files = getWindowsMediaFiles -Path $SourcePath
    $FileData = $Files | Get-FileMetadata -RootPath $SourcePath
}

Write-Debug "Processing $($FileData.Count) files"

###############################################################################
# Find matching track in iTunes, move the source file and update the file location

$UniqueCheck = ($FileData | Group-Object Album,Name | Measure-Object -Property Count -Maximum).Maximum

if($UniqueCheck -gt 1){
    Write-Warning "Some combinations of Album & Track name are not unique:"
    Write-Warning ($FileData | Group-Object Album,Name | Where-Object{$_.Count -gt 1} | Format-Table Album,Name | Out-String)
    exit 1
}

foreach($File in $FileData){
    $Search = generateSearchString -MetaData $File    
    $Results = Search-iTunesLibrary -Search $Search | Where-Object {[string]::IsNullOrEmpty($_.Location)}
    $Results = refineSearchResults -MetaData $File -Results $Results

    if(-not $Results){
        Write-Warning "No results (without location) returned for: $Search"
        continue
    }

    $TargetPath = getTargetPath -MetaData $File -iTunesMediaPath $iTunesMediaPath

    if($PSCmdlet.ShouldProcess($File.Location,"Move-Item")){
        Move-Item -LiteralPath $File.Location -Destination $TargetPath -Force -ErrorAction Stop
    }

    if($PSCmdlet.ShouldProcess($TargetPath,"Update iTunes Location")){
        $Results.Location = $TargetPath
    }
}

<#
function findFileDataMatchingTrack {
    param(
        $FileData,
        $iTunesTrack
    )

    $TrimmedAlbum = ($iTunesTrack.Album -replace '(^the|the$)',"").Trim(" ,")
    $TrimmedArtist = ($iTunesTrack.Artist -replace '(^the|the$)',"").Trim(" ,")

    $MatchingFile = $FileData | Where-Object {`
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

function filterAlbums {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        $FileData,

        [Parameter(Mandatory)]
        [string]
        $ByArtist
    )

    BEGIN {}

    PROCESS {
        Write-Output ($FileData | Where-Object {$_.AlbumArtist -eq $ByArtist}).Album | Select-Object -Unique
    }

    END {}
}

foreach($AlbumArtist in ($FileData.AlbumArtist | Select-Object -Unique)){

    foreach($Album in ($FileData | filterAlbums -ByArtist $AlbumArtist)){
        
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
#>