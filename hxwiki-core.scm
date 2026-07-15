;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; hxwiki-core.scm - Helix-independent logic for hxwiki
;;;
;;; Vault root handling, [[link]] scanning/resolution, and the
;;; rename-with-link-update machinery. None of this touches the Helix editor
;;; APIs, so it can be `require`d and exercised directly under a bare `steel`
;;; process -- see tests/.

(provide wiki-root
         set-hxwiki-root!
         path-parent
         ensure-parent-dir!
         scan-links
         find-link-at
         link-name->relative-path
         link-name->path-from
         paths-equal?
         path->root-relative
         relative-link-name
         list-md-files
         read-file-to-string
         write-string-to-file!
         rewrite-link-name
         rewrite-links-in-text
         update-links-in-vault!)

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

;; Getter for *wiki-root*, for use by other modules (hxwiki.scm). A `require`d
;; variable binding is a snapshot taken at require-time, not a live alias --
;; a caller that read *wiki-root* directly would never see a later
;; set-hxwiki-root! call. A function is immune to this: it's a closure that
;; re-reads *wiki-root* from this module's own environment on every call.
(define (wiki-root) *wiki-root*)

;; --- path helpers ---

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

;; --- [[link]] scanning ---

;; Finds the index (within `text`) of the "]]" closer, starting the search at `i`.
;; Returns the position of the pair's first "]", or #f if none is found.
(define (find-close text i)
  (define len (string-length text))
  (cond
    [(>= i (- len 1)) #f]
    [(and (char=? (string-ref text i) #\]) (char=? (string-ref text (+ i 1)) #\]))
     i]
    [else (find-close text (+ i 1))]))

;; Returns a list of (open-pos content-start content-end) triples, one per
;; [[...]] span found in `text`, in order of appearance. content-start/end
;; delimit the captured name (content-end is the index of the first "]" of
;; the closing "]]"). Implemented as a manual scan because Steel does not
;; yet expose a general-purpose regex library to scripts.
(define (scan-links text)
  (define len (string-length text))
  (define (scan i acc)
    (cond
      [(>= i (- len 1)) (reverse acc)]
      [(and (char=? (string-ref text i) #\[) (char=? (string-ref text (+ i 1)) #\[))
       (define content-start (+ i 2))
       (define close (find-close text content-start))
       (if close
           (scan (+ close 2) (cons (list i content-start close) acc))
           (scan (+ i 2) acc))]
      [else (scan (+ i 1) acc)]))
  (scan 0 '()))

;; Finds the [[...]] span that contains `pos` within `text`. Returns the
;; captured text (string) or #f.
(define (find-link-at text pos)
  (define (search spans)
    (cond
      [(null? spans) #f]
      [(let ([span (car spans)]) (and (<= (car span) pos) (<= pos (+ (caddr span) 1))))
       (substring text (cadr (car spans)) (caddr (car spans)))]
      [else (search (cdr spans))]))
  (search (scan-links text)))

(define (link-name->relative-path name)
  (if (ends-with? name ".md") name (string-append name ".md")))

;; Resolves a [[link]] name to an absolute file path, as if it were written
;; inside a note living in `base-dir`. A name starting with "/" is anchored
;; to the wiki root (VimWiki's root-relative link syntax); any other name is
;; resolved relative to `base-dir`, matching VimWiki's default link
;; resolution, so [[foo]] written in <root>/projects/bar.md opens
;; <root>/projects/foo.md rather than <root>/foo.md.
(define (link-name->path-from base-dir name)
  (define rel (link-name->relative-path name))
  (if (starts-with? rel "/")
      (string-append *wiki-root* rel)
      (string-append base-dir "/" rel)))

;; --- path arithmetic (for rename-with-link-update) ---

;; Replaces backslashes with forward slashes, so paths built by this plugin
;; (always "/"-separated) can be compared/split alongside paths handed back
;; by the editor (OS-native separators, i.e. "\\" on Windows).
(define (normalize-path p)
  (define len (string-length p))
  (define (loop i acc)
    (if (>= i len)
        acc
        (loop (+ i 1)
              (string-append acc (if (char=? (string-ref p i) #\\) "/" (substring p i (+ i 1)))))))
  (loop 0 ""))

(define (strip-md-extension name)
  (if (ends-with? name ".md")
      (substring name 0 (- (string-length name) 3))
      name))

;; Splits an absolute path into its non-empty "/"-separated segments.
(define (path-segments p)
  (filter (lambda (s) (not (string=? s ""))) (split-many (normalize-path p) "/")))

;; Collapses "." and ".." segments out of a segment list, as a filesystem
;; would when resolving them -- but purely lexically, so it works even for
;; paths that don't (yet) point at a real file, e.g. a [[../not-created-yet]]
;; link.
(define (collapse-segments segs)
  (define (go segs stack)
    (cond
      [(null? segs) (reverse stack)]
      [(string=? (car segs) ".") (go (cdr segs) stack)]
      [(and (string=? (car segs) "..") (not (null? stack))) (go (cdr segs) (cdr stack))]
      [(string=? (car segs) "..") (go (cdr segs) stack)]
      [else (go (cdr segs) (cons (car segs) stack))]))
  (go segs '()))

;; Compares two paths for equality, tolerant of "/" vs "\\", of "." / ".."
;; segments, and of case (Windows filesystems are case-insensitive).
(define (paths-equal? a b)
  (define (canonical p) (map string-downcase (collapse-segments (path-segments p))))
  (equal? (canonical a) (canonical b)))

;; `path` (assumed to live under *wiki-root*), relative to *wiki-root*,
;; without a leading "/" or a ".md" extension, e.g.
;; "<root>/projects/foo.md" -> "projects/foo".
(define (path->root-relative path)
  (define root-segs (path-segments *wiki-root*))
  (strip-md-extension (string-join (list-tail (path-segments path) (length root-segs)) "/")))

(define (common-prefix-len a b)
  (cond
    [(null? a) 0]
    [(null? b) 0]
    [(string=? (string-downcase (car a)) (string-downcase (car b)))
     (+ 1 (common-prefix-len (cdr a) (cdr b)))]
    [else 0]))

(define (repeat-string s n)
  (if (<= n 0) '() (cons s (repeat-string s (- n 1)))))

;; Computes a relative link name (no ".md") from `from-dir` to `to-path`,
;; walking up with ".." when `to-path` isn't nested under `from-dir` --
;; mirrors how [[links]] are resolved relative to the referencing note's
;; directory.
(define (relative-link-name from-dir to-path)
  (define from-segs (path-segments from-dir))
  (define to-segs (path-segments to-path))
  (define common (common-prefix-len from-segs to-segs))
  (define ups (repeat-string ".." (- (length from-segs) common)))
  (define downs (list-tail to-segs common))
  (strip-md-extension (string-join (append ups downs) "/")))

;; --- filesystem I/O helpers (for rename-with-link-update) ---

(define (read-file-to-string path)
  (call-with-input-file path read-port-to-string))

(define (write-string-to-file! path contents)
  (call-with-output-file path (lambda (port) (write-string contents port)) #:exists 'truncate))

;; Recursively collects every ".md" file under `dir`, skipping directories
;; whose name starts with "." (e.g. ".git").
(define (list-md-files dir)
  (apply append
         (map (lambda (p)
                (cond
                  [(and (is-dir? p) (not (starts-with? (file-name p) ".")))
                   (list-md-files p)]
                  [(ends-with? p ".md") (list p)]
                  [else '()]))
              (read-dir dir))))

;; Produces the replacement link name for a link whose captured text was
;; `name`, now that its target has moved to `new-abs`. Preserves the link's
;; anchoring style ("/"-rooted vs relative to `base-dir`) and whether ".md"
;; was spelled out explicitly.
(define (rewrite-link-name name new-abs base-dir)
  (define anchored (starts-with? name "/"))
  (define explicit-md (ends-with? name ".md"))
  (define base-name
    (if anchored
        (string-append "/" (path->root-relative new-abs))
        (relative-link-name base-dir new-abs)))
  (if explicit-md (string-append base-name ".md") base-name))

;; Rewrites `text` (the content of the note at `file-path`) so that every
;; [[link]] resolving (relative to `file-path`'s directory) to `old-abs`
;; instead resolves to `new-abs`. Returns the rewritten text, or #f if
;; nothing needed to change.
(define (rewrite-links-in-text text file-path old-abs new-abs)
  (define base-dir (or (path-parent file-path) *wiki-root*))
  (define (build spans cursor acc changed)
    (if (null? spans)
        (if changed (string-append acc (substring text cursor (string-length text))) #f)
        (let* ([span (car spans)]
               [content-start (cadr span)]
               [content-end (caddr span)]
               [name (substring text content-start content-end)])
          (if (paths-equal? (link-name->path-from base-dir name) old-abs)
              (let ([prefix (substring text cursor content-start)]
                    [new-name (rewrite-link-name name new-abs base-dir)])
                (build (cdr spans) content-end (string-append acc prefix new-name) #t))
              (build (cdr spans) cursor acc changed)))))
  (build (scan-links text) 0 "" #f))

;; Rewrites every [[link]] across all .md files under *wiki-root* that
;; resolves to `old-abs` so it resolves to `new-abs` instead. Returns the
;; number of files that were changed.
(define (update-links-in-vault! old-abs new-abs)
  (define (process files count)
    (if (null? files)
        count
        (let* ([file (car files)]
               [text (read-file-to-string file)]
               [rewritten (rewrite-links-in-text text file old-abs new-abs)])
          (when rewritten (write-string-to-file! file rewritten))
          (process (cdr files) (if rewritten (+ count 1) count)))))
  (process (list-md-files *wiki-root*) 0))
