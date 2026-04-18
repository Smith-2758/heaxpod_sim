param(
    [Parameter(Mandatory = $true)]
    [string]$DocxPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'

$replacements = @(
    @{
        Match = @(
            '2.1 机器人伸腿入坑动作仍不够自然',
            '2.1 深沟场景下足端入坑探测动作仍不够自然'
        )
        New = '2.1 深沟场景下足端入坑探测动作仍不够自然'
    },
    @{
        Match = @(
            '第1段建议：先把问题写具体。可写当前很多时候机器人只有在姿态已经出现一定失稳趋势时，腿部才较容易真正探入坑中；如果机身姿态过于稳定，足端反而不容易自然下探。这说明伸腿动作、机体姿态和整机重心之间的配合关系仍不够理想。',
            '目前深沟场景中，机器人伸腿入坑的动作还不够自然。从已有仿真现象来看，足端能否顺利下探和机体姿态、重心位置以及支撑状态有较大关系。很多时候，只有在机身已经出现一定失稳趋势时，腿部才比较容易真正探入坑中；如果机身姿态较稳，足端反而不容易自然下探。这说明现阶段足端下探轨迹和整机姿态之间的配合还不够理想。'
        )
        New = '目前深沟场景中，机器人伸腿入坑的动作还不够自然。从已有仿真现象来看，足端能否顺利下探和机体姿态、重心位置以及支撑状态有较大关系。很多时候，只有在机身已经出现一定失稳趋势时，腿部才比较容易真正探入坑中；如果机身姿态较稳，足端反而不容易自然下探。这说明现阶段足端下探轨迹和整机姿态之间的配合还不够理想。'
    },
    @{
        Match = @(
            '第2段建议：再写拟解决方案。建议从足端下探轨迹、机体姿态预调节和重心分配三方面联合展开，后续重点改善入坑阶段腿部运动与整机姿态之间的匹配关系，使足端能够在更自然、更可控的状态下完成探测和跨越。',
            '后续准备继续从足端下探轨迹、机体预调姿态和重心分配几个方面进行调整，重点改善入坑阶段腿部动作与整机状态之间的匹配关系。同时，还会结合关键阶段的关节角变化做进一步检查，分析该问题是否与部分工况下接近关节限位有关，并据此对轨迹参数和动作顺序作进一步修改。'
        )
        New = '后续准备继续从足端下探轨迹、机体预调姿态和重心分配几个方面进行调整，重点改善入坑阶段腿部动作与整机状态之间的匹配关系。同时，还会结合关键阶段的关节角变化做进一步检查，分析该问题是否与部分工况下接近关节限位有关，并据此对轨迹参数和动作顺序作进一步修改。'
    },
    @{
        Match = @(
            '2.2 基于ZMP的稳定控制建模与程序实现仍需进一步完善',
            '2.2 基于ZMP的稳定控制建模与控制实现仍需进一步完善',
            '2.2 基于ZMP的稳定控制建模与闭环控制实现仍需进一步完善'
        )
        New = '2.2 基于ZMP的稳定控制建模与控制实现仍需进一步完善'
    },
    @{
        Match = @(
            '第1段建议：这一段先回扣任务书要求。可写任务书明确提出要围绕ZMP判据开展稳定控制研究，当前工程在复杂地形轨迹规划和局部避险逻辑方面已经取得较多进展，但从课题整体要求看，仍需进一步形成面向复杂地形行走的ZMP稳定控制建模、程序实现与量化验证体系。',
            '按照任务书要求，后续还需要围绕 ZMP 判据开展复杂地形下的稳定控制研究。现阶段的工作主要集中在轨迹规划、局部避险和多场景仿真对比上，斜坡、高台和深沟场景已经取得了一定进展，但基于 ZMP 的稳定控制部分还没有真正实现。也就是说，目前还没有把 ZMP 判据进一步转化为对机体姿态、重心转移和运动过程的实际控制，相关程序和控制流程还需要继续补充。'
        )
        New = '按照任务书要求，后续还需要围绕 ZMP 判据开展复杂地形下的稳定控制研究。现阶段的工作主要集中在轨迹规划、局部避险和多场景仿真对比上，斜坡、高台和深沟场景已经取得了一定进展，但基于 ZMP 的稳定控制部分还没有真正实现。也就是说，目前还没有把 ZMP 判据进一步转化为对机体姿态、重心转移和运动过程的实际控制，相关程序和控制流程还需要继续补充。'
    },
    @{
        Match = @(
            '第2段建议：这一段写后续打算怎么补。建议写后续将在现有仿真平台上补充ZMP相关状态记录与稳定性指标计算，把机体姿态、足端支撑反力和支撑多边形约束统一起来，逐步形成从轨迹规划、稳定性判据计算到姿态控制反馈的一体化实现链路。',
            '下一步将在现有 MATLAB 与 CoppeliaSim 联合仿真平台基础上，开展基于 ZMP 的稳定控制建模、程序实现和仿真验证。具体包括支撑足识别、支撑多边形构建、ZMP 位置计算，以及根据 ZMP 相对支撑域的位置对机体姿态和重心转移进行调整，并逐步将其和现有轨迹规划过程结合起来，形成从轨迹生成、稳定性判断到姿态调节的完整控制过程。'
        )
        New = '下一步将在现有 MATLAB 与 CoppeliaSim 联合仿真平台基础上，开展基于 ZMP 的稳定控制建模、程序实现和仿真验证。具体包括支撑足识别、支撑多边形构建、ZMP 位置计算，以及根据 ZMP 相对支撑域的位置对机体姿态和重心转移进行调整，并逐步将其和现有轨迹规划过程结合起来，形成从轨迹生成、稳定性判断到姿态调节的完整控制过程。'
    },
    @{
        Match = @(
            '2.3 摆动相起步与落地衔接仍存在局部冲击和不连续现象',
            '2.3 足端轻落地控制与轨迹衔接平顺性仍需继续优化'
        )
        New = '2.3 足端轻落地控制与轨迹衔接平顺性仍需继续优化'
    },
    @{
        Match = @(
            '第1段建议：写清问题表现。可说明当前在复杂地形动作切换过程中，尤其是摆动相起步和落地衔接处，仍可能出现局部冲击和轨迹连续性不足的情况，这不仅影响受力平顺性，也会削弱姿态稳定性分析的说服力。',
            '从目前的仿真结果来看，机器人在复杂地形中的基本动作已经能够完成，但在摆动相起步、足端落地以及重新接回理论轨迹的过程中，局部冲击仍然偏大，轨迹衔接也还不够平顺。虽然前期已经通过原位锁定和短时软过渡等方法减轻了一部分落地反弹，但从受力变化和动作表现来看，落地瞬间的速度突变和局部冲击还没有完全压下来。'
        )
        New = '从目前的仿真结果来看，机器人在复杂地形中的基本动作已经能够完成，但在摆动相起步、足端落地以及重新接回理论轨迹的过程中，局部冲击仍然偏大，轨迹衔接也还不够平顺。虽然前期已经通过原位锁定和短时软过渡等方法减轻了一部分落地反弹，但从受力变化和动作表现来看，落地瞬间的速度突变和局部冲击还没有完全压下来。'
    },
    @{
        Match = @(
            '第2段建议：写清拟解决方案。建议从足端高度过渡、速度连续性以及动作切换条件三方面继续优化，并结合受力变化、足端高度变化和ZMP稳定性表现，对轨迹连接段进行针对性改进，以进一步减小动作切换处的瞬态冲击。',
            '后续将继续围绕轻落地这一目标开展优化。一方面进一步调整足端高度轨迹和速度过渡，减小摆动相起步和落地时的突变；另一方面继续修改动作切换条件和落地后的缓冲处理，使足端从探测、接触到重新起步的过程更加连贯。后面还会结合受力峰值、足端高度变化和机体姿态响应，对轻落地效果进行分析和验证。'
        )
        New = '后续将继续围绕轻落地这一目标开展优化。一方面进一步调整足端高度轨迹和速度过渡，减小摆动相起步和落地时的突变；另一方面继续修改动作切换条件和落地后的缓冲处理，使足端从探测、接触到重新起步的过程更加连贯。后面还会结合受力峰值、足端高度变化和机体姿态响应，对轻落地效果进行分析和验证。'
    },
    @{
        Match = @(
            '1. 继续完善复杂地形轨迹规划，并开展多场景综合越障能力考验。后续不再只针对单一场景分别调整，而是逐步从斜坡、台阶、深沟等多场景角度综合考察机器人越障能力，重点关注轨迹连续性、姿态协调性和障碍适应能力。',
            '4月6日~4月15日，继续围绕深沟场景开展调试，重点优化足端入坑探测动作和轻落地控制。后续将结合仿真结果，对足端下探轨迹、机体预调姿态和重心分配进行进一步调整，并检查伸腿入坑不够自然这一问题是否与部分工况下接近关节限位有关。'
        )
        New = '4月6日~4月15日，继续围绕深沟场景开展调试，重点优化足端入坑探测动作和轻落地控制。后续将结合仿真结果，对足端下探轨迹、机体预调姿态和重心分配进行进一步调整，并检查伸腿入坑不够自然这一问题是否与部分工况下接近关节限位有关。'
    },
    @{
        Match = @(
            '2. 推进基于ZMP的稳定控制建模、程序实现与指标验证。在现有仿真平台基础上补充ZMP轨迹计算、稳定裕度分析和支撑状态约束判断，并将ZMP指标与姿态波动、受力变化和轨迹执行结果结合起来，形成复杂地形稳定性分析的统一依据。',
            '4月16日~4月30日，在现有 MATLAB 与 CoppeliaSim 联合仿真平台基础上，继续开展基于 ZMP 的稳定控制建模、程序实现与仿真验证。主要工作包括支撑足识别、支撑多边形构建、ZMP 位置计算，以及根据稳定控制需求对机体姿态和重心转移进行调整，并结合斜坡、高台和深沟场景开展重复仿真和结果分析。'
        )
        New = '4月16日~4月30日，在现有 MATLAB 与 CoppeliaSim 联合仿真平台基础上，继续开展基于 ZMP 的稳定控制建模、程序实现与仿真验证。主要工作包括支撑足识别、支撑多边形构建、ZMP 位置计算，以及根据稳定控制需求对机体姿态和重心转移进行调整，并结合斜坡、高台和深沟场景开展重复仿真和结果分析。'
    },
    @{
        Match = @(
            '3. 实现机器人的轻落地问题。',
            '5月，整理各场景实验数据、轨迹图和指标结果，完成毕业设计论文撰写与修改，进一步完善图表和正文分析内容，并准备毕业设计答辩。'
        )
        New = '5月，整理各场景实验数据、轨迹图和指标结果，完成毕业设计论文撰写与修改，进一步完善图表和正文分析内容，并准备毕业设计答辩。'
    }
)

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

    (($Paragraph.SelectNodes('.//w:t', $Ns) | ForEach-Object { $_.InnerText }) -join '').Trim()
}

