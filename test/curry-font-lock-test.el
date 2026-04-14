;;; curry-font-lock-test.el --- Font-lock tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for curry-mode font-locking at all feature levels.

;;; Code:

(require 'curry-test-helpers)

(describe "curry-mode font-lock"

  (describe "level 1: comments and definitions"

    (when-fontifying-it "fontifies line comments"
      ("-- a comment"
       ("-- a comment" font-lock-comment-face)))

    (when-fontifying-it "fontifies block comments"
      ("{- a block comment -}"
       ("{- a block comment -}" font-lock-comment-face)))

    (when-fontifying-it "fontifies haddock comments"
      ("-- | A haddock comment"
       ("-- | A haddock comment" font-lock-doc-face)))

    (when-fontifying-it "fontifies pragmas"
      ("{-# LANGUAGE GADTs #-}"
       ("{-# LANGUAGE GADTs #-}" font-lock-preprocessor-face)))

    (when-fontifying-it "fontifies function definitions"
      ("foo x y = x + y"
       ("foo" font-lock-function-name-face)))

    (when-fontifying-it "fontifies type signatures"
      ("foo :: Int -> Int"
       ("foo" font-lock-function-name-face))))

  (describe "level 2: keywords, strings, numbers"

    (when-fontifying-it "fontifies keywords"
      ("module Main where"
       ("module" font-lock-keyword-face)
       ("where" font-lock-keyword-face)))

    (when-fontifying-it "fontifies import keywords"
      ("import qualified Data.Map as Map"
       ("import" font-lock-keyword-face)
       ("qualified" font-lock-keyword-face)
       ("as" font-lock-keyword-face)))

    (when-fontifying-it "fontifies control keywords"
      ("if x then y else z"
       ("if" font-lock-keyword-face)
       ("then" font-lock-keyword-face)
       ("else" font-lock-keyword-face)))

    (when-fontifying-it "fontifies string literals"
      ("x = \"hello world\""
       ("\"hello world\"" font-lock-string-face)))

    (when-fontifying-it "fontifies character literals"
      ("x = 'a'"
       ("'a'" font-lock-string-face)))

    (when-fontifying-it "fontifies integer literals"
      ("x = 42"
       ("42" font-lock-number-face)))

    (when-fontifying-it "fontifies float literals"
      ("x = 3.14"
       ("3.14" font-lock-number-face))))

  (describe "level 3: types, constructors, modules"

    (when-fontifying-it "fontifies type names in signatures"
      ("foo :: Int -> String"
       ("Int" font-lock-type-face)
       ("String" font-lock-type-face)))

    (when-fontifying-it "fontifies data constructors"
      ("x = Just 42"
       ("Just" font-lock-constant-face)))

    (when-fontifying-it "fontifies boolean constructors"
      ("x = True"
       ("True" font-lock-constant-face)))

    (when-fontifying-it "fontifies module names"
      ("module Data.Map where"
       ("Data" font-lock-constant-face)
       ("Map" font-lock-constant-face))))

  (describe "level 4: operators, variables, functions, brackets"

    (when-fontifying-it "fontifies operators"
      ("x = a + b"
       ("+" font-lock-operator-face)))

    (when-fontifying-it "fontifies function application"
      ("x = map f xs"
       ("map" font-lock-function-call-face)))))

;;; curry-font-lock-test.el ends here
