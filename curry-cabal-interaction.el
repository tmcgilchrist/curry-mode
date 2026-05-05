;;; curry-cabal-interaction.el --- Cabal build system interaction -*- lexical-binding: t; -*-

;; Copyright (C) 2026 Tim McGilchrist
;;
;; Author: Tim McGilchrist <timmcgil@gmail.com>
;; Maintainer: Tim McGilchrist <timmcgil@gmail.com>
;; URL: https://github.com/tmcgilchrist/curry-mode
;; Keywords: languages haskell cabal

;; This file is not part of GNU Emacs.

;;; Commentary:

;; Minor mode for running cabal commands from any curry-mode buffer.
;; Provides keybindings for common cabal operations (build, test,
;; run, clean, repl, haddock, format) and navigation to cabal files.

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

(require 'cl-lib)

(defgroup curry-cabal-interaction nil
  "Cabal build system interaction for curry-mode."
  :prefix "curry-cabal-interaction-"
  :group 'curry
  :link '(url-link :tag "GitHub" "https://github.com/tmcgilchrist/curry-mode"))

(defcustom curry-cabal-program "cabal"
  "The cabal executable."
  :type 'string
  :safe #'stringp
  :group 'curry-cabal-interaction
  :package-version '(curry-mode . "0.1.0"))

(defcustom curry-cabal-project-root-files '("cabal.project" "*.cabal")
  "Glob patterns for files that indicate a Cabal project root.
The first ancestor directory containing any matching file is used
as the project root for cabal commands."
  :type '(repeat string)
  :group 'curry-cabal-interaction
  :package-version '(curry-mode . "0.1.0"))

;;; Project root detection

(defun curry-cabal--project-root ()
  "Find the Cabal project root by walking up from the current directory.
Returns the directory containing `cabal.project' or a `.cabal' file,
or signals an error if none is found."
  (or (curry-cabal--locate-project-root default-directory)
      (error "Not inside a Cabal project (no cabal.project or .cabal file found)")))

(defun curry-cabal--locate-project-root (dir)
  "Find the nearest ancestor of DIR containing a Cabal project file."
  (cl-some (lambda (pattern)
             (when-let* ((found (locate-dominating-file
                                 dir
                                 (lambda (d)
                                   (directory-files d nil (wildcard-to-regexp pattern) t)))))
               (file-name-as-directory (expand-file-name found))))
           curry-cabal-project-root-files))

;;; Running cabal commands

(defun curry-cabal--run (command &rest args)
  "Run a cabal COMMAND with ARGS via `compile' in the project root."
  (let* ((default-directory (curry-cabal--project-root))
         (cmd (concat (shell-quote-argument curry-cabal-program) " "
                      (mapconcat #'shell-quote-argument
                                 (cons command args) " "))))
    (compile cmd)))

;;;###autoload
(defun curry-cabal-build ()
  "Run `cabal build' in the project root."
  (interactive)
  (curry-cabal--run "build"))

;;;###autoload
(defun curry-cabal-build-all ()
  "Run `cabal build all' in the project root."
  (interactive)
  (curry-cabal--run "build" "all"))

;;;###autoload
(defun curry-cabal-test ()
  "Run `cabal test' in the project root."
  (interactive)
  (curry-cabal--run "test" "all"))

;;;###autoload
(defun curry-cabal-run (target)
  "Run `cabal run TARGET' in the project root.
Prompts for the executable target name."
  (interactive "sExecutable target: ")
  (curry-cabal--run "run" target))

;;;###autoload
(defun curry-cabal-clean ()
  "Run `cabal clean' in the project root."
  (interactive)
  (curry-cabal--run "clean"))

;;;###autoload
(defun curry-cabal-repl (&optional target)
  "Run `cabal repl' in the project root.
With a prefix argument, prompt for TARGET component."
  (interactive
   (list (when current-prefix-arg
           (read-string "REPL target: "))))
  (let* ((default-directory (curry-cabal--project-root))
         (cmd (if target
                  (format "%s repl %s"
                          (shell-quote-argument curry-cabal-program)
                          (shell-quote-argument target))
                (format "%s repl"
                        (shell-quote-argument curry-cabal-program)))))
    (compile cmd t)))

;;;###autoload
(defun curry-cabal-haddock ()
  "Run `cabal haddock' in the project root."
  (interactive)
  (curry-cabal--run "haddock"))

;;;###autoload
(defun curry-cabal-format ()
  "Run `cabal-fmt' on the project's .cabal file."
  (interactive)
  (let* ((default-directory (curry-cabal--project-root))
         (cabal-file (car (directory-files default-directory nil "\\.cabal\\'" t))))
    (if cabal-file
        (compile (format "cabal-fmt -i %s" (shell-quote-argument cabal-file)))
      (user-error "No .cabal file found in %s" default-directory))))

;;;###autoload
(defun curry-cabal-update ()
  "Run `cabal update'."
  (interactive)
  (compile (format "%s update" (shell-quote-argument curry-cabal-program))))

(defvar curry-cabal--command-history nil
  "History for `curry-cabal-command'.")

;;;###autoload
(defun curry-cabal-command (command)
  "Run an arbitrary cabal COMMAND in the project root.
Prompts for the full command string (without the `cabal' prefix).
The command string is passed as-is, not shell-quoted."
  (interactive
   (list (read-string "cabal command: " nil 'curry-cabal--command-history)))
  (let ((default-directory (curry-cabal--project-root)))
    (compile (concat (shell-quote-argument curry-cabal-program) " " command))))

;;; Navigation

;;;###autoload
(defun curry-cabal-find-cabal-file ()
  "Find the nearest `.cabal' file governing the current directory."
  (interactive)
  (let* ((dir (or (and buffer-file-name
                       (file-name-directory buffer-file-name))
                  default-directory))
         (found (locate-dominating-file
                 dir
                 (lambda (d)
                   (directory-files d nil "\\.cabal\\'" t)))))
    (if found
        (let ((cabal-file (car (directory-files found t "\\.cabal\\'"))))
          (find-file cabal-file))
      (user-error "No .cabal file found above %s" dir))))

;;;###autoload
(defun curry-cabal-find-cabal-project ()
  "Find the nearest `cabal.project' file."
  (interactive)
  (let* ((dir (or (and buffer-file-name
                       (file-name-directory buffer-file-name))
                  default-directory))
         (found (locate-dominating-file dir "cabal.project")))
    (if found
        (find-file (expand-file-name "cabal.project" found))
      (user-error "No cabal.project file found above %s" dir))))

;;; Minor mode

(defvar curry-cabal-interaction-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map (kbd "C-c C-d b") #'curry-cabal-build)
    (define-key map (kbd "C-c C-d B") #'curry-cabal-build-all)
    (define-key map (kbd "C-c C-d t") #'curry-cabal-test)
    (define-key map (kbd "C-c C-d r") #'curry-cabal-run)
    (define-key map (kbd "C-c C-d c") #'curry-cabal-clean)
    (define-key map (kbd "C-c C-d i") #'curry-cabal-repl)
    (define-key map (kbd "C-c C-d h") #'curry-cabal-haddock)
    (define-key map (kbd "C-c C-d f") #'curry-cabal-format)
    (define-key map (kbd "C-c C-d d") #'curry-cabal-command)
    (define-key map (kbd "C-c C-d .") #'curry-cabal-find-cabal-file)
    (define-key map (kbd "C-c C-d p") #'curry-cabal-find-cabal-project)
    (easy-menu-define curry-cabal-interaction-menu map
      "Cabal interaction menu."
      '("Cabal"
        ["Build" curry-cabal-build]
        ["Build All" curry-cabal-build-all]
        ["Test" curry-cabal-test]
        ["Run..." curry-cabal-run]
        ["Clean" curry-cabal-clean]
        ["REPL" curry-cabal-repl]
        ["Haddock" curry-cabal-haddock]
        ["Format .cabal" curry-cabal-format]
        "---"
        ["Find .cabal File" curry-cabal-find-cabal-file]
        ["Find cabal.project" curry-cabal-find-cabal-project]
        "---"
        ["Run Command..." curry-cabal-command]))
    map)
  "Keymap for `curry-cabal-interaction-mode'.")

;;;###autoload
(define-minor-mode curry-cabal-interaction-mode
  "Minor mode for running cabal commands from Haskell buffers.

Provides keybindings for common cabal operations:

\\{curry-cabal-interaction-mode-map}"
  :lighter " Cabal"
  :keymap curry-cabal-interaction-mode-map)

(provide 'curry-cabal-interaction)

;;; curry-cabal-interaction.el ends here
