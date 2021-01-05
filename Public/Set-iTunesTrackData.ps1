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
            Write-Verbose "Set-iTunesTrackData: Updating $(formatiTunesTrackInfo -Track $Track)"

            if($PSCmdlet.ShouldProcess($Attribute,"Set attribute")){
                Write-Debug "Set-iTunesTrackData: $Attribute to $Value [$($Value.GetType().FullName)]"
                $Track.$Attribute = $Value
            }
        }
    }

    END {
    }
}