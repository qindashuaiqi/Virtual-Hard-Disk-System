# 回归测试：卸载脚本的 bcdedit 输出「切块 + 取 GUID」逻辑
#
# 背景：v1.33 的卸载工具用 -split "(?m)^-{20,}" 按横线切块，而 bcdedit 的分隔线
# 长度等于表头文字长度（"Windows Boot Loader" 19 字符 → 19 个 '-'），永远不到 20，
# 于是整份 osloader 输出成了唯一一块，GUID 取到了排在前面那条原系统，把它连同
# winresume 一起删掉 → 重启 0xc0000098。
#
# 这个测试不复述业务代码，而是**从待测脚本里把 Split-BcdEntries 函数抠出来执行**，
# 保证测的就是真正发货的那份实现。
#
# 跑法：powershell -ExecutionPolicy Bypass -File src/build/test_bcd_parse.ps1

param([string]$Root = '')

$ErrorActionPreference = 'Stop'

# 三种跑法都要能找到仓库根：
#   1) powershell -File src/build/test_bcd_parse.ps1   → 用 $PSScriptRoot
#   2) 以 scriptblock 方式执行（ExecutionPolicy 受限时）→ 用调用方的当前目录
#   3) 显式 -Root
if (-not $Root) {
    if ($PSScriptRoot) { $Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot) }
    else { $Root = (Get-Location).Path }
}
$root = $Root

$script:Fail = 0
$script:Pass = 0

function Check([string]$Name, [bool]$Cond, [string]$Detail = '') {
    if ($Cond) {
        $script:Pass++
        Write-Host ("  PASS  " + $Name) -ForegroundColor Green
    } else {
        $script:Fail++
        Write-Host ("  FAIL  " + $Name) -ForegroundColor Red
        if ($Detail) { Write-Host ("        " + $Detail) -ForegroundColor Yellow }
    }
}

# ---------------------------------------------------------------- 测试数据
# 真实 bcdedit 输出的分隔线长度（不得改动）：
#   "Windows Boot Manager" = 20 字符 → 20 个 '-'
#   "Windows Boot Loader"  = 19 字符 → 19 个 '-'
$DASH_MGR = '-' * 20
$DASH_LDR = '-' * 19

$PHYS = '{6fb46eb1-d84c-11f1-8f96-95df667bdf44}'   # 原系统（物理分区）
$VHD  = '{a1b2c3d4-1111-2222-3333-444455556666}'   # 装进 vhdx 的那个

# `bcdedit /enum osloader /v` 的真实形态：没有 {bootmgr} 段，只有若干 loader 段，
# 每段表头 "Windows Boot Loader"（19 字符）+ 19 个 '-'。输出顺序：先原系统，后 vhdx。
$enumLdr = @(
    'Windows Boot Loader'
    $DASH_LDR
    'identifier              ' + $PHYS
    'device                  partition=C:'
    'path                    \windows\system32\winload.efi'
    'description             Windows Server 2022'
    'locale                  en-US'
    ''
    'Windows Boot Loader'
    $DASH_LDR
    'identifier              ' + $VHD
    'device                  vhd=[C:]\NewSystemDisk.vhdx'
    'path                    \windows\system32\winload.efi'
    'description             VHD System'
    'locale                  en-US'
) -join "`r`n"

# `bcdedit /enum {bootmgr}` 的形态：表头 20 字符 → 20 个 '-'
$enumMgr = @(
    'Windows Boot Manager'
    $DASH_MGR
    'identifier              {9dea862c-5cdd-4e70-acc1-f32b344d4795}'
    'device                  partition=\Device\HarddiskVolume1'
    'default                 ' + $PHYS
    'displayorder            ' + $PHYS
    'timeout                 30'
) -join "`r`n"

# 中文输出：表头是「Windows 启动加载器」，横线按本地化表头算，比 20 还短
$enumZhLdr = @(
    'Windows 启动加载器'
    '-' * 13
    '标识符                  ' + $PHYS
    'device                  partition=C:'
    'path                    \windows\system32\winload.efi'
    '描述                    Windows Server 2022'
    ''
    'Windows 启动加载器'
    '-' * 13
    '标识符                  ' + $VHD
    'device                  vhd=[C:]\NewSystemDisk.vhdx'
    'path                    \windows\system32\winload.efi'
    '描述                    VHD 系统'
) -join "`r`n"

$errText = @(
    '无法打开启动配置数据存储。'
    '拒绝访问。'
) -join "`r`n"

# ---------------------------------------------------------------- 抠出待测函数
function Get-EmbeddedFunction([string]$ScriptPath, [string]$Name) {
    $txt = [IO.File]::ReadAllText($ScriptPath, [Text.Encoding]::UTF8)
    $errs = $null
    $tokens = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($txt, [ref]$tokens, [ref]$errs)
    if ($errs -and $errs.Count -gt 0) {
        throw ("$ScriptPath 有语法错误: " + $errs[0].Message)
    }
    $fn = $ast.FindAll({
        param($n)
        $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $Name
    }, $true)
    if (-not $fn -or $fn.Count -eq 0) { throw "$ScriptPath 里找不到函数 $Name" }
    return $fn[0].Extent.Text
}

