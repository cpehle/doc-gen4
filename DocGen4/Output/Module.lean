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
  let kindColor := match doc.getKind with
  | "def" | "instance" => "text-blue-500 dark:text-blue-400"
  | "theorem" => "text-purple-500 dark:text-purple-400"
  | "axiom" | "opaque" => "text-teal-500 dark:text-teal-400"
  | "structure" | "inductive" | "class" => "text-yellow-600 dark:text-yellow-500"
  | _ => "text-neutral-500 dark:text-neutral-400"

  let mut nodes := #[]
  nodes := nodes.push <| Html.element "span" false #[("class", s!"decl_kind mr-2 {kindColor}")] #[doc.getKindDescription]
  -- TODO: Can we inline if-then-else and avoid repeating <span> here?
  if doc.getSorried then
    nodes := nodes.push <span class="decl_name text-[var(--text-color)] cursor-help" style="text-decoration: underline wavy #b2871d;" title="declaration uses 'sorry'"> {← declNameToHtmlBreakWithinLink doc.getName} </span>
  else
    nodes := nodes.push <span class="decl_name text-[var(--text-color)]"> {← declNameToHtmlBreakWithinLink doc.getName} </span>
  for arg in doc.getArgs do
    nodes := nodes.push (← argToHtml arg)

  match doc with
  | DocInfo.structureInfo i => nodes := nodes.append (← structureInfoHeader i)
  | DocInfo.classInfo i => nodes := nodes.append (← structureInfoHeader i)
  | _ => nodes := nodes

  nodes := nodes.push <| Html.element "span" true #[("class", "decl_args text-neutral-500")] #[" : "]
  nodes := nodes.push <span class="decl_type text-[var(--text-color)]">[← infoFormatToHtml doc.getType]</span>
  
  let copyButton := 
    <button class="copy_decl_btn ml-2 p-1 text-neutral-400 hover:text-blue-600 transition-colors focus:outline-none" title="Copy declaration" "data-name"={doc.getName.toString}>
      {.raw "<svg class=\"w-3.5 h-3.5\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><rect x=\"9\" y=\"9\" width=\"13\" height=\"13\" rx=\"2\" ry=\"2\"></rect><path d=\"M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1\"></path></svg>"}
    </button>

  return <div class="decl_header font-mono text-[0.92rem] leading-relaxed flex items-center flex-wrap overflow-x-auto"> [nodes] {copyButton} </div>

/--
Render one token inside an attribute payload. If it looks like a fully-qualified
declaration name known to doc-gen, link it.
-/
private def attrTokenToHtml (tok : String) : HtmlM Html := do
  if tok.contains "." then
    let name := String.toName tok
    if (← getResult).name2ModIdx.contains name then
      return <a class="text-blue-600 dark:text-blue-400 no-underline hover:underline" href={← declNameToLink name}>{tok}</a>
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
  return Html.element "div" false #[("class", "text-neutral-500 text-xs font-mono mb-2")] nodes

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
  let kindColor := match doc.getKind with
  | "def" | "instance" => " border-blue-500 dark:border-blue-400"
  | "theorem" => " border-purple-500 dark:border-purple-400"
  | "axiom" | "opaque" => " border-teal-500 dark:border-teal-400"
  | "structure" | "inductive" | "class" => " border-yellow-600 dark:border-yellow-500"
  | _ => " border-neutral-300 dark:border-neutral-700"
  let cssClass := s!"decl border-l-[3px]{kindColor}" ++ if doc.getSorried then " sorried" else ""
  pure
    <div class={cssClass} id={doc.getName.toString}>
      <div class={doc.getKind}>
        <div class="float-right ml-4">
          <a class="text-[10px] font-bold uppercase tracking-widest text-neutral-400 hover:text-neutral-900 dark:text-neutral-500 dark:hover:text-neutral-100 no-underline" href={← getSourceUrl module doc.getDeclarationRange}>source</a>
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
    <div class="mod_doc mb-8 text-[var(--text-color)] leading-relaxed">
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
  <div class="nav_link mb-1">
    <a class="no-underline text-blue-600 dark:text-blue-400 hover:underline break-all text-xs" href={s!"#{declName.toString}"}>
      [breakWithin declName.toString]
    </a>
  </div>

def moduleViewToggle : Html :=
  <div class="module_view_toggle flex items-center mb-6 text-xs text-[var(--muted-text-color)]" id="module_view_toggle">
    <span class="module_view_toggle_label uppercase tracking-widest mr-3">Declarations</span>
    <button class="module_view_toggle_button border border-neutral-200 dark:border-neutral-700 bg-[var(--panel-bg)] pointer px-2 py-1 mr-2 rounded hover:border-neutral-400 dark:hover:border-neutral-500 transition-colors" id="module_view_source" type="button">declaration order</button>
    <button class="module_view_toggle_button border border-neutral-200 dark:border-neutral-700 bg-[var(--panel-bg)] pointer px-2 py-1 rounded hover:border-neutral-400 dark:hover:border-neutral-500 transition-colors" id="module_view_kind" type="button">group by kind</button>
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
  imports.mapM (fun i => do return <li class="mb-1 text-xs">{← moduleToHtmlLink i}</li>)

