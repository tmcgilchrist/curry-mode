;;; curry-indentation-test.el --- Indentation tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for curry-mode indentation.
;;
;; Haskell is layout-sensitive: indentation is part of the syntax.
;; The tree-sitter parser needs correct indentation to produce the
;; right parse tree, which means round-trip tests (strip all indent,
;; re-indent from scratch) cannot work for layout-dependent constructs
;; like where, do, case, class bodies etc.
;;
;; Instead we use two strategies:
;; - Round-trip tests for top-level and simple constructs where the
;;   parse tree is unaffected by stripping indentation.
;; - Newline-indent tests for layout-dependent constructs, which
;;   verify cursor position after pressing Enter on correctly-parsed code.

;;; Code:

(require 'curry-test-helpers)

(describe "curry-mode indentation"
  (before-all
    (unless (treesit-language-available-p 'haskell)
      (signal 'buttercup-pending "tree-sitter Haskell grammar not available")))

  (describe "top-level declarations"

    (when-indenting-it "keeps top-level bindings at column 0"
      "foo = 42"
      "bar = \"hello\"")

    (when-indenting-it "keeps type signatures at column 0"
      "foo :: Int -> Int")

    (when-indenting-it "keeps data declarations at column 0"
      "data Foo = Bar | Baz")

    (when-indenting-it "keeps class declarations at column 0"
      "class Eq a where")

    (when-indenting-it "keeps imports at column 0"
      "import Data.List"))

  (describe "do blocks"

    (when-indenting-it "indents do block statements"
      "main = do
  putStrLn \"hello\"
  putStrLn \"world\"")

    (when-indenting-it "indents do with let"
      "main = do
  let x = 42
  print x"))

  (describe "case expressions"

    (when-indenting-it "indents case alternatives"
      "foo x = case x of
  Nothing -> 0
  Just n -> n"))

  ;; Layout-dependent constructs: test via newline-indent.
  ;; These verify the cursor position after pressing Enter on
  ;; correctly-parsed code, which is the primary interactive use case.

  (describe "newline indentation after keywords"

    (when-newline-indenting-it "indents after where"
      ("foo = bar where" 2))

    (when-newline-indenting-it "indents after do"
      ("main = do" 2))

    (when-newline-indenting-it "indents after of"
      ("foo x = case x of" 2))

    (when-newline-indenting-it "indents after let"
      ("foo = let" 2))

    (when-newline-indenting-it "indents after ="
      ("foo x =" 2))

    (when-newline-indenting-it "indents after ->"
      ("foo x = case x of { Just n ->" 2))

    (when-newline-indenting-it "indents after then"
      ("foo = if True then" 2))

    (when-newline-indenting-it "indents after else"
      ("foo = if True then 1 else" 2))

    (when-newline-indenting-it "indents after \\"
      ("foo = \\" 2)))

  (describe "newline indentation preserves context"

    (when-newline-indenting-it "preserves indentation after statement"
      ("  putStrLn \"hello\"" 2))

    (when-newline-indenting-it "preserves indentation in do block"
      ("main = do\n  putStrLn \"hello\"" 2))

    (when-newline-indenting-it "preserves indentation in where body"
      ("foo = bar\n  where\n    x = 1" 4))

    (when-newline-indenting-it "preserves indentation in class body"
      ("class Foo a where\n  bar :: a -> Int" 2))

    (when-newline-indenting-it "preserves indentation in instance body"
      ("instance Foo Int where\n  bar n = n" 2)))

  (describe "newline indentation for data types"

    (when-newline-indenting-it "indents after data ="
      ("data Color =" 2))

    (when-newline-indenting-it "preserves indentation after constructor"
      ("data Color\n  = Red" 2)))

  (describe "newline indentation for guards"

    (when-newline-indenting-it "indents after | with ="
      ("  | x > 0 =" 4)))

  (describe "module and imports"

    (when-newline-indenting-it "indents after module name"
      ("module Foo" 2))))

;;; curry-indentation-test.el ends here
