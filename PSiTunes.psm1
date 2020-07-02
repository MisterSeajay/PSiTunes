Set-StrictMode -Version 2

###################################################################################################
# Dot-source functions

$Classes = Join-Path $PSScriptRoot "Classes"
$PrivateFunctions = Join-Path $PSScriptRoot "Private"
$PublicFunctions = Join-Path $PSScriptRoot "Public"

foreach($Folder in @($Classes,$PrivateFunctions,$PublicFunctions)){
    $Functions = Get-ChildItem -Path $Folder *.ps1

    foreach($Function in $Functions){
        . $Function.FullName
    }
}

###################################################################################################
# Set paths for iTunes music and the new "shared music" location
$GLOBAL:iTunesRoot = "D:\iTunes\iTunes Media\Music\"

###################################################################################################
# Start iTunes Application
Start-iTunes

###################################################################################################
# Load the iTunes Library object
$GLOBAL:iTunesLibrary = Get-iTunesLibrary
$GLOBAL:iTunesMediaPath = "D:\iTunes\iTunes Media"
# $GLOBAL:iTunesMediaPath = Get-iTunesMediaLocation