/-
Copyright (c) 2021 Henrik Böving. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
import Lean
import DocGen4.Process
import DocGen4.Output.Base
import DocGen4.Output.Index
import DocGen4.Output.Module
import DocGen4.Output.ModuleMarkdown
import DocGen4.Output.NotFound
import DocGen4.Output.Find
import DocGen4.Output.References
import DocGen4.Output.Bibtex
import DocGen4.Output.SourceLinker
import DocGen4.Output.Search
import DocGen4.Output.Tactics
import DocGen4.Output.ToJson
import DocGen4.Output.FoundationalTypes
import DocGen4.Output.Book

namespace DocGen4

open Lean IO System Output Process

def collectBackrefs (buildDir : System.FilePath) : IO (Array BackrefItem) := do
  let mut backrefs : Array BackrefItem := #[]
  for entry in ← System.FilePath.readDir (declarationsBasePath buildDir) do
    if entry.fileName.startsWith "backrefs-" && entry.fileName.endsWith ".json" then
      let fileContent ← FS.readFile entry.path
      match Json.parse fileContent with
      | .error err =>
        throw <| IO.userError s!"failed to parse file '{entry.path}' as json: {err}"
      | .ok jsonContent =>
        match fromJson? jsonContent with
        | .error err =>
          throw <| IO.userError s!"failed to parse file '{entry.path}': {err}"
        | .ok (arr : Array BackrefItem) => backrefs := backrefs ++ arr
  return backrefs

def htmlOutputSetup (config : SiteBaseContext) (staticDir : Option System.FilePath := none) : IO Unit := do
  let findBasePath (buildDir : System.FilePath) := basePath buildDir / "find"

  -- Base structure
  FS.createDirAll <| basePath config.buildDir
  FS.createDirAll <| findBasePath config.buildDir
  FS.createDirAll <| srcBasePath config.buildDir
  FS.createDirAll <| declarationsBasePath config.buildDir

  -- All the doc-gen static stuff
  let indexHtml := ReaderT.run index config |>.toString
  let notFoundHtml := ReaderT.run notFound config |>.toString
  let foundationalTypesHtml := ReaderT.run foundationalTypes config |>.toString
  let searchHtml := ReaderT.run search config |>.toString
  let referencesHtml := ReaderT.run (references (← collectBackrefs config.buildDir)) config |>.toString
  let tacticsHtml := ReaderT.run (tactics (← loadTacticsJSON config.buildDir)) config |>.toString
  let docGenStatic := #[
    ("style.css", styleCss),
    ("favicon.svg", faviconSvg),
    ("declaration-data.js", declarationDataCenterJs),
    ("color-scheme.js", colorSchemeJs),
    ("nav.js", navJs),
    ("module-view.js", moduleViewJs),
    ("jump-src.js", jumpSrcJs),
    ("shiki.js", shikiJs),
    ("how-about.js", howAboutJs),
    ("search.html", searchHtml),
    ("search.js", searchJs),
    ("shiki-runtime.js", shikiRuntimeJs),
    ("katex-config.js", katexConfigJs),
    ("instances.js", instancesJs),
    ("importedBy.js", importedByJs),
    ("index.html", indexHtml),
    ("foundational_types.html", foundationalTypesHtml),
    ("404.html", notFoundHtml),
    ("references.html", referencesHtml),
    ("tactics.html", tacticsHtml),
  ]
  for (fileName, content) in docGenStatic do
    let content := if fileName.endsWith ".html" then withDoctype content else content
    FS.writeFile (basePath config.buildDir / fileName) content

  -- Copy bundled font files into the output root.
  let fontFiles := #[
    "BerkeleyMonoVariable.woff2",
    "IBMPlexMono-Regular.woff2",
    "IBMPlexMono-Bold.woff2",
    "IBMPlexMono-Italic.woff2",
    "IBMPlexMono-BoldItalic.woff2"
  ]
  let staticPath := staticDir.getD "static"
  for fontFile in fontFiles do
    let srcFile : System.FilePath := staticPath / fontFile
    if ← srcFile.pathExists then
      let fontData ← FS.readBinFile srcFile
      FS.writeBinFile (basePath config.buildDir / fontFile) fontData

  let findHtml := ReaderT.run find { config with depthToRoot := 1 } |>.toString
  let findStatic := #[
    ("index.html", findHtml),
    ("find.js", findJs)
  ]
  for (fileName, content) in findStatic do
    let content := if fileName.endsWith ".html" then withDoctype content else content
    FS.writeFile (findBasePath config.buildDir / fileName) content

