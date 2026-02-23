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
        heading.className = "module_kind_heading";
        heading.id = `_decl_kind_${kind}`;
        heading.textContent = `${kindLabel(kind)} (${declarations.length})`;
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
          groupedLinks.push(...links);
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

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", initModuleViewToggle, { once: true });
  } else {
    initModuleViewToggle();
  }
})();
