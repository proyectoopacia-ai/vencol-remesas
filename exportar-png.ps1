# Exporta las piezas a PNG 1080x1920 con Chrome sin ventana.
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$perfil = Join-Path $env:TEMP 'vencol-banner-chrome'
Add-Type -AssemblyName System.Drawing

foreach ($pieza in 'banner-tasa-del-dia', 'tabla-completa') {
  $html = Join-Path $PSScriptRoot "$pieza.html"
  $png = Join-Path $PSScriptRoot "$pieza.png"
  $url = 'file:///' + ($html -replace '\\', '/' -replace ' ', '%20')

  & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
    --user-data-dir="$perfil" --window-size=1080,1920 --virtual-time-budget=6000 `
    --screenshot="$png" $url 2>$null | Out-Null

  Start-Sleep -Milliseconds 500
  $img = [System.Drawing.Image]::FromFile($png)
  "$pieza.png: $($img.Width)x$($img.Height)"
  $img.Dispose()
}
