# PSiTunes AGENTS.md

When a rule and existing code disagree, fix the code. Record any deliberate
exception in README.md rather than quietly violating the rule.

Read `TODO.md` at the start of a session. It holds the deferred work, the
reasons for any deliberate non-action, and the known bugs that have not been
fixed. Update it as items land, and add an entry the moment something is
deferred rather than dropped.

## Documentation

**Markdown is linted with markdownlint-cli2** (npm package). The rules live in
`.markdownlint.json` at the repository root, so the linter runs with no extra
flags:

```powershell
markdownlint-cli2 "**/*.md"
```

That is the v2 package, `markdownlint-cli2`. Do not confuse it with
`markdownlint-cli`, which is a different, older package with a different
config format; a green result from the wrong binary means nothing. If the
command is not on PATH, install the right one rather than substituting:

```powershell
npm install -g markdownlint-cli2
```

All three Markdown files currently lint clean under this config.

The config, not this section, is the contract. The settings that are easy to
trip over:

- Unordered lists use a dash, never an asterisk.
- Code blocks are fenced and tagged with a language, never indented.
- Lines wrap at 120 characters, except inside code blocks and tables.
- The first line of a file is its top-level heading.
- A heading may repeat under a different parent, but not twice under one parent.

Two reasons the config is a file rather than a set of command-line flags: every
contributor and every CI job then lints against the same rules, and a rule that
lives only in one person's shell history is not a rule.

### The pre-commit hook

`.githooks/pre-commit` runs the linter over the staged Markdown, so a rule is
checked before it can be committed rather than discovered later. It is
POSIX `sh`, not PowerShell, because that is what git executes on every platform
including Windows.

> **The hook does not exist here yet.** There is no `.githooks/` directory in this
> repository, so there is nothing to enable. The config it would use,
> `.markdownlint.json`, does now exist. Copy the hook from PSToolkit when you
> want the gate; the item is tracked in `TODO.md`.

Enable it once per clone:

```powershell
git config core.hooksPath .githooks
```

`core.hooksPath` is local configuration and is not committed, so a fresh clone
does not get the hook until someone runs that. Say so when you hand the
repository to someone; an enabled-by-default assumption that is actually
off by default is worse than no hook.

**A missing linter fails the commit.** The hook does not fall through to a
warning, because per 1.8 a check that is skipped silently is not a check. If
markdownlint-cli2 is absent the hook says so, names the install command and
points at `git commit --no-verify` as the deliberate bypass.

**`.githooks/*` is pinned to LF in `.gitattributes`.** The shebang is the
first line, and a CR before its LF makes it a path `sh` cannot resolve. The
repository-wide `eol=crlf` rule would otherwise break the hook on Windows, so
the exception is required rather than cosmetic.

## PowerShell guidelines

### 1.1 Encoding and line endings

**Store `.ps1`, `.psd1` and `.psm1` files as UTF-8 *with* a byte-order mark.**

Windows PowerShell 5.1 reads a file with no BOM as ANSI (Windows-1252). Any
non-ASCII character — box-drawing characters, accented text, emoji, smart
quotes — is then decoded wrongly and appears as mojibake. PowerShell 7+ detects
UTF-8 without a BOM, so a file can pass locally and break for every 5.1 user.
Adding a BOM is correct for both.

The BOM is committed to the repository. Do not use git's
`working-tree-encoding=UTF-8-BOM` attribute to synthesise it on checkout: the
git documentation describes that attribute as not recommended, and it
complicates renormalisation.

Keep Markdown, JSON and other data files as UTF-8 *without* a BOM.

**Add a `.gitattributes` so line endings do not depend on each machine:**

```gitattributes
# Force CRLF line endings for PowerShell source files across all platforms
*.ps1  text eol=crlf
*.psm1 text eol=crlf
*.psd1 text eol=crlf
```

Without explicit line ending definitions, a file's line endings depend on whatever
`core.autocrlf` the contributor happens to have, and the same file differs between clones.

