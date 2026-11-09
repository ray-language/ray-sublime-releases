# Installs ray-sublime on Windows from the latest published release.
#
#   irm https://raw.githubusercontent.com/ray-language/ray-sublime-releases/main/install.ps1 | iex
#
# Options, as environment variables set before running it:
#   $env:RAY_SUBLIME_VERSION = '0.1.11'      install that version instead of the latest
#   $env:RAY_SUBLIME_DIR = 'D:\Tools'        where to put the ray-sublime folder
#                                            (default: %LOCALAPPDATA%\Programs)
#
# The script reads update.json, the signed manifest the editor itself updates
# from, downloads the zip for this machine and checks its SHA-256 against the
# manifest before unpacking anything.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'https://github.com/ray-language/ray-sublime-releases'
$version = $env:RAY_SUBLIME_VERSION

$arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'x86_64' }
    'ARM64' { 'aarch64' }
    default { throw "unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
}
$key = "windows-$arch"

# The manifest: the latest one, or the one of the version asked for. Older
# releases were tagged with a leading v, newer ones without; both are tried.
if (-not $version) {
    $manifest = Invoke-RestMethod "$repo/releases/latest/download/update.json"
} else {
    try { $manifest = Invoke-RestMethod "$repo/releases/download/$version/update.json" }
    catch { $manifest = Invoke-RestMethod "$repo/releases/download/v$version/update.json" }
}
$version = $manifest.version
$entry = $manifest.artifacts.$key
if (-not $entry) { throw "no build for $key in release $version" }

$tmp = Join-Path ([IO.Path]::GetTempPath()) ("ray-sublime-" + [IO.Path]::GetRandomFileName())
New-Item -ItemType Directory -Force -Path $tmp | Out-Null
try {
    $zip = Join-Path $tmp 'ray-sublime.zip'
    Write-Host "ray-sublime $version for $key"
    Invoke-WebRequest -Uri $entry.url -OutFile $zip
    $got = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
    if ($got -ne $entry.sha256.ToLower()) { throw "checksum mismatch: expected $($entry.sha256), got $got" }
    Write-Host 'checksum ok'

    $base = if ($env:RAY_SUBLIME_DIR) { $env:RAY_SUBLIME_DIR } else { Join-Path $env:LOCALAPPDATA 'Programs' }
    New-Item -ItemType Directory -Force -Path $base | Out-Null
    $dest = Join-Path $base 'ray-sublime'
    $unpacked = Join-Path $tmp 'unpacked'
    Expand-Archive -LiteralPath $zip -DestinationPath $unpacked -Force
    if (Test-Path $dest) { Remove-Item -LiteralPath $dest -Recurse -Force }
    Move-Item -LiteralPath (Join-Path $unpacked 'ray-sublime') $dest

    # The bundle's own installer writes the Start Menu shortcut for this user.
    & (Join-Path $dest 'install.ps1')

    # The folder on the user's PATH, so `ray-sublime` works in a new terminal.
    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (($userPath -split ';') -contains $dest)) {
        [Environment]::SetEnvironmentVariable('Path', (($userPath, $dest) -join ';').Trim(';'), 'User')
        Write-Host "added to the user PATH: $dest (open a new terminal to use it)"
    }
    Write-Host "installed: $dest\ray-sublime.exe"
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
