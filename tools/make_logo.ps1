Add-Type -AssemblyName System.Drawing

$lime = [System.Drawing.Color]::FromArgb(255, 0xB6, 0xF5, 0x3C)
$ink  = [System.Drawing.Color]::FromArgb(255, 0x17, 0x17, 0x1C)
$brd  = [System.Drawing.Color]::FromArgb(255, 0x2A, 0x2A, 0x32)
$warm = [System.Drawing.Color]::FromArgb(255, 0xF2, 0xB4, 0x50)

function RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
  $p = New-Object System.Drawing.Drawing2D.GraphicsPath
  $p.AddArc($x, $y, $r*2, $r*2, 180, 90)
  $p.AddArc($x+$w-$r*2, $y, $r*2, $r*2, 270, 90)
  $p.AddArc($x+$w-$r*2, $y+$h-$r*2, $r*2, $r*2, 0, 90)
  $p.AddArc($x, $y+$h-$r*2, $r*2, $r*2, 90, 90)
  $p.CloseFigure()
  return $p
}

function RenderLogo([int]$size, [bool]$withWarm) {
  $bmp = New-Object System.Drawing.Bitmap($size, $size)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
  $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
  $k = $size / 256.0

  $bg = RoundRect 0 0 $size $size (56 * $k)
  $gb = New-Object System.Drawing.SolidBrush($ink)
  $g.FillPath($gb, $bg)
  $pb = New-Object System.Drawing.Pen($brd, [float](6 * $k))
  $g.DrawPath($pb, $bg)

  $lb = New-Object System.Drawing.SolidBrush($lime)

  # stem
  $stem = RoundRect (112*$k) (36*$k) (32*$k) (86*$k) (16*$k)
  $g.FillPath($lb, $stem)
  # arrow head
  $head = New-Object System.Drawing.PointF[] 3
  $head[0] = New-Object System.Drawing.PointF((74*$k), (104*$k))
  $head[1] = New-Object System.Drawing.PointF((182*$k), (104*$k))
  $head[2] = New-Object System.Drawing.PointF((128*$k), (162*$k))
  $g.FillPolygon($lb, $head)
  # destination bar
  $bar = RoundRect (62*$k) (178*$k) (132*$k) (24*$k) (12*$k)
  $g.FillPath($lb, $bar)

  if ($withWarm) {
    $wb = New-Object System.Drawing.SolidBrush($warm)
    $dot = RoundRect (188*$k) (40*$k) (16*$k) (16*$k) (5*$k)
    $g.FillPath($wb, $dot)
  }

  $g.Dispose()
  return $bmp
}

$sizes = @(256, 48, 32, 16)
$pngs = @{}
foreach ($s in $sizes) { $pngs[$s] = RenderLogo $s ($s -ge 48) }

# save PNG (256) for in-app use
$pngs[256].Save("$PSScriptRoot\..\assets\kuiklon_logo.png", [System.Drawing.Imaging.ImageFormat]::Png)

# pack multi-size ICO
$ms = New-Object System.IO.MemoryStream
$bw = New-Object System.IO.BinaryWriter($ms)
$bw.Write([uint16]0); $bw.Write([uint16]1); $bw.Write([uint16]$sizes.Count)
$offset = 6 + 16 * $sizes.Count
$entries = @()
foreach ($s in $sizes) {
  $m = New-Object System.IO.MemoryStream
  $pngs[$s].Save($m, [System.Drawing.Imaging.ImageFormat]::Png)
  $entries += @{ dim = $s; data = $m.ToArray() }
  $m.Dispose()
}
foreach ($e in $entries) {
  $d = if ($e.dim -ge 256) { 0 } else { $e.dim }
  $bw.Write([byte]$d); $bw.Write([byte]$d); $bw.Write([byte]0); $bw.Write([byte]0)
  $bw.Write([uint16]1); $bw.Write([uint16]32)
  $bw.Write([uint32]$e.data.Length); $bw.Write([uint32]$offset)
  $offset += $e.data.Length
}
foreach ($e in $entries) { $bw.Write($e.data) }
$bw.Flush()
[System.IO.File]::WriteAllBytes("$PSScriptRoot\..\assets\kuiklon_tray.ico", $ms.ToArray())
Copy-Item "$PSScriptRoot\..\assets\kuiklon_tray.ico" "$PSScriptRoot\..\windows\runner\resources\app_icon.ico" -Force

$bw.Dispose(); $ms.Dispose()
foreach ($b in $pngs.Values) { $b.Dispose() }
Write-Host "logo + ico generated"