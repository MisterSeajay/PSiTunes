function cleanCharacterSet {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(ValueFromPipeline)]
        [string]
        $InputObject
    )

    $InputBytes = [System.Text.Encoding]::GetEncoding("ISO-8859-8").GetBytes($InputObject)
    return [System.Text.Encoding]::UTF8.GetString($InputBytes)
}