**Never round-trip source through `Get-Content` / `Set-Content`.** Those cmdlets
infer encoding on read and pick a default on write, which silently rewrites
BOMs and line endings. Use explicit encodings:

```powershell
$text = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$text =$text -replace "(?<!`r)`n", "`r`n"
[System.IO.File]::WriteAllText($path, $text, [System.Text.UTF8Encoding]::new($true))
```

Note the `$true`: it emits the BOM. The parameter-less `UTF8` does not, and will
strip one.

**Detect encoding before editing a file programmatically.** UTF-16 appears with
either byte order, and checking only for one of them silently rewrites the file
as UTF-8:

| Bytes at offset 0 | Encoding |
| --- | --- |
| `FF FE` | UTF-16 LE |
| `FE FF` | UTF-16 BE |
| `EF BB BF` | UTF-8 with BOM |
| anything else | UTF-8 / ASCII |

**Verify edits by byte count, and use `GetByteCount`.** A one-character change is
not always a one-byte change: a box-drawing character is one character and three
UTF-8 bytes. Check `expected = 3 + $encoding.GetByteCount($text)` rather than
`3 + $text.Length`, or a correct file will look corrupt.

**Use literal `.Replace()`, not `-replace`, for programmatic edits.** In a
`-replace` replacement string, `$_` and `$1` are interpolated by PowerShell
before the regex engine sees them, so editing a line containing `$_` splices in
the wrong text. Use `[string]::Replace($old, $new)`, or escape as `$$`.

### 1.2 Functions and parameters

**Use approved verbs, and Verb-Noun naming.** Check with `Get-Verb`. Public
functions are `Verb-Noun`; private helpers may be `camelCase`.

**The verb MUST come from the `Get-Verb` list.** It is a hard requirement, not a
preference: an unapproved verb does not sort, does not get its own `-Verb`
parameter set in `Get-Command`, and is invisible to anything driven by
discovery. `Get-Verb -Verb * | Where-Object Verb -eq 'MyVerb'` returning nothing
means the name is wrong.

> **Gotcha in Windows PowerShell 5.1:** `Get-Verb` has no `-Name` parameter, only
> `-Verb` and `-Group`. `Get-Verb -Name Split` is a binding error, not an empty
> result, so it does not prove the verb is unapproved — it proves you are running
> 5.1. The module declares `PowerShellVersion = '5.0'`, so write the check as
> `Get-Verb -Verb * | Where-Object { $_.Verb -eq 'Split' }`.

**The noun SHOULD be a short, high-level object,** and the parts of that object
belong in parameters, not in separate functions. `Get-FolderSize -Directory`
covers the directories; `Get-SizeOfDirectoryInFolder` is not a better design,
it is a command nobody can guess.

**Name the file after the function it contains,** so a function called
`Get-Report` lives in a file called `Get-Report.ps1`.

**`[CmdletBinding()]` goes in the function's attribute list, before `param`:**

```powershell
function Get-Example {
    [CmdletBinding()]
    [OutputType([System.IO.DirectoryInfo])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [ValidateScript({ Test-Path $_ })]
        [string]$Path
    )
    
    begin { }
    process {
        # Processing logic here
    }
    end { }
}
```

Placing `[CmdletBinding()]` *inside* the `param()` parentheses makes it a
per-parameter attribute. It is then silently ignored: the function gets no
`-Verbose`, no `-ErrorAction`, and no `$ErrorActionPreference` integration, and
no error is raised. A test that only checks the function runs will not catch it —
assert that `$func.Parameters.ContainsKey('Verbose')`.

**Always use `process` blocks when accepting pipeline input.** Functions
accepting `ValueFromPipeline` or `ValueFromPipelineByPropertyName` must use
explicit `begin`, `process`, and `end` blocks. Executing code in an
un-sectioned function body only processes the final pipeline object.

**Always declare a type for every parameter.** Untyped parameters become
`[object]`, which forces casts downstream.

**Use attributes for validation** — `ValidateSet`, `ValidatePattern`,
`ValidateRange`, `ValidateScript` — rather than hand-rolled `if` blocks. They
fail at parameter binding, with a message that names the parameter.

