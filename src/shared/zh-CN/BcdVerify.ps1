# ============================================================
# BCD 相关工具函数，安装器 / 卸载器 / 修复工具 / 「修好菜单指向」共用。
#
# 打包时由 src/build/inline_shared.py 内联进每个脚本（发布形态是单个自解压 bat，
# 载荷只有一个 ps1），所以引用它的脚本各自带一份；源码里始终只有这一份。
#
# 在脚本里这样引用：
#     . "$PSScriptRoot\..\shared\zh-CN\BcdVerify.ps1"
# ============================================================

# 逐字比对「要写入的设备路径」和 bcdedit 回显的结果。
#
# 控制台代码页显示不了的字会变成 "?"：中文目录名回读成 "?" 时逐字节比对必然不相等，
# 但 BCD 里存的是对的。这里只在「期望字符本身非 ASCII」的位置接受 "?"，其余一律要求相同：
# 长度必须一致，所有 ASCII 字符必须完全一致。
function Test-BcdTextSame {
    param([string]$Want, [string]$Got)
    if ($null -eq $Got) { return $false }
    if ($Got -eq $Want) { return $true }
    if ($Got.Length -ne $Want.Length) { return $false }
    for ($i = 0; $i -lt $Want.Length; $i++) {
        if ($Got[$i] -eq $Want[$i]) { continue }
        if ($Got[$i] -eq '?' -and [int][char]$Want[$i] -gt 127) { continue }
        return $false
    }
    return $true
}

# 带 vhd= 的只有 device 那一行。前面的字段名随系统语言变（device / Gerät / デバイス / 设备），
# 所以永远不比对字段名，只取值。
function Get-BcdDeviceFromOutput {
    param([string]$Text)
    $m = [regex]::Match([string]$Text, '(?im)^[^\r\n]*?(vhd=\[[^\r\n]+)')
    if (-not $m.Success) { return '' }
    return $m.Groups[1].Value.Trim()
}

# 【v1.36】这一块是不是真的操作系统加载项（而不是恢复环境 / 内存诊断 / WinRE 桩）？
#
# 值和标签之间的那个词是本地化的 —— device / 设备 / Gerät / デバイス —— 所以永远不比对标签，
# 只取值。老写法要求必须出现英文 "device"，在把它本地化的系统上会跳过所有条目，
# 于是「删完自检」以为一个可启动系统都不剩，把健康的 BCD 用备份覆盖了。
function Test-BcdBlockIsLoader {
    param([string]$Text)
    if (Get-BcdDeviceFromOutput -Text $Text) { return $true }        # 任何 vhd= 条目
    return [bool]([regex]::IsMatch([string]$Text, '(?im)^[^\r\n]*?\bpartition=[^\s\r\n]+'))
}

# 【v1.36】删掉一个启动项，并说明它到底有没有被删掉。
#
# 老写法靠「输出里有没有『找不到』/『not found』/『invalid』」判断成败。
# 英文启动器开头 chcp 437，中文 bcdedit 的错误信息会变成乱码，一个关键词都匹配不上，
# 于是**删除失败也被记成成功** —— 卸载器接着把 vhdx 删了，菜单里留下一条指向
# 不存在文件的条目，下次开机选中就报 0xc000000f。
#
# 退出码不受系统语言影响：0 = 删掉了，非 0 = 没删掉。
function Remove-BcdEntry {
    param(
        [Parameter(Mandatory = $true)][string]$Guid,
        # 只有单元测试会传别的（一个故意返回非 0 的桩）。
        [string]$BcdExe = 'bcdedit.exe'
    )
    $res = [PSCustomObject]@{ Ok = $false; Code = -1; Text = '' }
    try {
        $out = (& $BcdExe /delete "$Guid" /f 2>&1 | Out-String)
        $res.Code = $LASTEXITCODE
        $res.Text = (($out -replace '\s+', ' ').Trim())
        $res.Ok = ($res.Code -eq 0)
    } catch {
        $res.Text = $_.Exception.Message
    }
    return $res
}

# 【v1.36】启动项处理完之后，这块 vhdx 到底能不能删？
#
# v1.35 是无条件删。可一旦上面刚判过「证不了哪条属于这块盘，已跳过不删」，
# 结果就是文件没了、菜单条目还在 —— 下次开机选中就报 0xc000000f。
#
# 规则：只有「什么都没匹配到」或「确实删掉了条目」才允许删文件。
# 「匹配到但删不掉」「多个同名候选」「记录里的条目对不上了」都意味着：停下，把盘留下。
function Get-UninstallDeleteVerdict {
    param(
        [int]$Removed = 0,
        [int]$HitCount = 0,
        [int]$CandidateCount = 0,
        [bool]$StateRefused = $false
    )
    if ($Removed -gt 0) {
        return [PSCustomObject]@{ Allow = $true; Reason = '' }
    }
    if ($HitCount -gt 0) {
        return [PSCustomObject]@{ Allow = $false; Reason = "命中了 $HitCount 个启动项，但一个都没删掉" }
    }
    if ($CandidateCount -gt 0) {
        return [PSCustomObject]@{ Allow = $false; Reason = "有 $CandidateCount 个启动项带同名文件，但一个都无法证明属于这个 vhdx" }
    }
    if ($StateRefused) {
        return [PSCustomObject]@{ Allow = $false; Reason = '状态文件里记的条目已经不再指向这个 vhdx' }
    }
    return [PSCustomObject]@{ Allow = $true; Reason = '没有任何启动项指向这个文件' }
}

# 【v1.36】让 bcdedit 的输出原样保留非 ASCII 字符。
#
# 2026-11-13 在 Windows 10 22H2 简体中文 + Windows PowerShell 5.1 上实测：
#   * 控制台程序的 stdout 被重定向时写出的是 ANSI 字节（这里是 GBK），
#     而 PowerShell 用 [Console]::OutputEncoding 去解码；
#   * 英文启动器开头执行 chcp 437，两边对不上，于是每个汉字回读成 "?"，
#     或者一个汉字变成两个乱码字符；
#   * 给 [Console]::OutputEncoding 赋值会连带切换控制台代码页（.NET 的 setter 会调
#     SetConsoleOutputCP），所以把它设成 ANSI 代码页，写的一侧和读的一侧就统一了。
#
# 返回 @{ Ok; Text; CodePage }。Ok=$false 表示 bcdedit 起不来或没有输出，
# 调用方必须退回原来的直接调用，绝不能把它当成「路径写错了」。
function Get-BcdOutputExact {
    param(
        [string[]]$BcdArgs,
        # 只有单元测试会传别的。
        [string]$BcdExe = 'bcdedit.exe'
    )
    $out = @{ Ok = $false; Text = ''; CodePage = 0 }
    $cp = 0
    try { $cp = [System.Text.Encoding]::Default.CodePage } catch {}
    if ($cp -le 0) { $cp = 437 }
    $oldEnc = $null
    try {
        try { $oldEnc = [Console]::OutputEncoding } catch {}
        if ($oldEnc) {
            try { [Console]::OutputEncoding = [System.Text.Encoding]::GetEncoding($cp) }
            catch { $cp = $oldEnc.CodePage }
        }
        $txt = (& $BcdExe @BcdArgs 2>&1 | Out-String)
        if ($txt -and $txt.Length -gt 0) { $out.Ok = $true; $out.Text = $txt }
    } catch {
        $out.Ok = $false
    } finally {
        if ($oldEnc) { try { [Console]::OutputEncoding = $oldEnc } catch {} }
    }
    $out.CodePage = $cp
    return $out
}
