;;; curry-repl-test.el --- REPL tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for choosing the directory `curry-repl-start' runs
;; the REPL program in.

;;; Code:

(require 'curry-test-helpers)
(require 'curry-repl)

(defvar curry-repl-test--root nil
  "Temporary directory holding the projects for one spec.")

(defun curry-repl-test--make (&rest files)
  "Create FILES, relative to `curry-repl-test--root'.
Return the absolute name of the last one."
  (let (name)
    (dolist (file files name)
      (setq name (expand-file-name file curry-repl-test--root))
      (make-directory (file-name-directory name) t)
      (write-region "" nil name nil 'silent))))

(defun curry-repl-test--root-from (file program)
  "Return `curry-repl-project-root' for FILE with PROGRAM as the REPL."
  (let ((default-directory (file-name-directory file))
        (curry-repl-program-name program))
    (curry-repl-project-root)))

(defun curry-repl-test--dir (relative)
  "Return RELATIVE under `curry-repl-test--root' as a directory name."
  (file-name-as-directory (expand-file-name relative curry-repl-test--root)))

(describe "curry-repl-project-root"
  (before-each
    (setq curry-repl-test--root
          (file-name-as-directory
           (file-truename (make-temp-file "curry-repl-test" t)))))
  (after-each
    (delete-directory curry-repl-test--root t))

  (it "finds the package directory for cabal repl"
    (let ((file (curry-repl-test--make "pkg/pkg.cabal"
                                       "pkg/src/Data/Thing.hs")))
      (expect (curry-repl-test--root-from file "cabal repl")
              :to-equal (curry-repl-test--dir "pkg"))))

  (it "prefers a cabal.project above the package"
    (let ((file (curry-repl-test--make "cabal.project"
                                       "pkg/pkg.cabal"
                                       "pkg/src/Thing.hs")))
      (expect (curry-repl-test--root-from file "cabal repl")
              :to-equal curry-repl-test--root)))

  (it "recognises cabal given as a path"
    (let ((file (curry-repl-test--make "pkg/pkg.cabal" "pkg/src/Thing.hs")))
      (expect (curry-repl-test--root-from file "/usr/local/bin/cabal repl")
              :to-equal (curry-repl-test--dir "pkg"))))

  (it "finds the stack.yaml directory for stack ghci"
    (let ((file (curry-repl-test--make "stack.yaml"
                                       "pkg/pkg.cabal"
                                       "pkg/src/Thing.hs")))
      (expect (curry-repl-test--root-from file "stack ghci")
              :to-equal curry-repl-test--root)))

  (it "returns nil for plain ghci, even inside a Cabal project"
    (let ((file (curry-repl-test--make "pkg/pkg.cabal" "pkg/src/Thing.hs")))
      (expect (curry-repl-test--root-from file "ghci") :to-be nil)))

  (it "returns nil for cabal repl outside a Cabal project"
    (let ((file (curry-repl-test--make "scripts/Thing.hs")))
      (expect (curry-repl-test--root-from file "cabal repl") :to-be nil))))

(describe "curry-repl-start"
  :var (started-in)
  (before-each
    (setq started-in nil)
    (spy-on 'make-comint-in-buffer
            :and-call-fake
            (lambda (_name buffer &rest _)
              (setq started-in
                    (buffer-local-value 'default-directory
                                        (get-buffer buffer)))
              (get-buffer buffer)))
    (spy-on 'pop-to-buffer))
  (after-each
    (when (get-buffer curry-repl-buffer-name)
      (kill-buffer curry-repl-buffer-name)))

  (it "starts the program in the directory from curry-repl-root-function"
    (let ((default-directory "/tmp/src/Data/")
          (curry-repl-root-function (lambda () "/tmp/"))
          (curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (curry-repl-start)
      (expect started-in :to-equal "/tmp/")))

  (it "treats a root without a trailing slash as a directory"
    (let ((default-directory "/tmp/src/Data/")
          (curry-repl-root-function (lambda () "/tmp/src"))
          (curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (curry-repl-start)
      (expect started-in :to-equal "/tmp/src/")))

  (it "falls back to the current directory when the function returns nil"
    (let ((default-directory "/tmp/src/Data/")
          (curry-repl-root-function #'ignore)
          (curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (curry-repl-start)
      (expect started-in :to-equal "/tmp/src/Data/")))

  (it "runs the mode hooks in the new directory before starting the program"
    (with-current-buffer (get-buffer-create curry-repl-buffer-name)
      (setq default-directory "/elsewhere/")
      (let ((curry-repl-history-file nil)
            (curry-repl-fontify-input nil))
        (curry-repl-mode)))
    (let* ((default-directory "/tmp/src/")
           (curry-repl-root-function (lambda () "/tmp/"))
           (curry-repl-history-file nil)
           (curry-repl-fontify-input nil)
           (hook-calls nil)
           (curry-repl-mode-hook
            (list (lambda ()
                    (push (list default-directory
                                (spy-calls-any 'make-comint-in-buffer))
                          hook-calls)))))
      (curry-repl-start)
      (expect hook-calls :to-equal '(("/tmp/" nil)))))

  (it "resets the directory of a REPL buffer left from an earlier session"
    (with-current-buffer (get-buffer-create curry-repl-buffer-name)
      (setq default-directory "/elsewhere/"))
    (let ((default-directory "/tmp/src/")
          (curry-repl-root-function (lambda () "/tmp/"))
          (curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (curry-repl-start)
      (expect started-in :to-equal "/tmp/"))))

;;; curry-repl-test.el ends here