# v1.33 的老写法，用来复现事故（不是待测代码，只是对照组）
function Old-Split([string]$Text) {
    return @($Text -split "(?m)^-{20,}" | Where-Object { $_ -match '\S' })
}

function FirstGuid([string]$Block) {
    $m = [regex]::Match($Block, '(?:identifier|标识符)\s+(\{[0-9a-fA-F\-]+\})')
    if ($m.Success) { return $m.Groups[1].Value }
    return ''
}

# ---------------------------------------------------------------- 开测
$targets = @(
    'src/zh-CN/Uninstall-VHDSystem.ps1',
    'src/en/Uninstall-VHDSystem.ps1'
)

foreach ($rel in $targets) {
    $p = Join-Path $root $rel
    Write-Host ""
    Write-Host ("===== " + $rel) -ForegroundColor Cyan

    if (-not (Test-Path -LiteralPath $p)) {
        Check "文件存在" $false $p
        continue
    }

    $fnText = Get-EmbeddedFunction $p 'Split-BcdEntries'
    . ([scriptblock]::Create($fnText))

    # ---- 对照组：证明 v1.33 的老写法在这个输入上会塌成一块
    $old = Old-Split $enumLdr
    $oldWithId = @($old | Where-Object { FirstGuid $_ })
    Check "对照：老写法 -{20,} 切不开 19 横线的 osloader 输出" ($oldWithId.Count -eq 1) `
        ("实际切出 " + $oldWithId.Count + " 个带 GUID 的块")
    Check "对照：老写法因此取到原系统的 GUID（事故直接原因）" `
        ($oldWithId.Count -eq 1 -and (FirstGuid $oldWithId[0]) -eq $PHYS) `
        ("取到 " + $(if ($oldWithId.Count) { FirstGuid $oldWithId[0] } else { '<无>' }))

    # ---- 新写法：英文 osloader 输出
    $s = Split-BcdEntries $enumLdr
    $sWithId = @($s.Blocks | Where-Object { FirstGuid $_ })
    Check "英文输出解析成功" ($s.Ok -eq $true) ("Raw=" + $s.Raw + " Parsed=" + $s.Parsed)
    Check "英文输出切出 2 个启动项" ($sWithId.Count -eq 2) ("实际 " + $sWithId.Count)
    $hitBlk = @($s.Blocks | Where-Object { $_ -match [regex]::Escape('vhd=[C:]\NewSystemDisk.vhdx') })
    Check "按 vhd= 精确串只命中 1 块" ($hitBlk.Count -eq 1) ("实际 " + $hitBlk.Count)
    Check "命中的是 vhdx 条目而不是原系统" ($hitBlk.Count -eq 1 -and (FirstGuid $hitBlk[0]) -eq $VHD) `
        ("取到 " + $(if ($hitBlk.Count) { FirstGuid $hitBlk[0] } else { '<无>' }))

    # ---- 新写法：中文输出（横线更短）
    $z = Split-BcdEntries $enumZhLdr
    $zWithId = @($z.Blocks | Where-Object { FirstGuid $_ })
    Check "中文输出解析成功" ($z.Ok -eq $true) ("Raw=" + $z.Raw + " Parsed=" + $z.Parsed)
    Check "中文输出切出 2 个启动项" ($zWithId.Count -eq 2) ("实际 " + $zWithId.Count)
    $zhit = @($z.Blocks | Where-Object { $_ -match [regex]::Escape('vhd=[C:]\NewSystemDisk.vhdx') })
    Check "中文：命中的是 vhdx 条目" ($zhit.Count -eq 1 -and (FirstGuid $zhit[0]) -eq $VHD) `
        ("实际 " + $zhit.Count + " 块")

    # ---- 异常输入必须判失败，让上层停手
    $e = Split-BcdEntries $errText
    Check "错误文本被判为解析失败（Ok=false）" ($e.Ok -eq $false) ("Raw=" + $e.Raw)
    $n = Split-BcdEntries ''
    Check "空输出被判为解析失败（Ok=false）" ($n.Ok -eq $false)

    # ---- 只有 bootmgr 的输出（20 横线）也要正常
    $m = Split-BcdEntries $enumMgr
    $mWithId = @($m.Blocks | Where-Object { FirstGuid $_ })
    Check "bootmgr 输出解析成功" ($m.Ok -eq $true -and $mWithId.Count -eq 1) `
        ("Raw=" + $m.Raw + " Parsed=" + $m.Parsed + " 带GUID块=" + $mWithId.Count)
}

Write-Host ""
if ($script:Fail -gt 0) {
    Write-Host ("结果：$($script:Pass) passed, $($script:Fail) FAILED") -ForegroundColor Red
} else {
    Write-Host ("结果：$($script:Pass) passed, 0 failed") -ForegroundColor Green
}