**Use `$PSBoundParameters`, not `$null -ne $x`, to detect an explicit argument.**
A parameter with a default is never `$null`; `$PSBoundParameters` distinguishes
"caller passed this" from "caller did not".

**Use `[switch]` for Booleans, and `ParameterSetName` for modes.** A
`[switch]$Directory` is unambiguous on the command line; a `[bool]$Directory`
accepts `$false`, which is almost never what the user meant. Mutually exclusive
modes belong in separate parameter sets so the binding engine rejects the
invalid combination:

```powershell
[CmdletBinding(DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'DirectoryOnly')][switch]$Directory,
    [Parameter(ParameterSetName = 'FileOnly')][switch]$File
)
```

**Support `-WhatIf` and `-Confirm` on modifying commands.** Any cmdlet
modifying disk, registry, or network state must declare
`[CmdletBinding(SupportsShouldProcess = $true)]` and wrap changes in
`if ($PSCmdlet.ShouldProcess($target, $action))`.

**Use `Set-StrictMode -Version 2.0` in modules and scripts.** It turns typos and
unset variables into errors instead of silent `$null`.

### 1.3 Output and the pipeline

**Return objects, not formatted text.** Callers may want to filter, sort or
count the result. A function that returns a pre-formatted string cannot be
composed.

**Prevent accidental pipeline pollution.** Any unassigned expression evaluated
inside a function leaks onto the output pipeline stream. Explicitly suppress
method results:

```powershell
# Bad: $list.Add() returns the index integer to the pipeline
$list.Add($item) 

# Good: Nullify unwanted return values
[void]$list.Add($item)
# OR
$null = $list.Add($item)
```

**Reserve `Write-Host` for messages addressed to a person.** It writes to the
host, not the pipeline, so the output cannot be piped, assigned, or asserted on
in a test. A tree-drawing command is a legitimate use — but document it, and
expect to capture it in tests with `6>&1`.

**Use the stream that matches the audience for everything else.** Diagnostics go
to `Write-Verbose` and `Write-Debug`, never to `Write-Host`. `-Verbose` is the
caller asking to see more, which is exactly what `Write-Verbose` is for, and
`[CmdletBinding()]` wires it up for free. Long-running progress that a user may
want to see but a pipeline should not receive goes to `Write-Information`,
captured with `6>&1`. A `Write-Host` diagnostic is invisible to
`-Verbose:$false`, unsuppressible, and untestable.

**Return `[System.IO.DirectoryInfo]` / `[FileInfo]`, not strings**, and declare
`[OutputType()]` so consumers can discover it.

### 1.4 Comment-based help is the source of truth

Comment-based help is the only documentation that travels with the code: it
works on an installed copy, renders in `Get-Help`, and is what the PowerShell
Gallery shows. A separate docs site drifts from the code and nothing detects it.

**The README describes the project. `Get-Help` describes the commands. They do
not overlap.** The README may list commands and show one example each. Parameter
types, defaults, and per-parameter semantics belong in `.PARAMETER` blocks and
nowhere else.

**A public function needs, at minimum:** `.SYNOPSIS`, `.DESCRIPTION`, a
`.PARAMETER` entry for every declared parameter, at least one `.EXAMPLE`, and
`.NOTES` for caveats. Place the help block inside the function body.

**`[Parameter(HelpMessage = "...")]` is not documentation.** It appears in
locally generated help, which makes an undocumented function look documented. It
does not appear in `Get-Help -Online` or on the Gallery. Do not use it as a
substitute for a help block.

**`.LINK` versus `HelpUri`:** `.LINK` is a normal keyword and always works.
`HelpUri` is what `Get-Help -Online` needs, and it must be an absolute URL to a
rendered page — a `blob/` URL to raw source will not serve as help. Choose
deliberately; do not set a `HelpUri` that does not actually resolve.

### Tooling gotchas when reading help from the AST

If you write tooling or tests that inspect help, note:

- `GetHelpContent()` returns **null** on the file-level `ScriptBlockAst`. Call it
  on the `FunctionDefinitionAst`.
