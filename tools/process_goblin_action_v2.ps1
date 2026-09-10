param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [int]$HorizontalOffset = 0,
    [int]$TargetBottom = 300,
    [int]$AttackSpillShift = 22,
    [int]$TargetIdleTorsoAnchor = 152,
    [string]$WalkSheetPath = ""
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$processorSource = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public static class GoblinActionV2Processor
{
    private const int Columns = 4;
    private const int Rows = 4;
    private const int CellSize = 313;

    public static void Process(
        string sourcePath,
        string outputPath,
        int horizontalOffset,
        int targetBottom,
        int attackSpillShift,
        int targetIdleTorsoAnchor,
        string walkSheetPath
    )
    {
        using (var source = new Bitmap(sourcePath))
        using (var normalized = new Bitmap(Columns * CellSize, Rows * CellSize, PixelFormat.Format32bppArgb))
        {
            for (int row = 0; row < Rows; row++)
            {
                for (int column = 0; column < Columns; column++)
                {
                    int sourceX0 = (int)Math.Round(column * source.Width / (double)Columns);
                    int sourceX1 = (int)Math.Round((column + 1) * source.Width / (double)Columns);
                    int sourceY0 = (int)Math.Round(row * source.Height / (double)Rows);
                    int sourceY1 = (int)Math.Round((row + 1) * source.Height / (double)Rows);
                    // The generated lunge crosses the boundary between attack cells 2 and 3.
                    // Move both sampling windows together so the whole connected pose lands in
                    // its own cell instead of leaving a club fragment in the wind-up frame.
                    if (row == 2 && (column == 1 || column == 2))
                    {
                        sourceX0 = Math.Max(0, sourceX0 - attackSpillShift);
                        sourceX1 = Math.Max(sourceX0 + 1, sourceX1 - attackSpillShift);
                    }

                    for (int y = 0; y < CellSize; y++)
                    {
                        for (int x = 0; x < CellSize; x++)
                        {
                            int sx = sourceX0 + Math.Min(
                                sourceX1 - sourceX0 - 1,
                                (int)((x + 0.5) * (sourceX1 - sourceX0) / CellSize)
                            );
                            int sy = sourceY0 + Math.Min(
                                sourceY1 - sourceY0 - 1,
                                (int)((y + 0.5) * (sourceY1 - sourceY0) / CellSize)
                            );
                            Color keyed = KeyGreen(source.GetPixel(sx, sy));
                            int destinationLocalX = x + horizontalOffset;
                            if (destinationLocalX >= 0 && destinationLocalX < CellSize)
                                normalized.SetPixel(column * CellSize + destinationLocalX, row * CellSize + y, keyed);
                        }
                    }
                }
            }

            using (var baselineAligned = AlignFootBaselines(normalized, targetBottom))
            using (var aligned = AlignIdleTorsoAnchors(baselineAligned, targetIdleTorsoAnchor))
            {
                string directory = Path.GetDirectoryName(outputPath);
                if (!string.IsNullOrEmpty(directory))
                    Directory.CreateDirectory(directory);
                if (!String.IsNullOrWhiteSpace(walkSheetPath))
                {
                    using (var walkSheet = new Bitmap(walkSheetPath))
                    using (var graphics = Graphics.FromImage(aligned))
                    {
                        graphics.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
                        graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
                        for (int column = 0; column < Columns; column++)
                        {
                            var sourceRect = new Rectangle(column * CellSize, 0, CellSize, CellSize);
                            var destinationRect = new Rectangle(column * CellSize, CellSize, CellSize, CellSize);
                            graphics.DrawImage(walkSheet, destinationRect, sourceRect, GraphicsUnit.Pixel);
                        }
                    }
                }
                aligned.Save(outputPath, ImageFormat.Png);
            }
        }
    }

    private static Bitmap AlignIdleTorsoAnchors(Bitmap sheet, int targetAnchor)
    {
        var aligned = new Bitmap(sheet.Width, sheet.Height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(aligned))
        {
            graphics.Clear(Color.Transparent);
            graphics.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
            graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            for (int row = 0; row < Rows; row++)
            {
                for (int column = 0; column < Columns; column++)
                {
                    int offsetX = row == 0 && targetAnchor >= 0
                        ? targetAnchor - FindRedTorsoAnchor(sheet, column, row)
                        : 0;
                    var sourceRect = new Rectangle(column * CellSize, row * CellSize, CellSize, CellSize);
                    var destinationRect = new Rectangle(
                        column * CellSize + offsetX,
                        row * CellSize,
                        CellSize,
                        CellSize
                    );
                    graphics.DrawImage(sheet, destinationRect, sourceRect, GraphicsUnit.Pixel);
                }
            }
        }
        return aligned;
    }

    private static int FindRedTorsoAnchor(Bitmap sheet, int column, int row)
    {
        int[] histogram = new int[CellSize];
        int redPixelCount = 0;
        int originX = column * CellSize;
        int originY = row * CellSize;
        for (int y = 0; y < CellSize; y++)
        {
            for (int x = 0; x < CellSize; x++)
            {
                Color pixel = sheet.GetPixel(originX + x, originY + y);
                if (
                    pixel.A > 0
                    && pixel.R >= 72
                    && pixel.R * 4 >= pixel.G * 5
                    && pixel.R * 5 >= pixel.B * 6
                    && pixel.R - pixel.G >= 18
                )
                {
                    histogram[x]++;
                    redPixelCount++;
                }
            }
        }
        if (redPixelCount == 0)
            return CellSize / 2;
        int midpoint = redPixelCount / 2;
        int accumulated = 0;
        for (int x = 0; x < CellSize; x++)
        {
            accumulated += histogram[x];
            if (accumulated >= midpoint)
                return x;
        }
        return CellSize / 2;
    }

    private static Bitmap AlignFootBaselines(Bitmap sheet, int targetBottom)
    {
        int[] bottoms = new int[Columns * Rows];
        for (int row = 0; row < Rows; row++)
        {
            for (int column = 0; column < Columns; column++)
            {
                int bottom = -1;
                for (int y = CellSize - 1; y >= 0 && bottom < 0; y--)
                {
                    for (int x = 0; x < CellSize; x++)
                    {
                        if (sheet.GetPixel(column * CellSize + x, row * CellSize + y).A >= 64)
                        {
                            bottom = y;
                            break;
                        }
                    }
                }
                if (bottom < 0)
                    throw new InvalidDataException(String.Format("Empty frame at row {0}, column {1}.", row, column));
                bottoms[row * Columns + column] = bottom;
            }
        }

        var aligned = new Bitmap(sheet.Width, sheet.Height, PixelFormat.Format32bppArgb);
        using (var graphics = Graphics.FromImage(aligned))
        {
            graphics.Clear(Color.Transparent);
            graphics.CompositingMode = System.Drawing.Drawing2D.CompositingMode.SourceCopy;
            graphics.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.NearestNeighbor;
            for (int row = 0; row < Rows; row++)
            {
                for (int column = 0; column < Columns; column++)
                {
                    int index = row * Columns + column;
                    int offsetY = targetBottom - bottoms[index];
                    var sourceRect = new Rectangle(column * CellSize, row * CellSize, CellSize, CellSize);
                    var destinationRect = new Rectangle(
                        column * CellSize,
                        row * CellSize + offsetY,
                        CellSize,
                        CellSize
                    );
                    graphics.DrawImage(sheet, destinationRect, sourceRect, GraphicsUnit.Pixel);
                }
            }
        }
        return aligned;
    }

    private static Color KeyGreen(Color pixel)
    {
        if (pixel.A == 0)
            return Color.Transparent;

        const double backgroundR = 20.0;
        const double backgroundG = 244.0;
        const double backgroundB = 12.0;
        int maxRedBlue = Math.Max(pixel.R, pixel.B);
        int greenExcess = pixel.G - maxRedBlue;
        if (pixel.G > 100 && greenExcess > 48 && pixel.G > maxRedBlue * 1.32)
            return Color.Transparent;

        double dr = pixel.R - backgroundR;
        double dg = pixel.G - backgroundG;
        double db = pixel.B - backgroundB;
        double distance = Math.Sqrt(dr * dr + dg * dg + db * db);
        if (distance <= 24.0)
            return Color.Transparent;

        double alpha = Math.Min(1.0, Math.Max(0.0, (distance - 24.0) / 72.0));
        if (alpha <= 0.02)
            return Color.Transparent;

        int red = Clamp((int)Math.Round((pixel.R - (1.0 - alpha) * backgroundR) / alpha));
        int green = Clamp((int)Math.Round((pixel.G - (1.0 - alpha) * backgroundG) / alpha));
        int blue = Clamp((int)Math.Round((pixel.B - (1.0 - alpha) * backgroundB) / alpha));
        int cleanedMaxRedBlue = Math.Max(red, blue);
        if (green > 76 && green > cleanedMaxRedBlue * 1.18)
            green = Clamp((int)Math.Round(cleanedMaxRedBlue * 1.03));
        int alphaByte = Clamp((int)Math.Round(alpha * 255.0));
        return Color.FromArgb(alphaByte, red, green, blue);
    }

    private static int Clamp(int value)
    {
        return Math.Min(255, Math.Max(0, value));
    }
}
"@

$drawingRoot = Split-Path -Parent ([System.Drawing.Bitmap].Assembly.Location)
$drawingAssemblies = @(
    [System.Drawing.Bitmap].Assembly.Location,
    [System.Drawing.Color].Assembly.Location
)
$drawingAssemblies += Get-ChildItem -LiteralPath $drawingRoot -Filter "System.Private.Windows*.dll" |
    Select-Object -ExpandProperty FullName
Add-Type -TypeDefinition $processorSource -ReferencedAssemblies $drawingAssemblies
[GoblinActionV2Processor]::Process(
    $SourcePath,
    $OutputPath,
    $HorizontalOffset,
    $TargetBottom,
    $AttackSpillShift,
    $TargetIdleTorsoAnchor,
    $WalkSheetPath
)
Write-Output "Wrote $OutputPath (1252x1252, 16 frames, floor baseline $TargetBottom)"
