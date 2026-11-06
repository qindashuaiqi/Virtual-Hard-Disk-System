# Virtual Hard Disk System

**Install Windows as a native-boot VHDX — no USB stick, no BIOS changes, no WinPE.**

Point it at a `.wim` / `.esd` / `.iso`, choose a folder and a name, click *Start installation*.
Reboot and the Windows Boot Manager shows one extra entry: pick it to boot the new system, pick the other one to boot the original.
Remove it later with one click — it disappears like deleting a large file.

[中文说明](README.zh-CN.md) · [User guide](docs/USER-GUIDE.md) · [中文使用说明](docs/USER-GUIDE.zh-CN.md)

---

## Why

The usual way to get a second Windows (for testing, gaming, a clean work environment) costs a USB stick, a BIOS detour, a PE environment and the risk of wiping the wrong disk. This tool does it from inside the running system:

1. creates a dynamically expanding `.vhdx` on a partition you choose
2. creates **one** NTFS partition inside it (native boot requires exactly one) and applies the image with DISM
3. adds **one** boot entry (`device=vhd=[...]`) to the active BCD store through the BCD API
4. done — the original system, its boot entries and its files are untouched

The new system is a real disk to Windows: it takes drivers, software, Windows Update, and grows as you use it.

## Features

- **No USB, no BIOS, no PE.** Runs from the existing Windows installation.
- **Multiple systems.** Each one is an independent vhdx with its own name and its own boot menu entry.
- **Your name, your folder.** `D:\VHD\Gaming`, `E:\Systems\Clean` — anything on a local NTFS disk.
- **`.wim`, `.esd` and `.iso`.** An ISO is mounted automatically, the image inside is used, and the ISO is dismounted afterwards even on failure.
- **Multi-edition images.** `install.wim` with four Server editions? Pick one; the tool skips non-installable WinPE indexes.
- **Live progress with a watchdog.** DISM output goes to a file and the UI polls it; a genuine stall (no output, no disk growth for 10 minutes) aborts instead of hanging forever.
- **Reversible.** The BCD is exported before any change, and the uninstaller restores `timeout` / `displaybootmenu` to their original values.
- **Recovery toolkit.** Nine focused tools for the failure modes found on real hardware: no menu after install, wrong vhdx path in the entry, leftover drive letters, drivers missing in the new system, an empty GPU in Task Manager, half-finished installs.

## Changelog

### v1.33

- **Shared module + build-time inlining.** `Say` appeared verbatim in five scripts per language. It now lives once in `src/shared/en/Logging.ps1`; each script dot-sources it, and `src/build/inline_shared.py` splices the module body into the script while packaging. The shipped `.bat` is still one self-extracting file with no runtime dependency and no `Import-Module`.
- The build now fails loudly when a shared module is missing, when the dot-source points at the other language's folder, or when any dot-source survives inlining.
- `verify_en.py` / `verify_zh.py` additionally assert that every function defined in a shared module really ends up inside the decoded payload.
- No behaviour change: console text, prompts, exit codes and log output are identical to v1.32. This release only pays down duplication.
- All tools bumped to v1.33.

### v1.32

- **BCD non-ASCII read-back fixed.** `chcp 437` made `bcdedit` echo non-ASCII path characters as `?`, so a *correct* boot entry was reported as "wrong path". The check now tolerates `?` at non-ASCII positions and falls back to a `bcdedit /export` + UTF-16 lookup.
- **Provisional state file.** A `.boot.txt` marker is written *before* the boot entry step, so the repair tool can find the disk even when bcdedit is so broken that neither `/copy` nor `/create` yields a GUID.
- **Repair final gate.** Before deleting the ESP/MSR inside a vhdx, the disk's `Location` is re-checked against the target file — a same-named disk in another folder is no longer at risk.
- **Driver tool "not added" false positive.** English `pnputil` says *"Driver package added successfully"*; the old pattern never matched. Added the correct wording plus a driver-store fallback, and fixed a use-before-assign on the leaf name.
- **Launcher `.bat` forwards `%*`.** `Repair-Boot-Menu.bat -VhdPath "…"` now passes the argument through, including across the UAC elevation.
- All tools bumped to v1.32.

## Quick start

1. Download or clone this repository.
2. Pick a language: **`en/`** (English) or **`zh-CN/`** (中文).
3. Double-click `Start.bat` (English) or `开始.bat` (Chinese) and pick a number — or run `Install-System.bat` / `双击我-装系统.bat` directly.
4. Accept the UAC prompt, pick your image, choose a folder and a name, click *Start installation*.
5. Reboot and select the new name in the boot menu.

Requirements: Windows 10 1607+ / Windows 11 on x64, administrator rights, an NTFS partition on a **local fixed disk**, and free space ≥ configured size + 5GB.

Two host requirements worth reading twice:

- **English or Chinese Windows only.** The output of `bcdedit` / `diskpart` is parsed from text, in those two languages. The boot entry itself is written through their machine-readable options, but the read-back verification would misfire on a German or Japanese host.
- **The image must be x64.** An x86 or ARM64 image installs happily and then never boots; it is now rejected before anything is written.


> Windows images are not bundled — prepare a `.wim`, `.esd` or `.iso` yourself.

## Repository layout

