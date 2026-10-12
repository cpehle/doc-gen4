/* Per-snippet copy buttons: every fenced code block gets a hover button
   that copies its text, Observable-docs style. */
const COPY_ICON =
  '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path></svg>';
const CHECK_ICON =
  '<svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><polyline points="20 6 9 17 4 12"></polyline></svg>';

function decorate(pre) {
  if (pre.dataset.copyDecorated) return;
  pre.dataset.copyDecorated = "true";
  const button = document.createElement("button");
  button.className = "code-copy-button";
  button.type = "button";
  button.title = "Copy code";
  button.setAttribute("aria-label", "Copy code");
  button.innerHTML = COPY_ICON;
  button.addEventListener("click", async () => {
    const code = pre.querySelector("code");
    const text = (code ? code.innerText : pre.innerText).replace(/\n$/, "");
    try {
      await navigator.clipboard.writeText(text);
      button.innerHTML = CHECK_ICON;
      button.classList.add("copied");
      setTimeout(() => {
        button.innerHTML = COPY_ICON;
        button.classList.remove("copied");
      }, 1600);
    } catch (err) {
      console.error("copy failed", err);
    }
  });
  pre.classList.add("has-copy-button");
  pre.appendChild(button);
}

function decorateAll() {
  document.querySelectorAll("main pre").forEach(decorate);
}

if (document.readyState === "loading") {
  document.addEventListener("DOMContentLoaded", decorateAll);
} else {
  decorateAll();
}
/* Shiki may re-render highlighted blocks after load. */
new MutationObserver(decorateAll).observe(document.body, { childList: true, subtree: true });
