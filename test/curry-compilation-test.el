;;; curry-compilation-test.el --- Compilation regexp tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for `curry--compilation-error-regexp': GHC errors and
;; warnings must be told apart so they get different faces, in both
;; `compilation-mode' and the GHCi REPL.

;;; Code:

(require 'curry-test-helpers)
(require 'compile)
(require 'curry-repl)

(defconst curry-compilation-test--output
  (concat
   "Foo.hs:10:5: error: [GHC-88464]\n"
   "    Variable not in scope: frob\n"
   "Foo.hs:3:1: warning: [GHC-40910] [-Wunused-top-binds]\n"
   "    Defined but not used: `helper'\n"
   "Foo.hs:12:7-15: error: [GHC-83865]\n"
   "    Couldn't match expected type\n"
   "Foo.hs:(20,1)-(22,9): warning: [GHC-62161] [-Wincomplete-patterns]\n"
   "    Pattern match(es) are non-exhaustive\n")
  "Sample GHC output with errors and warnings in each location format.")

(defun curry-compilation-test--messages (setup)
  "Parse the sample output in a buffer prepared by SETUP.
Return a list of (LINE COL TYPE) for each message found, where TYPE
is `error', `warning' or `info'."
  (with-temp-buffer
    (insert curry-compilation-test--output)
    (funcall setup)
    (compilation--ensure-parse (point-max))
    (let (result)
      (goto-char (point-min))
      (while (not (eobp))
        (let ((msg (get-text-property (point) 'compilation-message)))
          (when msg
            (let ((loc (compilation--message->loc msg)))
              (push (list (compilation--loc->line loc)
                          (compilation--loc->col loc)
                          (pcase (compilation--message->type msg)
                            (2 'error) (1 'warning) (_ 'info)))
                    result))))
        (forward-line 1))
      (nreverse result))))

(defconst curry-compilation-test--expected
  '((10 5 error) (3 1 warning) (12 7 error) (20 1 warning))
  "Messages expected from `curry-compilation-test--output'.")

(describe "curry--compilation-error-regexp"
  (it "tells GHC errors from warnings in compilation-mode"
    (expect (curry-compilation-test--messages #'compilation-mode)
            :to-equal curry-compilation-test--expected))

  (it "tells GHC errors from warnings in the GHCi REPL"
    (expect (curry-compilation-test--messages
             (lambda ()
               ;; Avoid reading the user's history file.
               (let ((curry-repl-history-file nil))
                 (curry-repl-mode))))
            :to-equal curry-compilation-test--expected)))

;;; curry-compilation-test.el ends here
