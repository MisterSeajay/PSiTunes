function Get-iTunesXmlLibrary {
    <#
    .SYNOPSIS
        Reads and parses the iTunes library XML.
    .DESCRIPTION
        Reads the iTunes library XML file and converts it into PowerShell objects,
        flattening the nested plist structure that the XML uses into dictionaries
        keyed by name.
    .PARAMETER Path
        The library XML to read. Defaults to the LibraryXMLPath of the running iTunes application.
    .EXAMPLE
        Get-iTunesXmlLibrary
    .NOTES
        Reading and parsing the XML does not update it. Export the library from iTunes first if it has not been done recently.
        This command reads a file, so it supports -WhatIf and -Confirm. Under -WhatIf it returns nothing.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([xml])]
    param(
        [Parameter()]
        [string]
        $Path = $iTunesApplication.LibraryXMLPath
    )

    if($PSCmdlet.ShouldProcess($Path,"Get-Content")){
        [xml]$iTunesLibraryXml = Get-Content -Raw -LiteralPath $Path
    } else {
        $iTunesLibraryXml = $null
    }

    $ItunesLibraryXML.plist | Foreach-Object {
        if($_.PSObject.Properties.Name -contains "dict"){
            Write-Output (New-Object PSObject (parsePlistDict $_.dict))
        }
    }
}