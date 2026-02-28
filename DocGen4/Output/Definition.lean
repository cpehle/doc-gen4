import DocGen4.Output.Template
import DocGen4.Output.DocString
import DocGen4.Process

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx
open Lean Widget

/-- This is basically an arbitrary number that seems to work okay. -/
def equationLimit : Nat := 200

def equationToHtml (c : CodeWithInfos) : HtmlM Html := do
  return <li class="equation mb-1 list-none text-[var(--muted-text-color)]">[← infoFormatToHtml c]</li>

/--
Attempt to render all `simp` equations for this definition. At a size
defined in `equationLimit` we stop trying since they:
- are too ugly to read most of the time
- take too long
-/
def equationsToHtml (i : Process.DefinitionInfo) : HtmlM (Array Html) := do
  if let some eqs := i.equations then
    let equationsHtml ← eqs.mapM equationToHtml
    let filteredEquationsHtml := equationsHtml.filter (·.textLength < equationLimit)
    let body := if equationsHtml.size ≠ filteredEquationsHtml.size then
      #[<li class="mb-1 list-none text-xs text-[var(--muted-text-color)] italic">One or more equations did not get rendered due to their size.</li>] ++ filteredEquationsHtml
    else
      filteredEquationsHtml
    return #[
      <details class="mt-4">
        <summary class="w-full cursor-pointer font-bold text-xs uppercase tracking-widest text-[var(--muted-text-color)] hover:text-neutral-900 dark:hover:text-neutral-100 transition-colors flex justify-between items-center list-none [&::-webkit-details-marker]:hidden">
          Equations
          {.raw "<svg class=\"chevron w-5 h-5 \" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\" xmlns=\"http://www.w3.org/2000/svg\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M9 5l7 7-7 7\"></path></svg>"}
        </summary>
        <ul class="list-none p-0 pl-4 mt-3 space-y-1 border-l-2 border-[var(--border-color)] ml-2">
          [body]
        </ul>
      </details>
    ]
  else
    return #[]

end Output
end DocGen4

