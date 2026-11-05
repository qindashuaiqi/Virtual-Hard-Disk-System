<#
  虚拟硬盘系统 - 卸载工具
  删除虚拟硬盘文件，并移除开机菜单里的对应启动项。原系统不受影响。
  支持装过多个系统：列表里每个系统单独一条，按名字删除。
  作者：connectsegabot
#>

$ErrorActionPreference = 'Stop'
$Script:Version = '1.31'
$Script:ProductName = '虚拟硬盘系统'

function Test-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    $p = New-Object Security.Principal.WindowsPrincipal($id)
    return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Request-Admin {
    try {
        # [审计 P1-8] 以前复制到固定名（uninstall-system-elevated.ps1）再提权执行。
        # 那个目录同用户可写，同用户的其它进程可以提前放一个同名文件，提权后执行的就是它。
        # 改成随机名，把"提前预置"这一半堵掉。复制→提权之间那点时间窗脚本关不掉，
        # 要彻底解决只能给发布物做 Authenticode 签名。
        $psi = Join-Path $env:TEMP ("uninstall-system-{0}.ps1" -f ([guid]::NewGuid().ToString('N').Substring(0, 12)))
        Copy-Item -LiteralPath $PSCommandPath -Destination $psi -Force
        Start-Process -FilePath 'powershell.exe' `
            -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-STA', '-File', "`"$psi`"") `
            -Verb RunAs -Wait
        Remove-Item -LiteralPath $psi -Force -ErrorAction SilentlyContinue
        return $true
    } catch {
        return $false
    }
}

# 判断当前是不是在新系统（虚拟磁盘）里运行。
# 卸载必须在原系统里做：在新系统里跑的话，删的正是自己正在用的那个 vhdx
# （文件被占用会失败，但更糟的是 bcdedit 只会改到 vhdx 内部那份 BCD，
# 对开机菜单完全没有作用，用户会以为「卸了但菜单还在」）。
function Test-RunningInVhd {
    try {
        $sys = $env:SystemDrive.TrimEnd(':')
        $part = Get-Partition -DriveLetter $sys -EA Stop | Select-Object -First 1
        if (-not $part) { return $false }
        $disk = Get-Disk -Number $part.DiskNumber -EA Stop
        return ([string]$disk.BusType -eq 'File Backed Virtual')
    } catch {
        return $false
    }
}

