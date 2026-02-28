import DocGen4.Output.Arg
import DocGen4.Output.Template
import DocGen4.Output.DocString
import DocGen4.Process

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx
open Lean

/--
Render a single field consisting of its documentation, its name and its type as HTML.
-/
def fieldToHtml (f : Process.FieldInfo) : HtmlM Html := do
  let shortName := f.name.componentsRev.head!.toString
  let name := f.name.toString
  let args ← f.args.mapM argToHtml
  let nameNode ← if f.isDirect then
    pure <span class="font-bold text-[var(--text-color)]">{shortName}</span>
  else
    pure <a class="text-blue-600 dark:text-blue-400 no-underline hover:underline" href={← declNameToLink f.name}>{shortName}</a>
  
  if f.isDirect then
    let doc : Array Html ←
      if let some doc := f.doc then
        let renderedDoc ← docStringToHtml doc name
        pure #[<div class="structure_field_doc mt-1 text-[var(--muted-text-color)] leading-relaxed border-l-2 border-[var(--border-color)] pl-3">[renderedDoc]</div>]
      else
        pure #[]
    pure
      <li id={name} class="structure_field mb-2 list-none">
        <div class="structure_field_info leading-relaxed">{nameNode} [args] <span class="text-[var(--muted-text-color)] mx-1">:</span> [← infoFormatToHtml f.type]</div>
        [doc]
      </li>
  else
    pure
      <li class="structure_field mb-1 list-none opacity-70">
        <div class="structure_field_info leading-relaxed">{nameNode} [args] <span class="text-[var(--muted-text-color)] mx-1">:</span> [← infoFormatToHtml f.type]</div>
      </li>

/--
Render all information about a structure as HTML.
-/
def structureToHtml (i : Process.StructureInfo) : HtmlM (Array Html) := do
  let structureHtml ← do
    if Name.isSuffixOf `mk i.ctor.name then
      pure
        <ul class="list-none p-0 pl-6 mt-2 space-y-1" id={i.ctor.name.toString}>
          [← i.fieldInfo.mapM fieldToHtml]
        </ul>
    else
      let ctorShortName := i.ctor.name.componentsRev.head!.toString
      pure
        <div class="mt-3">
          <div id={i.ctor.name.toString} class="font-mono font-bold text-[var(--text-color)] mb-1">{s!"{ctorShortName} "} :: (</div>
          <ul class="list-none p-0 pl-6 space-y-1">
            [← i.fieldInfo.mapM fieldToHtml]
          </ul>
          <div class="font-mono font-bold text-[var(--text-color)]">)</div>
        </div>
  return #[structureHtml]

end Output
end DocGen4
