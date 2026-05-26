# Regenerate Android launcher icons, iOS AppIcon.appiconset, and sync drawables.
# Usage: powershell -File tool/resize_launcher_icons.ps1
#        powershell -File tool/resize_launcher_icons.ps1 -Scale 0.82
param(
    [double]$Scale = 0.80,
    [int]$BlackThreshold = 32
)

Add-Type -AssemblyName System.Drawing

$projectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$src = Join-Path $PSScriptRoot "ic_launcher_foreground_master.png"
if (-not (Test-Path $src)) {
    throw "Missing $src - place full-bleed foreground PNG there first."
}

function Test-NearBlack {
    param([System.Drawing.Color]$Color, [int]$Threshold)
    return ($Color.A -gt 0 -and $Color.R -le $Threshold -and $Color.G -le $Threshold -and $Color.B -le $Threshold)
}

function Remove-EdgeConnectedNearBlack {
    param([System.Drawing.Bitmap]$Bitmap, [int]$Threshold)
    $w = $Bitmap.Width
    $h = $Bitmap.Height
    $visited = New-Object 'bool[,]' $w, $h
    $queue = [System.Collections.Generic.Queue[System.Drawing.Point]]::new()

    function Enqueue-IfNearBlack([int]$X, [int]$Y) {
        if ($X -lt 0 -or $Y -lt 0 -or $X -ge $w -or $Y -ge $h) { return }
        if ($visited[$X, $Y]) { return }
        $c = $Bitmap.GetPixel($X, $Y)
        if (-not (Test-NearBlack $c $Threshold)) { return }
        $visited[$X, $Y] = $true
        $queue.Enqueue([System.Drawing.Point]::new($X, $Y))
    }

    for ($x = 0; $x -lt $w; $x++) {
        Enqueue-IfNearBlack $x 0
        Enqueue-IfNearBlack $x ($h - 1)
    }
    for ($y = 0; $y -lt $h; $y++) {
        Enqueue-IfNearBlack 0 $y
        Enqueue-IfNearBlack ($w - 1) $y
    }

    while ($queue.Count -gt 0) {
        $p = $queue.Dequeue()
        $Bitmap.SetPixel($p.X, $p.Y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
        Enqueue-IfNearBlack ($p.X - 1) $p.Y
        Enqueue-IfNearBlack ($p.X + 1) $p.Y
        Enqueue-IfNearBlack $p.X ($p.Y - 1)
        Enqueue-IfNearBlack $p.X ($p.Y + 1)
    }
}

function Draw-GlassCircleBackground {
    param(
        [System.Drawing.Graphics]$Graphics,
        [int]$Size
    )
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 44, 44, 50))
    $Graphics.FillEllipse($brush, 0, 0, $Size, $Size)
    $brush.Dispose()
}

