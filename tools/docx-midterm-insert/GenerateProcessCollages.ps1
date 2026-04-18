param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Drawing

$outputDir = Join-Path $RepoRoot 'docs\paper\generated_assets'
if (-not (Test-Path -LiteralPath $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir | Out-Null
}

function New-ProcessCollage {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$InputPaths,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    if ($InputPaths.Count -ne 4) {
        throw "Expected exactly 4 input images, got $($InputPaths.Count)."
    }

    $images = New-Object 'System.Collections.Generic.List[System.Drawing.Image]'
    try {
        foreach ($path in $InputPaths) {
            if (-not (Test-Path -LiteralPath $path)) {
                throw "Image not found: $path"
            }
            $images.Add([System.Drawing.Image]::FromFile($path))
        }

        [int]$cellWidth = ($images | Measure-Object -Property Width -Maximum).Maximum
        [double]$targetAspectRatio = ($images | ForEach-Object { $_.Width / [double]$_.Height } | Measure-Object -Maximum).Maximum
        [int]$cellHeight = [math]::Round($cellWidth / $targetAspectRatio)
        [int]$padding = 32
        [int]$canvasWidth = $cellWidth * 2 + $padding * 3
        [int]$canvasHeight = $cellHeight * 2 + $padding * 3

        $bitmap = New-Object System.Drawing.Bitmap($canvasWidth, $canvasHeight)
        try {
            $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
            try {
                $graphics.Clear([System.Drawing.Color]::White)
                $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                $graphics.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::AntiAliasGridFit

                $labelFont = New-Object System.Drawing.Font('Times New Roman', 36, [System.Drawing.FontStyle]::Bold)
                $labelBrush = [System.Drawing.Brushes]::Black
                $labelBack = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::White)
                $borderPen = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(180, 180, 180), 2)

                try {
                    for ($index = 0; $index -lt $images.Count; $index++) {
                        $image = $images[$index]
                        [int]$row = [math]::Floor($index / 2)
                        [int]$column = $index % 2

                        [int]$slotX = $padding + $column * ($cellWidth + $padding)
                        [int]$slotY = $padding + $row * ($cellHeight + $padding)
                        [double]$sourceAspectRatio = $image.Width / [double]$image.Height

                        if ($sourceAspectRatio -gt $targetAspectRatio) {
                            [int]$cropWidth = [math]::Round($image.Height * $targetAspectRatio)
                            [int]$cropHeight = $image.Height
                            [int]$cropX = [math]::Floor(($image.Width - $cropWidth) / 2)
                            [int]$cropY = 0
                        }
                        else {
                            [int]$cropWidth = $image.Width
                            [int]$cropHeight = [math]::Round($image.Width / $targetAspectRatio)
                            [double]$focalY = $image.Height * 0.62
                            [int]$cropY = [math]::Round($focalY - $cropHeight / 2)
                            if ($cropY -lt 0) {
                                $cropY = 0
                            }
                            if ($cropY + $cropHeight -gt $image.Height) {
                                $cropY = $image.Height - $cropHeight
                            }
                            [int]$cropX = 0
                        }

                        $destRect = New-Object System.Drawing.Rectangle($slotX, $slotY, $cellWidth, $cellHeight)
                        $sourceRect = New-Object System.Drawing.Rectangle($cropX, $cropY, $cropWidth, $cropHeight)

                        $graphics.DrawImage($image, $destRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
                        $graphics.DrawRectangle($borderPen, $slotX, $slotY, $cellWidth, $cellHeight)

                        $label = '({0})' -f [char](97 + $index)
                        $labelSize = $graphics.MeasureString($label, $labelFont)
                        [single]$labelRectX = $slotX + 10
                        [single]$labelRectY = $slotY + 10
                        [single]$labelRectWidth = $labelSize.Width + 18
                        [single]$labelRectHeight = $labelSize.Height + 10
                        $graphics.FillRectangle($labelBack, $labelRectX, $labelRectY, $labelRectWidth, $labelRectHeight)
                        $graphics.DrawString($label, $labelFont, $labelBrush, [single]($slotX + 18), [single]($slotY + 8))
                    }
                }
                finally {
                    $borderPen.Dispose()
                    $labelBack.Dispose()
                    $labelFont.Dispose()
                }
            }
            finally {
                $graphics.Dispose()
            }

            $bitmap.Save($OutputPath, [System.Drawing.Imaging.ImageFormat]::Png)
        }
        finally {
            $bitmap.Dispose()
        }
    }
    finally {
        foreach ($image in $images) {
            $image.Dispose()
        }
    }
}

$sceneConfigs = @(
    @{
        Name = 'slope'
        Inputs = @(
            (Join-Path $RepoRoot 'log\slope\compare_user_slope_repeat3_20260331\midterm_assets_extra\process\1.png'),
            (Join-Path $RepoRoot 'log\slope\compare_user_slope_repeat3_20260331\midterm_assets_extra\process\2.png'),
            (Join-Path $RepoRoot 'log\slope\compare_user_slope_repeat3_20260331\midterm_assets_extra\process\3.png'),
            (Join-Path $RepoRoot 'log\slope\compare_user_slope_repeat3_20260331\midterm_assets_extra\process\4.png')
        )
        Output = (Join-Path $outputDir 'figure_extra_slope_process_collage.png')
    },
    @{
        Name = 'step'
        Inputs = @(
            (Join-Path $RepoRoot 'log\step\compare_user_step_repeat3_20260401_fixbaseline\midterm_assets_extra\process\1.png'),
            (Join-Path $RepoRoot 'log\step\compare_user_step_repeat3_20260401_fixbaseline\midterm_assets_extra\process\2.png'),
            (Join-Path $RepoRoot 'log\step\compare_user_step_repeat3_20260401_fixbaseline\midterm_assets_extra\process\3.png'),
            (Join-Path $RepoRoot 'log\step\compare_user_step_repeat3_20260401_fixbaseline\midterm_assets_extra\process\4.png')
        )
        Output = (Join-Path $outputDir 'figure_extra_step_process_collage.png')
    },
    @{
        Name = 'ditch'
        Inputs = @(
            (Join-Path $RepoRoot 'log\ditch\compare_user_ditch_repeat3_20260331\midterm_assets_extra\process\1.png'),
            (Join-Path $RepoRoot 'log\ditch\compare_user_ditch_repeat3_20260331\midterm_assets_extra\process\2.png'),
            (Join-Path $RepoRoot 'log\ditch\compare_user_ditch_repeat3_20260331\midterm_assets_extra\process\3.png'),
            (Join-Path $RepoRoot 'log\ditch\compare_user_ditch_repeat3_20260331\midterm_assets_extra\process\4.png')
        )
        Output = (Join-Path $outputDir 'figure_extra_ditch_process_collage.png')
    }
)

foreach ($scene in $sceneConfigs) {
    New-ProcessCollage -InputPaths $scene.Inputs -OutputPath $scene.Output
    Write-Output ("Generated collage for {0}: {1}" -f $scene.Name, $scene.Output)
}
