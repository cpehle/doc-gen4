import Std.Data.HashSet
import DocGen4.Output.DocString
import DocGen4.Output.Template

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx
open Lean System

structure SummaryConfig where
  enabled : Bool := true
  label : String := "Book"
  output : String := "book"
  deriving Inhabited

structure SummaryEntry where
  title : String
  sourceRel : String
  href : String
  level : Nat
  deriving Inhabited

structure ParsedSummary where
  config : SummaryConfig
  entries : Array SummaryEntry
  deriving Inhabited

private def trimAscii (s : String) : String :=
  let trimmedLeft := (s.dropWhile Char.isWhitespace).copy
  (trimmedLeft.dropEndWhile Char.isWhitespace).copy

private def stripLeadingDotSlash (s : String) : String :=
  if s.startsWith "./" then (s.drop 2).copy else s

private def stripWrappingQuotes (s : String) : String :=
  let v := trimAscii s
  if (v.startsWith "\"" && v.endsWith "\"") || (v.startsWith "'" && v.endsWith "'") then
    ((v.drop 1).dropEnd 1).copy
  else
    v

private def parseBool? (s : String) : Option Bool :=
  let v := stripWrappingQuotes s
  if v = "true" || v = "True" || v = "TRUE" || v = "yes" || v = "1" then
    some true
  else if v = "false" || v = "False" || v = "FALSE" || v = "no" || v = "0" then
    some false
  else
    none

private def normalizeOutputPrefix? (s : String) : Option String :=
  let raw := (stripWrappingQuotes s).replace "\\" "/"
  let raw := (raw.dropEndWhile (· = '/')).copy
  let raw := stripLeadingDotSlash raw
  if raw.isEmpty || raw.startsWith "/" then
    none
  else
    let parts := (raw.splitOn "/").filter (fun p => !p.isEmpty)
    if parts.isEmpty || parts.any (fun p => p == "..") then
      none
    else
      some ("/".intercalate parts)

private def parseKeyValue? (line : String) : Option (String × String) :=
  match line.splitOn ":" with
  | [] => none
  | [_] => none
  | key :: valueTail =>
    let key := trimAscii key
    let value := trimAscii (":".intercalate valueTail)
    if key.isEmpty then none else some (key, value)

private def splitLinkSuffix (href : String) : String × String :=
  let hashParts := href.splitOn "#"
  let beforeHash := hashParts.head!
  let hashSuffix :=
    match hashParts.tail with
    | [] => ""
    | hs => "#" ++ "#".intercalate hs
  let queryParts := beforeHash.splitOn "?"
  let pathPart := queryParts.head!
  let querySuffix :=
    match queryParts.tail with
    | [] => ""
    | qs => "?" ++ "?".intercalate qs
  (pathPart, querySuffix ++ hashSuffix)

