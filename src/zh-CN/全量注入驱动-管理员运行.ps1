param(
    [string]$OriginDir = ''
)

# ============================================================
# 全量注入驱动  v1.3
# 作者: connectsegabot
#
# 用途：装好的虚拟系统里「设备管理器一堆未知设备」。
#   把本机所有第三方驱动包（芯片组、ACPI、PCIe、网卡、音频、蓝牙、显卡…）
#   一次性搬进虚拟系统，重启后 PnP 自己就能认出来。
#
# 和「注入网卡驱动」的区别：那个只搬 Net 类 9 个包，这个搬全部 160+ 个。
#
# 同时会把导出的驱动留一份在 vhdx 所在盘的 NewSystemDriver 目录，
# 万一某几个没绑上，进新系统后还能用「新系统-诊断并装驱动.bat」现场装。
# ============================================================

$ErrorActionPreference = 'Continue'
$Script:Version = '1.32'
$Script:OriginDir = $OriginDir
try { $Host.UI.RawUI.WindowTitle = "全量注入驱动 v$($Script:Version) - connectsegabot" } catch {}

function Say {
    param([string]$Text, [string]$Color = 'Gray')
    Write-Host $Text -ForegroundColor $Color
}

Say ""
Say "  全量注入驱动  v$($Script:Version)" 'Cyan'
Say "  作者: connectsegabot" 'DarkGray'
Say "  ------------------------------------------------------------" 'DarkGray'
Say ""

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Say "  [错误] 需要管理员权限。请关掉本窗口，右键本文件 -> 以管理员身份运行。" 'Red'
    Say ""
    Read-Host "  按回车退出"
    exit 1
}

# ---------- 排除「当前正在运行的系统」 ----------
$sysLetter = ([string]$env:SystemDrive).TrimEnd(':').ToUpper()
$sysVolId = ''
try { $sysVolId = [string](Get-Volume -DriveLetter $sysLetter -ErrorAction Stop).UniqueId } catch {}

function Test-IsRunningSystem {
    param($Vol)
    if (([string]$Vol.DriveLetter).ToUpper() -eq $sysLetter) { return $true }
    if ($sysVolId -and ([string]$Vol.UniqueId -eq $sysVolId)) { return $true }
    return $false
}

function Get-TargetCandidates {
    $list = @()
    $vhdDisks = @{}
    foreach ($d in @(Get-Disk -ErrorAction SilentlyContinue)) {
        if ([string]$d.BusType -eq 'File Backed Virtual') { $vhdDisks[[int]$d.Number] = $true }
    }
    foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
        if (-not $v.DriveLetter) { continue }
        $root = "{0}:\" -f $v.DriveLetter
        if (-not (Test-Path -LiteralPath ($root + 'Windows\System32\ntoskrnl.exe'))) { continue }
        $diskNum = -1
        try { $diskNum = [int](Get-Partition -DriveLetter $v.DriveLetter -ErrorAction Stop).DiskNumber } catch {}
        $list += [pscustomobject]@{
            Letter  = [string]$v.DriveLetter
            Label   = [string]$v.FileSystemLabel
            Running = (Test-IsRunningSystem $v)
            IsVhd   = ($diskNum -ge 0 -and $vhdDisks.ContainsKey($diskNum))
            Disk    = $diskNum
            SizeGB  = [math]::Round($v.Size / 1GB, 1)
            FreeGB  = [math]::Round($v.SizeRemaining / 1GB, 1)
        }
    }
    return $list
}

function Find-VhdxFiles {
    $found = @()
    if ($Script:OriginDir -and (Test-Path -LiteralPath $Script:OriginDir)) {
        $c = Join-Path $Script:OriginDir 'NewSystemDisk.vhdx'
        if (Test-Path -LiteralPath $c) { $found += $c }
    }
    foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
        if (-not $v.DriveLetter) { continue }
        if ($v.DriveType -ne 'Fixed') { continue }
        $c = "{0}:\NewSystemDisk.vhdx" -f $v.DriveLetter
        if (Test-Path -LiteralPath $c) {
            $full = (Get-Item -LiteralPath $c).FullName
            if ($found -notcontains $full) { $found += $full }
        }
    }
    return $found
}

