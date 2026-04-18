using DocxMidtermInsert;

if (args.Length is < 1 or > 2)
{
    Console.Error.WriteLine("Usage: DocxMidtermInsert <docx-path> [repo-root]");
    return 1;
}

var docxPath = Path.GetFullPath(args[0]);
var repoRoot = args.Length == 2
    ? Path.GetFullPath(args[1])
    : Path.GetFullPath(Path.Combine(
        AppContext.BaseDirectory,
        "..",
        "..",
        "..",
        ".."));

MidtermDocxEditor.Update(docxPath, repoRoot);
Console.WriteLine("Updated midterm report successfully.");
return 0;
