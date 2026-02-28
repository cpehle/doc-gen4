import Lean
import DocGen4.Process
import DocGen4.Output.Base
import DocGen4.Output.Module
import Lean.Data.RBMap

namespace DocGen4.Output

open Lean Widget Elab

/-- Extract plain text from a `TaggedText`, stripping all tags. -/
partial def taggedTextToPlainText : TaggedText α → String
  | .text s => s
  | .tag _ t => taggedTextToPlainText t
  | .append ts => String.join (ts.toList.map taggedTextToPlainText)

/--
Walk a `CodeWithInfos` tree and produce an array of JSON segments for the search index.
Each segment is one of:
- A plain JSON string `"text"` for unlinked text
- A JSON array `["text", "DeclName"]` for text that links to a known declaration
- A JSON array `["text", null, true]` for unlinked implicit/instance arg text (rendered italic)
- A JSON array `["text", "DeclName", true]` for linked implicit/instance arg text (rendered italic)

This mirrors the logic of `infoFormatToHtmlAux` but produces structured data instead of HTML.
-/
private partial def codeWithInfosToSegments (i : CodeWithInfos) : HtmlM (Array Json) := do
  match i with
  | .text t => return #[Json.str t]
  | .append ts =>
    let mut result := #[]
    for t in ts do
      result := result ++ (← codeWithInfosToSegments t)
    return result
  | .tag a t =>
    match a.info.val.info with
    | Info.ofTermInfo ti =>
      let cleanExpr := ti.expr.consumeMData
      match cleanExpr with
      | .const name _ =>
        if (← getResult).name2ModIdx.contains name then
          let text := taggedTextToPlainText t
          return #[toJson #[Json.str text, Json.str name.toString]]
        else
          codeWithInfosToSegments t
      | _ => codeWithInfosToSegments t
    | _ => codeWithInfosToSegments t


structure JsonDeclarationInfo where
  name : String
  kind : String
  doc : String
  docLink : String
  sourceLink : String
  line : Nat
  deriving FromJson, ToJson

structure JsonDeclaration where
  info : JsonDeclarationInfo
  header : String
  typeSig : Json := Json.null
deriving FromJson, ToJson

structure JsonInstance where
  name : String
  className : String
  typeNames : Array String
  deriving FromJson, ToJson

structure JsonModule where
  name : String
  declarations : List JsonDeclaration
  instances : Array JsonInstance
  imports : Array String
  deriving FromJson, ToJson

structure JsonHeaderIndex where
  declarations : List (String × JsonDeclaration) := []

structure JsonIndexedDeclarationInfo where
  kind : String
  docLink : String
  typeSig : Json := Json.null
  deriving FromJson, ToJson

structure JsonIndexedModule where
  importedBy : Array String
  url : String
  deriving FromJson, ToJson

structure JsonIndexedDocumentInfo where
  title : String
  kind : String
  docLink : String
  previewText : String
  deriving FromJson, ToJson

structure JsonIndex where
  declarations : List (String × JsonIndexedDeclarationInfo) := []
  documents : List (String × JsonIndexedDocumentInfo) := []
  instances : Std.HashMap String (RBTree String Ord.compare) := ∅
  modules : Std.HashMap String JsonIndexedModule := ∅
  instancesFor : Std.HashMap String (RBTree String Ord.compare) := ∅

instance : ToJson JsonHeaderIndex where
  toJson idx := Json.mkObj <| idx.declarations.map (fun (k, v) => (k, toJson v))

instance : ToJson JsonIndex where
  toJson idx := Id.run do
    let jsonDecls := Json.mkObj <| idx.declarations.map (fun (k, v) => (k, toJson v))
    let jsonDocs := Json.mkObj <| idx.documents.map (fun (k, v) => (k, toJson v))
    let jsonInstances := Json.mkObj <| idx.instances.toList.map (fun (k, v) => (k, toJson v.toArray))
    let jsonModules := Json.mkObj <| idx.modules.toList.map (fun (k, v) => (k, toJson v))
    let jsonInstancesFor := Json.mkObj <| idx.instancesFor.toList.map (fun (k, v) => (k, toJson v.toArray))
    let finalJson := Json.mkObj [
      ("declarations", jsonDecls),
      ("documents", jsonDocs),
      ("instances", jsonInstances),
      ("modules", jsonModules),
      ("instancesFor", jsonInstancesFor)
    ]
    return finalJson