private def splitFrontMatter (lines : List String) : Array String × List String :=
  match lines with
  | [] => (#[], [])
  | first :: rest =>
    if trimAscii first != "---" then
      (#[], lines)
    else
      let rec go (acc : Array String) (remaining : List String) : Option (Array String × List String) :=
        match remaining with
        | [] => none
        | line :: tail =>
          if trimAscii line = "---" then
            some (acc, tail)
          else
            go (acc.push line) tail
      match go #[] rest with
      | some result => result
      | none => (#[], lines)

private def parseFrontMatterConfig (summaryFile : System.FilePath) (metaLines : Array String) :
    IO SummaryConfig := do
  let mut cfg : SummaryConfig := {}
  let mut inDocgenBlock := false
  for line in metaLines do
    let trimmed := trimAscii line
    let isIndented := line.startsWith " " || line.startsWith "\t"
    if trimmed.isEmpty || trimmed.startsWith "#" then
      continue
    if trimmed == "docgen:" then
      inDocgenBlock := true
      continue

    let keyValue? :=
      if trimmed.startsWith "docgen." then
        match parseKeyValue? trimmed with
        | some (key, value) => some ((key.drop "docgen.".length).copy, value)
        | none => none
      else if inDocgenBlock && isIndented then
        parseKeyValue? trimmed
      else
        none

    if !trimmed.startsWith "docgen." && !(inDocgenBlock && isIndented) then
      inDocgenBlock := false

    match keyValue? with
    | none => pure ()
    | some (key, valueRaw) =>
      let value := stripWrappingQuotes valueRaw
      match key with
      | "enabled" =>
        match parseBool? value with
        | some enabled =>
          cfg := { cfg with enabled := enabled }
        | none =>
          throw <| IO.userError
            s!"Invalid value '{valueRaw}' for docgen.enabled in '{summaryFile}'. Expected true/false."
      | "label" =>
        if !value.isEmpty then
          cfg := { cfg with label := value }
      | "output" =>
        match normalizeOutputPrefix? value with
        | some output =>
          cfg := { cfg with output := output }
        | none =>
          throw <| IO.userError
            s!"Invalid value '{valueRaw}' for docgen.output in '{summaryFile}'. Use a relative path like 'guides'."
      | _ => pure ()
  return cfg

private def parseSummaryLine? (outputPrefix : String) (line : String) : Option SummaryEntry :=
  let indent := line.takeWhile (fun c => c = ' ' || c = '\t')
  let level := indent.positions.count / 2
  let trimmed := (line.dropWhile (fun c => c = ' ' || c = '\t')).copy
  let payload :=
    if trimmed.startsWith "- " then
      (trimmed.drop 2).copy
    else if trimmed.startsWith "* " then
      (trimmed.drop 2).copy
    else if trimmed.startsWith "+ " then
      (trimmed.drop 2).copy
    else
      ""
  if payload.isEmpty || !payload.startsWith "[" then
    none
  else
    let rest := (payload.drop 1).copy
    match rest.splitOn "](" with
    | [] => none
    | title :: tail =>
      if tail.isEmpty then
        none
      else
        let linkTail := "](".intercalate tail
        let title := trimAscii title
        let rawHref := trimAscii ((linkTail.takeWhile (· != ')')).copy)
        if !linkTail.contains ')' || title.isEmpty || rawHref.isEmpty then
          none
        else if rawHref.startsWith "#" || rawHref.startsWith "http://" || rawHref.startsWith "https://" then
          none
        else
          let (rawPath, _suffix) := splitLinkSuffix rawHref
          if !rawPath.endsWith ".md" then
            none
          else
            let normalized := stripLeadingDotSlash (rawPath.replace "\\" "/")
            if normalized.isEmpty || normalized.startsWith "/" then
              none
            else if (normalized.splitOn "/").any (· == "..") then
              none
            else
              let htmlRel := (normalized.dropEnd 3).copy ++ ".html"
              some {
                title := title
                sourceRel := normalized
                href := s!"{outputPrefix}/{htmlRel}"
                level := level
              }

private def parseSummary (summaryFile : System.FilePath) : IO ParsedSummary := do
  let content ← IO.FS.readFile summaryFile
  let lines := content.splitOn "\n"
  let (metaLines, bodyLines) := splitFrontMatter lines
  let config ← parseFrontMatterConfig summaryFile metaLines
  let mut entries : Array SummaryEntry := #[]
  for line in bodyLines do
    if let some entry := parseSummaryLine? config.output line then
      entries := entries.push entry
  return {
    config := config
    entries := entries
  }

private def dedupSummaryEntries (entries : Array SummaryEntry) : Array SummaryEntry := Id.run do
  let mut seen : Std.HashSet String := .emptyWithCapacity entries.size
  let mut deduped : Array SummaryEntry := #[]
  for entry in entries do
    if seen.contains entry.sourceRel then
      continue
    seen := seen.insert entry.sourceRel
    deduped := deduped.push entry
  return deduped

private def chapterPage (chapter : SummaryEntry) (markdown : String)
    (prev? next? : Option SummaryEntry) : HtmlM Html := do
  let rendered ← docStringToHtml markdown chapter.title
  let mut chapterNav : Array Html := #[]
  if let some prev := prev? then
    chapterNav := chapterNav.push <a class="book-prev blue no-underline hover-underline mr-auto" href={s!"{← getRoot}{prev.href}"}>{s!"← {prev.title}"}</a>
  if let some next := next? then
    chapterNav := chapterNav.push <a class="book-next blue no-underline hover-underline ml-auto" href={s!"{← getRoot}{next.href}"}>{s!"{next.title} →"}</a>
  
  -- Escape the markdown string for safe embedding in a JS string literal
  -- We use HTML entities to avoid breaking the script tag
  let escapedMarkdown := ((markdown.replace "\\" "\\\\").replace "`" "\\`").replace "$" "\\$"
  
  templateLiftExtends (baseHtmlGenerator chapter.title) <| pure #[
    <main class="px-6 py-6 flex-auto relative min-w-0" style="max-width: var(--content-width);">
      <a id="top"></a>
      <div class="flex justify-between items-start mb-6">
        <h1 class="text-3xl font-bold m-0 text-[var(--text-color)]">{chapter.title}</h1>
        <button id="copy_markdown_btn" class="flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium text-[var(--muted-text-color)] bg-neutral-50 dark:bg-neutral-800 border border-neutral-200 dark:border-neutral-700 rounded-md hover:bg-neutral-100 dark:hover:bg-neutral-700 transition-colors focus:outline-none focus:ring-2 focus:ring-blue-500" title="Copy markdown content">
          {.raw "<svg class=\"w-4 h-4\" aria-hidden=\"true\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><rect x=\"9\" y=\"9\" width=\"13\" height=\"13\" rx=\"2\" ry=\"2\"></rect><path d=\"M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1\"></path></svg>"}
          <span>Copy markdown</span>
        </button>
      </div>
      <div class="lh-copy slate">[rendered]</div>
      [if chapterNav.isEmpty then #[] else #[<div class="book-nav-links flex mt5 pt3 bt b--light-slate">[chapterNav]</div>]]
      
      <script>
        {.raw (
        "document.getElementById('copy_markdown_btn')?.addEventListener('click', async function() {" ++
        "  const btn = this;" ++
        "  const originalText = btn.querySelector('span').innerText;" ++
        "  const originalHtml = btn.innerHTML;" ++
        "  try {" ++
        "    await navigator.clipboard.writeText(`" ++ escapedMarkdown ++ "`);" ++
        "    btn.innerHTML = '<svg class=\"w-4 h-4 text-green-500\" aria-hidden=\"true\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><polyline points=\"20 6 9 17 4 12\"></polyline></svg><span class=\"text-green-500\">Copied!</span>';" ++
        "    setTimeout(() => {" ++
        "      btn.innerHTML = originalHtml;" ++
        "    }, 2000);" ++
        "  } catch (err) {" ++
        "    console.error('Failed to copy: ', err);" ++
        "    btn.querySelector('span').innerText = 'Failed';" ++
        "    setTimeout(() => {" ++
        "      btn.querySelector('span').innerText = originalText;" ++
        "    }, 2000);" ++
        "  }" ++
        "});")}
      </script>
    </main>
  ]

/--
Render mdBook-style chapters from `<bookDir>/SUMMARY.md`, if present.

Supports optional front matter in `SUMMARY.md`:
```
---
docgen:
  enabled: true
  label: Guides
  output: guides
---
```
-/
def htmlOutputBook (baseConfig : SiteBaseContext) (bookDir? : Option System.FilePath := none) :
    IO SiteBaseContext := do
  let some bookDir := bookDir? | return baseConfig
  let summaryFile := bookDir / "SUMMARY.md"
  if !(← summaryFile.pathExists) then
    return baseConfig

  let parsed ← parseSummary summaryFile
  if !parsed.config.enabled then
    return baseConfig
  let chapters := dedupSummaryEntries parsed.entries
  if chapters.isEmpty then
    return baseConfig

  let siteConfig : SiteContext := {
    result := default
    sourceLinker := fun _ _ => ""
    refsMap := .ofList (baseConfig.refs.map (fun r => (r.citekey, r))).toList
  }

  let mut documents : Array DocumentData := #[]

  for i in [0:chapters.size] do
    let chapter := chapters[i]!
    let sourceFile := bookDir / chapter.sourceRel
    if !(← sourceFile.pathExists) then
      throw <| IO.userError s!"Book chapter '{chapter.sourceRel}' referenced in '{summaryFile}' does not exist."
    let markdown ← IO.FS.readFile sourceFile
    
    -- Extract a plain text preview
    let previewText := ((((markdown.replace "\n" " ").replace "#" "").trimAsciiStart.toString).take 200).toString ++ "..."
    documents := documents.push {
      title := chapter.title,
      kind := "guide",
      docLink := chapter.href,
      previewText := previewText
    }

    let outputRel := chapter.href
    let outputFile := basePath baseConfig.buildDir / outputRel
    if let some parent := outputFile.parent then
      IO.FS.createDirAll parent
    let depthToRoot := (outputRel.splitOn "/").length - 1
    let chapterConfig : SiteBaseContext := {
      baseConfig with
      depthToRoot := depthToRoot
      currentName := some "_Book".toName
      currentPage := some outputRel
      preserveRelativeLinks := true
    }
    let prevEntry := if i > 0 then some (chapters[i - 1]!) else none
    let nextEntry := if i + 1 = chapters.size then none else some (chapters[i + 1]!)
    let (html, state) := (chapterPage chapter markdown prevEntry nextEntry).run {} siteConfig chapterConfig
    if !state.errors.isEmpty then
      throw <| IO.userError s!"There are errors when generating '{outputFile}': {state.errors}"
    IO.FS.writeFile outputFile html.toString

  return {
    baseConfig with
    bookNav := chapters.map (fun chapter => {
      title := chapter.title
      href := chapter.href
      level := chapter.level
    })
    bookNavLabel := parsed.config.label
    documents := baseConfig.documents ++ documents
  }

end Output
end DocGen4
