param(
  [string]$WorkbookPath = "2025 Plan de charge.xlsx",
  [string]$OutputPdf = "Reporting_CODIR.pdf",
  [string]$Password = "Finance2026",
  [switch]$CodirOnly
)

$fullWorkbook = (Resolve-Path $WorkbookPath).Path
$outPath = Join-Path (Split-Path $fullWorkbook -Parent) $OutputPdf

$excel = New-Object -ComObject Excel.Application
$excel.Visible = $false
$excel.DisplayAlerts = $false

function Set-PageLayout($ws, $printArea, $landscape = $true, $fitTall = $false) {
  $ws.PageSetup.PrintArea = $printArea
  $ws.PageSetup.PaperSize = 9
  $ws.PageSetup.Orientation = $(if ($landscape) { 2 } else { 1 })
  $ws.PageSetup.Zoom = $false
  $ws.PageSetup.FitToPagesWide = 1
  if ($fitTall) { $ws.PageSetup.FitToPagesTall = 1 } else { $ws.PageSetup.FitToPagesTall = $false }
}

function Get-Sheet($wb, $name) {
  foreach ($ws in $wb.Worksheets) {
    if ($ws.Name -eq $name) { return $ws }
  }
  return $null
}

try {
  $wb = $excel.Workbooks.Open($fullWorkbook)

  $wsHome = Get-Sheet $wb 'Accueil CODIR'
  $wsAna  = Get-Sheet $wb 'Analyse'
  $wsAff  = Get-Sheet $wb 'Affaires'
  $wsRec  = Get-Sheet $wb 'Récapitulatif'
  if (-not $wsRec) {
    foreach ($ws in $wb.Worksheets) {
      if ($ws.Name -like '*capitulatif*') { $wsRec = $ws; break }
    }
  }

  foreach ($s in @($wsHome,$wsAna,$wsAff,$wsRec)) {
    if ($s) { try { $s.Unprotect($Password) } catch {} }
  }

  if ($wsHome) { Set-PageLayout $wsHome '$A$1:$L$38' $true $true }
  if ($wsAna)  { Set-PageLayout $wsAna  '$A$1:$N$60' $true $true }

  if ($wsAff) {
    $lastDataRow = 5
    for ($r = 504; $r -ge 5; $r--) {
      $count = $excel.WorksheetFunction.CountA($wsAff.Range("B$r:L$r"))
      if ($count -gt 0) { $lastDataRow = $r; break }
    }
    $affEnd = [Math]::Min(504, [Math]::Max(25, $lastDataRow + 6))
    $affArea = ('$A$1:$S${0}' -f $affEnd)
    Set-PageLayout $wsAff $affArea $true $false
  }

  if ($wsRec) {
    Set-PageLayout $wsRec '$A$1:$O$203' $true $false
  }

  foreach ($s in @($wsHome,$wsAna,$wsAff,$wsRec)) {
    if ($s) {
      try {
        $s.Protect($Password, $true, $true, $true, $true, $false, $false, $false, $false, $true, $false, $false, $true, $true, $true)
      } catch {}
    }
  }

  if ($CodirOnly) {
    $sheets = @('Accueil CODIR','Analyse')
  } else {
    $sheets = @('Accueil CODIR','Analyse','Affaires')
    if ($wsRec) { $sheets += $wsRec.Name }
  }

  $wb.Worksheets($sheets).Select() | Out-Null
  $wb.ActiveSheet.ExportAsFixedFormat(0, $outPath)
  Write-Output "PDF exported: $outPath"

  $wb.Save()
  $wb.Close($false)
}
finally {
  if ($wb) { [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($wb) }
  $excel.Quit()
  [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($excel)
}
