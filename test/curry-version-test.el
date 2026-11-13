;;; curry-version-test.el --- Version tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for `curry-version'.

;;; Code:

(require 'curry-test-helpers)

(describe "curry-version"
  (it "reads the constant from the Version header"
    (expect curry-version :to-match "\\`[0-9]+\\(\\.[0-9]+\\)*\\'"))

  (it "returns the version without displaying it when called from Lisp"
    (spy-on 'message)
    (expect (curry-version) :to-equal curry-version)
    (expect 'message :not :to-have-been-called))

  (it "displays the version when called interactively"
    (spy-on 'message)
    (expect (call-interactively #'curry-version) :to-equal curry-version)
    (expect 'message :to-have-been-called-with "curry-mode %s" curry-version)))

;;; curry-version-test.el ends here
