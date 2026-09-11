;;; curry-test-helpers.el --- Shared test helpers for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Shared macros and functions used across curry-mode buttercup test suites.
;; Provides unified buffer setup, font-lock assertion helpers, and
;; indentation test macros.

;;; Code:

(require 'buttercup)
(require 'curry-mode)

;;;; Grammar availability

;; Suites guard themselves with `curry-test-skip-unless-grammar' in a
;; `before-all' rather than installing grammars on load: requiring this
;; file should not shell out to a C compiler, and a developer without
;; the grammar should get pending specs instead of a build.  CI installs
;; the grammars explicitly before running `eldev test'.

(defvar curry-test--grammar-status nil
  "Cached result of `curry-test-grammar-status'.
Nil until first probed; afterwards one of the symbols it returns.")

(defun curry-test-grammar-status ()
  "Return the state of the Haskell grammar as a symbol.
One of `ready', `missing', or `outdated'.  A grammar is `outdated' when
it parses but lacks the `type_synonym' node type, which was spelled
`type_synomym' in older releases.  The result is cached."
  (or curry-test--grammar-status
      (setq curry-test--grammar-status
            (cond
             ((not (treesit-language-available-p 'haskell)) 'missing)
             ((with-temp-buffer
                (insert "type X = Int")
                (treesit-parser-create 'haskell)
                (treesit-search-subtree
                 (treesit-buffer-root-node) "type_synonym"))
              'ready)
             (t 'outdated)))))

(defun curry-test-skip-unless-grammar ()
  "Mark the current suite pending unless a current Haskell grammar is installed.
Call from a `before-all' block."
  (pcase (curry-test-grammar-status)
    ('missing
     (signal 'buttercup-pending "tree-sitter Haskell grammar not available"))
    ('outdated
     (signal 'buttercup-pending
             "tree-sitter Haskell grammar is outdated (no `type_synonym' \
node type); reinstall with M-x curry-install-grammars"))))

(defun curry-test-skip-unless-emacs-30 ()
  "Mark the current suite pending unless `treesit-thing-settings' exists.
Call from a `before-all' block."
  (unless (boundp 'treesit-thing-settings)
    (signal 'buttercup-pending
            "treesit-thing-settings not available (requires Emacs 30+)")))

;;;; String helpers

(defun curry-test--dedent (string)
  "Remove common leading whitespace from all non-empty lines in STRING.
A single leading newline is stripped (so the string can start on the
line after the opening quote), and a single trailing newline followed
by only whitespace is stripped (so the closing quote can sit on its
own indented line).  Interior blank lines are preserved.

  (curry-test--dedent \"
    main :: IO ()
    main = putStrLn \\\"hello\\\"\")

produces \"main :: IO ()\\nmain = putStrLn \\\"hello\\\"\"."
  (if (not (string-search "\n" string))
      string
    (let* ((str (if (string-prefix-p "\n" string)
                    (substring string 1)
                  string))
           (str (if (string-match "\n[ \t]*\\'" str)
                    (substring str 0 (match-beginning 0))
                  str))
           (lines (split-string str "\n"))
           (non-empty (seq-filter (lambda (l) (not (string-blank-p l))) lines))
           (min-indent (if non-empty
                          (apply #'min (mapcar (lambda (l)
                                                (- (length l)
                                                   (length (string-trim-left l))))
                                              non-empty))
                        0)))
      (mapconcat (lambda (l)
                   (if (string-blank-p l) ""
                     (substring l min-indent)))
                 lines "\n"))))

;;;; Buffer setup

(defmacro with-curry-test-buffer (mode content &rest body)
  "Set up a temporary buffer with CONTENT in MODE, run BODY.
MODE should be a symbol like `curry-mode'.
CONTENT is automatically dedented via `curry-test--dedent'."
  (declare (indent 2))
  `(with-temp-buffer
     (insert (curry-test--dedent ,content))
     (funcall #',mode)
     (goto-char (point-min))
     ,@body))

(defmacro with-curry-buffer (content &rest body)
  "Set up a temporary buffer with CONTENT in `curry-mode', run BODY.
CONTENT is automatically dedented via `curry-test--dedent'."
  (declare (indent 1))
  `(with-curry-test-buffer curry-mode ,content ,@body))

;;;; Font-lock helpers

(defun curry-test-face-at-range (start end)
  "Return the face at range [START, END] in the current buffer.
If all positions in the range share the same face, return it.
Otherwise return the symbol `various-faces'."
  (let ((face (get-text-property start 'face)))
    (if (= start end)
        face
      (let ((pos (1+ start))
            (consistent t))
        (while (and consistent (<= pos end))
          (unless (equal (get-text-property pos 'face) face)
            (setq consistent nil))
          (setq pos (1+ pos)))
        (if consistent face 'various-faces)))))

(defun curry-test--face-target (target)
  "Resolve TARGET to a (START END DESCRIPTION) list in the current buffer.
TARGET is one of:
  - a string, searched for sequentially from point (whole identifiers are
    matched on symbol boundaries, other text literally);
  - a position (integer);
  - a (START END) range.
Return nil when a string TARGET cannot be found."
  (cond
   ((stringp target)
    (let ((case-fold-search nil))
      (when (if (string-match-p "\\`[a-zA-Z_][a-zA-Z0-9_']*\\'" target)
                (re-search-forward
                 (concat "\\_<" (regexp-quote target) "\\_>") nil t)
              (search-forward target nil t))
        (list (match-beginning 0) (1- (match-end 0)) (format "%S" target)))))
   ((integerp target)
    (list target target (format "position %d" target)))
   ((and (consp target) (integerp (car target)))
    (list (nth 0 target) (nth 1 target)
          (format "range %d-%d" (nth 0 target) (nth 1 target))))))

(buttercup-define-matcher :to-have-face (target expected)
  "Check that TARGET is fontified with face EXPECTED in the current buffer.
TARGET is a string (searched for sequentially from point, matching whole
identifiers on symbol boundaries), a position, or a (START END) range.
Only meaningful after the buffer has been fontified."
  (let* ((target (funcall target))
         (expected (funcall expected))
         (resolved (curry-test--face-target target)))
    (if (not resolved)
        (cons nil (format "Expected to find %S in the buffer to check its \
face, but it was not present" target))
      (let* ((start (nth 0 resolved))
             (end (nth 1 resolved))
             (desc (nth 2 resolved))
             (actual (curry-test-face-at-range start end)))
        (cons (equal actual expected)
              (if (equal actual expected)
                  (format "Expected %s not to have face %S" desc expected)
                (format "Expected %s to have face %S, but it had %S"
                        desc expected actual)))))))

(defun curry-test--check-face-specs (mode content face-specs)
  "Fontify CONTENT with MODE and assert FACE-SPECS.
Each element of FACE-SPECS is either:
  (\"text\" EXPECTED-FACE) -- search for \"text\" sequentially and check its face
  (START END EXPECTED-FACE) -- check face at position range [START, END]"
  (with-temp-buffer
    (insert content)
    (let ((treesit-font-lock-level 4))
      (funcall mode))
    (font-lock-ensure)
    (goto-char (point-min))
    (dolist (spec face-specs)
      (if (stringp (car spec))
          ;; Text-based spec: ("text" face)
          (expect (nth 0 spec) :to-have-face (nth 1 spec))
        ;; Position-based spec: (start end face)
        (expect (list (nth 0 spec) (nth 1 spec)) :to-have-face (nth 2 spec))))))

(defmacro when-fontifying-it (description &rest tests)
  "Create a Buttercup test asserting font-lock faces in Haskell code.
DESCRIPTION is the test name.  Each element of TESTS is
  (CODE SPEC ...)
where each SPEC is either (\"text\" FACE) for text-based matching
or (START END FACE) for position-based matching."
  (declare (indent 1))
  `(it ,description
     (dolist (test (quote ,tests))
       (let ((content (car test))
             (specs (cdr test)))
         (curry-test--check-face-specs #'curry-mode content specs)))))

;;;; Indentation helpers

(defun curry-test--strip-indentation (code)
  "Remove all leading whitespace from each line of CODE."
  (mapconcat
   (lambda (line) (string-trim-left line))
   (split-string code "\n")
   "\n"))

(defmacro when-indenting-it (description &rest code-strings)
  "Create a Buttercup test that asserts each CODE-STRING indents correctly.
DESCRIPTION is the test name.  Each CODE-STRING is a properly-indented
Haskell code string.  The macro strips indentation, re-indents via
`curry-mode', and asserts the result matches the original."
  (declare (indent 1))
  `(it ,description
     ,@(mapcar
        (lambda (code)
          `(let ((expected ,code))
             (expect
              (with-temp-buffer
                (insert (curry-test--strip-indentation expected))
                (curry-mode)
                (indent-region (point-min) (point-max))
                (buffer-string))
              :to-equal expected)))
        code-strings)))

