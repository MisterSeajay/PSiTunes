param(
    # No default: the value has to come from the module, which is not imported
    # until after parameters are bound. It is resolved below, after the import.
    $BasePath = $null,
    $Limit = $null
)

$cwd = Split-Path $MyInvocation.InvocationName -Parent
$PSiTunes = Resolve-Path -Path (Join-Path $cwd "../PSiTunes.psd1")
Import-Module $PSiTunes -Force -Verbose:$false

# The module sets $iTunesRoot from the iTunes music folder, falling back to the
# path it was written against if the lookup fails. Use that rather than repeating
# a drive letter here. Read it from the global scope explicitly, since the
# parameter below shadows the name.
$ModuleMusicPath = $global:iTunesRoot

if(-not $BasePath){
    if($ModuleMusicPath){
        $BasePath = $ModuleMusicPath
    }
    else {
        Write-Error "Could not determine the iTunes music path. Pass -BasePath explicitly."
        return
    }
}

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
