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

- **The module starts iTunes when it is imported.** Every command in `Public/`
  reaches the iTunes COM automation object, and `PSiTunes.psm1` calls
  `Start-iTunes` and `Get-iTunesLibrary` at import time. That makes the module
  impossible to import for help, for `Get-Command`, or for a test that has
  nothing to do with iTunes. The test suite works around this by dot-sourcing
  the files it needs rather than importing the module; fixing the module itself
  is the single change that would unblock the most work here.

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

  One line has been fixed already: the missing blank line after the `# PSiTunes`
  heading, which markdownlint-cli2 flagged as MD022. That is the whole of the
  current content; the two-line stub is otherwise unchanged.

  markdownlint-cli2 0.23.3 is installed globally, and all three Markdown files
  lint clean under `.markdownlint.json`. The config was written before any
  linter had run against it, so that clean result is the first real validation
  of the config itself.

- [ ] **Copy the pre-commit hook from PSToolkit.** `.markdownlint.json` now
  exists and all three Markdown files lint clean under it, verified with
  markdownlint-cli2 v0.23.3. `.githooks/pre-commit` does not, so there is no
  gate: a Markdown rule can be committed without being checked. Copy the hook
  and remove the blockquote in `AGENTS.md` that says it is missing.
  `.gitattributes` is already in place and already pins `.githooks/*` to LF, so
  the hook will work once it exists.

  The hook should call `markdownlint-cli2`, which is now installed globally at
  0.23.3. Do not substitute `markdownlint-cli`: that is the older v0 package,
  it reads the config differently, and a green result from it does not mean the
  repository's own rules passed. This bit once already — the v0 package was the
  one on PATH, so a run against it would have looked fine while checking
  something else.

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

- [x] **Seven functions took pipeline input with no `process` / `end` blocks.**
  `AGENTS.md` 1.2 requires explicit sections on anything accepting
  `ValueFromPipeline`, because an un-sectioned body only processes the final
  pipeline object. Affected: `Find-iTunesDuplicatedTracks`,
  `Search-iTunesLibrary`, `Set-iTunesTrackGenre`, `Set-iTunesTrackRating`,
  `Set-mp3TrackData`, `Sync-iTunesPlaylistTracks`, `Sync-iTunesTrackData`.

  This was not theoretical. Demonstrated directly: piping three objects `A`,
  `B`, `C` into an un-sectioned function processed only `C`. So
  `Get-iTunesSelectedTracks | Set-iTunesTrackRating -Rating 5` on three tracks
  set one rating, on the last track only, silently. All seven are fixed and
  verified by piping several objects in and checking every one was handled.

  The fix is not uniform, and that is the part worth remembering:

  - Per-object commands (`Set-iTunesTrackGenre`, `Set-iTunesTrackRating`,
    `Set-mp3TrackData`, `Search-iTunesLibrary`, `Sync-iTunesPlaylistTracks`)
    do their work in `process`, once per object.
  - Whole-set commands (`Find-iTunesDuplicatedTracks`,
    `Sync-iTunesTrackData`) *cannot* work per object: a duplicate is a
    relationship between tracks, and a sync is a property of a group. These
    collect in `begin` and report in `end`. Converting them naively to
    `process` would have been a worse bug than the one being fixed.

  Two further problems were fixed at the same time.
  `Set-iTunesTrackGenre` compared genres with `-notmatch`, treating the genre
  as a regular expression, so a genre such as `C++/core (live)` would either
  throw or match the wrong tracks; it now uses `-cne`, a literal comparison.
  `Set-iTunesTrackRating` multiplied `$Rating` by 20 in the function body,
  which under a `process` block would compound once per pipeline object; the
  conversion is now into a per-object local.

- [x] **`Get-iTunesFileLocations` reported progress backwards.**
  `-PercentComplete [math]::floor($XmlCount/$Counter)` had the division the
  wrong way round, so over a 100-entry dictionary the bar started at 100% and
  fell to 1%: `floor(100/1)` is 100 and `floor(100/100)` is 1. It now reads
  `floor(($Counter / $XmlCount) * 100)`, which ascends 1, 50, 100, and it
  guards the empty-dictionary case, which the new expression would otherwise
  divide by zero.

  Note the direction: the bar ran backwards, it did not sit at zero. An
  earlier note in this file had that backwards, and said the bar stayed at 0%
  before jumping to full. Checked with arithmetic rather than by eye.

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

  This is the item that most needs a test suite, because the correct placement
  of a release is not something that can be checked by reading. A test that
  counts live handles across a loop would show whether the fix works.

- [ ] **`cleanCharacterSet` destroys non-ASCII text, and is dead code.**
  It round-trips a string through ISO-8859-8 and back as UTF-8. ISO-8859-8 has no
  code point for `é`, so it encodes to `?`, and that decodes as a plain `e`:
  `café` comes back as `cafe`, and a Cyrillic character comes back as `?`.
  Verified by inspecting the bytes. Anything non-ASCII that passed through this
  would be silently mangled, which matters for a module handling music metadata.

  It is currently **called from nowhere** — defined, exported by nothing, and
  unreferenced. So the bug is latent rather than active, which is why it is
  recorded rather than fixed here: the function's purpose is not recoverable from
  the code, and the fix depends on whether it was meant to convert *from*
  ISO-8859-8 (in which case the round trip is backwards) or to sanitise text
  (in which case it should be deleted). Either way it should not sit in
  `Private/` looking load-bearing.

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

