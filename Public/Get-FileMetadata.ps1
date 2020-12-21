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
                if($PSBoundParameters.Keys -contains "RootPath"){
                    $FullName = Get-Item -LiteralPath $RootPath
                } else {
                    $FullName = Get-Item -LiteralPath $Path
                }

                $FileMetadata = `
                    if(Test-Path -LiteralPath $FullName -PathType Container){
                        Get-ChildItem -LiteralPath $FullName | Foreach-Object {
                            Get-FileMetadata -Path $_.FullName -Method TagLib -Raw
                        }
                    } elseif($FullName.Extension -in @(".mp3", ".m4a", ".m4p")) {
                        getDataFromTagLib -Path $Fullname
                    } else {
                        $null
                    }
                
                if(-not $Raw){
                    $FileMetadata = ($FileMetadata -ne $null) | convertFromTagLibProperties
                }

                break
            }
        }
        
        Write-Output $FileMetadata
    }

    END {
    }
}