$cwd = Split-Path $MyInvocation.InvocationName -Parent
$PSiTunes = Resolve-Path -Path (Join-Path $cwd "../PSiTunes.psd1")
Import-Module $PSiTunes -Force -Verbose:$false

$itunesLibrary.Tracks |
    Group-Object -Property Artist, Name |
    Where-Object {$_.Count -gt 1} |
    Sort-Object -Property Name |
    Select-Object -First 20 -Property Name, Count
