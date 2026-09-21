;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; hxwiki.scm - VimWiki-style note-taking plugin for Helix
;;;
;;; Provides link following/creation and a daily diary for a plain-Markdown
;;; wiki vault, inspired by VimWiki. The Helix-independent logic (vault path
;;; handling, [[link]] scanning/resolution, rename-with-link-update) lives in
;;; hxwiki-core.scm so it can be unit-tested outside of Helix -- see tests/.
;;;
;;; Usage:
;;;   :hxwiki-index               - Open (or create) the vault's index.md
;;;   :hxwiki-diary-today         - Open/create today's diary entry (diary/YYYY/MM/DD.md)
;;;   :hxwiki-follow-or-create    - Follow the [[link]] under the cursor, creating
;;;                                 the target file if it doesn't exist yet
;;;   :hxwiki-rename <new-name>   - Rename the current note to <new-name> (same
;;;                                 syntax as a [[link]] name) and rewrite every
;;;                                 [[link]] across the vault that pointed at it
;;;   (set-hxwiki-root! path)     - Point the plugin at a different vault; "~" is
;;;                                 expanded to the user's home directory
;;;
;;; Default vault root is "~/hxwiki"; override with `set-hxwiki-root!` in init.scm.

(require "helix/editor.scm")
(require "helix/misc.scm")
(require (prefix-in helix. "helix/commands.scm"))
(require (prefix-in helix.static. "helix/static.scm"))
(require-builtin helix/core/text as text.)
(require-builtin steel/time)
(require "hxwiki-core.scm")

(provide hxwiki-index
         hxwiki-diary-today
         hxwiki-follow-or-create
         hxwiki-rename
         hxwiki-paste-image
         set-hxwiki-root!
         set-hxwiki-assets-dir-name!)

;; --- helpers ---

(define (current-doc-text)
  (text.rope->string (editor->text (editor->doc-id (editor-focus)))))

(define (current-doc-path)
  (editor-document->path (editor->doc-id (editor-focus))))

;; Resolves a [[link]] name relative to the currently focused note.
(define (link-name->path name)
  (link-name->path-from (or (path-parent (current-doc-path)) (wiki-root)) name))

;; --- commands ---

;;@doc
;; Opens (or creates) the wiki's index.md
(define (hxwiki-index)
  (helix.open (string-append (wiki-root) "/index.md")))

;;@doc
;; Opens (or creates) today's diary entry, at diary/YYYY/MM/DD.md
(define (hxwiki-diary-today)
  (define date (local-time/now! "%Y-%m-%d"))
  (define date-path (local-time/now! "%Y/%m/%d"))
  (define rel (string-append "diary/" date-path ".md"))
  (define full (string-append (wiki-root) "/" rel))
  (define is-new (not (path-exists? full)))
  (ensure-parent-dir! full)
  (helix.open full)
  (when is-new
    (helix.static.insert_string (string-append "# " date "\n\n"))))

;;@doc
;; Follows the [[...]] link under the cursor, creating the target file if it
;; doesn't exist yet
(define (hxwiki-follow-or-create)
  (define text (current-doc-text))
  (define pos (cursor-position))
  (define name (find-link-at text pos))
  (if name
      (let ([target (link-name->path name)])
        (ensure-parent-dir! target)
        (helix.open target))
      (set-status! "No [[link]] under the cursor")))

;;@doc
;; Renames the current note to <new-name> (same syntax as a [[link]] name:
;; "/"-prefixed to anchor it to the wiki root, otherwise relative to the
;; current note's directory) and rewrites every [[link]] across the vault
;; that pointed at it. The note being renamed must already be saved to disk.
(define (hxwiki-rename . args)
  (if (null? args)
      (set-status! "Usage: :hxwiki-rename <new-name>")
      (let* ([new-name (string-join args " ")]
             [old-path (current-doc-path)])
        (cond
          [(not (and old-path (is-file? old-path)))
           (set-status! "Current buffer is not a saved note")]
          [else
           (let ([new-path (link-name->path new-name)])
             (cond
               [(paths-equal? old-path new-path) (set-status! "Already named that")]
               [(path-exists? new-path)
                (set-status! (string-append "A note already exists at " new-path))]
               [else
                (define updated (update-links-in-vault! old-path new-path))
                (ensure-parent-dir! new-path)
                (rename-file-or-directory! old-path new-path)
                (helix.open new-path)
                (set-status!
                 (string-append "Renamed to "
                                 new-path
                                 " ("
                                 (number->string updated)
                                 " note(s) updated)"))]))]))))

;;@doc
;; Saves the image currently on the OS clipboard into a folder next to the
;; current note (named by (wiki-assets-dir-name), "assets" by default --
;; override with set-hxwiki-assets-dir-name!) and inserts a ![](...) link to
;; it at the cursor. The current buffer must already be a saved note.
;; Windows only for now.
(define (hxwiki-paste-image)
  (define doc-path (current-doc-path))
  (if (not (and doc-path (is-file? doc-path)))
      (set-status! "Current buffer is not a saved note")
      (let* ([dir (assets-dir-for doc-path)]
             [filename (string-append "paste-" (local-time/now! "%Y%m%d-%H%M%S") ".png")]
             [target (unique-path (string-append dir "/" filename))])
        (ensure-parent-dir! target)
        (let ([result (paste-clipboard-image! target)])
          (cond
            [(equal? result 'ok)
             (helix.static.insert_string
              (string-append "![](" (wiki-assets-dir-name) "/" (file-name target) ")"))]
            [(equal? result 'no-image) (set-status! "Clipboard has no image")]
            [(equal? result 'unsupported)
             (set-status! "hxwiki-paste-image: only Windows is supported so far")]
            [else (set-status! "hxwiki-paste-image: failed to run PowerShell")])))))
