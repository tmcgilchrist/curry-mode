;;; curry-cabal-mode.el --- Major mode for Cabal files -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist
;;
;; Author: Tim McGilchrist <timmcgil@gmail.com>
;;         Bozhidar Batsov <bozhidar@batsov.dev>
;; Maintainer: Tim McGilchrist <timmcgil@gmail.com>
;; URL: https://github.com/tmcgilchrist/curry-mode
;; Keywords: languages haskell cabal

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Tree-sitter based major mode for editing Cabal package description files.
;; For the tree-sitter grammar this mode is based on,
;; see https://gitlab.com/magus/tree-sitter-cabal.

;;; License:

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 3
;; of the License, or (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Code:

(require 'treesit)

(defgroup curry-cabal nil
  "Major mode for editing Cabal files with tree-sitter."
  :prefix "curry-cabal-"
  :group 'languages
  :link '(url-link :tag "GitHub" "https://github.com/tmcgilchrist/curry-mode"))

(defcustom curry-cabal-indent-offset 2
  "Number of spaces for each indentation step in `curry-cabal-mode'.
Cabal files conventionally use 2-space indentation."
  :type 'natnum
  :safe 'natnump
  :group 'curry-cabal
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-cabal-format-command '("cabal-fmt")
  "Command used by `curry-cabal-format-buffer', as (PROGRAM ARGS...).
The command must read a Cabal file on standard input and write the
formatted file to standard output.  cabal-fmt and cabal-gild both do
so when given no file argument.

haskell-language-server can also format Cabal files, defaulting to
cabal-gild, but it runs the same executables, so it still needs one
of them on the PATH."
  :type '(choice (const :tag "cabal-fmt" ("cabal-fmt"))
                 (const :tag "cabal-gild" ("cabal-gild"))
                 (cons :tag "Other command"
                       (string :tag "Program")
                       (repeat :tag "Arguments" string)))
  :group 'curry-cabal
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-cabal-format-on-save nil
  "When non-nil, format the buffer before saving.
Formatting uses `curry-cabal-format-command'."
  :type 'boolean
  :safe #'booleanp
  :group 'curry-cabal
  :package-version '(curry-mode . "0.1.0"))

;;; Grammar installation

;; Follows a branch until there is a tagged release (see ROADMAP.md).
(defconst curry-cabal-grammar-recipes
  '((cabal "https://gitlab.com/tmcgilchrist/tree-sitter-cabal.git"
           "main"
           "src"))
  "Tree-sitter grammar recipe for Cabal files.
Each entry is a list of (LANGUAGE URL REV SOURCE-DIR).
Suitable for use as the value of `treesit-language-source-alist'.")

(defun curry-cabal-install-grammar (&optional force)
  "Install the Cabal tree-sitter grammar if not already available.
With prefix argument FORCE, reinstall even if already installed."
  (interactive "P")
  (when (or force (not (treesit-language-available-p 'cabal nil)))
    (message "Installing cabal tree-sitter grammar...")
    (let ((treesit-language-source-alist curry-cabal-grammar-recipes))
      (treesit-install-language-grammar 'cabal))))

;;; Formatting

(defconst curry-cabal--format-max-secs 1
  "Seconds `curry-cabal-format-buffer' may spend diffing the output.")

;; A primitive taking a buffer since Emacs 31; older versions use the
;; `replace-buffer-contents' fallback below.
(declare-function replace-region-contents "editfns.c")

(defun curry-cabal--replace-text (source)
  "Replace the current buffer's text with that of buffer SOURCE.
Only the parts that differ are replaced, so point and markers stay on
the same text, and nothing happens when the texts are equal.  When
diffing takes longer than `curry-cabal--format-max-secs', the whole
text is replaced instead, and point and the window start are put back
at their old positions."
  (let ((case-fold-search nil)
        (pos (point))
        (start (window-start)))
    (unless (or (zerop (compare-buffer-substrings nil nil nil source nil nil))
                (if (>= emacs-major-version 31)
                    (replace-region-contents (point-min) (point-max) source
                                             curry-cabal--format-max-secs)
                  (with-suppressed-warnings ((obsolete replace-buffer-contents))
                    (replace-buffer-contents source
                                             curry-cabal--format-max-secs))))
      (goto-char (min pos (point-max)))
      (set-window-start nil start))))

(defun curry-cabal-format-buffer ()
  "Format the current buffer using `curry-cabal-format-command'.
Pipe the buffer through the command and replace only the text that
changed, so point and markers stay put.  The command's stderr is kept
out of the buffer and shown only if it fails."
  (interactive)
  (let ((program (car curry-cabal-format-command))
        (args (cdr curry-cabal-format-command)))
    (unless (executable-find program)
      (user-error "Cannot format: %s is not installed (see `%s')"
                  program 'curry-cabal-format-command))
    (let ((outbuf (generate-new-buffer " *curry-cabal-format*"))
          (errfile (make-temp-file "curry-cabal-format-err")))
      (unwind-protect
          (if (zerop (apply #'call-process-region (point-min) (point-max)
                            program nil (list outbuf errfile) nil args))
              (curry-cabal--replace-text outbuf)
            (user-error "Formatting with %s failed: %s" program
                        (with-temp-buffer
                          (insert-file-contents errfile)
                          (string-trim (buffer-string)))))
        (kill-buffer outbuf)
        (delete-file errfile)))))

(defun curry-cabal--format-before-save ()
  "Format the buffer before saving if `curry-cabal-format-on-save' is non-nil."
  (when curry-cabal-format-on-save
    (curry-cabal-format-buffer)))

;;; Font-lock

(defvar curry-cabal--font-lock-settings
  (treesit-font-lock-rules
   :language 'cabal
   :feature 'comment
   '((comment) @font-lock-comment-face)

   :language 'cabal
   :feature 'keyword
   '((section_type) @font-lock-keyword-face
     "cabal-version" @font-lock-keyword-face
     "if" @font-lock-keyword-face
     "elif" @font-lock-keyword-face
     "else" @font-lock-keyword-face)

   :language 'cabal
   :feature 'property
   '((field_name) @font-lock-property-name-face)

   :language 'cabal
   :feature 'constant
   '((spec_version) @font-lock-constant-face)

   :language 'cabal
   :feature 'type
   '((section_name) @font-lock-type-face))
  "Font-lock settings for `curry-cabal-mode'.")

;;; Indentation

(defconst curry-cabal--section-keyword-regexp
  (regexp-opt '("library" "executable" "test-suite" "benchmark"
                "common" "flag" "source-repository")
              'words)
  "Regexp matching the keyword that opens a Cabal section.
Matches the keyword as it appears in the buffer, so it spells
`test-suite' and `source-repository' with dashes rather than the
underscores used by the corresponding node types.")

(defun curry-cabal--after-section-header-p (_node _parent bol &rest _)
  "Return non-nil when the line at BOL follows a section header.
A section header with no body yet does not parse as a section: the
grammar reports it as (ERROR (section_type) (section_name)), so no
parent-is rule can match and the new line would open at column 0.
Recognise the header textually instead, so that pressing RET after
typing one opens the body at the right column."
  (save-excursion
    (goto-char bol)
    (forward-line -1)
    (while (and (not (bobp)) (looking-at-p "[ \t]*$"))
      (forward-line -1))
    (looking-at-p (concat "[ \t]*" curry-cabal--section-keyword-regexp))))

(defvar curry-cabal--indent-rules
  `((cabal
     ;; A section header always sits at column 0.  The grammar makes a
     ;; comment that precedes a section the section's first child, which
     ;; moves the section's start onto the comment's line; without this
     ;; rule the section rules below would then indent the header itself.
     ((node-is "section_type") column-0 0)
     ;; Opening the body of a section that does not parse as one yet.
     (curry-cabal--after-section-header-p
      prev-line curry-cabal-indent-offset)
     ((parent-is "cabal") column-0 0)
     ;; Properties at the top level
     ((parent-is "properties") column-0 0)
     ;; Sections at the top level
     ((parent-is "sections") column-0 0)
     ;; Fields within sections.  These anchor on the grandparent -- the
     ;; section or conditional owning the block -- rather than on the
     ;; block itself.  The scanner emits a zero-width `indent' token at
     ;; the first field, so the block starts on that field's line and
     ;; `parent-bol' would measure the body from its own first line,
     ;; pushing every later field one level deeper on each re-indent.
     ((parent-is "property_block") grand-parent curry-cabal-indent-offset)
     ((parent-is "property_or_conditional_block")
      grand-parent curry-cabal-indent-offset)
     ;; Conditionals
     ((parent-is "conditional") parent-bol 0)
     ((parent-is "condition_if") parent-bol curry-cabal-indent-offset)
     ((parent-is "condition_elseif") parent-bol curry-cabal-indent-offset)
     ((parent-is "condition_else") parent-bol curry-cabal-indent-offset)
     ;; Section bodies
     ((parent-is "library") parent-bol curry-cabal-indent-offset)
     ((parent-is "executable") parent-bol curry-cabal-indent-offset)
     ((parent-is "test_suite") parent-bol curry-cabal-indent-offset)
     ((parent-is "benchmark") parent-bol curry-cabal-indent-offset)
     ((parent-is "common") parent-bol curry-cabal-indent-offset)
     ((parent-is "flag") parent-bol curry-cabal-indent-offset)
     ((parent-is "source_repository") parent-bol curry-cabal-indent-offset)
     ;; Field values continuing on next line
     ((parent-is "field") parent-bol curry-cabal-indent-offset)
     ;; Fallback
     (no-node prev-line 0)))
  "Indentation rules for `curry-cabal-mode'.")

;;; Imenu

(defvar curry-cabal--imenu-settings
  '(("Library" "\\`library\\'" nil nil)
    ("Executable" "\\`executable\\'" nil nil)
    ("Test Suite" "\\`test_suite\\'" nil nil)
    ("Benchmark" "\\`benchmark\\'" nil nil)
    ("Common" "\\`common\\'" nil nil)
    ("Flag" "\\`flag\\'" nil nil)
    ("Source Repository" "\\`source_repository\\'" nil nil))
  "Imenu settings for `curry-cabal-mode'.
See `treesit-simple-imenu-settings' for the format.")

;;; Navigation

(defvar curry-cabal--defun-type-regexp
  (regexp-opt '("library" "executable" "test_suite" "benchmark"
                "common" "flag" "source_repository"))
  "Regex matching Cabal section node types treated as defun-like.")

(defun curry-cabal--defun-name (node)
  "Return a name for NODE suitable for imenu and which-func.
For sections, returns the section type and its name if present."
  (let ((type (treesit-node-type node)))
    (when (string-match-p curry-cabal--defun-type-regexp type)
      (let ((name-node (treesit-search-subtree node "section_name" nil nil 1)))
        (if name-node
            (format "%s %s"
                    (replace-regexp-in-string "_" "-" type)
                    (treesit-node-text name-node t))
          (replace-regexp-in-string "_" "-" type))))))

;;; Mode definition

;;;###autoload
(define-derived-mode curry-cabal-mode prog-mode "Cabal"
  "Major mode for editing Cabal package description files.

\\{curry-cabal-mode-map}"
  (when (< (treesit-library-abi-version) 15)
    (error "The cabal grammar needs libtree-sitter 0.25 or newer"))
  (unless (treesit-ready-p 'cabal)
    (when (y-or-n-p
           "Cabal tree-sitter grammar is not installed.  Install now?")
      (curry-cabal-install-grammar))
    (unless (treesit-ready-p 'cabal)
      (error "Cannot activate curry-cabal-mode without the cabal grammar")))

  (condition-case err
      (treesit-parser-create 'cabal)
    (treesit-error
     (message "curry-cabal: grammar failed to parse (possibly merge \
conflict markers?): %s" err)
     (fundamental-mode)))

  ;; Comments
  (setq-local comment-start "-- ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "--+ *")

  ;; Font-lock
  (setq-local treesit-font-lock-settings curry-cabal--font-lock-settings)
  (setq-local treesit-font-lock-feature-list
              '((comment keyword)
                (property)
                (constant type)
                ()))

  ;; Indentation
  (setq-local treesit-simple-indent-rules curry-cabal--indent-rules)
  (setq-local indent-tabs-mode nil)

  ;; Imenu
  (setq-local treesit-simple-imenu-settings curry-cabal--imenu-settings)

  ;; Navigation
  (setq-local treesit-defun-type-regexp curry-cabal--defun-type-regexp)
  (setq-local treesit-defun-name-function #'curry-cabal--defun-name)

  ;; which-func-mode / add-log integration
  (setq-local add-log-current-defun-function #'treesit-add-log-current-defun)

  ;; Format on save
  (add-hook 'before-save-hook #'curry-cabal--format-before-save nil t)

  ;; Final newline
  (setq-local require-final-newline mode-require-final-newline)

  (treesit-major-mode-setup))

(define-key curry-cabal-mode-map (kbd "C-c C-f") #'curry-cabal-format-buffer)

;;;###autoload
(add-to-list 'auto-mode-alist '("\\.cabal\\'" . curry-cabal-mode))

(provide 'curry-cabal-mode)

;;; curry-cabal-mode.el ends here
