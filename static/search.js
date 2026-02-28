/**
 * This module is used to handle user's interaction with the search form.
 */

import { DeclarationDataCenter } from "./declaration-data.js";

// Modal elements
const SEARCH_TRIGGER = document.querySelector("#search_trigger");
const SEARCH_MODAL = document.querySelector("#search_modal");
const SEARCH_FORM = document.querySelector("#search_form");
const SEARCH_INPUT = SEARCH_FORM ? SEARCH_FORM.querySelector("input[name=q]") : null;
const AC_RESULTS = document.querySelector("#autocomplete_results");

// Search form on the /search.html_page.  These may be null.
const SEARCH_PAGE_INPUT = document.querySelector("#search_page_query")
const SEARCH_RESULTS = document.querySelector("#search_results")

// Max results to show for autocomplete or /search.html page.
const AC_MAX_RESULTS = 30
const SEARCH_PAGE_MAX_RESULTS = undefined

// Search results are sorted into blocks for better performance; this determines the number of search results per block.
// Must be positive, may be infinite.
const RESULTS_PER_BLOCK = 50

const RECENT_SEARCHES_KEY = "docgen4_recent_searches";

function saveRecentSearch(resultItem) {
  let recent = [];
  try {
    const stored = localStorage.getItem(RECENT_SEARCHES_KEY);
    if (stored) recent = JSON.parse(stored);
  } catch (e) {}

  recent = recent.filter(item => item.name !== resultItem.name || item.kind !== resultItem.kind);

  recent.unshift({
    name: resultItem.name,
    kind: resultItem.kind,
    docLink: resultItem.docLink,
    previewText: resultItem.previewText,
    typeSig: resultItem.typeSig
  });

  if (recent.length > 5) recent = recent.slice(0, 5);

  try {
    localStorage.setItem(RECENT_SEARCHES_KEY, JSON.stringify(recent));
  } catch (e) {}
}

function renderRecentSearches(sr, dataCenter) {
  let recent = [];
  try {
    const stored = localStorage.getItem(RECENT_SEARCHES_KEY);
    if (stored) recent = JSON.parse(stored);
  } catch (e) {}

  if (recent.length === 0) {
    sr.classList.add("hidden");
    return;
  }

  sr.classList.remove("hidden");
  
  const header = document.createElement("div");
  header.className = "px-4 py-2 text-[10px] font-bold uppercase tracking-widest text-[var(--muted-text-color)] bg-neutral-50/50 dark:bg-neutral-800/50 border-b border-[var(--border-color)]";
  header.textContent = "Recent";
  sr.appendChild(header);

  const innerBlock = sr.appendChild(document.createElement("div"));
  innerBlock.classList.add("flex", "flex-col", "w-full");

  for (const item of recent) {
    renderSearchResultRow(item, innerBlock, true, dataCenter);
  }
}

/**
 * Open and close search modal
 */
function openSearch() {
  if (SEARCH_MODAL) {
    SEARCH_MODAL.classList.remove("hidden");
    SEARCH_MODAL.classList.add("flex");
    if (SEARCH_INPUT) {
      SEARCH_INPUT.focus();
      // Trigger input event to show recents if empty
      SEARCH_INPUT.dispatchEvent(new Event("input"));
    }
    document.body.style.overflow = "hidden"; // Prevent background scrolling
  }
}

function closeSearch() {
  if (SEARCH_MODAL) {
    SEARCH_MODAL.classList.add("hidden");
    SEARCH_MODAL.classList.remove("flex");
    if (SEARCH_INPUT) SEARCH_INPUT.blur();
    document.body.style.overflow = "";
  }
}

if (SEARCH_TRIGGER) {
  SEARCH_TRIGGER.addEventListener("click", openSearch);
}

if (SEARCH_MODAL) {
  // Close when clicking outside the modal content
  SEARCH_MODAL.addEventListener("click", (ev) => {
    if (ev.target === SEARCH_MODAL) {
      closeSearch();
    }
  });
}

