Set-StrictMode -Version 2

###################################################################################################
# Dot-source functions
# Order is load-bearing: the classes are referenced by Private/ and Public/, and the
# Private/ helpers are referenced by the Public/ functions. Keep Classes/ first.

$Classes = Join-Path $PSScriptRoot "Classes"
$PrivateFunctions = Join-Path $PSScriptRoot "Private"
$PublicFunctions = Join-Path $PSScriptRoot "Public"

foreach($Folder in @($Classes,$PrivateFunctions,$PublicFunctions)){
    $Functions = Get-ChildItem -Path $Folder *.ps1 -File

    foreach($Function in $Functions){
        . $Function.FullName
    }
}

###################################################################################################
# Start iTunes Application
# NOTE: importing this module starts iTunes. Several commands below assume
# $iTunesApplication is in scope, so this is not currently avoidable without
# passing the application object in as a parameter to each of them.

$GLOBAL:iTunesApplication = Start-iTunes

###################################################################################################
# Load the iTunes Library object

$GLOBAL:iTunesLibrary = Get-iTunesLibrary

###################################################################################################
# Set the media paths, asking iTunes where its music is rather than assuming a
# drive letter. Get-iTunesMediaLocation reads the "Music Folder" key out of the
# library XML and converts the file:// URI to a local path.
#
# The fallback is the path this module was written against. It is a fallback and
# not a default: on a machine where the lookup works it is never used, and on a
# machine where the lookup fails the warning below says so.

$FallbackMediaPath = "D:\iTunes\iTunes Media"

$MediaPath = $null
try {
    $MediaPath = Get-iTunesMediaLocation -ErrorAction Stop
}
catch {
    Write-Warning "Could not determine the iTunes media location: $($_.Exception.Message)"
}

if([string]::IsNullOrWhiteSpace($MediaPath)){
    if(-not $FallbackMediaPath){
        Write-Error "The iTunes media location could not be determined and there is no fallback path configured."
    }
    else {
        Write-Warning "Falling back to the built-in media path '$FallbackMediaPath'. Set it in PSiTunes.psm1 if this machine stores its media elsewhere."
        $MediaPath = $FallbackMediaPath
    }
}

# iTunesRoot is the Music folder, iTunesMediaPath the location the library is
# rooted at. iTunesRoot was historically a trailing-slash path; keep the
# separator so callers that concatenate onto it are unaffected.
$GLOBAL:iTunesMediaPath = $MediaPath
$GLOBAL:iTunesRoot = [System.IO.Path]::Combine($MediaPath, "Music")
