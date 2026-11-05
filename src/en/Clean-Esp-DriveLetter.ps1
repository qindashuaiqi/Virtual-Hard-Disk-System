# Remove a leftover ESP drive letter (S:)
# Run as administrator. Only the "access path" is removed, no partition data is touched - completely safe.
# Author: connectsegabot
$Script:Version = '1.31'
Write-Host ("Clean leftover drive letter v{0} - author: connectsegabot" -f $Script:Version)
Write-Host "=========================================="
$espGuid = 'c12a7328-f81f-11d2-ba4b-00a0c93ec93b'
foreach ($part in (Get-Partition -EA SilentlyContinue)) {
    if (-not $part.DriveLetter) { continue }
    $gpt = ([string]$part.GptType -replace '[{}]', '').ToLower()
    if ($gpt -ne $espGuid) { continue }
    $dl = [string]$part.DriveLetter
    Write-Host ("EFI system partition holding drive letter {0}: (Disk{1} Part{2})" -f $dl, $part.DiskNumber, $part.PartitionNumber)
    try {
        # Use -DriveLetter: -AccessPath expects a volume access path ("S:\"), and "S:" is rejected as invalid
        Remove-PartitionAccessPath -DiskNumber $part.DiskNumber -PartitionNumber $part.PartitionNumber -DriveLetter $dl -EA Stop | Out-Null
        Write-Host "Removed drive letter $dl`:  (green = success)" -ForegroundColor Green
    } catch {
        Write-Host ("Removal failed: {0}" -f $_.Exception.Message) -ForegroundColor Red
    }
}
Write-Host ""
Write-Host "Done. This window closes in 5 seconds."
