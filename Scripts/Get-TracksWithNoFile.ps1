$cwd = Split-Path $MyInvocation.InvocationName -Parent
$PSiTunes = Resolve-Path -Path (Join-Path $cwd "../PSiTunes.psd1")
Import-Module $PSiTunes -Force -Verbose:$false

$itunesLibrary.Tracks |
    Where-Object {[string]::IsNullOrEmpty($_.Location) `
        -and -not [string]::IsNullOrEmpty($_.AlbumArtist) `
        -and $_.Genre -notin ("Classical", "Comedy", "Guitar", "Karaoke")} |
    Group-Object -Property AlbumArtist, Album |
    Where-Object {$_.Count -gt 5} |
    Sort-Object -Property Name |
    Select-Object -First 20 -Property Name, Count
