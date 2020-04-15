function Get-FileMetadata {
    param(
        [Parameter(ValueFromPipeline=$True)]
        [ValidateNotNullOrEmpty()]
        [string]$Path = (Get-Location),

        [Parameter()]
        [ValidateSet("Explorer", "TagLib")]
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
        $Fullname = (Resolve-Path -LiteralPath $Path).ToString()

        switch($Method){
            "TagLib" {
                $FileMetaData = if(Test-Path -LiteralPath $Fullname -PathType Container){
                    Get-ChildItem $Fullname | Foreach-Object {
                        if(Test-Path -LiteralPath $_.Fullname -PathType Container){
                            Get-FileMetaData $_.Fullname
                        } else {
                            getTagLibData -Path $_.Fullname
                        }
                    }
                } else {
                    getTagLibData -Path $Fullname
                }

                if($Raw){
                    Write-Output $FileMetaData
                } else {
                    Write-Output ($FileMetaData | convertFromTagLibProperties)
                }
            }

            default {
                if(Test-Path -LiteralPath $Fullname -PathType Leaf) {
                    $Filename = Split-Path $Fullname -Leaf
                    $Fullname = Split-Path $Fullname -Parent
                } elseif($Recurse) {
                    $Filename = "*"
                } else {
                    $Filename = "*.mp3"
                }
        
                $FileMetaData = (getExplorerData -Path $Fullname -Filename $Filename)                      

                if($Raw){
                    Write-Output $FileMetaData
                } else {
                    Write-Output ($FileMetaData | convertFromExplorerProperties)
                }
            }
        }
        
    }

    END {
    }
}