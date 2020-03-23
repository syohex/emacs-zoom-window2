;;; zoom-window2.el --- Zoom window like tmux -*- lexical-binding: t; -*-

;; Copyright (C) 2020 by Syohei YOSHIDA

;; Author: Shohei YOSHIDA <syohex@gmail.com>
;; URL: https://github.com/syohex/emacs-zoom-window2
;; Version: 0.05
;; Package-Requires: ((emacs "26.3"))

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; zoom-window2.el provides functions which zooms specific window in frame and
;; restore original window configuration. This is like tmux's zoom/unzoom
;; features.

;;; Code:

(require 'cl-lib)

;; for byte-compile warnings
(declare-function elscreen-get-screen-property "elscreen")
(declare-function elscreen-get-current-screen "elscreen")
(declare-function elscreen-set-screen-property "elscreen")
(declare-function elscreen-get-conf-list "elscreen")

(defgroup zoom-window2 nil
  "zoom window like tmux"
  :group 'windows)

(defcustom zoom-window2-use-elscreen nil
  "non-nil means using elscreen"
  :type 'boolean)

(defcustom zoom-window2-mode-line-color "green"
  "Color of mode-line when zoom-window2 is enabled"
  :type 'string)

(defvar zoom-window2--window-configuration (make-hash-table :test #'equal))
(defvar zoom-window2--orig-color nil)

(defun zoom-window2--put-alist (key value alist)
  (let ((elm (assoc key alist)))
    (if elm
        (progn
          (setcdr elm value)
          alist)
      (cons (cons key value) alist))))

(defsubst zoom-window2--elscreen-current-property ()
  (elscreen-get-screen-property (elscreen-get-current-screen)))

(defsubst zoom-window2--elscreen-current-tab-property (prop)
  (let ((property (zoom-window2--elscreen-current-property)))
    (assoc-default prop property)))

(defun zoom-window2--elscreen-update ()
  (let* ((property (zoom-window2--elscreen-current-property))
         (orig-background (assoc-default 'zoom-window2-saved-color property))
         (is-zoomed (assoc-default 'zoom-window2-is-zoomed property))
         (curframe (window-frame nil)))
    (if is-zoomed
        (set-face-background 'mode-line zoom-window2-mode-line-color curframe)
      (when orig-background
        (set-face-background 'mode-line orig-background curframe)))
    (force-mode-line-update)))

(defun zoom-window2--elscreen-set-zoomed ()
  (let* ((current-screen (elscreen-get-current-screen))
         (prop (elscreen-get-screen-property current-screen))
         (orig-mode-line (face-background 'mode-line)))
    (setq prop (zoom-window2--put-alist 'zoom-window2-saved-color orig-mode-line prop))
    (elscreen-set-screen-property current-screen prop)))

(defun zoom-window2--elscreen-set-default ()
  (let* ((history (elscreen-get-conf-list 'screen-history))
         (current-screen (car (last history)))
         (prop (elscreen-get-screen-property current-screen)))
    (setq prop (zoom-window2--put-alist 'zoom-window2-is-zoomed nil prop))
    (setq prop (zoom-window2--put-alist 'zoom-window2-saved-color zoom-window2--orig-color prop))
    (elscreen-set-screen-property current-screen prop)))

;;;###autoload
(defun zoom-window2-setup ()
  "To work with elscreen"
  (cond
   ;; to work with elscreen
   (zoom-window2-use-elscreen
    (setq zoom-window2--orig-color (face-background 'mode-line))

    (add-hook 'elscreen-create-hook 'zoom-window2--elscreen-set-default)
    (add-hook 'elscreen-screen-update-hook 'zoom-window2--elscreen-update)
    ;; for first tab
    (zoom-window2--elscreen-set-default))
   ;; do nothing else
   (t nil)))

(defun zoom-window2--save-mode-line-color ()
  (cond (zoom-window2-use-elscreen
         (zoom-window2--elscreen-set-zoomed))
        (t (setq zoom-window2--orig-color (face-background 'mode-line)))))

(defun zoom-window2--save-buffers ()
  (let ((buffers (cl-loop for window in (window-list)
                          collect (window-buffer window))))
    (cond (zoom-window2-use-elscreen
           (let* ((curprops (zoom-window2--elscreen-current-property))
                  (props (zoom-window2--put-alist 'zoom-window2-buffers buffers curprops)))
             (elscreen-set-screen-property (elscreen-get-current-screen) props)))
          (t
           (set-frame-parameter
            (window-frame nil) 'zoom-window2-buffers buffers)))))

(defun zoom-window2--get-buffers ()
  (cond (zoom-window2-use-elscreen
         (let ((props (zoom-window2--elscreen-current-property)))
           (assoc-default 'zoom-window2-buffers props)))
        (t
         (frame-parameter (window-frame nil) 'zoom-window2-buffers))))

(defun zoom-window2--restore-mode-line-face ()
  (let ((color
         (cond (zoom-window2-use-elscreen
                (zoom-window2--elscreen-current-tab-property
                 'zoom-window2-saved-color))
               (t zoom-window2--orig-color))))
    (set-face-background 'mode-line color (window-frame nil))))

(defun zoom-window2--configuration-key ()
  (cond (zoom-window2-use-elscreen
         (format "zoom-window2-%d" (elscreen-get-current-screen)))
        (t (let ((parent-id (frame-parameter (window-frame nil) 'parent-id)))
             (if (not parent-id)
                 :zoom-window2 ;; not support multiple frame
               (format ":zoom-window2-%d" parent-id))))))

(defun zoom-window2--save-window-configuration ()
  (let ((key (zoom-window2--configuration-key))
        (window-conf (list (current-window-configuration) (point-marker))))
    (puthash key window-conf zoom-window2--window-configuration)))

(defun zoom-window2--restore-window-configuration ()
  (let* ((key (zoom-window2--configuration-key))
         (window-context (gethash key zoom-window2--window-configuration 'not-found)))
    (when (eq window-context 'not-found)
      (error "window configuration is not found"))
    (let ((window-conf (cl-first window-context))
          (marker (cl-second window-context)))
      (set-window-configuration window-conf)
      (when (marker-buffer marker)
        (goto-char marker))
      (remhash key zoom-window2--window-configuration))))

(defun zoom-window2--toggle-enabled ()
  (cond
   (zoom-window2-use-elscreen
    (let* ((current-screen (elscreen-get-current-screen))
           (prop (elscreen-get-screen-property current-screen))
           (val (assoc-default 'zoom-window2-is-zoomed prop)))
      (setq prop (zoom-window2--put-alist 'zoom-window2-is-zoomed (not val) prop))
      (elscreen-set-screen-property current-screen prop)))
   (t (let* ((curframe (window-frame nil))
             (status (frame-parameter curframe 'zoom-window2-enabled)))
        (set-frame-parameter curframe 'zoom-window2-enabled (not status))))))

(defun zoom-window2--enable-p ()
  (cond
   (zoom-window2-use-elscreen
    (zoom-window2--elscreen-current-tab-property 'zoom-window2-is-zoomed))
   (t (frame-parameter (window-frame nil) 'zoom-window2-enabled))))

(defsubst zoom-window2--goto-line (line)
  (goto-char (point-min))
  (forward-line (1- line)))

(defun zoom-window2--do-unzoom ()
  (let ((current-line (line-number-at-pos))
        (current-column (current-column))
        (current-buf (current-buffer)))
    (zoom-window2--restore-mode-line-face)
    (zoom-window2--restore-window-configuration)
    (unless (string= (buffer-name current-buf) (buffer-name))
      (switch-to-buffer current-buf))
    (zoom-window2--goto-line current-line)
    (move-to-column current-column)))

;;;###autoload
(defun zoom-window2-zoom ()
  (interactive)
  (let ((enabled (zoom-window2--enable-p))
        (curframe (window-frame nil)))
    (if (and (one-window-p) (not enabled))
        (message "There is only one window!!")
      (if enabled
          (with-demoted-errors "Warning: %S"
            (zoom-window2--do-unzoom))
        (zoom-window2--save-mode-line-color)
        (zoom-window2--save-buffers)
        (zoom-window2--save-window-configuration)
        (delete-other-windows)
        (set-face-background 'mode-line zoom-window2-mode-line-color curframe))
      (force-mode-line-update)
      (zoom-window2--toggle-enabled))))

(defun zoom-window2-next ()
  "Switch to next buffer which is in zoomed frame/screen"
  (interactive)
  (let* ((buffers (zoom-window2--get-buffers))
         (targets (member (current-buffer) buffers)))
    (if targets
        (if (cdr targets)
            (switch-to-buffer (cadr targets))
          (switch-to-buffer (car buffers)))
      (switch-to-buffer (car buffers)))))

(provide 'zoom-window2)

;;; zoom-window2.el ends here
