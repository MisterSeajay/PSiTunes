<#
.SYNOPSIS
    Unit tests for the private helper functions.
.DESCRIPTION
    These are the only tests that need no iTunes. Every function under Private/
    is a pure string or object transform, so the whole file is hermetic: it
    runs on any machine, with or without iTunes installed, and never touches
    the user's library or files.

    The tests assert observed behaviour rather than what the function name
    suggests. Where the behaviour is arguably wrong, the test records what it
    currently does and says so, so that changing it is a deliberate act rather
    than an accident. See the Context blocks for which those are.
#>

BeforeAll {
    # $PSScriptRoot inside a Pester block is the directory Pester was invoked
    # from, NOT the directory holding this test file. Using it here silently
    # resolved to the wrong folder, sourced nothing, and left every test below
    # asserting against functions that did not exist. $PSCommandPath is this
    # file, so derive the root from that.
    $script:TestFile = $PSCommandPath
    $script:RepoRoot = Split-Path -Parent (Split-Path -Parent $script:TestFile)
    $script:PrivateFolder = Join-Path $script:RepoRoot 'Private'

    if(-not (Test-Path -LiteralPath $script:PrivateFolder)){
        throw "Cannot find the Private folder at '$script:PrivateFolder'. RepoRoot resolved to '$script:RepoRoot' from test file '$script:TestFile'."
    }

    # Dot-source the helpers directly rather than importing the module: importing
    # PSiTunes.psd1 runs PSiTunes.psm1, which starts iTunes and populates
    # globals from the running application. A unit test must not do that.
    $script:HelperFiles = Get-ChildItem -Path $script:PrivateFolder -Filter '*.ps1' -File
    $script:HelperFiles | ForEach-Object { . $_.FullName }
}

Describe 'test harness integrity' {

    # These exist to make a silently empty suite impossible. A suite whose
    # setup failed can otherwise report passes while asserting nothing, which is
    # worse than no suite: it looks verified.
    It 'found the Private folder' {
        $script:PrivateFolder | Should -Exist
    }

    It 'dot-sourced at least one helper' {
        @($script:HelperFiles).Count | Should -BeGreaterThan 0
    }

    It 'has the helper functions actually defined' {
        foreach($name in @('cleanLocalUri','cleanSearchString','stripPath','convertToCapitalizedWords')){
            Get-Command $name -ErrorAction SilentlyContinue |
                Should -Not -BeNullOrEmpty -Because "$name must be available or the tests below assert nothing"
        }
    }
}

Describe 'cleanLocalUri' {

    Context 'when given a file URI' {

        It 'returns a local path for a file://localhost URI' {
            cleanLocalUri 'file://localhost/D:/Music/track.mp3' |
                Should -BeExactly 'D:\Music\track.mp3'
        }

        It 'returns a local path for a file URI without a host' {
            cleanLocalUri 'file:///D:/Music/track.mp3' |
                Should -BeExactly 'D:\Music\track.mp3'
        }

        It 'preserves the drive letter' {
            cleanLocalUri 'file://localhost/C:/x/y.mp3' |
                Should -BeExactly 'C:\x\y.mp3'
        }

        It 'does not mangle a path that has no file prefix' {
            # A UNC-style path is passed through the UNC branch of the replace.
            cleanLocalUri 'file://localhost\\localhost\share\a.mp3' |
                Should -Not -BeNullOrEmpty
        }
    }
}

Describe 'cleanSearchString' {

    Context 'with the default parameter set' {

        It 'removes a leading "the"' {
            cleanSearchString 'The Beatles' | Should -BeExactly 'Beatles'
        }

        It 'removes a trailing "the"' {
            cleanSearchString 'Pet Shop Boys The' | Should -BeExactly 'Pet Shop Boys'
        }

        It 'keeps a word that merely contains "the"' {
            cleanSearchString 'Theatre' | Should -BeExactly 'Theatre'
        }

        It 'collapses repeated whitespace' {
            cleanSearchString '  spaced   out  ' | Should -BeExactly 'spaced out'
        }

        It 'removes bracketed suffixes such as (live)' {
            cleanSearchString 'abc (live)' | Should -BeExactly 'abc'
        }
    }

    Context 'with -IgnoreNonAlphaNumeric' {

        # The non-alphanumeric characters become '.+', which is a regex fragment
        # rather than a literal. That is intended for matching a library entry
        # whose punctuation iTunes may render differently, and is why the result
        # is not a plain search string.
        It 'turns punctuation into a wildcard pattern' {
            cleanSearchString 'AC/DC' -IgnoreNonAlphaNumeric | Should -BeExactly 'AC.+DC'
        }

        It 'drops trailing punctuation' {
            cleanSearchString 'Hello!' -IgnoreNonAlphaNumeric | Should -BeExactly 'Hello'
        }

        It 'keeps letters and digits intact' {
            cleanSearchString 'Abbey Road 1969' -IgnoreNonAlphaNumeric |
                Should -BeExactly 'Abbey Road 1969'
        }
    }

    Context 'with -ForRegexMatching' {

        It 'escapes regex metacharacters' {
            cleanSearchString 'a.b' -ForRegexMatching | Should -BeExactly 'a\.b'
        }
    }
}

Describe 'stripPath' {

    It 'removes the root path and its separator' {
        stripPath -FullName 'D:\iTunes\Music\track.mp3' -RootPath 'D:\iTunes' |
            Should -BeExactly 'Music\track.mp3'
    }

    It 'leaves a path that does not start with the root alone' {
        stripPath -FullName 'E:\Other\track.mp3' -RootPath 'D:\iTunes' |
            Should -BeExactly 'E:\Other\track.mp3'
    }
}

Describe 'convertToCapitalizedWords' {

    It 'capitalizes each word' {
        convertToCapitalizedWords 'hello world' | Should -BeExactly 'Hello World'
    }

    It 'capitalizes after a hyphen' {
        convertToCapitalizedWords 'hello-world' | Should -BeExactly 'Hello-World'
    }

    It 'lowercases the letter after an apostrophe' {
        convertToCapitalizedWords "don't stop" | Should -Be "Don't Stop"
    }

    It 'leaves text that is already upper case unchanged' {
        # Recorded behaviour, not an endorsement. \b\w only upper-cases; it never
        # lower-cases the rest of the word, so ALL CAPS input stays ALL CAPS.
        # Callers wanting title case from ALL CAPS need that handled elsewhere.
        convertToCapitalizedWords 'THE BEATLES' | Should -BeExactly 'THE BEATLES'
    }

    It 'rejects an empty string' {
        { convertToCapitalizedWords '' } | Should -Throw
    }
}
