# 摘除残留的 ESP 盘符（S:）
# 需要管理员权限运行。只移除「访问路径」，不改分区数据，绝对安全。
# 作者：connectsegabot
$Script:Version = '1.32'
Write-Host ("清理残留盘符 v{0} - 作者：connectsegabot" -f $Script:Version)
Write-Host "=========================================="
$espGuid = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
foreach ($part in (Get-Partition -EA SilentlyContinue)) {
    if (-not $part.DriveLetter) { continue }
    $gpt = ([string]$part.GptType -replace '[{}]', '').ToLower()
    if ($gpt -ne $espGuid) { continue }
    $dl = [string]$part.DriveLetter
    Write-Host ("发现 EFI 系统分区占着盘符 {0}: (Disk{1} Part{2})" -f $dl, $part.DiskNumber, $part.PartitionNumber)
    try {
        # 用 -DriveLetter：-AccessPath 要的是卷访问路径（"S:\"），传 "S:" 会报参数无效
        Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -DriveLetter $dl -EA Stop | Out-Null
        Write-Host "已摘除盘符 $dl`:  (绿色=成功)" -ForegroundColor Green
    } catch {
        Write-Host ("摘除失败: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}
Write-Host ""
Write-Host "完成。此窗口 5 秒后自动关闭。"
