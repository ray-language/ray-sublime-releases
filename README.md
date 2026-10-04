# ray-sublime releases

The published builds of [ray-sublime](https://raylang.dev), a code editor
written in raylang. The source lives in a private repository; this one holds
only what the editor downloads to update itself.

Each release carries:

- `ray-sublime-<version>-<platform>-<arch>.zip`, the app bundle for one platform;
- `update.json`, the manifest naming the newest version and each platform's zip
  with its size and SHA-256;
- `update.json.sig`, the Ed25519 signature of the manifest.

The editor reads `releases/latest/download/update.json` from here. It trusts the
manifest only when it is signed with the key whose public half is baked into
the app, and it checks every zip against the manifest before installing it, so
a copy of these files hosted anywhere else is just as safe to use.

Pre-releases are never served as the latest version.
