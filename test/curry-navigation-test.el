;;; curry-navigation-test.el --- Navigation tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for curry-mode navigation: defun movement,
;; forward-sexp, defun-name, sentence navigation, and list navigation.

;;; Code:

(require 'curry-test-helpers)

;;;; beginning-of-defun / end-of-defun

(describe "navigation: beginning-of-defun"
  (before-all
    (curry-test-skip-unless-grammar))

  (it "moves to the start of the current function"
    (with-curry-buffer "
        foo = 1

        bar = 2"
      (goto-char (point-max))
      (beginning-of-defun)
      (expect (looking-at "bar") :to-be-truthy)))

  (it "moves past multiple defuns"
    (with-curry-buffer "
        foo = 1

        bar = 2

        baz = 3"
      (goto-char (point-max))
      (beginning-of-defun 2)
      (expect (looking-at "bar") :to-be-truthy))))

(describe "navigation: end-of-defun"
  (before-all
    (curry-test-skip-unless-grammar))

  (it "moves to the end of the current function"
    (with-curry-buffer "
        foo = 1

        bar = 2"
      (end-of-defun)
      (let ((pos (point)))
        (end-of-defun)
        (expect (> (point) pos) :to-be-truthy)))))

;;;; type declarations

(defconst curry-test--type-declarations "
        data A = A Int

        newtype B
          = B { unB :: Int }
          deriving (Show)

        type family F a where
          F Int = Bool

        data family D a

        type instance G Int = Bool

        type T :: Type

        f = 1"
  "Fixture with each kind of type declaration, some spread over lines.")

(defun curry-test--line-starts (move)
  "Return the text at the start of each line MOVE stops on.
Start from the end of the buffer and call MOVE until point stops
changing."
  (goto-char (point-max))
  (let (starts last)
    (while (not (eql last (point)))
      (setq last (point))
      (funcall move)
      (unless (eql last (point))
        (push (buffer-substring-no-properties (point) (line-end-position))
              starts)))
    starts))

(describe "navigation: type declarations"
  (before-all
    (curry-test-skip-unless-grammar))

  (it "beginning-of-defun moves from a newtype's record to its start"
    (with-curry-buffer curry-test--type-declarations
      (search-forward "unB")
      (beginning-of-defun)
      (expect (looking-at "newtype B$") :to-be-truthy)))

  (it "beginning-of-defun moves from a deriving clause to its newtype"
    (with-curry-buffer curry-test--type-declarations
      (search-forward "deriving")
      (beginning-of-defun)
      (expect (looking-at "newtype B$") :to-be-truthy)))

  (it "beginning-of-defun moves from a type family equation to the family"
    (with-curry-buffer curry-test--type-declarations
      (search-forward "F Int")
      (beginning-of-defun)
      (expect (looking-at "type family F") :to-be-truthy)))

  (it "beginning-of-defun stops at every type declaration"
    (with-curry-buffer curry-test--type-declarations
      (expect (curry-test--line-starts #'beginning-of-defun)
              :to-equal '("data A = A Int"
                          "newtype B"
                          "type family F a where"
                          "data family D a"
                          "type instance G Int = Bool"
                          "type T :: Type"
                          "f = 1"))))

  (it "end-of-defun stops after every type declaration"
    (with-curry-buffer curry-test--type-declarations
      (let (lines)
        (while (let ((pos (point)))
                 (end-of-defun)
                 (/= pos (point)))
          (push (line-number-at-pos) lines))
        (expect (length lines) :to-equal 7))))

  (it "names type families, instances and kind signatures"
    (with-curry-buffer curry-test--type-declarations
      (dolist (probe '(("F Int" . "F")
                       ("family D" . "D")
                       ("instance G" . "G")
                       ("T ::" . "T")))
        (goto-char (point-min))
        (search-forward (car probe))
        (expect (treesit-defun-name (treesit-defun-at-point))
                :to-equal (cdr probe)))))

  (it "backward-sentence stops at every type declaration (Emacs 30+)"
    (curry-test-skip-unless-emacs-30)
    (with-curry-buffer curry-test--type-declarations
      (expect (curry-test--line-starts #'backward-sentence)
              :to-equal '("data A = A Int"
                          "newtype B"
                          "type family F a where"
                          "data family D a"
                          "type instance G Int = Bool"
                          "type T :: Type"
                          "f = 1")))))

;;;; forward-sexp

(describe "navigation: forward-sexp"
  (before-all
    (curry-test-skip-unless-grammar))

  (it "moves over a parenthesized expression"
    (with-curry-buffer "foo = (1 + 2)"
      (search-forward "= ")
      (let ((start (point)))
        (forward-sexp)
        (expect (char-before) :to-equal ?\))
        (expect (> (point) start) :to-be-truthy))))

  (it "moves over an identifier"
    (with-curry-buffer "foo = bar"
      (search-forward "= ")
      (forward-sexp)
      (expect (looking-back "bar" (line-beginning-position)) :to-be-truthy)))

  (it "moves over a string"
    (with-curry-buffer "foo = \"hello\""
      (search-forward "= ")
      (forward-sexp)
      (expect (looking-back "\"hello\"" (line-beginning-position))
              :to-be-truthy))))

;;;; defun-name

