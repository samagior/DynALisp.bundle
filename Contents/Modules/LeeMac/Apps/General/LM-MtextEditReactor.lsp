;;  MText Edit Reactor
;;  Copyright (C) 2026  Samuel Martineau
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU General Public License as published by
;;  the Free Software Foundation, either version 3 of the License, or
;;  (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU General Public License for more details.
;;
;;  You should have received a copy of the GNU General Public License
;;  along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;  Author licence applies on top of the above GPL licence, See
;;  the "Licences" folder or Author domain for more details.
;;
;;----------------------------------------------------------------------;;
;;
;;  Author:  Lee Mac  -  www.lee-mac.com
;;
;;----------------------------------------------------------------------;;

(   (lambda nil (vl-load-com)

        ;; Mtext Edit Reactor On
        ;; Enables a reactor that selects all the text when an Mtext or multileader is edited.

        (defun c:Pst-MtextEditReactorOn nil
            (mtedit-reactor-remove)
            (vlr-set-notification
                (vlr-command-reactor "mtedit-reactor"
                   '((:vlr-commandwillstart . mtedit-reactor-callback))
                )
                'active-document-only
            )
            (vlr-set-notification
                (vlr-editor-reactor "mtedit-reactor"
                   '((:vlr-beginclose . mtedit-reactor-clean))
                )
                'active-document-only
            )
            (princ "\nMTEdit Reactor enabled.")
            (princ)
        )

        ;; Mtext Edit Reactor Off
        ;; Disables the Mtext edit reactor.

        (defun c:Pst-MtextEditReactorOff nil
            (mtedit-reactor-remove)
            (mtedit-reactor-clean nil nil)
            (princ "\nMTEdit Reactor disabled.")
            (princ)
        )
        (defun mtedit-reactor-callback ( a b )
            (if (wcmatch (strcase (car b) t) "mtedit,mleadercontentedit")
                (if (or mtedit-reactor-wsh (setq mtedit-reactor-wsh (vlax-create-object "wscript.shell")))
                    (vl-catch-all-apply 'vlax-invoke (list mtedit-reactor-wsh 'sendkeys "^{HOME}(^+{END})"))
                )
            )
            (princ)
        )
        (defun mtedit-reactor-clean ( a b )
            (if (= 'vla-object (type mtedit-reactor-wsh))
                (vl-catch-all-apply 'vlax-release-object (list mtedit-reactor-wsh))
            )
            (setq mtedit-reactor-wsh nil)
            (princ)
        )
        (defun mtedit-reactor-remove nil
            (foreach grp (vlr-reactors :vlr-command-reactor :vlr-editor-reactor)
                (foreach obj (cdr grp)
                    (if (= "mtedit-reactor" (vlr-data obj))
                        (vlr-remove obj)
                    )
                )
            )
        )
        (c:Pst-MtextEditReactorOn)
        (princ)
    )
)

;;-------------------------=={ DynALisp }==------------------------;;

;;  The commands above are child commands (Pst-*) of LM-MtextEditReactor, run by their
;;  aliases or picked in its dialog (Dyl:ChildPicker, dynalisp.mnl).

;; Mtext Edit Reactor
;; Lists the Mtext Edit Reactor commands with their aliases and runs the one picked.

(defun c:LM-MtextEditReactor ()
  (Dyl:ChildPicker "LM-MtextEditReactor.lsp" "Mtext Edit Reactor" "Double-click On or Off (or OK)." '*lm-mtexteditreactor:last*)
)
(princ)
