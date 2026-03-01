/-
Copyright (c) 2021 Henrik Böving. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
import Lean
import DocGen4.Output.ToHtmlFormat
import DocGen4.Output.Base

namespace DocGen4
namespace Output

open Lean
open scoped DocGen4.Jsx

def moduleListFile (file : Name) : BaseHtmlM Html := do
  let isCurrent := (← getCurrentName) == file
  let className := if isCurrent then "mb-1 font-semibold text-[var(--text-color)] bg-neutral-100 dark:bg-neutral-800 px-2 py-2 xl:py-1 rounded" else "mb-1 text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 px-2 py-2 xl:py-1 rounded hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-all"
  return <div class={className}>
    <a class="no-underline block w-full" href={← moduleNameToLink file}>{file.getString!}</a>
  </div>

def bookNavLink (entry : BookNavEntry) : BaseHtmlM Html := do
  let isCurrent := (← getCurrentPage) == some entry.href
  let className := if isCurrent then "mb-1 font-semibold text-[var(--text-color)] bg-neutral-100 dark:bg-neutral-800 px-2 py-2 xl:py-1 rounded" else "mb-1 text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 px-2 py-2 xl:py-1 rounded hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-all"
  let indentRem := entry.level + 1
  return <div class={className} style={s!"margin-left: {indentRem}rem"}>
    <a class="no-underline block w-full" href={s!"{← getRoot}{entry.href}"}>{entry.title}</a>
  </div>

/--
Build the HTML tree representing the module hierarchy.
-/
partial def moduleListDir (h : Hierarchy) : BaseHtmlM Html := do
  let children := Array.mk (h.getChildren.toList.map Prod.snd)
  let dirs := children.filter (fun c => c.getChildren.toList.length != 0)
  let files := children.filter (fun c => Hierarchy.isFile c && c.getChildren.toList.length = 0)
    |>.map Hierarchy.getName
  let dirNodes ← dirs.mapM moduleListDir
  let fileNodes ← files.mapM moduleListFile
  let moduleLink ← moduleNameToLink h.getName
  let label : Html ← do
    if h.isFile then
      pure <a class="no-underline text-inherit hover:text-neutral-900 dark:hover:text-neutral-100 flex-auto px-1" href={moduleLink}>{h.getName.getString!}</a>
    else
      pure <span class="text-[var(--muted-text-color)] flex-auto px-1">{h.getName.getString!}</span>
  let summary :=
    <summary class="w-full list-none flex items-center justify-between cursor-pointer hover:text-neutral-900 dark:hover:text-neutral-100 text-[var(--muted-text-color)] px-1 py-1 rounded hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-all [&::-webkit-details-marker]:hidden">
      {label}
      {.raw "<svg class=\"chevron w-4 h-4 ml-2 \" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\" xmlns=\"http://www.w3.org/2000/svg\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 5l7 7-7 7\"></path></svg>"}
    </summary>
  pure
    <details class="ml-2 group" "data-path"={moduleLink} [if (← getCurrentName).any (h.getName.isPrefixOf ·) then #[("open", "")] else #[]]>
      {summary}
      <div class="border-l border-[var(--border-color)] ml-2 pl-1 mt-1 mb-2">
        [dirNodes]
        [fileNodes]
      </div>
    </details>

/--
Return a list of top level modules, linkified and rendered as HTML
-/
def moduleList : BaseHtmlM Html := do
  let hierarchy ← getHierarchy
  let mut list := Array.empty
  for (_, cs) in hierarchy.getChildren do
    list := list.push <| ← moduleListDir cs
  return <div class="module_list mt2">[list]</div>

/--
Return the inner navigation content (static page links, module tree, settings)
without any HTML/head/body wrapper. Intended to be inlined directly into the page.
-/
def navContent : BaseHtmlM Html := do
  let mut staticPages : Array Html := #[
    <div class="mb-1 px-2 py-2 xl:py-1 rounded hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-all"><a class="no-underline text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 block w-full" href={s!"{← getRoot}"}>Index</a></div>,
    <div class="mb-1 px-2 py-2 xl:py-1 rounded hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-all"><a class="no-underline text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 block w-full" href={s!"{← getRoot}foundational_types.html"}>Foundational Types</a></div>,
    <div class="mb-1 px-2 py-2 xl:py-1 rounded hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-all"><a class="no-underline text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 block w-full" href={s!"{← getRoot}tactics.html"}>Tactics</a></div>,
  ]
  let config ← read
  if not config.refs.isEmpty then
    staticPages := staticPages.push <div class="mb-1 px-2 py-2 xl:py-1 rounded hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-all"><a class="no-underline text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 block w-full" href={s!"{← getRoot}references.html"}>References</a></div>
  let bookPages ← config.bookNav.mapM bookNavLink
  let bookSection : Array Html :=
    if bookPages.isEmpty then
      #[]
    else
      #[<h3 class="text-[10px] font-bold uppercase tracking-widest text-[var(--muted-text-color)] mt-6 mb-2 px-2"> {config.bookNavLabel} </h3>] ++ bookPages
  pure
    <nav class="nav fixed xl:sticky top-0 xl:top-[2.9rem] left-0 z-50 xl:z-0 w-72 xl:w-80 h-screen xl:h-[calc(100vh-2.9rem)] bg-[var(--body-bg)] border-r border-[var(--border-color)] px-4 py-6 overflow-auto text-sm transition-transform -translate-x-full xl:translate-x-0 shadow-xl xl:shadow-none">
      <div class="xl:hidden flex justify-between items-center mb-6 px-2">
        <span class="text-xs font-bold uppercase tracking-widest text-[var(--muted-text-color)]">Menu</span>
        <label for="nav_toggle" class="p-2 -mr-2 text-[var(--muted-text-color)] hover:text-[var(--text-color)] cursor-pointer transition-colors">
          {.raw "<svg class=\"w-5 h-5\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M6 18L18 6M6 6l12 12\"></path></svg>"}
        </label>
      </div>
      <h3 class="text-[10px] font-bold uppercase tracking-widest text-[var(--muted-text-color)] mt-0 mb-2 px-2"> General </h3>
      <div class="mb-6">
        [staticPages]
      </div>
      [bookSection]
      <h3 class="text-[10px] font-bold uppercase tracking-widest text-[var(--muted-text-color)] mt-6 mb-2 px-2"> Library </h3>
      <div class="mb-6">
        {← moduleList}
      </div>
    </nav>

end Output
end DocGen4
