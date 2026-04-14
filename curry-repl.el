;;; curry-repl.el --- GHCi REPL integration for curry-mode -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist
;;
;; Author: Tim McGilchrist <timmcgil@gmail.com>
;; Maintainer: Tim McGilchrist <timmcgil@gmail.com>
;; URL: https://github.com/tmcgilchrist/curry-mode
;; Keywords: languages haskell

;; This file is not part of GNU Emacs.

;;; Commentary:

;; This library provides integration with GHCi (the GHC interactive
;; environment) for the curry-mode package.  It offers a comint-based
;; REPL with tree-sitter syntax highlighting for input, and a minor
;; mode for sending code from source buffers.

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

(require 'comint)
(require 'pulse)
(require 'curry-mode)

(defgroup curry-repl nil
  "GHCi REPL integration for curry-mode."
  :prefix "curry-repl-"
  :group 'curry)

(defcustom curry-repl-program-name "ghci"
  "Program name for invoking GHCi.
Can also be set to \"cabal repl\" or \"stack ghci\" for
project-aware REPL sessions."
  :type 'string
  :group 'curry-repl
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-repl-program-args nil
  "Command line arguments for `curry-repl-program-name'."
  :type '(repeat string)
  :group 'curry-repl
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-repl-buffer-name "*GHCi*"
  "Name of the GHCi REPL buffer."
  :type 'string
  :group 'curry-repl
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-repl-history-file
  (expand-file-name "curry-repl-history" user-emacs-directory)
  "File to persist GHCi REPL input history across sessions.
Set to nil to disable history persistence."
  :type '(choice (file :tag "History file")
                 (const :tag "Disable" nil))
  :group 'curry-repl
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-repl-history-size 1000
  "Maximum number of input history entries to persist."
  :type 'integer
  :group 'curry-repl
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-repl-fontify-input t
  "When non-nil, fontify REPL input using tree-sitter via `curry-mode'.
This uses `comint-fontify-input-mode' (Emacs 29.1+) to provide full
syntax highlighting for Haskell code you type in the REPL, while REPL
output keeps its own highlighting.

Set to nil to use only the basic REPL font-lock keywords for input."
  :type 'boolean
  :group 'curry-repl
  :package-version '(curry-mode . "0.1.0"))

(defconst curry-repl--prompt-regexp
  "^\\(?:[A-Z][A-Za-z0-9_.]*\\(?:| [A-Z][A-Za-z0-9_.]*\\)*\\)?> \\|^\\*?[A-Z][A-Za-z0-9_.]*> \\|^ghci> \\|^> "
  "Regexp matching GHCi prompts.
Matches \"Prelude> \", \"Main> \", \"ghci> \", \"> \",
\"Prelude Data.List> \", and \"*Main> \" style prompts.")

(defvar-local curry-repl--source-buffer nil
  "Source buffer from which the REPL was last invoked.
Used by `curry-repl-switch-to-source' to return to the source buffer.")

(defvar curry-repl-mode-map
  (let ((map (make-sparse-keymap)))
    (set-keymap-parent map comint-mode-map)
    (define-key map (kbd "C-c C-z") #'curry-repl-switch-to-source)
    map)
  "Keymap for `curry-repl-mode'.")

(defvar curry-repl-font-lock-keywords
  '(;; GHC errors
    ("^\\([^ \t\n:]+\\):\\([0-9]+\\):\\([0-9]+\\): error:" (1 font-lock-warning-face))
    ;; GHC warnings
    ("^\\([^ \t\n:]+\\):\\([0-9]+\\):\\([0-9]+\\): warning:" (1 font-lock-warning-face))
    ;; Type display: "foo :: Int -> Int"
    ("^\\([a-z_][a-zA-Z0-9_']*\\) :: " (1 font-lock-function-name-face))
    ;; Kind display
    ("^\\([A-Z][a-zA-Z0-9_']*\\) :: " (1 font-lock-type-face))
    ;; GHCi commands
    ("^:[a-z]+" . font-lock-keyword-face))
  "Font-lock keywords for the GHCi REPL buffer.
Highlights errors, warnings, type information, and GHCi commands.")

(define-derived-mode curry-repl-mode comint-mode "GHCi"
  "Major mode for interacting with GHCi.

\\{curry-repl-mode-map}"
  (setq comint-prompt-regexp curry-repl--prompt-regexp)
  (setq comint-prompt-read-only t)
  (setq comint-process-echoes nil)
  ;; Strip ANSI escape sequences
  (ansi-color-for-comint-mode-on)
  (setq-local comment-start "-- ")
  (setq-local comment-end "")
  (setq-local font-lock-defaults '(curry-repl-font-lock-keywords t))

  ;; Error navigation
  (setq-local compilation-error-regexp-alist
              '(("^\\([^ \t\n:]+\\):\\([0-9]+\\):\\([0-9]+\\):" 1 2 3)))
  (compilation-shell-minor-mode)

  ;; Input history persistence
  (when curry-repl-history-file
    (setq comint-input-ring-file-name curry-repl-history-file)
    (setq comint-input-ring-size curry-repl-history-size)
    (setq comint-input-ignoredups t)
    (comint-read-input-ring t)
    (add-hook 'kill-buffer-hook #'comint-write-input-ring nil t))

  ;; Prettify symbols
  (setq-local prettify-symbols-alist (curry--prettify-symbols-alist))

  ;; Tree-sitter fontification for REPL input
  (when curry-repl-fontify-input
    (setq-local comint-indirect-setup-function #'curry-mode)
    (comint-fontify-input-mode)))

;;;###autoload
(defun curry-repl-start ()
  "Start a GHCi process in a new buffer.
If a process is already running, switch to its buffer."
  (interactive)
  (if (comint-check-proc curry-repl-buffer-name)
      (pop-to-buffer curry-repl-buffer-name)
    (let* ((cmdlist (append (split-string curry-repl-program-name)
                            curry-repl-program-args))
           (buffer (apply #'make-comint-in-buffer
                          "GHCi" curry-repl-buffer-name
                          (car cmdlist) nil (cdr cmdlist))))
      (with-current-buffer buffer
        (curry-repl-mode))
      (pop-to-buffer buffer))))

(defun curry-repl-switch-to-source ()
  "Switch from the REPL back to the source buffer that last invoked it."
  (interactive)
  (if (and curry-repl--source-buffer
           (buffer-live-p curry-repl--source-buffer))
      (pop-to-buffer curry-repl--source-buffer)
    (message "No source buffer to return to")))

;;;###autoload
(defun curry-repl-switch-to-repl ()
  "Switch to the GHCi REPL, saving the current buffer as the source.
If a REPL is already running, switch to it; otherwise start a new one.
Use \\[curry-repl-switch-to-source] in the REPL to return."
  (interactive)
  (let ((source (current-buffer)))
    (if (comint-check-proc curry-repl-buffer-name)
        (pop-to-buffer curry-repl-buffer-name)
      (curry-repl-start))
    (setq curry-repl--source-buffer source)))

(defun curry-repl--process ()
  "Return the REPL process, or nil if not running."
  (get-buffer-process curry-repl-buffer-name))

(defun curry-repl--ensure-running ()
  "Start a GHCi REPL if one is not already running."
  (unless (comint-check-proc curry-repl-buffer-name)
    (save-window-excursion (curry-repl-start))))

(defun curry-repl--send-string (string)
  "Send STRING to the GHCi REPL process.
For multiline input, wraps in GHCi's :{...}:} block."
  (curry-repl--ensure-running)
  (let ((proc (curry-repl--process)))
    (if (string-match-p "\n" string)
        ;; Multiline: use GHCi's multiline input syntax
        (progn
          (comint-send-string proc ":{")
          (comint-send-string proc "\n")
          (comint-send-string proc string)
          (comint-send-string proc "\n")
          (comint-send-string proc ":}\n"))
      ;; Single line
      (comint-send-string proc (concat string "\n")))))

;;;###autoload
(defun curry-repl-send-region (start end)
  "Send the region between START and END to the GHCi REPL."
  (interactive "r")
  (let ((text (string-trim (buffer-substring-no-properties start end))))
    (curry-repl--send-string text)
    (pulse-momentary-highlight-region start end)))

;;;###autoload
(defun curry-repl-send-buffer ()
  "Send the entire buffer to the GHCi REPL."
  (interactive)
  (curry-repl-send-region (point-min) (point-max)))

;;;###autoload
(defun curry-repl-send-definition ()
  "Send the current definition to the GHCi REPL."
  (interactive)
  (if-let* ((node (treesit-defun-at-point))
            (start (treesit-node-start node))
            (end (treesit-node-end node)))
      (curry-repl-send-region start end)
    (user-error "No definition at point")))

;;;###autoload
(defun curry-repl-send-line ()
  "Send the current line to the GHCi REPL."
  (interactive)
  (let ((line (string-trim (thing-at-point 'line t))))
    (curry-repl--send-string line)
    (pulse-momentary-highlight-one-line (point))))

;;;###autoload
(defun curry-repl-load-file (&optional file)
  "Load FILE into GHCi via the `:load' command.
Defaults to the current buffer's file."
  (interactive)
  (let ((file (or file (buffer-file-name))))
    (unless file
      (user-error "Buffer is not visiting a file"))
    (when (buffer-modified-p)
      (save-buffer))
    (curry-repl--ensure-running)
    (comint-send-string (curry-repl--process)
                        (format ":load %s\n" (shell-quote-argument file)))))

;;;###autoload
(defun curry-repl-reload ()
  "Reload the current module in GHCi via `:reload'."
  (interactive)
  (when (buffer-modified-p)
    (save-buffer))
  (curry-repl--ensure-running)
  (comint-send-string (curry-repl--process) ":reload\n"))

;;;###autoload
(defun curry-repl-type-at-point ()
  "Show the type of the expression at point via GHCi's `:type' command."
  (interactive)
  (let ((expr (or (when (use-region-p)
                    (buffer-substring-no-properties
                     (region-beginning) (region-end)))
                  (thing-at-point 'symbol t))))
    (unless expr
      (user-error "No expression at point"))
    (curry-repl--ensure-running)
    (comint-send-string (curry-repl--process)
                        (format ":type %s\n" expr))))

;;;###autoload
(defun curry-repl-info-at-point ()
  "Show info about the identifier at point via GHCi's `:info' command."
  (interactive)
  (let ((sym (thing-at-point 'symbol t)))
    (unless sym
      (user-error "No identifier at point"))
    (curry-repl--ensure-running)
    (comint-send-string (curry-repl--process)
                        (format ":info %s\n" sym))))

(defun curry-repl-clear-buffer ()
  "Clear the GHCi REPL buffer."
  (interactive)
  (with-current-buffer curry-repl-buffer-name
    (let ((inhibit-read-only t))
      (erase-buffer)
      (comint-send-input))))

(defun curry-repl-interrupt ()
  "Interrupt the GHCi REPL process."
  (interactive)
  (when (comint-check-proc curry-repl-buffer-name)
    (interrupt-process (curry-repl--process))))

;;; Minor mode for source buffers

(defvar curry-repl-minor-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-z") #'curry-repl-switch-to-repl)
    (define-key map (kbd "C-c C-c") #'curry-repl-send-definition)
    (define-key map (kbd "C-c C-r") #'curry-repl-send-region)
    (define-key map (kbd "C-c C-b") #'curry-repl-send-buffer)
    (define-key map (kbd "C-c C-l") #'curry-repl-load-file)
    (define-key map (kbd "C-c C-k") #'curry-repl-reload)
    (define-key map (kbd "C-c C-t") #'curry-repl-type-at-point)
    (define-key map (kbd "C-c C-i") #'curry-repl-info-at-point)

    (easy-menu-define curry-repl-minor-mode-menu map "GHCi REPL Menu"
      '("GHCi"
        ["Start/Switch to REPL" curry-repl-switch-to-repl]
        "--"
        ["Send Definition" curry-repl-send-definition]
        ["Send Region" curry-repl-send-region :active mark-active]
        ["Send Buffer" curry-repl-send-buffer]
        ["Send Line" curry-repl-send-line]
        "--"
        ["Load File" curry-repl-load-file]
        ["Reload" curry-repl-reload]
        "--"
        ["Type at Point" curry-repl-type-at-point]
        ["Info at Point" curry-repl-info-at-point]
        "--"
        ["Interrupt REPL" curry-repl-interrupt]
        ["Clear REPL Buffer" curry-repl-clear-buffer]))
    map)
  "Keymap for GHCi REPL interaction from source buffers.")

;;;###autoload
(define-minor-mode curry-repl-minor-mode
  "Minor mode for interacting with GHCi from Haskell source buffers.

\\{curry-repl-minor-mode-map}"
  :lighter " GHCi"
  :keymap curry-repl-minor-mode-map)

(provide 'curry-repl)

;;; curry-repl.el ends here
