;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; cog.scm - Forge package manifest for hxwiki
;;;
;;; Installable with Steel's package manager:
;;;
;;;   forge pkg install --git https://github.com/sipmann/hxwiki
;;;
;;; then, in ~/.config/helix/init.scm:
;;;
;;;   (require "hxwiki/hxwiki.scm")

(define package-name 'hxwiki)
(define version "0.1.0")

;; Pure Scheme, no external dependencies or native dylibs.
(define dependencies '())
