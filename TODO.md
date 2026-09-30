# TODO

Working list for PSiTunes. Items persist between sessions; check this file at
the start of a session and update it as things land.

Rules for this file:

- Tick a box only when the item is verified, not when the code compiles.
- Record the reason for a deliberate non-action, so it is not re-litigated.
- Add a new item the moment something is deferred rather than dropped.

Guidance for the project lives in `AGENTS.md`; cmdlet detail lives in
`Get-Help`. Neither duplicates what is tracked here.

## Read this first

Two of the items below are load-bearing for anything else that touches the
code, and are worth doing before the rest:

- **The module starts iTunes when it is imported.** Every command in `Public/`
  reaches the iTunes COM automation object, and `PSiTunes.psm1` calls
  `Start-iTunes` and `Get-iTunesLibrary` at import time. That makes the module
  impossible to import for help, for `Get-Command`, or for a test that has
  nothing to do with iTunes. See "Testing" below; fixing it properly is the
  single change that unblocks the most work here.
- **There is no test suite at all.** Several items below are bugs that a test
  would have caught, and at least two bugs already fixed this way were only
  found by reading the code.

## Documentation

- [ ] **Write the README.** It is still the original two lines:

  ```text
  # PSiTunes
  PowerShell command-line toolkit for iTunes libraries
  ```

  The module has 23 exported commands, an MIT licence, a vendored TagLibSharp
  and a `Scripts/` folder of utilities, and none of that is documented. Per
  `AGENTS.md` 1.4 the README describes the project: what it is for,
  installation, the fact that importing it starts iTunes, usage, and
  development requirements. It points at `Get-Help` for parameter detail and
  does not repeat it.

  Done when a reader can install the module and run their first command from
  the README alone. Every command line published in it should be run before it
  is written down: four of the first drafts of PSToolkit's README did not work
  and had to be corrected, two of them because they were product bugs.

- [ ] **Copy the documentation tooling from PSToolkit.** `.markdownlint.json`
  and `.githooks/pre-commit` do not exist here, so the `AGENTS.md` Documentation
  section currently tells a reader to run a linter with no config and enable a
  hook that is not there. `AGENTS.md` has a blockquote marking this, which is a
  note about a gap rather than a fix. Copy both, then remove the blockquote.
  `.gitattributes` is already in place and already pins `.githooks/*` to LF, so
  the hook will work once it exists.

- [ ] **Decide whether `AGENTS.md` should point at this file.** `AGENTS.md` 1
  says a deliberate exception belongs in `README.md`, which is a different
  thing: a README is read by users, and this list is not for them. PSToolkit hit
  exactly this — its TODO.md drifted for a while because nothing told a future
  session to read it. The README's Development section is the natural place to
  point here once the README exists, which is an argument for writing the README
  first.

## Bugs found by reading the code, not by a failure

Each of these is a defect present at the time of writing. None has caused a
reported failure, which is the point: they are silent.

- [ ] **Seven functions take pipeline input but have no `process` / `end`
  blocks.** `AGENTS.md` 1.2 requires explicit sections on anything accepting
  `ValueFromPipeline`, because an un-sectioned body only processes the final
  pipeline object. Affected: `Find-iTunesDuplicatedTracks`,
  `Search-iTunesLibrary`, `Set-iTunesTrackGenre`, `Set-iTunesTrackRating`,
  `Set-mp3TrackData`, `Sync-iTunesPlaylistTracks`, `Sync-iTunesTrackData`.

  These work today because each is normally invoked with one object at a time.
  They will silently do the wrong thing the first time someone pipes several
  tracks in, which is the normal way to use them. This is the most dangerous
  item on the list, because the failure mode is data loss rather than an error.

  Note that `Set-iTunesTrackRating` in particular has no `end` block and writes
  to the library, so `Get-iTunesSelectedTracks | Set-iTunesTrackRating -Rating 5`
  on three tracks would set one rating, not three. The same applies to
  `Set-iTunesTrackGenre` and the two `Sync-` commands.