function Mount-Vhdx {
    param([string]$Path)
    $dpFile = Join-Path $env:TEMP ("attach_all_{0}.txt" -f $PID)
    @("select vdisk file=`"$Path`"", 'attach vdisk', 'exit') | Set-Content -LiteralPath $dpFile -Encoding Default
    $r = ''
    try { $r = (& diskpart /s $dpFile 2>&1 | Out-String) } catch { $r = $_.Exception.Message }
    Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
    if ($r -match 'successfully|成功') { return $true }
    Say ("      挂载返回: " + (($r -replace "\s+", ' ').Trim())) 'Yellow'
    return $false
}

function Dismount-Vhdx {
    param([string]$Path)
    $dpFile = Join-Path $env:TEMP ("detach_all_{0}.txt" -f $PID)
    @("select vdisk file=`"$Path`"", 'detach vdisk', 'exit') | Set-Content -LiteralPath $dpFile -Encoding Default
    try { & diskpart /s $dpFile 2>&1 | Out-Null } catch {}
    Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
}

# ---------- [1/4] 找目标 ----------
Say "[1/4] 找目标系统 ..." 'White'

$attachedVhdx = ''
$targets = @(Get-TargetCandidates)
$usable = @($targets | Where-Object { -not $_.Running })
$vhdTargets = @($usable | Where-Object { $_.IsVhd })

if ($vhdTargets.Count -eq 0) {
    foreach ($f in @(Find-VhdxFiles)) {
        Say ("      发现虚拟磁盘 {0}，正在挂载 ..." -f $f) 'DarkGray'
        if (Mount-Vhdx -Path $f) {
            $attachedVhdx = $f
            Say "      已挂载" 'Green'
            break
        }
    }
    if ($attachedVhdx) {
        Start-Sleep -Seconds 2
        $targets = @(Get-TargetCandidates)
        $usable = @($targets | Where-Object { -not $_.Running })
        $vhdTargets = @($usable | Where-Object { $_.IsVhd })
    }
}

if ($vhdTargets.Count -eq 1) {
    $target = $vhdTargets[0]
} elseif ($usable.Count -eq 0) {
    Say ""
    Say "  [错误] 没找到可注入的虚拟系统。" 'Red'
    Say ("         {0}: 是当前正在运行的系统，不能当目标（DISM 会报 Error 87）。" -f $sysLetter) 'Yellow'
    Say "         也没找到 NewSystemDisk.vhdx。" 'Yellow'
    Say ""
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  按回车退出"
    exit 1
} else {
    Say "      找到多个可注入的系统：" 'White'
    for ($i = 0; $i -lt $usable.Count; $i++) {
        $t = $usable[$i]
        $kind = if ($t.IsVhd) { '虚拟磁盘' } else { '物理分区' }
        Say ("      [{0}] {1}:  {2}  {3} GB 卷标={4}" -f ($i + 1), $t.Letter, $kind, $t.SizeGB, $t.Label)
    }
    $sel = Read-Host "      输入序号（默认 1）"
    $idx = 1
    [int]::TryParse($sel, [ref]$idx) | Out-Null
    if ($idx -lt 1 -or $idx -gt $usable.Count) { $idx = 1 }
    $target = $usable[$idx - 1]
}

if ($target.Running) {
    Say "  [错误] 选中的是运行中的系统，已中止。" 'Red'
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  按回车退出"
    exit 1
}
Say ("      目标：{0}:  剩余 {1} GB" -f $target.Letter, $target.FreeGB) 'Green'

# ---------- [2/4] 导出本机全部第三方驱动 ----------
Say "[2/4] 导出本机全部第三方驱动 ..." 'White'
$drvDir = Join-Path $env:TEMP ("alldrv_{0}" -f $PID)
try { if (Test-Path -LiteralPath $drvDir) { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } } catch {}
New-Item -ItemType Directory -Path $drvDir -Force | Out-Null

$enumText = ''
try { $enumText = (& pnputil /enum-drivers 2>&1 | Out-String) } catch {}
$oems = New-Object System.Collections.ArrayList
foreach ($blk in ($enumText -split "(?:\r?\n){2,}")) {
    $m = [regex]::Match($blk, '(?i)\b(oem\d+\.inf)\b')
    if (-not $m.Success) { continue }
    $nm = $m.Groups[1].Value.ToLower()
    if (-not $oems.Contains($nm)) { [void]$oems.Add($nm) }
}
Say ("      第三方驱动包: {0} 个" -f $oems.Count) 'DarkGray'

$okExport = 0
foreach ($oem in $oems) {
    $er = (& pnputil /export-driver $oem $drvDir 2>&1 | Out-String)
    if ($er -match 'successfully|成功') { $okExport++ }
}

# 【v1.2】pnputil /enum-drivers 只列第三方 oem*.inf，物理网卡常用系统内置（in-box）
# 包——不在 oem 列表里，一个都导不出，而精简镜像/Server 新系统里恰好没有这个包。
# 所以把「当前真实存在的物理网卡」正在用的 INF 补导出：第三方 oem 已导过（跳过）；
# in-box 的从 DriverStore\FileRepository 整包复制——注入和 NewSystemDriver 备份都带上。
try {
    $physNets = @(Get-PnpDevice -Class Net -PresentOnly -EA SilentlyContinue |
        Where-Object { $_.InstanceId -match '^(PCI|USB)' })
    foreach ($dev in $physNets) {
        try {
            $drvInf = ''
            try { $drvInf = [string](Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -EA Stop).Data } catch {}
            if (-not $drvInf) { continue }
            $drvInf = $drvInf.ToLower()
            Say ("      物理网卡 {0} 正在使用 {1}" -f $dev.FriendlyName, $drvInf) 'DarkGray'
            if ($drvInf -match '^oem\d+\.inf$') { continue }
            # FileRepository 的包目录名是 <inf文件名>_<架构>_<哈希>，例如
            # rt640x64.inf_amd64_cbf4e23981c3c8a3。必须用带 .inf 的完整文件名去匹配；
            # 早前误用「去掉扩展名」的名字（rt640x64_*），永远匹配不上，内置驱动一个都
            # 复制不出来 —— 表现就是「注入了但网卡还是没驱动」。
            $frRoot = "$env:SystemRoot\System32\DriverStore\FileRepository"
            $pkgDirs = @(Get-ChildItem $frRoot -Directory -Filter ($drvInf + '_*') -EA SilentlyContinue)
            if ($pkgDirs.Count -eq 0) {
                $pkgDirs = @(Get-ChildItem $frRoot -Directory -EA SilentlyContinue |
                    Where-Object { $_.Name.ToLower().StartsWith($drvInf + '_') })
            }
            if ($pkgDirs.Count -eq 0) {
                Say ("  未找到 {0} 的驱动包目录（可能驱动名与目录名不一致）" -f $drvInf) 'Yellow'
            }
            foreach ($pd in $pkgDirs) {
                Copy-Item -LiteralPath $pd.FullName -Destination $drvDir -Recurse -Force -EA SilentlyContinue
                Say ("  已复制内置网卡驱动包: " + $pd.Name) 'DarkGray'
            }
        } catch { Say ("      内置网卡驱动导出失败: " + $_.Exception.Message) 'Yellow' }
    }
} catch { Say ("      内置网卡驱动导出异常: " + $_.Exception.Message) 'Yellow' }

$infFiles = @(Get-ChildItem -LiteralPath $drvDir -Recurse -Filter *.inf -ErrorAction SilentlyContinue)
$drvMB = 0
try { $drvMB = [math]::Round(((Get-ChildItem $drvDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1) } catch {}
Say ("      导出完成：{0} 个包 / {1} 个 INF / {2} MB" -f $okExport, $infFiles.Count, $drvMB) 'Green'
if ($infFiles.Count -eq 0) {
    Say "  [错误] 一个 INF 都没导出，无法继续。" 'Red'
    try { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } catch {}
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  按回车退出"
    exit 1
}

# ---------- 排除 IDD 虚拟显示驱动 ----------
# 【为什么要排除】远程串流 / 模拟器 / 投屏这类软件会装一个「间接显示驱动」（IDD），
# 它注册的设备是 ROOT\DISPLAY\NNNN —— 由软件自己实例化，没有真实 GPU 硬件。
# 这类 INF 一旦被注入，新系统首次开机 PnP 就会照 Root 枚举 ID 建一个设备出来，
# 任务管理器「性能」页于是多出一张显存/3D/Video 全是空的 GPU。
# 用户看到的就是「装好之后多了个空 GPU」，而且删幽灵显卡对它完全无效。
# 本机有、目标机不一定需要 —— 属于「搬过去只会添乱」的一类。
$iddPat = '(?i)(GameViewerIdd|IddDriver|IddSampleDriver|usbmmidd|Virtual\s*Display|VirtualDisplay|MuMuIdd|spacedesk|astropad|Parsec.*Idd|Oculus.*(Idd|Display))'
$byDir = @{}
foreach ($inf in $infFiles) {
    $dn = $inf.DirectoryName
    if (-not $byDir.ContainsKey($dn)) { $byDir[$dn] = New-Object System.Collections.ArrayList }
    [void]$byDir[$dn].Add($inf)
}
$excludedPkgs = @()
$excludedInf = @()
foreach ($dn in @($byDir.Keys)) {
    $list = $byDir[$dn]
    $allMatch = $true
    $hitName = ''
    foreach ($inf in $list) {
        $txt = ''
        try { $txt = [IO.File]::ReadAllText($inf.FullName, [Text.Encoding]::Default) } catch { $allMatch = $false; break }
        if ($txt -notmatch $iddPat) { $allMatch = $false; break }
        if (-not $hitName) { $hitName = $inf.Name }
    }
    if ($allMatch -and $list.Count -gt 0) {
        $excludedPkgs += [PSCustomObject]@{ Dir = $dn; Inf = $hitName }
        foreach ($inf in $list) { $excludedInf += $inf.FullName }
    }
}
$excludedMB = 0
if ($excludedPkgs.Count -gt 0) {
    Say ("      排除虚拟显示驱动 {0} 个（它们会让新系统多出空 GPU）：" -f $excludedPkgs.Count) 'Yellow'
    foreach ($e in $excludedPkgs) {
        Say ("        - " + $e.Inf) 'DarkGray'
        try { $excludedMB += [math]::Round(((Get-ChildItem $e.Dir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1) } catch {}
        try { Remove-Item -LiteralPath $e.Dir -Recurse -Force -EA SilentlyContinue } catch {}
    }
    # 重新统计要注入的 INF
    $infFiles = @(Get-ChildItem -LiteralPath $drvDir -Recurse -Filter *.inf -ErrorAction SilentlyContinue)
    try { $drvMB = [math]::Round(((Get-ChildItem $drvDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1) } catch {}
    Say ("      实际注入：{0} 个 INF / {1} MB（已排除 {2} MB）" -f $infFiles.Count, $drvMB, $excludedMB) 'Green'
    if ($infFiles.Count -eq 0) {
        Say "  [错误] 排除后没有可注入的驱动包。" 'Red'
        try { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } catch {}
        if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
        Read-Host "  按回车退出"
        exit 1
    }
} else {
    Say "      没有发现虚拟显示（IDD）驱动" 'DarkGray'
}

# 空间检查：注入后驱动库会占掉同等体积，留 1.5 倍余量
$needGB = [math]::Round(($drvMB / 1024) * 1.5 + 0.5, 1)
if ($target.FreeGB -lt $needGB) {
    Say ("  [错误] 目标系统只剩 {0} GB，注入大约需要 {1} GB。请先扩容或清理。" -f $target.FreeGB, $needGB) 'Red'
    try { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } catch {}
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  按回车退出"
    exit 1
}
Say ("      空间检查通过（需要 {0} GB，可用 {1} GB）" -f $needGB, $target.FreeGB) 'DarkGray'

# 留一份给「新系统里现场装」用：放到 vhdx 所在盘的 NewSystemDriver
$keepDir = ''
$vhdxPath = $attachedVhdx
if (-not $vhdxPath) {
    foreach ($f in @(Find-VhdxFiles)) { $vhdxPath = $f; break }
}
if ($vhdxPath) {
    try {
        $keepDir = Join-Path (Split-Path -Parent $vhdxPath) 'NewSystemDriver'
        if (Test-Path -LiteralPath $keepDir) { Remove-Item -LiteralPath $keepDir -Recurse -Force -EA SilentlyContinue }
        New-Item -ItemType Directory -Path $keepDir -Force | Out-Null
        Say ("      另存一份到 {0}（进新系统后可现场装）..." -f $keepDir) 'DarkGray'
        Copy-Item -Path (Join-Path $drvDir '*') -Destination $keepDir -Recurse -Force -EA SilentlyContinue
        Say "      已另存" 'Green'
    } catch {
        $keepDir = ''
        Say ("      另存失败（不影响注入）: " + $_.Exception.Message) 'Yellow'
    }
}

# ---------- [3/4] 注入 ----------
Say "[3/4] 注入全部驱动（3~10 分钟，别关窗口）..." 'White'
$logFile = Join-Path $env:TEMP ("alldrv_{0}.log" -f $PID)
$errFile = $logFile + '.err'
try { if (Test-Path -LiteralPath $logFile) { Remove-Item $logFile -Force -EA SilentlyContinue } } catch {}

$dismArgs = '/English /Image:{0}:\ /Add-Driver /Driver:"{1}" /Recurse' -f $target.Letter, $drvDir
Say ("      dism {0}" -f $dismArgs) 'DarkGray'

$proc = Start-Process -FilePath 'dism.exe' -ArgumentList $dismArgs `
            -RedirectStandardOutput $logFile -RedirectStandardError $errFile `
            -NoNewWindow -PassThru -ErrorAction Stop

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$lastBeat = 0
while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds 900
    if (($sw.ElapsedMilliseconds - $lastBeat) -ge 5000) {
        $lastBeat = $sw.ElapsedMilliseconds
        $done = 0
        try { $done = @([regex]::Matches([IO.File]::ReadAllText($logFile), '(?i)Installing \d+ of \d+')).Count } catch {}
        Say ("      已用 {0} 秒，已处理 {1} 个 ..." -f [int]$sw.Elapsed.TotalSeconds, $done) 'DarkGray'
    }
    if ($sw.ElapsedMilliseconds -gt 1800000) {
        try { Stop-Process -Id $proc.Id -Force -EA SilentlyContinue } catch {}
        Say "      超过 30 分钟，已放弃" 'Red'
        break
    }
}
try { $proc.WaitForExit() } catch {}

# ---------- [4/4] 结果 ----------
Say ""
$txt = ''
try { if (Test-Path -LiteralPath $logFile) { $txt = [IO.File]::ReadAllText($logFile, [Text.Encoding]::Default) } } catch {}
$errTxt = ''
try { if (Test-Path -LiteralPath $errFile) { $errTxt = [IO.File]::ReadAllText($errFile, [Text.Encoding]::Default) } } catch {}

$okList = @([regex]::Matches($txt, '(?i)Installing \d+ of \d+ - (.+?):\s*(?:The driver package was successfully installed|驱动包.*?已成功安装)') | ForEach-Object { $_.Groups[1].Value })
$failList = @([regex]::Matches($txt, '(?i)Installing \d+ of \d+ - (.+?):\s*Error') | ForEach-Object { $_.Groups[1].Value })

Say "[4/4] 结果：" 'White'
Say ("      成功注入: {0} 个驱动包" -f $okList.Count) 'Green'
if ($failList.Count -gt 0) {
    Say ("      未适用  : {0} 个（系统版本不匹配，见日志）" -f $failList.Count) 'Yellow'
    foreach ($f in ($failList | Select-Object -First 12)) { Say ("        - " + $f) 'DarkGray' }
    if ($failList.Count -gt 12) { Say ("        ... 还有 {0} 个" -f ($failList.Count - 12)) 'DarkGray' }
}
Say ("      日志: {0}" -f $logFile) 'Gray'

Say ""
if ($okList.Count -gt 0) {
    Say "  注入完成。重启进新系统后，设备管理器里的未知设备应该会大幅减少。" 'Green'
    if ($keepDir) {
        Say ("  如果还有几个带感叹号，进新系统后运行 目录里的「诊断并装驱动」，它会用 {0}" -f $keepDir) 'Gray'
    }
} else {
    Say "  一个都没注入成功，请看日志里的错误。" 'Red'
    if ($errTxt.Trim()) { foreach ($l in @($errTxt -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 6)) { Say ("      " + $l) 'Yellow' } }
}

# ---------- 收尾 ----------
try { if (Test-Path -LiteralPath $drvDir) { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } } catch {}
if ($attachedVhdx) {
    Say ""
    Say ("  卸载临时挂载的虚拟磁盘 ...") 'DarkGray'
    Dismount-Vhdx -Path $attachedVhdx
    Say "  已卸载" 'DarkGray'
}
Say ""
Read-Host "  按回车退出"
