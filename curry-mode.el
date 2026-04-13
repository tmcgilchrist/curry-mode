;;; curry-mode.el --- Major mode for Haskell code -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist
;;
;; Author: Tim McGilchrist <timmcgil@gmail.com>
;; Maintainer: Tim McGilchrist <timmcgil@gmail.com>
;; URL: https://github.com/tmcgilchrist/curry-mode
;; Keywords: languages haskell
;; Version: 0.1.0
;; Package-Requires: ((emacs "29.1"))

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Provides font-lock, indentation, and navigation for the
;; Haskell programming language (https://www.haskell.org).

;; For the tree-sitter grammar this mode is based on,
;; see https://github.com/tree-sitter/tree-sitter-haskell.

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
(require 'seq)

(defgroup curry nil
  "Major mode for editing Haskell code with tree-sitter."
  :prefix "curry-"
  :group 'languages
  :link '(url-link :tag "GitHub" "https://github.com/tmcgilchrist/curry-mode")
  :link '(emacs-commentary-link :tag "Commentary" "curry-mode"))

(defcustom curry-indent-offset 2
  "Number of spaces for each indentation step."
  :type 'natnum
  :safe 'natnump
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-guess-indent-offset t
  "When non-nil, automatically guess the indentation offset on file open.
Uses `curry-guess-indent-offset-function' to scan the buffer and set
`curry-indent-offset' to match the file's convention."
  :type 'boolean
  :safe #'booleanp
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-other-file-alist
  '(("\\.hs\\'" (".lhs"))
    ("\\.lhs\\'" (".hs")))
  "Associative list of alternate extensions to find.
See `ff-other-file-alist' and `ff-find-other-file'."
  :type '(repeat (list regexp (choice (repeat string) function)))
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-prettify-symbols-alist
  '(("\\" . ?λ)
    ("->" . ?→)
    ("<-" . ?←)
    ("=>" . ?⇒)
    ("/=" . ?≠)
    (">=" . ?≥)
    ("<=" . ?≤)
    ("==" . ?≡)
    ("&&" . ?∧)
    ("||" . ?∨))
  "Prettify symbols alist for Haskell operators.
Active when `prettify-symbols-mode' is enabled."
  :type '(alist :key-type string :value-type character)
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-prettify-words-alist
  '(("forall" . ?∀)
    ("undefined" . ?⊥))
  "Extra prettify symbols for Haskell keywords.
Active when `curry-prettify-words' and `prettify-symbols-mode'
are both enabled.  These may affect column alignment."
  :type '(alist :key-type string :value-type character)
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-prettify-words nil
  "When non-nil, include `curry-prettify-words-alist'.
The word symbols may affect column alignment."
  :type 'boolean
  :package-version '(curry-mode . "0.1.0"))

(defconst curry-version "0.1.0")

(defconst curry-grammar-recipes
  '((haskell "https://github.com/tree-sitter/tree-sitter-haskell"
             "v0.23.1"
             "src"))
  "Tree-sitter grammar recipe for Haskell.
Each entry is a list of (LANGUAGE URL REV SOURCE-DIR).
Suitable for use as the value of `treesit-language-source-alist'.")

(defun curry-install-grammars (&optional force)
  "Install required language grammars if not already available.
With prefix argument FORCE, reinstall grammars even if they are
already installed.  This is useful after upgrading curry-mode to a
version that requires a newer grammar."
  (interactive "P")
  (dolist (recipe curry-grammar-recipes)
    (let ((grammar (car recipe)))
      (when (or force (not (treesit-language-available-p grammar nil)))
        (message "Installing %s tree-sitter grammar..." grammar)
        (let ((treesit-language-source-alist curry-grammar-recipes))
          (treesit-install-language-grammar grammar))))))

;;;; Language data

(defvar curry--keywords
  '("where" "let" "in" "class" "instance" "data" "newtype" "type"
    "deriving" "via" "stock" "anyclass" "pattern"
    "if" "then" "else" "case" "of"
    "do" "mdo" "rec"
    "import" "qualified" "module" "as" "hiding"
    "forall" "family"
    "infix" "infixl" "infixr"
    "foreign")
  "Haskell keywords for tree-sitter font-locking.")

(defvar curry--builtin-ids
  '("error" "undefined" "try" "tryJust" "tryAny"
    "catch" "catches" "catchJust"
    "handle" "handleJust"
    "throw" "throwIO" "throwTo" "throwError"
    "ioError" "mask" "mask_"
    "uninterruptibleMask" "uninterruptibleMask_"
    "bracket" "bracket_" "bracketOnErrorSource"
    "finally" "fail" "onException"
    "trace" "traceId" "traceShow" "traceShowId"
    "traceWith" "traceShowWith" "traceStack"
    "traceIO" "traceM" "traceShowM")
  "Haskell builtin identifiers for tree-sitter font-locking.")


;;;; Font-locking

(defun curry--font-lock-settings (language)
  "Return tree-sitter font-lock settings for LANGUAGE.
The return value is suitable for `treesit-font-lock-settings'."
  (treesit-font-lock-rules
   :language language
   :feature 'comment
   '((comment) @font-lock-comment-face
     ((haddock) @font-lock-doc-face)
     (pragma) @font-lock-preprocessor-face
     (cpp) @font-lock-preprocessor-face)

   :language language
   :feature 'definition
   `(;; Function declarations
     (decl
      name: (variable) @font-lock-function-name-face)
     ;; Type signatures
     (decl/signature
      name: (variable) @font-lock-function-name-face)
     ;; Binding names (simple binds without function patterns)
     (decl/bind
      name: (variable) @font-lock-variable-name-face)
     ;; Binding that is `main` is always a function
     ((decl/bind
       name: (variable) @font-lock-function-name-face)
      (:match "^main$" @font-lock-function-name-face))
     ;; Function parameters
     (decl/function
      patterns: (patterns
                 (_) @font-lock-variable-name-face))
     ;; Lambda parameters
     (expression/lambda
      (_)+ @font-lock-variable-name-face
      "->"))

   :language language
   :feature 'keyword
   `([,@curry--keywords] @font-lock-keyword-face)

   :language language
   :feature 'string
   :override t
   '((string) @font-lock-string-face
     (char) @font-lock-string-face)

   :language language
   :feature 'number
   :override t
   '((integer) @font-lock-number-face
     (negation) @font-lock-number-face
     (expression/literal (float)) @font-lock-number-face)

   :language language
   :feature 'type
   '(;; Type constructors
     (name) @font-lock-type-face
     ;; Type variables in type signatures
     (type/variable) @font-lock-type-face
     ;; Star kind
     (type/star) @font-lock-type-face)

   :language language
   :feature 'constructor
   '(;; Data constructors
     (constructor) @font-lock-constant-face
     ;; True/False as booleans
     ((constructor) @font-lock-constant-face
      (:match "^\\(True\\|False\\)$" @font-lock-constant-face))
     ;; `otherwise` as boolean
     ((variable) @font-lock-constant-face
      (:match "^otherwise$" @font-lock-constant-face))
     ;; Unit
     (unit) @font-lock-constant-face)

   :language language
   :feature 'module
   '((module (module_id) @font-lock-constant-face))

   :language language
   :feature 'operator
   '((operator) @font-lock-operator-face
     (constructor_operator) @font-lock-operator-face
     ["." ".." "=" "|" "::" "=>" "->" "<-" "\\" "`" "@"]
     @font-lock-operator-face)

   :language language
   :feature 'variable
   '(;; Variables in patterns
     (pattern/variable) @font-lock-variable-use-face
     ;; Wildcards in patterns
     (pattern/wildcard) @font-lock-variable-use-face
     ;; Record field names
     (field_name (variable) @font-lock-property-use-face))

   :language language
   :feature 'function
   :override t
   `(;; Function application
     (apply
      [(expression/variable) @font-lock-function-call-face
       (expression/qualified
        (variable) @font-lock-function-call-face)])
     ;; Infix function application
     (infix_id
      [(variable) @font-lock-operator-face
       (qualified (variable) @font-lock-operator-face)])
     ;; Builtin functions
     ((expression/variable) @font-lock-builtin-face
      (:match ,(regexp-opt curry--builtin-ids 'symbols)
              @font-lock-builtin-face))
     ;; Quasi-quoters
     (quoter) @font-lock-function-call-face)

   :language language
   :feature 'bracket
   '((["(" ")" "[" "]" "{" "}"]) @font-lock-bracket-face)

   :language language
   :feature 'delimiter
   '((["," ";"]) @font-lock-delimiter-face)))


;;;; Indentation

(defvar curry--indent-body-tokens
  '("=" "->" "<-" "do" "mdo" "of" "in" "then" "else"
    "where" "let" "|" "\\")
  "Tokens that expect a body on the next line.
Used by `curry--empty-line-offset' to decide whether an empty line
should be indented relative to the previous line.")