def htmlOutputDeclarationDatas (buildDir : System.FilePath) (result : AnalyzerResult) : HtmlT IO Unit := do
  for (_, mod) in result.moduleInfo.toArray do
    let jsonDecls ← Module.toJson mod
    FS.writeFile (declarationsBasePath buildDir / s!"declaration-data-{mod.name}.bmp") (toJson jsonDecls).compress

/-- Custom source linker type: given an optional source URL and module name, returns a function from declaration range to URL -/
abbrev SourceLinkerFn := Option String → Name → Option DeclarationRange → String

/--
Imports of the analyzed modules that will have a page in this documentation build
although they are not part of the current analysis. Lake's `docs` facet runs
doc-gen4 once per module, so the analysis only contains that module. Its imports
still get pages when they are
* modules of the core libraries documented by `coreDocs` (`Init`, `Std`, `Lake`, `Lean`), or
* workspace modules, i.e. not shipped with the toolchain: the `docs` facet builds the
  documentation of every imported workspace module before this one.
Other toolchain modules are not documented and are not linked.
-/
def linkableImports (result : AnalyzerResult) : IO (Std.HashSet Name) := do
  let coreRoots : List Name := [`Init, `Std, `Lake, `Lean]
  let sysroot ← try some <$> Lean.findSysroot catch _ => pure none
  let toolchainLib? := sysroot.map fun r => (r / "lib" / "lean").toString
  let mut linkable : Std.HashSet Name := {}
  for (_, module) in result.moduleInfo.toArray do
    for i in module.imports do
      if result.moduleInfo.contains i || linkable.contains i then
        continue
      if coreRoots.contains i.getRoot then
        linkable := linkable.insert i
      else
        let fromToolchain ←
          match toolchainLib? with
          | none => pure true
          | some lib =>
            try
              let olean ← Lean.findOLean i
              pure (olean.toString.startsWith lib)
            catch _ => pure true
        unless fromToolchain do
          linkable := linkable.insert i
  return linkable

def htmlOutputResults (baseConfig : SiteBaseContext) (result : AnalyzerResult) (sourceUrl? : Option String)
    (sourceLinker? : Option SourceLinkerFn := none)
    (declarationDecorator? : Option DeclarationDecoratorFn := none) : IO (Array System.FilePath) := do
  let config : SiteContext := {
    result := result
    sourceLinker := (sourceLinker?.getD SourceLinker.sourceLinker) sourceUrl?
    refsMap := .ofList (baseConfig.refs.map fun x => (x.citekey, x)).toList
    declarationDecorator := declarationDecorator?.getD defaultDeclarationDecorator
  }

  FS.createDirAll <| basePath baseConfig.buildDir
  FS.createDirAll <| declarationsBasePath baseConfig.buildDir

  discard <| htmlOutputDeclarationDatas baseConfig.buildDir result |>.run {} config baseConfig

  let baseConfig := { baseConfig with linkableModules := ← linkableImports result }
  let mut outputs := #[]
  for (modName, module) in result.moduleInfo.toArray do
    let relFilePath := basePathComponent / moduleNameToFile modName
    let filePath := baseConfig.buildDir / relFilePath
    -- path: 'basePath/module/components/till/last.html'
    -- The last component is the file name, so we drop it from the depth to root.
    let moduleConfig := { baseConfig with
      depthToRoot := modName.components.dropLast.length
      currentName := some modName
    }
    let (moduleHtml, cfg) := moduleToHtml module |>.run {} config moduleConfig
    let (moduleMarkdown, _) := moduleToMarkdown module |>.run {} config moduleConfig
    let (tactics, cfg) := module.tactics.mapM TacticInfo.docStringToHtml |>.run cfg config baseConfig
    if not cfg.errors.isEmpty then
      throw <| IO.userError s!"There are errors when generating '{filePath}': {cfg.errors}"
    if let .some d := filePath.parent then
      FS.createDirAll d
    FS.writeFile filePath (withDoctype moduleHtml.toString)

    let mdRelFilePath := basePathComponent / moduleNameToMarkdownFile modName
    let mdFilePath := baseConfig.buildDir / mdRelFilePath
    if let some d := mdFilePath.parent then
      FS.createDirAll d
    FS.writeFile mdFilePath moduleMarkdown

    FS.writeFile (declarationsBasePath baseConfig.buildDir / s!"backrefs-{module.name}.json") (toString (toJson cfg.backrefs))
    saveTacticsJSON (declarationsBasePath baseConfig.buildDir / s!"tactics-{module.name}.json") tactics
    -- The output paths need to be relative to the build directory, as they are stored in a build
    -- artifact.
    outputs := outputs.push relFilePath

  let summaryMarkdown := ReaderT.run summaryToMarkdown baseConfig
  FS.writeFile (basePath baseConfig.buildDir / "SUMMARY.md") summaryMarkdown

  return outputs