/--
Render the internal nav bar (the thing on the right on all module pages).
-/
def internalNav (members : Array Name) (moduleName : Name) : HtmlM Html := do
  pure
    <nav class="internal_nav flex-shrink-0 sticky xl:h-[calc(100vh-2.9rem)] top-[2.9rem] border-b xl:border-b-0 xl:border-l border-[var(--border-color)] bg-[var(--body-bg)] text-[var(--text-color)] px-4 py-6 overflow-auto text-sm leading-relaxed z-30 w-full xl:w-[clamp(15rem,19vw,21rem)]">
      <div class="xl:hidden flex justify-between items-center mb-4">
        <h3 class="text-[10px] font-bold uppercase tracking-widest text-[var(--muted-text-color)]">On this page</h3>
        <details class="group">
          <summary class="list-none cursor-pointer flex items-center text-blue-600 dark:text-blue-400 font-medium">
            <span>Menu</span>
            {.raw "<svg class=\"chevron w-4 h-4 ml-1 transition-transform group-open:rotate-180\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M19 9l-7 7-7-7\"></path></svg>"}
          </summary>
          <div class="absolute left-0 right-0 mt-2 p-4 bg-[var(--body-bg)] border-b border-[var(--border-color)] shadow-xl overflow-y-auto max-h-[60vh] z-40">
            <p class="m-0 mb-3"><a class="no-underline text-blue-600 dark:text-blue-400 hover:underline font-medium" href="#top">Return to top</a></p>
            <div class="internal_nav_decls">
              [members.map declarationToNavLink]
            </div>
          </div>
        </details>
      </div>

      <div class="hidden xl:block">
        <p class="m-0 mb-3"><a class="no-underline text-blue-600 dark:text-blue-400 hover:underline font-medium" href="#top">Return to top</a></p>
        <p class="gh_nav_link m-0 mb-6"><a class="no-underline text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 text-[10px] uppercase tracking-wider" href={← getSourceUrl moduleName none}>Source</a></p>
        <div class="imports mb-6">
          <details class="mb-3 group">
            <summary class="w-full cursor-pointer font-bold uppercase tracking-widest text-[10px] text-[var(--muted-text-color)] mb-2 flex justify-between items-center list-none [&::-webkit-details-marker]:hidden">
              <span>Imports</span>
              {.raw "<svg class=\"chevron w-5 h-5 \" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\" xmlns=\"http://www.w3.org/2000/svg\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 5l7 7-7 7\"></path></svg>"}
            </summary>
            <ul class="list-none p-0 pl-3 m-0 border-l border-[var(--border-color)]">
              [← importsHtml moduleName]
            </ul>
          </details>
          <details class="mb-3 group">
            <summary class="w-full cursor-pointer font-bold uppercase tracking-widest text-[10px] text-[var(--muted-text-color)] mb-2 flex justify-between items-center list-none [&::-webkit-details-marker]:hidden">
              <span>Imported by</span>
              {.raw "<svg class=\"chevron w-5 h-5 \" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\" xmlns=\"http://www.w3.org/2000/svg\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 5l7 7-7 7\"></path></svg>"}
            </summary>
            <ul id={s!"imported-by-{moduleName}"} class="imported-by-list list-none p-0 pl-3 m-0 border-l border-[var(--border-color)] text-xs"> </ul>
          </details>
        </div>
        <div class="internal_nav_decls mt-4 pt-4 border-t border-[var(--border-color)]">
          [members.map declarationToNavLink]
        </div>
      </div>
    </nav>

def breadcrumb (name : Name) : BaseHtmlM Html := do
  let components := name.components
  let mut nodes : Array Html := #[]
  let mut currentName := Name.anonymous
  for i in [0:components.length] do
    let c := components[i]!
    currentName := Name.mkStr currentName c.toString
    let link ← moduleNameToLink currentName
    nodes := nodes.push <a class="no-underline text-blue-600 dark:text-blue-400 hover:underline" href={link}>{c.toString}</a>
    if i < components.length - 1 then
      nodes := nodes.push <span class="mx-1 text-neutral-400">.</span>
  return <nav class="flex text-xs font-mono mb-6 overflow-x-auto whitespace-nowrap pb-2">[nodes]</nav>

/--
The main entry point to rendering the HTML for an entire module.
-/
def moduleToHtml (module : Process.Module) : HtmlM Html := withTheReader SiteBaseContext (setCurrentName module.name) do
  let relevantMembers := module.members.filter Process.ModuleMember.shouldRender
  let memberDocs ← relevantMembers.mapM (moduleMemberToHtml module.name)
  let memberNames := filterDocInfo relevantMembers |>.map DocInfo.getName
  templateLiftExtends (baseHtmlGenerator module.name.toString) <| pure #[
    Html.element "main" true #[("class", "px-4 xl:px-8 py-8 flex-auto min-w-0 bg-[var(--body-bg)] text-[var(--text-color)]"), ("style", "max-width: var(--content-width);")] <| #[← breadcrumb module.name, moduleViewToggle] ++ memberDocs,
    ← internalNav memberNames module.name
  ]

end Output
end DocGen4
