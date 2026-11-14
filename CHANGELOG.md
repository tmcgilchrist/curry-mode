# Changelog

<!-- Entries are one line per item and section headings repeat for every release,
     so the line-length and duplicate-heading rules don't fit this file. -->
<!-- markdownlint-disable MD013 MD024 -->

## main (unreleased)

Initial release. Requires Emacs 29.1 or newer, linked against libtree-sitter 0.25 or newer.

### New features

- Tree-sitter based font-locking with 4 levels of highlighting for `.hs`, `.hsc` and `.hs-boot` files.
- Tree-sitter based indentation, with `curry-cycle-indent` to switch to `indent-relative`, shifting the region by one level (`C-c >` / `C-c <`), and guessing the indentation offset from the file (`curry-guess-indent-offset`).
- Navigation by definition (`beginning-of-defun`, `end-of-defun`), including type families and their instances, and by expression (`forward-sexp`).
- Navigation by top-level declaration (`M-a` / `M-e`), by list, and folding with `outline-minor-mode` (Emacs 30+).
- Jump to the import block and back with `curry-jump-to-imports` (`M-g i`).
- Imenu with Function, Type, Class, Instance and Import categories, and which-func support.
- Comment filling (`M-q`) and continuation (`M-j`) for line and block comments.
- Prettify-symbols for common operators, plus `forall` and `undefined` with `curry-prettify-words`.
- GHCi REPL (`curry-repl`) with tree-sitter fontification of input, persistent history, and `curry-repl-minor-mode` for sending definitions, regions, lines and buffers, loading and reloading files, and asking for `:type` and `:info` at point.
- [#7](https://github.com/tmcgilchrist/curry-mode/pull/7): `curry-cabal-mode` for `.cabal` files, with font-locking, indentation, imenu and section navigation that cope with merge conflict markers, and formatting with cabal-fmt or cabal-gild (`curry-cabal-format-command`), optionally on save, that changes only the text the formatter changed and keeps its warnings out of the file.
- [#7](https://github.com/tmcgilchrist/curry-mode/pull/7): `curry-cabal-interaction-mode` for running cabal commands (build, test, run, clean, repl, haddock, update, or any other) from Haskell buffers under `C-c C-d`, formatting the project's `.cabal` file with `curry-cabal-format-command`, and finding its `.cabal` and `cabal.project` files.
- GHC error and warning locations in `compile` output (`M-g n` / `M-g p`).
- Eglot registration for haskell-language-server.
- Debugging with dape and haskell-debugger (`curry-mode-dape-setup`, experimental, GHC 9.14+), and code folding with treesit-fold (`curry-mode-treesit-fold-setup`).
- Grammar installation with `curry-install-grammars` and `curry-cabal-install-grammar`, a warning when the installed Haskell grammar is outdated, and a clear error when Emacs's libtree-sitter is too old.
- `curry-version`, `curry-bug-report-info` and `curry-report-bug`.
