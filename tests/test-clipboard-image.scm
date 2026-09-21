;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; test-clipboard-image.scm - assets-dir-for / unique-path
;;;
;;; Only the pure path-arithmetic parts of :hxwiki-paste-image are covered
;;; here -- paste-clipboard-image! itself shells out to the OS clipboard and
;;; isn't exercised by this headless suite.
;;;
;;; Run from the repo root: steel < tests/test-clipboard-image.scm

(require "tests/harness.scm")
(require "hxwiki-core.scm")

;;;; assets-dir-for ;;;;

(check-equal! "assets-dir-for defaults to an \"assets\" folder next to the note"
              (assets-dir-for "/vault/projects/foo.md")
              "/vault/projects/assets")

(check-equal! "assets-dir-for is configurable"
              (begin
                (set-hxwiki-assets-dir-name! "images")
                (assets-dir-for "/vault/projects/foo.md"))
              "/vault/projects/images")

(set-hxwiki-assets-dir-name! "assets")

;;;; unique-path ;;;;

(check-equal! "unique-path leaves a non-existent path unchanged"
              (unique-path "/does/not/exist/paste-20260101-000000.png")
              "/does/not/exist/paste-20260101-000000.png")

;; Real, throwaway files on disk (tests/tmp-vault/, gitignored) -- the
;; behavior under test *is* path-exists? collision detection.
(define scratch "tests/tmp-vault")
(when (path-exists? scratch)
  (delete-directory! scratch))
(create-directory! scratch)

(define base (string-append scratch "/paste-20260101-000000.png"))
(write-string-to-file! base "fake png bytes")

(check-equal! "unique-path skips a taken name, tries -2 next"
              (unique-path base)
              (string-append scratch "/paste-20260101-000000-2.png"))

(write-string-to-file! (string-append scratch "/paste-20260101-000000-2.png") "fake png bytes")

(check-equal! "unique-path keeps counting past -2 if that's taken too"
              (unique-path base)
              (string-append scratch "/paste-20260101-000000-3.png"))

(delete-directory! scratch)

(summarize! "clipboard-image")
