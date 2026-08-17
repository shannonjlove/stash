# Koofr PARA layout (LoveCloud six-digit)

Koofr folders now use the same six-digit PARA coding as the LoveCloud manuals:

- [PARA-SYSTEM.md](https://github.com/shannonjlove/craft-repo/blob/main/PARA-SYSTEM.md)
- BookStack book 34, pages 50–51 (v10.3 / v10.3.1)

Pattern: `[PPPPPP]_[ROOT]__[surface]` for roots, `[PPPPPP]_[semantic]` for children.

This is the approved migration that v10.3 reserved: do not keep a competing unnumbered `@INBOX_koofr` tree.

## Roots

| Code | Name | Koofr surface | IDrive E2 projection on Koofr |
| ---: | --- | --- | --- |
| 010000 | INBOX | `010000_INBOX__koofr` | `010000_INBOX__idrive-e2` |
| 020000 | PROJECTS | `020000_PROJECTS__koofr` | `020000_PROJECTS__idrive-e2` |
| 030000 | AREAS | `030000_AREAS__koofr` | `030000_AREAS__idrive-e2` |
| 040000 | RESOURCES | `040000_RESOURCES__koofr` | `040000_RESOURCES__idrive-e2` |
| 050000 | ARCHIVES | `050000_ARCHIVES__koofr` | `050000_ARCHIVES__idrive-e2` |
| 060000 | PRIVATE-MEDIA | `060000_PRIVATE-MEDIA__koofr` | `060000_PRIVATE-MEDIA__idrive-e2` |
| 060010 | photos | (child of PRIVATE-MEDIA) | `060010_PHOTOS__idrive-e2` |
| 060020 | video-media | (child of PRIVATE-MEDIA) | `060020_VIDEO-MEDIA__idrive-e2` |
| 060030 | graphics | (child of PRIVATE-MEDIA) | `060030_GRAPHICS__idrive-e2` |
| 070000 | SYSTEM-AUTOMATION | `070000_SYSTEM-AUTOMATION__koofr` | — |
| 070010 | agent-data | (child) | `070010_AGENT-DATA__idrive-e2` |
| 070020 | assets | (child) | `070020_ASSETS__idrive-e2` |
| 070030 | stacks-backups | (child) | `070030_STACKS-BACKUPS__idrive-e2` |
| 080000 | APPLICATION-DATA | `080000_APPLICATION-DATA__koofr` | — |
| 080010 | n8n | (child) | `080010_N8N-BACKUPS__idrive-e2` |
| 080020 | bookstack | (child) | `080020_BOOKSTACK__idrive-e2` |
| 080030 | paperless | (child) | `080030_PAPERLESS__idrive-e2` |
| 090000 | QUARANTINE | `090000_QUARANTINE__koofr` | `090000_QUARANTINE__idrive-e2` |

Koofr product folders `My desktop sync`, `My documents`, `My pictures`, and `My videos` are unchanged.

## Stash library

NSFW media is class `060000`. The Stash library moved:

```text
Stash/media
  -> 060000_PRIVATE-MEDIA__koofr/Stash/media
```

Update rclone mounts / `KOOFR_PATH` to that path. SQLite, cache, blobs, and generated files stay on local disk.

## What this migration does not change

- IDrive E2 **bucket** names (S3). Only the Koofr folder projections of those buckets were renamed.
- Five-digit historical aliases such as `10001-web-projects`, `50003-01-raw-footage`, and unnumbered names (`uploads`, `raw-footage`). v10.3 keeps those as provenance; they must not drive new classifications.
- Hostinger / Oracle `/mnt/koofr` rclone **services**. Those units still mount the whole remote or an old prefix and need a separate reviewed Quadlet update to follow the new names.

## Apply / verify

```bash
cd koofr
# rclone.conf is gitignored; generate it from a Koofr app password
./apply-para-layout.sh --dry-run
./apply-para-layout.sh
./verify-para-layout.sh
```

`apply-para-layout.sh` is idempotent and uses rclone `DirMove` (server-side rename). It never runs `sync --delete`.

Machine-readable map: [para-codes.yaml](para-codes.yaml).