(defun curry--comment-body-anchor (node parent _bol &rest _)
  "Return the position of the comment body start.
Uses NODE if non-nil, otherwise PARENT (for continuation lines
where NODE is nil).  Used as an indentation anchor so that lines
inside a multi-line comment align with the text after the opening
delimiter."
  (let ((comment (or node parent)))
    (save-excursion
      (goto-char (treesit-node-start comment))
      (if (looking-at "{-+[ \t]*")
          (goto-char (match-end 0))
        (forward-char 2)
        (skip-chars-forward " \t"))
      (point))))

(defun curry--empty-line-offset (_node _parent bol)
  "Compute extra indentation offset for an empty line at BOL.
If the last token on the previous line expects a body (e.g., `=',
`->', `where'), return `curry-indent-offset'.  Otherwise return 0,
which preserves the previous line's indentation level."
  (save-excursion
    (goto-char bol)
    (if (and (zerop (forward-line -1))
             (progn
               (end-of-line)
               (skip-chars-backward " \t")
               (> (point) (line-beginning-position)))
             (let ((node (treesit-node-at (1- (point)))))
               (and node
                    (member (treesit-node-type node)
                            curry--indent-body-tokens))))
        curry-indent-offset
      0)))

(defun curry--indent-rules (language)
  "Return tree-sitter indentation rules for LANGUAGE.
The return value is suitable for `treesit-simple-indent-rules'."
  `((,language
     ;; Comment continuation lines: align with the body text after
     ;; the opening delimiter.  Must come before `no-node' because
     ;; lines inside a multi-line comment have node=nil, parent=comment.
     ((parent-is "comment") curry--comment-body-anchor 0)
     ((parent-is "haddock") curry--comment-body-anchor 0)

     ;; Empty lines: use previous line's indentation, adding offset
     ;; when the previous line ends with a body-expecting token.
     (no-node prev-line curry--empty-line-offset)

     ;; Top-level definitions: column 0
     ((parent-is "haskell") column-0 0)

     ;; Closing delimiters align with the opening construct
     ((node-is ")") parent-bol 0)
     ((node-is "]") parent-bol 0)
     ((node-is "}") parent-bol 0)

     ;; where keyword aligns with the enclosing declaration
     ((node-is "where") parent-bol curry-indent-offset)

     ;; Guards align with the function patterns
     ((node-is "guard") parent-bol curry-indent-offset)
     ((parent-is "guard") parent-bol curry-indent-offset)

     ;; Case alternatives
     ((parent-is "case") parent-bol curry-indent-offset)
     ((parent-is "alternative") parent-bol curry-indent-offset)
     ((parent-is "alternatives") parent-bol 0)

     ;; Do block statements
     ((parent-is "do") parent-bol curry-indent-offset)
     ((parent-is "mdo") parent-bol curry-indent-offset)

     ;; Let/in expressions
     ((parent-is "let_in") parent-bol curry-indent-offset)
     ((node-is "in") parent-bol 0)

     ;; Local bindings (where/let bodies)
     ((parent-is "local_binds") parent-bol 0)

     ;; Class and instance declarations
     ((parent-is "class") parent-bol curry-indent-offset)
     ((parent-is "instance") parent-bol curry-indent-offset)
     ((parent-is "class_declarations") parent-bol 0)
     ((parent-is "instance_declarations") parent-bol 0)

     ;; Data type declarations
     ((parent-is "data_type") parent-bol curry-indent-offset)
     ((parent-is "newtype") parent-bol curry-indent-offset)
     ((parent-is "data_constructors") parent-bol 0)
     ((parent-is "gadt_constructors") parent-bol 0)

     ;; Record syntax
     ((parent-is "record") parent-bol curry-indent-offset)
     ((parent-is "field") parent-bol curry-indent-offset)

     ;; Type signatures continuing across lines
     ((parent-is "signature") parent-bol curry-indent-offset)

     ;; Function definitions
     ((parent-is "function") parent-bol curry-indent-offset)
     ((parent-is "bind") parent-bol curry-indent-offset)
     ((parent-is "match") parent-bol curry-indent-offset)

     ;; If/then/else
     ((parent-is "conditional") parent-bol curry-indent-offset)

     ;; Lambda
     ((parent-is "lambda") parent-bol curry-indent-offset)

     ;; List/tuple expressions
     ((parent-is "list") parent-bol curry-indent-offset)
     ((parent-is "tuple") parent-bol curry-indent-offset)
     ((parent-is "parens") parent-bol curry-indent-offset)

     ;; Infix expressions
     ((parent-is "infix") parent-bol curry-indent-offset)

     ;; Module/import/export
     ((parent-is "header") parent-bol curry-indent-offset)
     ((parent-is "exports") parent-bol curry-indent-offset)
     ((parent-is "import") parent-bol curry-indent-offset)
     ((parent-is "import_list") parent-bol curry-indent-offset)

     ;; Deriving
     ((parent-is "deriving") parent-bol curry-indent-offset)

     ;; Multi-way if
     ((parent-is "multi_way_if") parent-bol curry-indent-offset)

     ;; Error recovery
     ((parent-is "ERROR") parent-bol curry-indent-offset))))

