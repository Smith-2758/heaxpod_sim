using System.Buffers.Binary;
using DocumentFormat.OpenXml;
using DocumentFormat.OpenXml.Packaging;
using DocumentFormat.OpenXml.Wordprocessing;
using A = DocumentFormat.OpenXml.Drawing;
using PIC = DocumentFormat.OpenXml.Drawing.Pictures;
using WP = DocumentFormat.OpenXml.Drawing.Wordprocessing;

namespace DocxMidtermInsert;

public static class MidtermDocxEditor
{
    private const long ImageWidthEmu = 5233973L;

    private const string MainHeading11 = "1.1 主要研究内容";
    private const string MainHeading12 = "1.2 进展情况及取得成果";
    private const string OldSlopeHeading = "1.2.1 15°斜坡场景下的轨迹规划优化与结果分析";
    private const string NewSlopeHeading = "1.2.2 15°斜坡场景下的轨迹规划优化与结果分析";
    private const string OldStepHeading = "1.2.2 0.5 m高台场景结果分析";
    private const string NewStepHeading = "1.2.3 0.5 m高台场景结果分析";
    private const string OldDitchHeading = "1.2.3 深沟场景下的半闭环跨越优化与结果分析";
    private const string NewDitchHeading = "1.2.4 深沟场景下的半闭环跨越优化与结果分析";

    private static readonly string AddedParagraphIn11 =
        "除三类典型复杂地形场景的对比分析外，现阶段还围绕六足机器人建模和步态规划方法做了基础梳理。结合机体姿态、足端落点和关节运动之间的关系，以及不同地形对支撑方式和动作连续性的要求，逐步形成了面向斜坡、高台和深沟场景的轨迹规划与稳定控制分析框架，也为后续进一步开展 ZMP 稳定控制、轻落地和质心平滑稳定控制研究打下了基础。";

    private static readonly string[] AddedSection121 =
    {
        "（1）六足机器人建模。本文研究对象为重型六足机器人，整机由机体和六条腿组成，每条腿包含 3 个主要关节，全系统共有 18 个关节。建模时重点关注机体姿态、足端位置和关节角之间的运动学关系，并通过逆运动学将足端轨迹转换为各关节的运动过程。在复杂地形下，足端落点、机体姿态和关节可达范围之间耦合明显，因此关节限位不仅影响动作能否完成，也会直接影响爬坡、越台和跨坑时的稳定性与通过性。",
        "（2）步态规划方法。斜坡和高台场景采用三角步态。该步态将六条腿划分为两组交替摆动和支撑，在规则障碍条件下推进效率较高，便于围绕坡面贴合和机体抬升来规划足端轨迹。深沟跨越场景采用波浪步态，即单腿依次摆动、其余多腿持续支撑的推进方式。与三角步态相比，波浪步态在支撑连续性和单腿独立控制方面更有优势，因此更适合深沟场景中的足端探测、踩空识别和恢复动作设计。"
    };

    private static readonly FigureInsertSpec GaitFigure = new(
        IntroText: "图2给出了六足机器人在三角步态和波浪步态下的时序对比关系。",
        Caption: "图2 六足机器人波浪步态与三角步态时序对比图",
        ImagePath: Path.Combine("docs", "paper", "generated_assets", "六足机器人波浪步态与三角步态时序对比图.png"));

