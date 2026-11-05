# Virtual Hard Disk System — User Guide

## What this is

A tool that installs Windows **without a USB stick, without entering the BIOS and without WinPE**.

Double-click it, point it at a Windows image, and it installs that image as an **independent virtual hard disk system**.
After a reboot the boot menu shows one extra entry (the name you chose) — pick it to boot the new system, pick the other one to boot the original.

**Your existing system is not modified.** The new system is, physically, a single `.vhdx` file in a folder.
To get rid of it, run the uninstaller: it disappears as cleanly as deleting a large file.

> The main scripts need Windows 10 (10240 or later), 64-bit, and administrator rights.
> The UI is a Windows Forms GUI; the repair tools are console windows.

### Several systems, any name, any folder (since v1.11)

Older versions installed exactly one system and hard-coded the file name `NewSystemDisk.vhdx`, failing as soon as that file existed. Now:

- **You name it**: step 3 asks for a name (ASCII or your own language). The name is what the boot menu shows and what the `.vhdx` file is called. Name it `GamingSystem` and you get `GamingSystem.vhdx` and a menu entry `GamingSystem`.
- **Install as many as you like**: after one finishes, close the window, open it again and use a different name. Every system is its own vhdx, independent of the others, each with its own menu entry.
- **Choose the folder freely**: step 2 lets you click a drive button to fill in the drive root, or type/browse any folder (`D:\VHD`, `E:\Systems\Gaming`). The program does not create missing folders — create them first, or use **Browse → New folder**.
- **Name clashes get a number**: if `Gaming.vhdx` already exists in that folder, the new one becomes `Gaming-2.vhdx`. The menu text stays `Gaming`; rename it if you want the menu to differ too.

Allowed names: the illegal characters `\ / : * ? " < > |` are stripped automatically, emoji are rejected with a clear message, and the limit is 48 characters. Reserved names such as `CON` and `PRN` become `CON-`.

Storage folder rules (all checked in the UI, so nothing fails halfway through):

| Requirement | Why |
|---|---|
| Must be an **NTFS** partition | exFAT/FAT32 cannot host the sparse file a vhdx needs |
| Must be a **local fixed disk** | a USB disk, external drive or network share may not be available at boot time, and the system would not start |
| Must not be inside `Windows` / `Program Files` / `Program Files (x86)` / `ProgramData` / `Users` | restricted permissions, and cleanup tools like to touch those |
| Free space ≥ configured size + 5GB | headroom so the disk cannot fill up |

### Which image formats are supported?

All three, just pick the file:

| Format | Description | Example |
|---|---|---|
| `.wim` | The most common. Exported by Dism++, or `sources\install.wim` from an original disc | `install.wim` |
| `.esd` | The compressed variant found inside official Microsoft ISOs; DISM supports it natively | `install.esd` |
| `.iso` | **A whole Windows installation disc image**; the tool mounts it and takes the image out of it | `Win10_22H2.iso` |

With an `.iso` the tool mounts it in the background (an extra optical drive letter appears) and dismounts it when the install ends — no manual *Mount* step.

> Index 1 of an official image is sometimes "Windows PE" or "Windows Setup" rather than a real system.
> The tool skips those automatically and selects the first index that can actually be installed.

### Is the virtual disk a normal disk?

Yes. To you it is an ordinary hard disk:

- it stores files, runs installers, takes drivers and Windows Update
- its size is the GB number you configured (100GB gives you a 100GB C: drive)
- **it grows on demand**: initially only a few dozen MB, growing as you use it, never reserving the full 100GB up front

The only difference is that its "platter" is that `.vhdx` file. Therefore:

- the vhdx cannot be deleted **from inside the new system** (it is in use) — delete it from the original system
- to move it to another PC, copy the vhdx and register the boot entry again there
- performance is slightly below a physical disk (one more filesystem layer); for office work and installing software you will not notice

---

## File layout

### Directory structure (reorganized since the 1.200 line)

