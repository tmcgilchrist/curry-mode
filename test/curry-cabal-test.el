;;; curry-cabal-test.el --- Tests for curry-cabal-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for `curry-cabal-mode': font-locking, indentation and
;; navigation.
;;
;; Properties of the Cabal grammar that shape every fixture here.
;;
;; A fixture has to parse without an ERROR node.  On such a buffer
;; sections go unrecognised, faces fall back to
;; `font-lock-property-name-face' and imenu returns nil, so assertions
;; pass or fail for the wrong reasons.  The grammar used to demand a
;; `cabal-version:' stanza, at least one top-level field and at least
;; one section, all three and in that order; since tree-sitter-cabal
;; made properties and sections optional a lone field, a lone section
;; or a bare version stanza all parse.  Fixtures below are still
;; complete little package descriptions, because that is what the mode
;; meets in practice, not because the grammar insists on it.
;;
;; One shape does still fail: `spec_version' matches a trailing newline
;; as part of the token, so a `cabal-version' line must be terminated.
;; `with-curry-cabal-buffer' dedents its content and strips the trailing
;; newline, which means a fixture must not *end* on its version line --
;; put any other line after it.
;;
;; Cabal is also layout-sensitive -- the grammar emits `indent'/`dedent'
;; tokens -- so stripping leading whitespace collapses a section body
;; into top-level fields and changes the parse tree.  That rules out the
;; strip-and-re-indent round trip `when-indenting-cabal-it' performs,
;; the same way it is ruled out for layout-dependent Haskell in
;; curry-indentation-test.el.  Indentation is checked here by asserting
;; that `indent-region' leaves correctly-indented text alone, and with
;; `when-newline-indenting-cabal-it'.
;;
;; Section bodies are covered with more than one field per section on
;; purpose.  The block node begins at its first field rather than after
;; the section header, so a body anchored on the block measures itself
;; from its own first line: the first field lands correctly while every
;; later one drifts a level deeper on each re-indent.  A suite of
;; single-field sections passes straight through that bug.

;;; Code:

(require 'curry-test-helpers)

(defun curry-cabal-test--expect-indent-preserved (content)
  "Assert that `indent-region' leaves CONTENT unchanged.
CONTENT is dedented first, so fixtures can be written indented in
source.  Cabal is layout-sensitive, so a strip-and-re-indent round trip
would change the parse tree; re-indenting already-correct text is the
meaningful check."
  (with-curry-cabal-buffer content
    (let ((original (buffer-string)))
      (indent-region (point-min) (point-max))
      (expect (buffer-string) :to-equal original))))

