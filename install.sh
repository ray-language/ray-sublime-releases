#!/bin/sh
# Installs ray-sublime on macOS or Linux from the latest published release.
#
#   curl -fsSL https://raw.githubusercontent.com/ray-language/ray-sublime-releases/main/install.sh | sh
#
# Options, as environment variables:
#   RAY_SUBLIME_VERSION=0.1.11   install that version instead of the latest
#   RAY_SUBLIME_DIR=/some/dir    where to put it (macOS: the folder that gets
#                                ray-sublime.app; Linux: the folder that gets
#                                the ray-sublime/ directory)
#
# The script reads update.json, the signed manifest the editor itself updates
# from, downloads the zip for this platform and checks its SHA-256 against the
# manifest before unpacking anything. It needs curl (or wget) and unzip.
set -eu

repo="https://github.com/ray-language/ray-sublime-releases"
version="${RAY_SUBLIME_VERSION:-}"

say() { printf '%s\n' "$*"; }
die() { printf 'install: %s\n' "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }

fetch() { # url -> stdout
    if have curl; then curl -fsSL "$1"
    elif have wget; then wget -qO- "$1"
    else die "curl or wget is needed to download the editor"
    fi
}

download() { # url file
    if have curl; then curl -fL --progress-bar -o "$2" "$1"
    else wget -q --show-progress -O "$2" "$1"
    fi
}

sha256() { # file -> hex
    if have sha256sum; then sha256sum "$1" | cut -d' ' -f1
    elif have shasum; then shasum -a 256 "$1" | cut -d' ' -f1
    else die "sha256sum or shasum is needed to verify the download"
    fi
}

have unzip || die "unzip is needed to unpack the editor"

case "$(uname -s)" in
    Darwin) os=macos ;;
    Linux) os=linux ;;
    *) die "unsupported system: $(uname -s). Windows users: install.ps1" ;;
esac
case "$(uname -m)" in
    arm64|aarch64) arch=aarch64 ;;
    x86_64|amd64) arch=x86_64 ;;
    *) die "unsupported architecture: $(uname -m)" ;;
esac
key="$os-$arch"

# The manifest: the latest one, or the one of the version asked for. Older
# releases were tagged with a leading v, newer ones without; both are tried.
if [ -z "$version" ]; then
    manifest=$(fetch "$repo/releases/latest/download/update.json") || die "could not read the release manifest"
else
    manifest=$(fetch "$repo/releases/download/$version/update.json" 2>/dev/null) \
        || manifest=$(fetch "$repo/releases/download/v$version/update.json" 2>/dev/null) \
        || die "no release $version"
fi

entry=$(printf '%s' "$manifest" | tr -d '\n' | grep -o "\"$key\":{[^}]*}") || die "no build for $key in this release"
url=$(printf '%s' "$entry" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
sum=$(printf '%s' "$entry" | grep -o '"sha256":"[^"]*"' | cut -d'"' -f4)
version=$(printf '%s' "$manifest" | grep -o '"version":"[^"]*"' | head -1 | cut -d'"' -f4)
[ -n "$url" ] && [ -n "$sum" ] || die "the manifest has no url or checksum for $key"

tmp=$(mktemp -d "${TMPDIR:-/tmp}/ray-sublime.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
zip="$tmp/ray-sublime.zip"

say "ray-sublime $version for $key"
download "$url" "$zip" || die "download failed: $url"
got=$(sha256 "$zip")
[ "$got" = "$sum" ] || die "checksum mismatch: expected $sum, got $got"
say "checksum ok"

if [ "$os" = macos ]; then
    dest="${RAY_SUBLIME_DIR:-}"
    if [ -z "$dest" ]; then
        if [ -w /Applications ]; then dest=/Applications; else dest="$HOME/Applications"; fi
    fi
    mkdir -p "$dest"
    unzip -q -o "$zip" -d "$tmp/unpacked"
    rm -rf "$dest/ray-sublime.app"
    mv "$tmp/unpacked/ray-sublime.app" "$dest/ray-sublime.app"
    say "installed: $dest/ray-sublime.app"
    say "open it from Launchpad, or: open -a \"$dest/ray-sublime.app\""
    say "for a 'ray-sublime' command in the terminal: ray-sublime > Install Command Line Tool…"
else
    dest="${RAY_SUBLIME_DIR:-$HOME/.local/opt}"
    mkdir -p "$dest"
    unzip -q -o "$zip" -d "$tmp/unpacked"
    rm -rf "$dest/ray-sublime"
    mv "$tmp/unpacked/ray-sublime" "$dest/ray-sublime"
    # The bundle's own installer writes the desktop entry for this user.
    sh "$dest/ray-sublime/install.sh"
    mkdir -p "$HOME/.local/bin"
    ln -sf "$dest/ray-sublime/ray-sublime" "$HOME/.local/bin/ray-sublime"
    say "installed: $dest/ray-sublime"
    say "command: $HOME/.local/bin/ray-sublime (make sure ~/.local/bin is in your PATH)"
    case ":${PATH}:" in
        *":$HOME/.local/bin:"*) ;;
        *) say "  e.g. export PATH=\"\$HOME/.local/bin:\$PATH\" in your shell profile" ;;
    esac
fi
