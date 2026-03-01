/**
 * This module is used to implement persistent navbar expansion.
 */

// The variable to store the expansion information.
let expanded = {};

// Load expansion information from sessionStorage.
for (const e of (sessionStorage.getItem("expanded") || "").split(",")) {
  if (e !== "") {
    expanded[e] = true;
  }
}

/**
 * Save expansion information to sessionStorage.
 */
function saveExpanded() {
  sessionStorage.setItem(
    "expanded",
    Object.getOwnPropertyNames(expanded)
      .filter((e) => expanded[e])
      .join(",")
  );
}

// save expansion information when user change the expansion.
for (const elem of document.getElementsByClassName("nav_sect")) {
  const id = elem.getAttribute("data-path");
  if (!id) continue;
  if (expanded[id]) {
    elem.open = true;
  }
  const firstChild = elem.firstElementChild;
  const summary =
    firstChild instanceof HTMLElement && firstChild.classList.contains("nav_summary")
      ? firstChild
      : null;
  const toggleButton = summary && summary.querySelector(".nav_toggle_button");
  const labelLink = summary && summary.querySelector(".nav_label_link");
  if (summary) {
    summary.addEventListener("click", (event) => {
      const target = event.target instanceof Element ? event.target : null;
      if (target && target.closest(".nav_label_text")) {
        event.preventDefault();
        elem.open = true;
        return;
      }
      // Disable native summary toggling; we use explicit controls below.
      event.preventDefault();
    });
    summary.addEventListener("keydown", (event) => {
      // Toggle is handled by the explicit button, not the summary itself.
      if (event.key === "Enter" || event.key === " ") {
        event.preventDefault();
      }
    });
  }
  if (toggleButton) {
    toggleButton.addEventListener("click", (event) => {
      event.preventDefault();
      event.stopPropagation();
      elem.open = !elem.open;
    });
  }
  if (labelLink) {
    // Expand first, then navigate via the label's default anchor behavior.
    labelLink.addEventListener("click", (event) => {
      event.stopPropagation();
      elem.open = true;
      expanded[id] = true;
      saveExpanded();
    });
  }
  if (toggleButton) {
    setToggleExpanded(toggleButton, elem.open);
  }
  elem.addEventListener("toggle", () => {
    expanded[id] = elem.open;
    saveExpanded();
    if (toggleButton) {
      setToggleExpanded(toggleButton, elem.open);
    }
  });
}

function setToggleExpanded(button, isOpen) {
  button.setAttribute("aria-expanded", isOpen ? "true" : "false");
}

// Global copy-to-clipboard functionality
document.addEventListener("click", (event) => {
  const btn = event.target.closest(".copy_decl_btn, .copy_code_block_btn, #copy-page-btn");
  if (!btn) return;

  const originalHtml = btn.innerHTML;
  
  const showSuccess = () => {
    btn.innerHTML = '<svg class="w-4 h-4 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><polyline points="20 6 9 17 4 12"></polyline></svg>';
    setTimeout(() => {
      btn.innerHTML = originalHtml;
    }, 2000);
  };

  let textPromise;

  if (btn.classList.contains("copy_decl_btn")) {
    textPromise = Promise.resolve(btn.getAttribute("data-name") || "");
  } else if (btn.classList.contains("copy_code_block_btn")) {
    const pre = btn.parentElement.querySelector("pre");
    textPromise = Promise.resolve(pre ? pre.innerText : "");
  } else if (btn.id === "copy-page-btn") {
    const mdUrl = window.location.pathname.replace(/\.html$/, ".md");
    textPromise = fetch(mdUrl).then(response => {
      if (response.ok) return response.text();
      throw new Error("Markdown not found");
    }).catch(() => {
      const mainContent = document.querySelector("main");
      return mainContent ? mainContent.innerText : document.body.innerText;
    });
  }

  if (textPromise) {
    if (navigator.clipboard && window.ClipboardItem) {
      // Create the ClipboardItem synchronously before the async execution yields,
      // which preserves the user gesture for strict browsers like Safari.
      const blobPromise = textPromise.then(text => new Blob([text], { type: "text/plain" }));
      const item = new ClipboardItem({ "text/plain": blobPromise });
      navigator.clipboard.write([item])
        .then(showSuccess)
        .catch(err => {
          console.error("ClipboardItem write failed, falling back to writeText: ", err);
          textPromise.then(text => navigator.clipboard.writeText(text)).then(showSuccess).catch(e => console.error(e));
        });
    } else {
      textPromise
        .then(text => navigator.clipboard.writeText(text))
        .then(showSuccess)
        .catch(err => console.error("Failed to copy: ", err));
    }
  }
});

// Scroll the nav sidebar so the current page link is visible
// without disturbing the main document's scroll position.
for (const currentFileLink of document.getElementsByClassName("visible")) {
  const nav = currentFileLink.closest("nav");
  if (nav) {
    const navRect = nav.getBoundingClientRect();
    const linkRect = currentFileLink.getBoundingClientRect();
    const offset = linkRect.top - navRect.top - navRect.height / 2;
    nav.scrollTop += offset;
  }
}
