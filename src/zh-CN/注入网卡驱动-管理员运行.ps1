param(
    [string]$OriginDir = ''
)

# ============================================================
# 注入网卡驱动  v1.2
# 作者: connectsegabot
#
# 用途：已经装好的虚拟系统进不去网（设备管理器里网卡带感叹号 / 网络图标打红叉），
#   用它把「当前这台机器正在用的网卡驱动」注入到那个系统里。
#
# 驱动是从本机现取的，硬件 ID 必然匹配，注入完联网即通。
# 只动目标系统的驱动库（DriverStore），不碰系统文件和引导。
#
# v1.1 修正（2026-11-04）：
#   v1.0 的目标识别有致命缺陷 —— 它只找「带 ntoskrnl.exe 的卷」，
#   而正在运行的 C: 本身就带内核，虚拟磁盘没挂载时 C: 是唯一候选，
#   于是脚本一路往 C: 里注入，DISM 直接报：
#       Error: 87  The /Image option that is specified points to a
#       running Windows installation.
#   （DISM 拒绝执行，所以什么都没写进去，原系统没有被改动。）
#   v1.1 起：排除当前运行的系统盘、优先认虚拟磁盘、没挂载就自动挂载。
#
# v1.2 修正（2026-11-05）：
#   v1.1 只导出 pnputil /enum-drivers 里的第三方 oem*.inf。物理机网卡多半用
#   系统内置（in-box）驱动包，根本不在 oem 列表里 → 一个都导不出来，注入
#   环节直接判「没有可导出的网卡驱动」退出，看现象就是「这个工具没效果」。
#   （以前在虚拟机里试总是好的，因为那里的虚拟网卡驱动恰好是 oem 包。）
#   v1.2 起：额外枚举真实存在的 PCI/USB 物理网卡，取其正在使用的 INF，
#   内置包从 DriverStore\FileRepository 整包复制后一起注入。
# ============================================================

$ErrorActionPreference = 'Continue'
$Script:Version = '1.31'
$Script:OriginDir = $OriginDir
try { $Host.UI.RawUI.WindowTitle = "注入网卡驱动 v$($Script:Version) - connectsegabot" } catch {}

function Say {
    param([string]$Text, [string]$Color = 'Gray')
    Write-Host $Text -ForegroundColor $Color
}

Say ""
Say "  注入网卡驱动  v$($Script:Version)" 'Cyan'
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

# ---------- 识别「当前正在运行的系统」，必须排除 ----------
$sysLetter = ([string]$env:SystemDrive).TrimEnd(':').ToUpper()
$sysVolId = ''
try { $sysVolId = [string](Get-Volume -DriveLetter $sysLetter -ErrorAction Stop).UniqueId } catch {}

function Test-IsRunningSystem {
    param($Vol)
    if (([string]$Vol.DriveLetter).ToUpper() -eq $sysLetter) { return $true }
    # 同一个卷被挂到另一个盘符时 UniqueId 相同，也要排除，
    # 否则 DISM 同样报 Error 87。
    if ($sysVolId -and ([string]$Vol.UniqueId -eq $sysVolId)) { return $true }
    return $false
}

# ---------- 候选卷 ----------
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
        }
    }
    return $list
}

# ---------- 找可挂载的 vhdx ----------
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
    $dpFile = Join-Path $env:TEMP ("attach_vhd_{0}.txt" -f $PID)
    @(
        "select vdisk file=`"$Path`"",
        'attach vdisk',
        'exit'
    ) | Set-Content -LiteralPath $dpFile -Encoding Default
    $r = ''
    try { $r = (& diskpart /s $dpFile 2>&1 | Out-String) } catch { $r = $_.Exception.Message }
    Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
    if ($r -match 'successfully|成功') { return $true }
    Say ("      挂载返回: " + (($r -replace "\s+", ' ').Trim())) 'Yellow'
    return $false
}

function Dismount-Vhdx {
    param([string]$Path)
    $dpFile = Join-Path $env:TEMP ("detach_vhd_{0}.txt" -f $PID)
    @(
        "select vdisk file=`"$Path`"",
        'detach vdisk',
        'exit'
    ) | Set-Content -LiteralPath $dpFile -Encoding Default
    try { & diskpart /s $dpFile 2>&1 | Out-Null } catch {}
    Remove-Item -LiteralPath $dpFile -Force -ErrorAction SilentlyContinue
}

# ---------- [1/4] 定位目标系统 ----------
Say "[1/4] 定位目标系统 ..." 'White'

$attachedVhdx = ''
$targets = @(Get-TargetCandidates)
$usable = @($targets | Where-Object { -not $_.Running })

# 优先用虚拟磁盘里的系统（本工具的本职场景）
$vhdTargets = @($usable | Where-Object { $_.IsVhd })

