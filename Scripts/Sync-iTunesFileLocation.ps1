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
    $UseiTunesMedia,

    [Parameter()]
    [int]
    $FolderLimit = 2
)

trap {
    Write-Debug $_.Exception
    throw
    exit 1
}

Import-Module S:\PowerShell\psiTunes -Force -Verbose:$false

###############################################################################
# internal functions
#region

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

function getWindowsMediaFolders {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [System.Management.Automation.PathInfo]
        $Path = (Get-Location)
    )

    BEGIN {
        $IgnoredFolders = @(
            "Amazon Music"
            "Audible"
            "iTunes"
            "Playlists"
        ) -join ("|")
    }
    
    PROCESS {
        Write-Output $Path

        Get-ChildItem -LiteralPath $Path.ToString() -Directory -Recurse |
            Where-Object {$_.Name -notmatch $IgnoredFolders} |
            Foreach-Object {Resolve-Path -LiteralPath $_.Name}
    }

    END {}
}

function hasEmptyProperties {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(ValueFromPipeline)]
        $InputObject,

        [Parameter(Mandatory)]
        [Alias("Property")]
        $Properties
    )

    foreach($Property in $Properties) {
        if([string]::IsNullOrWhiteSpace($InputObject.$Property)){
            return $true
        }
    }

}

function generateSearchString {
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline)]
        $MetaData,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        $Properties = @("Album","Name")
    )

    $SearchString = ""

    foreach($Property in $Properties){
        $SearchString += $Metadata.$Property + " "
    }

    return ($SearchString -replace "[(\[][^)\]]+[)\]]","")
}

function removeInvalidFileNameChars {
    param(
        [Parameter(Position=0,Mandatory,ValueFromPipeline=$true)]
        [string]
        $String
    )
  
    $InvalidFileNameChars = [System.IO.Path]::GetInvalidFileNameChars() -join ''
    $InvalidFileNameChars+= ":;."
    $InvalidFileNameRegex = "[{0}]" -f [RegEx]::Escape($InvalidFileNameChars)
    return ($String -replace $InvalidFileNameRegex,"_").trim()
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
        $AlbumArtist = removeInvalidFilenameChars -String $MetaData.AlbumArtist
        $ArtistFolder = Join-Path $RootPath $AlbumArtist
        $Filename = "{0}-{1:d2} - {2}" -f $MetaData.DiscNumber, $MetaData.TrackNumber, $MetaData.Artist, $MetaData.Name
    }

    $Album = removeInvalidFilenameChars -String $MetaData.Album
    $AlbumFolder = Join-Path $ArtistFolder $Album

    if(-not (Test-Path -LiteralPath $AlbumFolder)){
        New-Item -Path $AlbumFolder -ItemType Directory -ErrorAction Stop  | Out-Null
    }

    $Filename = removeInvalidFilenameChars -String $Filename

    $TargetPath = Join-Path $AlbumFolder $Filename.Trim(" -")

    $TargetPath+=($MetaData.Location -as [System.IO.FileInfo]).Extension

    return $TargetPath
}

function refineSearchResults {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        $MetaData,

        [Parameter(Position=1, ValueFromPipeline)]
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

#endregion
###############################################################################

###############################################################################
# Extract metadata from files to merge into iTunes

$iTunesMusicPath = Join-Path $iTunesMediaPath "Music"

if($UseiTunesMedia){
    $Files = getFilesWithHyphens $iTunesMusicPath
    $FileData = $Files | Get-FileMetadata -RootPath $iTunesMusicPath
} else {
    $Folders = getWindowsMediaFolders -Path (Resolve-Path -LiteralPath $SourcePath)
    $FileData = $Folders | Select-Object -First $FolderLimit | Get-FileMetadata -RootPath $SourcePath
}

$FileData = @($FileData | Where-Object {-not [string]::IsNullOrEmpty($_.Location)})

$UniqueCheck = ($FileData | Group-Object Album,Name | Measure-Object -Property Count -Maximum).Maximum

if($UniqueCheck -gt 1){
    Write-Warning "Some combinations of Album & Track name are not unique:"
    Write-Warning ($FileData | Group-Object Album,Name | Where-Object{$_.Count -gt 1} | Format-Table Album,Name | Out-String)
    exit 1
}

Write-Debug "Processing $($FileData.Count) files"

###############################################################################
# Find matching track in iTunes, move the source file and update the file location

$Output = New-Object -TypeName System.Collections.ArrayList
$Progress = 0

foreach($File in $FileData){
    $Progress++
    $Results = $null
    $Properties = @("Name", "Album")

    if($File | hasEmptyProperties -Property $Properties){
        continue
    }

    Write-Progress -Activity "Processing source files" -CurrentOperation $File.Location `
        -PercentComplete ([math]::floor(($Progress/$FileData.Count)*100))

    $obj = $File | Select-Object -Property Location,Status

    Write-Debug "Processing source file: $($File.Location)"
    
    do {
        $Search = generateSearchString -MetaData $File -Properties $Properties
        $Results = Search-iTunesLibrary -Search $Search | refineSearchResults -MetaData $File
        $Properties[-1]=$null
        $Properties = $Properties -ne $null
    } while ($Properties -and $Results.Count -ne 1)

    if(-not $Results){
        Write-Warning ("Failed to match in iTunes: {0} - {1} - {2}" -f $File.Album, $File.Artist, $File.Name)
        $obj.Status = "Missing"
        [void]$Output.Add($obj)
        continue
    }

    if(-not [string]::IsNullOrWhiteSpace($Results.Location)){
        Write-Warning "File present: $($Results.Location)"
        $obj.Status = "Skipped"
        [void]$Output.Add($obj)
        # Move or delete this duplicate file?
        # Check the target iTunes track for "re-rip" label?
        continue
    }

    Write-Debug ("Updating iTunes track: {0} - {1} - {2}" -f $Results.Album, $Results.Artist, $Results.Name)
    
    $TargetPath = getTargetPath -MetaData $File -iTunesMediaPath $iTunesMediaPath

    if($PSCmdlet.ShouldProcess($File.Location,"Move-Item")){
        Write-Debug "Copying source file to: $TargetPath"

        try {
            Copy-Item -LiteralPath $File.Location -Destination $TargetPath -Force -ErrorAction Stop
        } catch {
            Write-Warning "Failed"
            $obj.Status = "Failed to copy file"
            [void]$Output.Add($obj)
            continue
        }
    }

    if($PSCmdlet.ShouldProcess($TargetPath,"Update iTunes Location")){
        try {
            $Results.Location = $TargetPath
        } catch {
            Write-Warning "Failed to update iTunes"
            Write-Debug "$($File.Location) > $($TargetPath)"
            $obj.Status = "Failed"
            [void]$Output.Add($obj)

            Remove-Item -LiteralPath $TargetPath -Force -ErrorAction Stop
            throw
        } 
    }

    if($PSCmdlet.ShouldProcess($File.Location,"Remove-Item")){
        Write-Debug "Removing source file: $($File.Location)"

        try {
            Remove-Item -LiteralPath $File.Location -Force -ErrorAction Stop
        } catch {
            Write-Warning "Failed to remove source file"
        }
    }

    $obj.Status = "Updated"

    [void]$Output.Add($obj)
}

Write-Progress -Activity "Processing source files" -Completed

Write-Output $Output

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