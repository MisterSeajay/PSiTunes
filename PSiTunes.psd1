@{

# Script module or binary module file associated with this manifest.
RootModule = '.\PSiTunes.psm1'

# Version number of this module.
ModuleVersion = '1.0.0.0'

# ID used to uniquely identify this module
GUID = '36c788bd-bc39-414a-8e37-f7f881c1f9c6'

# Author of this module
Author = 'MisterSeajay'

# Company or vendor of this module
CompanyName = 'MisterSeajay'

# Copyright statement for this module
Copyright = 'MisterSeajay'

# Description of the functionality provided by this module
Description = 'iTunes Library management functions'

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '5.0'

# Name of the Windows PowerShell host required by this module
# PowerShellHostName = ''

# Minimum version of the Windows PowerShell host required by this module
# PowerShellHostVersion = ''

# Minimum version of Microsoft .NET Framework required by this module
# DotNetFrameworkVersion = ''

# Minimum version of the common language runtime (CLR) required by this module
# CLRVersion = ''

# Processor architecture (None, X86, Amd64) required by this module
# ProcessorArchitecture = ''

# Modules that must be imported into the global environment prior to importing this module
# RequiredModules = @()

# Assemblies that must be loaded prior to importing this module
RequiredAssemblies = @(
    "lib\TagLibSharp.dll"
)

# Script files (.ps1) that are run in the caller's environment prior to importing this module.
# These paths must match the files on disk exactly, including case: the manifest is
# resolved by the filesystem, so a name that differs only in case works on Windows
# and fails on any case-sensitive filesystem, which is what CI runs on.
ScriptsToProcess = @(
    "Classes\ITunesTrackData.class.ps1"
    "Classes\MusicFileInfo.class.ps1"
)

# Type files (.ps1xml) to be loaded when importing this module
# TypesToProcess = @()

# Format files (.ps1xml) to be loaded when importing this module
# FormatsToProcess = @()

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
# NestedModules = @()

# Functions to export from this module
# Listed explicitly rather than as '*-*'. A wildcard matches on name shape, so
# a private helper ever named Verb-Noun would be exported by accident. The list
# is derived from the files in Public/; regenerate it with the AST rather than
# maintaining it by hand, so a new function is never left out of the manifest.
FunctionsToExport = @(
    'Find-iTunesDuplicatedTracks'
    'Format-iTunesFileName'
    'Get-FileMetadata'
    'Get-SimpleAttributes'
    'Get-iTunesFileLocations'
    'Get-iTunesLibrary'
    'Get-iTunesLibraryGenres'
    'Get-iTunesMediaLocation'
    'Get-iTunesPlaylist'
    'Get-iTunesPlaylistTracks'
    'Get-iTunesSelectedTracks'
    'Get-iTunesXmlLibrary'
    'Get-iTunesXmlLibraryTracks'
    'Search-iTunesLibrary'
    'Set-iTunesTrackData'
    'Set-iTunesTrackGenre'
    'Set-iTunesTrackGrouping'
    'Set-iTunesTrackName'
    'Set-iTunesTrackRating'
    'Set-mp3TrackData'
    'Start-iTunes'
    'Sync-iTunesPlaylistTracks'
    'Sync-iTunesTrackData'
)

# Cmdlets to export from this module
# The module is a script module, so it has none. Explicitly empty so a future
# binary cmdlet is not exported by wildcard without a decision being made.
CmdletsToExport = @()

# Variables to export from this module
# The module deliberately exposes none of its internals. The .psm1 assigns the
# shared state with $GLOBAL:, which is true global scope, so iTunesRoot,
# iTunesApplication, iTunesLibrary and iTunesMediaPath reach the caller
# regardless of this setting; an empty list here does not hide them.
VariablesToExport = @()

# Aliases to export from this module
# The module defines no aliases.
AliasesToExport = @()

# DSC resources to export from this module
# DscResourcesToExport = @()

# List of all modules packaged with this module
# This lists the file names of other module manifests packaged alongside this one,
# not this module's own name. Naming PSiTunes here made Test-ModuleManifest fail
# with "the specified ModuleList entry is invalid", because there is no second
# manifest to list. There are no dependent modules, so it stays empty.
# ModuleList = @()

# List of all files packaged with this module
# FileList = @()

# Private data to pass to the module specified in RootModule/ModuleToProcess. This may also contain a PSData hashtable with additional module metadata used by PowerShell.
PrivateData = @{

    PSData = @{

        # Tags applied to this module. These help with module discovery in online galleries.
        Tags = @("PowerShell","iTunes")

        # A URL to the license for this module.
        LicenseUri = 'https://github.com/MisterSeajay/PSiTunes/blob/main/LICENSE'

        # A URL to the main website for this project.
        ProjectUri = 'https://github.com/MisterSeajay/PSiTunes'

        # A URL to an icon representing this module.
        # IconUri = ''

        # ReleaseNotes of this module
        ReleaseNotes = 'https://github.com/MisterSeajay/PSiTunes/wiki'

    } # End of PSData hashtable

} # End of PrivateData hashtable

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
# DefaultCommandPrefix = 'iTunes'

}