if ($vhdTargets.Count -eq 0) {
    $vhdxFiles = @(Find-VhdxFiles)
    if ($vhdxFiles.Count -gt 0) {
        foreach ($f in $vhdxFiles) {
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
}

if ($vhdTargets.Count -eq 1) {
    $target = $vhdTargets[0]
    Say ("      目标：{0}:  （虚拟磁盘里的系统，{1} GB）" -f $target.Letter, $target.SizeGB) 'Green'
}
elseif ($usable.Count -eq 0) {
    Say ""
    Say "  [错误] 没找到可注入的系统。" 'Red'
    Say ("         当前正在运行的是 {0}:，它不能作为目标（DISM 不允许）。" -f $sysLetter) 'Yellow'
    Say "         也没有找到已挂载或可挂载的 NewSystemDisk.vhdx。" 'Yellow'
    Say "         请确认虚拟系统装在哪个 vhdx 文件里、文件名是否叫 NewSystemDisk.vhdx。" 'Yellow'
    Say ""
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  按回车退出"
    exit 1
}
else {
    Say "      找到多个可注入的系统，请选择：" 'White'
    for ($i = 0; $i -lt $usable.Count; $i++) {
        $t = $usable[$i]
        $kind = if ($t.IsVhd) { '虚拟磁盘' } else { '物理分区' }
        Say ("      [{0}] {1}:  {2}  {3} GB  卷标={4}" -f ($i + 1), $t.Letter, $kind, $t.SizeGB, $t.Label)
    }
    $sel = Read-Host "      输入序号（默认 1）"
    $idx = 1
    [int]::TryParse($sel, [ref]$idx) | Out-Null
    if ($idx -lt 1 -or $idx -gt $usable.Count) { $idx = 1 }
    $target = $usable[$idx - 1]
    Say ("      目标：{0}:" -f $target.Letter) 'Green'
}

# 双保险：绝不往运行中的系统写
if ($target.Running) {
    Say ""
    Say "  [错误] 选中的是当前正在运行的系统，DISM 不允许（Error 87）。已中止。" 'Red'
    Say ""
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  按回车退出"
    exit 1
}

# ---------- [2/4] 导出本机网卡驱动 ----------
Say "[2/4] 从本机导出网卡驱动 ..." 'White'
$netClassGuid = '4d36e972-e325-11ce-bfc1-08002be10318'   # 网络适配器（与语言无关）
$drvDir = Join-Path $env:TEMP ("injectnet_{0}" -f $PID)
try { if (Test-Path -LiteralPath $drvDir) { Remove-Item -LiteralPath $drvDir -Recurse -Force -ErrorAction SilentlyContinue } } catch {}
New-Item -ItemType Directory -Path $drvDir -Force | Out-Null

$enumText = ''
try { $enumText = (& pnputil /enum-drivers 2>&1 | Out-String) } catch {}
$netOems = New-Object System.Collections.ArrayList
foreach ($blk in ($enumText -split "(?:\r?\n){2,}")) {
    if ($blk -notmatch $netClassGuid) { continue }
    $m = [regex]::Match($blk, '(?i)\b(oem\d+\.inf)\b')
    if (-not $m.Success) { continue }
    $nm = $m.Groups[1].Value.ToLower()
    if (-not $netOems.Contains($nm)) { [void]$netOems.Add($nm) }
}
Say ("      本机第三方网络驱动包: {0} 个" -f $netOems.Count) 'DarkGray'
foreach ($oem in $netOems) {
    $er = (& pnputil /export-driver $oem $drvDir 2>&1 | Out-String)
    if ($er -match 'successfully|成功') { Say ("      [ok] {0}" -f $oem) 'DarkGray' }
    else { Say ("      [!!] {0}  {1}" -f $oem, (($er -replace "\s+", ' ').Trim())) 'Yellow' }
}

# 【v1.2】pnputil /enum-drivers 只列第三方 oem*.inf，会漏掉内置（in-box）网卡
# 驱动：物理机网卡常用系统自带包（不在 oem 列表里），上面一个都导不出，于是
# 目标系统照样没网——看起来就是「这个工具没效果」。这里把「当前真实存在的
# 物理网卡」正在用的 INF 补导出：第三方 oem 已导过（跳过），in-box 的从
# DriverStore\FileRepository 整包复制。
Say "      补导出物理网卡正在使用的驱动（含系统内置）..." 'DarkGray'
try {
    $physNets = @(Get-PnpDevice -Class Net -PresentOnly -EA SilentlyContinue |
        Where-Object { $_.InstanceId -match '^(PCI|USB)' })
    foreach ($dev in $physNets) {
        try {
            $drvInf = ''
            try { $drvInf = [string](Get-PnpDeviceProperty -InstanceId $dev.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -EA Stop).Data } catch {}
            if (-not $drvInf) { continue }
            $drvInf = $drvInf.ToLower()
            Say ("      网卡 {0} 正在使用 {1}" -f $dev.FriendlyName, $drvInf) 'DarkGray'
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
        } catch { Say ("      [!!] 内置驱动导出失败: {0}" -f $_.Exception.Message) 'Yellow' }
    }
} catch { Say ("      [!!] 内置驱动导出异常: {0}" -f $_.Exception.Message) 'Yellow' }

$infFiles = @(Get-ChildItem -LiteralPath $drvDir -Recurse -Filter *.inf -ErrorAction SilentlyContinue)
if ($infFiles.Count -eq 0) {
    Say ""
    Say "  本机没有可导出的网卡驱动（第三方和系统内置都没找到）。" 'Yellow'
    Say "  这种情况通常不是缺驱动，请在目标系统里跑「新系统-诊断并装驱动」看具体报错。" 'Yellow'
    Say ""
    try { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } catch {}
    if ($attachedVhdx) { Dismount-Vhdx -Path $attachedVhdx }
    Read-Host "  按回车退出"
    exit 1
}
$mb = 0
try { $mb = [math]::Round(((Get-ChildItem $drvDir -Recurse -File | Measure-Object Length -Sum).Sum) / 1MB, 1) } catch {}
Say ("      导出完成：{0} 个 INF，{1} MB" -f $infFiles.Count, $mb) 'Green'

# ---------- [3/4] 注入 ----------
Say "[3/4] 注入到目标系统（可能要一两分钟）..." 'White'
$logFile = Join-Path $env:TEMP ("injectnet_{0}.log" -f $PID)
$errFile = $logFile + '.err'
try { if (Test-Path -LiteralPath $logFile) { Remove-Item $logFile -Force -EA SilentlyContinue } } catch {}

# /Image 后面不加引号：写成 "/Image:E:\" 时结尾的 \" 会被当成转义引号，
# 参数会变成 Image:E:" 而报错。盘符路径不含空格，不加引号最稳。
$dismArgs = '/English /Image:{0}:\ /Add-Driver /Driver:"{1}" /Recurse' -f $target.Letter, $drvDir
Say ("      dism {0}" -f $dismArgs) 'DarkGray'

$proc = Start-Process -FilePath 'dism.exe' -ArgumentList $dismArgs `
            -RedirectStandardOutput $logFile -RedirectStandardError $errFile `
            -NoNewWindow -PassThru -ErrorAction Stop

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$lastBeat = 0
while (-not $proc.HasExited) {
    Start-Sleep -Milliseconds 700
    if (($sw.ElapsedMilliseconds - $lastBeat) -ge 3000) {
        $lastBeat = $sw.ElapsedMilliseconds
        Say ("      已用 {0} 秒..." -f [int]$sw.Elapsed.TotalSeconds) 'DarkGray'
    }
    if ($sw.ElapsedMilliseconds -gt 900000) {
        try { Stop-Process -Id $proc.Id -Force -EA SilentlyContinue } catch {}
        Say "      超过 15 分钟，已放弃" 'Red'
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

Say "[4/4] 结果：" 'White'
$installed = @([regex]::Matches($txt, '(?i)driver package (?:was )?(?:successfully )?installed|驱动包.*?已成功安装')).Count
foreach ($l in @($txt -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 10)) { Say ("      " + $l) 'DarkGray' }
if ($errTxt.Trim()) {
    Say "      --- stderr ---" 'DarkGray'
    foreach ($l in @($errTxt -split "[`r`n]+" | Where-Object { $_.Trim() } | Select-Object -Last 6)) { Say ("      " + $l) 'Yellow' }
}

Say ""
if ($txt -match 'completed successfully|操作成功完成') {
    if ($installed -gt 0) { Say ("  注入完成，{0} 个驱动包已装入 {1}: 。" -f $installed, $target.Letter) 'Green' }
    else { Say ("  注入完成（DISM 未报告新增驱动包，可能目标系统里已有同样的驱动）。") 'Green' }
    Say ("  重启进新系统后，网卡应该就能认出来了。日志：{0}" -f $logFile) 'Gray'
}
elseif ($txt -match '87' -or $errTxt -match 'running Windows installation|正在运行的') {
    Say "  失败：目标被 DISM 判定为正在运行的系统（Error 87）。" 'Red'
    Say "  这说明定位到的还不是虚拟系统，请把 TargetDir 指到 vhdx 所在目录后再试。" 'Yellow'
}
else {
    Say "  注入结果不确定，请看上面的输出。" 'Yellow'
    Say ("  完整日志：{0}" -f $logFile) 'Gray'
    Say "  如果提示「该驱动与所选映像不兼容」，说明本机驱动要求更高的系统版本，" 'Gray'
    Say "  需要去网卡官网下载 Win10 版驱动，再手动在目标系统里安装。" 'Gray'
}

# ---------- 收尾 ----------
try { if (Test-Path -LiteralPath $drvDir) { Remove-Item -LiteralPath $drvDir -Recurse -Force -EA SilentlyContinue } } catch {}
if ($attachedVhdx) {
    Say ""
    Say ("  卸载临时挂载的虚拟磁盘：{0}" -f $attachedVhdx) 'DarkGray'
    Dismount-Vhdx -Path $attachedVhdx
    Say "  已卸载（不会留在「我的电脑」里）" 'DarkGray'
}
Say ""
Read-Host "  按回车退出"
