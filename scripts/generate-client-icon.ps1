[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$client = Join-Path $root 'apps/cliente'
$sourcePath = Join-Path $client 'assets/images/courier-app-icon.png'
$source = [System.Drawing.Image]::FromFile($sourcePath)

function Save-Icon([string]$RelativePath, [int]$Size, [bool]$Maskable) {
    $destination = Join-Path $client $RelativePath
    $bitmap = New-Object System.Drawing.Bitmap($Size, $Size)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.Clear([System.Drawing.Color]::FromArgb(8, 18, 37))
        $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
        $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
        $inset = if ($Maskable) { [int][Math]::Round($Size * .10) } else { 0 }
        $edge = $Size - 2 * $inset
        $graphics.DrawImage($source, (New-Object System.Drawing.Rectangle($inset, $inset, $edge, $edge)))
        $bitmap.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally {
        $graphics.Dispose()
        $bitmap.Dispose()
    }
}

try {
    Save-Icon 'web/icons/Icon-192.png' 192 $false
    Save-Icon 'web/icons/Icon-512.png' 512 $false
    Save-Icon 'web/icons/Icon-maskable-192.png' 192 $true
    Save-Icon 'web/icons/Icon-maskable-512.png' 512 $true
    Save-Icon 'web/favicon.png' 64 $false
    foreach ($entry in @(
        @{ Density = 'mdpi'; Size = 48 },
        @{ Density = 'hdpi'; Size = 72 },
        @{ Density = 'xhdpi'; Size = 96 },
        @{ Density = 'xxhdpi'; Size = 144 },
        @{ Density = 'xxxhdpi'; Size = 192 }
    )) {
        Save-Icon "android/app/src/main/res/mipmap-$($entry.Density)/ic_launcher.png" $entry.Size $false
    }
} finally {
    $source.Dispose()
}