```
<repo>/
├─ en/                      ← English release, double-click Start.bat
│  ├─ Start.bat             ← the only file you normally need: a numbered menu
│  ├─ Install-System.bat
│  ├─ Uninstall-System.bat
│  ├─ README.txt
│  ├─ USER-GUIDE.md
│  └─ tools/                ← 9 recovery tools, all reachable from the menu
├─ zh-CN/                   ← Chinese release, same structure (开始.bat)
├─ docs/
│  ├─ USER-GUIDE.md         ← this file
│  └─ USER-GUIDE.zh-CN.md   ← the original Chinese guide, incl. version postmortems
└─ src/
   ├─ en/                   ← 11 English PowerShell sources
   ├─ zh-CN/                ← 11 Chinese PowerShell sources
   └─ build/                ← make_bat_en.py, make_bat_zh.py, verify_en.py
```

**Most of the time you only need `Start.bat`.** It lists every function; type a number and press Enter.
Each tool returns to the menu when it finishes, so you never re-open files by hand.

| Function | Entry point | When to use it |
|---|---|---|
| Install a system | `Install-System.bat` | Install an independent virtual system. Several are allowed, name and folder are yours, the existing system is untouched |
| Uninstall a system | `Uninstall-System.bat` | Delete one virtual system by name; the others are unaffected |
| Diagnose and install drivers | `tools/Diagnose-And-Install-Drivers.bat` | **Run inside the virtual system.** Devices still show a warning sign; matches drivers by hardware ID |
| GPU check-up | `tools/Clean-Ghost-GPU.bat` | **Run inside the virtual system.** An extra empty GPU in Task Manager (the real culprit is a virtual display), or you want ghost records cleaned |
| Inject all drivers | `tools/Inject-All-Drivers.bat` | Device Manager is full of unknown devices; moves 160+ driver packages in one batch (virtual display drivers are excluded so the new system does not gain an empty GPU) |
| Inject network drivers | `tools/Inject-Network-Drivers.bat` | Only the network is missing; moves network-class drivers only (including in-box packages since v1.2) |
| Fix boot entry target | `tools/Fix-Boot-Entry-Device.bat` | The menu lists the entry but selecting it errors out / file not found. Verifies and corrects the vhdx path |
| Repair boot menu | `tools/Repair-Boot-Menu.bat` | No menu entry after a reboot; registers it without reinstalling. **Finds the vhdx under any name in any folder** (since v1.4) |
| Clean install residue | `tools/Clean-Install-Residue.bat` | The install hung or the window was closed early: kills dism, dismounts disks, removes this toolkit's half-built vhdx (custom names recognised, other people's vhdx untouched by default) |
| Clean leftover drive letter | `tools/Clean-Esp-DriveLetter.bat` | An extra `S:` style drive letter appears |
| Restore boot menu | `tools/Restore-Boot-Menu.bat` | The boot menu still pops up after uninstalling |