(describe "curry-cabal-mode font-lock"
  (before-all
    (curry-test-skip-unless-grammar 'cabal))

  (describe "level 1: comments and keywords"

    (when-fontifying-cabal-it "fontifies line comments"
      ("cabal-version: 2.4
name: my-package
-- a comment

library
  build-depends: base"
       ("-- a comment" font-lock-comment-face)))

    (when-fontifying-cabal-it "fontifies the cabal-version keyword"
      ("cabal-version: 2.4
name: my-package

library
  build-depends: base"
       ("cabal-version" font-lock-keyword-face)))

    (when-fontifying-cabal-it "fontifies section types"
      ("cabal-version: 2.4
name: my-package

library
  build-depends: base"
       ("library" font-lock-keyword-face)))

    (when-fontifying-cabal-it "fontifies executable and test-suite sections"
      ("cabal-version: 2.4
name: my-package

executable my-exe
  main-is: Main.hs"
       ("executable" font-lock-keyword-face))
      ("cabal-version: 2.4
name: my-package

test-suite spec
  type: exitcode-stdio-1.0"
       ("test-suite" font-lock-keyword-face)))

    ;; Cabal spells the else-if branch `elif'; the grammar accepted only
    ;; `elseif' until it was corrected, so real files using `elif' did
    ;; not parse at all.
    (when-fontifying-cabal-it "fontifies conditional keywords"
      ("cabal-version: 2.4
name: my-package

library
  if os(windows)
    build-depends: Win32
  elif os(linux)
    build-depends: unix
  else
    build-depends: base"
       ("if" font-lock-keyword-face)
       ("elif" font-lock-keyword-face)
       ("else" font-lock-keyword-face))))

  (describe "level 2: field names"

    (when-fontifying-cabal-it "fontifies top-level field names"
      ("cabal-version: 2.4
name: my-package
version: 0.1.0.0

library
  build-depends: base"
       ("name" font-lock-property-name-face)
       ("version" font-lock-property-name-face)))

    (when-fontifying-cabal-it "fontifies field names inside a section"
      ("cabal-version: 2.4
name: my-package

library
  exposed-modules: Foo
  build-depends: base"
       ("exposed-modules" font-lock-property-name-face)
       ("build-depends" font-lock-property-name-face))))

  (describe "level 3: spec versions and section names"

    (when-fontifying-cabal-it "fontifies the spec version"
      ("cabal-version: 2.4
name: my-package

library
  build-depends: base"
       ("2.4" font-lock-constant-face)))

    (when-fontifying-cabal-it "fontifies section names"
      ("cabal-version: 2.4
name: my-package

executable my-exe
  main-is: Main.hs"
       ("my-exe" font-lock-type-face)))

    (when-fontifying-cabal-it "distinguishes section name from section type"
      ("cabal-version: 2.4
name: my-package

test-suite spec
  type: exitcode-stdio-1.0"
       ("test-suite" font-lock-keyword-face)
       ("spec" font-lock-type-face)))))

(describe "curry-cabal-mode indentation"
  (before-all
    (curry-test-skip-unless-grammar 'cabal))

  (describe "indent-region leaves correct text alone"

    ;; Section bodies anchor on the section, not on the block, so every
    ;; field in a body lands at one offset -- not just the first.  Before
    ;; that fix each field after the first drifted a level deeper on
    ;; every re-indent, which single-field fixtures could not detect.
    (it "preserves a single-field section"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        library
          build-depends: base"))

    (it "preserves a section with several fields"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        library
          exposed-modules: Foo
          build-depends: base
          hs-source-dirs: src"))

    (it "preserves several sections"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        library
          build-depends: base
          ghc-options: -Wall

        executable my-exe
          main-is: Main.hs
          hs-source-dirs: app"))

    (it "preserves a conditional following a field"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        library
          build-depends: base
          if flag(dev)
            ghc-options: -Wall
          else
            ghc-options: -O2"))

    (it "preserves an if/elif/else chain"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        library
          if os(windows)
            build-depends: Win32
          elif os(linux)
            build-depends: unix
          else
            build-depends: base"))

    (it "preserves a nested conditional"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        library
          if flag(dev)
            if os(windows)
              build-depends: Win32"))

    (it "preserves test-suite and benchmark sections"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        test-suite spec
          type: exitcode-stdio-1.0
          main-is: Spec.hs

        benchmark bench
          type: exitcode-stdio-1.0
          main-is: Bench.hs"))

    (it "preserves common and flag stanzas"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        flag dev
          description: dev mode
          default: False

        common warnings
          ghc-options: -Wall

        library
          import: warnings
          build-depends: base"))

    ;; The grammar makes a comment that precedes a section the section's
    ;; first child, so the section node starts on the comment's line.
    ;; The `section_type' rule pins the header to column 0 regardless.
    (it "preserves a section preceded by a comment"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package
        -- a comment

        library
          build-depends: base"))

    (it "preserves a section with a comment directly above it"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        -- a comment
        library
          build-depends: base"))

    (it "preserves a comment inside a section body"
      (curry-cabal-test--expect-indent-preserved "
        cabal-version: 2.4
        name: my-package

        library
          build-depends: base
          -- note
          ghc-options: -Wall")))

  (describe "newline indentation"

    (when-newline-indenting-cabal-it "stays at column 0 after a top-level field"
      ("cabal-version: 2.4
name: my-package

library
  build-depends: base

version: 0.1.0.0" 0))

    (when-newline-indenting-cabal-it "opens the body after a section header"
      ("cabal-version: 2.4
name: my-package

library
  build-depends: base

executable my-exe" 2))

    (when-newline-indenting-cabal-it "stays in the body after a field"
      ("cabal-version: 2.4
name: my-package

library
  build-depends: base" 2))))

(describe "curry-cabal-mode navigation"
  (before-all
    (curry-test-skip-unless-grammar 'cabal))

  (describe "defun-name"

    (it "names a library section"
      (with-curry-cabal-buffer "
        cabal-version: 2.4
        name: my-package

        library
          build-depends: base"
        (search-forward "build-depends")
        (expect (add-log-current-defun) :to-equal "library")))

    (it "names an executable section with its section name"
      (with-curry-cabal-buffer "
        cabal-version: 2.4
        name: my-package

        executable my-exe
          main-is: Main.hs"
        (search-forward "main-is")
        (expect (add-log-current-defun) :to-equal "executable my-exe")))

    (it "renders underscores in node types as dashes"
      (with-curry-cabal-buffer "
        cabal-version: 2.4
        name: my-package

        test-suite spec
          type: exitcode-stdio-1.0"
        (search-forward "exitcode")
        (expect (add-log-current-defun) :to-equal "test-suite spec"))))

  (describe "imenu"

    (it "groups sections by kind"
      (with-curry-cabal-buffer "
        cabal-version: 2.4
        name: my-package

        library
          build-depends: base

        executable my-exe
          main-is: Main.hs

        test-suite spec
          type: exitcode-stdio-1.0"
        (let ((index (treesit-simple-imenu)))
          (expect (mapcar #'car index)
                  :to-equal '("Library" "Executable" "Test Suite"))
          (expect (car (nth 0 (alist-get "Executable" index nil nil #'equal)))
                  :to-equal "executable my-exe"))))

    (it "omits kinds that are not present"
      (with-curry-cabal-buffer "
        cabal-version: 2.4
        name: my-package

        library
          build-depends: base"
        (expect (mapcar #'car (treesit-simple-imenu)) :to-equal '("Library")))))

  (describe "beginning-of-defun"

    (it "moves to the start of the enclosing section"
      (with-curry-cabal-buffer "
        cabal-version: 2.4
        name: my-package

        library
          build-depends: base

        executable my-exe
          main-is: Main.hs"
        (goto-char (point-max))
        (beginning-of-defun)
        (expect (buffer-substring-no-properties (point) (line-end-position))
                :to-equal "executable my-exe")))))

(provide 'curry-cabal-test)

;;; curry-cabal-test.el ends here
