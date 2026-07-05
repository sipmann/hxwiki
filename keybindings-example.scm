;; Copyright (C) 2026 Sipmann
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU Affero General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;;; keybindings-example.scm - example wiring for hxwiki
;;;
;;; Copy the relevant parts into your own ~/.config/helix/init.scm and adjust
;;; to taste. Assumes cogs/keymaps.scm is already present in your Helix config
;;; (see https://github.com/mattwparas/helix-config for that helper).

(require "cogs/keymaps.scm")
(require "hxwiki/hxwiki.scm")

;; Point this at your own vault. Defaults to "~/hxwiki" if you don't call this.
(set-hxwiki-root! "~/hxwiki")

;; space w w -> open the wiki index
;; space w d -> open/create today's diary entry
(keymap (global)
  (normal (space (w (w ":hxwiki-index") (d ":hxwiki-diary-today")))))

;; Enter (normal mode), only in .md files, follows/creates the [[link]] under the cursor
(define md-keybindings (deep-copy-global-keybindings))
(merge-keybindings md-keybindings (keymap (normal (ret ":hxwiki-follow-or-create"))))
(set-global-buffer-or-extension-keymap (hash "md" md-keybindings))
