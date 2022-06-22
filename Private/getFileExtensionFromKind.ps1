function getFileExtenstionFromKind{
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]$KindAsString
    )

    switch($KindAsString){
        "AAC audio file" {
            return ".m4a"
        }

        "MPEG audio file" {
            return ".mp3"
        }

        "Purchased AAC audio file" {
            return ".m4a"
        }

        "Protected AAC audio file" {
            return ".m4p"
        }

        "Purchased MPEG-4 video file" {
            return ".m4v"
        }

        default {
            Write-Warning "Unknown KindAsString: $KindAsString; guessing .mp3 file type!"
            return ".mp3"
        }
    }
}