- `CommentHelpInfo.Parameters` is a `Dictionary[String, String]`, not a
  collection of objects. Read names from `.Keys` — `.Parameters.Parameter` is
  `$null`, and `@($null)` looks like a one-element list with an empty name.
- The parser **upper-cases** those keys, and the dictionary is case-sensitive on
  lookup. Normalise before indexing, or compare case-insensitively.

### 1.5 Behave like the cmdlet you are imitating

**When a parameter name copies a built-in, copy its semantics too.** A
parameter that behaves differently from the cmdlet users already know is worse
than a differently named one.

`Get-ChildItem -Exclude` is the reference for exclusion parameters:

- patterns are **wildcards**, tested against the item's **name** (the leaf), not
  its full path
- matching is case-insensitive
- a directory that matches is **pruned**, not descended into
- it takes one or more patterns

`Get-ChildItem -ExcludePath` does **not** exist in Windows PowerShell 5.1, so do
not design against it unless the module declares a higher minimum version.

Two `-Exclude` parameters in the same module must behave identically. When more
than one command needs the same matching, put it in one shared private helper so
the two cannot drift apart.

### 1.6 Module structure

**Ship a `.psd1` manifest and a `.psm1` loader.** The manifest is the contract;
keep it valid by asserting `Test-ModuleManifest` passes.

**Disallow wildcards in manifest exports.** Set explicit arrays for
`CmdletsToExport`, `FunctionsToExport`, `VariablesToExport`, and
`AliasesToExport` in the manifest rather than wildcard `*`. Wildcards slow down
module auto-loading performance.

**Dot-source `Private/` then `Public/**` so definitions are available regardless
of alphabetical order:

```powershell
Set-StrictMode -Version 2.0
foreach ($sub in @('Private', 'Public')) {
    Get-ChildItem -Path (Join-Path $PSScriptRoot $sub) -Filter '*.ps1' -File |
        ForEach-Object { . $_.FullName }
}
```

**Derive `FunctionsToExport` from the `Public/` folder** using the AST, and write
it into the manifest at build time. A hand-maintained list drifts, and a
forgotten entry means the function still works locally but is missing for
everyone who installs the module.

**`PSData` URIs must actually resolve.** `ProjectUri`, `LicenseUri` and
`ReleaseNotes` are shown to Gallery users; check that each returns HTTP 200. A
link to an empty wiki, or to a licence file that does not exist, is a broken
promise. Prefer a file in the repository over a wiki you have not written yet.

**Do not ship stale generated artefacts.** If a build step writes a `.psd1`
alongside a `.psm1`, the `.psm1` remains the source of truth and the `.psd1` is
disposable. Make this explicit so nobody edits the generated copy.

### 1.7 Error handling

- **`throw` for programmer errors** — a bad argument the caller controls is
  usually a binding-time failure via validation attributes; use `Write-Error` for
  runtime conditions.
- **Set `-ErrorAction Stop` inside `try`** when you intend to `catch`. Without
  it, a non-terminating error does not enter the block.
- **Never swallow an exception.** An empty `catch` hides the failure. If
  continuing is correct, say so in a warning and explain what was skipped.
- **Partial-failure traversal should warn and continue.** A recursive walk that
  meets one access-denied directory should report it and keep going, rather than
  aborting everything. A bulk operation where one failure means the whole result
  is wrong should fail hard — pick per operation and document the choice.

### 1.8 Testing

**Pester 5 or later.** Structure tests as `Describe` / `Context` / `It`.

