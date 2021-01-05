function Set-iTunesTrackData {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(
            ValueFromPipeline=$true)]
        [System.Object[]]
        $Tracks,
        
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
        foreach($Track in $Tracks){
            if($PSCmdlet.ShouldProcess((formatiTunesTrackInfo -Track $Track),"Set $Attribute")){
                Write-Debug "Set-iTunesTrackData: Set $Attribute to $Value [$($Value.GetType().FullName)]"
                $Track.$Attribute = $Value
            } else {
                Write-Debug "Set-iTunesTrackData: Set $Attribute to $Value [$($Value.GetType().FullName)]"
            }
        }
    }

    END {
    }
}