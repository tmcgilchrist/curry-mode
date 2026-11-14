;;; curry-cabal-interaction-test.el --- Tests for curry-cabal-interaction -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for `curry-cabal-interaction-mode' commands.

;;; Code:

(require 'curry-test-helpers)
(require 'curry-cabal-interaction)

(defmacro with-curry-cabal-project (content &rest body)
  "Run BODY in a temporary project holding a.cabal with CONTENT.
`default-directory' is the project root, and the file's buffer, if
BODY visits it, is killed afterwards."
  (declare (indent 1))
  `(let* ((root (file-name-as-directory (make-temp-file "curry-cabal" t)))
          (cabal-file (expand-file-name "a.cabal" root))
          (default-directory root))
     (unwind-protect
         (progn
           (with-temp-file cabal-file (insert ,content))
           ,@body)
       (when-let* ((buffer (get-file-buffer cabal-file)))
         (with-current-buffer buffer (set-buffer-modified-p nil))
         (kill-buffer buffer))
       (delete-directory root t))))

(defun curry-test--file-contents (file)
  "Return the contents of FILE on disk."
  (with-temp-buffer
    (insert-file-contents file)
    (buffer-string)))

(describe "curry-cabal-format"
  ;; `tr' stands in for cabal-fmt and cabal-gild, so these exercise the
  ;; plumbing without either installed.
  (before-all
    (curry-test-skip-unless-grammar 'cabal))

  (it "formats the .cabal file with curry-cabal-format-command and saves it"
    (let ((curry-cabal-format-command '("tr" "a-z" "A-Z")))
      (with-curry-cabal-project "cabal-version: 2.4\nname: a\n"
        (curry-cabal-format)
        (expect (curry-test--file-contents cabal-file)
                :to-equal "CABAL-VERSION: 2.4\nNAME: A\n"))))

  (it "leaves a buffer with unsaved changes unsaved"
    (let ((curry-cabal-format-command '("tr" "a-z" "A-Z")))
      (with-curry-cabal-project "cabal-version: 2.4\nname: a\n"
        (with-current-buffer (find-file-noselect cabal-file)
          (goto-char (point-max))
          (insert "version: 0.1\n"))
        (curry-cabal-format)
        (expect (curry-test--file-contents cabal-file)
                :to-equal "cabal-version: 2.4\nname: a\n")
        (expect (with-current-buffer (get-file-buffer cabal-file)
                  (buffer-string))
                :to-equal "CABAL-VERSION: 2.4\nNAME: A\nVERSION: 0.1\n"))))

  (it "reports a project without a .cabal file"
    (let* ((root (file-name-as-directory (make-temp-file "curry-cabal" t)))
           (default-directory root))
      (unwind-protect
          (progn
            (with-temp-file (expand-file-name "cabal.project" root)
              (insert "packages: .\n"))
            (expect (curry-cabal-format) :to-throw 'user-error))
        (delete-directory root t)))))

;;; curry-cabal-interaction-test.el ends here
