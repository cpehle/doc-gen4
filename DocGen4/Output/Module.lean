/-
Copyright (c) 2021 Henrik Böving. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
import DocGen4.Output.Template
import DocGen4.Output.Inductive
import DocGen4.Output.Structure
import DocGen4.Output.Class
import DocGen4.Output.Definition
import DocGen4.Output.Instance
import DocGen4.Output.ClassInductive
import DocGen4.Output.DocString
import DocGen4.Process

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx
open Lean Process

/--
Render the structures this structure extends from as HTML so it can be
added to the top level.
-/
def structureInfoHeader (s : Process.StructureInfo) : HtmlM (Array Html) := do
  let mut nodes := #[]
  if s.parents.size > 0 then
    nodes := nodes.push <span class="decl_extends">extends</span>
    let mut parents := #[Html.text " "]
    for parent in s.parents, i in [0:s.parents.size] do
      if i > 0 then
        parents := parents.push (Html.text ", ")
      parents := parents ++ (← infoFormatToHtml parent.type)
    nodes := nodes ++ parents
  return nodes

/--
Render the general header of a declaration containing its declaration type
and name.
-/
def docInfoHeader (doc : DocInfo) : HtmlM Html := do
  let mut nodes := #[]
  nodes := nodes.push <| Html.element "span" false #[("class", "decl_kind")] #[doc.getKindDescription]
  -- TODO: Can we inline if-then-else and avoid repeating <span> here?
  if doc.getSorried then
    nodes := nodes.push <span class="decl_name" title="declaration uses 'sorry'"> {← declNameToHtmlBreakWithinLink doc.getName} </span>
  else
    nodes := nodes.push <span class="decl_name"> {← declNameToHtmlBreakWithinLink doc.getName} </span>
  for arg in doc.getArgs do
    nodes := nodes.push (← argToHtml arg)

  match doc with
  | DocInfo.structureInfo i => nodes := nodes.append (← structureInfoHeader i)
  | DocInfo.classInfo i => nodes := nodes.append (← structureInfoHeader i)
  | _ => nodes := nodes

  nodes := nodes.push <| Html.element "span" true #[("class", "decl_args")] #[" : "]
  nodes := nodes.push <span class="decl_type">[← infoFormatToHtml doc.getType]</span>
  return <div class="decl_header"> [nodes] </div>

/--
Render one token inside an attribute payload. If it looks like a fully-qualified
declaration name known to doc-gen, link it.
-/
private def attrTokenToHtml (tok : String) : HtmlM Html := do
  if tok.contains "." then
    let name := String.toName tok
    if (← getResult).name2ModIdx.contains name then
      return <a href={← declNameToLink name}>{tok}</a>
  return tok

/--
Render a raw attribute payload (e.g. `deprecated Foo.bar (since := "v1")`) with
linkification for declaration names.
-/
private def attrPayloadToHtml (attr : String) : HtmlM (Array Html) := do
  let parts := attr.splitOn " " |>.toArray
  let mut nodes : Array Html := #[]
  for part in parts, i in [0:parts.size] do
    if i > 0 then
      nodes := nodes.push " "
    nodes := nodes.push (← attrTokenToHtml part)
  return nodes

/--
Render `@[attr1, attr2, ...]` as HTML, preserving punctuation while allowing
linkification inside each attribute payload.
-/
private def attrsToHtml (attrs : Array String) : HtmlM Html := do
  let mut nodes : Array Html := #["@["]
  for attr in attrs, i in [0:attrs.size] do
    if i > 0 then
      nodes := nodes.push ", "
    nodes := nodes ++ (← attrPayloadToHtml attr)
  nodes := nodes.push "]"
  return Html.element "div" false #[("class", "attributes")] nodes