- [x] **Create `Tests/` and a Pester suite.** 35 tests across two files, plus
  `Scripts/Invoke-Tests.ps1` as the runner. All pass.

  `Tests/Private.Tests.ps1` unit-tests the pure helpers, which need no iTunes.
  `Tests/Module.Tests.ps1` checks structure: one function per file, approved
  verbs, `CmdletBinding` present, every parameter typed, help complete, and the
  manifest's export list matching `Public/` exactly.

  Two things about Pester 6 that cost time and will cost it again:

  - **`$PSScriptRoot` inside a `BeforeAll` is the directory Pester was invoked
    from, not the test file's directory.** Using it to locate `Private/`
    silently resolved to the wrong folder, sourced nothing, and left 20 tests
    asserting against functions that did not exist. `$PSCommandPath` is the test
    file. `Tests/Module.Tests.ps1` now opens with a Describe that asserts the
    helpers are actually defined, so a setup failure cannot again present as a
    green suite.
  - **`Should -Be` is case-insensitive; `Should -BeExactly` is not.** Assertions
    like `convertToCapitalizedWords 'hello world' | Should -Be 'Hello World'`
    cannot ever fail, because the only difference is case. Every string
    assertion in the suite now uses `-BeExactly`.

- [x] **Prove the gate can fail.** Done, per `AGENTS.md` 1.8:

  - Sabotaging `Private/convertToCapitalizedWords.ps1` so it returns its input
    unchanged: 33 passed, 2 failed, exit 1.
  - Removing a type constraint from `Get-SimpleAttributes.ps1`: exit 1.
  - Removing that function's help block: exit 1.
  - Adding a test file that cannot be parsed: 35 passed, 0 failed, but 1 failed
    *container*, exit 1. This is the case a `FailedCount`-only gate would call a
    pass.
  - Pointing the runner at an empty directory: exit 1.
  - Passing a non-existent path: exit 1.

- [x] **Guard the help with a test.** `Tests/Module.Tests.ps1` fails if a public
  function loses its help block, its `.SYNOPSIS`, its `.DESCRIPTION`, its
  `.EXAMPLE`, or a `.PARAMETER` entry, and also if a `.PARAMETER` names something
  not declared. All 23 pass. There is no allow-list, because there is nothing to
  allow.

  It also found seven untyped parameters, all now fixed: `$XmlLibrary` in
  `Get-iTunesMediaLocation` and `Get-iTunesXmlLibraryTracks`, `$Path` in
  `Get-iTunesXmlLibrary`, `$Track` in `Format-iTunesFileName` and
  `Get-SimpleAttributes`, and `$Value` in `Set-iTunesTrackData` and
  `Set-mp3TrackData`. The two `$Value` parameters are `[System.Object]` on
  purpose: their `ValidateScript` is what constrains them to Int, String or
  DateTime, and keeping the type loose means the validation attribute produces
  the error rather than the binder.

- [x] **Add a PSScriptAnalyzer gate at `-Severity Error`.** Wired into
  `Scripts/Invoke-Tests.ps1`, which now runs the tests and the analyzer and
  exits non-zero on either.

  The baseline, measured before setting the threshold: **0 errors, 66 warnings**,
  6 informational. Error is the right first gate because the codebase is clean at
  that level. The warnings, by count:

  | Rule | Count |
  | --- | --- |
  | `PSUseProcessBlockForPipelineCommand` | 11 |
  | `PSUseSingularNouns` | 9 |
  | `PSAvoidUsingWriteHost` | 9 |
  | `PSAvoidGlobalVars` | 8 |
  | `PSShouldProcess` | 8 |
  | `PSAvoidUsingCmdletAliases` | 7 |
  | `PSReviewUnusedParameter` | 6 |
  | `PSPossibleIncorrectComparisonWithNull` | 5 |
  | `PSUseOutputTypeCorrectly` | 4 |
  | `PSAvoidUsingPositionalParameters` | 2 |
  | `PSAvoidDefaultValueForMandatoryParameter` | 1 |
  | `PSAvoidDefaultValueSwitchParameter` | 1 |

  Lowering the gate to Warning is a decision to make, not a side effect, and each
  group wants a different answer. `PSUseProcessBlockForPipelineCommand` at 11 is
  the largest and the most interesting: the seven in `Public/` are now fixed, so
  the remainder are in `Private/` and `Scripts/`. `PSShouldProcess` at 8 marks
  commands that mutate state without `-WhatIf`, which several in this module
  arguably should have. `PSUseSingularNouns` at 9 will not be fixed: the
  `iTunes`-suffixed nouns are deliberate and renaming them would break every
  script that uses the module.

- [ ] **Integration tests for the COM commands.** Still not done, and still the
  largest gap in coverage. Everything tested so far is either a pure helper or a
  structural check; not one test exercises a command against a real library.
  This needs iTunes installed, a populated library, and the real media path.

  Keep it small, and make it skip loudly rather than silently pass when iTunes is
  absent. `AGENTS.md` 1.8 is explicit that a check skipped silently is not a
  check, and the pattern is already in `Invoke-Tests.ps1` for a missing Pester.

  The COM release item below is the one that most needs this, because whether a
  release is in the right place cannot be determined by reading the code.

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

- [ ] **Decide what to do about the 66 analyzer warnings.** Not a task list, a
  menu. Some groups are worth fixing, some should be formally excluded, and at
  least one should be left alone on purpose. Settling it is what makes lowering
  the gate to Warning possible. The counts are in the Testing section above.

  The `.gitattributes` in this repository is also worth a look here: it pins
  `*.ps1` as `text`, which does not record that those files carry a BOM. Git
  treats the BOM as part of the content, so it is preserved, but nothing in the
  attributes would stop a future contributor stripping it. `AGENTS.md` 1.1 asks
  for the BOM to be committed rather than synthesised, which is what happens; a
  test asserting the BOM is present on every source file would enforce it.

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
