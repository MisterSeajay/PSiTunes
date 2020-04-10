<#
EXAMPLE USE OF TAGLIB
=====================

Load up the MP3 file. Again, I used a relative path, but an absolute path works too
$media = [TagLib.File]::Create((resolve-path ".\Netcast 185 - Growing Old with Todd.mp3"))

# set the tags
$media.Tag.Album = "Todd Klindt's SharePoint Netcast"
$media.Tag.Year = "2014"
$media.Tag.Title = "Netcast 185 - Growing Old with Todd"
$media.Tag.Track = "185"
$media.Tag.AlbumArtists = "Todd Klindt"
$media.Tag.Comment = "http://www.toddklindt.com/blog"

# Load up the picture and set it
$pic = [taglib.picture]::createfrompath("c:\Dropbox\Netcasts\Todd Netcast 1 - 480.jpg")
$media.Tag.Pictures = $pic

# Save the file back
$media.Save() 
#>

function Set-mp3TrackData {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true)]
        [string]
        $Path,
        
        [Parameter()]
        [System.String]
        $Attribute,

        [Parameter()]
        [ValidateScript({$_.GetType() -in ([Int],[String],[DateTime])})]
        $Value
    )

    Write-Verbose "Updating $Attribute on $Path"

    if($PSCmdlet.ShouldProcess($Attribute,"Set attribute")){
        Write-Debug "Set $Attribute to $Value [$($Value.GetType().FullName)]"
        $TagLibFile = [TagLib.File]::Create((Resolve-Path $Path))
        $TagLibFile.Tag.$Attribute = $Value
        $TagLibFile.Save()
    }
}