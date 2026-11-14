# curry-mode Roadmap

This document collects ideas for where curry-mode could go next. It's a wish list
and a thinking tool, not a set of promises or a strict ordering. Items will move
in and out as priorities shift and as the surrounding ecosystem (Emacs,
haskell-language-server, the tree-sitter grammars) evolves. Contributions and
discussion on any of these are very welcome.

## Guiding principles

A few things that shape what belongs here and what doesn't:

- **tree-sitter first.** Font-lock, indentation and navigation come from the
  grammar and the built-in `treesit` machinery. We prefer fixing things at that
  layer, or upstream in the grammar, over bolting on regexp heuristics.
- **Lean on HLS, don't reinvent it.** haskell-language-server already provides
  completion, types on hover, go-to-definition, diagnostics, code actions and
  formatting through Eglot. curry-mode's job is to be a great editing substrate
  underneath that, and to work well before a server is running. Rewrites that
  only need the syntax tree are a different story: they work without a server,
  and they're exactly what tree-sitter is good at.
- **The build and the tooling around it are ours.** Cabal files, running the
  right tests and the REPL have no language server behind them, so that's where
  curry-mode's own features pay off most.
- **Indentation is an ongoing research area, not a launch blocker.** Ship rules
  for the common layouts, always keep an escape hatch, and document the cases we
  get wrong.
- **The grammar is a dependency, not a vendored asset.** Pin a revision, ship a
  recipe for `treesit-install-language-grammar`, and warn when the installed
  grammar is older than the one we need.
- **Tests are infrastructure.** Every feature lands with Buttercup specs, and CI
  runs them on every supported Emacs.

## Indentation and formatting

### 1. Hand a region to a formatter

`curry-cycle-indent` switches between tree-sitter indentation and
`indent-relative`. The third step the original plan called for, running the
region or buffer through `fourmolu` or `ormolu`, isn't wired up, and there's no
Haskell format-on-save to match `curry-cabal-format-on-save`. A
`curry-format-command` option and a `curry-format-buffer` command, following
`curry-cabal-format-command`, would cover both. Replacing only the parts of the
buffer that changed (`replace-buffer-contents`), rather than erasing and
reinserting it, keeps point, markers and undo history intact. HLS can also
format through `eglot-format-buffer`, so this is for people working without a
server. **Priority: high.**

### 2. Check indentation against real code

There's no way today to tell whether a rule change makes indentation better or
worse across real Haskell. A script could take a corpus of code already
formatted by fourmolu or ormolu, reindent every file with curry-mode in batch
Emacs, and report the lines that come out differently. Run before and after a
change, that shows what the change fixed and what it broke, and it would show
where we disagree with `haskell-mode`'s indentation too. Known hard cases
(`NondecreasingIndentation`, CPP blocks, layouts that change the parse tree as
you type) should be listed in the specs as expected failures rather than left to
surprise people. **Priority: medium.**

### 3. Electric reindentation

Reindent the current line as soon as typing a keyword settles where it belongs:
`then`, `else`, `of`, `in` and `where`. With `electric-pair-mode` on, close a
`{-#` pragma opener with `#-}`. **Priority: medium.**

## Navigation

### 4. Group multi-equation functions in imenu

Each equation of a function is its own node in the grammar, so a function with a
signature and two equations shows up three times under "Function". imenu should
list it once and jump to its first equation (or its signature).
**Priority: high.**

### 5. Keyword-led forms in `C-M-f` on Emacs 31

On Emacs 31, `treesit-major-mode-setup` sets `forward-sexp-function` to
`treesit-forward-sexp-list`. That moves over lists using the `list` thing, but
hands everything else to `forward-sexp-default-function` and ignores the `sexp`
thing, so a form that starts with a keyword is treated as a bare word and
`C-M-f` stops after the keyword. Haskell's `case`, `do`, `if` and `let` are
likely affected. If so, use `curry--forward-sexp-hybrid` on every Emacs version:
it walks sexps with tree-sitter and falls back to `scan-sexps` only on delimiter
characters, which keeps `delete-pair` working too. **Priority: medium.**

