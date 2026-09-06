param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,
    [Parameter(Mandatory = $true)]
    [string]$OutputPath,
    [int]$HorizontalOffset = 0,
    [int]$TargetBottom = -1
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

$processorSource = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.IO;

public static class GoblinWalkV4Processor
{
    private const int Columns = 4;
    private const int Rows = 2;
    private const int CellSize = 313;

    public static void Process(string sourcePath, string outputPath, int horizontalOffset, int requestedBottom)
    {
        using (var source = new Bitmap(sourcePath))
        using (var output = new Bitmap(Columns * CellSize, Rows * CellSize, PixelFormat.Format32bppArgb))
        {
            for (int row = 0; row < Rows; row++)
            {
                for (int column = 0; column < Columns; column++)
                {
                    int sourceX0 = (int)Math.Round(column * source.Width / (double)Columns);
                    int sourceX1 = (int)Math.Round((column + 1) * source.Width / (double)Columns);
                    int sourceY0 = (int)Math.Round(row * source.Height / (double)Rows);
                    int sourceY1 = (int)Math.Round((row + 1) * source.Height / (double)Rows);

                    for (int y = 0; y < CellSize; y++)
                    {
                        for (int x = 0; x < CellSize; x++)
                        {
                            int sx = sourceX0 + Math.Min(sourceX1 - sourceX0 - 1, (int)((x + 0.5) * (sourceX1 - sourceX0) / CellSize));
                            int sy = sourceY0 + Math.Min(sourceY1 - sourceY0 - 1, (int)((y + 0.5) * (sourceY1 - sourceY0) / CellSize));
                            Color keyed = KeyGreen(source.GetPixel(sx, sy));
                            int destinationLocalX = x + horizontalOffset;
                            if (destinationLocalX >= 0 && destinationLocalX < CellSize)
                                output.SetPixel(column * CellSize + destinationLocalX, row * CellSize + y, keyed);
                        }
                    }
                }
            }

            using (var aligned = AlignFootBaselines(output, requestedBottom))
            {
                string directory = Path.GetDirectoryName(outputPath);
                if (!string.IsNullOrEmpty(directory))
                    Directory.CreateDirectory(directory);
                aligned.Save(outputPath, ImageFormat.Png);
            }
        }
    }

    private static Bitmap AlignFootBaselines(Bitmap sheet, int requestedBottom)
    {
        int[] bottoms = new int[Columns * Rows];
        int targetBottom = requestedBottom;
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
                int index = row * Columns + column;
                bottoms[index] = bottom;
                if (requestedBottom < 0)
                    targetBottom = Math.Max(targetBottom, bottom);
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
                    var destinationRect = new Rectangle(column * CellSize, row * CellSize + offsetY, CellSize, CellSize);
                    graphics.DrawImage(sheet, destinationRect, sourceRect, GraphicsUnit.Pixel);
                }
            }
        }
        return aligned;
    }

    private static Color KeyGreen(Color pixel)
    {
        const double backgroundR = 20.0;
        const double backgroundG = 244.0;
        const double backgroundB = 12.0;
        int maxRedBlue = Math.Max(pixel.R, pixel.B);
        int greenExcess = pixel.G - maxRedBlue;
        if (pixel.G > 100 && greenExcess > 50 && pixel.G > maxRedBlue * 1.35)
            return Color.FromArgb(0, 0, 0, 0);

        double dr = pixel.R - backgroundR;
        double dg = pixel.G - backgroundG;
        double db = pixel.B - backgroundB;
        double distance = Math.Sqrt(dr * dr + dg * dg + db * db);
        if (distance <= 22.0)
            return Color.FromArgb(0, 0, 0, 0);

        double alpha = Math.Min(1.0, Math.Max(0.0, (distance - 22.0) / 68.0));
        if (alpha <= 0.02)
            return Color.Transparent;

        int red = Clamp((int)Math.Round((pixel.R - (1.0 - alpha) * backgroundR) / alpha));
        int green = Clamp((int)Math.Round((pixel.G - (1.0 - alpha) * backgroundG) / alpha));
        int blue = Clamp((int)Math.Round((pixel.B - (1.0 - alpha) * backgroundB) / alpha));
        int cleanedMaxRedBlue = Math.Max(red, blue);
        if (green > 80 && green > cleanedMaxRedBlue * 1.20)
            green = Clamp((int)Math.Round(cleanedMaxRedBlue * 1.05));
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
[GoblinWalkV4Processor]::Process($SourcePath, $OutputPath, $HorizontalOffset, $TargetBottom)
Write-Output "Wrote $OutputPath (1252x626, 8 frames)"
