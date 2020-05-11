function getDataFromFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, ValueFromPipeline=$true)]
        [string]
        $FullName,

        [Parameter(Position=1)]
        [string]
        $RootPath = (Get-Location)
    )
    
    BEGIN {}

    PROCESS {
        $ShortPath = stripPath $FullName $RootPath

        if($ShortPath -match '^([^\\]+)\\([^\\]+)\\([^\\]+)\.[^.]+$'){
            $MetaData = [ordered]@{
                RelativePath = Join-Path "." $ShortPath
                FullName = $FullName
                Artist = $null
                AlbumArtist = $Matches[1].trim()
                Compilation = $null
                Album = $Matches[2].trim()
                Title = $Matches[3].trim()
            }
        } else {
            Write-Warning "Unusual folder structure: $ShortPath"
            return $null
        }

        switch($MetaData){
            {$_.AlbumArtist -match 'Various'} {
                $MetaData.Compilation = $true
            }

            {$_.Title -match '^\d+\s*-?\s*\S+'} {
                $MetaData.TrackNumber = [int]($_.Title -replace '^(\d+).*','$1')
                $MetaData.Title = ($_.Title -replace '^\d+\s*-?\s*(.+)','$1').trim()
            }

            {$_.Album -match '\[Disc \d+\]'} {
                $MetaData.Disc = [int]($_.Album -replace '.+\[Disc (\d+)\]','$1')
                $MetaData.Album = ($_.Album -replace '\s+\[Disc \d+\]','').trim()
            }

            {$_.Album -match '^\[\d{4}\].+'} {
                $MetaData.Year = [int]($_.Album -replace '^\[(\d+)\].+','$1')
                $MetaData.Album = ($_.Album -replace '^\[(\d+)\]','').trim()
            }

            {$_.Compilation -and ($_.Title -match '.+\s+-\s+.+')} {
                $MetaData.Artist = $_.Title.split('-')[0].trim()
                $MetaData.Title = $_.Title.split('-')[-1].trim()
            }
        }

        if([string]::IsNullOrWhiteSpace($MetaData.Artist) -and -not $MetaData.Compilation){
            $MetaData.Artist = $MetaData.AlbumArtist
        }

        return [PSCustomObject]$MetaData
    }

    END {}
}