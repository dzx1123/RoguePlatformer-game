param(
    [string]$ProjectRoot = "D:\Godot\RoguePlatformer-game"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$sourcePath = Join-Path $ProjectRoot "assets\characters\frames_polished\hero_jump_rise.png"
$riseOutput = Join-Path $ProjectRoot "assets\characters\frames_polished\hero_jump_rise_v2.png"
$apexOutput = Join-Path $ProjectRoot "assets\characters\frames_polished\hero_jump_apex_v2.png"

$source = [System.Drawing.Bitmap]::FromFile($sourcePath)
$output = New-Object System.Drawing.Bitmap $source.Width, $source.Height, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [System.Drawing.Graphics]::FromImage($output)
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::None
$graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
$graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::Half
$graphics.DrawImageUnscaled($source, 0, 0)

# Clear only the old thin blade below the existing cyan/gold guard.
$clearBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::Transparent)
$clearShape = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(194, 266),
    [System.Drawing.Point]::new(250, 266),
    [System.Drawing.Point]::new(244, 310),
    [System.Drawing.Point]::new(198, 395),
    [System.Drawing.Point]::new(145, 395),
    [System.Drawing.Point]::new(145, 335),
    [System.Drawing.Point]::new(194, 276)
)
$graphics.FillPolygon($clearBrush, $clearShape)
$clearBrush.Dispose()

$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceOver

# Rebuild the weapon as the same broad, intact silver blade used by the idle pose.
$outlineBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 12, 23, 31))
$outline = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(210, 264),
    [System.Drawing.Point]::new(237, 277),
    [System.Drawing.Point]::new(190, 369),
    [System.Drawing.Point]::new(164, 386),
    [System.Drawing.Point]::new(158, 380),
    [System.Drawing.Point]::new(166, 354),
    [System.Drawing.Point]::new(204, 275)
)
$graphics.FillPolygon($outlineBrush, $outline)
$outlineBrush.Dispose()

$bladeBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 202, 214, 217))
$blade = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(213, 270),
    [System.Drawing.Point]::new(230, 279),
    [System.Drawing.Point]::new(185, 365),
    [System.Drawing.Point]::new(165, 379),
    [System.Drawing.Point]::new(171, 357),
    [System.Drawing.Point]::new(207, 279)
)
$graphics.FillPolygon($bladeBrush, $blade)
$bladeBrush.Dispose()

$facetBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 91, 108, 117))
$facet = [System.Drawing.Point[]]@(
    [System.Drawing.Point]::new(221, 276),
    [System.Drawing.Point]::new(230, 279),
    [System.Drawing.Point]::new(185, 365),
    [System.Drawing.Point]::new(165, 379),
    [System.Drawing.Point]::new(181, 357)
)
$graphics.FillPolygon($facetBrush, $facet)
$facetBrush.Dispose()

$highlightPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(255, 246, 249, 244)), 4
$graphics.DrawLine($highlightPen, 211, 278, 174, 356)
$graphics.DrawLine($highlightPen, 174, 356, 166, 376)
$highlightPen.Dispose()

# The blade belongs behind the hand, guard and cape tip. Restore those original
# pixels last so the repaired blade never covers the cyan gem or gold crossguard.
$graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
$guardRect = [System.Drawing.Rectangle]::new(145, 228, 135, 62)
$graphics.DrawImage($source, $guardRect, $guardRect, [System.Drawing.GraphicsUnit]::Pixel)

$graphics.Dispose()
$source.Dispose()
$output.Save($riseOutput, [System.Drawing.Imaging.ImageFormat]::Png)
$output.Save($apexOutput, [System.Drawing.Imaging.ImageFormat]::Png)
$output.Dispose()

Write-Output "Repaired jump sword frames:"
Write-Output $riseOutput
Write-Output $apexOutput