**A test that has never failed proves nothing.** When you add an assertion,
temporarily break the code and confirm the test goes red *for the stated reason*.
Also assert the file still parses, so you can distinguish a behavioural failure
from a syntax error:

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile($path, [ref]$null, [ref]$errors) | Out-Null
@($errors).Count | Should -Be 0
```

**Aggregate problems, then assert empty.** Collecting every failure into a list
and asserting it is empty reports all the problems in one run instead of one per
run:

```powershell
$problems = [System.Collections.Generic.List[string]]::new()
# ... $problems.Add("...") per issue ...
($problems -join [Environment]::NewLine) | Should -BeNullOrEmpty
```

**A test file that cannot be parsed never reports a failed test.** It produces a
failed *container*, so a gate that checks only `FailedCount` sees zero failures
and reports a broken suite as green. Check all three:

```powershell
$failures = $result.FailedCount + $result.FailedContainersCount + $result.FailedBlocksCount
```

Report containers and blocks separately from tests in the message, otherwise
"0 test(s) failed" reads as success rather than as a suite that never ran. Have
the runner exit non-zero, so a calling script or CI job fails with it.

**Do not gate on a check that can be skipped silently.** If a lint or test step
is conditional on a tool being installed, warn loudly when it is skipped —
otherwise an unverified build looks exactly like a verified one.

**`-ForEach` is evaluated at discovery time, before `BeforeAll` runs.** Anything
`BeforeAll` defines — variables, helper functions — does not exist yet. Define
fixtures in a function and call it from the test body, or use a plain loop.

**`Import-Module Pester` before touching `[PesterConfiguration]`** in a fresh
session, or the type does not resolve and the configuration silently becomes
`$null`.

**A test runner must be able to fail, and you must watch it do so.** Pester 5
and later only return a result object when `Run.PassThru` is `$true`, which is
not the default. Without it `Invoke-Pester` returns `$null`, every count on the
result is `$null`, the total reads as `0`, and the runner cheerfully reports a
failing suite as a pass. Set `PassThru`, treat a `$null` result as a failure
rather than a pass, and then prove the whole thing by running the runner against
a suite that is meant to fail and asserting a non-zero exit code. A gate that
has never been observed failing is not a gate.

Asserting only "exits non-zero" is weaker than it looks: a runner that exits
non-zero for *any* reason satisfies it. Also assert that the success case exits
zero, and assert on the message, or a runner broken in some other way passes
the test.

**Test behaviour, not implementation.** For `Write-Host` output, capture the
information stream: `(Get-Example 6>&1 | Out-String)`.

**Testing this module needs a running iTunes.** Every command in `Public/`
reaches the iTunes COM automation object, so an integration suite is not
hermetic: it needs iTunes installed, a library populated, and the machine's
media path to match. Write unit tests against `Private/` helpers with injected
data, and keep the COM-dependent commands to a smaller integration suite that can
be skipped loudly. A suite that silently passes because iTunes was not there is
worse than no suite — see the warning rule above.

**Make a linter a gate, not advice.** Run PSScriptAnalyzer in the test suite so
a violation fails the build.

**Lint Markdown with markdownlint-cli2, on the same terms.** See the
Documentation section above. A tool that is not installed must not turn the
check into a silent pass: report loudly that it was skipped, or the run looks
verified when it is not.

**Fix diagnostics on code you did not write opportunistically,** but only while
the count stays small. A single PSScriptAnalyzer warning in a function you are
already editing is a free fix. Thirty of them is a separate piece of work with
its own reviewable diff — do not bury a baseline change inside a feature.

**A gate needs a baseline before it needs a threshold.** `-Severity Error` is a
reasonable first gate. Raising it to warnings requires deciding what happens to
the existing ones: fix them, or record a count that must not increase. A
threshold nobody has agreed to is not a gate, and neither is one that has never
been seen to fail.

**Guard documentation with tests.** Because help is the source of truth, a test
should fail when a public function loses its help block, its `.SYNOPSIS`, or a
`.PARAMETER` entry. Keep an explicit, commented allow-list of parameters that are
deliberately undocumented, so a new undocumented parameter still fails.

### 1.9 Pitfalls worth knowing

- **Dynamic scoping leaks caller variables.** A function can read a variable it
  never declared, because it exists in the caller's scope. A helper called as
  `Build-Node -Item $dir` that then reads `$MaxDepth` from the function that
  called it will work, be invisible in its own signature, and break silently on
  refactor. Pass such values as explicit parameters.
- **An empty `PSModulePath` does not mean "no modules".** PowerShell reads
  `$env:PSModulePath = ''` as "use the defaults", so `Import-Module Pester`
  still succeeds. A test that clears it to simulate a missing module passes
  without ever reaching the branch it is meant to cover. Point it at a
  directory that does not exist instead, and assert the module really is gone.
- **A double quote inside a string passed to a native command is eaten.** To
  pass `PSModulePath = ""` to `powershell.exe -Command`, the argument parser
  consumes the quotes and the child sees a single `"`, producing a parse error
  that looks like a bug in the code under test. Build the child script as a
  file and pass it with `-File`; that also avoids deadlocks seen when changing
  `PSModulePath` through `-Command`.