/--
The main entry point for rendering a single declaration inside a given module.
-/
def docInfoToHtml (module : Name) (doc : DocInfo) : HtmlM Html := do
  -- basic info like headers, types, structure fields, etc.
  let docInfoHtml ← match doc with
  | DocInfo.inductiveInfo i => inductiveToHtml i
  | DocInfo.structureInfo i => structureToHtml i
  | DocInfo.classInfo i => classToHtml i
  | DocInfo.classInductiveInfo i => classInductiveToHtml i
  | _ => pure #[]
  -- rendered doc stirng
  let docStringHtml ← match doc.getDocString with
  | some s => docStringToHtml s doc.getName.toString
  | none => pure #[]
  -- extra information like equations and instances
  let extraInfoHtml ← match doc with
  | DocInfo.classInfo i => pure #[← classInstancesToHtml i.name]
  | DocInfo.definitionInfo i => pure ((← equationsToHtml i) ++ #[← instancesForToHtml i.name])
  | DocInfo.instanceInfo i => equationsToHtml i.toDefinitionInfo
  | DocInfo.classInductiveInfo i => pure #[← classInstancesToHtml i.name]
  | DocInfo.inductiveInfo i => pure #[← instancesForToHtml i.name]
  | DocInfo.structureInfo i => pure #[← instancesForToHtml i.name]
  | _ => pure #[]
  let attrs := doc.getAttrs
  let attrsHtml ←
    if attrs.size > 0 then
      pure #[← attrsToHtml attrs]
    else
      pure #[]
  -- custom decoration (e.g., verification badges from external tools)
  let decorator ← getDeclarationDecorator
  let decoratorHtml := decorator module doc.getName doc.getKind
  let cssClass := "decl" ++ if doc.getSorried then " sorried" else ""
  pure
    <div class={cssClass} id={doc.getName.toString}>
      <div class={doc.getKind}>
        <div class="gh_link">
          <a href={← getSourceUrl module doc.getDeclarationRange}>source</a>
        </div>
        [decoratorHtml]
        [attrsHtml]
        {← docInfoHeader doc}
        [docStringHtml]
        [docInfoHtml]
        [extraInfoHtml]
      </div>
    </div>

/--
Rendering a module doc string, that is the ones with an ! after the opener
as HTML.
-/
def modDocToHtml (mdoc : ModuleDoc) : HtmlM Html := do
  pure
    <div class="mod_doc">
      [← docStringToHtml mdoc.doc ""]
    </div>

/--
Render a module member, that is either a module doc string or a declaration
as HTML.
-/
def moduleMemberToHtml (module : Name) (member : ModuleMember) : HtmlM Html := do
  match member with
  | ModuleMember.docInfo d => docInfoToHtml module d
  | ModuleMember.modDoc d => modDocToHtml d

def declarationToNavLink (declName : Name) : Html :=
  <div class="nav_link">
    <a class="break_within" href={s!"#{declName.toString}"}>
      [breakWithin declName.toString]
    </a>
  </div>

def moduleViewToggle : Html :=
  <div class="module_view_toggle" id="module_view_toggle">
    <span class="module_view_toggle_label">Declarations</span>
    <button class="module_view_toggle_button" id="module_view_source" type="button">declaration order</button>
    <button class="module_view_toggle_button" id="module_view_kind" type="button">group by kind</button>
  </div>

/--
Returns the list of all imports this module does.
-/
def getImports (module : Name) : HtmlM (Array Name) := do
  let res ← getResult
  return res.moduleInfo[module]!.imports

/--
Sort the list of all modules this one is importing, linkify it
and return the HTML.
-/
def importsHtml (moduleName : Name) : HtmlM (Array Html) := do
  let imports := (← getImports moduleName).qsort Name.lt
  imports.mapM (fun i => do return <li>{← moduleToHtmlLink i}</li>)

/--
Render the internal nav bar (the thing on the right on all module pages).
-/
def internalNav (members : Array Name) (moduleName : Name) : HtmlM Html := do
  pure
    <nav class="internal_nav">
      <p><a href="#top">return to top</a></p>
      <p class="gh_nav_link"><a href={← getSourceUrl moduleName none}>source</a></p>
      <div class="imports">
        <details>
          <summary>Imports</summary>
          <ul>
            [← importsHtml moduleName]
          </ul>
        </details>
        <details>
          <summary>Imported by</summary>
          <ul id={s!"imported-by-{moduleName}"} class="imported-by-list"> </ul>
        </details>
      </div>
      <div class="internal_nav_decls">
        [members.map declarationToNavLink]
      </div>
    </nav>

/--
The main entry point to rendering the HTML for an entire module.
-/
def moduleToHtml (module : Process.Module) : HtmlM Html := withTheReader SiteBaseContext (setCurrentName module.name) do
  let relevantMembers := module.members.filter Process.ModuleMember.shouldRender
  let memberDocs ← relevantMembers.mapM (moduleMemberToHtml module.name)
  let memberNames := filterDocInfo relevantMembers |>.map DocInfo.getName
  templateLiftExtends (baseHtmlGenerator module.name.toString) <| pure #[
    ← internalNav memberNames module.name,
    Html.element "main" false #[] <| #[moduleViewToggle] ++ memberDocs
  ]

end Output
end DocGen4