### 6. Jump between code and its tests

`C-c C-a` toggles between related files with `ff-find-other-file`. Emacs 29's
`find-sibling-rules` could pair a module with its test the same way, following
the hspec-discover convention: `src/Foo/Bar.hs` ↔ `test/Foo/BarSpec.hs`.
**Priority: low.**

## Language support

### 7. Literate Haskell

`.lhs` files mix prose with code, in Bird style (`>` lines) or LaTeX style
(`\begin{code}`). The Haskell grammar parses neither: every `>` line of a
Bird-style file comes back as an error, so curry-mode shouldn't open `.lhs`
files until this is done. A literate grammar exists
(tree-sitter-literate-haskell); supporting it means a host parser for the
document, with the Haskell grammar injected into the code blocks through
`treesit-range-settings`. **Priority: medium.**

### 8. Font-lock refinements

- Finer faces for infix operators, monadic operators (`>>=`, `<-`) and
  user-defined operators.
- Highlight the code inside Template Haskell splices and the contents of
  well-known quasiquoters (SQL, HTML, raw strings) by language injection.
- Highlight only the pattern variables that are actually bound, rather than
  every name in a pattern, as `haskell-ts-mode` does.

**Priority: medium / low.**

### 9. Install grammars from tagged releases

Both grammar recipes follow a branch today, so a curry-mode release doesn't
control exactly which grammar it gets: a push to either branch can change node
types under the font-lock queries.

