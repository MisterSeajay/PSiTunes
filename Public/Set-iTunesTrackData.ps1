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
            Write-Verbose "Updating $Attribute on $(formatiTunesTrackInfo -Track $Track)"

            if($PSCmdlet.ShouldProcess($Attribute,"Set attribute")){
                Write-Debug "Set $Attribute to $Value [$($Value.GetType().FullName)]"
                $Track.$Attribute = $Value
            }
        }
    }

    END {
    }
}