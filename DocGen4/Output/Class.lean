import DocGen4.Output.Template
import DocGen4.Output.Structure
import DocGen4.Process

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx
open Lean

def classInstancesToHtml (className : Name) : HtmlM Html := do
  pure
    <details «class»="instances mt-4">
        <summary class="w-full cursor-pointer font-bold text-xs uppercase tracking-widest text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 transition-colors flex justify-between items-center list-none [&::-webkit-details-marker]:hidden">
          Instances
          {.raw "<svg class=\"chevron w-5 h-5 \" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\" xmlns=\"http://www.w3.org/2000/svg\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 5l7 7-7 7\"></path></svg>"}
        </summary>
        <ul id={s!"instances-list-{className}"} class="instances-list list-none p-0 pl-4 mt-3 border-l border-[var(--border-color)]"></ul>
    </details>

def classToHtml (i : Process.ClassInfo) : HtmlM (Array Html) := do
  structureToHtml i

end Output
end DocGen4
