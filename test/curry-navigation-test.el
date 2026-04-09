;;; curry-navigation-test.el --- Navigation tests for curry-mode -*- lexical-binding: t; -*-

;;; Commentary:

;; Buttercup tests for curry-mode navigation and imenu.

;;; Code:

(require 'curry-test-helpers)

(describe "curry-mode navigation"

  (describe "defun-name"

    (it "extracts function name"
      (with-curry-buffer "
        foo :: Int -> Int
        foo x = x + 1
        "
        (goto-char (point-min))
        (search-forward "foo x")
        (let ((node (treesit-node-at (point))))
          ;; Navigate up to the function node
          (while (and node
                      (not (string-match-p
                            "function\\|bind"
                            (treesit-node-type node))))
            (setq node (treesit-node-parent node)))
          (when node
            (expect (curry--defun-name node) :to-equal "foo"))))))

  (describe "imenu"

    (it "lists top-level functions"
      (with-curry-buffer "
        foo :: Int -> Int
        foo x = x + 1

        bar :: String -> String
        bar s = s
        "
        (let ((index (treesit-simple-imenu)))
          (expect index :not :to-be nil))))))

;;; curry-navigation-test.el ends here
