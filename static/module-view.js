/**
 * Toggle module declaration rendering between declaration order and kind groups.
 */

(function () {
  const ORDER_QUERY_PARAM = "decl-order";
  const ORDER_DECLARATION = "declaration";
  const ORDER_KIND = "kind";

  const KNOWN_KINDS = ["theorem", "def", "inductive", "structure", "class", "instance", "axiom", "opaque", "ctor", "other"];

  const KIND_LABELS = {
    theorem: "Theorems",
    def: "Definitions",
    inductive: "Inductives",
    structure: "Structures",
    class: "Classes",
    instance: "Instances",
    axiom: "Axioms",
    opaque: "Opaque Declarations",
    ctor: "Constructors",
    other: "Other Declarations",
  };

  function initModuleViewToggle() {
    const main = document.querySelector("main");
    const sourceButton = document.getElementById("module_view_source");
    const kindButton = document.getElementById("module_view_kind");
    if (!(main instanceof HTMLElement) || !(sourceButton instanceof HTMLButtonElement) || !(kindButton instanceof HTMLButtonElement)) {
      return;
    }

    const originalMainChildren = Array.from(main.children);
    const declarationNodes = originalMainChildren.filter(isDeclaration);
    if (declarationNodes.length === 0) {
      return;
    }

    const preDeclarationNodes = [];
    const postDeclarationNodes = [];
    let seenDeclaration = false;
    for (const node of originalMainChildren) {
      if (isDeclaration(node)) {
        seenDeclaration = true;
        continue;
      }
      if (seenDeclaration) {
        postDeclarationNodes.push(node);
      } else {
        preDeclarationNodes.push(node);
      }
    }

    const declarationKinds = new Map();
    for (const decl of declarationNodes) {
      declarationKinds.set(decl, declarationKind(decl));
    }

    const declarationsByKind = groupByKind(declarationNodes, (decl) => declarationKinds.get(decl) || "other");
    const internalNavDecls = document.querySelector(".internal_nav_decls");
    const originalNavLinks =
      internalNavDecls instanceof HTMLElement
        ? Array.from(internalNavDecls.children).filter(
            (node) => node instanceof HTMLElement && node.classList.contains("nav_link")
          )
        : [];
    const navLinksByKind = groupByKind(originalNavLinks, navLinkKind);
    const orderedKinds = kindsInOrder(declarationsByKind, navLinksByKind);

    let currentOrder = parseOrderFromLocation();
    render(currentOrder, false);

    sourceButton.addEventListener("click", () => {
      if (currentOrder !== ORDER_DECLARATION) {
        currentOrder = ORDER_DECLARATION;
        render(currentOrder, true);
      }
    });

    kindButton.addEventListener("click", () => {
      if (currentOrder !== ORDER_KIND) {
        currentOrder = ORDER_KIND;
        render(currentOrder, true);
      }
    });

    window.addEventListener("popstate", () => {
      const order = parseOrderFromLocation();
      if (order !== currentOrder) {
        currentOrder = order;
        render(currentOrder, false);
      }
    });

    function render(order, updateUrl) {
      if (order === ORDER_KIND) {
        renderKindGrouped();
      } else {
        renderDeclarationOrder();
      }
      renderNav(order);
      setButtonState(order);
      if (updateUrl) {
        updateLocation(order);
      }
    }

    function renderDeclarationOrder() {
      replaceElementChildren(main, originalMainChildren);
    }

    function getKindColorClass(kind) {
      switch (kind) {
        case "def":
        case "instance":
          return "text-blue-500 dark:text-blue-400";
        case "theorem":
          return "text-purple-500 dark:text-purple-400";
        case "axiom":
        case "opaque":
          return "text-teal-500 dark:text-teal-400";
        case "structure":
        case "inductive":
        case "class":
          return "text-yellow-600 dark:text-yellow-500";
        default:
          return "text-neutral-500 dark:text-neutral-400";
      }
    }

    function renderKindGrouped() {
      replaceElementChildren(main, preDeclarationNodes);
      for (const kind of orderedKinds) {
        const declarations = declarationsByKind.get(kind);
        if (!declarations || declarations.length === 0) {
          continue;
        }
        const section = document.createElement("section");
        section.className = "module_kind_section";
        section.setAttribute("data-kind", kind);

        const heading = document.createElement("h2");
        heading.className = "text-xs uppercase tracking-widest mt-12 mb-6 flex items-baseline gap-2";
        heading.id = `_decl_kind_${kind}`;
        
        const labelSpan = document.createElement("span");
        labelSpan.className = getKindColorClass(kind);
        labelSpan.textContent = kindLabel(kind);
        
        const countSpan = document.createElement("span");
        countSpan.className = "text-[var(--muted-text-color)] font-normal";
        countSpan.textContent = `(${declarations.length})`;

        heading.appendChild(labelSpan);
        heading.appendChild(countSpan);
        
        section.appendChild(heading);

        for (const decl of declarations) {
          section.appendChild(decl);
        }

        main.appendChild(section);
      }

      for (const node of postDeclarationNodes) {
        main.appendChild(node);
      }
    }

    function renderNav(order) {
      if (!(internalNavDecls instanceof HTMLElement) || originalNavLinks.length === 0) {
        return;
      }
      if (order !== ORDER_KIND) {
        replaceElementChildren(internalNavDecls, originalNavLinks);
        return;
      }

      const groupedLinks = [];
      for (const kind of orderedKinds) {
        const links = navLinksByKind.get(kind);
        if (links && links.length > 0) {
          const details = document.createElement("details");
          details.className = "mb-3 group";
          details.open = true;

          const summary = document.createElement("summary");
          summary.className = "w-full cursor-pointer font-bold uppercase tracking-widest text-[10px] mb-2 flex justify-between items-center list-none [&::-webkit-details-marker]:hidden";
          
          const labelSpan = document.createElement("span");
          labelSpan.className = getKindColorClass(kind);
          labelSpan.textContent = kindLabel(kind);
          summary.appendChild(labelSpan);
          
          const svgHtml = '<svg class="chevron w-4 h-4 text-[var(--muted-text-color)] " fill="none" stroke="currentColor" viewBox="0 0 24 24" xmlns="http://www.w3.org/2000/svg"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7"></path></svg>';
          summary.insertAdjacentHTML('beforeend', svgHtml);
          
          details.appendChild(summary);

          const ul = document.createElement("ul");
          ul.className = "list-none p-0 pl-2 m-0 border-l border-[var(--border-color)]";
          for (const link of links) {
            ul.appendChild(link);
          }
          details.appendChild(ul);
          
          groupedLinks.push(details);
        }
      }
      replaceElementChildren(internalNavDecls, groupedLinks);
    }

    function setButtonState(order) {
      const sourceActive = order !== ORDER_KIND;
      sourceButton.classList.toggle("is-active", sourceActive);
      kindButton.classList.toggle("is-active", !sourceActive);
      sourceButton.setAttribute("aria-pressed", sourceActive ? "true" : "false");
      kindButton.setAttribute("aria-pressed", sourceActive ? "false" : "true");
    }

    function navLinkKind(navLink) {
      const link = navLink.querySelector("a");
      if (!(link instanceof HTMLAnchorElement)) {
        return "other";
      }
      const href = link.getAttribute("href");
      if (!href || !href.startsWith("#")) {
        return "other";
      }
      const target = document.getElementById(href.slice(1));
      if (!isDeclaration(target)) {
        return "other";
      }
      return declarationKinds.get(target) || "other";
    }
  }

  function isDeclaration(node) {
    return node instanceof HTMLElement && node.classList.contains("decl");
  }

  function declarationKind(declNode) {
    const container = declNode.firstElementChild;
    if (!(container instanceof HTMLElement)) {
      return "other";
    }
    for (const kind of KNOWN_KINDS) {
      if (kind !== "other" && container.classList.contains(kind)) {
        return kind;
      }
    }
    return "other";
  }

  function groupByKind(items, kindFn) {
    const grouped = new Map();
    for (const item of items) {
      const kind = kindFn(item);
      const existing = grouped.get(kind);
      if (existing) {
        existing.push(item);
      } else {
        grouped.set(kind, [item]);
      }
    }
    return grouped;
  }

  function kindsInOrder(...groupedMaps) {
    const kinds = new Set();
    for (const grouped of groupedMaps) {
      for (const key of grouped.keys()) {
        kinds.add(key);
      }
    }
    const known = KNOWN_KINDS.filter((kind) => kinds.has(kind));
    const unknown = Array.from(kinds)
      .filter((kind) => !KNOWN_KINDS.includes(kind))
      .sort((a, b) => a.localeCompare(b));
    return [...known, ...unknown];
  }

  function kindLabel(kind) {
    if (Object.prototype.hasOwnProperty.call(KIND_LABELS, kind)) {
      return KIND_LABELS[kind];
    }
    return kind;
  }

  function parseOrderFromLocation() {
    const order = new URL(window.location.href).searchParams.get(ORDER_QUERY_PARAM);
    if (order === ORDER_KIND) {
      return ORDER_KIND;
    }
    return ORDER_DECLARATION;
  }

  function updateLocation(order) {
    const url = new URL(window.location.href);
    if (order === ORDER_KIND) {
      url.searchParams.set(ORDER_QUERY_PARAM, ORDER_KIND);
    } else {
      url.searchParams.delete(ORDER_QUERY_PARAM);
    }
    try {
      window.history.replaceState(null, "", `${url.pathname}${url.search}${url.hash}`);
    } catch (_err) {
      // Keep rendering behavior even if URL rewriting is unavailable.
    }
  }

  function replaceElementChildren(parent, children) {
    while (parent.firstChild) {
      parent.removeChild(parent.firstChild);
    }
    for (const child of children) {
      parent.appendChild(child);
    }
  }

  function initScrollSpy() {
    let activeLink = null;

    function onScroll() {
      // Re-query links dynamically in case order changed
      const navLinks = Array.from(document.querySelectorAll('.internal_nav a[href^="#"]')).filter(
        link => link.getAttribute('href') !== '#top'
      );
      if (navLinks.length === 0) return;

      const targetElements = navLinks
        .map(link => {
          try {
            const id = link.getAttribute('href').slice(1);
            return document.getElementById(id);
          } catch {
            return null;
          }
        })
        .filter(Boolean);

      if (targetElements.length === 0) return;

      let closestDecl = null;
      let minDistance = -Infinity; // Distance from the ideal trigger line (e.g. top third)
      const triggerLine = window.innerHeight / 3;

      for (const el of targetElements) {
        const rect = el.getBoundingClientRect();
        // We only consider elements whose top is above the trigger line
        if (rect.top <= triggerLine) {
          if (rect.top > minDistance) {
            minDistance = rect.top;
            closestDecl = el;
          }
        }
      }

      // If nothing is above the trigger line, default to the first element
      if (!closestDecl && targetElements.length > 0) {
        closestDecl = targetElements[0];
        let minTop = Infinity;
        for (const el of targetElements) {
          const top = el.getBoundingClientRect().top;
          if (top < minTop) {
            minTop = top;
            closestDecl = el;
          }
        }
      }

      if (closestDecl) {
        const id = closestDecl.id;
        const correspondingLink = navLinks.find(link => link.getAttribute('href') === '#' + id);
        if (correspondingLink && correspondingLink !== activeLink) {
          if (activeLink) {
            activeLink.classList.remove('font-bold', 'bg-blue-50', 'dark:bg-blue-900/50', 'px-2', 'py-1', 'rounded', 'block', 'text-blue-800', 'dark:text-blue-200', '-ml-2');
            activeLink.classList.add('text-blue-600', 'dark:text-blue-400');
          }
          correspondingLink.classList.remove('text-blue-600', 'dark:text-blue-400');
          correspondingLink.classList.add('font-bold', 'bg-blue-50', 'dark:bg-blue-900/50', 'px-2', 'py-1', 'rounded', 'block', 'text-blue-800', 'dark:text-blue-200', '-ml-2');
          activeLink = correspondingLink;
          
          const navContainer = correspondingLink.closest('.internal_nav');
          if (navContainer) {
            const linkRect = correspondingLink.getBoundingClientRect();
            const navRect = navContainer.getBoundingClientRect();
            if (linkRect.top < navRect.top || linkRect.bottom > navRect.bottom) {
              correspondingLink.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
            }
          }
        }
      }
    }

    window.addEventListener('scroll', onScroll, { passive: true });
    document.getElementById("module_view_source")?.addEventListener("click", () => setTimeout(onScroll, 50));
    document.getElementById("module_view_kind")?.addEventListener("click", () => setTimeout(onScroll, 50));
    onScroll();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", () => {
      initModuleViewToggle();
      initScrollSpy();
    }, { once: true });
  } else {
    initModuleViewToggle();
    initScrollSpy();
  }
})();
