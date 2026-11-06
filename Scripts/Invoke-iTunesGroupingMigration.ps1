<#
.SYNOPSIS
    Migrates metadata from the iTunes 'Grouping' field to the 'Comment' field across the library.

.DESCRIPTION
    For years, using the 'Grouping' field to store mood or genre keywords was a standard way to build
    dynamic smart playlists in iTunes/Apple Music. However, recent versions of the iOS/iPadOS Music app
    automatically group songs in UI views according to the Grouping field, causing undesirable library
    sorting.

    This script programmatically transfers track keywords from 'Grouping' into 'Comment' via the iTunes
    COM API and subsequently clears 'Grouping' so iOS devices resume normal album/artist layout.

    Because the 'Comment' field maps directly to standard ID3/MP4 audio file tags (COMM / cmt), this
    metadata remains completely visible and editable across both iTunes/Apple Music and third-party
    media managers like MusicBee.

    The script imports the PSiTunes module itself, so it can be run from any PowerShell session. Run
    with -WhatIf first. -Limit processes a prefix of the library for a cheap trial run. -Confirm can
    be used to force prompts; by default there is no per-track prompt (confirm impact is Medium).

.PARAMETER KeepGrouping
    Switch. When set, the track's 'Grouping' property is left populated after it is copied to
    'Comment'. Without it (the default) 'Grouping' is cleared, which is what fixes the iOS UI
    grouping behaviour.

.PARAMETER Limit
    Trial-run limit: examine only the first N tracks of the library instead of all of them. 0 (the
    default) examines the whole library.

.PARAMETER ExistingComment
    What to do when a track already has data in its 'Comment' field. 'Overwrite' (the default)
    replaces it, 'Append' adds the Grouping text after the existing comment separated by a space,
    and 'Skip' leaves such tracks untouched and counts them in the summary. Tracks whose Comment is
    empty behave identically in all three modes.

.EXAMPLE
    .\Scripts\Invoke-iTunesGroupingMigration.ps1 -WhatIf -Limit 25
    Dry-runs the migration across the first 25 tracks of the library, showing what would change
    without modifying any track tags or files.

.EXAMPLE
    .\Scripts\Invoke-iTunesGroupingMigration.ps1
    Executes the migration across all file-based tracks in the iTunes library.

.EXAMPLE
    .\Scripts\Invoke-iTunesGroupingMigration.ps1 -ExistingComment Append
    Runs the migration while preserving any existing Comment text and appending the Grouping
    keywords to it.

.NOTES
    RUNNING AGAINST LARGE LIBRARIES (10k+ TRACKS):
    1. Execution speed and disk I/O: modifying track properties via the iTunes COM interface causes
       iTunes to schedule tag flushes back to the physical audio files. For libraries with 15,000+
       items, execution can take 10-30 minutes depending on whether media resides on an SSD or
       network storage (NAS/HDD). Start with -WhatIf -Limit 25, then a real run of -Limit 100.
    2. Comment data: with the default -ExistingComment Overwrite, existing comments are replaced.
       Many older tracks contain legacy junk in the Comment field (e.g. the 10-character hex strings
       generated for iTunes Sound Check, or store transaction IDs). Sound Check data is recalculated
       by iTunes when enabled, so overwriting it is not a loss. Use -ExistingComment Append or Skip
       to preserve other comment content.
    3. Tracks screened out: only Kind 1 (file) tracks whose Location is neither empty nor an
       http/itms URL are touched, which screens out streams, URLs and most cloud tracks. The start
       of this screening is the module-wide convention ($_.Kind -eq 1); the cloud side of the claim
       is based on the Location check and should be confirmed on a trial run before a full one.
       Any individual track that still fails reports a warning and the run continues.
    4. Safe to re-run: a track migrated successfully has an empty Grouping field and is skipped on
       the next run, so an interrupted run can simply be started again.
    5. Smart playlists: after running, update your Smart Playlists to filter on
       [Comment] [contains] [keyword] instead of [Grouping] [contains] [keyword].
    6. Import noise under -WhatIf: -WhatIf propagates into the module import and suppresses its own
       COM connection, so an import-time 'What if: Performing New-Object' line, two media-path
       fallback warnings and a property-not-found error appear before this script's output. The
       script then makes its own connection (the 'Trial run:' / 'Scanning:' lines show enumeration
       worked). Those messages are module import behaviour, not the migration failing.
#>

[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'Medium')]
param(
    [switch]$KeepGrouping,

    [ValidateRange(0, [int]::MaxValue)]
    [int]$Limit = 0,

    [ValidateSet('Overwrite', 'Append', 'Skip')]
    [string]$ExistingComment = 'Overwrite'
)

Set-StrictMode -Version 2

# Import the module after parameter binding, in the pattern of Merge-FilesToLibrary.ps1.
# Importing starts iTunes and populates the module's globals; note that it cannot do so under
# -WhatIf (see below), which is why the script makes its own connection afterwards.
$ScriptRoot = $PSScriptRoot
if (-not $ScriptRoot) { $ScriptRoot = Split-Path $MyInvocation.InvocationName -Parent }
$ModuleManifest = Join-Path $ScriptRoot '..\PSiTunes.psd1'
Import-Module (Resolve-Path $ModuleManifest) -Force -Verbose:$false

# Progress and summary lines below use Write-Host deliberately: they are addressed to the person
# running the script, not the pipeline (AGENTS.md 1.3).