(defun curry-shift-region-right (start end &optional count)
  "Shift the region between START and END right by COUNT indentation levels.
COUNT defaults to 1.  With a negative prefix argument, shifts left."
  (interactive "r\np")
  (let ((offset (* (or count 1) curry-indent-offset)))
    (indent-rigidly start end offset)))

(defun curry-shift-region-left (start end &optional count)
  "Shift the region between START and END left by COUNT indentation levels.
COUNT defaults to 1.  With a negative prefix argument, shifts right."
  (interactive "r\np")
  (let ((offset (* (or count 1) (- curry-indent-offset))))
    (indent-rigidly start end offset)))

(defun curry-cycle-indent ()
  "Cycle between `treesit-indent' and `indent-relative' for indentation."
  (interactive)
  (if (eq indent-line-function 'treesit-indent)
      (progn (setq indent-line-function #'indent-relative)
             (message "[curry] Switched indentation to indent-relative"))
    (setq indent-line-function #'treesit-indent)
    (message "[curry] Switched indentation to treesit-indent")))

(defun curry-guess-indent-offset ()
  "Guess the indentation offset used in the current buffer.
Scans the buffer for the smallest common indentation step and sets
`curry-indent-offset' accordingly."
  (interactive)
  (let ((counts (make-hash-table))
        (best-offset curry-indent-offset))
    (save-excursion
      (goto-char (point-min))
      (while (not (eobp))
        (let ((indent (current-indentation)))
          (when (> indent 0)
            (puthash indent (1+ (gethash indent counts 0)) counts)))
        (forward-line 1)))
    (let ((min-indent nil))
      (maphash (lambda (indent _)
                 (when (or (null min-indent) (< indent min-indent))
                   (setq min-indent indent)))
               counts)
      (when (and min-indent (member min-indent '(2 3 4 8)))
        (setq best-offset min-indent)))
    (setq-local curry-indent-offset best-offset)
    (when (called-interactively-p 'interactive)
      (message "Guessed indent offset: %d" best-offset))))


;;;; Find the definition at point

(defvar curry--defun-type-regexp
  (regexp-opt '("function"
                "bind"
                "signature"
                "data_type"
                "newtype"
                "type_synomym"
                "class"
                "instance"
                "deriving_instance"
                "foreign_import"
                "foreign_export"
                "fixity"
                "pattern_synonym"
                "import"))
  "Regex matching tree-sitter node types treated as defun-like.
Used as the value of `treesit-defun-type-regexp'.")

(defun curry--defun-valid-p (node)
  "Return non-nil if NODE is a top-level definition.
Filters out nodes nested inside `let_in' expressions."
  (and (treesit-node-check node 'named)
       (not (treesit-node-top-level node "\\`let_in\\'"))))

(defun curry--subtree-text (node type &optional depth)
  "Return the text of the first TYPE child in NODE's subtree.
Search up to DEPTH levels deep (default 1).  Return nil if not found."
  (when-let* ((child (treesit-search-subtree
                       node type nil nil (or depth 1))))
    (treesit-node-text child t)))

(defun curry--defun-name (node)
  "Return the defun name of NODE.
Return nil if there is no name or if NODE is not a defun node."
  (pcase (treesit-node-type node)
    ((or "function" "bind" "signature")
     (treesit-node-text
      (treesit-node-child-by-field-name node "name") t))
    ("data_type"
     (curry--subtree-text node "name" 2))
    ("newtype"
     (curry--subtree-text node "name" 2))
    ("type_synomym"
     (curry--subtree-text node "name" 2))
    ("class"
     (curry--subtree-text node "name" 2))
    ("instance"
     (curry--subtree-text node "name" 2))
    ("import"
     (curry--subtree-text node "module" 2))
    ("pattern_synonym"
     (curry--subtree-text node "name" 2))))


;;;; Imenu integration

(defun curry--imenu-name (node)
  "Return the fully-qualified name of NODE by walking up the tree.
Joins ancestor defun names with `treesit-add-log-defun-delimiter'."
  (let ((name nil))
    (while node
      (when-let* ((new-name (treesit-defun-name node)))
        (if name
            (setq name (concat new-name
                               treesit-add-log-defun-delimiter
                               name))
          (setq name new-name)))
      (setq node (treesit-node-parent node)))
    name))

(defvar curry--imenu-settings
  `(("Function" "\\`\\(function\\|bind\\)\\'"
     curry--defun-valid-p curry--imenu-name)
    ("Type" "\\`\\(data_type\\|newtype\\|type_synomym\\)\\'"
     curry--defun-valid-p curry--imenu-name)
    ("Class" "\\`class\\'"
     curry--defun-valid-p curry--imenu-name)
    ("Instance" "\\`\\(instance\\|deriving_instance\\)\\'"
     curry--defun-valid-p curry--imenu-name)
    ("Import" "\\`import\\'"
     curry--defun-valid-p curry--imenu-name))
  "Settings for `treesit-simple-imenu' in `curry-mode'.")


;;;; Structured navigation

(defvar curry--block-regex
  (regexp-opt '("function" "bind" "signature"
                "data_type" "newtype" "type_synomym"
                "class" "instance"
                "import"
                "case" "alternative"
                "do" "mdo"
                "let_in"
                "conditional"
                "lambda" "lambda_case" "lambda_cases"
                "match"
                "apply" "infix"
                "parens" "list" "tuple"
                "record"
                "string" "char" "integer" "float"
                "variable" "constructor" "operator"
                "comment" "haddock" "pragma")
              'symbols)
  "Regex matching tree-sitter node types for sexp-based navigation.")

(defun curry-forward-sexp (count)
  "Move forward across COUNT balanced Haskell expressions.
If COUNT is negative, move backward."
  (if (< count 0)
      (treesit-beginning-of-thing curry--block-regex (- count))
    (treesit-end-of-thing curry--block-regex count)))

(defun curry--delimiter-p ()
  "Return non-nil if point is on a delimiter character."
  (let ((syntax (syntax-after (point))))
    (and syntax
         (memq (syntax-class syntax) '(4 5)))))

(defun curry--forward-sexp-hybrid (arg)
  "Hybrid `forward-sexp-function' combining tree-sitter and syntax table.
When point is on a delimiter character, fall back to syntax-table-based
matching.  Otherwise, use tree-sitter sexp navigation.

ARG is as in `forward-sexp-function'."
  (let ((arg (or arg 1)))
    (if (or (curry--delimiter-p)
            (and (< arg 0)
                 (save-excursion
                   (skip-chars-backward " \t")
                   (not (bobp))
                   (let ((syntax (syntax-after (1- (point)))))
                     (and syntax (eq (syntax-class syntax) 5))))))
        (if (fboundp 'forward-sexp-default-function)
            (forward-sexp-default-function arg)
          (goto-char (or (scan-sexps (point) arg) (buffer-end arg))))
      (if (fboundp 'treesit-forward-sexp)
          (treesit-forward-sexp arg)
        (curry-forward-sexp arg)))))

(defun curry--thing-settings (language)
  "Return `treesit-thing-settings' definitions for LANGUAGE."
  `((,language
     (sexp (not ,(rx (or "{" "}" "(" ")" "[" "]"
                         "," ";" ":" "::" "->" "<-"
                         "=" "|" ".."))))
     (list ,(regexp-opt '("parens" "list" "tuple"
                          "unboxed_tuple" "unboxed_sum"
                          "record" "exports" "import_list")
                        'symbols))
     (sentence ,(regexp-opt '("function" "bind" "signature"
                              "data_type" "newtype" "type_synomym"
                              "class" "instance" "deriving_instance"
                              "import" "fixity"
                              "foreign_import" "foreign_export"
                              "pattern_synonym")))
     (text ,(regexp-opt '("comment" "haddock" "string" "char")))
     (comment ,(regexp-opt '("comment" "haddock"))))))


;;;; Compilation support

(defvar curry--compilation-error-regexp
  `(,(rx bol
         (group-n 1 (+ (not (any ":" "\n"))))
         ":"
         (group-n 2 (+ digit))
         ":"
         (group-n 3 (+ digit))
         (or ": error" ": warning" "-"))
    1 2 3)
  "Regexp matching GHC error/warning messages.
Suitable for `compilation-error-regexp-alist-alist'.")

(defun curry--setup-compilation ()
  "Register GHC error regexp with `compilation-mode'."
  (with-eval-after-load 'compile
    (defvar compilation-error-regexp-alist-alist)
    (defvar compilation-error-regexp-alist)
    (add-to-list 'compilation-error-regexp-alist-alist
                 (cons 'ghc curry--compilation-error-regexp))
    (add-to-list 'compilation-error-regexp-alist 'ghc)))


;;;; Fill paragraph

(defun curry--comment-at-point ()
  "Return the comment or haddock node at or around point, or nil."
  (treesit-parent-until
   (treesit-node-at (point))
   (lambda (n) (member (treesit-node-type n) '("comment" "haddock")))
   t))

(defun curry--fill-paragraph (&optional _justify)
  "Fill the Haskell comment at point.
Uses tree-sitter to find comment boundaries, then narrows to the
comment body (excluding delimiters) and fills.  Returns t if point
was in a comment, nil otherwise to let the default handler run."
  (let ((comment (curry--comment-at-point)))
    (when comment
      (let ((start (treesit-node-start comment))
            (end (treesit-node-end comment)))
        (save-excursion
          (save-restriction
            ;; Narrow to comment body: skip {- prefix and -} suffix
            (goto-char start)
            (cond
             ((looking-at "{-[|!#]?[ \t]*")
              (setq start (match-end 0)))
             ((looking-at "--[ \t|]*")
              (setq start (match-end 0))))
            (goto-char end)
            (when (looking-back "-}" nil)
              (goto-char (match-beginning 0))
              (skip-chars-backward " \t")
              (setq end (point)))
            (let ((body-col (save-excursion
                              (goto-char start)
                              (current-column))))
              (narrow-to-region start end)
              (let* ((paragraph-start
                      (concat paragraph-start
                              "\\|[ \t]*[-*+][ \t]"
                              "\\|[ \t]*@[a-z]+\\b"))
                     par-start par-end)
                (save-excursion
                  (skip-chars-forward " \t")
                  (backward-paragraph)
                  (skip-chars-forward " \t\n")
                  (setq par-start (point))
                  (forward-paragraph)
                  (setq par-end (point)))
                (let* ((par-col (save-excursion
                                  (goto-char par-start)
                                  (skip-chars-forward " \t")
                                  (current-column)))
                       (fill-prefix
                        (make-string (max body-col par-col) ?\s))
                       (fill-paragraph-function nil))
                  (fill-region-as-paragraph par-start par-end))))))
        t))))

;;;; Comment continuation (M-j)

(defun curry--comment-body-column ()
  "Return the column of the comment body text start, or nil."
  (let ((comment (curry--comment-at-point)))
    (when comment
      (save-excursion
        (goto-char (treesit-node-start comment))
        (cond
         ((looking-at "{-[|!#]?[ \t]*")
          (goto-char (match-end 0))
          (current-column))
         ((looking-at "--[ \t|]*")
          ;; For line comments, continue with "-- " prefix
          nil))))))

(defun curry--comment-indent-new-line (&optional soft)
  "Break line at point and indent, continuing comment if within one.
For block comments, aligns continuation with the comment body.
For line comments, inserts a new `-- ' prefixed line.
SOFT works the same as in `comment-indent-new-line'."
  (let ((body-col (curry--comment-body-column)))
    (if body-col
        ;; Inside a block comment: align with body
        (progn
          (if soft (insert-and-inherit ?\n) (newline 1))
          (insert-char ?\s body-col))
      ;; Line comment or not in comment: use default
      (comment-indent-new-line soft))))

;;;; Prettify symbols

(defun curry--prettify-symbols-alist ()
  "Return the prettify symbols alist for the current settings.
Includes word symbols when `curry-prettify-words' is non-nil."
  (if curry-prettify-words
      (append curry-prettify-symbols-alist
              curry-prettify-words-alist)
    curry-prettify-symbols-alist))

;;;; Major mode definitions

(defvar curry-base-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-a") #'ff-find-other-file)
    (define-key map (kbd "C-c C-c") #'compile)
    (define-key map (kbd "C-c >") #'curry-shift-region-right)
    (define-key map (kbd "C-c <") #'curry-shift-region-left)
    (easy-menu-define curry-mode-menu map "Curry Mode Menu"
      '("Haskell"
        ("Navigate"
         ["Beginning of Definition" beginning-of-defun]
         ["End of Definition" end-of-defun]
         ["Forward Expression" forward-sexp]
         ["Backward Expression" backward-sexp])
        "--"
        ["Mark Definition" mark-defun]
        ["Mark Expression" mark-sexp]
        "--"
        ["Shift Region Right" curry-shift-region-right
         :active mark-active]
        ["Shift Region Left" curry-shift-region-left
         :active mark-active]
        "--"
        ["Compile..." compile]
        ["Cycle indent function" curry-cycle-indent]
        ["Guess indent offset" curry-guess-indent-offset]
        ["Install tree-sitter grammars" curry-install-grammars]))
    map)
  "Keymap for `curry-mode'.")

(defvar curry-base-mode-syntax-table
  (let ((st (make-syntax-table)))
    ;; Underscores and primes are part of identifiers
    (modify-syntax-entry ?_ "_" st)
    (modify-syntax-entry ?' "_" st)
    ;; Line comments: -- to end of line
    (modify-syntax-entry ?-  ". 12" st)
    (modify-syntax-entry ?\n ">" st)
    ;; Block comments: {- ... -}
    ;; { and } are paired delimiters that also participate in comments
    (modify-syntax-entry ?{  "(}1nb" st)
    (modify-syntax-entry ?}  "){4nb" st)
    ;; String delimiter
    (modify-syntax-entry ?\" "\"" st)
    ;; Backslash is escape
    (modify-syntax-entry ?\\ "\\" st)
    ;; Operator characters
    (dolist (c '(?! ?# ?$ ?% ?& ?* ?+ ?. ?/ ?< ?= ?> ?? ?@ ?^ ?| ?~ ?:))
      (modify-syntax-entry c "." st))
    st)
  "Syntax table in use in curry-mode buffers.")

(defun curry--setup-mode (language)
  "Set up tree-sitter font-lock, indentation, and navigation for LANGUAGE.
Called from `curry-mode' to configure the language-specific parts."
  ;; Offer to install missing grammars
  (when-let* ((missing (seq-filter
                        (lambda (r)
                          (not (treesit-language-available-p (car r))))
                        curry-grammar-recipes)))
    (when (y-or-n-p
           "Haskell tree-sitter grammar is not installed.  Install now?")
      (curry-install-grammars)))

  (when (treesit-ready-p language)
    (let ((parser (treesit-parser-create language)))
      (when (boundp 'treesit-primary-parser)
        (setq-local treesit-primary-parser parser)))

    ;; Font-lock
    (setq-local treesit-font-lock-settings
                (curry--font-lock-settings language))

    ;; Indentation
    (setq-local treesit-simple-indent-rules
                (curry--indent-rules language))

    ;; Navigation (Emacs 30+)
    (when (boundp 'treesit-thing-settings)
      (setq-local treesit-thing-settings
                  (curry--thing-settings language)))

    (treesit-major-mode-setup)

    ;; Hybrid forward-sexp for Emacs 29-30
    (unless (fboundp 'treesit-forward-sexp-list)
      (setq-local forward-sexp-function
                  #'curry--forward-sexp-hybrid))))

(defun curry--register-with-eglot ()
  "Register curry-mode with eglot if loaded."
  (when (boundp 'eglot-server-programs)
    (add-to-list 'eglot-server-programs
                 '((curry-mode :language-id "haskell")
                   "haskell-language-server-wrapper" "--lsp"))))

(define-derived-mode curry-base-mode prog-mode "Haskell"
  "Base major mode for Haskell files, providing shared setup.
This mode is not intended to be used directly.  Use `curry-mode'."
  :syntax-table curry-base-mode-syntax-table

  ;; Comment settings
  (setq-local comment-start "-- ")
  (setq-local comment-end "")
  (setq-local comment-start-skip "[-{]-[ \t]*")
  (setq-local comment-padding 1)
  (setq-local comment-multi-line t)
  (setq-local comment-line-break-function #'curry--comment-indent-new-line)

  ;; Fill paragraph
  (setq-local fill-paragraph-function #'curry--fill-paragraph)
  (setq-local adaptive-fill-mode t)

  ;; Electric indentation and pairs
  (setq-local electric-indent-chars
              (append "{}()[],;" electric-indent-chars))
  (electric-pair-local-mode 1)

  ;; Font-lock feature levels
  (setq-local treesit-font-lock-feature-list
              '((comment definition)
                (keyword string number)
                (type constructor module)
                (operator variable function bracket delimiter)))

  ;; Indentation
  (setq-local indent-line-function #'treesit-indent)

  ;; Forward-sexp fallback for Emacs 29
  (unless (boundp 'treesit-thing-settings)
    (setq-local forward-sexp-function #'curry--forward-sexp-hybrid))

  ;; Defun navigation
  (setq-local treesit-defun-type-regexp
              (cons curry--defun-type-regexp
                    #'curry--defun-valid-p))
  (setq-local treesit-defun-name-function #'curry--defun-name)

  ;; which-func-mode integration
  (setq-local add-log-current-defun-function
              #'treesit-add-log-current-defun)

  ;; outline-minor-mode (Emacs 30+)
  (when (boundp 'treesit-outline-predicate)
    (setq-local treesit-outline-predicate
                (cons curry--defun-type-regexp
                      #'curry--defun-valid-p)))

  ;; ff-find-other-file
  (setq-local ff-other-file-alist curry-other-file-alist)

  ;; Prettify symbols (users enable prettify-symbols-mode via hooks)
  (setq-local prettify-symbols-alist (curry--prettify-symbols-alist))

  ;; Eglot integration
  (curry--register-with-eglot))

;;;###autoload
(define-derived-mode curry-mode curry-base-mode "Haskell"
  "Major mode for editing Haskell code, powered by tree-sitter.

\\{curry-base-mode-map}"
  (setq-local treesit-simple-imenu-settings curry--imenu-settings)
  (curry--setup-mode 'haskell)
  ;; Auto-guess indentation offset from file contents
  (when (and curry-guess-indent-offset
             (not (local-variable-p 'curry-indent-offset))
             (> (buffer-size) 0))
    (curry-guess-indent-offset)))

;;;###autoload
(progn
  (add-to-list 'auto-mode-alist '("\\.hs\\'" . curry-mode))
  (add-to-list 'auto-mode-alist '("\\.lhs\\'" . curry-mode)))

;; Hide Haskell build artifacts from find-file completion
(dolist (ext '(".hi" ".o" ".dyn_hi" ".dyn_o"))
  (add-to-list 'completion-ignored-extensions ext))

;; Register GHC compilation error regexp at load time
(curry--setup-compilation)

;; Eglot language ID
(put 'curry-mode 'eglot-language-id "haskell")

(provide 'curry-mode)

;;; curry-mode.el ends here
