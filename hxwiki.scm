;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; hxwiki.scm - VimWiki-style note-taking plugin for Helix
;;;
;;; Provides link following/creation and a daily diary for a plain-Markdown
;;; wiki vault, inspired by VimWiki.
;;;
;;; Usage:
;;;   :hxwiki-index               - Open (or create) the vault's index.md
;;;   :hxwiki-diary-today         - Open/create today's diary entry (diary/YYYY/MM/DD.md)
;;;   :hxwiki-follow-or-create    - Follow the [[link]] under the cursor, creating
;;;                                 the target file if it doesn't exist yet
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

(provide hxwiki-index
         hxwiki-diary-today
         hxwiki-follow-or-create
         set-hxwiki-root!)

;; Expands a leading "~" to the user's home directory (USERPROFILE)
(define (expand-user path)
  (if (starts-with? path "~")
      (string-append (env-var "USERPROFILE") (substring path 1 (string-length path)))
      path))

(define *wiki-root* (expand-user "~/hxwiki"))

;;@doc
;; Sets the wiki vault root (the directory where .md notes live). Accepts a
;; leading "~" as shorthand for the user's home directory, e.g. "~/hxwiki"
(define (set-hxwiki-root! path)
  (set! *wiki-root* (expand-user path)))

;; --- helpers ---

(define (current-doc-text)
  (text.rope->string (editor->text (editor->doc-id (editor-focus)))))

;; Ensures the intermediate directories exist (create-directory! is not recursive)
(define (ensure-parent-dir! relative-path)
  (define segments (split-many relative-path "/"))
  (define dirs (reverse (cdr (reverse segments))))
  (let loop ([acc *wiki-root*]
             [rest dirs])
    (unless (null? rest)
      (define next (string-append acc "/" (car rest)))
      (unless (path-exists? next)
        (create-directory! next))
      (loop next (cdr rest)))))

;; Finds the index (within `text`) of the "]]" closer, starting the search at `i`.
;; Returns the position of the pair's first "]", or #f if none is found.
(define (find-close text i)
  (define len (string-length text))
  (cond
    [(>= i (- len 1)) #f]
    [(and (char=? (string-ref text i) #\]) (char=? (string-ref text (+ i 1)) #\]))
     i]
    [else (find-close text (+ i 1))]))

;; Finds the [[...]] span that contains `pos` within `text`. Returns the
;; captured text (string) or #f. Implemented as a manual scan because Steel
;; does not yet expose a general-purpose regex library to scripts.
(define (find-link-at text pos)
  (define len (string-length text))
  (define (scan i)
    (cond
      [(>= i (- len 1)) #f]
      [(and (char=? (string-ref text i) #\[) (char=? (string-ref text (+ i 1)) #\[))
       (define content-start (+ i 2))
       (define close (find-close text content-start))
       (if (and close (<= i pos) (<= pos (+ close 1)))
           (substring text content-start close)
           (scan (+ i 2)))]
      [else (scan (+ i 1))]))
  (scan 0))

(define (link-name->relative-path name)
  (if (ends-with? name ".md") name (string-append name ".md")))

(define (link-name->path name)
  (string-append *wiki-root* "/" (link-name->relative-path name)))

;; --- commands ---

;;@doc
;; Opens (or creates) the wiki's index.md
(define (hxwiki-index)
  (helix.open (string-append *wiki-root* "/index.md")))

;;@doc
;; Opens (or creates) today's diary entry, at diary/YYYY/MM/DD.md
(define (hxwiki-diary-today)
  (define date (local-time/now! "%Y-%m-%d"))
  (define date-path (local-time/now! "%Y/%m/%d"))
  (define rel (string-append "diary/" date-path ".md"))
  (define full (string-append *wiki-root* "/" rel))
  (define is-new (not (path-exists? full)))
  (ensure-parent-dir! rel)
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
      (begin
        (ensure-parent-dir! (link-name->relative-path name))
        (helix.open (link-name->path name)))
      (set-status! "No [[link]] under the cursor")))
