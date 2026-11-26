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

(defun curry-repl-test--command-from (file program &optional args)
  "Return `curry-repl--command' for FILE with PROGRAM and ARGS."
  (let ((default-directory (file-name-directory file))
        (curry-repl-program-name program)
        (curry-repl-program-args args)
        (curry-cabal-program "cabal"))
    (curry-repl--command)))

(describe "curry-repl-program-name set to auto"
  (before-each
    (setq curry-repl-test--root
          (file-name-as-directory
           (file-truename (make-temp-file "curry-repl-test" t)))))
  (after-each
    (delete-directory curry-repl-test--root t))

  (it "runs cabal repl from a cabal.project, with the file's package"
    (let ((file (curry-repl-test--make "cabal.project"
                                       "stack.yaml"
                                       "a/a.cabal"
                                       "b/b.cabal"
                                       "b/src/Thing.hs")))
      (expect (curry-repl-test--command-from file 'auto)
              :to-equal '("cabal" "repl" "b"))
      (expect (curry-repl-test--root-from file 'auto)
              :to-equal curry-repl-test--root)))

  (it "runs stack ghci from a stack.yaml when there is no cabal.project"
    (let ((file (curry-repl-test--make "stack.yaml"
                                       "pkg/pkg.cabal"
                                       "pkg/src/Thing.hs")))
      (expect (curry-repl-test--command-from file 'auto)
              :to-equal '("stack" "ghci"))
      (expect (curry-repl-test--root-from file 'auto)
              :to-equal curry-repl-test--root)))

  (it "runs cabal repl from a lone .cabal file"
    (let ((file (curry-repl-test--make "pkg/pkg.cabal" "pkg/src/Thing.hs")))
      (expect (curry-repl-test--command-from file 'auto)
              :to-equal '("cabal" "repl" "pkg"))
      (expect (curry-repl-test--root-from file 'auto)
              :to-equal (curry-repl-test--dir "pkg"))))

  (it "runs ghci outside any project"
    (let ((file (curry-repl-test--make "scripts/Thing.hs")))
      (expect (curry-repl-test--command-from file 'auto) :to-equal '("ghci"))
      (expect (curry-repl-test--root-from file 'auto) :to-be nil)))

  (it "uses curry-cabal-program for cabal"
    (let ((file (curry-repl-test--make "pkg/pkg.cabal" "pkg/Thing.hs")))
      (let ((default-directory (file-name-directory file))
            (curry-repl-program-name 'auto)
            (curry-repl-program-args nil)
            (curry-cabal-program "/opt/cabal"))
        (expect (curry-repl--command) :to-equal '("/opt/cabal" "repl" "pkg"))))))

(describe "curry-repl--command"
  (before-each
    (setq curry-repl-test--root
          (file-name-as-directory
           (file-truename (make-temp-file "curry-repl-test" t)))))
  (after-each
    (delete-directory curry-repl-test--root t))

  (it "takes the package name from the .cabal file's name field"
    (let ((file (curry-repl-test--make "pkg/pkg.cabal" "pkg/src/Thing.hs")))
      (write-region "cabal-version: 3.0\nName:   real-name\n" nil
                    (expand-file-name "pkg/pkg.cabal" curry-repl-test--root)
                    nil 'silent)
      (expect (curry-repl-test--command-from file "cabal repl")
              :to-equal '("cabal" "repl" "real-name"))))

  (it "adds no package when a directory has several .cabal files"
    (let ((file (curry-repl-test--make "pkg/a.cabal" "pkg/b.cabal"
                                       "pkg/Thing.hs")))
      (expect (curry-repl-test--command-from file "cabal repl")
              :to-equal '("cabal" "repl"))))

  (it "adds no package when the command already names more"
    (let ((file (curry-repl-test--make "pkg/pkg.cabal" "pkg/Thing.hs")))
      (expect (curry-repl-test--command-from file "cabal repl exe:tool")
              :to-equal '("cabal" "repl" "exe:tool"))
      (expect (curry-repl-test--command-from file "cabal repl" '("test:spec"))
              :to-equal '("cabal" "repl" "test:spec"))))

  (it "runs other commands as given"
    (let ((file (curry-repl-test--make "pkg/pkg.cabal" "pkg/Thing.hs")))
      (expect (curry-repl-test--command-from file "ghci" '("-Wall"))
              :to-equal '("ghci" "-Wall"))
      (expect (curry-repl-test--command-from file "stack ghci")
              :to-equal '("stack" "ghci")))))

(describe "curry-repl--safe-program-p"
  (it "accepts auto and the standard commands"
    (dolist (value '(auto "ghci" "cabal repl" "stack ghci"))
      (expect (curry-repl--safe-program-p value) :to-be-truthy)))

  (it "rejects any other command"
    (dolist (value '("rm -rf ~" "cabal repl --with-ghc=./evil" nil 42))
      (expect (curry-repl--safe-program-p value) :not :to-be-truthy))))

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

  (it "runs ghci from a directory that no longer exists"
    (let ((default-directory "/nonexistent/curry-repl-test/")
          (curry-repl-program-name 'auto)
          (curry-repl-program-args nil)
          (curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (curry-repl-start)
      (expect started-in :to-equal "/nonexistent/curry-repl-test/")
      (expect (cddr (spy-calls-args-for 'make-comint-in-buffer 0))
              :to-equal '("ghci" nil))))

  (it "passes the program arguments to the process"
    (let ((default-directory "/nonexistent/curry-repl-test/")
          (curry-repl-program-name "ghci")
          (curry-repl-program-args '("-Wall" "-v0"))
          (curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (curry-repl-start)
      (expect (cddr (spy-calls-args-for 'make-comint-in-buffer 0))
              :to-equal '("ghci" nil "-Wall" "-v0"))))

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