# -WhatIf on the command line propagates into the module import: Start-iTunes's ShouldProcess then
# suppresses the COM connection and leaves the module's $iTunesApplication global null, so every
# later property access fails first with 'What if: Performing New-Object' and then with
# property-not-found errors (AGENTS.md 2.2). Enumerating the library is read-only, so even a dry run
# needs the connection: make an explicit one here. -WhatIf:$false overrides the inherited preference
# for this one call, and the library is taken from this connection rather than from any module
# global, so the script is not coupled to state a caller could shadow (AGENTS.md 2.3).
$iTunesConnection = Start-iTunes -WhatIf:$false -Verbose:$false
if (-not $iTunesConnection) {
    Write-Error 'Unable to connect to iTunes. Check that iTunes is installed and can be automated (Start-iTunes warns when the ProgID is registered by another application), then run again.'
    return
}
$Library = $iTunesConnection.LibraryPlaylist
$Tracks = $Library.Tracks
$TotalTracks = $Tracks.Count

$CandidateCount = 0
$WrittenCount = 0
$NotConfirmedCount = 0
$FailedCount = 0
$SkippedNoGrouping = 0
$SkippedNotLocal = 0
$SkippedOccupied = 0

$EndIndex = $TotalTracks
if ($Limit -gt 0 -and $Limit -lt $EndIndex) {
    $EndIndex = $Limit
    Write-Host "Trial run: examining the first $Limit of $TotalTracks tracks." -ForegroundColor Cyan
}

Write-Host "Scanning $EndIndex of $TotalTracks tracks in the iTunes library..." -ForegroundColor Cyan

try {
    for ($i = 1; $i -le $EndIndex; $i++) {
        $Track = $Tracks.Item($i)
        try {
            # Kind 1 is ITTrackKindFile: file-based tracks. Anything else is a stream, CD track, URL
            # or other non-file item. Cloud tracks can still report Kind 1, so the Location check
            # below screens those too.
            if ($Track.Kind -ne 1) {
                $SkippedNotLocal++
                continue
            }

            # Empty or remote locations (http/itms) mean the track has no local file behind it.
            $Location = [string]$Track.Location
            if ([string]::IsNullOrEmpty($Location) -or $Location -match '^(https?|itms)://') {
                $SkippedNotLocal++
                continue
            }

            $Grouping = $Track.Grouping
            if ([string]::IsNullOrWhitespace($Grouping)) {
                $SkippedNoGrouping++
                continue
            }
            $Grouping = $Grouping.Trim()

            switch ($ExistingComment) {
                'Append' {
                    $CurrentComment = $Track.Comment
                    if ([string]::IsNullOrWhitespace($CurrentComment)) {
                        $NewComment = $Grouping
                    }
                    else {
                        $NewComment = ($CurrentComment.Trim() + ' ' + $Grouping).Trim()
                    }
                }
                'Skip' {
                    $CurrentComment = $Track.Comment
                    if (-not [string]::IsNullOrWhitespace($CurrentComment)) {
                        $SkippedOccupied++
                        continue
                    }
                    $NewComment = $Grouping
                }
                default {
                    $NewComment = $Grouping
                }
            }

            $CandidateCount++

            if (-not ($PSCmdlet.ShouldProcess($Track.Name, "Migrate Grouping '$Grouping' to Comment"))) {
                $NotConfirmedCount++
                continue
            }

            $Track.Comment = $NewComment
            if (-not $KeepGrouping) {
                $Track.Grouping = ''
            }
            $WrittenCount++
        }
        catch {
            $FailedCount++
            Write-Warning "Track $i could not be updated: $($_.Exception.Message)"
        }
        finally {
            # The script owns this reference and is done with it at the end of every iteration, so
            # this is the right place to release (AGENTS.md 1.9: $track = $null alone is not a
            # release).
            if ($Track) {
                try {
                    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Track)
                }
                catch {
                    Write-Verbose "ReleaseComObject for track $i failed: $($_.Exception.Message)"
                }
                $Track = $null
            }
        }

        if ($i % 500 -eq 0 -or $i -eq $EndIndex) {
            $Percent = [math]::Floor(($i / $EndIndex) * 100)
            Write-Progress -Activity 'Migrating iTunes keywords (Grouping to Comment)' `
                           -Status "Processing track $i of $EndIndex" `
                           -PercentComplete $Percent
        }
    }
}
finally {
    # The script owns the collection and the library playlist reference it fetched; release both now
    # that it is done with them. The collection is released before the playlist it came from.
    foreach ($Reference in @($Tracks, $Library)) {
        try {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($Reference)
        }
        catch {
            Write-Verbose "ReleaseComObject failed: $($_.Exception.Message)"
        }
    }
}

$Colour = if ($FailedCount -eq 0) { 'Green' } else { 'Yellow' }
if ($WhatIfPreference) {
    Write-Host "Would migrate $CandidateCount track(s); $FailedCount failed; skipped: $SkippedNoGrouping with no Grouping, $SkippedNotLocal not local file tracks, $SkippedOccupied with an existing Comment." -ForegroundColor $Colour
}
else {
    $DeclinedText = ''
    if ($NotConfirmedCount -gt 0) { $DeclinedText = "; $NotConfirmedCount declined at confirmation" }
    Write-Host "Migrated $WrittenCount track(s)$DeclinedText; $FailedCount failed; skipped: $SkippedNoGrouping with no Grouping, $SkippedNotLocal not local file tracks, $SkippedOccupied with an existing Comment." -ForegroundColor $Colour
}
