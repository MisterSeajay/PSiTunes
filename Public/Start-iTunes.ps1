function Start-iTunes {
    [CmdletBinding(SupportsShouldProcess)]
    param()
    
    $iTunesApplication = $null

    if($PSCmdlet.ShouldProcess("iTunes.Application","New-Object")){
        try {
            $iTunesApplication = New-Object -ComObject iTunes.Application
        }
        catch {
            if(Get-Process | ?{$_.Name -eq "iTunes"}) {
                Write-Warning "Unable to connect to running iTunes application"
            }
        }
    }

    return $iTunesApplication
}