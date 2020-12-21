function Get-FileMetadata {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([MusicFileInfo[]])]
    param(
        [Parameter(Position=0, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path = (Get-Location),

        [Parameter()]
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
    }
    
    PROCESS {
        switch($Method){
            "FileAttributes" {
                $FullName = (Resolve-Path -LiteralPath $Path).ToString()
                Write-Debug $Fullname
        
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
                    $FileMetadata = ($FileMetadata | convertFromFileAttributes)
                }

                break
            }
            
            "FilePath" {
                $FileMetadata = getDataFromFilePath -FullName $Path -RootPath $RootPath
                if($FileMetadata -and -not $Raw){
                    $FileMetadata = ($FileMetadata | convertFromFileAttributes)
                }

                break
            }

            "TagLib" {
                $FullName = if($RootPath){$RootPath} else {$Path}
                Write-Debug "Get-FileMetadata: Processing $FullName"
                
                $FileMetadata = if(Test-Path -LiteralPath $FullName -PathType Container){
                        Get-ChildItem -LiteralPath $FullName |
                            Where-Object {$_.PSIsContainer -or $_.Extension -in ("mp3")} |
                            Foreach-Object {
                                if(Test-Path -LiteralPath $_.FullName -PathType Container){
                                    Get-FileMetadata -Path $_.FullName -Method TagLib
                                } else {
                                    $FilePath = $_.FullName
                                    getDataFromTagLib -Path $FilePath
                                }
                        }
                    } else {
                        $FilePath = $FullName
                        getDataFromTagLib -Path $FilePath
                    }

                if($FileMetadata -and -not $Raw){
                    $FileMetadata = $FileMetadata -ne $null |
                        Foreach-Object {$_ | convertFromTagLibProperties}
                }

                break
            }
        }
        
        Write-Output $FileMetadata
    }

    END {
    }
}