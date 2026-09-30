function Start-iTunes {
    <#
    .SYNOPSIS
        Connects to the running iTunes application, or starts one.
    .DESCRIPTION
        Returns an automation object for iTunes, connecting to the instance that is
        already running if there is one and starting iTunes if there is not. The
        module calls this when it is imported, so usually you do not need to.
    .EXAMPLE
        Start-iTunes
    .NOTES
        Warns if iTunes is running but the automation object cannot be created, which usually means another application has registered the iTunes ProgID.
        Returns $null if the application could not be created.
    #>
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