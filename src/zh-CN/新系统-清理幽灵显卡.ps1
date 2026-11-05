param()

# ============================================================
# 新系统 显卡体检与整理   v2.0
# 作者: connectsegabot
#
# 在哪运行：**新装的那个虚拟系统里**（不是原来的系统）。
#
# v1.0 的错误（用户实际反馈「根本没删掉幽灵显卡」）：
#   1. 把任务管理器里的「空 GPU」当成幽灵卡。其实任务管理器的 GPU 列表只枚举
#      **正在活动的适配器**，幽灵设备（设备已不在本机）从来不会出现在那里。
#      真正占着位置的是 ROOT\DISPLAY 枚举的 **IDD 虚拟显示器**
#      （远程串流 / 模拟器那类软件装的，Service=WUDFRd，没有真实 DX 引擎，
#      所以显存、3D、Video 全是空的）。
#   2. 只信 pnputil 的退出码。pnputil /remove-device 对 non-present 设备
#      会返回 0x0 但其实什么都没删，报告写「删除成功 3 个」而记录还在。
#      v2.0 删完必须重新枚举复核，报告里直接写「已消失 / 仍在」。
#   3. 删除顺序反了。Remove-PnpDevice 走 DIF_REMOVE，能处理不在位的设备；
#      pnputil 只是它的补充。v1.0 先试 pnputil 且判成功就跳过，等于永远不修。
#
# 结果文件：<某个盘>:\显卡诊断.txt
# ============================================================

$ErrorActionPreference = 'Continue'
$Script:Version = '1.31'
try { $Host.UI.RawUI.WindowTitle = "新系统 显卡体检 v$($Script:Version) - connectsegabot" } catch {}

function Say {
    param([string]$Text, [string]$Color = 'Gray')
    Write-Host $Text -ForegroundColor $Color
}

Say ""
Say "  新系统 显卡体检与整理  v$($Script:Version)" 'Cyan'
Say "  作者: connectsegabot" 'DarkGray'
Say "  ------------------------------------------------------------" 'DarkGray'
Say ""

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
    Say "  [错误] 需要管理员权限。请右键 -> 以管理员身份运行。" 'Red'
    Read-Host "  按回车退出"
    exit 1
}

$report = New-Object System.Collections.ArrayList
function Add-Line { param([string]$T = '') [void]$report.Add($T) }

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
Add-Line "=============== 显卡诊断 v$($Script:Version) ==============="
Add-Line ("计算机名 : " + $env:COMPUTERNAME)
Add-Line ("系统     : " + $os.Caption + "  Build " + $os.BuildNumber)
Add-Line ("系统盘   : " + $env:SystemDrive)
Add-Line ""

function Get-ProblemText {
    param([int]$Code)
    switch ($Code) {
        0  { return '正常' }
        3  { return '驱动已损坏' }
        10 { return '设备无法启动' }
        18 { return '需要重新安装驱动' }
        22 { return '已被禁用' }
        28 { return '驱动未安装' }
        31 { return '驱动无法加载' }
        43 { return '设备报告故障后已停止' }
        45 { return '幽灵记录（设备不在本机）' }
        default { return ("问题码 " + $Code) }
    }
}

# ---------- [1/5] 采集 ----------
Say "[1/5] 读取显示适配器..." 'White'

# 拿到任务管理器真正会枚举的那批（活动适配器）
$activeNames = @()
try {
    foreach ($vc in @(Get-CimInstance Win32_VideoController -ErrorAction SilentlyContinue)) {
        if ($vc.Name) { $activeNames += [string]$vc.Name }
    }
} catch {}

