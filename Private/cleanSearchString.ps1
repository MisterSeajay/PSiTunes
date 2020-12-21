function cleanSearchString {
    [CmdletBinding(DefaultParameterSetName="IgnoreNonAlphaNumeric")]
    param(
        [Parameter(ValueFromPipeline, Position=0)]
        [string]
        $InputObject,

        [Parameter(ParameterSetName="IgnoreNonAlphaNumeric")]
        [switch]
        $IgnoreNonAlphaNumeric,

        [Parameter(ParameterSetName="ForRegexMatching")]
        [switch]
        $ForRegexMatching
    )

    BEGIN {
        $StuffInBrackets = '[(\[][^)\]]+[)\]]'
        $WordsWeDontWant = '(^\s*the\b|\bthe\s*$)'
        $StuffToTrimAway = '(^\s*\W?|\W?\s*$)'
        $NonAlphaNumeric = '[^A-Za-z0-9 ]'
    }

    PROCESS {
        $CleanString = $InputObject

        $CleanString = $CleanString -replace $StuffInBrackets, ''
        $CleanString = $CleanString -replace $WordsWeDontWant, ''
        $CleanString = $CleanString -replace $StuffToTrimAway, ''
        $CleanString = $CleanString.trim() -replace '\s+', ' '

        if($IgnoreNonAlphaNumeric){
            $CleanString = $CleanString -replace $NonAlphaNumeric, '.?'
            $CleanString = $CleanString -replace '(\.\?)+', '.+'
        }

        if($ForRegexMatching){
            $CleanString = [regex]::Escape($CleanString)
        }

        return $CleanString
    }

    END {}
}
