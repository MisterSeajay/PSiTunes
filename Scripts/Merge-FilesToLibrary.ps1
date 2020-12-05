[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter()]
    [string]
    $iTunesMediaPath = "D:\iTunes\iTunes Media",

    [Parameter()]
    [string]
    $SourcePath = "D:\Music\Ripped",
    #$SourcePath = (Get-Location),

    [Parameter()]
    [string]
    $DuplicatePath = (Join-Path (Split-Path $SourcePath -Parent) "Duplicate"),

    [Parameter()]
    [switch]
    $AddMissing,

    [Parameter()]
    [switch]
    $MoveDuplicates,

    [Parameter()]
    [switch]
    $Force,

    [Parameter()]
    [switch]
    $UseiTunesMedia,

    [Parameter()]
    [int]
    $FolderLimit = 0
)

Set-StrictMode -Version 2

$cwd = Split-Path $MyInvocation.InvocationName -Parent
$PSiTunes = Resolve-Path -Path (Join-Path $cwd "../PSiTunes.psd1")
Import-Module $PSiTunes -Force -Verbose:$false

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
        $Subfolders = @(Get-ChildItem -LiteralPath $Path.ToString() -Directory -Recurse |
            Where-Object {$_.Name -notmatch $IgnoredFolders} |
            Select-Object -ExpandProperty FullName)

        $Subfolders+= (Resolve-Path -LiteralPath $Path).Path

        foreach($Folder in $Subfolders){
            if(Get-ChildItem -LiteralPath $Folder -File){
                Write-Output $Folder
            }
        }
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
        if($SearchString -notmatch [regex]::Escape($Metadata.$Property)){
            $SearchString += $Metadata.$Property + " "
        }
    }

    Write-Debug "generateSearchString: $SearchString"

    return $SearchString
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
        $Filename = "{0}-{1:d2} - {2}" -f $MetaData.DiscNumber, $MetaData.TrackNumber, $MetaData.Name
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

function cleanTextForRefining {
    [CmdletBinding()]
    param(
        [Parameter(ValueFromPipeline)]
        [string]
        $InputObject,

        [Parameter()]
        [switch]
        $ReplaceNonAlphaNumeric
    )

    BEGIN {
        $StuffInBrackets = '[(\[][^)\]]+[)\]]'
        $WordsWeDontWant = '(^\s*the\b|\bthe\s*$)'
        $StuffToTrimAway = '(^\s*\W?|\W?\s*$)'
        $NonAlphaNumeric = '[\W_-[ ]]'
    }

    PROCESS {
        $InputObject = $InputObject -replace $StuffInBrackets, ''
        $InputObject = $InputObject -replace $WordsWeDontWant, ''
        $InputObject = $InputObject -replace $StuffToTrimAway, ''
        if($ReplaceNonAlphaNumeric){
            $InputObject = $InputObject -replace $NonAlphaNumeric, '.?'
        }
        $InputObject = $InputObject -replace '\s+', ' '
        return $InputObject
    }

    END {}
}