    private static readonly SceneSpec[] Scenes =
    {
        new(
            SectionHeading: NewSlopeHeading,
            ExistingFirstCaption: "图6 斜坡场景机身轨迹与俯仰角变化对比图",
            ProcessIntro: "以下为当前方案在斜坡场景中的仿真过程截图，按时间顺序展示机器人由平地接近坡面到稳定爬坡的过程。",
            ProcessCaption: "图3 当前方案在斜坡场景中的连续运动过程截图",
            ProcessDetail: "（a）接近坡面；（b）前腿触坡并开始抬升；（c）机体进入坡面；（d）稳定爬坡",
            ProcessImagePath: Path.Combine("docs", "paper", "generated_assets", "figure_extra_slope_process_collage.png"),
            FootIntro: "图4为斜坡场景下的足端过程曲线。",
            FootCaption: "图4 斜坡场景足端过程曲线图",
            FootImagePath: Path.Combine("log", "slope", "compare_user_slope_repeat3_20260331", "midterm_assets_extra", "figure_extra_slope_footend_curve.png"),
            ForceIntro: "图5为斜坡场景下的总受力全过程曲线。",
            ForceCaption: "图5 斜坡场景总受力全过程曲线图",
            ForceImagePath: Path.Combine("log", "slope", "compare_user_slope_repeat3_20260331", "midterm_assets_extra", "figure_extra_slope_total_force_curve.png")),
        new(
            SectionHeading: NewStepHeading,
            ExistingFirstCaption: "图12 高台场景下传统方案与当前方案的质心轨迹对比图",
            ProcessIntro: "以下为当前方案在高台场景中的仿真过程截图，展示机器人接近台阶、前腿上台和后腿跟进的过程。",
            ProcessCaption: "图9 当前方案在高台场景中的连续运动过程截图",
            ProcessDetail: "（a）接近台阶前沿；（b）前腿上台并开始抬升机身；（c）机体跨越台阶边缘；（d）后腿跟进并稳定上台",
            ProcessImagePath: Path.Combine("docs", "paper", "generated_assets", "figure_extra_step_process_collage.png"),
            FootIntro: "图10给出了高台场景下的足端过程曲线。",
            FootCaption: "图10 高台场景足端过程曲线图",
            FootImagePath: Path.Combine("log", "step", "compare_user_step_repeat3_20260401_fixbaseline", "midterm_assets_extra", "figure_extra_step_footend_curve.png"),
            ForceIntro: "图11为高台场景下的总受力全过程曲线。",
            ForceCaption: "图11 高台场景总受力全过程曲线图",
            ForceImagePath: Path.Combine("log", "step", "compare_user_step_repeat3_20260401_fixbaseline", "midterm_assets_extra", "figure_extra_step_total_force_curve.png")),
        new(
            SectionHeading: NewDitchHeading,
            ExistingFirstCaption: "图17 深沟场景三阶段过程收敛对比图",
            ProcessIntro: "以下为当前方案在深沟场景中的仿真过程截图，展示机器人接近坑边、足端探测和完成跨越后的推进过程。",
            ProcessCaption: "图14 当前方案在深沟场景中的连续运动过程截图",
            ProcessDetail: "（a）接近坑边并准备探测；（b）足端下探或触发探测；（c）关键跨越或恢复阶段；（d）完成跨越后的稳定推进",
            ProcessImagePath: Path.Combine("docs", "paper", "generated_assets", "figure_extra_ditch_process_collage.png"),
            FootIntro: "图15为深沟场景下的足端过程曲线。",
            FootCaption: "图15 深沟场景足端过程曲线图",
            FootImagePath: Path.Combine("log", "ditch", "compare_user_ditch_repeat3_20260331", "midterm_assets_extra", "figure_extra_ditch_footend_curve.png"),
            ForceIntro: "图16给出了深沟场景下的总受力全过程曲线。",
            ForceCaption: "图16 深沟场景总受力全过程曲线图",
            ForceImagePath: Path.Combine("log", "ditch", "compare_user_ditch_repeat3_20260331", "midterm_assets_extra", "figure_extra_ditch_total_force_curve.png"))
    };