function Replace-ParagraphText {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns,
        [System.Xml.XmlDocument]$Xml,
        [string]$Text
    )

    $templateRun = [System.Xml.XmlElement]$Paragraph.SelectSingleNode('./w:r', $Ns)
    if (-not $templateRun) {
        $templateRun = $Xml.CreateElement('w', 'r', $wNs)
    }
    else {
        $templateRun = [System.Xml.XmlElement]$templateRun.CloneNode($true)
    }

    @($templateRun.ChildNodes) | Where-Object { $_.LocalName -ne 'rPr' } | ForEach-Object {
        [void]$templateRun.RemoveChild($_)
    }

    $textNode = $Xml.CreateElement('w', 't', $wNs)
    if ($Text.StartsWith(' ') -or $Text.EndsWith(' ')) {
        [void]$textNode.SetAttribute('space', 'http://www.w3.org/XML/1998/namespace', 'preserve')
    }
    $textNode.InnerText = $Text
    [void]$templateRun.AppendChild($textNode)

    @($Paragraph.ChildNodes) | Where-Object { $_.LocalName -ne 'pPr' } | ForEach-Object {
        [void]$Paragraph.RemoveChild($_)
    }
    [void]$Paragraph.AppendChild($templateRun)
}

$resolvedDocx = (Resolve-Path $DocxPath).Path
$zip = [System.IO.Compression.ZipFile]::Open($resolvedDocx, [System.IO.Compression.ZipArchiveMode]::Update)

try {
    [xml]$documentXml = Read-EntryText -Zip $zip -EntryName 'word/document.xml'

    $ns = New-Object System.Xml.XmlNamespaceManager($documentXml.NameTable)
    $ns.AddNamespace('w', $wNs)

    $paragraphs = $documentXml.SelectNodes('//w:p', $ns)

    foreach ($replacement in $replacements) {
        $matched = $null

        foreach ($paragraph in $paragraphs) {
            $text = Get-ParagraphText -Paragraph $paragraph -Ns $ns
            foreach ($candidate in $replacement.Match) {
                if ($text.StartsWith($candidate, [System.StringComparison]::Ordinal)) {
                    $matched = [System.Xml.XmlElement]$paragraph
                    break
                }
            }

            if ($matched) {
                break
            }
        }

        if (-not $matched) {
            throw "Paragraph match not found: $($replacement.New)"
        }

        Replace-ParagraphText -Paragraph $matched -Ns $ns -Xml $documentXml -Text $replacement.New
    }

    Save-XmlToZip -Zip $zip -EntryName 'word/document.xml' -Xml $documentXml
}
finally {
    $zip.Dispose()
}

Write-Output 'Rewrote sections II and III successfully.'
