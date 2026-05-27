Write-Host "Running Windows System Assessment..." -ForegroundColor Cyan
winsat formal

Write-Host "Results:" -ForegroundColor Cyan
Get-CimInstance -Query "SELECT * FROM Win32_WinSAT" | Format-Table CPUScore, D3DScore, DiskScore, GraphicsScore, MemoryScore -AutoSize
