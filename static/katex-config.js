/*
 * KaTeX auto-render configuration.
 * Replaces the previous MathJax setup with identical delimiter behaviour.
 */
document.addEventListener("DOMContentLoaded", function () {
  renderMathInElement(document.body, {
    delimiters: [
      { left: "$$", right: "$$", display: true },
      { left: "$", right: "$", display: false },
    ],
    ignoredTags: [
      "script",
      "noscript",
      "style",
      "textarea",
      "pre",
      "code",
      "annotation",
      "annotation-xml",
      "decl",
      "decl_meta",
      "attributes",
      "decl_args",
      "decl_header",
      "decl_name",
      "decl_type",
      "equation",
      "equations",
      "structure_field",
      "structure_fields",
      "constructor",
      "constructors",
      "instances",
    ],
    ignoredClasses: ["tex2jax_ignore"],
    throwOnError: false,
  });
});
