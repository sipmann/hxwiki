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
