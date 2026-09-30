function Get-FileMetadata {
    <#
    .SYNOPSIS
        Reads metadata from audio files on disk.
    .DESCRIPTION
        Reads metadata for one or more audio files, by one of three methods:
        reading the file tags with TagLib, reading extended file attributes, or
        deriving values from the file path. Accepts a file or a directory; when
        given a directory only its immediate children are read unless Recurse is
        used.
    .PARAMETER Path
        The file or directory to read. Accepts pipeline input. Defaults to the current location.
    .PARAMETER RootPath
        The root to strip from the path when building metadata. Used by the FilePath method.
    .PARAMETER Method
        How to read the metadata: TagLib to read the file tags, FileAttributes to read the extended file attributes, or FilePath to derive values from the file path. Defaults to TagLib.
    .PARAMETER Raw
        Return the raw values as read, without converting them into MusicFileInfo objects.
    .PARAMETER Recurse
        Descend into subdirectories. Without this, a directory yields only its immediate files.
    .EXAMPLE
        Get-FileMetadata -Path "D:\Music\Ripped\track.mp3"
    .EXAMPLE
        Get-ChildItem -Path "D:\Music\Ripped" -Filter *.mp3 -Recurse | Get-FileMetadata -Method FileAttributes
    .NOTES
        The TagLib method only reads .mp3, .m4a and .m4p files; anything else yields nothing.
        This command reads files only. It does not write tags; use Set-mp3TrackData for that.
    #>
    [CmdletBinding(SupportsShouldProcess=$false)]
    [OutputType([MusicFileInfo[]])]
    param(
        [Parameter(Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = (Get-Location),

        [Parameter(Position=1)]
        [string]
        $RootPath,

        [Parameter()]
        [ValidateSet("FilePath", "FileAttributes", "TagLib")]
        [string]
        $Method = "TagLib",

        [switch]
        $Raw,

        [switch]
        $Recurse
    )

    BEGIN {
        $FileMetadata = $null
    }

    PROCESS {
        switch($Method){
            "FileAttributes" {
                $FullName = (Resolve-Path -LiteralPath $Path).ToString()

                $params = @{}

                if(Test-Path -LiteralPath $FullName -PathType Leaf) {
                    $params.Path = Split-Path $FullName -Parent
                    $params.Glob = Split-Path $FullName -Leaf
                } elseif($Recurse) {
                    $params.Path = $Fullname
                    $params.Glob = "*"
                } else {
                    $params.Path = $Fullname
                }

                $FileMetadata = getDataFromFileAttributes @params

                if($FileMetadata -and -not $Raw){
                    $FileMetadata = ($FileMetadata -ne $null) | convertFromFileAttributes
                }

                break
            }

            "FilePath" {
                $FileMetadata = getDataFromFilePath -FullName $Path -RootPath $RootPath
                if($FileMetadata -and -not $Raw){
                    $FileMetadata = ($FileMetadata -ne $null) | convertFromFileAttributes
                }

                break
            }

            "TagLib" {
                $FullName = Get-Item -LiteralPath $Path

                $FileMetadata = `
                    if(Test-Path -LiteralPath $FullName -PathType Container){
                        # Write-Verbose "Get-FileMetadata: Entering $Fullname"
                        if($Recurse) {
                            $ChildItems = Get-ChildItem -LiteralPath $FullName
                        } else {
                            $ChildItems = Get-ChildItem -LiteralPath $FullName -File
                        }

                        foreach($Child in $ChildItems) {
                            Get-FileMetadata -Path $Child.FullName -Method TagLib -Raw
                        }
                        # Write-Debug "Get-FileMetadata: Completing $Fullname"

                    } elseif($FullName.Extension -in @(".mp3", ".m4a", ".m4p")) {
                        getDataFromTagLib -Path $Fullname
                    } else {
                        $null
                    }

                if($FileMetadata -and -not $Raw){
                    $FileMetadata = @($FileMetadata) -ne $null | convertFromTagLibProperties
                }

                break
            }
        }

        Write-Output $FileMetadata
    }

    END {
    }
}