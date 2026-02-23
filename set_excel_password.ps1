param(
  [string]$WorkbookPath = "2025 Plan de charge.xlsx",
  [string]$CurrentPassword = "Finance2026",
  [string]$NewPassword = "Finance2026"
)

$fullWorkbook = (Resolve-Path $WorkbookPath).Path

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

try {
  $wb = $excel.Workbooks.Open($fullWorkbook)

  foreach ($ws in $wb.Worksheets) {
    try { $ws.Unprotect($CurrentPassword) } catch {}

    while ($ws.Protection.AllowEditRanges.Count -gt 0) {
      $ws.Protection.AllowEditRanges.Item(1).Delete()
    }

    $used = $ws.UsedRange
    $null = $ws.Protection.AllowEditRanges.Add('Zone protegee', $used, $NewPassword)

    $ws.Protect($NewPassword, $true, $true, $true, $true, $false, $false, $false, $false, $true, $false, $false, $true, $true, $true)
  }

  try { $wb.Unprotect($CurrentPassword) } catch {}
  $wb.Protect($NewPassword, $true, $false)

  $wb.Save()
  Write-Output "Password updated successfully: $NewPassword"
  $wb.Close($true)
}
finally {
  if ($wb) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) }
  $excel.Quit()
  [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
}
