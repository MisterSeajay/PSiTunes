<#
EXAMPLE USE OF TAGLIB
=====================
https://www.toddklindt.com/blog/Lists/Posts/Post.aspx?ID=468

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
    <#
    .SYNOPSIS
        Sets a tag on an audio file on disk.
    .DESCRIPTION
        Writes one tag to an audio file using TagLib, then saves the file. This is
        the file-based counterpart to Set-iTunesTrackData: it changes the file on
        disk rather than the library entry, and iTunes will pick the change up on
        its next scan.
    .PARAMETER Path
        The file to write to. Accepts pipeline input.
    .PARAMETER Attribute
        The name of the tag to set, for example Album or Title.
    .PARAMETER Value
        The value to set. Must be an integer, a string or a DateTime.
    .EXAMPLE
        Set-mp3TrackData -Path "D:\Music\Ripped\track.mp3" -Attribute "Album" -Value "Chillout"
    .NOTES
        The value must be an Int, String or DateTime; anything else is rejected at parameter binding.
        This writes to the file directly and immediately, so it cannot be undone from PowerShell.
        iTunes holds its own copy of the tags. Rescan the library afterwards or the change may not appear in iTunes.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true)]
        [string]
        $Path,

        [Parameter()]
        [string]
        $Attribute,

        [Parameter()]
        [ValidateScript({$_.GetType() -in ([Int],[String],[DateTime])})]
        $Value
    )

    BEGIN {
    }

    PROCESS {
        Write-Verbose "Updating $Attribute on $Path"

        if($PSCmdlet.ShouldProcess($Attribute,"Set attribute")){
            Write-Debug "Set $Attribute to $Value [$($Value.GetType().FullName)]"
            $TagLibFile = [TagLib.File]::Create((Resolve-Path $Path))
            $TagLibFile.Tag.$Attribute = $Value
            $TagLibFile.Save()
        }
    }

    END {
    }
}