    private static readonly (string OldText, string NewText)[] ExactParagraphReplacements =
    {
        (OldSlopeHeading, NewSlopeHeading),
        (OldStepHeading, NewStepHeading),
        (OldDitchHeading, NewDitchHeading),
        ("图2 斜坡场景机身轨迹与俯仰角变化对比图", "图6 斜坡场景机身轨迹与俯仰角变化对比图"),
        ("图3 斜坡场景通过性指标对比图", "图7 斜坡场景通过性指标对比图"),
        ("图4 斜坡场景稳定性指标对比图", "图8 斜坡场景稳定性指标对比图"),
        ("图5 高台场景下传统方案与当前方案的质心轨迹对比图", "图12 高台场景下传统方案与当前方案的质心轨迹对比图"),
        ("图6 高台场景下传统方案与当前方案关键指标对比图", "图13 高台场景下传统方案与当前方案关键指标对比图"),
        ("图7 深沟场景三阶段过程收敛对比图", "图17 深沟场景三阶段过程收敛对比图"),
        ("图8 深沟场景通过性指标对比图", "图18 深沟场景通过性指标对比图"),
        ("图9 深沟场景稳定性指标对比图", "图19 深沟场景稳定性指标对比图")
    };

    private static readonly (string OldValue, string NewValue)[] InlineReplacements =
    {
        ("从图2可以看出", "从图6可以看出"),
        ("从图5可以看出", "从图12可以看出"),
        ("如图6所示", "如图13所示"),
        ("从图7可以看出", "从图17可以看出")
    };

    public static void Update(string docxPath, string repoRoot)
    {
        if (!File.Exists(docxPath))
        {
            throw new FileNotFoundException("DOCX file not found.", docxPath);
        }

        if (!Directory.Exists(repoRoot))
        {
            throw new DirectoryNotFoundException("Repository root not found: " + repoRoot);
        }

        using var document = WordprocessingDocument.Open(docxPath, true);
        var mainPart = document.MainDocumentPart ?? throw new InvalidOperationException("Missing main document part.");
        var body = mainPart.Document?.Body ?? throw new InvalidOperationException("Missing document body.");
        var mainCell = GetMainContentCell(body);

        var paragraphs = mainCell.Elements<Paragraph>().ToList();
        var bodyTemplate = FindParagraphExact(paragraphs, "六足机器人在灾害救援、野外运输和复杂环境作业中有较强的应用需求，因此有必要研究其在复杂地面上的稳定行走方法。这一问题既有工程意义，也直接关系到后续轨迹规划和控制策略的设计。");
        var headingTemplate = FindParagraphExact(paragraphs, OldSlopeHeading);
        var captionTemplate = FindParagraphExact(paragraphs, "图1 毕业设计总体技术路线图");
        var imageTemplate = paragraphs.FirstOrDefault(p => p.Descendants<DocumentFormat.OpenXml.Wordprocessing.Drawing>().Any())
            ?? throw new InvalidOperationException("Image paragraph template not found.");

        InsertParagraphBeforeHeading(
            mainCell,
            FindParagraphExact(paragraphs, MainHeading12),
            CreateTextParagraphFromTemplate(bodyTemplate, AddedParagraphIn11));

        var docPropertyId = GetMaxDocPropertyId(mainPart) + 1U;
        var originalSlopeHeading = FindParagraphExact(mainCell.Elements<Paragraph>(), OldSlopeHeading);
        InsertSection121(mainCell, originalSlopeHeading, headingTemplate, bodyTemplate);
        InsertGaitFigure(mainCell, mainPart, repoRoot, originalSlopeHeading, bodyTemplate, captionTemplate, imageTemplate, ref docPropertyId);

        ApplyReplacements(mainCell.Elements<Paragraph>().ToList());

        foreach (var scene in Scenes)
        {
            InsertSceneAssets(mainCell, mainPart, repoRoot, scene, bodyTemplate, captionTemplate, imageTemplate, ref docPropertyId);
        }

        mainPart.Document!.Save();
    }

    private static TableCell GetMainContentCell(Body body)
    {
        var tables = body.Elements<Table>().ToList();
        if (tables.Count < 2)
        {
            throw new InvalidOperationException("Unexpected document structure: second table not found.");
        }

        return tables[1]
            .Elements<TableRow>()
            .First()
            .Elements<TableCell>()
            .First();
    }

