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

(define (current-doc-path)
  (editor-document->path (editor->doc-id (editor-focus))))

;; Returns the parent directory of `path` (the portion before the last "/" or
;; "\\"), or #f if `path` has no directory separator.
(define (path-parent path)
  (define len (string-length path))
  (let loop ([i (- len 1)])
    (cond
      [(< i 0) #f]
      [(or (char=? (string-ref path i) #\/) (char=? (string-ref path i) #\\))
       (substring path 0 i)]
      [else (loop (- i 1))])))

;; Recursively creates the ancestor directories of `path` (an absolute file
;; or directory path), stopping once an existing ancestor is found.
;; create-directory! is not recursive, so this walks top-down once the first
;; existing ancestor has been located.
(define (ensure-parent-dir! path)
  (define dir (path-parent path))
  (when (and dir (not (path-exists? dir)))
    (ensure-parent-dir! dir)
    (create-directory! dir)))

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

;; Resolves a [[link]] name to an absolute file path. A name starting with
;; "/" is anchored to the wiki root (VimWiki's root-relative link syntax);
;; any other name is resolved relative to the current note's directory,
;; matching VimWiki's default link resolution, so [[foo]] written in
;; <root>/projects/bar.md opens <root>/projects/foo.md rather than
;; <root>/foo.md.
(define (link-name->path name)
  (define rel (link-name->relative-path name))
  (if (starts-with? rel "/")
      (string-append *wiki-root* rel)
      (let ([base (or (path-parent (current-doc-path)) *wiki-root*)])
        (string-append base "/" rel))))

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
