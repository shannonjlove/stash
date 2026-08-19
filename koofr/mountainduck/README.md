# Mountain Duck — koofr2 and IDrive e2

Mount the LoveCloud **Koofr PARA tree** and **IDrive e2** buckets as Finder volumes on ShaJe'sMBA.

`koofr` remains the Hostinger/Oracle **native rclone** remote. **koofr2** is the Mac client: Mountain Duck over WebDAV (`https://app.koofr.net/dav/Koofr`). It is not a second Koofr product.

Suggested Finder mount names (Mountain Duck nickname = volume name):

| Nickname | Protocol | Local path (suggested) |
| --- | --- | --- |
| `Koofr2` | WebDAV | `/Users/shannonjlove/Koofr2` |
| `IDriveE2` | S3 path-style | `/Users/shannonjlove/IDriveE2` |
| `IDriveE2-Nexus` | S3 path-style | `/Users/shannonjlove/IDriveE2-Nexus` |

Use **Online** connect mode (on-demand). Smart Sync is optional and duplicates rclone cache if `/Users/shannonjlove/Koofr` is still mounted.

## Install on the Mac

1. Copy `profiles/*.cyberduckprofile` into Mountain Duck (double-click each file, or copy into the Profiles folder).
2. Copy `bookmarks/*.duck.example` to `*.duck` (the generator does this) and double-click, or copy into the Bookmarks folder.
3. Enter credentials when prompted. They go to **Keychain**. Do not paste passwords into committed `.duck` files.

macOS application-support folders (Mountain Duck 4/5):

```text
~/Library/Group Containers/G69SCX94XU.duck/Library/Application Support/duck/Profiles
~/Library/Group Containers/G69SCX94XU.duck/Library/Application Support/duck/Bookmarks
```

Docs: [Mountain Duck installation](https://docs.mountainduck.io/mountainduck/installation/), [connect modes](https://docs.mountainduck.io/mountainduck/connect/).

## Koofr (koofr2)

| Field | Value |
| --- | --- |
| Protocol | `davs` (WebDAV HTTPS) |
| Host | `app.koofr.net` |
| Port | `443` |
| Path | `/dav/Koofr` |
| Username | Koofr account email (`shannonjlove@mac.com`) |
| Password | Koofr **app password**, not the login password |

Create a dedicated app password named `mountainduck-koofr2` at [Koofr passwords](https://app.koofr.net/app/admin/preferences/password). Do not reuse the Hostinger or Oracle app password long-term.

After connect you should see the six-digit PARA roots (`010000_INBOX__koofr`, …). Stash media is:

```text
060000_PRIVATE-MEDIA__koofr/Stash/media
```

Optional extra bookmark: `koofr2-stash-media.duck.example` mounts that folder only.

If rclone still mounts `/Users/shannonjlove/Koofr`, keep that read-only and use `/Users/shannonjlove/Koofr2` for Mountain Duck so the two do not collide.

## IDrive e2

IDrive e2 needs **path-style** S3 (`s3.bucket.virtualhost.disable=true`). Official guide: [Mountain Duck + IDrive e2](https://www.idrive.com/s3-storage-e2/mountain-duck). There is no official `IDrive.cyberduckprofile`; these profiles combine that path-style setting with the LoveCloud region endpoints.

| Surface | Endpoint | Region | Bookmark |
| --- | --- | --- | --- |
| Virginia (primary data) | `p3h2.va.idrivee2-48.com` | `us-east-1` | `IDriveE2` |
| Oregon / nexus | `d8v7.or4.idrivee2-73.com` | `us-west-1` | `IDriveE2-Nexus` |

Username = Access Key ID, password = Secret Access Key. Keys are **region-specific**. Virginia keys do not work on Oregon.

S3 **bucket names were not renamed**. Mountain Duck `Path` must use the real bucket, for example `areas-idrive-e2`, not the Koofr PARA folder `030000_AREAS__idrive-e2`.

Virginia buckets (leave names as-is; `areas-idrive-e2` is large):

```text
inbox-idrive-e2
projects-idrive-e2
areas-idrive-e2
resources-idrive-e2
archives-idrive-e2
private-idrive-e2
shannon-photos-e2
video-media-e2
graphics-media-e2
agent-data-e2
assets-e2
stacks-backups-e2
n8n-backups-e2
bookstack-data-e2
paperless-docs-e2
quarantine-e2
```

The Koofr folders with `__idrive-e2` suffixes are **projections**, not the buckets themselves.

## Generator / verifier

```bash
cd koofr
cp mountainduck/env.example .env   # gitignored; fill secrets locally
./mountainduck/generate-bookmarks.sh
./mountainduck/verify-webdav.sh
```

`generate-bookmarks.sh` writes `mountainduck/generated/*.duck` (no passwords) and optionally a gitignored rclone WebDAV snippet. `verify-webdav.sh` lists PARA roots over WebDAV.

IDrive access keys are not in this repo. Fill them from 1Password or the e2 console before expecting the S3 bookmarks to connect.

## Do not

- Commit Keychain passwords, rclone `pass=` lines, or filled `.duck` files under `generated/`
- Bulk-rename IDrive S3 buckets
- Run `rclone sync --delete` against Koofr
- Point Stash `KOOFR_PATH` at the old `Stash/media` root
