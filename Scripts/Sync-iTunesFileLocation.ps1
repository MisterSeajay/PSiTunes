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
    $AddMissing,

    [Parameter()]
    [switch]
    $Force,

    [Parameter()]
    [switch]
    $UseiTunesMedia,

    [Parameter()]
    [int]
    $FolderLimit = 1
)

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
        $SearchString += $Metadata.$Property + " "
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

function refineSearchResults {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory)]
        $MetaData,

        [Parameter(Position=1, ValueFromPipeline)]
        $Target
    )

    BEGIN {
        $Album = $MetaData.Album -replace "[(\[][^)\]]+[)\]]",""
        $Album = $Album -replace '[\W-[ ]]','.?'
        $Name = $MetaData.Name -replace "[(\[][^)\]]+[)\]]",""
        $Name = $Name -replace '[\W-[ ]]','.?'

        Write-Debug "refineSearchResults: Refining for $Album, $Name, track $($MetaData.TrackNumber)"
    }

    PROCESS {
        $Target | Where-Object {$_.Album -match $Album.trim() `
            -and $_.Name -match $Name.trim() `
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
        $iTunesMediaPath = $script:iTunesMediaPath
    )

    Write-Debug ("moveFileToiTunes: Updating iTunes track: {0} - {1} - {2} track {3}." -f `
        $Target.Value.Artist, $Target.Value.Album, $Target.Value.Name, $Target.Value.TrackNumber)

    if($AddNew){
        $TargetPath = Join-Path $iTunesMediaPath "Automatically Add to iTunes"
    } else {
        $TargetPath = getTargetPath -MetaData $File -iTunesMediaPath $iTunesMediaPath
        $Status = "Updated"
    }

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
        $Status = "Added to iTunes"
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

Write-Information "Processing $($FileData.Count) files"

###############################################################################
# Find matching track in iTunes, move the source file and update the file location

$Output = New-Object -TypeName System.Collections.ArrayList
$Progress = 0

foreach($File in $FileData){
    $Progress++
    $Target = $null
    $Properties = @("Name", "Album")

    if($File | hasEmptyProperties -Property $Properties){
        continue
    }

    Write-Verbose "Processing source file: $($File.Location)"
    
    Write-Progress -Activity "Processing source files" -CurrentOperation $File.Location `
        -PercentComplete ([math]::floor(($Progress/$FileData.Count)*100))

    $obj = $File | Select-Object -Property Location,Status

    do {
        $Search = generateSearchString -MetaData $File -Properties $Properties
        $Target = @(Search-iTunesLibrary -Search $Search | refineSearchResults -MetaData $File)
        Write-Debug "$($Target.Count) results after refining"
        $Properties[-1]=$null
        $Properties = $Properties -ne $null
    } while ($Properties -and $Target.Count -ne 1)

    if($Target.Count -gt 0){
        if([string]::IsNullOrWhiteSpace($Target.Location) -or $Force){
            $obj.Status = moveFileToiTunes -File $File -Target ([ref]$Target[0])
        } else {
            Write-Verbose "File already present: $($Target.Location)"
            $obj.Status = "Skipped"
            # Move or delete this duplicate file?
            # Check the target iTunes track for "re-rip" label?
        }    
    } elseif($AddMissing){
        Write-Verbose ("Adding new file to iTunes: {0} - {1} - {2}" -f $File.Album, $File.Artist, $File.Name)
        $obj.Status = moveFileToiTunes -File $File -Add
    } else {
        Write-Warning ("Failed to match in iTunes: $Search")
        $obj.Status = "Missing in iTunes"
    }

    [void]$Output.Add($obj)
}

Write-Progress -Activity "Processing source files" -Completed

Write-Output $Output