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

/--
Render the 404 page.
-/
def notFound : BaseHtmlM Html := do templateExtends (baseHtml "404") <|
  pure <|
    <main class="ph3 mv4 flex-auto" style="max-width: var(--content-width);">
      <h1 class="f2 fw6 ma0 mb3">404 Not Found</h1>
      <p class="f5 lh-copy slate"> Unfortunately, the page you were looking for is no longer here. </p>
      <div id="howabout" class="mt4 slate"></div>
    </main>

end Output
end DocGen4
