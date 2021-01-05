function Get-FileMetadata {
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