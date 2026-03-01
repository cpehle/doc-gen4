/-
Copyright (c) 2021 Henrik Böving. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving
-/
import DocGen4.Output.ToHtmlFormat
import DocGen4.Output.Navbar

namespace DocGen4
namespace Output

open scoped DocGen4.Jsx

/--
The HTML template used for all pages.
-/
def baseHtmlGenerator (title : String) (site : Array Html) : BaseHtmlM Html := do
  let moduleConstant :=
    if let some module := ← getCurrentName then
      #[<script>{.raw s!"const MODULE_NAME={String.quote module.toString};"}</script>]
    else
      #[]
  pure
    <html lang="en">
      <head>
        [← baseHtmlHeadDeclarations]

        <title>{title}</title>
        <script>{.raw "(function(){try{var t=localStorage.getItem('theme')||'system';if(t==='system')t=matchMedia('(prefers-color-scheme:dark)').matches?'dark':'light';document.documentElement.setAttribute('data-theme',t)}catch(e){}})()"}</script>
        <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.css"/>
        <script defer="true" src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/katex.min.js"></script>
        <script defer="true" src="https://cdn.jsdelivr.net/npm/katex@0.16/dist/contrib/auto-render.min.js"></script>
        <script defer="true" src={s!"{← getRoot}katex-config.js"}></script>

        <script>{.raw s!"const SITE_ROOT={String.quote (← getRoot)};"}</script>
        [moduleConstant]
        <script type="module" src={s!"{← getRoot}jump-src.js"}></script>
        <script type="module" src={s!"{← getRoot}search.js"}></script>
        <script type="module" src={s!"{← getRoot}shiki.js"}></script>
        <script type="module" src={s!"{← getRoot}how-about.js"}></script>
        <script type="module" src={s!"{← getRoot}instances.js"}></script>
        <script type="module" src={s!"{← getRoot}importedBy.js"}></script>
        <script type="module" src={s!"{← getRoot}nav.js"}></script>
        <script type="module" src={s!"{← getRoot}module-view.js"}></script>
        <script type="module" src={s!"{← getRoot}color-scheme.js"}></script>
      </head>

      <body>
                        <input id="nav_toggle" type="checkbox" class="hidden"/>
                
                        <header class="fixed top-0 left-0 right-0 z-50 flex items-center px-4 border-b bg-[var(--body-bg)] text-[var(--text-color)] border-[var(--border-color)]" style="height: 2.9rem;">
                          <label for="nav_toggle" class="xl:hidden mr-4 p-1 flex-shrink-0 rounded-sm hover:bg-neutral-100 dark:hover:bg-neutral-800 cursor-pointer text-[var(--muted-text-color)]">
                            {.raw "<svg class=\"w-6 h-6\" fill=\"none\" stroke=\"currentColor\" viewBox=\"0 0 24 24\"><path stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"M4 6h16M4 12h16M4 18h16\"></path></svg>"}
                          </label>
                
                  <h1 class="flex items-center text-xs font-medium uppercase tracking-wider m-0 mr-4 sm:mr-6 flex-shrink-0 text-[var(--muted-text-color)]"><span class="hidden sm:inline">Documentation</span></h1>
                  <h2 class="flex-auto text-sm font-medium m-0 truncate text-[var(--text-color)] font-mono">[breakWithin title]</h2>
                                  <button id="theme-toggle" class="ml-auto mr-2 sm:mr-4 flex items-center justify-center w-8 h-8 flex-shrink-0 rounded-sm text-[var(--muted-text-color)] hover:text-[var(--text-color)] border border-[var(--border-color)] bg-[var(--panel-bg)] hover:bg-[var(--code-bg)] transition-colors focus:outline-none" title="Toggle dark mode (⌘T)">
                            {.raw "<svg id=\"theme-toggle-dark-icon\" class=\"hidden w-4 h-4\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><path d=\"M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z\"></path></svg>"}
                            {.raw "<svg id=\"theme-toggle-light-icon\" class=\"hidden w-4 h-4\" fill=\"none\" viewBox=\"0 0 24 24\" stroke=\"currentColor\" stroke-width=\"2\" stroke-linecap=\"round\" stroke-linejoin=\"round\"><circle cx=\"12\" cy=\"12\" r=\"5\"></circle><line x1=\"12\" y1=\"1\" x2=\"12\" y2=\"3\"></line><line x1=\"12\" y1=\"21\" x2=\"12\" y2=\"23\"></line><line x1=\"4.22\" y1=\"4.22\" x2=\"5.64\" y2=\"5.64\"></line><line x1=\"18.36\" y1=\"18.36\" x2=\"19.78\" y2=\"19.78\"></line><line x1=\"1\" y1=\"12\" x2=\"3\" y2=\"12\"></line><line x1=\"21\" y1=\"12\" x2=\"23\" y2=\"12\"></line><line x1=\"4.22\" y1=\"19.78\" x2=\"5.64\" y2=\"18.36\"></line><line x1=\"18.36\" y1=\"5.64\" x2=\"19.78\" y2=\"4.22\"></line></svg>"}
                          </button>

                          <button id="search_trigger" class="relative flex-shrink-0 flex items-center justify-center sm:justify-start w-8 h-8 sm:w-64 pl-0 sm:pl-10 pr-0 sm:pr-12 text-sm rounded-sm border border-[var(--border-color)] bg-[var(--panel-bg)] hover:bg-[var(--code-bg)] hover:text-[var(--text-color)] text-[var(--muted-text-color)] transition-colors text-left focus:outline-none">
                            <div class="sm:absolute inset-y-0 left-0 flex items-center sm:pl-3 pointer-events-none">
                              {.raw "<svg class=\"w-4 h-4\" aria-hidden=\"true\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 20 20\"><path stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"m19 19-4-4m0-7A7 7 0 1 1 1 8a7 7 0 0 1 14 0Z\"/></svg>"}
                            </div>
                            <span class="hidden sm:inline">Search...</span>
                            <div class="hidden sm:flex absolute inset-y-0 right-0 items-center pr-2 pointer-events-none">
                              <span class="text-[10px] font-medium font-sans border border-[var(--border-color)] bg-[var(--body-bg)] text-[var(--muted-text-color)] rounded-sm px-1.5 py-0.5 shadow-sm">{.raw "⌘K"}</span>
                            </div>
                          </button>
                        </header>
                
                        <div id="search_modal" class="fixed inset-0 z-[100] hidden bg-neutral-900/50 dark:bg-black/50 backdrop-blur-[2px] p-0 sm:p-6 md:p-[10vh]">
                          <div class="mx-auto w-full max-w-2xl bg-[var(--body-bg)] text-[var(--text-color)] sm:rounded-sm shadow-2xl flex flex-col overflow-hidden border border-[var(--border-color)] h-full sm:h-auto sm:max-h-[80vh]">
                            <form id="search_form" class="relative flex items-center m-0 border-b border-[var(--border-color)] flex-shrink-0" onsubmit="event.preventDefault();">
                              <div class="absolute inset-y-0 left-0 flex items-center pl-4 pointer-events-none">
                                {.raw "<svg class=\"w-5 h-5 text-[var(--muted-text-color)]\" aria-hidden=\"true\" xmlns=\"http://www.w3.org/2000/svg\" fill=\"none\" viewBox=\"0 0 20 20\"><path stroke=\"currentColor\" stroke-linecap=\"round\" stroke-linejoin=\"round\" stroke-width=\"2\" d=\"m19 19-4-4m0-7A7 7 0 1 1 1 8a7 7 0 0 1 14 0Z\"/></svg>"}
                              </div>
                              <input class="w-full bg-transparent pl-12 pr-4 py-4 text-[var(--text-color)] text-lg focus:outline-none placeholder-neutral-400 dark:placeholder-neutral-500" type="text" name="q" autocomplete="off" placeholder="Search declarations..."/>
                            </form>
                            <div id="autocomplete_results" class="overflow-auto flex-auto bg-[var(--body-bg)] text-[var(--text-color)]"></div>
                          </div>
                        </div>

                        <div class="flex flex-col xl:flex-row pt-[2.9rem] min-h-screen bg-[var(--body-bg)] text-[var(--text-color)]">
                          <label for="nav_toggle" class="nav-overlay fixed inset-0 z-40 hidden bg-neutral-900/50 backdrop-blur-sm xl:hidden"></label>
                          {.raw "<!-- NAV_START --><nav class=\"nav\"></nav><!-- NAV_END -->"}
                          [site]
                        </div>
                      </body>
                    </html>

/--
A comfortability wrapper around `baseHtmlGenerator`.
-/
def baseHtml (title : String) (site : Html) : BaseHtmlM Html := baseHtmlGenerator title #[site]

end Output
end DocGen4
