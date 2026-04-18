param(
    [Parameter(Mandatory = $true)]
    [string]$DocxPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

$bodyRunPropsXml = @"
<w:rPr xmlns:w="$wNs">
  <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="SimSun" w:cs="Times New Roman" w:hint="eastAsia" />
  <w:sz w:val="24" />
  <w:szCs w:val="24" />
  <w:lang w:val="en-US" w:eastAsia="zh-CN" />
</w:rPr>
"@

$captionRunPropsXml = @"
<w:rPr xmlns:w="$wNs">
  <w:rFonts w:ascii="SimSun" w:hAnsi="SimSun" w:eastAsia="SimSun" w:cs="SimSun" />
  <w:sz w:val="21" />
  <w:szCs w:val="21" />
  <w:lang w:val="en-US" w:eastAsia="zh-CN" />
</w:rPr>
"@

$formulaRunPropsXml = @"
<w:rPr xmlns:w="$wNs">
  <w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:eastAsia="Times New Roman" w:cs="Times New Roman" />
  <w:sz w:val="24" />
  <w:szCs w:val="24" />
  <w:lang w:val="en-US" w:eastAsia="zh-CN" />
</w:rPr>
"@

$h2RunPropsXml = @"
<w:rPr xmlns:w="$wNs">
  <w:rFonts w:ascii="SimSun" w:hAnsi="SimSun" w:eastAsia="SimSun" w:cs="SimSun" />
  <w:b />
  <w:bCs />
  <w:sz w:val="28" />
  <w:szCs w:val="28" />
  <w:lang w:val="en-US" w:eastAsia="zh-CN" />
</w:rPr>
"@

$h3RunPropsXml = @"
<w:rPr xmlns:w="$wNs">
  <w:rFonts w:ascii="SimSun" w:hAnsi="SimSun" w:eastAsia="SimSun" w:cs="SimSun" />
  <w:b />
  <w:bCs />
  <w:sz w:val="24" />
  <w:szCs w:val="24" />
  <w:lang w:val="en-US" w:eastAsia="zh-CN" />
</w:rPr>
"@

$bodyParagraphPropsXml = @"
<w:pPr xmlns:w="$wNs">
  <w:autoSpaceDE w:val="1" />
  <w:autoSpaceDN w:val="1" />
  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto" />
  <w:ind w:firstLine="480" w:firstLineChars="200" />
</w:pPr>
"@

$captionParagraphPropsXml = @"
<w:pPr xmlns:w="$wNs">
  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto" />
  <w:jc w:val="center" />
</w:pPr>
"@

$formulaParagraphPropsXml = @"
<w:pPr xmlns:w="$wNs">
  <w:spacing w:before="0" w:after="0" w:line="240" w:lineRule="auto" />
  <w:jc w:val="center" />
</w:pPr>
"@

$imageParagraphPropsXml = @"
<w:pPr xmlns:w="$wNs">
  <w:spacing w:before="0" w:after="0" />
  <w:jc w:val="center" />
</w:pPr>
"@

$h2ParagraphPropsXml = @"
<w:pPr xmlns:w="$wNs">
  <w:keepNext />
  <w:keepLines />
  <w:spacing w:before="60" w:after="0" w:line="240" w:lineRule="auto" />
  <w:outlineLvl w:val="1" />
</w:pPr>
"@

$h3ParagraphPropsXml = @"
<w:pPr xmlns:w="$wNs">
  <w:keepNext />
  <w:keepLines />
  <w:spacing w:before="60" w:after="0" w:line="240" w:lineRule="auto" />
  <w:outlineLvl w:val="2" />
</w:pPr>
"@

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

function New-XmlElement {
    param(
        [System.Xml.XmlDocument]$Xml,
        [string]$InnerXml
    )

    $fragment = $Xml.CreateDocumentFragment()
    $fragment.InnerXml = $InnerXml
    [System.Xml.XmlElement]$fragment.FirstChild
}

function Get-ParagraphText {
    param(
        [System.Xml.XmlNode]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns
    )

    (($Paragraph.SelectNodes('.//w:t', $Ns) | ForEach-Object { $_.InnerText }) -join '').Trim()
}

function Replace-ParagraphProperties {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns,
        [System.Xml.XmlDocument]$Xml,
        [string]$ParagraphPropsXml
    )

    $existing = [System.Xml.XmlElement]$Paragraph.SelectSingleNode('./w:pPr', $Ns)
    $sectPr = $null
    if ($existing) {
        $sectPr = $existing.SelectSingleNode('./w:sectPr', $Ns)
        [void]$Paragraph.RemoveChild($existing)
    }

    $newPPr = New-XmlElement -Xml $Xml -InnerXml $ParagraphPropsXml
    if ($sectPr) {
        [void]$newPPr.AppendChild($Xml.ImportNode($sectPr, $true))
    }

    if ($Paragraph.FirstChild) {
        [void]$Paragraph.InsertBefore($newPPr, $Paragraph.FirstChild)
    }
    else {
        [void]$Paragraph.AppendChild($newPPr)
    }
}