- [ ] **`Get-iTunesFileLocations` reports progress backwards.**
  `-PercentComplete [math]::floor($XmlCount/$Counter)` has the division the
  wrong way round. At the first track it reports 0%, and by the last it reports
  `$XmlCount`, which exceeds 100. It should be
  `[math]::floor($Counter / $XmlCount * 100)`. Confirmed by arithmetic:
  `floor(10/100)` is 0 and `floor(100/10)` is 10. `Write-Progress` clamps a
  value above 100, so the visible effect is a bar that sits at 0% for the whole
  run and then jumps to full — not a crash, just a useless progress bar.

- [ ] **No command releases its COM references.** `ReleaseComObject` appears
  nowhere in the module. `Get-iTunesLibraryGenres` and `Set-iTunesTrackName`
  both iterate `$iTunesLibrary.Tracks`, which materialises a COM object per
  track. `AGENTS.md` 1.9 notes that assigning `$track = $null` is not a reliable
  release. The failure mode is deferred and misattributed: handles leak during
  a long run, and hours later iTunes starts refusing new automation calls, which
  reads as an iTunes problem rather than a leak in this module.

  Needs care rather than a blanket `try/finally`: releasing an object the caller
  still holds is worse than leaking it, so the release has to be at the point
  where the module is done with a reference it owns.

- [ ] **`Set-iTunesTrackName` takes its library from a self-assignment.**
  Line 48 is `$iTunesLibrary = $iTunesLibrary  # Uses global variable if set`,
  where the parameter's default is the identically named global. This works
  only through PowerShell's dynamic scoping, which `AGENTS.md` 1.9 calls out as
  invisible in the signature and liable to break on refactor. A caller who has
  an unrelated `$iTunesLibrary` in scope silently changes which library gets
  renamed. The parameter already exists, so the fix is to make the fallback
  explicit (`$global:iTunesLibrary`) rather than to add a parameter.

  `Scripts/Set-iTunesFileLocations.ps1` does the same thing with
  `$global:iTunesLibrary` read directly, so it has the same coupling to module
  state and is not directly testable.

## Testing

- [ ] **Create `Tests/` and a Pester 5 suite.** Nothing is tested, so nothing
  gates a change. `AGENTS.md` 1.8 is the specification.

  The hard part is that this module is not hermetic. Two approaches, and they
  are not equally useful:

  - **Unit-test `Private/` with injected data.** `cleanLocalUri`,
    `cleanSearchString`, `parsePlistDict`, `convertToCapitalizedWords`,
    `convertFromFileAttributes` and `getDataFromFilePath` are all pure string
    or object transforms and can be tested with no iTunes at all. This is where
    most of the value is, and it is achievable today.
  - **Integration-test the `Public/` COM commands.** This needs iTunes
    installed, a populated library, and the machine's real media path. Keep it
    small, and make it skip loudly rather than silently pass when iTunes is
    absent — `AGENTS.md` 1.8 is explicit that a check which is skipped silently
    is not a check.

  Per 1.8, the suite must set `Run.PassThru` and treat a `$null` result as a
  failure, and the runner must exit non-zero. It is also worth proving the
  runner can fail by running it against a suite that is meant to fail, per the
  same section.

- [ ] **Guard the help with a test.** `AGENTS.md` 1.8 asks for a test that
  fails when a public function loses its help block, its `.SYNOPSIS`, or a
  `.PARAMETER` entry. All 23 functions currently pass such a check, verified
  via the AST: documented parameters equal declared parameters in both
  directions. There is no allow-list of undocumented parameters, because there
  are none, so the test starts green and stays meaningful.

  Two AST gotchas from 1.4 apply and were hit while doing this by hand:
  `GetHelpContent()` returns `$null` on the file-level `ScriptBlockAst` and must
  be called on the `FunctionDefinitionAst`, and the parser upper-cases the
  parameter keys while the dictionary is case-sensitive on lookup.

- [ ] **Add a PSScriptAnalyzer gate, starting at `-Severity Error`.** Per
  `AGENTS.md` 1.8 a gate needs a baseline before it needs a threshold, and the
  threshold needs to have been seen failing. Establish the current count first,
  then decide whether to fix or freeze it.

