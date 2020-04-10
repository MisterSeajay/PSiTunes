Set-StrictMode -Version 2

function Get-FileMetadata {
  param(
    [Parameter(ValueFromPipeline=$True)]
    [ValidateScript({Test-Path -LiteralPath $_})]
    [string]$Path = (Get-Location),

    [string]$Include = '*'
  )
  
  $Path = (Get-Item -LiteralPath $Path).FullName
  Write-Verbose "Processing $Path"

  $Shell = New-Object -ComObject Shell.Application
  $Folder = $Shell.Namespace($Path)
  
  Write-Debug "$($Folder.Items().Count) items in $Path"

  $Items = $Folder.Items() | Where-Object {$_.Path -like $Include}

  foreach ($Item in $Items) {
    if(Test-Path -PathType Container $Item.Path){
      Get-FileMetadata -Path $Item.Path
    } else {
        $Count=0
        $Object = New-Object PSObject
        $Object | Add-Member NoteProperty FullName $Item.Path
        #Get all the file detail items of the current file and add them to an object.
        while($Folder.getDetailsOf($Folder.Items, $Count) -ne "") {
            $Object | Add-Member -Force NoteProperty ($Folder.getDetailsOf($Folder.Items, $Count)) ($Folder.getDetailsOf($Item, $Count))
            $Count+=1
        }

        Write-Output $Object
    }
  }
}

function Get-MusicTags {
  param(
    [Parameter(ValueFromPipeline)]
    $InputObject
  )
  
  BEGIN {
  }

  PROCESS {
    $InputObject | Where-Object {$_.Kind -eq "Music"} |
      Foreach-Object {
        if($_.Album -match "Disc\s*(\d+)"){
          $Disc = $Matches[1]
        } else {
          $Disc = 1
        }

        [PSCustomObject]@{
          "Album Artist" = $_.Authors
          "Album Title" = $_.Album
          "Track Title" = $_.Title
          "Track Artist" = $_."Contributing Artists"
          Year = $_.Year
          Genre = $_.Genre
          Conductor = $_.Conductors
          Rating = $_.Rating
          Comments = $_.Comments
          Track = $_."#"
          Disc = $Disc
          Length = $_.Length
          Bitrate = $_."Bit rate"
          FileName = $_.Name
          FilePath = $_.Fullname
          FileSize = $_.Size
        }
      }
  }
  END {
  }
}