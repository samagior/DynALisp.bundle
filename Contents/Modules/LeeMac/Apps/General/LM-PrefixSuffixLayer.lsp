;;  Prefix/Suffix Layer
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

;;----------------------=={ Prefix/Suffix Layer  }==--------------------;;
;;                                                                      ;;
;;  This program allows the user to apply or remove a prefix and/or     ;;
;;  suffix to all layers found in a selection of objects.               ;;
;;                                                                      ;;
;;  The command 'pslay' prompts the user to specify a prefix and/or     ;;
;;  suffix and a selection of objects residing on layers whose layer    ;;
;;  names are to be modified. Following a valid response, the program   ;;
;;  renamed the layers accordingly, notifying the user of any layers    ;;
;;  which could not be renamed.                                         ;;
;;                                                                      ;;
;;  Similarly, the command 'rpslay' enables the user to remove a layer  ;;
;;  prefix and/or suffix from the layer names of all layers found in a  ;;
;;  selection of objects.                                               ;;
;;----------------------------------------------------------------------;;
;;  Author:  Lee Mac, Copyright � 2016  -  www.lee-mac.com              ;;
;;----------------------------------------------------------------------;;
;;  Version 1.0    -    2016-11-08                                      ;;
;;                                                                      ;;
;;  - First release.                                                    ;;
;;----------------------------------------------------------------------;;
;;  Version 1.1    -    2017-01-15                                      ;;
;;                                                                      ;;
;;  - Fixed bug causing the prefix/suffix to be applied a number of     ;;
;;    times equal to the number of objects in the selection.            ;;
;;                                                                      ;;
;;  - Removed the restriction preventing layers which start/end with    ;;
;;    the same character as the prefix/suffix from being selected.      ;;
;;                                                                      ;;
;;  - Added more verbose output to indicate which layers have been      ;;
;;    renamed and the result of the rename.                             ;;
;;----------------------------------------------------------------------;;

;; Prefix Suffix Layer
;; Adds a prefix and or suffix to the layer names of the selected objects.

(defun c:LM-PrefixSuffixLayer ( / idx lay lst pre sel suf )
    (setq pre (pslay:getstring "\nSpecify layer prefix <none>: ")
          suf (pslay:getstring "\nSpecify layer suffix <none>: ")
    )
    (if (and (not (= "" pre suf)) (setq sel (ssget)))
        (repeat (setq idx (sslength sel))
            (or (member (setq lay (cdr (assoc 8 (entget (ssname sel (setq idx (1- idx))))))) lst)
                (setq lst (cons (pslay:renamelayer lay (strcat pre lay suf)) lst))
            )
        )
    )
    (princ)
)

;; Remove Prefix Suffix Layer
;; Removes a prefix and or suffix from the layer names of the selected objects.

(defun c:Pst-RemovePrefixSuffixLayer ( / idx lay lst pre sel suf )
    (setq pre (pslay:getstring "\nSpecify layer prefix to remove <none>: ")
          suf (pslay:getstring "\nSpecify layer suffix to remove <none>: ")
    )
    (if (and (not (= "" pre suf)) (setq sel (ssget (list (cons 8 (strcat pre "*" suf))))))
        (repeat (setq idx (sslength sel))
            (or (member (setq lay (cdr (assoc 8 (entget (ssname sel (setq idx (1- idx))))))) lst)
                (setq lst (cons (pslay:renamelayer lay (substr lay (1+ (strlen pre)) (- (strlen lay) (strlen pre) (strlen suf)))) lst))
            )
        )
    )
    (princ)
)
(defun pslay:renamelayer ( old new / lay )
    (cond
        (   (tblsearch "layer" new)
            (prompt (strcat "\n" new " already exists, cannot rename " old "."))
        )
        (   (wcmatch (strcase old t) "0,defpoints,*|*")
            (prompt (strcat "\nCannot rename " old "."))
        )
        (   (and (setq lay (tblobjname "layer" old))
                 (setq lay (entget lay))
                 (entmod (subst (cons 2 new) (assoc 2 lay) lay))
            )
            (prompt (strcat "\nLayer " old " renamed to " new "."))
            new
        )
    )
)
(defun pslay:getstring ( msg / rtn )
    (while (and (/= "" (setq rtn (getstring t msg))) (wcmatch rtn "*[\\<>/?\":;*|`,=`]*"))
        (princ (strcat "\nLayer name cannot contain the characters \\<>/?\":;*|,=`"))
    )
    rtn
)
;;; (princ
;;;     (strcat
;;;         "\n:: PrefixSuffixLayer.lsp | Version 1.1 | \\U+00A9 Lee Mac "
;;;         (menucmd "m=$(edtime,0,yyyy)")
;;;         " www.lee-mac.com ::"
;;;         "\n:: \"pslay\" to Apply | \"rpslay\" to Remove ::"
;;;     )
;;; )
;;; (princ)

;;----------------------------------------------------------------------;;
;;                             End of File                              ;;
;;----------------------------------------------------------------------;;