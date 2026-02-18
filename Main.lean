import DocGen4
import Lean
import Cli

open DocGen4 Lean Cli

def getTopLevelModules (p : Parsed) : IO (List String) :=  do
  let topLevelModules := p.variableArgsAs! String |>.toList
  if topLevelModules.length == 0 then
    throw <| IO.userError "No topLevelModules provided."
  return topLevelModules

def runHeaderDataCmd (p : Parsed) : IO UInt32 := do
  let buildDir := match p.flag? "build" with
    | some dir => dir.as! String
    | none => ".lake/build"
  headerDataOutput buildDir
  return 0

def runSetupGithubCmd (p : Parsed) : IO UInt32 := do
  let remote := p.flag! "remote" |>.as! String
  let out ← IO.Process.output {
    cmd := "git",
    args := #["remote", "get-url", remote]
  }
  if out.exitCode != 0 then
    throw <| IO.userError s!"Failed to find a git remote '{remote}' in your project."
  let remoteUrl := out.stdout.trimAsciiEnd.copy
  let some githubUrl := DocGen4.Output.getGithubBaseUrl remoteUrl
    | throw <| IO.userError s!"Could not interpret Git remote uri {remoteUrl} as a Github source repo."

  let workflow := s!"name: doc-gen test build

on:
  push:
    branches:
      - \"main\"
  pull_request:

jobs:
  build:
    name: doc-gen test build
    runs-on: ubuntu-latest
    env:
      DOCGEN_REMOTE: {remote}
    steps:
      - name: Checkout repo
        uses: actions/checkout@v4

      - name: Add {remote} remote
        run: git remote add {remote} {githubUrl}.git

      - name: install elan and build doc-gen4
        uses: leanprover/lean-action@v1
        with:
          build-args: \"--wfail\"

      - name: Build docs
        run: |
          export LEAN_ABORT_ON_PANIC=1
          # to ensure that the `--query` test below has a baseline to compare against.
          rm -rf .lake/build/docs
          lake build DocGen4:docs

      - name: Check `--query` output
        shell: bash  # enables pipefail
        run: |
          export LEAN_ABORT_ON_PANIC=1
          lake query DocGen4:docs | sort > expected.txt
          find \"$(pwd)/.lake/build/doc\" -type f ! -name '*.trace' ! -name '*.hash' | sort > actual.txt
          diff actual.txt expected.txt
"
  IO.FS.createDirAll ".github/workflows"
  IO.FS.writeFile ".github/workflows/build.yml" workflow
  return 0

def runSingleCmd (p : Parsed) : IO UInt32 := do
  let buildDir := match p.flag? "build" with
    | some dir => dir.as! String
    | none => ".lake/build"
  let relevantModules := #[p.positionalArg! "module" |>.as! String |> String.toName]
  let sourceUri := p.positionalArg! "sourceUri" |>.as! String
  let (doc, hierarchy) ← load <| .analyzeConcreteModules relevantModules
  let baseConfig ← getSimpleBaseContext buildDir hierarchy
  discard <| htmlOutputResults baseConfig doc (some sourceUri)
  return 0

def runIndexCmd (p : Parsed) : IO UInt32 := do
  let buildDir := match p.flag? "build" with
    | some dir => dir.as! String
    | none => ".lake/build"
  let staticDir := p.flag? "static" |>.map (·.as! String)
  let bookDir := p.flag? "book" |>.map (·.as! String)
  let hierarchy ← Hierarchy.fromDirectory (Output.basePath buildDir)
  let baseConfig ← getSimpleBaseContext buildDir hierarchy
  htmlOutputIndex baseConfig staticDir bookDir
  return 0