def getSimpleBaseContext (buildDir : System.FilePath) (hierarchy : Hierarchy) :
    IO SiteBaseContext := do
  let contents ← FS.readFile (declarationsBasePath buildDir / "references.json") <|> (pure "[]")
  let sourceLinksEnabled := (← IO.getEnv "DOCGEN_SRC") != some "none"
  match Json.parse contents with
  | .error err =>
    throw <| IO.userError s!"Failed to parse 'references.json': {err}"
  | .ok jsonContent =>
    match fromJson? jsonContent with
    | .error err =>
      throw <| IO.userError s!"Failed to parse 'references.json': {err}"
    | .ok (refs : Array BibItem) =>
      return {
        buildDir := buildDir
        depthToRoot := 0
        currentName := none
        hierarchy := hierarchy
        refs := refs
        sourceLinksEnabled := sourceLinksEnabled
      }

/-- Recursively collect all HTML files under a directory. -/
partial def collectHtmlFiles (dir : System.FilePath) : IO (Array System.FilePath) := do
  let mut files := #[]
  for entry in ← System.FilePath.readDir dir do
    if ← entry.path.isDir then
      files := files ++ (← collectHtmlFiles entry.path)
    else if entry.path.extension = some "html" then
      files := files.push entry.path
  return files

/-- Compute module name from relative path components like `["DocGen4", "Output", "Base.html"]`.
    Returns `none` for non-module pages (e.g. `index.html`, `404.html`). -/
def moduleNameOfRelPath (relComponents : List String) : Option Name :=
  match relComponents.getLast? with
  | none => none
  | some fileName =>
    match fileName.splitOn "." with
    | [baseName, "html"] =>
      if !baseName.isEmpty && baseName.front.isUpper then
        let modParts := relComponents.dropLast ++ [baseName]
        some (modParts.foldl (fun acc part => Name.mkStr acc part) Name.anonymous)
      else
        none
    | _ => none

/-- Fill in the deferred nav placeholder in all HTML files with the complete navigation. -/
def patchNavInAllFiles (config : SiteBaseContext) : IO Unit := do
  let docDir := basePath config.buildDir
  let docPrefix :=
    let s := docDir.toString
    if s.endsWith "/" then s else s ++ "/"
  let htmlFiles ← collectHtmlFiles docDir
  let startMarker := "<!-- NAV_START -->"
  let endMarker := "<!-- NAV_END -->"
  for filePath in htmlFiles do
    let content ← FS.readFile filePath
    let startParts := content.splitOn startMarker
    if startParts.length != 2 then continue
    let endParts := startParts[1]!.splitOn endMarker
    if endParts.length != 2 then continue
    -- Compute depth and currentName from relative path
    let relStr := (filePath.toString.drop docPrefix.length).toString |>.replace "\\" "/"
    let relComponents := relStr.splitOn "/"
    let depth := relComponents.length - 1
    let currentName := moduleNameOfRelPath relComponents
    -- Generate complete nav with correct context
    let navConfig := {
      config with
      depthToRoot := depth
      currentName := currentName
      currentPage := some relStr
    }
    let navHtml := ReaderT.run navContent navConfig |>.toString
    let patched := startParts[0]! ++ navHtml ++ endParts[1]!
    FS.writeFile filePath (withDoctype patched)

