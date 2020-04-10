#$xmlLibrary.plist.dict.dict.dict | Select-Object -First 1 | Foreach-Object {
#    $_.SelectNodes('key') | Foreach-Object {$ht=@{}} {$ht[$_.'#text'] = $_.NextSibling.'#text'} {New-Object psobject -Property $ht}
#}

function parsePlistDict{
    [CmdletBinding()]
    [OutputType([System.Collections.Hashtable])]
    param(
        [Parameter(ValueFromPipeline)]    
        [System.Xml.XmlElement]$dict
    )

    $ht = @{}
    $keys = $dict.SelectNodes('key')

    foreach($key in $keys) {
        if($key.NextSibling.LocalName -eq "dict"){
            $ht[$key.InnerText] = parsePlistDict $key.NextSibling
        } else {
            $ht[$key.InnerText] = $key.NextSibling.InnerText
        }
    }
    
    return $ht
}

function Get-iTunesLibraryXml {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([xml])]
    param(
        [Parameter()]
        $Path = "$env:USERPROFILE\Music\iTunes\iTunes Library.xml"
    )

    if($PSCmdlet.ShouldProcess($Path,"Get-Content")){
        [xml]$iTunesLibraryXml = Get-Content $Path -Raw
    } else {
        $iTunesLibraryXml = $null
    }

    if($iTunesLibraryXml){
        New-Object PSObject (parsePlistDict $iTunesLibraryXml.plist.dict)
    }
}