**When you share this with somebody, package the whole `en` folder** — `Start.bat` calls the tools in `tools\` by relative path, so copying only the root files makes the menu report "cannot find".
Windows images (`.wim` / `.esd` / `.iso`) are not included; they are 20GB-class files.

> **Think twice about "Inject all drivers" first.** It pours 160+ driver packages (GPU included) into the virtual disk at once.
> Device Manager ends up clean, but the first PnP enumeration in the new system becomes noticeably slower (minutes on real hardware),
> and an incompatible driver can blue-screen the new system outright — and a blue screen there is hard to recover from, because it is a vhdx.
>
> The safe order is: **inject network drivers first** (network class only, enough to download the rest) →
> boot the new system, confirm network and clean shutdown → then come back for the full injection.
> A virtual disk can always be reinstalled in 20 minutes; do not go all-in on the first try.

---

## How to use it

### Step 1: prepare a Windows image

You need a `.wim`, `.esd` or `.iso`. The tool searches automatically in:

- the program folder (two levels down included)
- its parent folder
- `Downloads` and `Desktop`
- the root of every local disk

If nothing is found, click **Browse...**, or drag the image file onto the window.

> An `.iso` is fine — no need to extract it; the tool mounts it and looks for `sources\install.wim`
> or `sources\install.esd` inside. Third-party trimmed ISOs with a different layout are searched recursively.

### Step 2: choose the storage folder

The UI shows an **editable path box**, a row of drive buttons (one click fills in that drive's root) and a **Browse...** button for any folder.

Hard requirements (violations are explained immediately in the red line below the box):

- **NTFS**
- **local fixed disk** (no USB, external, network or optical drive)
- not inside `Windows` / `Program Files` / `ProgramData` / `Users`
- free space ≥ configured size + 5GB

Before v1.11 you picked a drive letter from a dropdown and the vhdx had to sit in the drive root;
now `D:\VHD` or `E:\Systems\Gaming` are fine (the folder must exist).

**No partition is formatted, no existing file is touched.** The new system is one `.vhdx` file in that folder.

The disk size defaults to the unpacked image size × 1.3 and can be adjusted. It is a **ceiling**, not an allocation — VHDX grows on demand.

### Step 3: name the system

One name is used for two things:

1. the **vhdx file name** — `<name>.vhdx`
2. the **text in the boot menu** — the line you select after rebooting

Two small buttons next to the box:

- **Use edition name** — fill in the image's edition name (e.g. `Windows 10 Pro`)
- **Add number** — append `-2`, `-3` to install the same image several times

The line below the box previews the resulting file name, folder and whether a number will be appended.
Illegal characters are stripped, emoji are rejected, the limit is 48 characters, and reserved names become `CON-`.

The panel below lists the virtual systems already installed on this machine, so you do not repeat a name.

### Step 4: click "Start installation"

A confirmation dialog lists the system name / image / location / size. After confirming:

| Stage | Typical duration | Notes |
|---|---|---|
| Create the virtual disk | seconds | |
| Partition and format | seconds | |
| **Restore system files** | **10–40 minutes** | the slow step, with a live percentage |
| Configure the boot menu | seconds | |

**Do not power off or hibernate during this.** You can use the machine, but keep it awake.

When it finishes you are asked whether to reboot now.

### Step 5: reboot and select the new system

The Windows Boot Manager appears.

- pick **the name you chose** → the new system
- pick the other entry (or wait) → the original system

The menu waits 10 seconds by default. Tap an **arrow key** during boot to stop the countdown.

The first boot of the new system takes a few minutes of initialization (spinning, preparing devices) — that is normal.

> **No menu at all, it booted straight into the original system?**
> Run `tools/Repair-Boot-Menu.bat`: it registers the missing entry in about 30 seconds, **no reinstall needed**.
>
> **The name is in the menu but selecting it fails (0xc000000f / file not found)?**
> Run `tools/Fix-Boot-Entry-Device.bat`: it corrects the wrong path inside the menu entry.
> Versions before v1.13 hit this whenever the vhdx lived in a subfolder such as `D:\VirtualDisks\`.

---

## After installing

### What the new system can do

It is a complete Windows installation. Windows installs most drivers itself, but keep these in mind:

**1. The new system cannot see the original system's files**
It is independent; the original C: is just another disk to it. To copy data, open *This PC* in the new system and look for it (the letter may have changed).

**2. Never format a disk you do not recognise from inside the new system**
Especially the partition holding your `<name>.vhdx` — that file is the new system's own shell; delete it and the system is gone.

**3. If the new system will not boot (0x7B / INACCESSIBLE_BOOT_DEVICE)**
The storage driver in the image does not match this machine:
- boot the original system (it is still fine)
- run the uninstaller and remove the new system
- that image is not suitable for this machine

> Note: the boot files are written with `/f UEFI`; the in-box storahci / stornvme / iaStorAVC drivers cover
> most machines. If the target runs RAID mode (Intel RST) or an unusual storage controller, switch SATA mode to AHCI
> in the BIOS, or inject the driver into the image beforehand.

### Uninstalling a system

Run `Uninstall-System.bat` (**from the original system**):

1. it scans for every installed virtual system (`*.vhdx` in the root and first-level subfolders of each fixed NTFS drive) and lists **system name + used space + file path**
2. select the one to delete and click **Delete the selected system**
3. it deletes the virtual disk file and removes the matching boot menu entry

With several systems installed there are several rows; **deleting one affects only that one**.
The original system is untouched and the boot menu returns to its previous state.

The menu entry is cleaned in three layers:

- **Delete by record**: at install time a `<name>.boot.txt` is written next to the vhdx, holding the boot entry GUID and the pre-install `timeout` / `displaybootmenu`. The uninstaller deletes by that GUID first.
- **Scan fallback**: if the state file is gone, it scans `bcdedit /enum osloader /v` and matches the **full device path** (`vhd=[D:]\folder\name.vhdx`) exactly; then falls back to "same drive letter + same file name"; only then to the file name alone (with an explicit warning that a same-named system on another drive may be hit).
- **Restore the menu switches**: `timeout` and `displaybootmenu` are restored to their pre-install values. If `displaybootmenu` never existed, `bcdedit /deletevalue` restores "not set" — a single-system machine still boots straight in, and a multi-boot machine keeps its menu.

If something is still left over, run `tools/Restore-Boot-Menu.bat` once.

> Since v1.6 there is a safety gate: **running the uninstaller inside the new system is refused** (the system drive is checked for the `File Backed Virtual` bus type).
> Deleting from there would only edit that system's own boot configuration while the menu entry remains, which looks like a failed uninstall.

---

## Notes on ISO / ESD

### How an ISO is handled

Once you pick an `.iso`, at the start of the installation the tool:

1. mounts it with the built-in `Mount-DiskImage`, which yields an optical drive letter
2. looks for `\sources\install.wim`, then `\sources\install.esd` (and finally searches recursively for `install.*`, which covers third-party trimmed media)
3. installs from the file it found
4. **always dismounts the ISO afterwards, on success and on failure**, leaving no stray drive letter

So the ISO **must not be moved, renamed or deleted while the installation runs**.

### Which ISOs work

- official Microsoft Windows 10 / 11 installation ISOs — yes
- third-party trimmed builds and Ghost recovery discs — only if the internal layout is standard
  - containing `sources\install.wim` or `install.esd`: yes
  - containing only `.gho` / split `.esd` fragments, or a `.wim` in the root: **no**
- non-Windows media (Linux, PE tool discs): no

### Index selection

One image may hold several editions (Home, Pro, Education...). The tool defaults to **index 1**, but if index 1 is "Windows PE" or "Windows Setup" — something that cannot be installed as a system — it jumps to the first installable index.

To force a specific edition, pass `-ImageIndex` to `Invoke-Install` in the source (or pick the edition in the UI since v1.17).

### ESD vs WIM

An `.esd` is a WIM with stronger compression. For you there is no difference — same selection, same install, just slightly more CPU during extraction.

---

## FAQ

**Q: Double-clicking flashes a window and nothing happens.**
Self-extraction or elevation failed. Right-click `Install-System.bat` → *Run as administrator*. If it still fails, read the log: `%TEMP%\VirtualHardDiskSystem-YYYYMMDD.log`.

**Q: "No sources\install.wim or install.esd inside the ISO".**
That ISO is not a standard Windows installation disc. Use another image, or extract its `.wim` and pick that file directly.

**Q: After installing from an ISO an optical drive letter stays mounted.**
It should be dismounted automatically. If one lingers, right-click the drive in *This PC* → *Eject*.

**Q: The image file is not found.**
The tool only scans its own folder (two levels down), the parent, Downloads, Desktop and drive roots. If your image lives deeper, click **Browse...**.

**Q: It says administrator rights are required but nothing happens when I agree.**
Right-click `Install-System.bat` and choose *Run as administrator*.

**Q: "Self-extraction failed".**
1. the file may be an incomplete copy — copy it again
2. antivirus blocked `certutil` — disable it temporarily and retry
3. check that `%TEMP%` is writable

**Q: The progress bar is not moving.**
DISM pauses for tens of seconds while unpacking large blocks; that is normal. Only 10 minutes without any movement is a problem.
Open Task Manager and check whether `dism.exe` is still using CPU or disk.

**Q: It finished, but the boot menu has no new entry.**
1. boot the original system and look for `<your name>.vhdx` (if it exists, the system files are installed and only the entry is missing)
2. **run `tools/Fix-Boot-Entry-Device.bat`** — it checks the menu and adds the entry back
3. if that fails, `tools/Repair-Boot-Menu.bat` rebuilds an entry
4. to check by hand: in an administrator PowerShell run `bcdedit /enum osloader` and look for `device  vhd=[X:]\folder\<your name>.vhdx`
5. read the logs: `%TEMP%\VirtualHardDiskSystem-*.log`
6. check `bcdedit /enum {bootmgr}` for `timeout` — with `0` the default system boots straight in and no menu appears (the repair tool sets 10 seconds)

**Q: The name is in the menu but selecting it gives 0xc000000f / file not found.**
The entry points at the wrong vhdx path. Before v1.13, installing into a subfolder wrote only the **file name** into the entry and dropped the folder, e.g. `vhd=[D:]\maimai.vhdx` for a file at `D:\VirtualDisks\maimai.vhdx`.

Fix: run `tools/Fix-Boot-Entry-Device.bat` — seconds, no reinstall. To inspect, run `bcdedit /enum osloader` and compare the `device` line with the real file location.

**Q: Can I install to a USB drive?**
No (refused explicitly since v1.11). The vhd must be readable by the firmware/boot manager at boot time, and USB, external and network drives may not be present or identified — the whole system would fail to start. Local fixed NTFS disks only.

**Q: Can I install several systems?**
Yes, supported natively since v1.11:

1. install the first one, close the window, open it again
2. use a different name in step 3
3. the same folder or a different one, both fine
4. after rebooting the menu has two entries, each booting its own system

Every system is an independent vhdx. A name clash in the same folder becomes `<name>-2.vhdx`, so nothing is overwritten.
The uninstaller lists them by name and deletes only the selected one.

**Q: Can it install into a subfolder such as `D:\VHD\Win11`?**
Yes. Type any existing folder in the path box or use **Browse...**. Requirements: NTFS on a local fixed disk, outside `Windows` / `Program Files` / `ProgramData` / `Users`.

**Q: How much space does a new system take?**
A few dozen MB at first (dynamic VHDX), growing with use, up to the configured size. When it fills up the new system reports low disk space and you would have to extend it (mount the vhdx, `diskpart extend`) — an advanced operation.

**Q: "The expression after '&' in a pipeline element produced an invalid object" (v1.0, fixed).**
Root cause: the script block returned by `Guard` as `return { & $Body ... }` resolves `$Body` **when it executes**, long after the function scope is gone, so `$Body` is `$null`. It must be captured with `.GetNewClosure()`:

```powershell
$handler = { param($sender, $e) ... & $Body ... }
return $handler.GetNewClosure()
```

**PowerShell script blocks bind late by default; `return { ... }` does not carry the current scope's variables.**

**Q: "Cannot convert 'DefaultButton1' to 'MessageBoxDefaultButton'" (v1.1, fixed).**
`MessageBoxDefaultButton` has no `DefaultButton1`; the correct members are `Button1` / `Button2` / `Button3`.
A string passes the parser (conversion happens at runtime) and only explodes when the dialog opens.
The fix wraps every `MessageBox.Show` in one strongly typed helper:

```powershell
function Show-Box {
    param(
        [string]$Text,
        [string]$Caption = 'Notice',
        [System.Windows.Forms.MessageBoxButtons]$Buttons = [System.Windows.Forms.MessageBoxButtons]::OK,
        [System.Windows.Forms.MessageBoxIcon]$Icon = [System.Windows.Forms.MessageBoxIcon]::Information,
        [System.Windows.Forms.MessageBoxDefaultButton]$Default = [System.Windows.Forms.MessageBoxDefaultButton]::Button1
    )
    return [System.Windows.Forms.MessageBox]::Show($Text, $Caption, $Buttons, $Icon, $Default)
}
```

**Second trap found on the way**: `GetNewClosure()` captures **variables**, not **function definitions**. The closure returned by `Guard` runs in a new session state where even the script-level `function Show-Box` does not resolve (measured: `Get-Command Show-Box` returns `$null` inside the closure), so the error path crashed again. Hoist the function body into a variable first:

```powershell
$boxFn = (Get-Item function:Show-Box).ScriptBlock   # captured with the closure
& $boxFn -Text $msg -Caption 'Operation failed' -Buttons ... -Icon ...
```

**Q: "Error while formatting the string: the index must be greater than or equal to zero" (v1.0, fixed).**
```powershell
# wrong: method arguments split on commas, -f only gets $stamp while the format string has 3 placeholders
$log.AppendText('[{0}] {1}{2}' -f $stamp, $m, [char]13 + [char]10)