def htmlOutputIndex (baseConfig : SiteBaseContext) (staticDir : Option System.FilePath := none)
    (bookDir : Option System.FilePath := none) : IO Unit := do
  htmlOutputSetup baseConfig staticDir
  let baseConfig ← htmlOutputBook baseConfig bookDir
  patchNavInAllFiles baseConfig

  let mut modules : Array JsonModule := #[]
  for entry in ← System.FilePath.readDir (declarationsBasePath baseConfig.buildDir) do
    if entry.fileName.startsWith "declaration-data-" && entry.fileName.endsWith ".bmp" then
      let fileContent ← FS.readFile entry.path
      match Json.parse fileContent with
      | .error err =>
        throw <| IO.userError s!"failed to parse file '{entry.path}' as json: {err}"
      | .ok jsonContent =>
        match fromJson? jsonContent with
        | .error err =>
          throw <| IO.userError s!"failed to parse file '{entry.path}': {err}"
        | .ok (module : JsonModule) =>
          modules := modules.push module
  -- Modules documented in this build; `importedBy` only records these.
  let documented : Std.HashSet String := modules.foldl (fun s m => s.insert m.name) {}
  let mut index : JsonIndex := {}
  for module in modules do
    index := index.addModule module documented |>.run baseConfig

  let mut indexedDocs : List (String × JsonIndexedDocumentInfo) := []
  for doc in baseConfig.documents do
    indexedDocs := (doc.title, { title := doc.title, kind := doc.kind, docLink := doc.docLink, previewText := doc.previewText }) :: indexedDocs
  index := { index with documents := indexedDocs }

  let finalJson := toJson index
  -- The root JSON for find
  let declarationDir := basePath  baseConfig.buildDir / "declarations"
  FS.createDirAll declarationDir
  FS.writeFile (declarationDir / "declaration-data.bmp") finalJson.compress

def headerDataOutput (buildDir : System.FilePath) : IO Unit := do
  let mut headerIndex : JsonHeaderIndex := {}
  for entry in ← System.FilePath.readDir (declarationsBasePath buildDir) do
    if entry.fileName.startsWith "declaration-data-" && entry.fileName.endsWith ".bmp" then
      let fileContent ← FS.readFile entry.path
      let .ok jsonContent := Json.parse fileContent | unreachable!
      let .ok (module : JsonModule) := fromJson? jsonContent | unreachable!
      headerIndex := headerIndex.addModule module

  let finalHeaderJson := toJson headerIndex
  let declarationDir := basePath buildDir / "declarations"
  FS.createDirAll declarationDir
  FS.writeFile (declarationDir / "header-data.bmp") finalHeaderJson.compress

/--
The main entrypoint for outputting the documentation HTML based on an
`AnalyzerResult`.
-/
def htmlOutput (buildDir : System.FilePath) (result : AnalyzerResult) (hierarchy : Hierarchy)
    (sourceUrl? : Option String) (sourceLinker? : Option SourceLinkerFn := none)
    (declarationDecorator? : Option DeclarationDecoratorFn := none)
    (staticDir : Option System.FilePath := none)
    (bookDir : Option System.FilePath := none) : IO Unit := do
  let baseConfig ← getSimpleBaseContext buildDir hierarchy
  discard <| htmlOutputResults baseConfig result sourceUrl? sourceLinker? declarationDecorator?
  htmlOutputIndex baseConfig staticDir bookDir

end DocGen4
