;; Copyright (C) 2026 Tom Waddington
;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; harness.scm - Minimal assertion harness for headless Steel tests
;;;
;;; Adapted from nrepl.hx's tests/harness.scm
;;; (https://github.com/waddie/nrepl.hx/blob/main/tests/harness.scm),
;;; licensed AGPL-3.0-or-later.
;;;
;;; Run a suite from the repo root: steel < tests/test-*.scm
;;; (Piping via stdin resolves `require` paths relative to the current
;;; working directory rather than to this file, so every require in a test
;;; file -- including this one -- is repo-root-relative, e.g.
;;; (require "tests/harness.scm") and (require "hxwiki-core.scm").)
;;;
;;; The bare `steel` CLI exits 0 even when a piped script raises an
;;; uncaught error, so tests/run-all.sh can't rely on the exit code -- it
;;; greps for the SUITE-PASS/SUITE-FAIL line `summarize!` prints. A suite
;;; that crashes before reaching its `summarize!` call never prints either
;;; one, which run-all.sh also treats as a failure.

(provide check-equal!
         check-true!
         check-false!
         summarize!)

(define *checks* (box 0))
(define *failures* (box 0))

(define (record-check! ok? label actual expected)
  (set-box! *checks* (+ 1 (unbox *checks*)))
  (if ok?
      #t
      (begin
        (set-box! *failures* (+ 1 (unbox *failures*)))
        (displayln (string-append "FAIL: " label))
        (displayln (string-append "  expected: " (to-string expected)))
        (displayln (string-append "  actual:   " (to-string actual)))
        #f)))

;;@doc
;; Asserts `actual` equals `expected`; on mismatch prints a FAIL line with both.
(define (check-equal! label actual expected)
  (record-check! (equal? actual expected) label actual expected))

;;@doc
;; Asserts `actual` is truthy.
(define (check-true! label actual)
  (record-check! (if actual #t #f) label actual #t))

;;@doc
;; Asserts `actual` is #f.
(define (check-false! label actual)
  (record-check! (not actual) label actual #f))

;;@doc
;; Prints the suite verdict; see the file header for why run-all.sh greps
;; for this instead of checking the process exit code. A suite that recorded
;; zero checks counts as a failure too -- otherwise an error early in the
;; file (e.g. a broken `require`) that stops every check from ever running
;; would still print SUITE-PASS, since 0 failures out of 0 checks is
;; vacuously "clean".
(define (summarize! name)
  (define f (unbox *failures*))
  (define c (unbox *checks*))
  (cond
    [(= c 0) (displayln (string-append "SUITE-FAIL " name ": 0 checks ran (see errors above)"))]
    [(= f 0) (displayln (string-append "SUITE-PASS " name " (" (to-string c) " checks)"))]
    [else
     (displayln (string-append "SUITE-FAIL "
                                name
                                ": "
                                (to-string f)
                                " of "
                                (to-string c)
                                " checks failed"))]))