    private static void InsertParagraphBeforeHeading(TableCell mainCell, Paragraph heading, Paragraph newParagraph)
    {
        mainCell.InsertBefore(newParagraph, heading);
    }

    private static void InsertSection121(TableCell mainCell, Paragraph slopeHeading, Paragraph headingTemplate, Paragraph bodyTemplate)
    {
        var newHeading = CreateTextParagraphFromTemplate(headingTemplate, "1.2.1 六足机器人建模与步态规划方法概述");
        mainCell.InsertBefore(newHeading, slopeHeading);

        foreach (var paragraphText in AddedSection121)
        {
            mainCell.InsertBefore(CreateTextParagraphFromTemplate(bodyTemplate, paragraphText), slopeHeading);
        }
    }

    private static void InsertGaitFigure(
        TableCell mainCell,
        MainDocumentPart mainPart,
        string repoRoot,
        Paragraph slopeHeading,
        Paragraph bodyTemplate,
        Paragraph captionTemplate,
        Paragraph imageTemplate,
        ref uint docPropertyId)
    {
        var gaitImagePath = ResolvePath(repoRoot, GaitFigure.ImagePath);
        var elements = new List<OpenXmlElement>
        {
            CreateTextParagraphFromTemplate(bodyTemplate, GaitFigure.IntroText),
            CreateImageParagraphFromTemplate(
                imageTemplate,
                BuildDrawingElement(mainPart, gaitImagePath, ref docPropertyId, GaitFigure.Caption)),
            CreateTextParagraphFromTemplate(captionTemplate, GaitFigure.Caption)
        };

        foreach (var element in elements)
        {
            mainCell.InsertBefore(element, slopeHeading);
        }
    }

    private static void ApplyReplacements(IReadOnlyList<Paragraph> paragraphs)
    {
        foreach (var paragraph in paragraphs)
        {
            var text = NormalizeText(paragraph);
            if (string.IsNullOrEmpty(text))
            {
                continue;
            }

            var exactReplacement = ExactParagraphReplacements.FirstOrDefault(item => item.OldText == text);
            if (exactReplacement != default)
            {
                ReplaceParagraphText(paragraph, exactReplacement.NewText);
                continue;
            }

            var replaced = false;
            foreach (var (oldValue, newValue) in InlineReplacements)
            {
                if (text.Contains(oldValue, StringComparison.Ordinal))
                {
                    text = text.Replace(oldValue, newValue, StringComparison.Ordinal);
                    replaced = true;
                    break;
                }
            }

            if (replaced && text != NormalizeText(paragraph))
            {
                ReplaceParagraphText(paragraph, text);
            }
        }
    }

    private static void InsertSceneAssets(
        TableCell mainCell,
        MainDocumentPart mainPart,
        string repoRoot,
        SceneSpec scene,
        Paragraph bodyTemplate,
        Paragraph captionTemplate,
        Paragraph imageTemplate,
        ref uint docPropertyId)
    {
        var paragraphs = mainCell.Elements<Paragraph>().ToList();
        var sectionHeading = FindParagraphExact(paragraphs, scene.SectionHeading);
        var firstCaption = FindParagraphExact(paragraphs, scene.ExistingFirstCaption);
        var anchor = firstCaption.PreviousSibling<Paragraph>() ?? firstCaption;

        var processImagePath = ResolvePath(repoRoot, scene.ProcessImagePath);
        var footImagePath = ResolvePath(repoRoot, scene.FootImagePath);
        var forceImagePath = ResolvePath(repoRoot, scene.ForceImagePath);

        var elements = new List<OpenXmlElement>
        {
            CreateTextParagraphFromTemplate(bodyTemplate, scene.ProcessIntro),
            CreateImageParagraphFromTemplate(
                imageTemplate,
                BuildDrawingElement(mainPart, processImagePath, ref docPropertyId, scene.ProcessCaption)),
            CreateTextParagraphFromTemplate(captionTemplate, scene.ProcessCaption),
            CreateTextParagraphFromTemplate(captionTemplate, scene.ProcessDetail),
            CreateTextParagraphFromTemplate(bodyTemplate, scene.FootIntro),
            CreateImageParagraphFromTemplate(
                imageTemplate,
                BuildDrawingElement(mainPart, footImagePath, ref docPropertyId, scene.FootCaption)),
            CreateTextParagraphFromTemplate(captionTemplate, scene.FootCaption),
            CreateTextParagraphFromTemplate(bodyTemplate, scene.ForceIntro),
            CreateImageParagraphFromTemplate(
                imageTemplate,
                BuildDrawingElement(mainPart, forceImagePath, ref docPropertyId, scene.ForceCaption)),
            CreateTextParagraphFromTemplate(captionTemplate, scene.ForceCaption)
        };

        foreach (var element in elements)
        {
            mainCell.InsertBefore(element, anchor);
        }
    }

