param(
    [Parameter(Mandatory = $true)]
    [string]$DocxPath,

    [string]$AssetsDir = (Join-Path $PSScriptRoot '..\..\log\ditch\compare_user_ditch_repeat3_20260331\midterm_assets')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Security
Add-Type -AssemblyName System.Drawing

$wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$wpNs = 'http://schemas.openxmlformats.org/drawingml/2006/wordprocessingDrawing'
$aNs = 'http://schemas.openxmlformats.org/drawingml/2006/main'
$picNs = 'http://schemas.openxmlformats.org/drawingml/2006/picture'
$rNs = 'http://schemas.openxmlformats.org/officeDocument/2006/relationships'
$relNs = 'http://schemas.openxmlformats.org/package/2006/relationships'

$markdownFile = 'section_1_2_3_ditch_revised.md'
$sectionPrefix = '1.2.3 '
$nextSectionPrefix = '二、'
$imageWidthEmu = 5233973

$figures = @(
    @{
        Placeholder = '图1'
        File = 'figure1_ditch_process_comparison.png'
        FigureRef = '图7'
        Caption = '图7 深沟场景三阶段过程收敛对比图'
    },
    @{
        Placeholder = '图2'
        File = 'figure2_ditch_passability_comparison.png'
        FigureRef = '图8'
        Caption = '图8 深沟场景通过性指标对比图'
    },
    @{
        Placeholder = '图3'
        File = 'figure3_ditch_stability_comparison.png'
        FigureRef = '图9'
        Caption = '图9 深沟场景稳定性指标对比图'
    }
)

function Escape-Xml {
    param([string]$Text)
    [System.Security.SecurityElement]::Escape($Text)
}

function Read-EntryText {
    param(
        [System.IO.Compression.ZipArchive]$Zip,
        [string]$EntryName
    )

    $entry = $Zip.GetEntry($EntryName)
    if (-not $entry) {
        throw "Entry not found: $EntryName"
    }

    $stream = $entry.Open()
    try {
        $reader = New-Object System.IO.StreamReader($stream)
        try {
            return $reader.ReadToEnd()
        }
        finally {
            $reader.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Save-XmlToZip {
    param(
        [System.IO.Compression.ZipArchive]$Zip,
        [string]$EntryName,
        [System.Xml.XmlDocument]$Xml
    )

    $existing = $Zip.GetEntry($EntryName)
    if ($existing) {
        $existing.Delete()
    }

    $entry = $Zip.CreateEntry($EntryName)
    $stream = $entry.Open()
    try {
        $writer = New-Object System.IO.StreamWriter($stream, (New-Object System.Text.UTF8Encoding($false)))
        try {
            $Xml.Save($writer)
        }
        finally {
            $writer.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-ParagraphText {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    (($Paragraph.SelectNodes('.//w:t', $Ns) | ForEach-Object { $_.InnerText }) -join '')
}

function Get-FirstParagraphByPrefix {
    param(
        [System.Xml.XmlNodeList]$Paragraphs,
        [System.Xml.XmlNamespaceManager]$Ns,
        [string]$Prefix
    )

    foreach ($paragraph in $Paragraphs) {
        if ((Get-ParagraphText -Paragraph $paragraph -Ns $Ns).StartsWith($Prefix, [System.StringComparison]::Ordinal)) {
            return [System.Xml.XmlElement]$paragraph
        }
    }

    throw "Paragraph prefix not found: $Prefix"
}

function Get-NextRelationshipId {
    param([System.Xml.XmlDocument]$Relationships)

    $max = 0
    foreach ($rel in $Relationships.DocumentElement.ChildNodes) {
        $id = $rel.GetAttribute('Id')
        if ($id -match '^rId(\d+)$') {
            $num = [int]$Matches[1]
            if ($num -gt $max) {
                $max = $num
            }
        }
    }

    "rId$($max + 1)"
}

function Get-NextMediaIndex {
    param([System.IO.Compression.ZipArchive]$Zip)

    $max = 0
    foreach ($entry in $Zip.Entries) {
        if ($entry.FullName -match '^word/media/image(\d+)\.(png|jpe?g)$') {
            $num = [int]$Matches[1]
            if ($num -gt $max) {
                $max = $num
            }
        }
    }

    $max + 1
}

function Get-NextDocPropertyId {
    param(
        [System.Xml.XmlNodeList]$Paragraphs,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    $max = 0
    foreach ($paragraph in $Paragraphs) {
        $docPr = [System.Xml.XmlElement]$paragraph.SelectSingleNode('.//wp:docPr', $Ns)
        if ($docPr) {
            $id = [int]$docPr.GetAttribute('id')
            if ($id -gt $max) {
                $max = $id
            }
        }
    }

    $max + 1
}

function Get-PngSize {
    param([string]$Path)

    $image = [System.Drawing.Image]::FromFile($Path)
    try {
        @{
            Width = $image.Width
            Height = $image.Height
        }
    }
    finally {
        $image.Dispose()
    }
}

function New-ParagraphFragment {
    param(
        [System.Xml.XmlDocument]$Xml,
        [string]$InnerXml
    )

    $fragment = $Xml.CreateDocumentFragment()
    $fragment.InnerXml = $InnerXml
    [System.Xml.XmlElement]$fragment.FirstChild
}

function New-HeadingParagraph {
    param(
        [System.Xml.XmlDocument]$Xml,
        [string]$Text
    )

    $escaped = Escape-Xml $Text
    New-ParagraphFragment -Xml $Xml -InnerXml @"
<w:p xmlns:w="$wNs">
  <w:pPr>
    <w:keepNext />
    <w:keepLines />
    <w:spacing w:before="60" w:after="0" w:line="240" w:lineRule="auto" />
    <w:outlineLvl w:val="2" />
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="SimSun" w:hAnsi="SimSun" w:eastAsia="SimSun" w:cs="SimSun" />
      <w:b />
      <w:bCs />
      <w:sz w:val="24" />
      <w:szCs w:val="24" />
      <w:lang w:val="en-US" w:eastAsia="zh-CN" />
    </w:rPr>
    <w:t>$escaped</w:t>
  </w:r>
</w:p>
"@
}

function New-BodyParagraph {
    param(
        [System.Xml.XmlDocument]$Xml,
        [string]$Text
    )

    $escaped = Escape-Xml $Text
    New-ParagraphFragment -Xml $Xml -InnerXml @"
<w:p xmlns:w="$wNs">
  <w:pPr>
    <w:autoSpaceDE w:val="1" />
    <w:autoSpaceDN w:val="1" />
    <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto" />
    <w:ind w:firstLine="480" w:firstLineChars="200" />
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="SimSun" w:cs="Times New Roman" w:hint="eastAsia" />
      <w:sz w:val="24" />
      <w:szCs w:val="24" />
      <w:lang w:val="en-US" w:eastAsia="zh-CN" />
    </w:rPr>
    <w:t>$escaped</w:t>
  </w:r>
</w:p>
"@
}

function New-CaptionParagraph {
    param(
        [System.Xml.XmlDocument]$Xml,
        [string]$Text
    )

    $escaped = Escape-Xml $Text
    New-ParagraphFragment -Xml $Xml -InnerXml @"
<w:p xmlns:w="$wNs">
  <w:pPr>
    <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto" />
    <w:jc w:val="center" />
  </w:pPr>
  <w:r>
    <w:rPr>
      <w:rFonts w:ascii="SimSun" w:hAnsi="SimSun" w:eastAsia="SimSun" w:cs="SimSun" />
      <w:sz w:val="21" />
      <w:szCs w:val="21" />
      <w:lang w:val="en-US" w:eastAsia="zh-CN" />
    </w:rPr>
    <w:t>$escaped</w:t>
  </w:r>
</w:p>
"@
}

function New-ImageParagraph {
    param(
        [System.Xml.XmlDocument]$Xml,
        [string]$RelationshipId,
        [string]$Name,
        [string]$Description,
        [int]$DocPropertyId,
        [long]$Cx,
        [long]$Cy
    )

    $escapedName = Escape-Xml $Name
    $escapedDescription = Escape-Xml $Description
    New-ParagraphFragment -Xml $Xml -InnerXml @"
<w:p xmlns:w="$wNs" xmlns:wp="$wpNs" xmlns:a="$aNs" xmlns:pic="$picNs" xmlns:r="$rNs">
  <w:pPr>
    <w:spacing w:before="0" w:after="0" />
    <w:jc w:val="center" />
  </w:pPr>
  <w:r>
    <w:drawing>
      <wp:inline distT="0" distB="0" distL="0" distR="0">
        <wp:extent cx="$Cx" cy="$Cy" />
        <wp:effectExtent l="0" t="0" r="0" b="0" />
        <wp:docPr id="$DocPropertyId" name="$escapedName" descr="$escapedDescription" />
        <wp:cNvGraphicFramePr>
          <a:graphicFrameLocks noChangeAspect="1" />
        </wp:cNvGraphicFramePr>
        <a:graphic>
          <a:graphicData uri="http://schemas.openxmlformats.org/drawingml/2006/picture">
            <pic:pic>
              <pic:nvPicPr>
                <pic:cNvPr id="0" name="$escapedName" />
                <pic:cNvPicPr />
              </pic:nvPicPr>
              <pic:blipFill>
                <a:blip r:embed="$RelationshipId" cstate="print" />
                <a:stretch>
                  <a:fillRect />
                </a:stretch>
              </pic:blipFill>
              <pic:spPr>
                <a:xfrm>
                  <a:off x="0" y="0" />
                  <a:ext cx="$Cx" cy="$Cy" />
                </a:xfrm>
                <a:prstGeom prst="rect">
                  <a:avLst />
                </a:prstGeom>
              </pic:spPr>
            </pic:pic>
          </a:graphicData>
        </a:graphic>
      </wp:inline>
    </w:drawing>
  </w:r>
</w:p>
"@
}

function Load-SectionContent {
    param([string]$Directory)

    $markdownPath = Join-Path $Directory $markdownFile
    if (-not (Test-Path $markdownPath)) {
        throw "Markdown source not found: $markdownPath"
    }

    $markdown = Get-Content -Raw $markdownPath
    $blocks = [regex]::Split($markdown.Trim(), "\r?\n\s*\r?\n") |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }

    if ($blocks.Count -lt 2) {
        throw 'Markdown source does not contain enough content blocks.'
    }

    $heading = ($blocks[0] -replace '^#+\s*', '').Replace("`r", ' ').Replace("`n", ' ').Trim()
    $items = New-Object System.Collections.ArrayList

    foreach ($block in $blocks[1..($blocks.Count - 1)]) {
        $normalized = ($block -replace '`', '').Replace("`r", "`n").Replace("`n", ' ').Trim()
        $matchedFigure = $null

        foreach ($figure in $figures) {
            if ($normalized.StartsWith("【$($figure.Placeholder)", [System.StringComparison]::Ordinal)) {
                $matchedFigure = $figure
                break
            }
        }

        if ($matchedFigure) {
            [void]$items.Add(@{
                Type = 'figure'
                Figure = $matchedFigure
            })
            continue
        }

        foreach ($figure in $figures) {
            $normalized = $normalized.Replace($figure.Placeholder, $figure.FigureRef)
        }

        [void]$items.Add(@{
            Type = 'paragraph'
            Text = $normalized
        })
    }

    @{
        Heading = $heading
        Items = $items
    }
}

$resolvedDocx = (Resolve-Path $DocxPath).Path
$resolvedAssets = (Resolve-Path $AssetsDir).Path
$sectionContent = Load-SectionContent -Directory $resolvedAssets

$zip = [System.IO.Compression.ZipFile]::Open($resolvedDocx, [System.IO.Compression.ZipArchiveMode]::Update)
try {
    [xml]$documentXml = Read-EntryText -Zip $zip -EntryName 'word/document.xml'
    [xml]$relationshipsXml = Read-EntryText -Zip $zip -EntryName 'word/_rels/document.xml.rels'

    $ns = New-Object System.Xml.XmlNamespaceManager($documentXml.NameTable)
    $ns.AddNamespace('w', $wNs)
    $ns.AddNamespace('wp', $wpNs)

    $allParagraphs = $documentXml.SelectNodes('//w:p', $ns)
    $sectionHeading = Get-FirstParagraphByPrefix -Paragraphs $allParagraphs -Ns $ns -Prefix $sectionPrefix
    $nextHeading = Get-FirstParagraphByPrefix -Paragraphs $allParagraphs -Ns $ns -Prefix $nextSectionPrefix

    $newHeading = New-HeadingParagraph -Xml $documentXml -Text $sectionContent.Heading
    [void]$sectionHeading.ParentNode.ReplaceChild($newHeading, $sectionHeading)
    $sectionHeading = $newHeading

    $node = $sectionHeading.NextSibling
    while ($node -and $node -ne $nextHeading) {
        $nextNode = $node.NextSibling
        [void]$sectionHeading.ParentNode.RemoveChild($node)
        $node = $nextNode
    }

    $docPropertyId = Get-NextDocPropertyId -Paragraphs $allParagraphs -Ns $ns
    $mediaIndex = Get-NextMediaIndex -Zip $zip

    $newElements = New-Object System.Collections.ArrayList
    foreach ($item in $sectionContent.Items) {
        if ($item.Type -eq 'paragraph') {
            [void]$newElements.Add((New-BodyParagraph -Xml $documentXml -Text $item.Text))
            continue
        }

        $figure = $item.Figure
        $imagePath = Join-Path $resolvedAssets $figure.File
        $size = Get-PngSize -Path $imagePath
        $imageHeightEmu = [long][math]::Round($imageWidthEmu * $size.Height / $size.Width)
        $relationshipId = Get-NextRelationshipId -Relationships $relationshipsXml
        $mediaTarget = "media/image$mediaIndex.png"

        $relationship = $relationshipsXml.CreateElement('Relationship', $relNs)
        [void]$relationship.SetAttribute('Id', $relationshipId)
        [void]$relationship.SetAttribute('Type', 'http://schemas.openxmlformats.org/officeDocument/2006/relationships/image')
        [void]$relationship.SetAttribute('Target', $mediaTarget)
        [void]$relationshipsXml.DocumentElement.AppendChild($relationship)

        [System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip,
            $imagePath,
            "word/$mediaTarget",
            [System.IO.Compression.CompressionLevel]::Optimal
        ) | Out-Null

        [void]$newElements.Add((New-ImageParagraph -Xml $documentXml -RelationshipId $relationshipId -Name $figure.File -Description $figure.Caption -DocPropertyId $docPropertyId -Cx $imageWidthEmu -Cy $imageHeightEmu))
        [void]$newElements.Add((New-CaptionParagraph -Xml $documentXml -Text $figure.Caption))

        $docPropertyId++
        $mediaIndex++
    }

    foreach ($element in $newElements) {
        [void]$nextHeading.ParentNode.InsertBefore($element, $nextHeading)
    }

    Save-XmlToZip -Zip $zip -EntryName 'word/document.xml' -Xml $documentXml
    Save-XmlToZip -Zip $zip -EntryName 'word/_rels/document.xml.rels' -Xml $relationshipsXml
}
finally {
    $zip.Dispose()
}

Write-Output 'Updated section 1.2.3 successfully.'
