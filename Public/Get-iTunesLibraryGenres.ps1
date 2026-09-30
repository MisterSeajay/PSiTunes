function Get-iTunesLibraryGenres {
    <#
    .SYNOPSIS
        Lists the genres used in the iTunes library.
    .DESCRIPTION
        Returns a sorted, de-duplicated list of the genres assigned to tracks in
        the library, always including "Compilations". Tracks marked as compilations
        are excluded from the scan, since a compilation''s own genre says nothing
        about the music on it.
    .PARAMETER iTunesLibrary
        The library to read. Defaults to the library of the running iTunes application.
    .EXAMPLE
        Get-iTunesLibraryGenres
    .EXAMPLE
        Get-iTunesLibraryGenres -iTunesLibrary (Get-iTunesLibrary)
    .NOTES
        "Compilations" is always the first entry, whether or not any track uses that genre.
    #>
  [CmdletBinding(SupportsShouldProcess)]
  param(
    [System.Object]$iTunesLibrary = $(Get-iTunesLibrary)
  )

  if(-not $iTunesLibrary){
    Write-Error "No Library object provided"
    return $null
  }

  # Build list of (non-blank) genres in the Library as an array. We assume that there will
  # always be a genre called "Compilations"
  $Genres = @()
  $Genres+= "Compilations"
  $iTunesLibrary.Tracks | ?{($_.Compilation -eq $false) -and ($_.Genre -ne $null)} `
    | Group-Object Genre | %{$Genres+= $_.Name}

  return $Genres
}
