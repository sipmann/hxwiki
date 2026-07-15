;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; test-rename.scm - update-links-in-vault! / rewrite-links-in-text, end to end
;;;
;;; Run from the repo root: steel < tests/test-rename.scm
;;;
;;; Exercises the vault-wide link rewrite against a real, throwaway vault on
;;; disk (tests/tmp-vault/, gitignored) rather than mocking the filesystem,
;;; since the behavior under test *is* the filesystem walk + read/write.

(require "tests/harness.scm")
(require "hxwiki-core.scm")

(define vault "tests/tmp-vault")
(set-hxwiki-root! vault)

(define (reset-vault!)
  (when (path-exists? vault)
    (delete-directory! vault))
  (create-directory! (string-append vault "/projects"))
  (create-directory! (string-append vault "/projects/sub")))

;;;; Scenario 1: rename within the same directory, exercising every link
;;;; style (relative, root-anchored, explicit .md, "../", self-link) ;;;;

(reset-vault!)

;; index.md links to the note both relatively and root-anchored, plus an
;; explicit-.md variant and an unrelated link that must survive untouched.
(write-string-to-file!
 (string-append vault "/index.md")
 "See [[projects/foo]] and [[/projects/foo]] and [[projects/foo.md]] and [[unrelated]].\n")

;; projects/bar.md links to it by bare name (same directory).
(write-string-to-file! (string-append vault "/projects/bar.md") "Back to [[foo]], not [[unrelated]].\n")

;; projects/sub/deep.md links up a directory with "../".
(write-string-to-file! (string-append vault "/projects/sub/deep.md") "Up to [[../foo]] we go.\n")

;; The note being renamed, with a self-link.
(write-string-to-file! (string-append vault "/projects/foo.md") "# Foo\nSelf link: [[foo]]\n")

(define old-abs (string-append vault "/projects/foo.md"))
(define new-abs (string-append vault "/projects/renamed.md"))

(define updated (update-links-in-vault! old-abs new-abs))

(check-equal! "update-links-in-vault! reports every changed file" updated 4)

(check-equal! "relative + root-anchored + explicit-.md links all rewritten, unrelated link untouched"
              (read-file-to-string (string-append vault "/index.md"))
              "See [[projects/renamed]] and [[/projects/renamed]] and [[projects/renamed.md]] and [[unrelated]].\n")

(check-equal! "same-directory relative link rewritten, unrelated link untouched"
              (read-file-to-string (string-append vault "/projects/bar.md"))
              "Back to [[renamed]], not [[unrelated]].\n")

(check-equal! "\"../\"-style link from a subdirectory rewritten"
              (read-file-to-string (string-append vault "/projects/sub/deep.md"))
              "Up to [[../renamed]] we go.\n")

(check-equal! "self-link rewritten (rewrite happens before the physical move)"
              (read-file-to-string old-abs)
              "# Foo\nSelf link: [[renamed]]\n")

;; Now actually move the file, as hxwiki-rename does after updating links.
(rename-file-or-directory! old-abs new-abs)
(check-true! "renamed file exists at its new path" (path-exists? new-abs))
(check-false! "old path is gone after the move" (path-exists? old-abs))

;;;; Scenario 2: rename that also moves the note into a different
;;;; directory -- relative-link-name must walk back up with ".." ;;;;

(reset-vault!)
(create-directory! (string-append vault "/archive"))
(write-string-to-file!
 (string-append vault "/projects/foo.md")
 "# Foo\nSee also [[foo]] (self) and [[bar]] (sibling, untouched).\n")
(write-string-to-file! (string-append vault "/projects/bar.md") "# Bar\n")

(define old-abs-2 (string-append vault "/projects/foo.md"))
(define new-abs-2 (string-append vault "/archive/renamed-foo.md"))
(update-links-in-vault! old-abs-2 new-abs-2)

(check-equal! "self-link survives a rename into a different directory"
              (read-file-to-string old-abs-2)
              "# Foo\nSee also [[../archive/renamed-foo]] (self) and [[bar]] (sibling, untouched).\n")

(when (path-exists? vault)
  (delete-directory! vault))

(summarize! "rename")
