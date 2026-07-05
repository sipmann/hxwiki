;;; cog.scm - Forge package manifest for hxwiki
;;;
;;; Installable with Steel's package manager:
;;;
;;;   forge pkg install --git https://github.com/<your-username>/hxwiki
;;;
;;; then, in ~/.config/helix/init.scm:
;;;
;;;   (require "hxwiki/hxwiki.scm")

(define package-name 'hxwiki)
(define version "0.1.0")

;; Pure Scheme, no external dependencies or native dylibs.
(define dependencies '())