function refineSearchResults {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        [ValidateNotNullOrEmpty()]
        $MetaData,      # Reference track, i.e. metadata from non-iTunes file

        [Parameter(Position=1, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        $Target         # Search results (tracks) to refine against reference data
    )

    BEGIN {
        $AlbumArtist = cleanTextForRefining ($Metadata.AlbumArtist.split('\W'))[0] -ReplaceNonAlphaNumeric
        $Album = cleanTextForRefining ($MetaData.Album.split('\W'))[0] -ReplaceNonAlphaNumeric
        $Name = cleanTextForRefining $MetaData.Name -ReplaceNonAlphaNumeric

        Write-Debug "refineSearchResults: Refining for $Album, $Name, track $($MetaData.TrackNumber)"
    }

    PROCESS {
        $Target | Where-Object { 1 -eq 1 `
            -and (cleanTextForRefining $_.AlbumArtist) -match $AlbumArtist `
            -and (cleanTextForRefining $_.Album) -match $Album `
            -and (cleanTextForRefining $_.Name) -match $Name `
            -and $_.TrackNumber -eq $MetaData.TrackNumber}
    }
    
    END {}
}

function moveFileToiTunes {
    [CmdletBinding(SupportsShouldProcess,DefaultParameterSetName="Update")]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        $File,

        [Parameter(Mandatory,ParameterSetName="Update")]
        [ValidateNotNullOrEmpty()]
        [ref]$Target,
        
        [Parameter(ParameterSetName="Add")]
        [switch]
        $AddNew,

        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $iTunesMediaPath = $script:iTunesMediaPath,

        [Parameter()]
        [string]
        $Reason = "Updated"
    )

    if($AddNew){
        $TargetPath = Join-Path $iTunesMediaPath "Automatically Add to iTunes"
    } else {
        Write-Debug ("moveFileToiTunes: Updating iTunes track: {0} - {1} - {2} track {3}." -f `
            $Target.Value.Artist, $Target.Value.Album, $Target.Value.Name, $Target.Value.TrackNumber)

        $TargetPath = getTargetPath -MetaData $File -iTunesMediaPath $iTunesMediaPath
    }

    $Status = $Reason
    
    if($PSCmdlet.ShouldProcess($File.Location,"Move-Item")){
        Write-Debug "moveFileToiTunes: Copying source file to: $TargetPath"

        try {
            Copy-Item -LiteralPath $File.Location -Destination $TargetPath -Force -ErrorAction Stop
        } catch {
            Write-Error $_.ToString()
            return "Failed to copy file"
        }
    }
    
    if($AddNew){
        # We don't need to update an existing track
    } elseif($PSCmdlet.ShouldProcess($TargetPath,"Update iTunes Location")){

        if(-not (Test-Path -LiteralPath $TargetPath)){
            Write-Error "$TargetPath missing"
            return "Failed to copy file"
        }
        
        try {
            $Target.Value.Location = $TargetPath
        } catch {
            Write-Error $_.ToString()
            Write-Warning "moveFileToiTunes: Removing $TargetPath"
            Remove-Item -LiteralPath $TargetPath -Force
            return "Failed to update iTunes"
        } 
    }

    if($PSCmdlet.ShouldProcess($File.Location,"Remove-Item")){
        Write-Debug "moveFileToiTunes: Removing source file: $($File.Location)"

        try {
            Remove-Item -LiteralPath $File.Location -Force -ErrorAction Stop
        } catch {
            Write-Warning "moveFileToiTunes: Failed to remove source file"
        }
    }

    return $Status    
}

function removeEmptyFolders {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(ValueFromPipeline)]
        [string]
        $Path = (Get-Location).Path
    )

    $WhatIfRemoved = New-Object -TypeName System.Collections.ArrayList

    do {
        $Removed = $false
        $Folders = Get-ChildItem -LiteralPath $Path -Directory -Recurse
        $Folders = $Folders.where{$_.Fullname -notin $WhatIfRemoved}

        foreach($Folder in $Folders) {
            if(($Folder.GetFiles().Count -eq 0) -and ($Folder.GetDirectories().Count -eq 0)) {
                if($PSCmdlet.ShouldProcess($Folder.Fullname,"Remove-Item")){
                    Remove-Item -LiteralPath $Folder.Fullname -ErrorAction Stop
                    $Removed = $true
                } else {
                    $WhatIfRemoved.Add($Folder.Fullname) | Out-Null
                }
            }
        }
    } while ($Removed)
}

#endregion
###############################################################################

###############################################################################
# Extract metadata from files to merge into iTunes

$iTunesMusicPath = Join-Path $iTunesMediaPath "Music"

if($UseiTunesMedia){
    $Files = getFilesWithHyphens $iTunesMusicPath
    $MusicFileInfos = $Files | Get-FileMetadata -RootPath $iTunesMusicPath
} else {
    $Folders = getWindowsMediaFolders -Path (Resolve-Path -LiteralPath $SourcePath)
    if($FolderLimit -gt 0){
        $Folders = $Folders | Select-Object -First $FolderLimit
    }
    $MusicFileInfos = $Folders | Get-FileMetadata -RootPath $SourcePath -Method TagLib
}

$FileData = New-Object -TypeName System.Collections.ArrayList

foreach($MusicFileInfo in $MusicFileInfos){
    try {
        if($MusicFileInfo -and $MusicFileInfo.Exists()){
            [void]$FileData.Add($MusicFileInfo)
        }
    } catch {
        Write-Warning "$MusicFileInfo doesn't exist??"
        Write-Debug ($MusicFileInfo | Format-List | Out-String)
        throw
        exit 1
    }
}

Write-Information "Checking $($FileData.Count) files for duplicates"

$UniqueCheck = $FileData | Group-Object Album, Name

if(($UniqueCheck | Measure-Object -Property Count -Maximum).Maximum -gt 1){
    Write-Warning "Some combinations of Album & Track name are not unique:"
    Write-Warning ($UniqueCheck | Where-Object{$_.Count -gt 1} | Format-Table Count, Name | Out-String)
    $FileData = @($FileData | Where-Object {$_.Album -notin $UniqueCheck.Name.split(",")[0]})
}

Write-Information "Processing $($FileData.Count) files"

###############################################################################
# Find matching track in iTunes, move the source file and update the file location

$Output = New-Object -TypeName System.Collections.ArrayList
$Progress = 0

foreach($File in $FileData){
    $Progress++
    $Target = $null
    $Properties = @("Name", "Album", "AlbumArtist")

    if($File | hasEmptyProperties -Property $Properties){
        continue
    }

    Write-Progress -Activity "Processing source files" -CurrentOperation $File.Location `
        -PercentComplete ([math]::floor(($Progress/$FileData.Count)*100))

    $obj = $File | Select-Object -Property Location,Status

    do {
        $Search = generateSearchString -MetaData $File -Properties $Properties
        $SearchResults = Search-iTunesLibrary -Search $Search
        if($SearchResults){
            $Target = @(refineSearchResults -MetaData $File -Target $SearchResults)
        } else {
            $Target = @()
        }
        $Properties[-1]=$null
        $Properties = $Properties -ne $null #Ignore PSScriptAnalyzer; this filters out nulls
    } while ($Properties -and $Target.Count -ne 1)

    if($Target.Count -gt 0){
        if([string]::IsNullOrWhiteSpace($Target.Location) -or $Force){
            $obj.Status = moveFileToiTunes -File $File -Target ([ref]$Target[0])
        } elseif($Target.Grouping -match 're-?rip') {
            Write-Debug "Target track flagged for re-rip"
            $obj.Status = moveFileToiTunes -File $File -Target ([ref]$Target[0]) -Reason "Re-rip"
        } elseif($File.BitRate -gt $Target.BitRate) {
            Write-Debug "Source file has higher quality"
            $obj.Status = moveFileToiTunes -File $File -Target ([ref]$Target[0]) -Reason "Update quality"
        } else {
            Write-Verbose "File already present: $($Target.Location)"
            $obj.Status = "Duplicate"
        }    
    } elseif($AddMissing){
        Write-Verbose ("Adding new file to iTunes: {0} - {1} - {2}" -f $File.Album, $File.Artist, $File.Name)
        $obj.Status = moveFileToiTunes -File $File -Add -Reason "Add new file"
    } else {
        Write-Warning ("Failed to match in iTunes: $Search")
        $obj.Status = "Missing in iTunes"
    }

    [void]$Output.Add($obj)
}

Write-Progress -Activity "Processing source files" -Completed

if($MoveDuplicates){
    $Output.where{$_.Status -eq "Duplicate"} |
        Foreach-Object {
            $params = @{
                LiteralPath = $_.Location
                Destination = ($_.Location -replace [regex]::Escape($SourcePath),$DuplicatePath)
            }

            $DestinationFolder = Split-Path $params.Destination -Parent
            New-Item -Path $DestinationFolder -ItemType Directory -Force | Out-Null

            try {
                Move-Item @params -ErrorAction Stop
            } catch {
                Write-Warning "Failed to move duplicate: $($params.LiteralPath)"
            }
        }
}

removeEmptyFolders -Path $SourcePath

Write-Output $Output