- **`-eq` against an array filters instead of returning a boolean.**
  `@('a','b','c') -eq 'b'` returns a one-element array containing `b`, and any
  non-empty array is truthy, so `if ($array -eq 'x')` is true whenever *any*
  element matches. Use `-contains` / `-notcontains`, which read as the question
  you meant.
- **Nested `Where-Object` scripts both use `$_`.** Capture the outer value in a
  local before entering the inner block, or the pattern is tested against the
  wrong object.
- **`Get-ChildItem` returns `[DateTime]`, not strings,** for `LastWriteTime` and
  friends. String operations and `[datetime]` casts behave differently than
  expected.
- **Exact matching is rarely what a user wants from a filter.** `-notcontains`
  needs an exact, case-insensitive name and silently ignores wildcards, so
  `-Exclude '*.log'` does nothing. Prefer `-like` / `-notlike` for patterns.
- **A COM release-assignment looks like a no-op and is not.** `$track = $null`
  on an iTunes track drops a reference; the reliable form is
  `[System.Runtime.InteropServices.Marshal]::ReleaseComObject($track)`. Forgetting
  it leaks a handle per track, which shows up much later as iTunes refusing new
  automation calls rather than at the loop that caused it.
- **iTunes writes to stdout.** The COM automation interface can emit dialog and
  status text straight to the console, which will corrupt captured output in a
  test or a `ForEach-Object` pipeline. Do not assume every line on the pipeline
  came from your function.

## 2. This repository

Section 1 is portable and is meant to be copied into other repositories.
Section 2 is specific to PSiTunes: the layout, and the traps that only apply
here. The README covers the project for a reader; `Get-Help` covers the
commands. Neither repeats what is below.

### 2.1 Layout

```text
Public/         exported functions, one Verb-Noun function per file
Private/        internal helpers, camelCase, dot-sourced by the .psm1
Classes/        class definitions, dot-sourced by the .psm1 and by ScriptsToProcess
Scripts/        developer utilities and one-off reporting scripts; not the module
lib/            vendored TagLibSharp.dll, loaded via RequiredAssemblies
PSiTunes.psd1   manifest
PSiTunes.psm1   loader; dot-sources Classes/ then Private/ then Public/
```

Only `Public/` is the module. `Scripts/` is not exported and is not covered by
the module's contract, so do not treat the two as interchangeable.

**There is no `Tests/` directory yet.** Section 1.8 describes the target state,
not the current one. Do not claim a test suite exists, and do not report a green
run that never happened.

### 2.2 The module talks to iTunes over COM

Most of this module is a wrapper over the iTunes automation interface. The
consequences shape how the code is written and why it is awkward to test:

- **`Start-iTunes` connects to a running instance or creates one** via
  `New-Object -ComObject iTunes.Application`. It returns the application object,
  and it guards the `New-Object` with `ShouldProcess` — but `ShouldProcess`
  around a constructor that has the side effect of launching an application is
  a side effect the caller cannot preview. Be careful about what you wrap.
- **`Get-iTunesLibrary` returns the iTunes object, not a data snapshot.** It
  hands back `$iTunesApplication.LibraryPlaylist`, a live COM reference. Every
  consumer is coupled to the running application, and the object is not valid
  after iTunes exits.
