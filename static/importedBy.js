import { DeclarationDataCenter } from "./declaration-data.js";

fillImportedBy();

async function fillImportedBy() {
  if (typeof(MODULE_NAME) == "undefined") {
    return;
  }
  // Only module pages have an "Imported by" list; other pages (e.g. book
  // chapters) have nothing to fill.
  const importedByList = document.querySelector(".imported-by-list");
  if (importedByList === null) {
    return;
  }
  const dataCenter = await DeclarationDataCenter.init();
  const moduleName = MODULE_NAME;
  const importedBy = dataCenter.moduleImportedBy(moduleName);
  var innerHTML = "";
  for(var module of importedBy) {
    const moduleLink = dataCenter.moduleNameToLink(module);
    innerHTML += `<li><a href="${SITE_ROOT}${moduleLink}">${module}</a></li>`
  }
  importedByList.innerHTML = innerHTML;
}
