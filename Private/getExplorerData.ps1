function getExplorerData {
    param(
      [Parameter(ValueFromPipeline=$True)]
      [ValidateScript({Test-Path -LiteralPath $_})]
      [string]$Path = (Get-Location),

      [Parameter()]
      [string]$Filename = '*'
    )

    BEGIN {
        $Shell = New-Object -ComObject Shell.Application
    }

    PROCESS {
        $Path = (Resolve-Path -LiteralPath $Path).ToString()

        if(-not (Test-Path $Path -PathType Container)){
            $Filename = Split-Path $Path -Leaf
            $Path = Split-Path $Path -Parent
        }
        
        $Folder = $Shell.Namespace($Path)
      
        $Items = $Folder.Items() | Where-Object {(Split-Path $_.Path -Leaf) -like $Filename}

        foreach ($Item in $Items) {
          
            if(Test-Path -LiteralPath $Item.Path -PathType Container){
                Get-FileMetadata -Path $Item.Path
            } else {
                $Count=0
                $Object = New-Object PSObject
                $Object | Add-Member NoteProperty FullName $Item.Path

                while($Folder.getDetailsOf($Folder.Items, $Count) -ne "") {
                    $Object | Add-Member -Force NoteProperty ($Folder.getDetailsOf($Folder.Items, $Count)) ($Folder.getDetailsOf($Item, $Count))
                    $Count++
                }

                Write-Output $Object
            }
        }
      }

      END {
      }
}