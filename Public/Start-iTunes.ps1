function Start-iTunes {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    if($PSCmdlet.ShouldProcess("iTunes.Application","New-Object")){
        try {
            $GLOBAL:iTunesApplication = New-Object -ComObject iTunes.Application
        }
        catch {
            if(Get-Process | ?{$_.Name -eq "iTunes"}) {
                Write-Warning "Unable to connect to running iTunes application"
            }

            $GLOBAL:iTunesApplication = $null
        }
    }
}