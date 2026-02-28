/-
Copyright (c) 2025 Anne Baanen. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Anne Baanen
-/
import DocGen4.Process.Analyze
import DocGen4.Output.Module

namespace DocGen4.Process

open scoped DocGen4.Jsx
open DocGen4 Output Lean

/--
Render the HTML for a single tactic.
-/
def TacticInfo.docStringToHtml (tac : TacticInfo MarkdownDocstring) : Output.HtmlM (TacticInfo Html) := do
  return {
    tac with
    docString := <p>[← Output.docStringToHtml tac.docString tac.internalName.toString]</p>
  }

/--
Render the HTML for a single tactic.
-/
def TacticInfo.toHtml (tac : TacticInfo Html) : Output.BaseHtmlM Html := do
  let internalName := tac.internalName.toString
  let defLink := (← moduleNameToLink tac.definingModule) ++ "#" ++ internalName
  let tags := ", ".intercalate (tac.tags.map (·.toString)).qsort.toList
  return <div id={internalName} class="tactic">
    <h2 class="text-xl font-bold mb-6 text-[var(--text-color)]">{tac.userName}</h2>
    <div class="leading-relaxed text-[var(--text-color)] mb-8">{tac.docString}</div>
    <dl class="text-sm leading-relaxed m-0 text-[var(--muted-text-color)]">
      <div class="flex items-baseline mb-2">
        <dt class="font-bold uppercase tracking-widest text-[10px] text-neutral-500 mr-4 w-32 flex-shrink-0">Tags</dt>
        <dd class="m-0 font-mono text-xs bg-neutral-100 dark:bg-neutral-800 px-2 py-0.5 rounded-sm">{tags}</dd>
      </div>
      <div class="flex items-baseline">
        <dt class="font-bold uppercase tracking-widest text-[10px] text-neutral-500 mr-4 w-32 flex-shrink-0">Defined in module</dt>
        <dd class="m-0"><a class="text-blue-600 dark:text-blue-400 no-underline hover:underline font-mono text-xs" href={defLink}>{tac.definingModule.toString}</a></dd>
      </div>
    </dl>
  </div>

def TacticInfo.navLink (tac : TacticInfo α) : Html :=
  <p class="m-0 mb-1"><a class="no-underline text-blue-600 dark:text-blue-400 hover:underline text-xs" href={"#".append tac.internalName.toString}>{tac.userName}</a></p>

end DocGen4.Process

namespace DocGen4.Output

open scoped DocGen4.Jsx
open Lean Process

/--
Render the HTML for the tactics listing page.
-/
def tactics (tacticInfo : Array (TacticInfo Html)) : BaseHtmlM Html := do
  let sectionsHtml ← tacticInfo.mapM (· |>.toHtml)
  templateLiftExtends (baseHtmlGenerator "Tactics") <| pure #[
    Html.element "main" true #[("class", "px-6 py-6 flex-auto min-w-0 bg-[var(--body-bg)] text-[var(--text-color)] text-[var(--text-color)]"), ("style", "max-width: var(--content-width);")] (
      #[<p class="text-lg leading-relaxed text-[var(--muted-text-color)] mb-8">The tactic language is a special-purpose programming language for constructing proofs, indicated using the keyword <code class="bg-neutral-100 dark:bg-neutral-800 px-1 rounded text-sm">by</code>.</p>] ++
      sectionsHtml),
    <nav class="flex-shrink-0 sticky h-[calc(100vh-2.9rem)] top-[2.9rem] border-l border-[var(--border-color)] bg-[var(--body-bg)] text-[var(--text-color)] px-4 py-6 overflow-auto text-sm leading-relaxed shadow-sm" style="width: clamp(15rem, 19vw, 21rem);">
      <p class="m-0 mb-3"><a class="no-underline text-blue-600 dark:text-blue-400 hover:underline font-medium" href="#top">Return to top</a></p>
      [tacticInfo.map (· |>.navLink)]
    </nav>
  ]

def loadTacticsJSON (buildDir : System.FilePath) : IO (Array (TacticInfo Html)) := do
  let mut result : Array (TacticInfo _) := #[]
  for entry in ← System.FilePath.readDir (declarationsBasePath buildDir) do
    if entry.fileName.startsWith "tactics-" && entry.fileName.endsWith ".json" then
      let fileContent ← IO.FS.readFile entry.path
      match Json.parse fileContent with
      | .error err =>
        throw <| IO.userError s!"failed to parse file '{entry.path}' as json: {err}"
      | .ok jsonContent =>
        match fromJson? jsonContent with
        | .error err =>
          throw <| IO.userError s!"failed to parse file '{entry.path}': {err}"
        | .ok (arr : Array (TacticInfo _)) => result := result ++ arr
  return result.qsort (lt := (·.userName < ·.userName))

/-- Save sections of supplementary pages declared in a specific module.

This `abbrev` exists as a type-checking wrapper around `toJson`, ensuring `loadTacticsJSON` gets
objects in the expected format.
-/
abbrev saveTacticsJSON (fileName : System.FilePath) (tacticInfo : Array (TacticInfo Html)) : IO Unit := do
  if tacticInfo.size > 0 then
    IO.FS.writeFile fileName (toString (toJson tacticInfo))

end Output
end DocGen4