- **Track and playlist collections are lazily evaluated COM objects.** A
  `foreach` over `$iTunesLibrary.Tracks` touches every track, which is slow on a
  large library and is not a no-op. Prefer `TrackCollection` filters pushed to
  iTunes where the API offers one, and say which you are doing.
- **`PSiTunes.psm1` has import-time side effects.** It dot-sources the folders,
  then sets `$GLOBAL:iTunesRoot` and `$GLOBAL:iTunesMediaPath`, then calls
  `Start-iTunes` and `Get-iTunesLibrary` at import. Importing the module starts
  iTunes. That is a real trap for tooling and for anyone who imports the module
  to read one function's help.

### 2.3 Traps specific to this repository

- **The `.psm1` dot-source order is load-bearing.** It walks `@($Classes,
  $PrivateFunctions, $PublicFunctions)`. `Private/` helpers are referenced by
  `Public/` functions, and the classes are referenced by both, so reordering the
  array breaks the module. Keep it, and if you add a fourth folder, put it before
  `Private/`.
- **`Classes/` is loaded twice.** The manifest's `ScriptsToProcess` lists the
  class scripts, and the `.psm1` dot-sources the same directory. Harmless
  today, but it means a class definition is executed on import and again during
  module load. Pick one mechanism and remove the other.
- **The manifest names a class file that does not exist.**
  `ScriptsToProcess` references `Classes\iTunesTrackData.class.ps1`, but the
  file on disk is `Classes\ITunesTrackData.class.ps1`. It resolves on Windows
  because the filesystem is case-insensitive, and fails on any case-sensitive
  filesystem — which is every Linux CI runner. Fix the casing.
- **`PSiTunes.psd1` is UTF-16 LE** (`FF FE`), and
  `Private/convertToCapitalizedWords.ps1` is UTF-16 BE (`FE FF`). Both violate
  1.1. The manifest is read as a module contract, so a BOM-less rewrite must be
  done with `UTF8Encoding($true)` and the byte-order mark must be verified
  afterwards — this is exactly the case the table in 1.1 exists for. Every other
  `.ps1` and the `.psm1` are currently BOM-less, which is the other half of the
  same problem.
- **The manifest uses wildcards for exports.**
  `FunctionsToExport = '*-*'`, `VariablesToExport = '*'`, and
  `AliasesToExport = '*'`. This violates 1.6. Tightening
  `VariablesToExport` is **not** the behaviour change an earlier version of this
  file claimed: the `.psm1` assigns with `$GLOBAL:`, which is true global scope
  rather than module scope, so those variables stay visible to callers no matter
  what `VariablesToExport` says. This was verified with a throwaway module
  exporting `'*'` and `@()` and reading the variable back from the caller; both
  returned it. `FunctionsToExport = '*-*'` did hide a real risk, though: it
  matches on shape, so a future private helper named `Verb-Noun` would be
  exported by accident. The private helpers are all camelCase today, so the
  wildcard happens to select the 23 public functions and nothing else.
