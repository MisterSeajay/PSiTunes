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