(describe "navigation: defun-name"
  (before-all
    (curry-test-skip-unless-grammar))

  (it "returns the name of a function"
    (with-curry-buffer "
        foo :: Int -> Int
        foo x = x + 1"
      (search-forward "foo x")
      (let ((node (treesit-node-at (point))))
        (while (and node
                    (not (string-match-p
                          "function\\|bind"
                          (treesit-node-type node))))
          (setq node (treesit-node-parent node)))
        (when node
          (expect (curry--defun-name node) :to-equal "foo")))))

  (it "returns the name of a data type"
    (with-curry-buffer "data Color = Red | Green | Blue"
      (search-forward "Color")
      (let ((node (treesit-node-at (1- (point)))))
        (while (and node
                    (not (string= (treesit-node-type node) "data_type")))
          (setq node (treesit-node-parent node)))
        (when node
          (expect (curry--defun-name node) :to-equal "Color")))))

  (it "returns the name of a type synonym"
    (with-curry-buffer "type Name = String"
      (search-forward "Name")
      (let ((node (treesit-node-at (1- (point)))))
        (while (and node
                    (not (string= (treesit-node-type node) "type_synonym")))
          (setq node (treesit-node-parent node)))
        (when node
          (expect (curry--defun-name node) :to-equal "Name")))))

  (it "returns the name of a class"
    (with-curry-buffer "class Eq a where"
      (search-forward "Eq")
      (let ((node (treesit-node-at (1- (point)))))
        (while (and node
                    (not (string= (treesit-node-type node) "class")))
          (setq node (treesit-node-parent node)))
        (when node
          (expect (curry--defun-name node) :to-equal "Eq"))))))

;;;; sentence navigation (Emacs 30+ only)

(describe "navigation: sentence (Emacs 30+)"
  (before-all
    (curry-test-skip-unless-grammar)
    (curry-test-skip-unless-emacs-30))

  (it "forward-sentence moves between top-level definitions"
    (with-curry-buffer "
        foo = 1

        bar = 2

        baz = 3"
      (forward-sentence)
      (let ((pos (point)))
        (forward-sentence)
        (expect (> (point) pos) :to-be-truthy))))

  (it "backward-sentence moves to previous definitions"
    (with-curry-buffer "
        foo = 1

        bar = 2

        baz = 3"
      (goto-char (point-max))
      (backward-sentence)
      (expect (looking-at "baz") :to-be-truthy)
      (backward-sentence)
      (expect (looking-at "bar") :to-be-truthy)))

  (it "navigates between different definition kinds"
    (with-curry-buffer "
        data Color = Red

        foo = 1

        class Eq a where"
      (goto-char (point-max))
      (backward-sentence)
      (expect (looking-at "class") :to-be-truthy)
      (backward-sentence)
      (expect (looking-at "foo") :to-be-truthy)
      (backward-sentence)
      (expect (looking-at "data") :to-be-truthy))))

;;;; list navigation (Emacs 30+ only)

(describe "navigation: list (Emacs 30+)"
  (before-all
    (curry-test-skip-unless-grammar)
    (curry-test-skip-unless-emacs-30))

  (it "forward-list moves over a parenthesized expression"
    (with-curry-buffer "foo = (1 + 2) + 3"
      (search-forward "= ")
      (forward-list)
      (expect (char-before) :to-equal ?\))))

  (it "forward-list moves over a list expression"
    (with-curry-buffer "foo = [1, 2, 3]"
      (search-forward "= ")
      (forward-list)
      (expect (char-before) :to-equal ?\])))

  (it "up-list moves out of a parenthesized expression"
    (with-curry-buffer "foo = (1 + 2)"
      (search-forward "1 ")
      (up-list)
      (expect (char-before) :to-equal ?\))))

  (it "delete-pair removes matching parentheses"
    (with-curry-buffer "foo = (1 + 2)"
      (search-forward "= ")
      (delete-pair)
      (expect (buffer-string) :to-equal "foo = 1 + 2"))))

;;;; imenu

(describe "navigation: imenu"
  (before-all
    (curry-test-skip-unless-grammar))

  (it "lists top-level functions"
    (with-curry-buffer "
        foo :: Int -> Int
        foo x = x + 1

        bar :: String -> String
        bar s = s"
      (let ((index (treesit-simple-imenu)))
        (expect index :not :to-be nil)
        (expect (assoc "Function" index) :not :to-be nil))))

  (it "lists data types"
    (with-curry-buffer "data Color = Red | Green | Blue"
      (let ((index (treesit-simple-imenu)))
        (expect (assoc "Type" index) :not :to-be nil))))

  (it "lists type synonyms"
    (with-curry-buffer "type Name = String\n\nfoo = 42"
      (font-lock-ensure)
      (let ((index (treesit-simple-imenu)))
        (expect (assoc "Type" index) :not :to-be nil))))

  (it "lists imports"
    (with-curry-buffer "import Data.List"
      (let ((index (treesit-simple-imenu)))
        (expect (assoc "Import" index) :not :to-be nil)))))

;;;; which-func / add-log integration

(describe "navigation: which-func"
  (before-all
    (curry-test-skip-unless-grammar))

  (it "returns the current defun name"
    (with-curry-buffer "
        foo x = x + 1

        bar y = y * 2"
      (search-forward "x + ")
      (expect (add-log-current-defun) :to-equal "foo")))

  (it "returns the current type name"
    (with-curry-buffer "data Color = Red | Green | Blue"
      (search-forward "Green")
      (expect (add-log-current-defun) :to-equal "Color"))))

;;;; outline integration (Emacs 30+ only)

(when (boundp 'treesit-outline-predicate)
  (describe "navigation: outline (Emacs 30+)"
    (before-all
      (curry-test-skip-unless-grammar))

    (it "sets treesit-outline-predicate"
      (with-curry-buffer "foo = 1"
        (expect treesit-outline-predicate :not :to-be nil)))

    (it "outline-next-heading moves to the next definition"
      (with-curry-buffer "
          foo = 1

          bar = 2

          data T = T"
        (outline-minor-mode 1)
        (outline-next-heading)
        (expect (looking-at "bar") :to-be-truthy)
        (outline-next-heading)
        (expect (looking-at "data") :to-be-truthy)))))

;;; curry-navigation-test.el ends here
