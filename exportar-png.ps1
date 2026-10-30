# Exporta las piezas a PNG con Chrome sin ventana.
$chrome = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
$perfil = Join-Path $env:TEMP 'vencol-banner-chrome'
Add-Type -AssemblyName System.Drawing

$piezas = @(
  @{ nombre = 'banner-tasa-del-dia'; tamano = '1080,1920' },
  @{ nombre = 'tabla-completa'; tamano = '1080,1920' },
  @{ nombre = 'perfil-whatsapp'; tamano = '1080,1080' },
  @{ nombre = 'portada-whatsapp'; tamano = '1600,900' }
)

foreach ($pieza in $piezas) {
  $html = Join-Path $PSScriptRoot "$($pieza.nombre).html"
  $png = Join-Path $PSScriptRoot "$($pieza.nombre).png"
  $url = 'file:///' + ($html -replace '\\', '/' -replace ' ', '%20') + '?export=1'

  & $chrome --headless=new --disable-gpu --hide-scrollbars --force-device-scale-factor=1 `
    --user-data-dir="$perfil" --window-size=$($pieza.tamano) --virtual-time-budget=6000 `
    --screenshot="$png" $url 2>$null | Out-Null

  Start-Sleep -Milliseconds 500
  $img = [System.Drawing.Image]::FromFile($png)
  "$($pieza.nombre).png: $($img.Width)x$($img.Height)"
  $img.Dispose()
}
