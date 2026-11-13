;;; curry-prettify-test.el --- Prettify-symbols tests for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist

;;; Commentary:

;; Buttercup tests for the `prettify-symbols-mode' integration:
;; which operators and words curry-mode composes, and where it leaves
;; them alone.

;;; Code:

(require 'curry-test-helpers)

(defun curry-test--composed-char (text &optional nth)
  "Return the character the NTH occurrence of TEXT is composed into.
NTH defaults to 1.  Return nil when that occurrence is not composed.
Signal an error when TEXT does not occur NTH times, so a typo in a
fixture cannot pass as a missing composition."
  (save-excursion
    (goto-char (point-min))
    (unless (search-forward text nil t (or nth 1))
      (error "Text %S not found in buffer" text))
    (let ((composition (get-text-property (match-beginning 0) 'composition)))
      (when (and composition
                 (= (get-text-property (match-beginning 0)
                                       'prettify-symbols-end)
                    (match-end 0)))
        (cdr (car composition))))))

(defmacro with-curry-prettified-buffer (content &rest body)
  "Run BODY in a `curry-mode' buffer holding CONTENT, prettified.
Enables `prettify-symbols-mode' and fontifies the whole buffer, which
is what applies the compositions."
  (declare (indent 1))
  `(with-curry-buffer ,content
     (prettify-symbols-mode 1)
     (font-lock-ensure)
     ,@body))

(describe "curry-mode prettify-symbols"
  (before-all
    (curry-test-skip-unless-grammar))

  (describe "operators"
    (it "installs `curry-prettify-symbols-alist' by default"
      (with-curry-buffer "f = x"
        (expect prettify-symbols-alist
                :to-equal curry-prettify-symbols-alist)))

    (it "composes the arrow in a type signature"
      (with-curry-prettified-buffer "f :: Int -> Int"
        (expect (curry-test--composed-char "->") :to-equal ?→)))

    (it "composes a lambda backslash"
      (with-curry-prettified-buffer "f = \\x -> x"
        (expect (curry-test--composed-char "\\") :to-equal ?λ)))

    (it "composes comparison and boolean operators"
      (with-curry-prettified-buffer "f x y = x /= y && x >= y || x == y"
        (expect (curry-test--composed-char "/=") :to-equal ?≠)
        (expect (curry-test--composed-char "&&") :to-equal ?∧)
        (expect (curry-test--composed-char ">=") :to-equal ?≥)
        (expect (curry-test--composed-char "||") :to-equal ?∨)
        (expect (curry-test--composed-char "==") :to-equal ?≡)))

    (it "composes a constraint arrow and a bind arrow"
      (with-curry-prettified-buffer "
        f :: Show a => a -> IO ()
        f x = do
          y <- pure x
          print y"
        (expect (curry-test--composed-char "=>") :to-equal ?⇒)
        (expect (curry-test--composed-char "<-") :to-equal ?←))))

  (describe "where it does not compose"
    (it "leaves an arrow inside a comment alone"
      (with-curry-prettified-buffer "f = x -- a -> b"
        (expect (curry-test--composed-char "->") :to-be nil)))

    (it "leaves an arrow inside a string alone"
      (with-curry-prettified-buffer "f = \"a -> b\""
        (expect (curry-test--composed-char "->") :to-be nil)))

    (it "leaves an arrow that is part of a longer operator alone"
      (with-curry-prettified-buffer "f = x --> y"
        (expect (curry-test--composed-char "->") :to-be nil))))

  (describe "words"
    (it "does not compose words by default"
      (with-curry-prettified-buffer "f :: forall a. a\nf = undefined"
        (expect (curry-test--composed-char "forall") :to-be nil)
        (expect (curry-test--composed-char "undefined") :to-be nil)))

    (it "composes words when `curry-prettify-words' is set"
      (let ((curry-prettify-words t))
        (with-curry-prettified-buffer "f :: forall a. a -> a\nf = undefined"
          (expect (curry-test--composed-char "forall") :to-equal ?∀)
          (expect (curry-test--composed-char "undefined") :to-equal ?⊥)
          (expect (curry-test--composed-char "->") :to-equal ?→))))

    (it "leaves a word that is part of a longer identifier alone"
      (let ((curry-prettify-words t))
        (with-curry-prettified-buffer "f = undefinedThing"
          (expect (curry-test--composed-char "undefined") :to-be nil))))))

;;; curry-prettify-test.el ends here
