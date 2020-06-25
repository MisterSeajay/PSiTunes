function Get-FileMetadata {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([MusicFile])]
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
        $Method = "FileAttributes",

        [switch]
        $Raw,

        [switch]
        $Recurse
    )

    BEGIN {
    }
    PROCESS {
        $FullName = (Resolve-Path -LiteralPath $Path).ToString()
        Write-Debug $Fullname

        switch($Method){
            "FileAttributes" {
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
            }
            
            "FilePath" {
                $FileMetadata = getDataFromFilePath -FullName $Path -RootPath $RootPath
                if($FileMetadata -and -not $Raw){
                    $FileMetadata = ($FileMetadata | convertFromFileAttributes)
                }
            }

            "TagLib" {
                $FileMetadata = if(Test-Path -LiteralPath $FullName -PathType Container){
                        Get-ChildItem $FullName | Foreach-Object {
                            if(Test-Path -LiteralPath $_.FullName -PathType Container){
                                Get-FileMetadata $_.FullName
                            } else {
                                getDataFromTagLib -Path $_.FullName
                            }
                        }
                    } else {
                        getDataFromTagLib -Path $FullName
                    }

                if($FileMetadata -and -not $Raw){
                    $FileMetadata = ($FileMetadata | convertFromTagLibProperties)
                }

                break
            }
        }
        
        Write-Output $FileMetadata
    }

    END {
    }
}