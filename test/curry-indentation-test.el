;;; curry-indentation-test.el --- Indentation tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for curry-mode indentation.
;; Round-trip tests: strip indentation, re-indent, compare with original.
;; Newline tests: check cursor column after newline-and-indent.

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

  (describe "where clauses"

    (when-newline-indenting-it "indents after where"
      ("foo = bar where" 2))

    (when-indenting-it "indents where body"
      "foo = result
  where
    result = 42")

    (when-indenting-it "indents multiple where bindings"
      "foo = x + y
  where
    x = 1
    y = 2"))

  (describe "do blocks"

    (when-newline-indenting-it "indents after do"
      ("main = do" 2))

    (when-indenting-it "indents do block statements"
      "main = do
  putStrLn \"hello\"
  putStrLn \"world\"")

    (when-indenting-it "indents do with let"
      "main = do
  let x = 42
  print x"))

  (describe "case expressions"

    (when-newline-indenting-it "indents after of"
      ("foo x = case x of" 2))

    (when-indenting-it "indents case alternatives"
      "foo x = case x of
  Nothing -> 0
  Just n -> n"))

  (describe "let/in expressions"

    (when-newline-indenting-it "indents after let"
      ("foo = let" 2))

    (when-indenting-it "indents let bindings"
      "foo =
  let x = 1
  in x + 1"))

  (describe "guards"

    (when-newline-indenting-it "indents after ="
      ("foo x =" 2))

    (when-indenting-it "indents guarded equations"
      "foo x
  | x > 0 = \"positive\"
  | otherwise = \"non-positive\""))

  (describe "if/then/else"

    (when-newline-indenting-it "indents after then"
      ("foo = if True then" 2))

    (when-newline-indenting-it "indents after else"
      ("foo = if True then 1 else" 2))

    (when-indenting-it "indents if expression"
      "foo x =
  if x > 0
    then x
    else negate x"))

  (describe "class and instance declarations"

    (when-indenting-it "indents class body"
      "class MyClass a where
  myMethod :: a -> String
  myDefault :: a -> Int")

    (when-indenting-it "indents instance body"
      "instance MyClass Int where
  myMethod n = show n"))

  (describe "data types"

    (when-indenting-it "indents data constructors"
      "data Color
  = Red
  | Green
  | Blue")

    (when-indenting-it "indents record syntax"
      "data Person = Person
  { name :: String
  , age :: Int
  }"))

  (describe "lambda expressions"

    (when-newline-indenting-it "indents after lambda arrow"
      ("foo = \\x ->" 2)))

  (describe "lists and tuples"

    (when-indenting-it "indents list elements"
      "xs =
  [ 1
  , 2
  , 3
  ]"))

  (describe "module header"

    (when-indenting-it "indents export list"
      "module Foo
  ( bar
  , baz
  ) where"))

  (describe "imports"

    (when-indenting-it "indents import list"
      "import Data.List
  ( sort
  , nub
  )"))

  (describe "type signatures"

    (when-indenting-it "indents multiline type signature"
      "foo
  :: Int
  -> String
  -> Bool"))

  (describe "empty line indentation"

    (when-newline-indenting-it "indents after do keyword"
      ("main = do" 2))

    (when-newline-indenting-it "indents after where keyword"
      ("f x = y where" 2))

    (when-newline-indenting-it "indents after = sign"
      ("foo =" 2))

    (when-newline-indenting-it "indents after -> arrow"
      ("foo x = case x of { Just n ->" 2))

    (when-newline-indenting-it "indents after <- bind"
      ("  x <-" 2))

    (when-newline-indenting-it "preserves indentation after normal line"
      ("  putStrLn \"hello\"" 2))

    (when-newline-indenting-it "indents after let keyword"
      ("foo = let" 2))

    (when-newline-indenting-it "indents after pipe"
      ("  | x > 0 =" 2))))

;;; curry-indentation-test.el ends here