function Save-ScaledIcon {
    param(
        [string]$SourcePath,
        [string]$DestPath,
        [int]$Size,
        [double]$Scale,
        [int]$BlackThreshold
    )
    $srcImg = [System.Drawing.Image]::FromFile($SourcePath)
    $bmp = New-Object System.Drawing.Bitmap($Size, $Size, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    $g.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality

    Draw-GlassCircleBackground -Graphics $g -Size $Size

    $w = [int][Math]::Round($Size * $Scale)
    $h = [int][Math]::Round($Size * $Scale)
    $x = [int][Math]::Round(($Size - $w) / 2.0)
    $y = [int][Math]::Round(($Size - $h) / 2.0)
    $g.DrawImage($srcImg, $x, $y, $w, $h)
    $g.Dispose()
    $srcImg.Dispose()

    Remove-EdgeConnectedNearBlack -Bitmap $bmp -Threshold $BlackThreshold

    $bmp.Save($DestPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host "Wrote $DestPath (scale=$Scale)"
}

function Sync-AndroidDrawableToIos {
    param(
        [string]$AndroidRes,
        [string]$IosAssets,
        [string]$Name,
        [hashtable]$DensityToScale
    )
    $imageset = Join-Path $IosAssets "$Name.imageset"
    New-Item -ItemType Directory -Force -Path $imageset | Out-Null

    $images = @()
    foreach ($entry in ($DensityToScale.GetEnumerator() | Sort-Object { $_.Value.Scale })) {
        $srcFile = Join-Path $AndroidRes "$($entry.Key)\$Name.png"
        if (-not (Test-Path $srcFile)) {
            throw "Missing $srcFile"
        }
        $destName = if ($entry.Value.Scale -eq 1) { "$Name.png" } else { "${Name}@$($entry.Value.Scale)x.png" }
        Copy-Item -Path $srcFile -Destination (Join-Path $imageset $destName) -Force
        $images += @{
            idiom    = "universal"
            filename = $destName
            scale    = "$($entry.Value.Scale)x"
        }
        Write-Host "Synced $destName <- $srcFile"
    }

    $contents = @{
        images = $images
        info   = @{ version = 1; author = "xcode" }
    }
    ($contents | ConvertTo-Json -Depth 4) + "`n" | Set-Content -Path (Join-Path $imageset "Contents.json") -Encoding utf8
}

$androidRes = Join-Path $projectRoot "android\app\src\main\res"
$iosAssets = Join-Path $projectRoot "ios\Runner\Assets.xcassets"
@{
    "mipmap-mdpi"    = @(108, 48)
    "mipmap-hdpi"    = @(162, 72)
    "mipmap-xhdpi"   = @(216, 96)
    "mipmap-xxhdpi"  = @(324, 144)
    "mipmap-xxxhdpi" = @(432, 192)
}.GetEnumerator() | ForEach-Object {
    Save-ScaledIcon $src (Join-Path $androidRes "$($_.Key)\ic_launcher_foreground.png") $_.Value[0] $Scale $BlackThreshold
    Save-ScaledIcon $src (Join-Path $androidRes "$($_.Key)\ic_launcher.png") $_.Value[1] $Scale $BlackThreshold
}

$iosAppIcon = Join-Path $projectRoot "ios\Runner\Assets.xcassets\AppIcon.appiconset"
@(
    @{ File = "Icon-App-20x20@1x.png";       Size = 20 }
    @{ File = "Icon-App-20x20@2x.png";       Size = 40 }
    @{ File = "Icon-App-20x20@3x.png";       Size = 60 }
    @{ File = "Icon-App-29x29@1x.png";       Size = 29 }
    @{ File = "Icon-App-29x29@2x.png";       Size = 58 }
    @{ File = "Icon-App-29x29@3x.png";       Size = 87 }
    @{ File = "Icon-App-40x40@1x.png";       Size = 40 }
    @{ File = "Icon-App-40x40@2x.png";       Size = 80 }
    @{ File = "Icon-App-40x40@3x.png";       Size = 120 }
    @{ File = "Icon-App-60x60@2x.png";       Size = 120 }
    @{ File = "Icon-App-60x60@3x.png";       Size = 180 }
    @{ File = "Icon-App-76x76@1x.png";       Size = 76 }
    @{ File = "Icon-App-76x76@2x.png";       Size = 152 }
    @{ File = "Icon-App-83.5x83.5@2x.png";   Size = 167 }
    @{ File = "Icon-App-1024x1024@1x.png";   Size = 1024 }
) | ForEach-Object {
    Save-ScaledIcon $src (Join-Path $iosAppIcon $_.File) $_.Size $Scale $BlackThreshold
}

Sync-AndroidDrawableToIos -AndroidRes $androidRes -IosAssets $iosAssets -Name "ic_bg_service_small" @{
    "drawable-mdpi"    = @{ Scale = 1 }
    "drawable-xhdpi"   = @{ Scale = 2 }
    "drawable-xxhdpi"  = @{ Scale = 3 }
}

Sync-AndroidDrawableToIos -AndroidRes $androidRes -IosAssets $iosAssets -Name "ic_notification_logo" @{
    "drawable-mdpi"    = @{ Scale = 1 }
    "drawable-xhdpi"   = @{ Scale = 2 }
    "drawable-xxhdpi"  = @{ Scale = 3 }
}

$flutterAssets = Join-Path $projectRoot "assets\images"
New-Item -ItemType Directory -Force -Path $flutterAssets | Out-Null
Copy-Item (Join-Path $androidRes "drawable-xxhdpi\ic_notification_logo.png") (Join-Path $flutterAssets "ic_notification_logo.png") -Force
Write-Host "Synced assets/images/ic_notification_logo.png"

Write-Host "Done."
