# Generate the original GOGDELY Master shield icon on Windows.
Add-Type -AssemblyName System.Drawing
$root = Join-Path $PSScriptRoot '..\apps\master\web'
$icons = Join-Path $root 'icons'

function New-MasterIcon([int]$size, [string]$path, [bool]$maskable) {
    $bitmap = [System.Drawing.Bitmap]::new($size, $size)
    $graphic = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphic.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $graphic.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit
    $graphite = [System.Drawing.ColorTranslator]::FromHtml('#151B2B')
    $blue = [System.Drawing.ColorTranslator]::FromHtml('#2563EB')
    $white = [System.Drawing.Color]::White
    $background = [System.Drawing.SolidBrush]::new($graphite)
    $brand = [System.Drawing.SolidBrush]::new($blue)
    $ink = [System.Drawing.SolidBrush]::new($white)
    try {
        $graphic.FillRectangle($background, 0, 0, $size, $size)
        $margin = if ($maskable) { 0.24 } else { 0.16 }
        $left = $size * $margin
        $right = $size * (1 - $margin)
        $top = $size * 0.19
        $bottom = $size * 0.82
        $shield = [System.Drawing.Drawing2D.GraphicsPath]::new()
        try {
            $points = [System.Drawing.PointF[]]@(
                [System.Drawing.PointF]::new($size * 0.5, $top),
                [System.Drawing.PointF]::new($right, $size * 0.32),
                [System.Drawing.PointF]::new($right - $size * 0.035, $size * 0.61),
                [System.Drawing.PointF]::new($size * 0.5, $bottom),
                [System.Drawing.PointF]::new($left + $size * 0.035, $size * 0.61),
                [System.Drawing.PointF]::new($left, $size * 0.32)
            )
            $shield.AddPolygon($points)
            $graphic.FillPath($brand, $shield)
        } finally { $shield.Dispose() }
        $font = [System.Drawing.Font]::new('Segoe UI', $size * 0.32,
            [System.Drawing.FontStyle]::Bold, [System.Drawing.GraphicsUnit]::Pixel)
        try {
            $format = [System.Drawing.StringFormat]::new()
            $format.Alignment = [System.Drawing.StringAlignment]::Center
            $format.LineAlignment = [System.Drawing.StringAlignment]::Center
            $graphic.DrawString('G', $font, $ink,
                [System.Drawing.RectangleF]::new($size * 0.26, $size * 0.30,
                    $size * 0.48, $size * 0.39), $format)
        } finally { $font.Dispose() }
        $dot = $size * 0.025
        foreach ($x in @(0.41, 0.50, 0.59)) {
            $graphic.FillEllipse($ink, $size * $x - $dot, $size * 0.70,
                $dot * 2, $dot * 2)
        }
        $bitmap.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphic.Dispose(); $bitmap.Dispose()
        $background.Dispose(); $brand.Dispose(); $ink.Dispose()
    }
}

New-MasterIcon 192 (Join-Path $icons 'Icon-192.png') $false
New-MasterIcon 512 (Join-Path $icons 'Icon-512.png') $false
New-MasterIcon 192 (Join-Path $icons 'Icon-maskable-192.png') $true
New-MasterIcon 512 (Join-Path $icons 'Icon-maskable-512.png') $true
New-MasterIcon 180 (Join-Path $icons 'apple-touch-icon.png') $false
New-MasterIcon 64 (Join-Path $root 'favicon.png') $false
