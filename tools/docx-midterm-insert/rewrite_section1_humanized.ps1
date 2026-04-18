param(
    [Parameter(Mandatory = $true)]
    [string]$DocxPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$wNs = 'http://schemas.openxmlformats.org/wordprocessingml/2006/main'
$slopeIntroPrefix = '15°斜坡场景主要用来检验机器人连续上坡时的通过能力和姿态稳定性'
$slopeFormulaText = 'f(p)=3p^2-2p^3, p∈[0,1]'
$slopeFormulaExplainText = '其中 p∈[0,1] 表示归一化过渡进度。该函数在起点和终点处的一阶导数都为 0，适合用来处理高度和俯仰角这类量的渐变，因此能减小入坡时的状态突变。'

$replacements = @(
    @{
        Prefix = '随着六足机器人在灾害救援、野外运输和复杂环境作业中的应用需求不断增加'
        New = '六足机器人在灾害救援、野外运输和复杂环境作业中有较强的应用需求，因此有必要研究其在复杂地面上的稳定行走方法。这一问题既有工程意义，也直接关系到后续轨迹规划和控制策略的设计。'
    },
    @{
        Prefix = '本次毕业设计围绕重型六足机器人在斜坡、台阶、深沟等复杂地面上的稳定行走问题展开'
        New = '本次毕业设计主要研究重型六足机器人在斜坡、台阶和深沟等复杂地形上的稳定行走问题。现阶段的工作包括机器人运动学与动力学分析、复杂地形下的足端轨迹规划与步态设计、基于 ZMP 判据的姿态稳定控制研究，以及 MATLAB 与 CoppeliaSim 联合仿真验证。具体做法是先建立机器人和典型复杂地形模型，分析机体姿态、落足位置与支撑状态之间的关系；再针对不同地形分别设计轨迹和步态，并结合姿态调节与支撑受力信息逐步完善控制方法；最后通过多场景仿真比较轨迹执行效果、姿态稳定性和落地冲击。预期成果是形成一套面向复杂地形行走的轨迹规划与稳定控制方案，并完成相应的程序实现和仿真验证。'
    },
    @{
        Prefix = '15°斜坡场景主要用于检验六足机器人在连续上坡过程中的通过能力和姿态稳定性'
        New = '15°斜坡场景主要用来检验机器人连续上坡时的通过能力和姿态稳定性。传统方案主要靠足端简单抬升来适应坡面，虽然能够完成基本爬坡，但对坡前过渡、机身前倾建立和重心调节考虑不够，因此在入坡后容易出现回滑较大、姿态波动明显和推进效率偏低的问题。针对这些现象，当前方案在接近坡面前提前抬升机身，并把俯仰姿态变化写入逆运动学求解。这里采用了三次平滑阶跃函数来处理高度和俯仰角的渐变，其表达式为：'
    },
    @{
        Prefix = '从图2可以看出，当前方案在前腿到达坡面前沿之前就已经开始建立机身高度和姿态过渡'
        New = '从图2可以看出，当前方案在前腿接近坡面前就开始建立机身高度和姿态过渡，进入坡面后的轨迹更连续，俯仰角也能较平稳地过渡到 15° 左右并保持。相比之下，传统方案在入坡阶段准备不足，俯仰角波动更明显，说明仅靠足端简单抬升还不足以形成稳定的贴坡姿态。这与代码中提前预抬升、分段重心调节以及用同样方法处理俯仰角过渡的设计是一致的。'
    },
    @{
        Prefix = '从通过性指标来看，当前方案的通过距离由 6.345 m 提高到 7.553 m'
        New = '从通过性指标来看，当前方案的通过距离由 6.345 m 提高到 7.553 m，提升 19.0%；高度增益由 0.907 m 提高到 1.194 m，提升 31.6%；路径效率由 0.644 提高到 0.880，提升 36.7%。这里的路径效率表示实际位移与总行走路径长度的比值，可用于反映推进过程中的有效前进程度。以上结果说明，当前方案在适当降低速度的情况下，仍然取得了更好的前进效果和更高的有效推进能力。'
    },
    @{
        Prefix = '从稳定性指标来看，当前方案的回滑距离由 0.705 m 降至 0.231 m'
        New = '从稳定性指标来看，当前方案的回滑距离由 0.705 m 降至 0.231 m，下降 67.2%；总受力均方根由 101883 N 降至 88215 N，下降 13.4%；横滚峰值由 5.299° 降至 1.683°，下降 68.2%；航向漂移由 2.824° 降至 1.120°，下降 60.3%。这说明优化后的方案不仅提高了通过能力，也减小了受力波动、横向晃动和方向偏移，使机器人在斜坡上的运动更稳定。'
    },
    @{
        Prefix = '综合来看，斜坡场景下的性能提升主要来自三个方面'
        New = '总体来看，斜坡场景下的改进主要体现在三个地方：坡前提前抬升机身，改善了进入坡面的初始几何关系；把俯仰调节纳入逆运动学求解，使机身姿态和足端轨迹变化保持一致；采用相同的三次平滑阶跃处理减小了平地到坡面的状态突变。平均速度由 0.488 m/s 调整为 0.445 m/s，下降 8.7%，这一变化主要是为了提高上坡稳定性，因此不视为性能退化。综合这些结果，当前方案在 15° 斜坡场景下较好地兼顾了推进能力、爬升能力和姿态稳定性。'
    },
    @{
        Prefix = '高台场景下，传统方案主要依赖阈值切换完成高度补偿'
        New = '0.5 m 高台场景主要用来检验机器人在离散障碍前的机身抬升和越障衔接能力。传统方案主要依赖阈值切换完成高度补偿。按本次修正后的对比结果，旧方案虽然能够完成上台，但越台阶段的机身高度调整较为零散，在接近台阶前沿和后腿跟进时更容易出现局部突变，从而带来较明显的姿态波动。'
    },
    @{
        Prefix = '针对这一问题，当前方案对越台阶段的机体高度调节进行了重新组织'
        New = '这里的改进主要集中在越台阶段的机体高度调节。当前方案在整体抬升过程中采用了与斜坡场景相同的三次平滑阶跃处理，并适当后移抬升峰值；同时将最高底盘高度由 0.5 m 下调至 0.4 m，以减轻后腿悬空和机体前倾。'
    },
    @{
        Prefix = '从图5可以看出，两种方案在越台阶段的质心高度变化存在明显差别'
        New = '从图5可以看出，两种方案在越台阶段的质心高度变化有明显差别。传统方案的曲线在接近台阶前沿和后续跟进阶段出现多次斜率变化，说明机体抬升与足端动作之间的衔接还不够稳定。相比之下，当前方案在中段抬升区间的曲线更连续，过渡也更缓，这与采用相同平滑阶跃处理和峰值后移的设计是一致的。抬升峰值降低后，越台后段的平台段波动也有所减弱，说明机体姿态调整更协调。'
    },
    @{
        Prefix = '如图6所示，当前方案的通过距离由 5.268 m 提高到 6.311 m'
        New = '如图6所示，当前方案的通过距离由 5.268 m 提高到 6.311 m，提高 19.8%；总受力均方根由 79850 N 降到 70265 N，下降 12.0%。这说明机器人在完成越台动作后可以保持更长的稳定前进距离，同时接触过程中的整体冲击也有所减小。'
    },
    @{
        Prefix = '为进一步描述越台过程中的稳定性，本文引入了垂向平滑指标和阶段俯仰峰值'
        New = '为进一步描述越台过程的稳定性，本文引入了垂向平滑指标和阶段俯仰峰值。垂向平滑指标由 9.53e-05 降到 5.81e-05，下降 39.1%。该指标越小，说明质心高度变化越平顺，也更能反映采用相同平滑阶跃处理和峰值后移的效果。阶段俯仰峰值由 3.398° 降到 1.330°，下降 60.9%。这说明在最高底盘高度下调到 0.4 m 后，越台阶段的前后俯仰扰动明显减小，机体姿态控制更稳定。'
    },
    @{
        Prefix = '总体来看，当前方案的优化重点不在于单纯提高机身抬升幅度'
        New = '总体来看，高台场景下的改进重点不在于单纯提高机身抬升幅度，而在于协调抬升节奏、姿态变化和接触受力。按这组修正后的结果，当前方案在越台过程中更平顺，姿态控制也更稳定。'
    },
    @{
        Prefix = '深沟场景主要用于评估六足机器人在未知落脚条件下的跨越能力'
        New = '深沟场景主要用来评估机器人在未知落脚条件下的跨越能力。与斜坡和高台不同，这一场景不仅看前向通过能力，还要看足端踩空后的识别、恢复和姿态约束是否有效，否则很容易出现反复试探、方向偏移和整机失稳。因此，本节将深沟实验分为传统方案、优化方案和当前方案三个阶段，用于说明控制策略从开环跨坑到半闭环收敛的改进过程。'
    },
    @{
        Prefix = '传统方案本质为三角步态下的开环跨坑策略'
        New = '传统方案属于三角步态下的开环跨坑策略。三角步态在规则支撑条件下瞬时静稳定性较好，因此部分姿态指标看起来较保守，但在深沟边缘一旦发生踩空，该方案缺乏在线补救机制，很难稳定完成跨越。后续方案改为波浪步态，并加入力觉探测和闭环恢复逻辑。这样做提高了可操作性，但也带来了横向漂移、偏航累积和姿态波动更易放大的问题。'
    },
    @{
        Prefix = '优化方案已经建立起基本的力觉探测与闭环恢复框架'
        New = '优化方案已经建立了基本的踩空识别和二次跨越能力，但恢复顺序、姿态约束和方向抑制还不够。当前方案在此基础上加入了“先直接前跨、失败后再退回”的恢复顺序、单腿脱困、原位锁定、左右步幅差分纠偏和分级重心前移等策略，使波浪步态跨沟过程进一步收敛。'
    },
    @{
        Prefix = '从图7可以看出，传统方案在前向位移曲线上较早出现推进停滞'
        New = '从图7可以看出，传统方案在前向位移曲线上较早出现推进停滞，说明机器人到达坑边后难以继续完成有效跨越。优化方案能够继续推进，但横向位移和航向角在中后段持续累积，说明闭环恢复虽然已经起作用，但偏航和横摆仍然明显。相比之下，当前方案的前向推进更连续，横向偏移和姿态曲线也更收敛，说明恢复顺序调整、原位锁定和步幅差分纠偏对姿态发散有明显抑制作用。'
    },
    @{
        Prefix = '从通过性指标来看，传统方案和优化方案的成功标志均为 0'
        New = '从通过性指标来看，传统方案和优化方案的成功标志均为 0，当前方案提高到 1，说明当前方案已经能够稳定跨沟。这里的“通过距离”仍按机身沿 X 轴的首末位移差计算，“直线净位移”则表示起点到终点的空间直线距离，容易受到横向漂移和无效折返的影响，因此只作为辅助指标。按此口径，传统方案的通过距离由 0.287 m 提高到 5.282 m，直线净位移由 2.615 m 提高到 6.080 m，路径效率由 0.190 提高到 0.520。优化方案的通过距离虽然已提升到 1.325 m，但仍存在恢复链条偏保守、无效折返较多的问题。当前方案在路径效率和直线净位移上的进一步改善，说明恢复顺序重构和单腿脱困策略确实减少了坑边反复试探。'
    },
    @{
        Prefix = '从稳定性指标来看，当前方案相对优化方案的总受力均方根由 1279653 N 下降到 267597 N'
        New = '从稳定性指标来看，当前方案相对优化方案的总受力均方根由 1279653 N 降到 267597 N，下降 79.1%；阶段俯仰峰值由 21.335° 降到 13.261°，下降 37.8%；阶段横滚峰值由 11.924° 降到 3.228°，下降 72.9%；航向漂移由 45.889° 降到 14.223°，下降 69.0%；最大横向漂移由 0.960 m 降到 0.839 m，下降 12.5%。这里更合理的比较对象是优化方案与当前方案，因为两者都属于波浪步态半闭环框架。当前方案的改进，主要就是针对优化方案中偏航累积和姿态不稳的问题展开的。'
    },
    @{
        Prefix = '综合来看，深沟场景下的优化重点并不在于单纯增大步长或提高探测深度'
        New = '总体来看，深沟场景下的关键不在于单纯增大步长或提高探测深度，而在于把步态选择、探测恢复、脱困补救、重心调节和姿态纠偏这条控制链路收紧。当前结果说明，只有把恢复顺序、单腿脱困、重心补偿和偏航抑制配合起来，波浪步态才可能在深沟场景下同时兼顾通过能力和稳定性。'
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

function Get-MatchProbe {
    param(
        [string]$Text
    )

    if (-not $Text) {
        return ''
    }

    $stopIndex = -1
    foreach ($delimiter in @('。', '；', '：')) {
        $currentIndex = $Text.IndexOf($delimiter)
        if ($currentIndex -ge 0 -and ($stopIndex -lt 0 -or $currentIndex -lt $stopIndex)) {
            $stopIndex = $currentIndex
        }
    }

    if ($stopIndex -ge 0) {
        return $Text.Substring(0, $stopIndex + 1)
    }

    $length = [Math]::Min(28, $Text.Length)
    $Text.Substring(0, $length)
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

function New-ParagraphNode {
    param(
        [System.Xml.XmlDocument]$Xml,
        [string]$Text
    )

    $paragraph = $Xml.CreateElement('w', 'p', $wNs)
    $run = $Xml.CreateElement('w', 'r', $wNs)
    $textNode = $Xml.CreateElement('w', 't', $wNs)
    $textNode.InnerText = $Text
    [void]$run.AppendChild($textNode)
    [void]$paragraph.AppendChild($run)
    $paragraph
}

function Get-NextParagraph {
    param(
        [System.Xml.XmlNode]$Paragraph
    )

    $next = $Paragraph.NextSibling
    while ($next -and $next.LocalName -ne 'p') {
        $next = $next.NextSibling
    }

    [System.Xml.XmlElement]$next
}

function Ensure-ParagraphAfter {
    param(
        [System.Xml.XmlElement]$Paragraph,
        [System.Xml.XmlNamespaceManager]$Ns,
        [System.Xml.XmlDocument]$Xml,
        [string]$Text
    )

    $nextParagraph = Get-NextParagraph -Paragraph $Paragraph
    if ($nextParagraph -and (Get-ParagraphText -Paragraph $nextParagraph -Ns $Ns) -eq $Text) {
        return $nextParagraph
    }

    $newParagraph = New-ParagraphNode -Xml $Xml -Text $Text
    [void]$Paragraph.ParentNode.InsertAfter($newParagraph, $Paragraph)
    [System.Xml.XmlElement]$newParagraph
}

$resolvedDocx = (Resolve-Path $DocxPath).Path
$zip = [System.IO.Compression.ZipFile]::Open($resolvedDocx, [System.IO.Compression.ZipArchiveMode]::Update)

try {
    [xml]$documentXml = Read-EntryText -Zip $zip -EntryName 'word/document.xml'

    $ns = New-Object System.Xml.XmlNamespaceManager($documentXml.NameTable)
    $ns.AddNamespace('w', $wNs)

    $paragraphs = $documentXml.SelectNodes('//w:p', $ns)
    $slopeParagraph = $null

    foreach ($replacement in $replacements) {
        $matched = $null
        $prefixProbe = Get-MatchProbe -Text $replacement.Prefix
        $newProbe = Get-MatchProbe -Text $replacement.New
        foreach ($paragraph in $paragraphs) {
            $text = Get-ParagraphText -Paragraph $paragraph -Ns $ns
            if (
                $text.StartsWith($replacement.Prefix, [System.StringComparison]::Ordinal) -or
                $text.StartsWith($replacement.New, [System.StringComparison]::Ordinal) -or
                ($prefixProbe -and $text.StartsWith($prefixProbe, [System.StringComparison]::Ordinal)) -or
                ($newProbe -and $text.StartsWith($newProbe, [System.StringComparison]::Ordinal))
            ) {
                $matched = [System.Xml.XmlElement]$paragraph
                break
            }
        }

        if (-not $matched) {
            throw "Paragraph prefix not found: $($replacement.Prefix)"
        }

        Replace-ParagraphText -Paragraph $matched -Ns $ns -Xml $documentXml -Text $replacement.New

        if ($replacement.New.StartsWith($slopeIntroPrefix, [System.StringComparison]::Ordinal)) {
            $slopeParagraph = $matched
        }
    }

    if (-not $slopeParagraph) {
        throw 'Slope introduction paragraph not found after replacement.'
    }

    $formulaParagraph = Ensure-ParagraphAfter -Paragraph $slopeParagraph -Ns $ns -Xml $documentXml -Text $slopeFormulaText
    [void](Ensure-ParagraphAfter -Paragraph $formulaParagraph -Ns $ns -Xml $documentXml -Text $slopeFormulaExplainText)

    Save-XmlToZip -Zip $zip -EntryName 'word/document.xml' -Xml $documentXml
}
finally {
    $zip.Dispose()
}

Write-Output 'Rewrote section I tone successfully.'
