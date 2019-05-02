function Get-iTunesLibraryGenres {
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
  $iTunes.LibraryPlaylist.Tracks | ?{($_.Compilation -eq $false) -and ($_.Genre -ne $null)} `
    | Group-Object Genre | %{$Genres+= $_.Name}
  
  return $Genres
}