# >>> COMMON:Get-StateDisplayName
# 由 _源码\_build\sync_common.py 从 common\Get-StateDisplayName.ps1 注入。改这里没用。
function Get-StateDisplayName {
    param([string]$VhdPath)
    # 状态文件里「这个名字」有三个键（历史包袱）：Desc / Name / Description。
    # 安装器三个都写；修复工具 v1.4 只写了 Description；卸载器只读 Desc|Name。
    # 于是「用修复工具补过一次启动项」的系统，名字在安装器和卸载器里都是空的，
    # 自定义名字在这个边角上又丢一次。
    # 统一按 Desc → Name → Description 取，谁写的都能读出来。
    $st = [System.IO.Path]::ChangeExtension($VhdPath, '.boot.txt')
    if (-not (Test-Path -LiteralPath $st)) { return '' }
    $vals = @{}
    foreach ($ln in (Get-Content -LiteralPath $st -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        if ($ln -match '^\s*([^#=]+?)\s*=(.*)$') {
            $k = $matches[1].Trim().ToLower()
            if (-not $vals.ContainsKey($k)) { $vals[$k] = $matches[2].Trim() }
        }
    }
    foreach ($k in @('desc', 'name', 'description')) {
        if ($vals.ContainsKey($k) -and $vals[$k]) { return $vals[$k] }
    }
    return ''
}
# <<< COMMON:Get-StateDisplayName

# 找出装好的虚拟硬盘系统。
#
# v1.11 起由用户自己取名（WinVHD / 游戏系统 / WorkWin ... 都行），
# 所以不能再靠固定文件名，改成：
#   1. 固定盘根目录下所有 .vhdx（本工具只会装在这个位置）
#   2. 老版本的两种名字一定收进来（NewSystemDisk.vhdx / 新系统.vhdx），
#      即使文件被用户挪进子目录也能扫到
function Find-InstalledVhds {
    $legacy = @('NewSystemDisk.vhdx', '新系统.vhdx')
    $seen = @{}
    $found = @()

    function Add-Hit([string]$Path, [string]$Letter) {
        $key = $Path.ToLower()
        if ($seen.ContainsKey($key)) { return }
        $seen[$key] = $true
        $fi = Get-Item -LiteralPath $Path -EA SilentlyContinue
        if (-not $fi) { return }
        $desc = Get-StateDisplayName -VhdPath $Path
        $script:FoundVhds += [PSCustomObject]@{
            Path   = $Path
            SizeGB = [math]::Round($fi.Length / 1GB, 1)
            Letter = $Letter
            Desc   = $desc
            Name   = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        }
    }
    $script:FoundVhds = @()

    foreach ($vol in (Get-Volume -EA SilentlyContinue)) {
        if (-not $vol.DriveLetter) { continue }
        if ($vol.FileSystem -ne 'NTFS') { continue }
        if ($vol.DriveType -ne 'Fixed') { continue }
        $letter = $vol.DriveLetter

        # 【v1.9】除了盘根，还要往下找。
        # 以前只扫根目录，装到 D:\虚拟磁盘\maimai.vhdx 的系统卸载器完全看不见。
        # 用广度优先 + 目录名剪枝：不进系统目录和回收站，深度开到 6 也很快。
        $skip = @('$RECYCLE.BIN', 'System Volume Information', 'Windows', 'Program Files',
                  'Program Files (x86)', 'ProgramData', 'Users', '$WinREAgent', 'Recovery',
                  'node_modules', '.git', 'WinSxS')
        $queue = New-Object System.Collections.Queue
        $queue.Enqueue(@("$($letter):\", 0))
        while ($queue.Count -gt 0) {
            $cur = $queue.Dequeue()
            $dir = [string]$cur[0]
            $d = [int]$cur[1]
            try {
                foreach ($f in [System.IO.Directory]::GetFiles($dir, '*.vhdx')) { Add-Hit $f $letter }
            } catch {}
            if ($d -ge 6) { continue }
            try {
                foreach ($sub in [System.IO.Directory]::EnumerateDirectories($dir)) {
                    if ($skip -contains [System.IO.Path]::GetFileName($sub)) { continue }
                    try {
                        if ([System.IO.File]::GetAttributes($sub) -band [System.IO.FileAttributes]::ReparsePoint) { continue }
                    } catch { continue }
                    $queue.Enqueue(@($sub, ($d + 1)))
                }
            } catch {}
        }

        # 老名字兜底（万一被放进了找不到的深目录，至少这几个固定名还能认出来）
        foreach ($n in $legacy) {
            # 这里原来写的是 "$root$n" —— $root 在整个脚本里从没定义过（只有 $rootLen），
            # 展开成空串就成了相对路径 "NewSystemDisk.vhdx"，Test-Path 永远为假，
            # 兜底等于没有。$letter 是当前卷的盘符，拼完整路径才对。
            $p = "$($letter):\$n"
            if (Test-Path -LiteralPath $p) { Add-Hit $p $letter }
        }
    }
    $found = @($script:FoundVhds)
    return $found
}

function Show-Gui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()

    $form = New-Object System.Windows.Forms.Form
    $form.Text = "卸载虚拟系统 v$($Script:Version) - connectsegabot"
    $form.Size = New-Object System.Drawing.Size(680, 500)
    $form.StartPosition = 'CenterScreen'
    $form.FormBorderStyle = 'FixedSingle'
    $form.MaximizeBox = $false
    $form.BackColor = [System.Drawing.Color]::FromArgb(247, 248, 250)
    $form.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9)

    $header = New-Object System.Windows.Forms.Panel
    $header.Location = New-Object System.Drawing.Point(0, 0)
    $header.Size = New-Object System.Drawing.Size(680, 76)
    $header.BackColor = [System.Drawing.Color]::FromArgb(120, 46, 46)
    $form.Controls.Add($header)

    $lblTitle = New-Object System.Windows.Forms.Label
    $lblTitle.Text = "卸载虚拟系统"
    $lblTitle.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 18, [System.Drawing.FontStyle]::Bold)
    $lblTitle.ForeColor = [System.Drawing.Color]::White
    $lblTitle.Location = New-Object System.Drawing.Point(24, 12)
    $lblTitle.Size = New-Object System.Drawing.Size(300, 34)
    $header.Controls.Add($lblTitle)

    $lblSub = New-Object System.Windows.Forms.Label
    $lblSub.Text = "删除装好的虚拟系统，并移除开机菜单里的启动项。原系统不会被改动。  作者：connectsegabot"
    $lblSub.ForeColor = [System.Drawing.Color]::FromArgb(232, 190, 190)
    $lblSub.Location = New-Object System.Drawing.Point(26, 48)
    $lblSub.Size = New-Object System.Drawing.Size(600, 20)
    $header.Controls.Add($lblSub)

    $listBox = New-Object System.Windows.Forms.ListBox
    $listBox.Location = New-Object System.Drawing.Point(24, 94)
    $listBox.Size = New-Object System.Drawing.Size(620, 130)
    $listBox.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 9.5)
    $form.Controls.Add($listBox)

    $lblInfo = New-Object System.Windows.Forms.Label
    $lblInfo.Text = "正在查找..."
    $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(90, 100, 115)
    $lblInfo.Location = New-Object System.Drawing.Point(26, 232)
    $lblInfo.Size = New-Object System.Drawing.Size(618, 40)
    $form.Controls.Add($lblInfo)

    $logBox = New-Object System.Windows.Forms.TextBox
    $logBox.Location = New-Object System.Drawing.Point(24, 278)
    $logBox.Size = New-Object System.Drawing.Size(620, 120)
    $logBox.Multiline = $true
    $logBox.ScrollBars = 'Vertical'
    $logBox.ReadOnly = $true
    $logBox.BackColor = [System.Drawing.Color]::FromArgb(252, 252, 253)
    $logBox.ForeColor = [System.Drawing.Color]::FromArgb(68, 78, 92)
    $logBox.Font = New-Object System.Drawing.Font('Consolas', 8.5)
    $logBox.BorderStyle = 'FixedSingle'
    $form.Controls.Add($logBox)

    $btnUninstall = New-Object System.Windows.Forms.Button
    $btnUninstall.Text = "删除选中的系统"
    $btnUninstall.Location = New-Object System.Drawing.Point(24, 410)
    $btnUninstall.Size = New-Object System.Drawing.Size(180, 40)
    $btnUninstall.BackColor = [System.Drawing.Color]::FromArgb(180, 52, 52)
    $btnUninstall.ForeColor = [System.Drawing.Color]::White
    $btnUninstall.FlatStyle = 'Flat'
    $btnUninstall.FlatAppearance.BorderSize = 0
    $btnUninstall.Font = New-Object System.Drawing.Font('Microsoft YaHei UI', 10.5, [System.Drawing.FontStyle]::Bold)
    $btnUninstall.Enabled = $false
    $form.Controls.Add($btnUninstall)

    $btnClose = New-Object System.Windows.Forms.Button
    $btnClose.Text = "关闭"
    $btnClose.Location = New-Object System.Drawing.Point(544, 410)
    $btnClose.Size = New-Object System.Drawing.Size(100, 40)
    $btnClose.FlatStyle = 'System'
    $form.Controls.Add($btnClose)
    $btnClose.Add_Click({ $form.Close() })

    function Log([string]$m) {
        # 方法调用的参数按逗号切分，-f 只能拿到第一个参数，必须先生成整行
        $line = '[' + (Get-Date).ToString('HH:mm:ss') + '] ' + $m + "`r`n"
        $logBox.AppendText($line)
        $logBox.SelectionStart = $logBox.TextLength
        $logBox.ScrollToCaret()
        [System.Windows.Forms.Application]::DoEvents()
    }

    $script:Items = @()

    function Refresh-List {
        $listBox.Items.Clear()
        $script:Items = Find-InstalledVhds
        if (@($script:Items).Count -eq 0) {
            $lblInfo.Text = "没有找到装好的虚拟系统。可能已经卸载过了。"
            $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(118, 128, 144)
            $btnUninstall.Enabled = $false
            return
        }
        # v1.8：支持自定义名称后，同一个目录下可能有多个 vhdx，
        # 列表第一列显示系统名称（开机菜单里看到的名字），换行再显示文件路径。
        foreach ($it in $script:Items) {
            $label = $it.Desc
            if (-not $label) { $label = $it.Name }
            if (-not $label) { $label = [System.IO.Path]::GetFileNameWithoutExtension($it.Path) }
            [void]$listBox.Items.Add("$label    占用 $($it.SizeGB) GB    $($it.Path)")
        }
        $listBox.SelectedIndex = 0
        $lblInfo.Text = "找到 $(@($script:Items).Count) 个。删除后该系统的数据会全部消失，无法恢复。"
        $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(150, 90, 40)
        $btnUninstall.Enabled = $true
    }

    $listBox.Add_SelectedIndexChanged({
        $btnUninstall.Enabled = ($listBox.SelectedIndex -ge 0 -and @($script:Items).Count -gt 0)
    })

    $btnUninstall.Add_Click({
        if ($listBox.SelectedIndex -lt 0) { return }
        $it = $script:Items[$listBox.SelectedIndex]

        $itName = $it.Desc
        if (-not $itName) { $itName = $it.Name }
        if (-not $itName) { $itName = [System.IO.Path]::GetFileNameWithoutExtension($it.Path) }
        $r = [System.Windows.Forms.MessageBox]::Show(
            "即将删除：`n`n$itName`n$($it.Path)`n占用 $($it.SizeGB) GB`n`n" +
            "这个虚拟系统里的所有数据都会消失，且无法恢复。`n" +
            "同时会从开机菜单里移除对应启动项。`n`n" +
            "原系统（你现在用的这个）不会受到任何影响。`n`n" +
            "确认删除吗？",
            '确认删除',
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Warning,
            [System.Windows.Forms.MessageBoxDefaultButton]::Button2)
        if ($r -ne 'Yes') { return }

        $btnUninstall.Enabled = $false
        try {
            Log "=== 开始卸载 ==="
            Log "目标: $($it.Path)"

            # 1. 移除 BCD 启动项
            #
            # 优先按安装时记下的 GUID 精确删除（v1.4 起会写 Xxx.boot.txt），
            # 找不到状态文件再退回「扫全库找含 vhdx 文件名的条目」。
            $fileName = [System.IO.Path]::GetFileName($it.Path)
            $statePath = [System.IO.Path]::ChangeExtension($it.Path, '.boot.txt')
            $stateGuid = ''
            $origTimeout = ''
            $origDisplay = ''
            $origDisplaySet = ''
            if (Test-Path -LiteralPath $statePath) {
                $sd = @{}
                foreach ($ln in (Get-Content -LiteralPath $statePath -Encoding UTF8 -EA SilentlyContinue)) {
                    if ($ln -match '^\s*([^#=]+)=(.*)$') { $sd[$matches[1].Trim()] = $matches[2].Trim() }
                }
                if ($sd['Guid'] -match '^\{[0-9a-fA-F-]{36}\}$') { $stateGuid = $sd['Guid'] }
                if ($sd['OrigTimeout']) { $origTimeout = $sd['OrigTimeout'] }
                if ($sd['OrigDisplayMenu']) { $origDisplay = $sd['OrigDisplayMenu'] }
                # v1.7 起才有这个键：1 = 安装前 BCD 里确实写过 displaybootmenu，0 = 原本没有这一项。
                # 老状态文件没这个键，留空，按老逻辑走安全方向。
                if ($sd.ContainsKey('OrigDisplayMenuSet')) { $origDisplaySet = [string]$sd['OrigDisplayMenuSet'] }
                Log "状态文件：条目 $stateGuid，原 timeout=$origTimeout displaybootmenu=$origDisplay（显式写入=$origDisplaySet）"
            }

            $removed = 0
            if ($stateGuid) {
                $del = & bcdedit /delete "$stateGuid" /f 2>&1 | Out-String
                $t = ($del -replace '\s+', ' ').Trim()
                Log "按记录删除 $stateGuid => $t"
                if ($del -notmatch '找不到|not found|无效|invalid|拒绝|denied') { $removed++ }
            }

            # 只删指向「这一个 vhdx 文件」的条目。
            #
            # 光比文件名不够：本工具在每块盘根目录都叫 NewSystemDisk.vhdx，
            # 用户在两块盘各装了一份时（D:\ 和 E:\），按文件名删会把不该删的一起删。
            # 安装时写进 BCD 的是完整设备路径 vhd=[D:]\NewSystemDisk.vhdx，
            # 所以先按这个精确串匹配；一个都没命中再退回文件名兜底。
            $vhdLetter = ''
            $exactDev = ''
            try {
                $vhdLetter = [System.IO.Path]::GetPathRoot($it.Path).TrimEnd('\').TrimEnd(':')
                # 【v1.9】精确串要带子目录。
                # 装到 D:\虚拟磁盘\maimai.vhdx 时，BCD 里写的是 vhd=[D:]\虚拟磁盘\maimai.vhdx；
                # 只用文件名拼出 vhd=[D:]\maimai.vhdx 永远对不上，每次都得走兜底，容易误伤。
                $rootLen = [System.IO.Path]::GetPathRoot($it.Path).Length
                $rel = $it.Path.Substring($rootLen).TrimStart('\')
                if ($vhdLetter -and $rel) { $exactDev = "vhd=[$($vhdLetter):]\$rel" }
            } catch {}
            if ($exactDev) { Log "精确匹配目标: $exactDev" }

            Log "查找启动项（含 $fileName 的 VHD 引导）"

            $bcdOut = & bcdedit /enum osloader /v 2>&1 | Out-String
            $blocks = $bcdOut -split "(?m)^-{20,}" | Where-Object { $_ -match '\S' }

            # 注意：-match 会刷新 $Matches，所以 GUID 必须在第二次匹配之前先取出来
            $hit = New-Object System.Collections.ArrayList
            if ($exactDev) {
                foreach ($blk in $blocks) {
                    if ($blk -notmatch '(?:identifier|标识符)\s+(\{[0-9a-fA-F\-]+\})') { continue }
                    $g = $Matches[1]
                    if ($blk -match [regex]::Escape($exactDev)) {
                        [void]$hit.Add([PSCustomObject]@{ Guid = $g; Block = $blk })
                    }
                }
            }

            $matchMode = '精确路径'
            if ($hit.Count -eq 0) {
                # 精确串对不上（比如老版本写成 vhd=[D:]\sub\NewSystemDisk.vhdx）时的兜底。
                #
                # 兜底也不能一把抓：两块盘各装一份时文件名完全一样，
                # 所以先在「盘符相同」的条目里找，找到了就只删这些；
                # 还找不到（盘符也变了，如 D: 被改成了 F:）才放开比全文件名。
                $sameLetter = New-Object System.Collections.ArrayList
                $sameName = New-Object System.Collections.ArrayList
                foreach ($blk in $blocks) {
                    # 【中英双语】bcdedit 输出跟随系统语言：
                    #   英文 → identifier / description，中文 → 标识符 / 描述
                    if ($blk -notmatch '(?:identifier|标识符)\s+(\{[0-9a-fA-F\-]+\})') { continue }
                    $g = $Matches[1]
                    if (-not (($blk -match '\.vhdx') -or ($blk -match 'vhd='))) { continue }
                    if ($blk -notmatch [regex]::Escape($fileName)) { continue }

                    [void]$sameName.Add([PSCustomObject]@{ Guid = $g; Block = $blk })
                    if ($vhdLetter -and ($blk -match [regex]::Escape("vhd=[$($vhdLetter):"))) {
                        [void]$sameLetter.Add([PSCustomObject]@{ Guid = $g; Block = $blk })
                    }
                }
                if ($sameLetter.Count -gt 0) {
                    $matchMode = "同盘符兜底（$($vhdLetter):）"
                    foreach ($x in $sameLetter) { [void]$hit.Add($x) }
                } else {
                    $matchMode = '仅文件名兜底（风险：可能命中别的盘上的同名系统）'
                    foreach ($x in $sameName) { [void]$hit.Add($x) }
                }
            }
            if ($hit.Count -gt 0) { Log "命中 $($hit.Count) 个启动项（$matchMode）" }
            if ($matchMode -like '仅文件名*' -and $hit.Count -gt 1) {
                Log "警告：找不到盘符能对上的条目，按文件名命中了 $($hit.Count) 个 —— 可能包含别的盘上的同名系统，请核对后再决定"
            }

            foreach ($h in $hit) {
                $desc = ''
                if ($h.Block -match '(?:description|描述)\s+(.+?)\r?\n') { $desc = $Matches[1].Trim() }
                Log "发现启动项: $($h.Guid)  $desc"
                $del = & bcdedit /delete "$($h.Guid)" /f 2>&1 | Out-String
                Log "删除: $(($del -replace '\s+', ' ').Trim())"
                $removed++
            }
            Log "共移除 $removed 个启动项"

            # 数一下删完之后还剩几个系统，用来判断菜单该不该保留
            $left = 0
            try {
                # 【v1.13】恢复分区（device ramdisk=）不是用户能选的系统，不能算进「还剩几个系统」。
                # 否则「原系统 + 恢复分区」的单系统机器也会被当成多系统，菜单永远关不掉。
                $after = (& bcdedit /enum osloader /v 2>&1 | Out-String)
                foreach ($ab in @($after -split '(?m)^-{20,}' | Where-Object { $_ -match '\S' })) {
                    if ($ab -match '(?im)^\s*device\s+ramdisk=') { continue }
                    if ($ab -match '(?:identifier|标识符)\s+\{') { $left++ }
                }
            } catch {}
            Log "剩余启动项: $left 个"

            # 还原开机菜单：装的时候可能改过 displaybootmenu / timeout，
            # 这里按状态文件里记下的原始值还原（不是硬编码 timeout==0）。
            if ($removed -gt 0) {
                # 【v1.13】机器上还剩别的系统时，绝不能把菜单关掉。
                #
                # 老逻辑无条件按状态文件还原成「安装前的 displaybootmenu / timeout」。
                # 一台机器上装了两个 VHDX 系统、只卸载其中一个时，剩下那个的条目
                # 其实还在 BCD 里，菜单却被还原成「安装前的关 / 超时 0」——
                # 用户看到的就是「重启后菜单里只剩原系统，另一个系统再也进不去」。
                #
                # 判据用「删完之后还剩几个真实系统」（$left 已排除恢复分区）：
                #   >= 2 → 有得选，菜单必须留着；= 1 → 只剩原系统，按原状还原。
                $keepMenu = ($left -ge 2)
                if ($keepMenu) {
                    & bcdedit /set '{bootmgr}' displaybootmenu Yes 2>&1 | Out-Null
                    $t2 = 10
                    if ($origTimeout -match '^\d+$' -and [int]$origTimeout -gt 0) { $t2 = [int]$origTimeout }
                    & bcdedit /set '{bootmgr}' timeout $t2 2>&1 | Out-Null
                    Log "还剩 $left 个系统，保持开机菜单显示（displaybootmenu=Yes, timeout=$t2），否则剩下的系统进不去"
                } else {
                    if ($origTimeout -ne '') {
                        & bcdedit /set '{bootmgr}' timeout $origTimeout 2>&1 | Out-Null
                        Log "已把开机菜单超时还原为 $origTimeout"
                    }
                    if ($origDisplay -eq 'Yes') {
                        & bcdedit /set '{bootmgr}' displaybootmenu Yes 2>&1 | Out-Null
                        Log "已把 displaybootmenu 还原为 Yes（安装前本来就显式开着菜单）"
                    } elseif ($origDisplaySet -eq '1' -and $origDisplay -eq 'No') {
                        & bcdedit /set '{bootmgr}' displaybootmenu No 2>&1 | Out-Null
                        Log "已把 displaybootmenu 还原为 No（安装前就是显式关掉的）"
                    } else {
                        # 安装前 BCD 里压根没有 displaybootmenu 这一项 → 用 /deletevalue 恢复成「未设置」，
                        # 而不是硬设 No：
                        #   · 单系统：未设置 = bootmgr 本来就不弹菜单 → 照样直接进原系统
                        #   · 多系统：未设置 = 正常弹菜单 → 用户原来的双系统菜单保住了
                        $dv = & bcdedit /deletevalue '{bootmgr}' displaybootmenu 2>&1 | Out-String
                        Log ("已清除 displaybootmenu 设置，恢复系统默认 => " + (($dv -replace '\s+', ' ').Trim()))
                    }
                }
            }

            # 清掉残留的一次性直通（bootsequence）：这个值正常在首次启动后被
            # winload 自动清除，但启动被打断时会赖着不走 —— 菜单从此被短路，
            # 上面的还原全部白做。卸载收尾时顺手清一次，没有该值就静默跳过。
            try {
                $bsRaw = (& bcdedit /enum '{bootmgr}' 2>&1 | Out-String)
                if ($bsRaw -match '(?im)^\s*bootsequence\s') {
                    $bsDel = & bcdedit /deletevalue '{bootmgr}' bootsequence 2>&1 | Out-String
                    Log ("发现残留的 bootsequence（一次性直通），已清除 => " + (($bsDel -replace '\s+', ' ').Trim()))
                }
            } catch {}

            # 2. 删除 vhdx
            if (Test-Path -LiteralPath $it.Path) {
                Log "删除文件: $($it.Path)"
                Remove-Item -LiteralPath $it.Path -Force -EA Stop
                Log "文件已删除"
            }
            if (Test-Path -LiteralPath $statePath) {
                Remove-Item -LiteralPath $statePath -Force -EA SilentlyContinue
            }

            # 3. 摘掉安装/修复工具可能遗留在物理 ESP 上的临时盘符
            #
            # 老版修复工具（v1.0）会给物理 ESP 挂个盘符（常见 S:）去读写 BCD，
            # 后来改走活动存储后不再需要盘符，但早期挂上去的可能没摘干净，
            # 就变成「卸载后 S 盘还残留」的现象。
            # 这里扫一遍所有分区：凡是「EFI 系统分区（GUID c12a7328-...）却占着
            # 一个非系统盘符」的，说明是残留，摘掉（不改数据，只是去掉访问路径）。
            $espGuid = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
            $sysLetter = $env:SystemDrive.TrimEnd(':')
            $released = 0
            foreach ($part in (Get-Partition -EA SilentlyContinue)) {
                if (-not $part.DriveLetter) { continue }
                $gpt = [string]$part.GptType
                $gpt = ($gpt -replace '[{}]', '').ToLower()
                if ($gpt -ne $espGuid) { continue }
                if ([string]$part.DriveLetter -eq $sysLetter) { continue }
                $dl = [string]$part.DriveLetter
                try {
                    # 用 -DriveLetter 而不是 -AccessPath "S:"：
                    # -AccessPath 要的是卷访问路径（形如 "S:\"），传 "S:" 会被判参数无效；
                    # 而 catch 只记一行日志，于是盘符没摘掉、用户却以为清了。
                    Remove-PartitionAccessPath -DiskNumber $part.DiskNumber `
                        -PartitionNumber $part.PartitionNumber -DriveLetter $dl -EA Stop | Out-Null
                    Log "已摘除残留的 ESP 盘符 $dl`:"
                    $released++
                } catch {
                    Log "摘除盘符 $dl 失败（可手动在磁盘管理里移除）: $($_.Exception.Message)"
                }
            }
            if ($released -eq 0) { Log "没有发现残留的 ESP 盘符" }

            Log "=== 卸载完成 ==="
            [System.Windows.Forms.MessageBox]::Show(
                "卸载完成。`n`n虚拟硬盘已删除，启动项已移除。`n`n下次开机菜单里就不会再出现「$itName」了。`n" +
                "（如果菜单里还剩一项，可以忽略，或重启一次让它自动清理。）",
                '完成',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Information) | Out-Null

            Refresh-List
        } catch {
            Log "失败: $_"
            [System.Windows.Forms.MessageBox]::Show(
                "删除失败：`n`n$_`n`n" +
                "可能是文件正被占用。建议：`n" +
                "  1. 重启电脑后立刻运行本工具`n" +
                "  2. 或手动删除该文件`n`n" +
                "启动项可以用命令清理：`n" +
                "  bcdedit /enum osloader`n" +
                "  bcdedit /delete {对应GUID} /f",
                '删除失败',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Error) | Out-Null
        } finally {
            $btnUninstall.Enabled = ($listBox.SelectedIndex -ge 0)
        }
    })

    $form.Add_Shown({
        if (-not (Test-Admin)) {
            $r = [System.Windows.Forms.MessageBox]::Show(
                "卸载需要管理员权限。点「是」以管理员身份重新启动。",
                '需要管理员权限',
                [System.Windows.Forms.MessageBoxButtons]::YesNo,
                [System.Windows.Forms.MessageBoxIcon]::Information)
            if ($r -eq 'Yes') {
                if (Request-Admin) { $form.Close(); return }
            }
            $lblInfo.Text = "缺少管理员权限，可能无法删除"
            $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(190, 90, 60)
        }
        Log "卸载工具启动 v$($Script:Version)"
        Refresh-List

        # 【安全闸】在新系统里运行时禁止卸载（见 Test-RunningInVhd 注释）
        if (Test-RunningInVhd) {
            $btnUninstall.Enabled = $false
            $lblInfo.Text = "当前正运行在新系统里 —— 请重启回原系统再卸载。"
            $lblInfo.ForeColor = [System.Drawing.Color]::FromArgb(190, 60, 60)
            Log "检测到当前系统运行在虚拟磁盘上，已禁用删除"
            [System.Windows.Forms.MessageBox]::Show(
                "你正在新系统里运行这个工具。`n`n" +
                "卸载必须在原系统里做：这里的删除操作只会改到新系统自己的引导，`n" +
                "开机菜单里的那一项仍然会在。`n`n" +
                "请重启，在开机菜单里选原来的系统，然后再运行本工具。",
                '请回原系统卸载',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Warning) | Out-Null
        }
    })

    [void]$form.ShowDialog()
}

try {
    Show-Gui
} catch {
    Write-Host "启动失败: $_" -ForegroundColor Red
    Read-Host "按回车退出"
}
