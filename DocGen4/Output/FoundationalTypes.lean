import DocGen4.Output.Template
import DocGen4.Output.Inductive

namespace DocGen4.Output

open scoped DocGen4.Jsx

def foundationalTypes : BaseHtmlM Html := templateLiftExtends (baseHtml "Foundational Types") do
  pure <|
    <main class="px-6 py-6 flex-auto min-w-0 bg-[var(--body-bg)] text-[var(--text-color)] text-[var(--text-color)]" style="max-width: var(--content-width);">
      <a id="top"></a>
      <h1 class="text-3xl font-bold mb-6">Foundational Types</h1>

      <p class="text-lg leading-relaxed text-[var(--muted-text-color)] mb-4">Some of Lean's types are not defined in any Lean source files (even the <code>prelude</code>) since they come from its foundational type theory. This page provides basic documentation for these types.</p>
      <p class="text-lg leading-relaxed text-[var(--muted-text-color)] mb-8">For a more in-depth explanation of Lean's type theory, refer to
      <a class="text-blue-600 dark:text-blue-400 no-underline hover:underline font-medium" href="https://leanprover.github.io/theorem_proving_in_lean4/Dependent-Type-Theory/">TPiL</a>.</p>


      <h2 id="codesort-ucode" class="text-2xl font-bold mt-12 mb-4"><code>Sort u</code></h2>
      <p class="leading-relaxed text-[var(--muted-text-color)] mb-4"><code>Sort u</code> is the type of types in Lean, and <code>Sort u : Sort (u + 1)</code>.</p>
      {← instancesForToHtml `_builtin_sortu}

      <h2 id="codetype-ucode" class="text-2xl font-bold mt-12 mb-4"><code>Type u</code></h2>
      <p class="leading-relaxed text-[var(--muted-text-color)] mb-4"><code>Type u</code> is notation for <code>Sort (u + 1)</code>.</p>
      {← instancesForToHtml `_builtin_typeu}

      <h2 id="codepropcode" class="text-2xl font-bold mt-12 mb-4"><code>Prop</code></h2>
      <p class="leading-relaxed text-[var(--muted-text-color)] mb-4"><code>Prop</code> is notation for <code>Sort 0</code>.</p>
      {← instancesForToHtml `_builtin_prop}

      <h2 id="pi-types-codeπ-a--α-β-acode" class="text-2xl font-bold mt-12 mb-4">Pi types, <code>{"(a : α) → β a"}</code></h2>
      <p class="leading-relaxed text-[var(--muted-text-color)] mb-4">The type of dependent functions is known as a pi type.
      Non-dependent functions and implications are a special case.</p>
      <p class="leading-relaxed text-[var(--muted-text-color)] mb-4">Note that these can also be written with the alternative notations:</p>
      <ul class="list-disc pl-6 mb-6 text-[var(--muted-text-color)] space-y-2">
      <li><code>∀ a : α, β a</code>, conventionally used where <code>β a : Prop</code>.</li>
      <li><code>(a : α) → β a</code></li>
      <li><code>α → γ</code>, possible only if <code>β a = γ</code> for all <code>a</code>.</li>
      </ul>
      <p class="leading-relaxed text-[var(--muted-text-color)] mb-4">Lean also permits ASCII-only spellings of the three variants:</p>
      <ul class="list-disc pl-6 mb-6 text-[var(--muted-text-color)] space-y-2">
      <li><code>forall a : A, B a</code>, for <code>{"∀ a : α, β a"}</code></li>
      <li ><code>{"(a : A) -> B a"}</code>, for <code>(a : α) → β a</code></li>
      <li><code>{"A -> B"}</code>, for <code>α → β</code></li>
      </ul>
      <p class="leading-relaxed text-[var(--muted-text-color)] mb-4">Note that despite not itself being a function, <code>(→)</code> is available as infix notation for
      <code>{"fun α β, α → β"}</code>.</p>
      -- TODO: instances for pi types
    </main>

end DocGen4.Output
