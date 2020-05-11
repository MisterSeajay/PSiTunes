function Get-FileMetadata {
    param(
        [Parameter(Position=0, ValueFromPipeline=$True)]
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
        # Write-Debug $Path

        $FullName = (Resolve-Path -LiteralPath $Path).ToString()

        switch($Method){
            "FileAttributes" {
                if(Test-Path -LiteralPath $FullName -PathType Leaf) {
                    $Filename = Split-Path $FullName -Leaf
                    $FullName = Split-Path $FullName -Parent
                } elseif($Recurse) {
                    $Filename = "*"
                } else {
                    $Filename = "*.mp3"
                }
        
                $FileMetadata = getDataFromFileAttributes -Path $FullName -Name $Filename

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