    private static string ResolvePath(string repoRoot, string relativePath)
    {
        var resolved = Path.GetFullPath(Path.Combine(repoRoot, relativePath));
        if (!File.Exists(resolved))
        {
            throw new FileNotFoundException("Image asset not found.", resolved);
        }

        return resolved;
    }

    private static Paragraph FindParagraphExact(IEnumerable<Paragraph> paragraphs, string text)
    {
        return paragraphs.FirstOrDefault(p => NormalizeText(p) == text)
            ?? throw new InvalidOperationException("Could not find paragraph: " + text);
    }

    private static string NormalizeText(Paragraph paragraph)
    {
        return paragraph.InnerText.Trim();
    }

    private static Paragraph CreateTextParagraphFromTemplate(Paragraph template, string text)
    {
        var paragraph = new Paragraph();
        if (template.ParagraphProperties is not null)
        {
            paragraph.Append(template.ParagraphProperties.CloneNode(true));
        }

        var run = new Run();
        var templateRun = template.Elements<Run>().FirstOrDefault(r => r.GetFirstChild<Text>() is not null)
            ?? template.Descendants<Run>().FirstOrDefault(r => r.GetFirstChild<Text>() is not null);
        if (templateRun?.RunProperties is not null)
        {
            run.Append(templateRun.RunProperties.CloneNode(true));
        }

        run.Append(CreateText(text));
        paragraph.Append(run);
        return paragraph;
    }

    private static Paragraph CreateImageParagraphFromTemplate(
        Paragraph template,
        DocumentFormat.OpenXml.Wordprocessing.Drawing drawing)
    {
        var paragraph = new Paragraph();
        if (template.ParagraphProperties is not null)
        {
            paragraph.Append(template.ParagraphProperties.CloneNode(true));
        }

        paragraph.Append(new Run(drawing));
        return paragraph;
    }

    private static void ReplaceParagraphText(Paragraph paragraph, string text)
    {
        var template = (Paragraph)paragraph.CloneNode(true);
        paragraph.RemoveAllChildren();
        if (template.ParagraphProperties is not null)
        {
            paragraph.Append(template.ParagraphProperties.CloneNode(true));
        }

        var run = new Run();
        var templateRun = template.Elements<Run>().FirstOrDefault(r => r.GetFirstChild<Text>() is not null)
            ?? template.Descendants<Run>().FirstOrDefault(r => r.GetFirstChild<Text>() is not null);
        if (templateRun?.RunProperties is not null)
        {
            run.Append(templateRun.RunProperties.CloneNode(true));
        }

        run.Append(CreateText(text));
        paragraph.Append(run);
    }

    private static Text CreateText(string text)
    {
        return new Text(text)
        {
            Space = text.StartsWith(' ') || text.EndsWith(' ')
                ? SpaceProcessingModeValues.Preserve
                : null
        };
    }