```
.
├─ en/                 English release (double-click Start.bat)
│  ├─ Start.bat
│  ├─ Install-System.bat        self-extracting: base64 → PowerShell
│  ├─ Uninstall-System.bat
│  ├─ README.txt / USER-GUIDE.md
│  └─ tools/                   9 recovery tools
├─ zh-CN/              中文发行版（双击 开始.bat），结构同上
├─ docs/
│  ├─ USER-GUIDE.md            short English guide (the Chinese one is the complete manual)
│  └─ USER-GUIDE.zh-CN.md      完整中文说明（含每一版的排障复盘）
└─ src/
   ├─ en/              11 English PowerShell sources
   ├─ zh-CN/           11 Chinese PowerShell sources
   └─ build/           make_bat_en.py · make_bat_zh.py · verify_en.py · selftest_bat.py
```

The `.bat` files are **self-extracting wrappers**, not the logic: each one carries its PowerShell script as a base64 payload, decodes it into `%TEMP%` with `certutil`, verifies the byte count and re-launches elevated. That is why they work by double-click with no execution-policy fiddling — and why the sources live in `src/`.

## Build

```powershell
# rebuild the English bat files from src/en/*.ps1
python src/build/make_bat_en.py

# verify every bat: ASCII only, CRLF, payload byte-identical to its ps1
python src/build/verify_en.py

# actually run every bat (UAC prompt suppressed, GUI launch stubbed out)
python src/build/selftest_bat.py en
python src/build/selftest_bat.py zh-CN

# rebuild the Chinese bat files from src/zh-CN/*.ps1 (writes GBK, not ASCII)
python src/build/make_bat_zh.py
```

`make_bat_zh.py` expects the Chinese release layout (`急救工具\`); `make_bat_en.py` writes to `en\` and `en\tools\`.

`verify_en.py` only proves the payload is intact. It does **not** prove the batch
file runs — a byte-perfect launcher can still die on a cmd parsing quirk. So
`selftest_bat.py` executes each one, with the elevation branch short-circuited
(no UAC prompt during a test run) and the final PowerShell launch replaced by a
marker echo, then requires: exit code 0, marker printed, no
`unexpected at this time`, and the extracted payload files deleted.

That check exists because v1.x shipped with every English launcher dead:
`echo [ERROR] Self-extraction failed (expected ... bytes)` sat inside an
`if not ... ( ... )` block, the half-width `)` terminated the block early, and
cmd aborted with `. was unexpected at this time.` before printing anything. The
window closed instantly, no log was written, and the symptom looked exactly like
"the installer crashes". Never put a half-width `)` in an `echo` inside a
parenthesised block — the lint in `selftest_bat.py` now fails the build on it.

### Why a few Chinese tokens remain in the English sources

The English sources are translated line by line (2076 CJK lines → English), with 48 lines deliberately left as-is because they are **not display text**:

- `bcdedit` / `diskpart` / `pnputil` print localized output, so the matchers keep both spellings, e.g. `-match 'identifier|标识符'`, `-match 'completed successfully|操作成功完成'`;
- legacy compatibility: the uninstaller still recognises `新系统.vhdx` and the driver tool still scans `新系统驱动`, so systems installed by old Chinese builds are found;
- one input accept-list also takes `是` / `删除`.

Removing them would break behaviour on Chinese Windows. Display strings, dialogs, logs and comments are fully English.


## How it works, and the traps it avoids

```
.iso ──Mount-DiskImage──► sources\install.wim / install.esd
create .vhdx ──► attach ──► GPT + one NTFS partition ──► dism /Apply-Image
             ──► detach ──► bcdedit: device = vhd=[D:]\Folder\Name.vhdx
```

Four rules that were paid for the hard way (all documented in the guide):

1. **Never put an ESP inside the vhdx.** UEFI firmware only reads the ESP on the physical disk, so `bcdboot` reports success and the menu stays empty (v1.3).
2. **Never touch `\EFI\Microsoft\Boot\bcd` as a file.** The running system holds it and every write hits a sharing violation; use the BCD API (the active store) instead (v1.5).
3. **Dismount before writing `vhd=`.** With the disk still attached, bcdedit silently rewrites `vhd=[...]` into `partition=X:` and the entry never boots (v1.6).
4. **Write the full relative path.** `vhd=[D:]\maimai.vhdx` for a file in `D:\VirtualDisks\` is an entry that exists and cannot boot (v1.13).

## Safety

- The tool needs administrator rights: it creates partitions, applies images and edits the boot store.
- It **adds** boot entries, it never edits or deletes anyone else's; uninstalling restores the original `timeout` / `displaybootmenu`.
- The BCD is exported to `<folder>-logs\bcd-backup-<timestamp>.bcd` before every change.
- Since v1.31 it never deletes `C:\Boot` (a genuine Windows boot folder). `C:\EFI` is only removed when three conditions hold: created within 48 hours, contains nothing but `Microsoft\Boot`, and holds no `BCD` / `bootmgfw.efi`.
- Known limits: Legacy BIOS is refused, Secure Boot with a modified image fails with `0xc0000428`, and a vhdx on the same physical disk as the original system shares that disk's performance and failure modes.

## Tested on

UEFI x64 machines running Windows 10 (19041) and Windows 11 hosts, installing Windows 10 / Windows Server 2022 images from `.wim` and `.iso`, into both drive roots and subfolders. Legacy BIOS, RAID/Intel RST controllers and Secure Boot with modified images are **not** verified — see [the guide](docs/USER-GUIDE.md#verified--not-verified).

## License

MIT. See [LICENSE](LICENSE).
