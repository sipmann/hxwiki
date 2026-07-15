;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; test-path-arithmetic.scm - paths-equal? / path->root-relative / relative-link-name
;;;
;;; Run from the repo root: steel < tests/test-path-arithmetic.scm

(require "tests/harness.scm")
(require "hxwiki-core.scm")

;;;; paths-equal? ;;;;

(check-true! "paths-equal? on identical paths" (paths-equal? "/vault/projects/foo.md" "/vault/projects/foo.md"))

(check-true! "paths-equal? tolerates \\ vs / separators"
             (paths-equal? "/vault/projects\\foo.md" "/vault/projects/foo.md"))

(check-true! "paths-equal? is case-insensitive (Windows filesystems are)"
             (paths-equal? "/vault/Projects/Foo.md" "/vault/projects/foo.md"))

(check-true! "paths-equal? lexically collapses \"..\" segments"
             (paths-equal? "/vault/projects/sub/../foo.md" "/vault/projects/foo.md"))

(check-true! "paths-equal? collapses \"..\" that walks above the common prefix"
             (paths-equal? "/vault/a/../../foo.md" "/foo.md"))

(check-false! "paths-equal? on genuinely different paths"
              (paths-equal? "/vault/projects/foo.md" "/vault/projects/bar.md"))

;;;; path->root-relative ;;;;

(set-hxwiki-root! "/vault")

(check-equal! "path->root-relative strips the root and .md, keeps subdirectories"
              (path->root-relative "/vault/projects/foo.md")
              "projects/foo")

(check-equal! "path->root-relative on a top-level note" (path->root-relative "/vault/index.md") "index")

;;;; relative-link-name ;;;;

(check-equal! "relative-link-name in the same directory" (relative-link-name "/vault/projects" "/vault/projects/foo.md") "foo")

(check-equal! "relative-link-name across sibling directories"
              (relative-link-name "/vault/projects" "/vault/other/foo.md")
              "../other/foo")

(check-equal! "relative-link-name walking up from a subdirectory"
              (relative-link-name "/vault/projects/sub" "/vault/projects/foo.md")
              "../foo")

(summarize! "path-arithmetic")
