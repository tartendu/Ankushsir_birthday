# Builds index.html (one self-contained file) from source.html.
# Every photo referenced as src="assets/..." is shrunk and embedded inside the HTML,
# so the page works on hosts that only serve the single index.html file.
#
# Run:  powershell -ExecutionPolicy Bypass -File build.ps1

Add-Type -AssemblyName System.Drawing

$root    = $PSScriptRoot
$maxW    = 820     # embedded photo width in pixels
$quality = 78      # JPEG quality (0-100)

$codec = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
$encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, [long]$quality)

function Get-EmbeddedPhoto([string]$path) {
  $img = [System.Drawing.Image]::FromFile($path)
  try {
    $scale = [Math]::Min(1.0, $maxW / $img.Width)
    $w = [int]($img.Width * $scale); $h = [int]($img.Height * $scale)
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $w, $h)
    $ms = New-Object System.IO.MemoryStream
    $bmp.Save($ms, $codec, $encParams)
    $g.Dispose(); $bmp.Dispose()
    return 'data:image/jpeg;base64,' + [Convert]::ToBase64String($ms.ToArray())
  } finally { $img.Dispose() }
}

$html = [System.IO.File]::ReadAllText("$root\source.html", [System.Text.Encoding]::UTF8)

$count = 0
$html = [regex]::Replace($html, 'src="assets/([^"]+)"', [System.Text.RegularExpressions.MatchEvaluator]{
  param($m)
  $file = Join-Path "$root\assets" $m.Groups[1].Value
  if (-not (Test-Path $file)) { throw "Missing photo: $file" }
  $script:count++
  'src="' + (Get-EmbeddedPhoto $file) + '"'
})

$note = "<!doctype html>`n<!-- GENERATED FILE. Do not edit here: change source.html, then run build.ps1 -->"
$html = $html -replace '^<!doctype html>', $note

[System.IO.File]::WriteAllText("$root\index.html", $html, (New-Object System.Text.UTF8Encoding $false))
"Embedded $count photos. index.html is now {0:N1} MB." -f ((Get-Item "$root\index.html").Length / 1MB)