def JsonHeaderIndex.addModule (index : JsonHeaderIndex) (module : JsonModule) : JsonHeaderIndex :=
  let merge idx decl := { idx with declarations := (decl.info.name, decl) :: idx.declarations }
  module.declarations.foldl merge index

def JsonIndex.addModule (index : JsonIndex) (module : JsonModule) : BaseHtmlM JsonIndex := do
  let mut index := index
  let newDecls := module.declarations.map (fun d => (d.info.name, {
    kind := d.info.kind,
    docLink := d.info.docLink,
    typeSig := d.typeSig,
  }))
  index := { index with
    declarations := newDecls ++ index.declarations
  }

  -- TODO: In theory one could sort instances and imports by name and batch the writes
  for inst in module.instances do
    let mut insts := index.instances.getD inst.className {}
    insts := insts.insert inst.name
    index := { index with instances := index.instances.insert inst.className insts }
    for typeName in inst.typeNames do
      let mut instsFor := index.instancesFor.getD typeName {}
      instsFor := instsFor.insert inst.name
      index := { index with instancesFor := index.instancesFor.insert typeName instsFor }

  -- TODO: dedup
  if index.modules[module.name]?.isNone then
    let moduleLink ← moduleNameToLink (String.toName module.name)
    let indexedModule := { url := moduleLink, importedBy := #[] }
    index := { index with modules := index.modules.insert module.name indexedModule }

  for imp in module.imports do
    let indexedImp ←
      match index.modules[imp]? with
      | some i => pure i
      | none =>
        let impLink ← moduleNameToLink (String.toName imp)
        let indexedModule := { url := impLink, importedBy := #[] }
        pure indexedModule
    index := { index with
      modules :=
        index.modules.insert
        imp
        { indexedImp with importedBy := indexedImp.importedBy.push module.name }
    }
  return index

def DocInfo.toJson (sourceLinker : Option DeclarationRange → String) (info : Process.DocInfo) : HtmlM JsonDeclaration := do
  let name := info.getName.toString
  let kind := info.getKind
  let doc := info.getDocString.getD ""
  let docLink ← declNameToLink info.getName
  let sourceLink := sourceLinker info.getDeclarationRange
  let line := info.getDeclarationRange.pos.line
  let header := (← docInfoHeader info).toString
  -- Build structured type signature from all args + return type
  let mut segments : Array Json := #[]
  let mut first := true
  for arg in info.getArgs do
    if !first then
      segments := segments.push (Json.str " → ")
    first := false
    segments := segments ++ (← codeWithInfosToSegments arg.binder)
  if !first then
    segments := segments.push (Json.str " → ")
  segments := segments ++ (← codeWithInfosToSegments info.getType)
  let typeSig := Json.arr segments
  let info := { name, kind, doc, docLink, sourceLink, line }
  return { info, header, typeSig }

def Process.Module.toJson (module : Process.Module) : HtmlM Json := do
    let mut jsonDecls := []
    let mut instances := #[]
    let sourceLinker := (← read).sourceLinker module.name
    let declInfo := Process.filterDocInfo module.members
    for decl in declInfo do
      jsonDecls := (← DocInfo.toJson sourceLinker decl) :: jsonDecls
      if let .instanceInfo i := decl then
        instances := instances.push {
          name := i.name.toString,
          className := i.className.toString
          typeNames := i.typeNames.map Name.toString
        }
    let jsonMod : JsonModule :=  {
      name := module.name.toString,
      declarations := jsonDecls,
      instances,
      imports := module.imports.map Name.toString
    }
    return ToJson.toJson jsonMod

end DocGen4.Output
