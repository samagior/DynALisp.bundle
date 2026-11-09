;;  Renumber Layouts
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

;;------------------------=={ Renumber Layouts }==----------------------;;
;;                                                                      ;;
;;  This program enables the user to automatically sequentially         ;;
;;  renumber all Paperspace layouts, with an optional prefix and/or     ;;
;;  suffix.                                                             ;;
;;                                                                      ;;
;;  The layouts are renumbered in the order in which they appear in     ;;
;;  the active drawing, with a configurable parameter defining the      ;;
;;  number of digits constituting the numerical portion of the layout   ;;
;;  name.                                                               ;;
;;                                                                      ;;
;;  The user may optionally predefine a fixed prefix and/or suffix      ;;
;;  within the 'Program Parameters' section of the source code below,   ;;
;;  or, if such parameters are set to nil, the program will prompt the  ;;
;;  user to specify the prefix and suffix upon invoking the command.    ;;
;;----------------------------------------------------------------------;;
;;  Author:  Lee Mac, Copyright � 2020  -  www.lee-mac.com              ;;
;;----------------------------------------------------------------------;;
;;  Version 1.0    -    2020-01-26                                      ;;
;;                                                                      ;;
;;  - First release.                                                    ;;
;;----------------------------------------------------------------------;;
;;  Version 1.1    -    2020-09-05                                      ;;
;;                                                                      ;;
;;  - Added option to specify layout starting number.                   ;;
;;----------------------------------------------------------------------;;

;; Renumber Layouts
;; Renumbers every layout in order with an optional prefix and suffix.

(defun c:LM-RenumberLayouts ( / *error* int lst lyn ord pad pre sed suf tmp )

    (defun *error* ( msg )
        (LM:endundo (LM:acdoc))
        (if (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*"))
            (princ (strcat "\nError: " msg))
        )
        (princ)
    )

    (setq

;;----------------------------------------------------------------------;;
;;                          Program Parameters                          ;;
;;----------------------------------------------------------------------;;

        ;; Optional Predefined Layout Prefix
        ;; Set to nil to prompt the user, or "" for no prefix.
        pre nil

        ;; Optional Predefined Layout Suffix
        ;; Set to nil to prompt the user, or "" for no suffix.
        suf nil

        ;; Optional Predefined Starting Number
        ;; Set to nil to prompt the user
        int nil

        ;; Number of Numerical Digits
        ;; e.g. 1 = "1", 2 = "01", 3 = "001"
        pad 2

;;----------------------------------------------------------------------;;

    )

    ;; Obtain a valid (optional) prefix & suffix
    (or (= 'str (type pre)) (setq pre (LM:rl:validstring "\nSpecify prefix <none>: ")))
    (or (= 'str (type suf)) (setq suf (LM:rl:validstring "\nSpecify suffix <none>: ")))
    (or (= 'int (type int)) (setq int (cond ((getint "\nSpecify starting number <1>: ")) (1))))
    (or (and (= 'int (type pad)) (<= 0 pad)) (setq pad 0))
    
    ;; Obtain list of layout objects, current names, and sort index
    (vlax-for lyt (vla-get-layouts (LM:acdoc))
        (if (= :vlax-false (vla-get-modeltype lyt))
            (setq lst (cons lyt lst)
                  lyn (cons (strcase (vla-get-name lyt)) lyn)
                  ord (cons (vla-get-taborder lyt) ord)
            )
        )
    )

    ;; Construct a unique seed for temporary renaming
    (setq lyn (cons (strcase pre) lyn)
          sed "%"
    )
    (while (vl-some '(lambda ( x ) (wcmatch x (strcat "*" sed "*"))) lyn)
        (setq sed (strcat sed "%"))
    )

    ;; Temporarily rename layouts to ensure no duplicate keys when renumbering
    (LM:startundo (LM:acdoc))
    (setq tmp 0)
    (foreach lyt lst
        (vla-put-name lyt (strcat sed (itoa (setq tmp (1+ tmp)))))
    )

    ;; Rename layouts in tab order, with prefix & suffix
    (foreach idx (vl-sort-i ord '<)
        (vla-put-name
            (nth idx lst)
            (strcat pre (LM:rl:padzeros (itoa int) pad) suf)
        )
        (setq int (1+ int))
    )
    
    (LM:endundo (LM:acdoc))
    (princ)
)

;;----------------------------------------------------------------------;;

(defun LM:rl:validstring ( msg / rtn )
    (while
        (not
            (or
                (= "" (setq rtn (getstring t msg)))
                (snvalid (vl-string-trim " " rtn))
            )
        )
        (princ (strcat "\nThe layout name cannot contain the characters \\<>/?\":;*|,=`"))
    )
    rtn
)

;;----------------------------------------------------------------------;;

(defun LM:rl:padzeros ( str len )
    (if (< (strlen str) len) (LM:rl:padzeros (strcat "0" str) len) str)
)

;;----------------------------------------------------------------------;;

;; Start Undo  -  Lee Mac
;; Opens an Undo Group.

(defun LM:startundo ( doc )
    (LM:endundo doc)
    (vla-startundomark doc)
)

;;----------------------------------------------------------------------;;

;; End Undo  -  Lee Mac
;; Closes an Undo Group.

(defun LM:endundo ( doc )
    (while (= 8 (logand 8 (getvar 'undoctl)))
        (vla-endundomark doc)
    )
)

;;----------------------------------------------------------------------;;

;; Active Document  -  Lee Mac
;; Returns the VLA Active Document Object

(defun LM:acdoc nil
    (eval (list 'defun 'LM:acdoc 'nil (vla-get-activedocument (vlax-get-acad-object))))
    (LM:acdoc)
)

;;----------------------------------------------------------------------;;

;;; (vl-load-com)
;;; (princ
;;;     (strcat
;;;         "\n:: RenumberLayouts.lsp | Version 1.1 | \\U+00A9 Lee Mac "
;;;         ((lambda ( y ) (if (= y (menucmd "m=$(edtime,0,yyyy)")) y (strcat y "-" (menucmd "m=$(edtime,0,yyyy)")))) "2020")
;;;         " www.lee-mac.com ::"
;;;         "\n:: Type \"RL\" to Invoke ::"
;;;     )
;;; )
;;; (princ)

;;----------------------------------------------------------------------;;
;;                             End of File                              ;;
;;----------------------------------------------------------------------;;