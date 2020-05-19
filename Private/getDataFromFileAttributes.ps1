function getDataFromFileAttributes {
    param(
        [Parameter(ValueFromPipeline=$True)]
        [ValidateScript({Test-Path -LiteralPath $_})]
        [string]$Path = (Get-Location),

        [Parameter()]
        [Alias("Filename","Name")]
        [string]$Glob = '*.mp3',

        [Parameter()]
        [switch]$Recurse,

        [Parameter()]
        [int]$Depth = 1
    )

    BEGIN {
        $Shell = New-Object -ComObject Shell.Application
    }

    PROCESS {
        $Path = (Resolve-Path -LiteralPath $Path).ToString()

        if(-not (Test-Path -LiteralPath $Path -PathType Container)){
            $Glob = Split-Path $Path -Leaf
            $Path = Split-Path $Path -Parent
        }

        # Write-Debug "getDataFromFileAttributes: `$Path = ""$Path"""
        # Write-Debug "getDataFromFileAttributes: `$Glob = ""$Glob"""
        
        $Folder = $Shell.Namespace($Path)
      
        $Items = $Folder.Items()
        $ItemTotal = $Folder.Items().Count
        $ItemCount = 0

        foreach ($Item in $Items) {
            $ItemCount++
            Write-Progress -Id $Depth -ParentId ($Depth - 1) -Activity "getDataFromFileAttributes" `
                -CurrentOperation $Item.Name -PercentComplete ([math]::Floor(100 * ($ItemCount/$ItemTotal))) 

            if($Item.Name -like $Glob -and -not $Item.IsFolder){
                # Write-Debug "getDataFromFileAttributes: Reading $($Item.Name)"
                $Count=0
                $Object = New-Object PSObject
                $Object | Add-Member NoteProperty FullName $Item.Path

                while($Folder.getDetailsOf($Folder.Items, $Count) -ne "") {
                    $Object | Add-Member -Force NoteProperty ($Folder.getDetailsOf($Folder.Items, $Count)) ($Folder.getDetailsOf($Item, $Count))
                    $Count++
                }

                Write-Output $Object
            } elseif($Recurse -and $Item.IsFolder) {
                getDataFromFileAttributes -Path $Item.Path -Recurse -Depth ($Depth + 1)
            }
        }

        Write-Progress -Id $Depth -Activity "getDataFromFileAttributes" -Completed
    }

    END {
    }
}