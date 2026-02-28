/-
Copyright (c) 2021 Henrik Böving. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
import DocGen4.Output.ToHtmlFormat
import DocGen4.Output.Template

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx

def index : BaseHtmlM Html := do templateExtends (baseHtml "Index") <|
  pure <|
    <main class="px-6 py-6 flex-auto min-w-0 bg-[var(--body-bg)] text-[var(--text-color)] text-[var(--text-color)]" style="max-width: var(--content-width);">
      <a id="top"></a>
      <h1 class="text-3xl font-bold mb-6"> Welcome to the documentation page </h1>
      -- Temporary comment until the lake issue is resolved
      -- for commit <a class="text-blue-600 dark:text-blue-400 no-underline hover:underline" href={s!"{← getProjectGithubUrl}/tree/{← getProjectCommit}"}>{s!"{← getProjectCommit} "}</a>
      <p class="text-lg leading-relaxed text-[var(--muted-text-color)]">This was built using Lean 4 <a class="text-blue-600 dark:text-blue-400 no-underline hover:underline font-medium" href={s!"https://github.com/leanprover/lean4/tree/{Lean.githash}"}>{Lean.versionString}</a></p>
    </main>

end Output
end DocGen4
