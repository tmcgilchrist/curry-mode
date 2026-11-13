;;; curry-eglot-test.el --- Eglot integration tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for how curry-mode registers itself with eglot.

;;; Code:

(require 'curry-test-helpers)
(require 'eglot)

(defun curry-test--eglot-entries ()
  "Return the `eglot-server-programs' entries that name `curry-mode'."
  (seq-filter (lambda (entry)
                (let ((modes (car entry)))
                  (or (eq modes 'curry-mode)
                      (and (consp modes)
                           (or (eq (car modes) 'curry-mode)
                               (seq-some (lambda (m)
                                           (eq (car-safe m) 'curry-mode))
                                         modes))))))
              eglot-server-programs))

(describe "curry-mode eglot registration"
  (it "registers haskell-language-server for curry-mode"
    (expect (curry-test--eglot-entries)
            :to-equal '(((curry-mode :language-id "haskell")
                         "haskell-language-server-wrapper" "--lsp"))))

  (it "does not touch eglot-server-programs when a buffer opens"
    (curry-test-skip-unless-grammar)
    (let ((before (copy-sequence eglot-server-programs)))
      (with-curry-buffer "f = x"
        (expect eglot-server-programs :to-equal before)))))

;;; curry-eglot-test.el ends here
