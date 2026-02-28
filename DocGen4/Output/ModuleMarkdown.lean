/-
Copyright (c) 2024 Henrik Böving. All rights reserved.
Released under Apache 2.0 license as described in the file LICENSE.
Authors: Henrik Böving, Gemini CLI
-/
import DocGen4.Output.Base
import DocGen4.Output.DocString
import DocGen4.Process

namespace DocGen4
namespace Output

open Lean Process Elab Widget

/-- Turns a `CodeWithInfos` object into a Markdown string with linkification. -/
partial def infoFormatToMarkdown (i : CodeWithInfos) : HtmlM String := do
  match i with
  | TaggedText.text t => return t
  | TaggedText.append tt => do
    let ss ← tt.mapM infoFormatToMarkdown
    return String.join ss.toList
  | TaggedText.tag a t => do
    let inner ← infoFormatToMarkdown t
    match a.info.val.info with
    | Info.ofTermInfo i =>
      let cleanExpr := i.expr.consumeMData
      match cleanExpr with
      | .const name _ =>
        let res ← getResult
        if res.name2ModIdx.contains name then
          let link ← declNameToLink name
          return s!"[{inner}]({← getRoot}{link})"
        else
          return inner
      | _ => return inner
    | _ => return inner

def docInfoHeaderToMarkdown (doc : Process.DocInfo) : HtmlM String := do
  let mut res := s!"## `{doc.getName}` ({doc.getKindDescription})\n\n"
  res := res ++ "```lean\n"
  res := res ++ s!"{doc.getKindDescription} {doc.getName}"
  for arg in doc.getArgs do
    res := res ++ s!" {← infoFormatToMarkdown arg.binder}"
  res := res ++ " : " ++ (← infoFormatToMarkdown doc.getType) ++ "\n"
  res := res ++ "```\n"
  return res

def docInfoToMarkdown (doc : Process.DocInfo) : HtmlM String := do
  let header ← docInfoHeaderToMarkdown doc
  let docString := doc.getDocString.getD ""
  return s!"{header}\n{docString}\n\n"

def moduleToMarkdown (module : Process.Module) : HtmlM String := withTheReader SiteBaseContext (setCurrentName module.name) do
  let mut res := s!"# Module `{module.name}`\n\n"
  for member in module.members do
    match member with
    | ModuleMember.docInfo d =>
      if d.shouldRender then
        res := res ++ (← docInfoToMarkdown d)
    | ModuleMember.modDoc d =>
      res := res ++ d.doc ++ "\n\n"
  return res

partial def hierarchyToMarkdown (h : Hierarchy) (level : Nat := 0) : BaseHtmlM String := do
  let mut res := ""
  let indent := String.join (List.replicate level "  ")
  if h.getName != Name.anonymous then
    if h.isFile then
      res := res ++ s!"{indent}- [{h.getName.getString!}]({← moduleNameToMarkdownLink h.getName})\n"
    else
      res := res ++ s!"{indent}- {h.getName.getString!}\n"
  
  let children := h.getChildren.toArray.map Prod.snd |>.qsort (fun a b => a.getName.toString < b.getName.toString)
  for child in children do
    res := res ++ (← hierarchyToMarkdown child (if h.getName == Name.anonymous then level else level + 1))
  return res

def summaryToMarkdown : BaseHtmlM String := do
  let hierarchy ← getHierarchy
  let mut res := "# Summary\n\n"
  res := res ++ (← hierarchyToMarkdown hierarchy)
  return res

end Output
end DocGen4
