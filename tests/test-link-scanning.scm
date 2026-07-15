;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; test-link-scanning.scm - scan-links / find-link-at / link-name->*
;;;
;;; Run from the repo root: steel < tests/test-link-scanning.scm

(require "tests/harness.scm")
(require "hxwiki-core.scm")

;;;; scan-links ;;;;

(check-equal! "scan-links finds a single span" (scan-links "hello [[foo]] world") (list (list 6 8 11)))

(check-equal! "scan-links finds multiple spans in order"
              (map cadr (scan-links "[[a]] and [[bcd]]"))
              (list 2 12))

(check-equal! "scan-links returns empty list when there are no links" (scan-links "no links here") (list))

(check-equal! "scan-links ignores an unclosed [[ opener" (scan-links "before [[unterminated") (list))

;;;; find-link-at ;;;;

(check-equal! "find-link-at returns the captured name when cursor is inside the brackets"
              (find-link-at "see [[foo/bar]] here" 8)
              "foo/bar")

(check-equal! "find-link-at matches with cursor on the opening bracket" (find-link-at "[[foo]]" 0) "foo")

(check-false! "find-link-at returns #f when cursor is outside any link" (find-link-at "see [[foo]] here" 1))

(check-false! "find-link-at returns #f when there is no link in the text" (find-link-at "just plain text" 3))

;;;; link-name->relative-path ;;;;

(check-equal! "link-name->relative-path appends .md when missing"
              (link-name->relative-path "foo/bar")
              "foo/bar.md")

(check-equal! "link-name->relative-path leaves an explicit .md alone" (link-name->relative-path "foo.md") "foo.md")

;;;; link-name->path-from ;;;;

(check-equal! "link-name->path-from resolves relative to base-dir"
              (link-name->path-from "/vault/projects" "foo")
              "/vault/projects/foo.md")

(check-equal! "link-name->path-from resolves a subdirectory relative to base-dir"
              (link-name->path-from "/vault/projects" "sub/foo")
              "/vault/projects/sub/foo.md")

(set-hxwiki-root! "/vault")
(check-equal! "link-name->path-from anchors a \"/\"-prefixed name to the wiki root"
              (link-name->path-from "/vault/projects" "/index")
              "/vault/index.md")

(summarize! "link-scanning")