- **Haskell.** curry-mode uses tek/tree-sitter-haskell, which carries fixes no
  upstream release has (typed holes, the hsc2hs dialect, tab handling, sized
  primitive literals, an aarch64 scanner crash). tek's repository neither
  commits a generated `parser.c` nor tags releases, and
  `treesit-install-language-grammar` compiles `src/parser.c` without running
  `tree-sitter generate`. So the recipe follows the `tek-main-abi-15` branch of
  a fork that adds the parsers, generated at ABI 15 with tree-sitter-cli 0.27.2,
  on top of tek's main. An official tagged release with a generated parser has
  been requested from tek. Once one exists (from tek, or from
  tree-sitter/tree-sitter-haskell carrying tek's fixes), pin the recipe to it
  and retire the fork.
- **Cabal.** The recipe follows the `main` branch of a fork of
  magus/tree-sitter-cabal that carries fixes for curry-cabal-mode. Tag a release
  there, or upstream the fixes and pin an upstream tag.

When both recipes name tags, add a spec that fails if a recipe names a branch,
so the pins can't drift back. **Priority: high.**

## Refactoring

### 10. Syntactic refactorings

Rewrites that only need the syntax tree work without a running server.
hlint, through HLS, already suggests eta reduction and removing redundant `$`
and parentheses, so these are the ones it doesn't do:

- `f $ g x` ↔ `f (g x)`, and `f . g $ x` ↔ `f (g x)`.
- `do` notation ↔ `>>=` and `>>`.
- `\x -> case x of ...` ↔ `\case ...`.
- `where` bindings ↔ `let ... in`.
- `if`/`then`/`else` ↔ guards.
- Pun and unpun record fields: `Foo { bar = bar }` ↔ `Foo { bar }`.

A good shape for each: find the node with `treesit-thing-at-point`, edit through
markers from the end backwards so earlier positions stay valid, reindent the
result, signal a `user-error` for shapes it doesn't handle, and test it with
before/after specs. They'd get a prefix of their own, such as `C-c C-m`
(`C-c C-r` is taken by the REPL's send-region). Before building the punning
toggle, check whether fourmolu or ormolu normalise puns; if they do, the toggle
is pointless for most people. **Priority: medium.**

## Editing

### 11. Skeletons and templates

- An `auto-insert` template for a new file that writes its module header, with
  the module name worked out from the file's path below the package's
  `hs-source-dirs`: `src/Foo/Bar.hs` starts as `module Foo.Bar where`.
- A command that inserts a `{-# LANGUAGE ... #-}` pragma at the top of the file,
  with completion of GHC's extension names.
- Skeletons for cabal sections: `library`, `executable`, `test-suite` and
  `common` stanzas with their usual fields.

**Priority: medium.**

## REPL

### 12. A REPL session per project

`curry-repl` is a thin `comint` wrapper around a single global `*GHCi*` buffer.
Multi-project work needs more:

- One REPL buffer per project, named after its path below the project root
  (`*GHCi: my-project*`), so each project gets its own session and dependencies.
- Pick `cabal repl`, `stack ghci` or plain `ghci` from the files at the project
  root (`cabal.project`, `stack.yaml`, `*.cabal`), with a `curry-repl-backend`
  option to override it.
- Show errors from REPL output in the source buffer, not only as
  `compilation-shell-minor-mode` links in the REPL.

This is the largest item here. **Priority: high.**

### 13. More REPL helpers

- Map errors that point into the REPL's own input (`<interactive>:3:5`) back to
  the definition that was sent from the source buffer.
- Restart the REPL, and `:browse` the module at point.

HLS's eval plugin already inserts an expression's result below a `-- >>>`
comment, so that belongs in the documentation (item 20) rather than here.
**Priority: medium.**

## Cabal and the build

### 14. A test workflow

- Run `cabal test` for the component the current file belongs to, rather than
  `cabal test all`.
- Run just the test at point, taking its name from the parse tree and passing it
  as hspec's `--match` or tasty's `-p` pattern.
- Rerun the last test command from anywhere in the project.

**Priority: high.**

### 15. Cabal conveniences

- `cabal run` with completion of the package's executables, read from the
  `.cabal` file with the cabal grammar.
- Completion of targets for `cabal build`.
- ghcid support: a buffer that keeps a ghcid process running for the project and
  shows its latest errors, as a fast alternative to rebuilding with `compile`.

**Priority: medium.**

### 16. Add a missing package

When GHC reports that a module "is a member of the hidden package aeson", offer
to add `aeson` to the `build-depends` of the component the file belongs to.
HLS's cabal plugin may already offer this as a code action (through the
cabal-add library); check first, and if it does, document it in item 20
instead. **Priority: medium.**

### 17. `M-x align` rules for cabal sections

The original plan called for `align-rules-list` entries in `curry-cabal-mode` to
line up the values of the fields in a section. cabal-fmt and cabal-gild already
do this when formatting the whole file, so this is for people who'd rather align
one section by hand. **Priority: low.**

## Tools

### 18. A setup checker

Bug reports about a broken setup tend to need the same answers. A `curry-doctor`
command could collect them up front:

- whether the Haskell and cabal grammars are installed and load, and at which
  ABI version;
- which `haskell-language-server-wrapper`, `ghc`, `cabal` or `stack`, and
  `cabal-fmt` or `cabal-gild` are on the `PATH`, and their versions;
- whether Eglot has an entry for `curry-mode`;
- whether there are stale `.elc` files older than their source.

It grows naturally out of `curry-bug-report-info`. **Priority: medium-high.**

### 19. See what GHC did

Show GHC's intermediate output for the current file in a read-only side buffer:

- Template Haskell splices after expansion (`-ddump-splices`).
- Instances produced by `deriving` (`-ddump-deriv`).
- GHC Core (`-ddump-simpl -dsuppress-all`), with a small `special-mode`
  derivative to fontify it, and STG or Cmm on request.

**Priority: low.**

## Documentation and the HLS ecosystem

### 20. Document what HLS, Emacs and other packages already do

Several things `haskell-mode` builds in are already covered elsewhere, and need
only a recipe in the README:

- Sorting and aligning imports with stylish-haskell through `eglot-format`
  (`align_imports`, `pad_module_names` in `.stylish-haskell.yaml`).
- Adding, removing and qualifying imports, and the other code actions (hlint
  suggestions, retrie, GADT conversion, splice expansion, `eval` code lenses),
  through `eglot-code-actions` and `eglot-code-action-quickfix`.
- Evaluating `-- >>>` comments with HLS's eval plugin.
- Hoogle search with [consult-hoogle](https://github.com/aikrahguzar/consult-hoogle).
- Unicode input with
  [haskell-unicode-input-method](https://github.com/roelvandijk/emacs-haskell-unicode-input-method).
- Structural editing with [combobulate](https://github.com/mickeynp/combobulate),
  once Haskell support lands upstream
  ([tmcgilchrist/combobulate#12](https://github.com/tmcgilchrist/combobulate/pull/12)).
- Emacs 30's `completion-preview-mode`, which shows the top completion inline
  and works with Eglot, and `flymake-show-diagnostics-at-end-of-line`.

**Priority: high, docs only.**

### 21. Align the imports block only

`eglot-format-buffer` with stylish-haskell formats the whole buffer. A
`curry-align-imports` command could run `stylish-haskell` over just the imports
node, for codebases where formatting everything is disruptive. Only worth doing
if that friction turns up in practice. **Priority: low.**

## Adopting newer Emacs features (29 / 30 / 31)

### 22. Grammar install via the Emacs 31 built-ins

Emacs 31 adds `treesit-auto-install-grammar`, which offers to fetch and build a
missing grammar. On 31+ we could lean on it instead of our own "grammar not
installed" prompt, keeping the current path for 29 and 30.
**Priority: medium.**

## Smaller items and nice-to-haves

- **Menus**: a `:help` string on every menu item, and the flat Haskell menu
  split into submenus (Navigate, Edit, Toggle, Font-Lock Level), with entries
  for customizing curry-mode and reporting a bug.
- **Performance**: check the behavior on very large modules, and pick a sensible
  default for `treesit-font-lock-level`.
- **Upstream into haskell-mode**: once indentation is stable, propose
  curry-mode's approach for haskell-mode's tree-sitter work
  ([haskell-mode#1804](https://github.com/haskell/haskell-mode/issues/1804)).
- **Adaptive indentation**: remember which indentation a user picked with
  `curry-cycle-indent` for a construct, and offer it first next time.

## Not planned

- **CPP `#if` / `#elif` / `#else` blocks.** The grammar doesn't model them, and
  that can't be fixed from Emacs.
- **`NondecreasingIndentation`.** Rarely used, and it fights the layout rule the
  indentation rules are built on. Document it as unsupported.
- **Docs for the symbol at point.** HLS hovers already link to the symbol's
  Haddock page, and consult-hoogle covers search.

## Lessons from sibling modes

Patterns worth borrowing, noted next to the items they informed:

- **neocaml** (OCaml): checking indentation against a formatted corpus (item 2),
  per-project REPL sessions (item 12), a setup checker (item 18), and the hybrid
  `forward-sexp-function` (item 5).
- **clojure-ts-mode and clj-refactor**: refactoring commands built on the parse
  tree, and a before/after test style for them (item 10).
- **haskell-ts-mode**: highlighting only the pattern variables that are bound
  (item 8).
- **haskell-mode**: its interactive REPL as the bar for multi-project sessions
  (item 12).

## References

- [Tree-sitter Major Modes (Emacs Lisp manual)](https://www.gnu.org/software/emacs/manual/html_node/elisp/Tree_002dsitter-Major-Modes.html)
- [haskell-language-server](https://haskell-language-server.readthedocs.io/)
- [tree-sitter-haskell](https://github.com/tree-sitter/tree-sitter-haskell)
- [tek/tree-sitter-haskell](https://github.com/tek/tree-sitter-haskell)
- [haskell-mode#1804](https://github.com/haskell/haskell-mode/issues/1804)
- [haskell-ts-mode](https://codeberg.org/pranshu/haskell-ts-mode)
- [neocaml](https://github.com/bbatsov/neocaml)
- [Building Emacs Major Modes with Tree-sitter: Lessons Learned](https://batsov.com/articles/2026/02/27/building-emacs-major-modes-with-treesitter-lessons-learned/)
