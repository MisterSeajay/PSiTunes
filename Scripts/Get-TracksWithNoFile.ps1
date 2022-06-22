param(
    $BasePath = "D:\iTunes\iTunes Media\Music\",
    $Limit = $null
)

$cwd = Split-Path $MyInvocation.InvocationName -Parent
$PSiTunes = Resolve-Path -Path (Join-Path $cwd "../PSiTunes.psd1")
Import-Module $PSiTunes -Force -Verbose:$false

$MissingLocation = $itunesLibrary.Tracks |
    Where-Object {[string]::IsNullOrEmpty($_.Location) `
        -and -not [string]::IsNullOrEmpty($_.AlbumArtist) `
        -and $_.Genre -notin ("Classical", "Comedy", "Guitar", "Karaoke")}

if($Limit){
    $MissingLocation = $MissingLocation | Select-Object -First $Limit
}

foreach($Track in $MissingLocation) {
    $ExpectedLocation = $BasePath

    if($Track.AlbumArtist -eq "VariousArtists"){
        $ExpectedLocation += "Compilations\$($Track.Album)\$($Track.DiscNumber)-$($Track.TrackNumber) - $($Track.Artist) - $($Track.Name)"
    } else {
        $ExpectedLocation += "$($Track.AlbumArtist)\$($Track.Album)\$($Track.DiscNumber)-$($Track.TrackNumber) - $($Track.Name)"
    }

    Write-Debug $ExpectedLocation
    Test-Path -LiteralPath $ExpectedLocation
}
