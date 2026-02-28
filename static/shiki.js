import {
  getDocGenHighlighter,
  SHIKI_THEME_DARK,
  SHIKI_THEME_LIGHT,
} from "./shiki-runtime.js";

const LANG_ALIASES = {
  lean4: "lean",
  bash: "shellscript",
  shell: "shellscript",
  sh: "shellscript",
  zsh: "shellscript",
  yml: "yaml",
  text: "plaintext",
  txt: "plaintext",
};

let highlighterPromise = null;

function currentTheme() {
  return document.documentElement.getAttribute("data-theme") === "dark"
    ? SHIKI_THEME_DARK
    : SHIKI_THEME_LIGHT;
}

function normalizeLang(raw) {
  const lang = (raw || "").toLowerCase();
  if (!lang) return "plaintext";
  return LANG_ALIASES[lang] || lang;
}

function languageFromCodeClass(code) {
  const cls = Array.from(code.classList).find((c) => c.startsWith("language-"));
  if (!cls) return null;
  return normalizeLang(cls.slice("language-".length));
}

function ensureBlockMetadata(pre) {
  if (pre.dataset.shikiSource && pre.dataset.shikiLang) {
    return true;
  }
  const code = pre.querySelector("code");
  if (!code) return false;
  const lang = languageFromCodeClass(code);
  if (!lang) return false;
  pre.dataset.shikiSource = code.textContent || "";
  pre.dataset.shikiLang = lang;
  return true;
}

function renderPreFromHtml(html) {
  const template = document.createElement("template");
  template.innerHTML = html.trim();
  return template.content.querySelector("pre");
}

async function getHighlighter() {
  if (!highlighterPromise) {
    highlighterPromise = getDocGenHighlighter();
  }
  return highlighterPromise;
}

async function highlightAllCodeBlocks() {
  let highlighter;
  try {
    highlighter = await getHighlighter();
  } catch (err) {
    console.warn("Shiki failed to load; keeping unhighlighted code blocks.", err);
    return;
  }

  const theme = currentTheme();
  const blocks = Array.from(document.querySelectorAll("pre")).filter(ensureBlockMetadata);

  for (const pre of blocks) {
    if (pre.dataset.shikiTheme === theme) continue;
    const source = pre.dataset.shikiSource || "";
    const lang = normalizeLang(pre.dataset.shikiLang || "txt");
    let renderedHtml;
    try {
      renderedHtml = highlighter.codeToHtml(source, { lang, theme });
    } catch {
      continue;
    }
    const renderedPre = renderPreFromHtml(renderedHtml);
    if (!renderedPre) continue;
    
    // Preserve original classes (like Tailwind utility classes)
    const originalClasses = Array.from(pre.classList);
    if (originalClasses.length > 0) {
      renderedPre.classList.add(...originalClasses);
    }
    
    renderedPre.dataset.shikiSource = source;
    renderedPre.dataset.shikiLang = lang;
    renderedPre.dataset.shikiTheme = theme;
    pre.replaceWith(renderedPre);
  }
}

let highlightScheduled = false;
function scheduleHighlight() {
  if (highlightScheduled) return;
  highlightScheduled = true;
  queueMicrotask(() => {
    highlightScheduled = false;
    void highlightAllCodeBlocks();
  });
}

document.addEventListener("DOMContentLoaded", scheduleHighlight);

const rootObserver = new MutationObserver((mutations) => {
  for (const mutation of mutations) {
    if (mutation.type === "attributes" && mutation.attributeName === "data-theme") {
      scheduleHighlight();
      return;
    }
    if (mutation.type === "childList" && (mutation.addedNodes.length > 0 || mutation.removedNodes.length > 0)) {
      scheduleHighlight();
      return;
    }
  }
});

rootObserver.observe(document.documentElement, {
  attributes: true,
  attributeFilter: ["data-theme"],
  childList: true,
  subtree: true,
});