$adapters = @()
foreach ($d in @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue)) {
    if (-not $d) { continue }

    $present = $false
    try {
        $v = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_IsPresent' -ErrorAction Stop).Data
        if ($v -eq $true) { $present = $true }
    } catch {}

    $prov = ''; $ver = ''; $inf = ''; $svc = ''
    try { $prov = [string](Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverProvider' -ErrorAction Stop).Data } catch {}
    try { $ver = [string](Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverVersion' -ErrorAction Stop).Data } catch {}
    try { $inf = [string](Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_DriverInfPath' -ErrorAction Stop).Data } catch {}
    try { $svc = [string](Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_Service' -ErrorAction Stop).Data } catch {}

    $hw = @()
    try {
        $h = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_HardwareIds' -ErrorAction Stop).Data
        if ($h) { $hw = @($h) }
    } catch {}

    $prob = 0
    if ($d.Problem -ne $null) { $prob = [int]$d.Problem }

    # 【关键】IDD 虚拟显示器的识别：ROOT 枚举 + 类是 Display + 用户模式驱动框架。
    # 这类设备是软件造出来的假显卡，任务管理器会给它一个 GPU 位，
    # 但里面没有任何引擎/显存数据 —— 这就是用户说的「空 GPU」。
    $isRoot = $d.InstanceId -like 'ROOT\*'
    $isIdd = $false
    if ($isRoot) {
        if ($svc -eq 'WUDFRd' -or $svc -like '*Idd*' -or $d.FriendlyName -like '*Virtual*') { $isIdd = $true }
        else { $isIdd = $true }   # ROOT\DISPLAY 出来的都是软件适配器
    }

    $kind = ''
    if (-not $present) { $kind = '幽灵' }
    elseif ($isIdd) { $kind = '虚拟显示器' }
    elseif ($prob -ne 0) { $kind = '故障' }
    else { $kind = '在用' }

    $adapters += [pscustomobject]@{
        Name       = $d.FriendlyName
        InstanceId = $d.InstanceId
        Status     = [string]$d.Status
        Present    = $present
        Problem    = $prob
        Kind       = $kind
        IsIdd      = $isIdd
        Provider   = $prov
        Version    = $ver
        Inf        = $inf
        Service    = $svc
        HwIds      = $hw
    }
}

$realGpu = @($adapters | Where-Object { $_.Kind -eq '在用' })
$idds    = @($adapters | Where-Object { $_.Kind -eq '虚拟显示器' })
$ghosts  = @($adapters | Where-Object { $_.Kind -eq '幽灵' })
$faults  = @($adapters | Where-Object { $_.Kind -eq '故障' })
$disabled = @($adapters | Where-Object { $_.Status -eq 'Error' -and $_.Problem -eq 22 })

# ---------- [2/5] 摊开 ----------
Say "[2/5] 分类结果..."
Add-Line "---------- 显示适配器 ----------"
Add-Line ("共 {0} 个：真实在用 {1} / 虚拟显示器 {2} / 幽灵 {3} / 故障 {4}" -f `
    $adapters.Count, $realGpu.Count, $idds.Count, $ghosts.Count, $faults.Count)
Add-Line ""
Say ("  共 {0} 个：真实在用 {1} / 虚拟显示器 {2} / 幽灵 {3} / 故障 {4}" -f `
    $adapters.Count, $realGpu.Count, $idds.Count, $ghosts.Count, $faults.Count) 'Cyan'
Say ""

foreach ($a in $adapters) {
    $col = 'Gray'
    if ($a.Kind -eq '在用')       { $col = 'Green' }
    if ($a.Kind -eq '故障')       { $col = 'Yellow' }
    if ($a.Kind -eq '虚拟显示器') { $col = 'Magenta' }
    if ($a.Kind -eq '幽灵')       { $col = 'DarkGray' }

    Say ("  [{0}] {1}" -f $a.Kind, $a.Name) $col
    Say ("        状态={0}  驱动={1} {2}  INF={3}" -f (Get-ProblemText $a.Problem), $a.Provider, $a.Version, $a.Inf) 'DarkGray'
    Say ("        实例={0}" -f $a.InstanceId) 'DarkGray'

    Add-Line ("[{0}] {1}" -f $a.Kind, $a.Name)
    Add-Line ("    状态: " + (Get-ProblemText $a.Problem) + "  (Status=" + $a.Status + ", Present=" + $a.Present + ")")
    Add-Line ("    驱动: " + $a.Provider + " " + $a.Version + "  INF=" + $a.Inf + "  Service=" + $a.Service)
    Add-Line ("    实例: " + $a.InstanceId)
    if ($a.HwIds.Count -gt 0) { Add-Line ("    硬件: " + ($a.HwIds -join ' ; ')) }
    Add-Line ""
}

# ---------- [3/5] 结论：空 GPU 到底是谁 ----------
Say "[3/5] 判断任务管理器里那张空卡..." 'White'
Add-Line "---------- 空 GPU 的成因 ----------"

if ($idds.Count -gt 0) {
    Add-Line ("任务管理器「性能」页只枚举**正在活动的**显示适配器，不会为幽灵设备留位置。")
    Add-Line ("所以那张没有数据的空 GPU，真身是下面这些虚拟显示器（IDD）：")
    foreach ($i in $idds) {
        Add-Line ("    " + $i.Name + "   实例=" + $i.InstanceId + "   INF=" + $i.Inf)
    }
    Add-Line ""
    Add-Line "它们由远程串流 / 模拟器这类软件安装，没有真实 DX 引擎，显存和 3D 使用率永远是空的。"
    Say ("  空 GPU = 虚拟显示器（{0} 个），不是幽灵卡" -f $idds.Count) 'Yellow'
}
if ($ghosts.Count -gt 0) {
    Add-Line ("另外还有 {0} 个幽灵显示适配器（克隆镜像带来的历史记录）：" -f $ghosts.Count)
    foreach ($g in $ghosts) { Add-Line ("    " + $g.Name + "   " + $g.InstanceId) }
    Add-Line "幽灵设备不会出现在任务管理器，只会在「显示隐藏的设备」时看到，属于无害残留。"
    Say ("  另有 {0} 个幽灵记录（无害，只影响设备管理器观感）" -f $ghosts.Count) 'DarkGray'
}
if ($faults.Count -gt 0) {
    foreach ($f in $faults) { Add-Line ("故障适配器: " + $f.Name + " | " + (Get-ProblemText $f.Problem) + " | " + $f.InstanceId) }
    Say ("  有 {0} 个适配器处于故障状态（多为缺厂商驱动）" -f $faults.Count) 'Yellow'
}
if ($disabled.Count -gt 0) {
    foreach ($x in $disabled) { Add-Line ("已禁用适配器: " + $x.Name + " | " + $x.InstanceId) }
}
Add-Line ""

# ---------- [4/5] 操作 ----------
Add-Line "---------- 处理 ----------"
$didSomething = $false
$stillGhost = 0
$stillIddOn = 0

# 4a. 虚拟显示器 —— 这才是空 GPU 的解
if ($idds.Count -gt 0) {
    Say "[4/5] 消除空 GPU..." 'White'
    Say "      禁用虚拟显示器后，任务管理器里那张空卡会消失；" 'DarkGray'
    Say "      需要用串流/模拟器时再启用回来，随时可恢复。" 'DarkGray'
    Say ""
    foreach ($i in $idds) { Say ("      - " + $i.Name) 'Magenta' }
    Say ""
    $ans = Read-Host "  禁用这些虚拟显示器吗？输入 Y 回车执行，其他键跳过"
    if ($ans -match '^[Yy]') {
        foreach ($i in $idds) {
            $ok = $false
            $msg = ''
            try {
                Disable-PnpDevice -InstanceId $i.InstanceId -Confirm:$false -ErrorAction Stop
                $ok = $true
            } catch {
                $msg = $_.Exception.Message
                $o = (& pnputil /disable-device $i.InstanceId 2>&1 | Out-String)
                if ($LASTEXITCODE -eq 0) { $ok = $true; $msg = '' }
                elseif (-not $msg) { $msg = ($o -replace '\s+', ' ').Trim() }
            }
            # 复核：问题码变成 22（已禁用）才算真的生效
            $now = $null
            try { $now = Get-PnpDevice -InstanceId $i.InstanceId -ErrorAction Stop } catch {}
            $really = $false
            if ($now -ne $null -and $now.Problem -ne $null) {
                if ([int]$now.Problem -eq 22) { $really = $true }
            }
            if ($ok -and $really) {
                Say ("    已禁用: " + $i.Name) 'Green'
                Add-Line ("禁用成功: " + $i.Name + " | " + $i.InstanceId)
            } elseif ($ok -and -not $really) {
                Say ("    命令报成功但状态没变: " + $i.Name) 'Yellow'
                Add-Line ("禁用结果不确定: " + $i.Name + " | 命令返回成功但复核 Status=" + $(if ($now) { $now.Status } else { '无' }) + " Problem=" + $(if ($now) { $now.Problem } else { '无' }))
            } else {
                Say ("    禁用失败: " + $i.Name) 'Red'
                Add-Line ("禁用失败: " + $i.Name + " | " + $msg)
            }
        }
        $didSomething = $true
        Say ""
    } else {
        Add-Line "用户跳过禁用虚拟显示器"
        Say "      已跳过。" 'DarkGray'
        Say "      想手动处理：设备管理器 -> 显示适配器 -> 右键该项 -> 禁用设备" 'DarkGray'
        Say ""
    }
} else {
    Add-Line "没有虚拟显示器（ROOT\DISPLAY）—— 空 GPU 若仍存在，请说明是第几号。"
}

# 4b. 幽灵记录
if ($ghosts.Count -eq 0) {
    Say "  没有幽灵记录需要清理。" 'DarkGray'
} else {
    Say "  另发现 $($ghosts.Count) 个幽灵记录（镜像残留，不在本机，不影响使用）。" 'White'
    Say "      清掉只是让「显示隐藏的设备」时列表更干净。" 'DarkGray'
    Say ""
    $ans2 = Read-Host "  清理这些幽灵记录吗？输入 Y 回车执行，其他键跳过"
    if ($ans2 -match '^[Yy]') {
        foreach ($g in $ghosts) {
            $ok = $false; $via = ''; $msg = ''

            # 【顺序修正】先 Remove-PnpDevice（DIF_REMOVE 能处理不在位设备）
            try {
                Remove-PnpDevice -InstanceId $g.InstanceId -Confirm:$false -ErrorAction Stop
                $ok = $true; $via = 'Remove-PnpDevice'
            } catch {
                $msg = $_.Exception.Message
            }
            # 再退到 pnputil
            if (-not $ok) {
                $o = (& pnputil /remove-device $g.InstanceId 2>&1 | Out-String)
                if ($LASTEXITCODE -eq 0) { $ok = $true; $via = 'pnputil' }
                else { if (-not $msg) { $msg = ($o -replace '\s+', ' ').Trim() } }
            }

            # 【必须复核】命令说成功不代表真删了
            $still = $null
            try { $still = Get-PnpDevice -InstanceId $g.InstanceId -ErrorAction Stop } catch {}
            $gone = ($null -eq $still)

            if ($gone) {
                Say ("    已消失: " + $g.Name) 'Green'
                Add-Line ("幽灵已删除(" + $via + "): " + $g.InstanceId)
            } else {
                Say ("    仍然存在: " + $g.Name) 'Yellow'
                Add-Line ("幽灵未删除: " + $g.InstanceId + " | 尝试方式=" + $via + " | 命令结果=" + $(if ($ok) { '报成功' } else { '失败' }) + " | 错误=" + $msg)
                Add-Line "    说明: 该记录在注册表 Enum 里仍占位，需要手动处理（见下）"
            }
        }
        $didSomething = $true
    } else {
        Add-Line "用户跳过清理幽灵"
        Say "      已跳过。" 'DarkGray'
    }
}

# ---------- [5/5] 复核 ----------
if ($didSomething) {
    Say ""
    Say "[5/5] 复核当前状态..." 'White'
    Start-Sleep -Milliseconds 500
    $after = @(Get-PnpDevice -Class Display -ErrorAction SilentlyContinue)
    $stillGhost = 0
    $stillIddOn = 0
    foreach ($d in $after) {
        if (-not $d) { continue }
        $pres = $false
        try { $p = (Get-PnpDeviceProperty -InstanceId $d.InstanceId -KeyName 'DEVPKEY_Device_IsPresent' -ErrorAction Stop).Data; if ($p -eq $true) { $pres = $true } } catch {}
        $pr = 0
        if ($d.Problem -ne $null) { $pr = [int]$d.Problem }
        if (-not $pres) { $stillGhost++ }
        elseif ($d.InstanceId -like 'ROOT\*' -and $pr -ne 22) { $stillIddOn++ }
    }
    Add-Line ""
    Add-Line "---------- 复核结果 ----------"
    Add-Line ("剩余幽灵记录: " + $stillGhost)
    Add-Line ("仍启用的虚拟显示器: " + $stillIddOn)
    Say ("  复核：幽灵还剩 {0} 个，仍启用的虚拟显示器 {1} 个" -f $stillGhost, $stillIddOn) 'Cyan'
} else {
    Add-Line ""
    Add-Line "本次只做诊断，没有修改任何设备。"
}

# ---------- 写报告 ----------
Add-Line ""
Add-Line "==================== 诊断结束 ===================="

# 【v1.29】报告不再直接丢在盘根，统一进 <盘>:\虚拟硬盘系统-日志\
$saved = @()
foreach ($v in @(Get-Volume -ErrorAction SilentlyContinue)) {
    if (-not $v.DriveLetter) { continue }
    if ($v.DriveType -ne 'Fixed') { continue }
    $dir = "{0}:\虚拟硬盘系统-日志" -f $v.DriveLetter
    try {
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null
        }
        $p = Join-Path $dir '显卡诊断.txt'
        $report -join "`r`n" | Set-Content -LiteralPath $p -Encoding UTF8 -ErrorAction Stop
        $saved += $p
    } catch {}
}

Say ""
Say "  ------------------------------------------------------------" 'DarkGray'
foreach ($p in $saved) { Say ("  报告已保存: " + $p) 'Green' }

if ($stillGhost -gt 0) {
    Say ""
    Say "  仍有幽灵记录删不掉时的手动办法：" 'Yellow'
    Say "    设备管理器 -> 查看 -> 显示隐藏的设备 -> 显示适配器 ->" 'DarkGray'
    Say "    灰色那几项右键「卸载设备」-> 重启。" 'DarkGray'
}
Say ""
Say "  禁用虚拟显示器后要重启一次，任务管理器 GPU 列表才刷新。" 'Cyan'
Say ""
Read-Host "  按回车退出"
