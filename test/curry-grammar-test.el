;;; curry-grammar-test.el --- Grammar compatibility tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for the check that warns when the installed Haskell
;; grammar is older than the one curry-mode pins.

;;; Code:

(require 'curry-test-helpers)

(describe "curry-mode grammar compatibility"
  (before-all
    (curry-test-skip-unless-grammar))

  (describe "curry--grammar-outdated-p"
    (it "accepts the pinned grammar"
      (expect (curry--grammar-outdated-p) :to-be nil))

    (it "flags a grammar that lacks a probed node type"
      (let ((curry--grammar-probes
             (append curry--grammar-probes
                     '(("f = x" . "curry_no_such_node")))))
        (expect (curry--grammar-outdated-p) :to-be-truthy)))

    (it "matches node types exactly, not as a substring"
      ;; The parse contains `type_synonym', which must not count as a
      ;; node of type `synonym'.
      (let ((curry--grammar-probes '(("type X = Int" . "synonym"))))
        (expect (curry--grammar-outdated-p) :to-be-truthy))))

  (describe "curry--check-grammar-compatibility"
    (before-each
      (spy-on 'display-warning))

    (it "does not warn about the pinned grammar"
      (let ((curry--grammar-compatibility-checked nil))
        (curry--check-grammar-compatibility)
        (expect 'display-warning :not :to-have-been-called)))

    (it "warns once per session about an outdated grammar"
      (let ((curry--grammar-compatibility-checked nil)
            (curry--grammar-probes '(("f = x" . "curry_no_such_node"))))
        (curry--check-grammar-compatibility)
        (curry--check-grammar-compatibility)
        (expect 'display-warning :to-have-been-called-times 1)
        (expect (car (spy-calls-args-for 'display-warning 0))
                :to-equal 'curry-mode)))

    (it "runs when curry-mode starts"
      (spy-on 'curry--check-grammar-compatibility)
      (with-curry-buffer "f = x"
        (expect 'curry--check-grammar-compatibility
                :to-have-been-called)))))

;;; curry-grammar-test.el ends here