## Module structure

- [ ] **Importing the module starts iTunes.** `PSiTunes.psm1` calls
  `Start-iTunes` and `Get-iTunesLibrary` at import, and sets
  `$GLOBAL:iTunesApplication` and `$GLOBAL:iTunesLibrary`. About a dozen
  functions assume `$iTunesApplication` is in scope rather than taking it as a
  parameter, so importing the module to read one function's help launches the
  application.

  The fix is to pass the application object into the commands that need it, which
  is a real refactor rather than a small one. The alternative of leaving it is a
  deliberate decision, and it is currently unrecorded: if it stays, the reason
  belongs here, because `AGENTS.md` says an exception should be recorded rather
  than quietly kept.

- [ ] **`Classes/` is loaded twice.** The manifest's `ScriptsToProcess` lists
  both class scripts, and `PSiTunes.psm1` dot-sources the same directory. Each
  class definition therefore executes at import and again at module load. Harmless
  today. Pick one mechanism and remove the other; the `.psm1` dot-source is the
  better one to keep, since it is the mechanism `AGENTS.md` 1.6 describes and it
  does not depend on the manifest's paths resolving.

- [ ] **Regenerate `FunctionsToExport` rather than maintaining it by hand.**
  The manifest now lists all 23 functions explicitly, which is what `AGENTS.md`
  1.6 asks for, but the list is a snapshot. A new function in `Public/` is not
  exported until someone remembers to add it, and it will still work locally
  while being missing for anyone who installs the module. A small build step
  that derives the list from the AST and writes it into the manifest is the fix.
  There is no build script at all yet, so this may want to wait for one.

## Known behaviour worth a decision

- [ ] **`Get-iTunesPlaylist` matches names as regular expressions.** `-Name`
  defaults to `"."`, which matches every playlist, and a name containing regex
  metacharacters such as `(` or `[` will either fail to match or throw. The
  `-ExactMatch` switch exists and is not the default. Decide whether the default
  should be an exact match with an opt-in to regex, which is safer and matches
  what a user typing a playlist name expects, or keep the current behaviour and
  document it as deliberate. Either way this is a breaking change for anyone
  relying on the regex behaviour, so it wants a decision rather than a quiet fix.

- [ ] **`$SourcePath` in `Scripts/Merge-FilesToLibrary.ps1` is still a literal**
  (`D:\Music\Ripped`). The iTunes media paths are now derived from the library
  XML, but this one is a source directory for new music, which there is nothing
  in the library to derive it from. It is left as a parameter default; change it
  on the command line. Recorded here so it is not mistaken for an oversight.

  `PSiTunes.psm1` also still has `$FallbackMediaPath = "D:\iTunes\iTunes Media"`,
  used only when the library lookup fails. That one is intentional: it is a
  fallback, not a default, and it warns when it is used.

- [ ] **`Set-iTunesTrackData` does not release the tracks it is given.** Called
  directly by several commands, and the notes in its help say so. Folded into
  the COM release item above rather than tracked twice.

## Ideas, not yet decided

- [ ] **Build script and packaging.** There is no build step. A built module
  would need `Public/`, `Private/`, `Classes/` and `lib/TagLibSharp.dll` at
  minimum; note that `PSiTunes.psd1` has `RequiredAssemblies` pointing at
  `lib\TagLibSharp.dll`, so a package missing `lib/` will not import. Per
  `AGENTS.md` 1.6 a built module should be self-contained.

- [ ] **Decide whether the module is still for iTunes.** Windows 12 and later
  ship Media Player, and Apple has deprecated the iTunes Windows application.
  The COM ProgID `iTunes.Application` is what the entire module is built on, and
  on a machine without iTunes installed every command in `Public/` fails at
  import. Confirm the module is still the thing you want to maintain before
  investing further in it; the answer changes the value of most items above.

- [ ] **Continuous integration.** Nothing runs on push. Once there are tests and
  a linter, a workflow that runs them would catch the regression class that
  produced every bug in this list, all of which passed review or sat unnoticed
  because nothing executed the code.
