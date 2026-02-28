/-
Copyright (c) 2023 Jeremy Salwen. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Jeremy Salwen
-/
import DocGen4.Output.ToHtmlFormat
import DocGen4.Output.Template

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx

def search : BaseHtmlM Html := do templateExtends (baseHtml "Search") <| do
  pure
    <main class="px-6 py-6 flex-auto min-w-0 bg-[var(--body-bg)] text-[var(--text-color)] text-[var(--text-color)]" style="max-width: var(--content-width);">
      <input id="search_page_query" class="w-full max-w-2xl px-4 py-2 text-lg border rounded bg-neutral-50 dark:bg-neutral-800 border-neutral-300 dark:border-neutral-700 text-[var(--text-color)] focus:outline-none focus:ring-2 focus:ring-blue-500 mb-6" placeholder="Search declarations..." />
      <div id="kinds" class="flex flex-wrap items-center gap-3 text-xs text-[var(--muted-text-color)] mb-8">
        <span class="font-bold uppercase tracking-widest text-[10px]">Filter:</span>
        <input type="checkbox" id="def_checkbox" class="kind_checkbox hidden" value="def" checked="checked" />
        <label for="def_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">def</label>
        <input type="checkbox" id="theorem_checkbox" class="kind_checkbox hidden" value="theorem" checked="checked" />
        <label for="theorem_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">theorem</label>
        <input type="checkbox" id="inductive_checkbox" class="kind_checkbox hidden" value="inductive" checked="checked" />
        <label for="inductive_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">inductive</label>
        <input type="checkbox" id="structure_checkbox" class="kind_checkbox hidden" value="structure" checked="checked" />
        <label for="structure_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">structure</label>
        <input type="checkbox" id="class_checkbox" class="kind_checkbox hidden" value="class" checked="checked" />
        <label for="class_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">class</label>
        <input type="checkbox" id="instance_checkbox" class="kind_checkbox hidden" value="instance" checked="checked" />
        <label for="instance_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">instance</label>
        <input type="checkbox" id="axiom_checkbox" class="kind_checkbox hidden" value="axiom" checked="checked" />
        <label for="axiom_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">axiom</label>
        <input type="checkbox" id="opaque_checkbox" class="kind_checkbox hidden" value="opaque" checked="checked" />
        <label for="opaque_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">opaque</label>
        <input type="checkbox" id="guide_checkbox" class="kind_checkbox hidden" value="guide" checked="checked" />
        <label for="guide_checkbox" class="border border-neutral-200 dark:border-neutral-700 px-3 py-1 rounded cursor-pointer hover:bg-neutral-50 dark:hover:bg-neutral-800 transition-colors">guide</label>
      </div>

      <script>
        {.raw "document.getElementById('search_page_query').value = new URL(window.location.href).searchParams.get('q')"}
      </script>
      <div id="search_results">
      </div>
    </main>

end Output
end DocGen4