/**
 * Global shortcut to focus the search box (Cmd+K, Ctrl+K, or /)
 */
document.addEventListener("keydown", (ev) => {
  if (
    ((ev.metaKey || ev.ctrlKey) && ev.key.toLowerCase() === 'k') ||
    (ev.key === '/' && document.activeElement !== SEARCH_INPUT && !['INPUT', 'TEXTAREA'].includes(document.activeElement.tagName))
  ) {
    ev.preventDefault();
    openSearch();
  } else if (ev.key === 'Escape') {
    closeSearch();
  }
});

/**
 * Attach `selected` class to the the selected autocomplete result.
 */
function handleSearchCursorUpDown(down) {
  if (!AC_RESULTS) return;
  const sel = AC_RESULTS.querySelector(`.selected`);
  const results = [...AC_RESULTS.getElementsByClassName("search_result")];
  if (results.length === 0) return;
  const selIndex = results.indexOf(sel);
  let toSelect;
  if (sel) {
    sel.classList.remove("selected", "bg-neutral-100", "dark:bg-neutral-800");
    toSelect = results[down ? selIndex + 1 : selIndex - 1];
  } else {
    toSelect = down ? results[0] : results[results.length-1];
  }
  if (toSelect){
    toSelect.classList.add("selected", "bg-neutral-100", "dark:bg-neutral-800");
    toSelect.scrollIntoView({block:"nearest"});
  }
}

/**
 * Perform search (when enter is pressed).
 */
function handleSearchEnter() {
  if (!AC_RESULTS) return;
  const sel = AC_RESULTS.querySelector(`.selected .result_link a`) || AC_RESULTS.querySelector(`.search_result .result_link a`);
  if (sel) {
    sel.click();
  }
}

/**
 * Allow user to navigate autocomplete results with up/down arrow keys, and choose with enter.
 */
if (SEARCH_INPUT) {
  SEARCH_INPUT.addEventListener("keydown", (ev) => {
    switch (ev.key) {
      case "Down":
      case "ArrowDown":
        ev.preventDefault();
        handleSearchCursorUpDown(true);
        break;
      case "Up":
      case "ArrowUp":
        ev.preventDefault();
        handleSearchCursorUpDown(false);
        break;
      case "Enter":
        ev.preventDefault();
        handleSearchEnter();
        break;
    }
  });
}

/**
 * Remove all children of a DOM node.
 */
function removeAllChildren(node) {
  while (node.firstChild) {
    node.removeChild(node.lastChild);
  }
}

/**
 * Filter search results to a single kind by updating the checkboxes and re-triggering the search.
 * Clicking the same kind again resets all checkboxes to checked.
 */
function filterToKind(kind) {
  const checkboxes = document.querySelectorAll(".kind_checkbox");
  const alreadySolo = Array.from(checkboxes).every(cb => cb.value === kind ? cb.checked : !cb.checked);
  checkboxes.forEach(cb => { cb.checked = alreadySolo || cb.value === kind; });
  if (SEARCH_PAGE_INPUT) SEARCH_PAGE_INPUT.dispatchEvent(new Event("input"));
}

/**
 * Render a structured type signature as a DocumentFragment.
 * `typeSig` is a JSON array of segments, each either:
 *   - a string for plain text
 *   - ["text", "DeclName"] for text that links to a declaration
 */
function renderTypeSig(typeSig, declarations) {
  const frag = document.createDocumentFragment();
  if (!Array.isArray(typeSig)) {
    frag.appendChild(document.createTextNode(String(typeSig)));
    return frag;
  }
  for (const seg of typeSig) {
    if (typeof seg === "string") {
      frag.appendChild(document.createTextNode(seg));
    } else if (Array.isArray(seg) && seg.length >= 2 && seg[1] != null) {
      const a = document.createElement("a");
      const decl = declarations && declarations[seg[1]];
      if (decl) {
        a.href = SITE_ROOT + decl.docLink;
      }
      a.textContent = seg[0];
      a.classList.add("result_type_link", "text-neutral-500", "dark:text-neutral-400", "hover:underline");
      frag.appendChild(a);
    } else if (Array.isArray(seg) && seg.length >= 1) {
      frag.appendChild(document.createTextNode(seg[0]));
    }
  }
  return frag;
}