- **The media paths come from iTunes now.** The `.psm1` reads the
  "Music Folder" key out of the library XML via `Get-iTunesMediaLocation`
  instead of assuming `D:\`. If that lookup fails it warns and falls back to
  `$FallbackMediaPath`, which is still the `D:\iTunes\iTunes Media` literal
  the module was written against — that is the one place a drive letter is
  still expected to be right. `Scripts/Merge-FilesToLibrary.ps1` has its own
  fallback for the same reason, and `Scripts/Get-TracksWithNoFile.ps1` has
  none: it errors rather than guessing. Both scripts import the module *after*
  their parameters are bound, so they resolve the path after the import, and
  both read the module's global through `$global:` into a differently named
  variable, because their own parameter of the same name shadows it.
- **`$SourcePath` in `Scripts/Merge-FilesToLibrary.ps1` is still a literal**
  (`D:\Music\Ripped`). That one is a source directory rather than an iTunes
  setting, so there is nothing in the library to derive it from. Change it on
  the command line.
- **Commands read the globals rather than declaring parameters.**
  `Set-iTunesTrackName` and `Set-iTunesFileLocations` read `$iTunesLibrary` from
  scope, and the latter reads `$global:iTunesLibrary` explicitly. This is the
  dynamic-scoping trap in 1.9, made concrete: a caller who has a different
  `$iTunesLibrary` in scope silently changes which library is modified. Pass the
  playlist in as a parameter, with the global as a fallback.
- **Every public function declares `[CmdletBinding()]` now.** `Get-iTunesLibrary`
  and `Get-iTunesSelectedTracks` were the last two without it; both were fixed
  in febefda. When counting this, count functions, not `ShouldProcess` call
  sites: a function with several `if ($PSCmdlet.ShouldProcess(...))` branches
  has several sites, which inflates the number and is how an earlier count of
  "22 of 24" was wrong. The real figures are 23 public functions, all with
  `CmdletBinding`, 15 of them with `SupportsShouldProcess`.
- **Every public function has comment-based help.** Added in 7b4de12: all 23
  have `.SYNOPSIS`, `.DESCRIPTION`, a `.PARAMETER` entry for every declared
  parameter, at least one `.EXAMPLE`, and `.NOTES` where a caveat is worth
  stating. There is no allow-list of undocumented parameters, because there are
  none; keep it that way, so a new parameter without help is a visible gap
  rather than a silent one.
- **`Get-Help Search-iTunesLibrary` needs iTunes running.** Its `$SearchType`
  parameter is typed `[ITPlaylistSearchField]`, an interop type that the iTunes
  COM object registers at runtime, so on a machine without iTunes
  `Get-Help` fails with "Unable to find type [ITPlaylistSearchField]" rather
  than showing help. Parsing the file is unaffected. A `[ValidateSet]` on the
  string values would remove the dependency at the cost of the type's
  discoverability; not done, because it changes the parameter's contract.
- **Two functions were outright broken and are now fixed** (509f92b).
  `Set-iTunesTrackRating` compared and wrote `Genre` while referencing an
  undeclared `$Genre`, so it could not set a rating at all; it now writes
  `Rating` and passes `-Tracks` to `Set-iTunesTrackData`, which the call had
  been omitting. `Get-iTunesLibraryGenres` read `$iTunes.LibraryPlaylist.Tracks`
  where the parameter is `$iTunesLibrary`, and `$iTunes` is never defined, so
  it returned only the hardcoded `"Compilations"`. Both threw under StrictMode.
  The lesson worth keeping: under `Set-StrictMode -Version 2` an undeclared
  variable is an error, so this class of bug is loud rather than silent — but
  only if a command actually runs. Reading the code is what found these.
- **`lib/TagLibSharp.dll` is a vendored binary** loaded by
  `RequiredAssemblies`, used by `Private/getDataFromTagLib.ps1` and
  `Private/convertFromTagLibProperties.ps1` for reading audio file tags. It is
  committed, so the PowerShell version it binds against is fixed by whatever
  .NET the machine has. If tag reads fail on a new OS, suspect the DLL before
  suspecting the parsing code.
- **`LicenseUri` still points at the old branch name.** The `PSData` URIs are
  `github.com/MisterSeajay/PSiTunes`, but `LicenseUri` ends in
  `/blob/master/LICENSE` and the default branch is now `main`, so that link 404s.
  Per 1.6 these URIs are shown to Gallery users, and a link that does not
  resolve is a broken promise. Change `master` to `main`. The `.LINK` block of
  `Private/convertToCapitalizedWords.ps1` and the `ReleaseNotes` wiki URL are
  branch-independent and are fine as they are.
- **The module manifest declares `PowerShellVersion = '5.0'`,** so treat Windows
  PowerShell 5.1 as the floor. Anything from PowerShell 7 is not available: no
  `Get-Verb -Name` (see the note in 1.2), no ternary, no `??`.
- **`Get-ChildItem` is called without `-File` in the `.psm1`** (`Get-ChildItem
  -Path $Folder *.ps1`). It works because the folders contain only files, but
  a subdirectory named `*.ps1` would be dot-sourced and fail. Add `-File`.
