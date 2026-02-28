import DocGen4.Output.Arg
import DocGen4.Output.Template
import DocGen4.Output.DocString
import DocGen4.Process

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx
open Lean

def instancesForToHtml (typeName : Name) : BaseHtmlM Html := do
  pure
    <details id={s!"instances-for-list-{typeName}"} «class»="instances-for-list mt-4">
        <summary class="w-full cursor-pointer font-bold text-xs uppercase tracking-widest text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 transition-colors flex justify-between items-center list-none [&::-webkit-details-marker]:hidden">
          Instances For
          {.raw "<svg class=\"chevron w-5 h-5 \" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\" xmlns=\"http://www.w3.org/2000/svg\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 5l7 7-7 7\"></path></svg>"}
        </summary>
        <ul class="instances-for-enum list-none p-0 pl-4 mt-3 border-l border-[var(--border-color)]"></ul>
    </details>

def ctorToHtml (c : Process.ConstructorInfo) : HtmlM Html := do
  let shortName := c.name.componentsRev.head!.toString
  let name := c.name.toString
  let args ← c.args.mapM argToHtml
  let header := <span class="font-bold text-[var(--text-color)]">{shortName}</span>
  if let some doc := c.doc then
    let renderedDoc ← docStringToHtml doc name
    pure
      <li class="constructor mb-3 list-none" id={name}>
        {header} [args] <span class="text-[var(--muted-text-color)] mx-1">:</span> [← infoFormatToHtml c.type]
        <div class="inductive_ctor_doc mt-1 text-[var(--muted-text-color)] leading-relaxed pl-2 opacity-80">[renderedDoc]</div>
      </li>
  else
    pure
      <li class="constructor mb-1 list-none" id={name}>
        {header} [args] <span class="text-[var(--muted-text-color)] mx-1">:</span> [← infoFormatToHtml c.type]
      </li>

def inductiveToHtml (i : Process.InductiveInfo) : HtmlM (Array Html) := do
  let constructorsHtml := <ul class="list-none p-0 pl-4 mt-3 border-l-2 border-[var(--border-color)] ml-2">[← i.ctors.toArray.mapM ctorToHtml]</ul>
  return #[constructorsHtml]

end Output
end DocGen4
