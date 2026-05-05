# curry-mode

`curry-mode` is a modern, tree-sitter-powered Emacs major mode for Haskell. It
provides font-lock, indentation, navigation, imenu, GHCi REPL integration, and
Cabal build commands. Delegating all semantic features (completion,
go-to-definition, type info, code actions) to HLS via Eglot.

## Why?

Because `haskell-mode` has grown complex over the years, bundling everything
from indentation to REPL to HLS interaction in one monolith. With tree-sitter
built into Emacs 29+ and HLS providing all semantic features via LSP, a modern
Haskell mode can be dramatically simpler.

The architecture follows [neocaml](https://github.com/bbatsov/neocaml) and
[fsharp-ts-mode](https://github.com/bbatsov/fsharp-ts-mode): a thin
tree-sitter mode for syntax, with everything semantic delegated to the language
server.

## Features

- Tree-sitter based font-locking (4 levels) for `.hs`, `.lhs`, `.hsc`, and `.hs-boot` files
- Tree-sitter based indentation with cycle-indent and shift-region support
- Auto-detection of indentation offset from existing code
- Navigation (`beginning-of-defun`, `end-of-defun`, `forward-sexp`, sentence movement with `M-a`/`M-e`)
- Imenu with categories for Functions, Types, Classes, Instances, and Imports
- Toggling between `.hs` and `.lhs` via `ff-find-other-file` (`C-c C-a`)
- GHCi REPL integration (`curry-repl`) with tree-sitter input fontification
- Comment support: `fill-paragraph` (`M-q`), comment continuation (`M-j`), and `comment-dwim` (`M-;`)
- Electric indentation and electric pairs (parentheses, brackets, braces, backticks, quotes)
- Cabal file editing (`curry-cabal-mode`) with font-lock, indentation, imenu, and `cabal-fmt` integration
- Cabal build commands (`curry-cabal-interaction-mode`) -- build, test, run, clean, repl, haddock
- Easy installation of the Haskell tree-sitter grammar via `M-x curry-install-grammars`
- Compilation error regexp for GHC output (`M-g n` / `M-g p`)
- Eglot integration (auto-configured for `haskell-language-server-wrapper`)
- Debugging via [dape](https://github.com/svaante/dape) + [hdb](https://github.com/well-typed/haskell-debugger) (experimental, GHC 9.14+)
- Prettify-symbols for common Haskell operators

## Installation

### From source

Requires Emacs 29.1+ (for `:vc` support in `use-package`).

```emacs-lisp
(use-package curry-mode
  :vc (:url "https://github.com/tmcgilchrist/curry-mode" :rev :newest))
```

### Grammar

curry-mode uses a fork of the Haskell tree-sitter grammar with ABI 14
compatibility and bug fixes from [tek/tree-sitter-haskell](https://github.com/tek/tree-sitter-haskell).
The grammar is installed automatically when needed, or manually via:

```
M-x curry-install-grammars
```

## Usage

`curry-mode` activates automatically for `.hs`, `.lhs`, `.hsc`, and `.hs-boot`
files. `curry-cabal-mode` activates for `.cabal` files.

To use with Eglot, ensure `haskell-language-server-wrapper` is on your PATH
(install via [ghcup](https://www.haskell.org/ghcup/)):

```
ghcup install hls
```

Then start Eglot with `M-x eglot` in any Haskell buffer.

### Compilation

`C-c C-c` runs `M-x compile`, and curry-mode registers a GHC-specific error
regexp so that `next-error` (`M-g n`) and `previous-error` (`M-g p`) jump
directly to the source locations reported by the compiler.

## Navigation

curry-mode uses tree-sitter to power all structural navigation commands. These
are standard Emacs keybindings, backed by the AST rather than heuristics:

| Keybinding | Command              | Description                                           |
|------------|----------------------|-------------------------------------------------------|
| `C-M-a`    | `beginning-of-defun` | Move to the beginning of the current definition       |
| `C-M-e`    | `end-of-defun`       | Move to the end of the current definition             |
| `C-M-f`    | `forward-sexp`       | Move forward over a balanced expression               |
| `C-M-b`    | `backward-sexp`      | Move backward over a balanced expression              |
| `M-a`      | `backward-sentence`  | Move to the previous top-level declaration (Emacs 30+)|
| `M-e`      | `forward-sentence`   | Move to the next top-level declaration (Emacs 30+)    |
| `M-g i`    | `curry-jump-to-imports` | Jump to the import block; toggle back on second invocation |

<!-- TODO C-M-a / C-M-e jump around between data types fine but newtype or type they don't work -->
"Definitions" include function bindings, type signatures, data types, newtypes,
type synonyms, classes, instances, and imports. "Statements" (sentences) cover
the same set, enabling `M-a`/`M-e` to jump between top-level declarations.

All navigation commands are also available from the Haskell menu.

## Configuration

### Font-locking

curry-mode provides 4 levels of font-locking, as is standard for tree-sitter
modes. The default level in Emacs is 3, and you can change it like this:

```emacs-lisp
;; this font-locks everything curry-mode supports
(setq treesit-font-lock-level 4)
```

The font-lock features available at each level are:

**Level 1** (minimal -- comments and definitions):

- `comment` -- line comments, block comments, haddock comments, pragmas, CPP directives
- `definition` -- function declarations, type signatures, binding names, function parameters, lambda parameters

**Level 2** (add keywords, strings, numbers):

- `keyword` -- language keywords: `let`, `where`, `do`, `case`, `of`, `class`, `instance`, `data`, `import`, ...
- `string` -- string and character literals
- `number` -- integer, float, and negation literals

**Level 3** (default -- types, constructors, modules):

- `type` -- type constructors, type variables, star kind
- `constructor` -- data constructors, `True`/`False`, `otherwise`, unit `()`
- `module` -- module names in module declarations and imports

**Level 4** (maximum detail):

- `operator` -- operators, constructor operators, special symbols (`::`/`->`/`=>`/`<-`/`=`/`|`)
- `variable` -- variables and wildcards in patterns, record field names
- `function` -- function application, infix function application, builtin functions, quasi-quoters
- `bracket` -- parentheses, brackets, braces
- `delimiter` -- commas and semicolons

#### Selecting features

You don't have to use the level system. If you want fine-grained control over
what gets highlighted, cherry-pick individual features using
`treesit-font-lock-recompute-features`:

```emacs-lisp
(defun my-curry-font-lock-setup ()
  (treesit-font-lock-recompute-features
   ;; enable these features
   '(comment definition keyword string number
     type constructor module
     operator variable function)
   ;; disable these features
   '(bracket delimiter)))

(add-hook 'curry-base-mode-hook #'my-curry-font-lock-setup)
```

#### Customizing faces

The faces used are standard `font-lock-*-face` faces, so any theme applies
automatically. For buffer-local customization (only affects Haskell buffers):

```emacs-lisp
(add-hook 'curry-base-mode-hook
  (lambda ()
    (face-remap-add-relative 'font-lock-type-face
                             :foreground "DarkSeaGreen4")))
```

#### Adding custom font-lock rules

For distinctions that curry-mode doesn't make by default, layer additional
tree-sitter font-lock rules via a hook:

```emacs-lisp
(defface my-haskell-keyword-face
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for certain Haskell keywords.")

(defun my-curry-extra-keywords ()
  (setq treesit-font-lock-settings
        (append treesit-font-lock-settings
                (treesit-font-lock-rules
                 :language 'haskell
                 :override t
                 :feature 'keyword
                 '(["where" "let" "in" "do"]
                   @my-haskell-keyword-face))))
  (treesit-font-lock-recompute-features))

(add-hook 'curry-base-mode-hook #'my-curry-extra-keywords)
```

Use `M-x treesit-explore-mode` to inspect the syntax tree and find the right
node types to match.

#### Prettify Symbols

You can "prettify" certain Haskell operators by enabling `prettify-symbols-mode`:

```emacs-lisp
(add-hook 'curry-base-mode-hook #'prettify-symbols-mode)
```

The default replacements are: `\` to `lambda`, `->` to `arrow`, `<-` to `leftarrow`,
`=>` to `double arrow`, `/=` to `not equal`, `>=`/`<=` to `ge`/`le`, `==` to `equiv`,
`&&`/`||` to `and`/`or`.

For additional word-level prettification (`forall` to `for all`, `undefined` to `bottom`):

```emacs-lisp
(setq curry-prettify-words t)
```

### Indentation

Haskell is layout-sensitive: indentation is part of the syntax. This creates a
fundamental tension with tree-sitter indentation -- the parser needs correct
indentation to produce the right parse tree, but the indenter needs the parse
tree to compute correct indentation.

curry-mode handles this pragmatically:

- **Newline indentation** works well: pressing Enter after `do`, `where`, `=`,
  `->`, `case ... of`, etc. puts the cursor at the right column.
- **Re-indenting from scratch** (e.g. `indent-region` on fully stripped code) is
  inherently limited for layout-dependent constructs.
- **Round-trip preservation** works: correctly-indented code stays
  correctly-indented when re-indented.

For more details on why this is hard, see Batsov's
[F# indentation analysis](https://batsov.com/articles/2026/03/27/fsharp-ts-mode-a-modern-emacs-mode-for-fsharp/#fs-indentation-sensitive-syntax-is-tricky).

#### Indentation offset

The default indentation offset is 2 spaces. curry-mode auto-detects the offset
from existing files on open (controlled by `curry-guess-indent-offset`). You can
also set it explicitly:

```emacs-lisp
(setq curry-indent-offset 4)
```

Or per-project via `.dir-locals.el`:

```emacs-lisp
((curry-mode (curry-indent-offset . 4)))
```

#### Shift region

For manual indentation adjustment in layout-sensitive code:

| Keybinding | Command                    | Description                       |
|------------|----------------------------|-----------------------------------|
| `C-c >`    | `curry-shift-region-right`  | Indent region by one offset level |
| `C-c <`    | `curry-shift-region-left`   | Dedent region by one offset level |

#### Cycle indent

You can toggle between tree-sitter indentation and `indent-relative` using
`M-x curry-cycle-indent` (also available from the Haskell menu). This is handy
when the tree-sitter indentation doesn't do what you want for a particular piece
of code.

### Comments

Haskell uses `-- ` line comments and `{- ... -}` block comments. curry-mode
configures all the necessary variables so Emacs comment commands work out of the
box:

- **`M-;`** (`comment-dwim`) -- comments/uncomments regions, inserts inline comments
- **`M-j`** (`default-indent-new-line`) -- inside a block comment, inserts a
  newline and aligns the continuation with the comment body text
- **`M-q`** (`fill-paragraph`) -- refills the current comment, wrapping text at
  `fill-column` with proper indentation. Respects `{- -}`, `-- |` (haddock),
  and `{-# #-}` (pragma) delimiters.

### Code Folding

On Emacs 30+, `outline-minor-mode` works out of the box -- it automatically
picks up definition headings from the tree-sitter parse tree. Enable it via a
hook:

```emacs-lisp
(add-hook 'curry-base-mode-hook #'outline-minor-mode)
```

For tree-sitter-aware code folding (fold any node, not just top-level
definitions), [treesit-fold](https://github.com/emacs-tree-sitter/treesit-fold)
is supported via `curry-mode-treesit-fold-setup`, which registers `curry-mode`
with treesit-fold's Haskell fold definitions:

```emacs-lisp
(use-package treesit-fold
  :ensure t
  :hook (curry-base-mode . treesit-fold-mode)
  :config (curry-mode-treesit-fold-setup))
```

### Structural Selection

[expreg](https://github.com/casouri/expreg) provides expand-region-style
selection that leverages tree-sitter for language-aware expansion:

```emacs-lisp
(use-package expreg
  :ensure t
  :bind (("C-=" . expreg-expand)
         ("C--" . expreg-contract)))
```

## GHCi REPL Integration

`curry-repl-minor-mode` provides interaction with GHCi from source buffers.
Enable it via a hook:

```emacs-lisp
(add-hook 'curry-base-mode-hook #'curry-repl-minor-mode)
```

The following keybindings are available when `curry-repl-minor-mode` is active:

> **Note:** `C-c C-c` is bound to `compile` in the base mode. When
> `curry-repl-minor-mode` is enabled, it is rebound to
> `curry-repl-send-definition`.

| Keybinding | Command                      | Description                      |
|------------|------------------------------|----------------------------------|
| `C-c C-z`  | `curry-repl-switch-to-repl`  | Start GHCi or switch to it       |
| `C-c C-c`  | `curry-repl-send-definition` | Send the current definition      |
| `C-c C-r`  | `curry-repl-send-region`     | Send the selected region         |
| `C-c C-b`  | `curry-repl-send-buffer`     | Send the entire buffer           |
| `C-c C-l`  | `curry-repl-load-file`       | Load current file (`:load`)      |
| `C-c C-k`  | `curry-repl-reload`          | Reload current module (`:reload`)|
| `C-c C-t`  | `curry-repl-type-at-point`   | Show type (`:type`)              |
| `C-c C-i`  | `curry-repl-info-at-point`   | Show info (`:info`)              |

### Input Syntax Highlighting

By default, code you type in the REPL is fontified using tree-sitter via
`comint-fontify-input-mode`, giving you the same syntax highlighting as in
regular `.hs` buffers. To disable this:

```emacs-lisp
(setq curry-repl-fontify-input nil)
```

### Configuration

```emacs-lisp
;; Use cabal repl instead of bare ghci
(setq curry-repl-program-name "cabal repl")

;; Or use stack
(setq curry-repl-program-name "stack ghci")

;; Change the REPL buffer name
(setq curry-repl-buffer-name "*My-GHCi*")
```

## Cabal Support

### Cabal File Editing

`curry-cabal-mode` activates automatically for `.cabal` files and provides
tree-sitter based font-lock, indentation, imenu (Library, Executable, Test
Suite, Benchmark, Common, Flag, Source Repository), and formatting via
`cabal-fmt`.

| Keybinding | Command                     | Description            |
|------------|-----------------------------|------------------------|
| `C-c C-f`  | `curry-cabal-format-buffer` | Format with `cabal-fmt`|

To enable automatic formatting on save:

```emacs-lisp
(setq curry-cabal-format-on-save t)
```

### Cabal Build Commands

`curry-cabal-interaction-mode` is a minor mode that provides keybindings for
running common cabal commands from any Haskell buffer. All commands run via
`compile`, so you get error navigation and clickable source locations.

Enable it in Haskell buffers:

```emacs-lisp
(add-hook 'curry-base-mode-hook #'curry-cabal-interaction-mode)
```

Available commands (all under the `C-c C-d` prefix):

| Keybinding  | Command                          | Description                      |
|-------------|----------------------------------|----------------------------------|
| `C-c C-d b` | `curry-cabal-build`              | Build default target             |
| `C-c C-d B` | `curry-cabal-build-all`          | Build all targets                |
| `C-c C-d t` | `curry-cabal-test`               | Run all tests                    |
| `C-c C-d r` | `curry-cabal-run`                | Run executable (prompts)         |
| `C-c C-d c` | `curry-cabal-clean`              | Clean build artifacts            |
| `C-c C-d i` | `curry-cabal-repl`               | Launch `cabal repl`              |
| `C-c C-d h` | `curry-cabal-haddock`            | Generate documentation           |
| `C-c C-d f` | `curry-cabal-format`             | Run `cabal-fmt` on .cabal file   |
| `C-c C-d d` | `curry-cabal-command`            | Run arbitrary cabal command      |
| `C-c C-d .` | `curry-cabal-find-cabal-file`    | Jump to nearest `.cabal` file    |
| `C-c C-d p` | `curry-cabal-find-cabal-project` | Jump to nearest `cabal.project`  |

The project root is determined by walking up from the current file to find
`cabal.project` or a `.cabal` file.

## Debugging

curry-mode integrates with [dape](https://github.com/svaante/dape) (a DAP
client, available from GNU ELPA) and
[haskell-debugger](https://github.com/well-typed/haskell-debugger) (`hdb`) for
step-through debugging. Call `curry-mode-dape-setup` after dape is loaded to
register the `haskell-debugger` configuration.

**This is experimental and requires GHC 9.14+.**

### Setup

1. Install hdb:

   ```
   cabal install haskell-debugger \
     --allow-newer=base,time,containers,ghc,ghc-bignum,template-haskell \
     --enable-executable-dynamic
   ```

2. Install dape from GNU ELPA (`M-x package-install RET dape RET`).

3. Register the `haskell-debugger` configuration by calling
   `curry-mode-dape-setup` after dape is loaded:

   ```emacs-lisp
   (with-eval-after-load 'dape
     (curry-mode-dape-setup))
   ```

   Or with `use-package`:

   ```emacs-lisp
   (use-package dape
     :config (curry-mode-dape-setup))
   ```

### Usage

Set breakpoints with `M-x dape-breakpoint-toggle`, then start a debug session
with `M-x dape` -- select `haskell-debugger` and adjust `:entryFile` and
`:entryPoint` if needed.

You can set project defaults via `.dir-locals.el`:

```emacs-lisp
((curry-mode
  (dape-command . (haskell-debugger
                   :entryFile "app/Main.hs"
                   :entryPoint "main"))))
```

See the [Well-Typed blog post](https://well-typed.com/blog/2026/01/haskell-debugger/)
for details on debugger features and capabilities.

## Comparison with haskell-mode

| Feature                  | curry-mode                 | haskell-mode                   |
|--------------------------|----------------------------|--------------------------------|
| Required Emacs version   | 29.1+ (30+ recommended)    | 25+                            |
| Font-lock                | Tree-sitter (4 levels)     | Regex                          |
| Indentation              | Tree-sitter + cycle-indent | SMIE (haskell-indentation)     |
| REPL integration         | Yes (comint + tree-sitter) | Yes (interactive-haskell-mode) |
| Navigation (defun, sexp) | Tree-sitter                | Regex-based                    |
| Imenu                    | Tree-sitter (5 categories) | Regex-based                    |
| LSP (Eglot) integration  | Yes (auto-configured)      | Manual                         |
| Debugger                 | Yes (dape + hdb)           | No                             |
| Cabal file support       | Yes (tree-sitter)          | Yes (regex)                    |
| Cabal build commands     | Yes                        | Yes                            |
| Compilation commands     | Error regexp + `C-c C-c`   | Yes                            |
| Prettify symbols         | Yes                        | Yes                            |
| Code folding (outline)   | Yes (Emacs 30+)            | No                             |
| Import management        | Delegate to HLS            | Built-in                       |
| Type at point            | Delegate to HLS            | Built-in (via GHCi)            |

### The impact of LSP on major modes

Historically, `haskell-mode` bundled features like type display, completion,
jump-to-definition, import management, and smart suggestions -- driven by GHCi
process communication. Today, HLS provides all of these through the standard
LSP protocol, and Eglot (built into Emacs 29+) acts as the client. There is no
reason for a major mode to reimplement any of this.

HLS uses only standard LSP methods so vanilla Eglot gives you the complete
feature set: completions, hover, go-to-definition, code actions (add imports,
add pragmas, apply hlint fixes, case splitting), code lenses (type signatures,
eval plugin), rename, formatting, and diagnostics.

## Emacs Version Compatibility

| Feature                      | Emacs 29 | Emacs 30+ |
|------------------------------|----------|-----------|
| Font-lock                    | Yes      | Yes       |
| Indentation                  | Yes      | Yes       |
| `treesit-thing-settings`     | No       | Yes       |
| Sentence navigation (M-a/e)  | No       | Yes       |
| Hybrid `forward-sexp`        | Yes      | Yes       |
| `outline-minor-mode` folding | No       | Yes       |

## Development

### Running tests

```
eldev test
```

### Byte-compile

```
eldev compile --warnings-as-errors
```

### Lint

```
eldev lint
```

### Debugging tree-sitter

These built-in tools are invaluable when working on font-lock or indentation rules:

- `M-x treesit-explore-mode` -- visualise the full parse tree
- `M-x treesit-inspect-mode` -- show node type at point in the mode line
- `(setq treesit--font-lock-verbose t)` -- log which font-lock rules fire
- `(setq treesit--indent-verbose t)` -- log which indent rule matched

## Contributing

Contributions are welcome. The codebase follows the architecture of
[neocaml](https://github.com/bbatsov/neocaml) and
[fsharp-ts-mode](https://github.com/bbatsov/fsharp-ts-mode) -- a thin
tree-sitter mode with semantic features delegated to the language server.

## License

Copyright (c) 2026 Tim McGilchrist and [contributors](https://github.com/tmcgilchrist/curry-mode).

Distributed under the GNU General Public License, version 3 or later.
