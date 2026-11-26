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

(defun curry-repl-test--kill-repls ()
  "Kill every REPL buffer, and any process in it."
  (dolist (buffer (buffer-list))
    (when (with-current-buffer buffer
            (or (derived-mode-p 'curry-repl-mode)
                (string-prefix-p "*GHCi" (buffer-name))))
      (when-let* ((process (get-buffer-process buffer)))
        (set-process-query-on-exit-flag process nil)
        (delete-process process))
      (kill-buffer buffer))))

(defun curry-repl-test--leftover (root directory)
  "Create a REPL buffer for ROOT, with no process, in DIRECTORY."
  (with-current-buffer (get-buffer-create
                        (curry-repl--buffer-name root))
    (setq default-directory directory)
    (let ((curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (curry-repl-mode))
    (setq curry-repl--root root)
    (current-buffer)))

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
    (curry-repl-test--kill-repls))

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
    (curry-repl-test--leftover "/tmp/" "/elsewhere/")
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
    (let ((leftover (curry-repl-test--leftover "/tmp/" "/elsewhere/"))
          (default-directory "/tmp/src/")
          (curry-repl-root-function (lambda () "/tmp/"))
          (curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (expect (curry-repl-start) :to-be leftover)
      (expect started-in :to-equal "/tmp/"))))

(defun curry-repl-test--start-in (root)
  "Start the REPL from a buffer whose project root is ROOT."
  (let ((default-directory "/nonexistent/")
        (curry-repl-root-function (lambda () root))
        (curry-repl-history-file nil)
        (curry-repl-fontify-input nil))
    (curry-repl-start)))

(describe "one REPL per project"
  (before-each
    (spy-on 'make-comint-in-buffer
            :and-call-fake (lambda (_name buffer &rest _) (get-buffer buffer)))
    (spy-on 'pop-to-buffer))
  (after-each
    (curry-repl-test--kill-repls))

  (it "names each REPL after its project root"
    (expect (buffer-name (curry-repl-test--start-in "/work/alpha/"))
            :to-equal "*GHCi: alpha*")
    (expect (buffer-name (curry-repl-test--start-in "/work/beta"))
            :to-equal "*GHCi: beta*"))

  (it "uses curry-repl-buffer-name as it is when there is no root"
    (expect (buffer-name (curry-repl-test--start-in nil))
            :to-equal "*GHCi*"))

  (it "keeps a custom buffer name without asterisks"
    (let ((curry-repl-buffer-name "GHCi"))
      (expect (buffer-name (curry-repl-test--start-in "/work/alpha/"))
              :to-equal "GHCi: alpha")))

  (it "gives different roots with the same directory name their own REPLs"
    (let ((first (curry-repl-test--start-in "/work/pkg/"))
          (second (curry-repl-test--start-in "/home/pkg/")))
      (expect second :not :to-be first)
      (expect (buffer-name second) :to-equal "*GHCi: pkg*<2>")))

  (it "reuses the REPL buffer of the same root"
    (expect (curry-repl-test--start-in "/work/alpha/")
            :to-be (curry-repl-test--start-in "/work/alpha")))

  (it "finds a REPL buffer from inside it"
    (with-current-buffer (curry-repl-test--start-in "/work/alpha/")
      (let ((curry-repl-root-function (lambda () "/work/beta/")))
        (expect (curry-repl--buffer) :to-be (current-buffer)))))

  (it "records the source buffer in that project's REPL"
    (let ((curry-repl-history-file nil)
          (curry-repl-fontify-input nil)
          (default-directory "/nonexistent/"))
      (with-temp-buffer
        (let ((source (current-buffer))
              (curry-repl-root-function (lambda () "/work/alpha/")))
          (curry-repl-switch-to-repl)
          (expect (buffer-local-value
                   'curry-repl--source-buffer
                   (curry-repl--find-buffer "/work/alpha/"))
                  :to-be source))))))

(defun curry-repl-test--send-from (root string)
  "Send STRING to the REPL of ROOT, running `cat' as the REPL."
  (with-temp-buffer
    (let ((default-directory root)
          (curry-repl-program-name "cat")
          (curry-repl-program-args nil)
          (curry-repl-root-function (lambda () default-directory))
          (curry-repl-history-file nil)
          (curry-repl-fontify-input nil))
      (curry-repl--send-string string)
      (let ((process (curry-repl--process)))
        (set-process-query-on-exit-flag process nil)
        (accept-process-output process 1)
        (process-buffer process)))))

(describe "sending to the project's REPL"
  :var (roots)
  (before-each
    (setq roots (list (file-name-as-directory
                       (file-truename (make-temp-file "curry-repl-a" t)))
                      (file-name-as-directory
                       (file-truename (make-temp-file "curry-repl-b" t)))))
    (spy-on 'pop-to-buffer))
  (after-each
    (curry-repl-test--kill-repls)
    (dolist (root roots) (delete-directory root t)))

  (it "sends each buffer's input to the REPL of its own project"
    (let ((a (curry-repl-test--send-from (nth 0 roots) "from-a"))
          (b (curry-repl-test--send-from (nth 1 roots) "from-b")))
      (expect a :not :to-be b)
      (expect (with-current-buffer a (buffer-string)) :to-match "from-a")
      (expect (with-current-buffer a (buffer-string)) :not :to-match "from-b")
      (expect (with-current-buffer b (buffer-string)) :to-match "from-b"))))

;;; curry-repl-test.el ends here