# right: build the whole line first
$line = '[' + $stamp + '] ' + $m + [char]13 + [char]10
$log.AppendText($line)
```
**`-f` in command position consumes the whole comma list; inside a method call it does not.**

---

## How it works (for the curious)

```
0. (.iso only) Mount-DiskImage     mount the ISO, take sources\install.wim or install.esd
1. New-VHD or diskpart             create a dynamically expanding .vhdx on the current system
2. Mount-VHD or attach vdisk       attach it as a virtual disk (like plugging in a new drive)
3. diskpart                        create a GPT + **one** NTFS primary partition (no ESP)
4. dism /Apply-Image               apply the image to that partition (WinPE-style indexes skipped)
5. bcdedit                         add one entry to the BCD on the **physical ESP**:
                                     device   = vhd=[D:]\Folder\Name.vhdx
                                     osdevice = vhd=[D:]\Folder\Name.vhdx
                                     path     = \Windows\system32\winload.efi
6. Dismount-VHD / detach vdisk     detach
7. (.iso only) Dismount-DiskImage  dismount the ISO (in finally, on success and failure)
```

On machines without the Hyper-V module, steps 1, 2 and 6 fall back to `diskpart create/attach/detach vdisk`.

**Why exactly one partition inside the vhdx**: this is called native boot, a boot mode Windows supports natively. Given `vhd=[D:]\xxx.vhdx`, bootmgr treats the **first partition** of that virtual disk as the boot partition. An extra ESP inside makes bootmgr pick the wrong partition and the system does not start.

**Why the entry must live on the physical ESP**: UEFI firmware only scans the EFI system partition on physical disks and loads `\EFI\Microsoft\Boot\bootmgfw.efi` from it. It does not know about partitions inside a vhdx and never looks there. So "write the boot files into the ESP inside the vhdx" cannot work — that was the v1.3 failure.

**On the accuracy of "does not modify your existing system"**:
- partition table, system files, existing boot entries: **not touched**
- one record **is added** to the BCD store on the physical ESP (existing records are not modified, `bootmgfw.efi` is not overwritten)
- the BCD is backed up before any change (`<folder>-logs\bcd-backup-<timestamp>.bcd`), and uninstalling removes the added record

Image handling is funnelled through one function, `Resolve-RealImage`:

| Input | Path handed to DISM | Cleanup |
|---|---|---|
| `x.wim` / `x.esd` | the original path | none |
| `x.iso` | `G:\sources\install.esd` (resolved after mounting) | dismount G: |

So `Invoke-Install` only ever deals with one `$realImage` and never tests formats all over the place.

---

## Limits and caveats

### Hard requirements

| Item | Requirement | If not met |
|---|---|---|
| Current system | Windows 10 10240 or later, 64-bit | will not run |
| Privileges | administrator | exits when elevation fails |
| Storage partition | NTFS, local fixed disk, free ≥ size+5GB | the partition is not listed |
| Storage partition, cont. | the system drive (C:) is allowed too — the only option on single-disk machines | it consumes system space; the UI warns in yellow |
| Target machine | **must boot Windows normally** | the tool is unusable; you need USB/WinPE |

### Known limits

**1. The new system coexists with the old one, it does not replace it**
The original C: still exists and still takes space. That is the only way without entering WinPE. A true replacement means formatting C: from WinPE — which brings the USB stick back.

**2. The new system may ask for activation**
The licensing state comes along with the image. If the source was not activated, neither is the copy (use the original key, or a digital licence is picked up automatically).

**3. Drive letters may change**
Inside the new system the original C: may appear as D: or E:. That is normal — the boot volume differs.

**4. Hibernation / fast startup**
If the original system has *Fast startup* enabled, the boot menu may not appear. Turn it off in *Control Panel → Power Options → Choose what the power buttons do*.

**5. Secure Boot**

The new system's `winload.efi` comes from the image. With an original Microsoft image the signature is valid and Secure Boot accepts it.
With a modified image (drivers removed, boot changed, trimmed) the signature may be broken and boot fails with `0xc0000428` (digital signature could not be verified).

In that case, disable Secure Boot in the BIOS temporarily. The tool cannot detect your Secure Boot state.

**6. The machine already has other systems (dual/multi boot)**

The tool **adds** one entry on top of the existing setup and never touches other entries:

| Case | Behaviour |
|---|---|
| Which entry is duplicated | `{current}` (the system you are running), not `{default}` — on a multi-boot machine `{default}` may be a different system, and duplicating it produces a wrongly targeted entry |
| Does it change your menu timeout | only when `timeout=0` it raises it to 10 seconds (otherwise the menu is never seen); a 30-second setting stays 30 seconds |
| Duplicate menu description | an existing entry with the same text gets the drive letter appended, e.g. `Windows 10 Pro (Virtual System D:)` |
| Uninstalling | deletes only the entry pointing at **this exact vhdx path**; two drives both holding `NewSystemDisk.vhdx` will not confuse it |
| Menu after uninstalling | `bcdedit /deletevalue` restores "not set": single-system machines still boot straight in, **multi-boot machines keep their menu** |

The log records `The machine already has N boot entries (multi-boot): this run only adds one...` so you can verify.

The one manual boundary: if you **change the drive letter of the vhdx by hand** (D: → F:), the uninstaller's fallback degrades to "file name only", and with the same file name on two drives the log prints `WARNING: ... may include same-named systems on other drives`. Check before deleting.

**7. Distribution compliance**
If you hand this image and tool to somebody else, remember the image is a clone of a machine and may contain:
- your user data, browser history, saved credentials
- commercial software licences (usually not transferable)
- OEM licensing bound to the original hardware

**Run `sysprep /generalize` on the image before distributing**, or at least wipe personal data.

---

## Where logs / backups / reports live

**Since v1.29 every side file produced by an installation lives in one subfolder next to the virtual disk:**

```
D:\VirtualDisks\Virtual Hard Disk System-logs\   ← vhdx in D:\VirtualDisks
D:\Virtual Hard Disk System-logs\                ← vhdx in the drive root
```

Contents:

| File | What it is |
|---|---|
| `Virtual Hard Disk System-YYYYMMDD.log` | installation log: timestamps, command output, DISM exit code. Read this first when something fails |
| `bcd-backup-YYYYMMDD-HHmmss.bcd` | the BCD as it was before the install/repair; use it to roll back |
| `repair-bootmenu-report.txt` | report written by *Repair boot menu* |
| `new-system-report.txt` / `gpu-report.txt` | reports written by the matching tools |

Only two things stay next to the virtual disk: **the vhdx itself** and its **`xxx.boot.txt`** (the state file written by the installer, holding the boot entry GUID — the uninstaller and the repair tool need it, so it must travel with the vhdx).

> Before v1.29 the log lived in `%TEMP%`, the BCD backup was dropped next to the vhdx, and `bcdedit /export`
> additionally produced `.bcd.LOG` / `.LOG1` / `.LOG2` companions — a mess in the drive root.
> Those legacy files are not moved automatically; run `tools/Clean-Install-Residue.bat` and its last step
> lists them and deletes only after you type `y` (whitelist-matched, the `.bcd` backups themselves are kept).

---

## Verified / not verified

### Measured on real hardware

- image parsing (`Windows 10 Pro` 19041 wim: single image, 30.86GB unpacked)
- partition enumeration (USB / optical / network / non-NTFS excluded, free space correct, system drive listed and labelled)
- firmware detection (UEFI / Legacy BIOS)
- **the whole bat chain** (certutil decode → byte-identical payload → zero syntax errors → correct console output)
- **the "unpacked into a temp folder" case** (an image in the parent folder is still found after `OriginDir` is passed in)
- **the full UI refresh path** (partition dropdown, image dropdown, log pane, all with empty/null values)
- the empty-GPU diagnosis (the culprit is the IDD virtual display, not a ghost adapter — 2026-11-04)
- the DISM progress polling mechanism (v2.0)
- multi-format support (v1.1), the diskpart path-encoding fix (v1.2), the native-boot menu fixes (v1.4+)

### Not verified here

- Legacy BIOS machines (the tool refuses them explicitly instead of half working)
- Secure Boot enabled with a modified image (`0xc0000428`)
- RAID / Intel RST storage controllers

---

## Version history (condensed)

The Chinese guide (`docs/USER-GUIDE.zh-CN.md`) contains the full postmortems, including logs and measurement data. This is the summary.

| Version | What changed |
|---|---|
| v1.0 | First working version: vhdx + DISM + bcdedit native boot |
| v1.1 | Multi-format support (.wim/.esd/.iso); fixed the `MessageBoxDefaultButton` enum crash |
| v1.2 | Fixed virtual disk creation failing on non-ASCII paths (diskpart script must be written as ANSI/GBK, not ASCII) |
| v1.3 | bcdboot reported BFSVC 0x7b: an ESP inside the vhdx is invisible to UEFI firmware — abandoned that approach entirely |
| v1.4 | No boot menu after install: removed the ESP from the vhdx (native boot wants exactly one partition) and wrote the entry through the BCD API |
| v1.5 | Sharing violation when backing up the BCD: switched from file copy to `bcdedit /export` on the active store |
| v1.6 | `vhd=` silently turned into `partition=E:`: the vhdx must be dismounted before writing the entry |
| v1.7 | Leftover ESP drive letter (S:) after uninstalling — the access path is now released |
| v1.8 | Boot menu still present after uninstalling: `displaybootmenu` / `timeout` restored from the recorded originals |
| v1.9 | Code review round: 8 issues fixed, 2 of them data-loss class |
| v1.9.1 | False "boot will probably fail" warning: compare total partition count, not the partition number |
| v1.10 | No longer depends on the Hyper-V module (falls back to diskpart) |
| v1.11 | Multiple systems, custom names, custom folders; project renamed to *Virtual Hard Disk System* |
| v1.12 | "Hundreds of GB free but it says no space": free space is taken as the largest of three sources plus a real write probe |
| v1.13 | Menu pointed at the wrong file when installing into a subfolder: the full relative path is written now |
| v1.14 | Custom names propagated through the whole chain (installer, uninstaller, repair tool, residue cleaner) |
| v1.15 | Five review findings: wrong menu numbers in hints, originals overwritten by current values, delete-before-create, other people's vhdx treated as residue, three inconsistent state-file keys |
| v1.16 | Regression fix: the GUID parsing after `/copy` had been deleted; plus a static check for variables referenced but never assigned |
| v1.17 | Single-disk machines could not click a single button: the partition enumeration excluded the system drive |
| v1.18 | "Second install fails at the last step": `/copy` source resolution now falls back through `{current}` → `{default}` → a real osloader |
| v1.19 | Even a wiped BCD can get an entry: `/create` as the last resort, plus a displayorder confirmation |
| v1.20 | A manually typed disk size is no longer snapped back to the suggestion |
| v1.21 | Pre-seeded `SetupComplete.cmd` that gives the original system partition a drive letter on first boot |
| v1.22–v1.23 | Repair tool / uninstaller hardening around the leftover one-shot `bootsequence` that short-circuits the menu |
| v1.24 | `/copy` does not add to displayorder while `/create` does — both routes now confirm it |
| v1.25 | Fixed the XML metadata being appended repeatedly (missing `break`), which duplicated edition entries |
| v1.26 | Removed the offline network driver injection: proven never to work across Windows builds |
| v1.27 | Parentheses in a name broke the BCD `vhd=[...]` syntax; they are now replaced with `-` |
| v1.28 | Renamed to *Virtual Hard Disk System* everywhere, all tool versions unified |
| v1.29 | Logs, BCD backups and reports moved into `<vhdx folder>-logs\` instead of the drive root |
| v1.30 | Cleaner tool: a broken `Write-Host` call and a silently skipped step 4 (missing `-Force` for Hidden+System files) |
| v1.31 | **High severity**: the installer and repair tool used to delete `C:\Boot` (a real Windows boot folder) — removed; `C:\EFI` now needs three conditions |
| v2.0 | DISM no longer deadlocks at 12% (output goes to a file, the main thread polls); MSR partition handling for a single-partition layout |