def runGenCoreCmd (p : Parsed) : IO UInt32 := do
  let buildDir := match p.flag? "build" with
    | some dir => dir.as! String
    | none => ".lake/build"
  let manifestOutput? := (p.flag? "manifest").map (·.as! String)
  let module := p.positionalArg! "module" |>.as! String |> String.toName
  let (doc, hierarchy) ← load <| .analyzePrefixModules module
  let baseConfig ← getSimpleBaseContext buildDir hierarchy
  let outputs ← htmlOutputResults baseConfig doc none
  if let .some manifestOutput := manifestOutput? then
    IO.FS.writeFile manifestOutput (Lean.toJson outputs).compress
  return 0

def runDocGenCmd (_p : Parsed) : IO UInt32 := do
  IO.println "You most likely want to use me via Lake now, check my README on Github on how to:"
  IO.println "https://github.com/leanprover/doc-gen4"
  return 0

def runBibPrepassCmd (p : Parsed) : IO UInt32 := do
  let buildDir := match p.flag? "build" with
    | some dir => dir.as! String
    | none => ".lake/build"
  if p.hasFlag "none" then
    IO.println "INFO: reference page disabled"
    disableBibFile buildDir
  else
    match p.variableArgsAs! String with
    | #[source] =>
      let contents ← IO.FS.readFile source
      if p.hasFlag "json" then
        IO.println "INFO: 'references.json' will be copied to the output path; there will be no 'references.bib'"
        preprocessBibJson buildDir contents
      else
        preprocessBibFile buildDir contents Bibtex.process
    | _ => throw <| IO.userError "there should be exactly one source file"
  return 0

def singleCmd := `[Cli|
  single VIA runSingleCmd;
  "Only generate the documentation for the module it was given, might contain broken links unless all documentation is generated."

  FLAGS:
    b, build : String; "Build directory."

  ARGS:
    module : String; "The module to generate the HTML for. Does not have to be part of topLevelModules."
    sourceUri : String; "The sourceUri as computed by the Lake facet"
]

def indexCmd := `[Cli|
  index VIA runIndexCmd;
  "Index the documentation that has been generated by single."

  FLAGS:
    b, build : String; "Build directory."
    s, static : String; "Static directory."
    k, book : String; "Directory containing mdBook-style sources (expects SUMMARY.md)."
]

def genCoreCmd := `[Cli|
  genCore VIA runGenCoreCmd;
  "Generate documentation for the specified Lean core module as they are not lake projects."

  FLAGS:
    b, build : String; "Build directory."
    m, manifest : String; "Manifest output, to list all the files generated."

  ARGS:
    module : String; "The module to generate the HTML for."
]

def bibPrepassCmd := `[Cli|
  bibPrepass VIA runBibPrepassCmd;
  "Run the bibliography prepass: copy the bibliography file to output directory. By default it assumes the input is '.bib'."

  FLAGS:
    n, none; "Disable bibliography in this project."
    j, json; "The input file is '.json' which contains an array of objects with 4 fields: 'citekey', 'tag', 'html' and 'plaintext'."
    b, build : String; "Build directory."

  ARGS:
    ...source : String; "The bibliography file. We only support one file for input. Should be '.bib' or '.json' according to flags."
]

def headerDataCmd := `[Cli|
  headerData VIA runHeaderDataCmd;
  "Produce `header-data.bmp`, this allows embedding of doc-gen declarations into other pages and more."

  FLAGS:
    b, build : String; "Build directory."
]

def setupGithubCmd := `[Cli|
  "setup-github" VIA runSetupGithubCmd;
  "Configure a GitHub Actions workflow for doc-gen4."

  FLAGS:
    r, remote : String; "The git remote to use for GitHub source links."
]

def docGenCmd : Cmd := `[Cli|
  "doc-gen4" VIA runDocGenCmd; ["0.1.0"]
  "A documentation generator for Lean 4."

  SUBCOMMANDS:
    singleCmd;
    indexCmd;
    genCoreCmd;
    bibPrepassCmd;
    headerDataCmd;
    setupGithubCmd
]

def main (args : List String) : IO UInt32 :=
  docGenCmd.validate args