(defmacro when-indenting-with-point-it (description before after)
  "Create a Buttercup test asserting single-line indentation with cursor tracking.
DESCRIPTION is the test name.
BEFORE is the buffer content with `|' marking cursor position.
AFTER is the expected content after `indent-according-to-mode'
with `|' marking the expected cursor position."
  (declare (indent 1))
  `(it ,description
     (let* ((after-str ,after)
            (expected-cursor-pos (1+ (seq-position after-str ?|)))
            (expected-state (concat (substring after-str 0
                                               (1- expected-cursor-pos))
                                    (substring after-str
                                               expected-cursor-pos))))
       (with-temp-buffer
         (insert ,before)
         (curry-mode)
         (goto-char (point-min))
         (search-forward "|")
         (delete-char -1)
         (font-lock-ensure)
         (indent-according-to-mode)
         (expect (buffer-string) :to-equal expected-state)
         (expect (point) :to-equal expected-cursor-pos)))))

(defmacro when-newline-indenting-it (description &rest tests)
  "Create a Buttercup test asserting empty-line indentation.
DESCRIPTION is the test name.  Each element of TESTS is
\(CODE EXPECTED-COLUMN) where CODE is a source string and
EXPECTED-COLUMN is the column that `newline-and-indent' should
produce after CODE."
  (declare (indent 1))
  `(it ,description
     (dolist (test (quote ,tests))
       (let ((code (nth 0 test))
             (expected-col (nth 1 test)))
         (with-temp-buffer
           (insert code)
           (let ((treesit-font-lock-level 4))
             (curry-mode))
           (goto-char (point-max))
           (newline-and-indent)
           (expect (current-column) :to-equal expected-col))))))

(provide 'curry-test-helpers)

;;; curry-test-helpers.el ends here