function renderSearchResultRow(item, container, autocomplete, dataCenter) {
  const row = container.appendChild(document.createElement("div"));
  row.classList.add("search_result", "flex", "items-center", "px-4", "py-3", "border-b", "border-neutral-100", "dark:border-neutral-800", "hover:bg-neutral-50", "dark:hover:bg-neutral-800/50", "transition-colors", "cursor-pointer");
  
  const linkdiv = row.appendChild(document.createElement("div"))
  linkdiv.classList.add("result_link", "flex", "items-start", "w-full", "min-w-0");
  
  const kindSpan = linkdiv.appendChild(document.createElement("span"));
  kindSpan.classList.add("result_kind", "flex-shrink-0", "w-20", "mr-3", "mt-0.5", "px-1", "py-0.5", "border", "border-neutral-200", "dark:border-neutral-700", "bg-neutral-50", "dark:bg-neutral-800", "text-[0.65rem]", "font-bold", "tracking-wider", "uppercase", "text-center", "text-neutral-500", "dark:text-neutral-400", "rounded", "hover:border-neutral-400", "dark:hover:border-neutral-500", "hover:text-neutral-900", "dark:hover:text-neutral-100");
  kindSpan.textContent = item.kind;
  kindSpan.dataset.kind = item.kind;
  if (SEARCH_PAGE_INPUT) {
    kindSpan.addEventListener("click", (ev) => {
      ev.preventDefault();
      ev.stopPropagation();
      filterToKind(ev.target.dataset.kind);
    });
  }

  const textContainer = linkdiv.appendChild(document.createElement("div"));
  textContainer.classList.add("flex", "flex-col", "min-w-0", "w-full");
  
  const link = textContainer.appendChild(document.createElement("a"));
  link.classList.add("truncate", "w-full");
  link.href = SITE_ROOT + item.docLink;
  
  link.addEventListener("click", () => {
    saveRecentSearch(item);
  });
  
  const nameSpan = link.appendChild(document.createElement("span"));
  nameSpan.classList.add("result_name", "text-neutral-900", "dark:text-neutral-100", "font-mono", "text-sm", "font-semibold", "hover:text-blue-600", "dark:hover:text-blue-400");
  nameSpan.textContent = item.name;
  link.title = item.name;
  
  // Right side: Type Signature (truncated gracefully)
  if (item.typeSig) {
    const sigSpan = textContainer.appendChild(document.createElement("span"));
    sigSpan.classList.add("result_type", "text-neutral-500", "dark:text-neutral-400", "text-xs", "font-mono", "truncate", "opacity-75", "mt-0.5");
    if (!autocomplete && dataCenter) {
      sigSpan.appendChild(renderTypeSig(item.typeSig, dataCenter.declarationData.declarations));
    } else {
      sigSpan.appendChild(renderTypeSig(item.typeSig, {}));
    }
  } else if (item.previewText) {
    const previewSpan = textContainer.appendChild(document.createElement("span"));
    previewSpan.classList.add("result_preview", "text-neutral-500", "dark:text-neutral-400", "text-xs", "truncate", "opacity-75", "mt-0.5");
    previewSpan.textContent = item.previewText;
  }
}

// counts how often `handleSearch` has already been called. Used to terminate the previous call whenever a new one has started.
var handleSearchCounter = 0;

/**
 * Handle user input and perform search.
 */