function Replace-TextRunProperties {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns,
        [System.Xml.XmlDocument]$Xml,
        [string]$RunPropsXml
    )

    $runs = $Paragraph.SelectNodes('.//w:r[w:t]', $Ns)
    foreach ($run in $runs) {
        $existing = [System.Xml.XmlElement]$run.SelectSingleNode('./w:rPr', $Ns)
        if ($existing) {
            [void]$run.RemoveChild($existing)
        }

        $newRPr = New-XmlElement -Xml $Xml -InnerXml $RunPropsXml
        if ($run.FirstChild) {
            [void]$run.InsertBefore($newRPr, $run.FirstChild)
        }
        else {
            [void]$run.AppendChild($newRPr)
        }
    }
}

$resolvedDocx = (Resolve-Path $DocxPath).Path
$zip = [System.IO.Compression.ZipFile]::Open($resolvedDocx, [System.IO.Compression.ZipArchiveMode]::Update)

try {
    [xml]$documentXml = Read-EntryText -Zip $zip -EntryName 'word/document.xml'

    $ns = New-Object System.Xml.XmlNamespaceManager($documentXml.NameTable)
    $ns.AddNamespace('w', $wNs)

    $paragraphs = $documentXml.SelectNodes('//w:p', $ns)
    $started = $false

    foreach ($paragraph in $paragraphs) {
        $text = Get-ParagraphText -Paragraph $paragraph -Ns $ns
        $hasDrawing = [bool]$paragraph.SelectSingleNode('.//w:drawing', $ns)

        if (-not $started) {
            if ($text -match '^(一|二|三|四|五|六|七|八|九|十)、') {
                $started = $true
            }
            else {
                continue
            }
        }

        if ($hasDrawing) {
            Replace-ParagraphProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -ParagraphPropsXml $imageParagraphPropsXml
            continue
        }

        if (-not $text) {
            continue
        }

        if ($text -match '^签字：' -or $text -match '^成绩：') {
            continue
        }

        if ($text -match '^\d+\.\d+\.\d+\s') {
            Replace-ParagraphProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -ParagraphPropsXml $h3ParagraphPropsXml
            Replace-TextRunProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -RunPropsXml $h3RunPropsXml
            continue
        }

        if ($text -match '^\d+\.\d+\s') {
            Replace-ParagraphProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -ParagraphPropsXml $h2ParagraphPropsXml
            Replace-TextRunProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -RunPropsXml $h2RunPropsXml
            continue
        }

        if ($text -match '^(图|表)\d+\s') {
            Replace-ParagraphProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -ParagraphPropsXml $captionParagraphPropsXml
            Replace-TextRunProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -RunPropsXml $captionRunPropsXml
            continue
        }

        if ($text -match '^f\(p\)=3p\^2-2p\^3,\s*p∈\[0,1\]$') {
            Replace-ParagraphProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -ParagraphPropsXml $formulaParagraphPropsXml
            Replace-TextRunProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -RunPropsXml $formulaRunPropsXml
            continue
        }

        if ($text -match '^(一|二|三|四|五|六|七|八|九|十)、') {
            continue
        }

        Replace-ParagraphProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -ParagraphPropsXml $bodyParagraphPropsXml
        Replace-TextRunProperties -Paragraph $paragraph -Ns $ns -Xml $documentXml -RunPropsXml $bodyRunPropsXml
    }

    Save-XmlToZip -Zip $zip -EntryName 'word/document.xml' -Xml $documentXml
}
finally {
    $zip.Dispose()
}

Write-Output 'Normalized report formatting successfully.'