    private static uint GetMaxDocPropertyId(MainDocumentPart mainPart)
    {
        return mainPart.Document!.Descendants<WP.DocProperties>()
            .Select(props => props.Id?.Value ?? 0U)
            .DefaultIfEmpty(0U)
            .Max();
    }

    private static DocumentFormat.OpenXml.Wordprocessing.Drawing BuildDrawingElement(
        MainDocumentPart mainPart,
        string imagePath,
        ref uint docPropertyId,
        string description)
    {
        var imageSize = ReadPngSize(imagePath);
        var imageHeightEmu = (long)Math.Round(ImageWidthEmu * (double)imageSize.Height / imageSize.Width);

        var imagePart = mainPart.AddImagePart(ImagePartType.Png);
        using (var stream = File.OpenRead(imagePath))
        {
            imagePart.FeedData(stream);
        }

        var relId = mainPart.GetIdOfPart(imagePart);
        var fileName = Path.GetFileName(imagePath);

        var picture = new PIC.Picture(
            new PIC.NonVisualPictureProperties(
                new PIC.NonVisualDrawingProperties
                {
                    Id = 0U,
                    Name = fileName
                },
                new PIC.NonVisualPictureDrawingProperties()),
            new PIC.BlipFill(
                new A.Blip
                {
                    Embed = relId,
                    CompressionState = A.BlipCompressionValues.Print
                },
                new A.Stretch(new A.FillRectangle())),
            new PIC.ShapeProperties(
                new A.Transform2D(
                    new A.Offset { X = 0L, Y = 0L },
                    new A.Extents { Cx = ImageWidthEmu, Cy = imageHeightEmu }),
                new A.PresetGeometry(new A.AdjustValueList())
                {
                    Preset = A.ShapeTypeValues.Rectangle
                }));

        return new DocumentFormat.OpenXml.Wordprocessing.Drawing(
            new WP.Inline(
                new WP.Extent { Cx = ImageWidthEmu, Cy = imageHeightEmu },
                new WP.EffectExtent
                {
                    LeftEdge = 0L,
                    TopEdge = 0L,
                    RightEdge = 0L,
                    BottomEdge = 0L
                },
                new WP.DocProperties
                {
                    Id = docPropertyId++,
                    Name = fileName,
                    Description = description
                },
                new WP.NonVisualGraphicFrameDrawingProperties(
                    new A.GraphicFrameLocks { NoChangeAspect = true }),
                new A.Graphic(
                    new A.GraphicData(picture)
                    {
                        Uri = "http://schemas.openxmlformats.org/drawingml/2006/picture"
                    }))
            {
                DistanceFromTop = 0U,
                DistanceFromBottom = 0U,
                DistanceFromLeft = 0U,
                DistanceFromRight = 0U
            });
    }

    private static ImageSize ReadPngSize(string path)
    {
        using var stream = File.OpenRead(path);
        Span<byte> header = stackalloc byte[24];
        stream.ReadExactly(header);

        var signature = new byte[] { 137, 80, 78, 71, 13, 10, 26, 10 };
        if (!header[..8].SequenceEqual(signature))
        {
            throw new InvalidDataException("Unsupported PNG file: " + path);
        }

        var width = BinaryPrimitives.ReadInt32BigEndian(header.Slice(16, 4));
        var height = BinaryPrimitives.ReadInt32BigEndian(header.Slice(20, 4));
        return new ImageSize(width, height);
    }

    private sealed record SceneSpec(
        string SectionHeading,
        string ExistingFirstCaption,
        string ProcessIntro,
        string ProcessCaption,
        string ProcessDetail,
        string ProcessImagePath,
        string FootIntro,
        string FootCaption,
        string FootImagePath,
        string ForceIntro,
        string ForceCaption,
        string ForceImagePath);

    private sealed record FigureInsertSpec(
        string IntroText,
        string Caption,
        string ImagePath);

    private sealed record ImageSize(int Width, int Height);
}