async function handleSearch(dataCenter, err, ev, sr, maxResults, autocomplete) {
  const text = ev.target.value;
  const callIndex = ++handleSearchCounter;

  if (!sr) return;

  // If no input clear all and show recents.
  if (!text) {
    sr.removeAttribute("state");
    removeAllChildren(sr);
    if (autocomplete) {
      renderRecentSearches(sr, dataCenter);
    }
    return;
  }

  if (autocomplete) {
    sr.classList.remove("hidden");
  }

  // searching
  sr.setAttribute("state", "loading");

  if (dataCenter) {
    var allowedKinds;
    if (!autocomplete) {
      allowedKinds = new Set();
      document.querySelectorAll(".kind_checkbox").forEach((checkbox) =>
        {
          if (checkbox.checked) {
            allowedKinds.add(checkbox.value);
          }
        } 
      );
    }
    const result = dataCenter.search(text, false, allowedKinds, maxResults);

    // in case user has updated the input.
    if (ev.target.value != text) return;
  
    // update autocomplete results
    removeAllChildren(sr);
    for (let i = 0; i < result.length; i += RESULTS_PER_BLOCK) {
      const block = document.createElement("div");
      block.classList.add("search_result_block");
      const innerBlock = block.appendChild(document.createElement("div"));
      innerBlock.classList.add("search_result_block_inner", "flex", "flex-col", "w-full");
      for (let j = i; j < Math.min(result.length, i + RESULTS_PER_BLOCK); j++){
        renderSearchResultRow(result[j], innerBlock, autocomplete, dataCenter);
      }
      sr.appendChild(block);
      await new Promise(resolve=>setTimeout(resolve,0));
      if (handleSearchCounter!=callIndex) return;
    }
  }
  // handle error
  else {
    removeAllChildren(sr);
    const d = sr.appendChild(document.createElement("a"));
    d.classList.add("block", "p-4", "text-red-500");
    d.innerText = `Cannot fetch data, please check your network connection.\n${err}`;
  }
  sr.setAttribute("state", "done");
}

// https://www.joshwcomeau.com/snippets/javascript/debounce/
const debounce = (callback, wait) => {
  let timeoutId = null;
  return (...args) => {
    window.clearTimeout(timeoutId);
    timeoutId = window.setTimeout(() => {
      callback.apply(null, args);
    }, wait);
  };
}

// The debounce delay for the search. 90 ms is below the noticable input lag for me
const SEARCH_DEBOUNCE = 90;

DeclarationDataCenter.init()
  .then((dataCenter) => {
    // Search autocompletion.
    if (SEARCH_INPUT) {
      SEARCH_INPUT.addEventListener("input", debounce(ev => handleSearch(dataCenter, null, ev, AC_RESULTS, AC_MAX_RESULTS, true), SEARCH_DEBOUNCE));
      SEARCH_INPUT.dispatchEvent(new Event("input"))
    }
    if(SEARCH_PAGE_INPUT) {
      SEARCH_PAGE_INPUT.addEventListener("input", ev => handleSearch(dataCenter, null, ev, SEARCH_RESULTS, SEARCH_PAGE_MAX_RESULTS, false))
      document.querySelectorAll(".kind_checkbox").forEach((checkbox) =>
        checkbox.addEventListener("input", ev => SEARCH_PAGE_INPUT.dispatchEvent(new Event("input")))
      );
      SEARCH_PAGE_INPUT.dispatchEvent(new Event("input"))
    }
  })
  .catch(e => {
    if (SEARCH_INPUT) {
      SEARCH_INPUT.addEventListener("input", debounce(ev => handleSearch(null, e, ev, AC_RESULTS, AC_MAX_RESULTS, true), SEARCH_DEBOUNCE));
    }
    if(SEARCH_PAGE_INPUT) {
      SEARCH_PAGE_INPUT.addEventListener("input", ev => handleSearch(null, e, ev, SEARCH_RESULTS, SEARCH_PAGE_MAX_RESULTS, false));
    }
  });
