;;  Print List
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

;; Print List  -  Lee Mac
;; Prints a supplied list to the command-line or to a given filename,
;; with nested lists displayed in a hierarchical format.
;; l - [lst] List to print
;; f - [str] Optional filename

(defun LM:princl ( l f / _print _princ d r )
    
    (defun _print ( l i )
        (if (and (= 'list (type l)) (vl-list-length l) (vl-some 'vl-consp l))
            (progn
                (_princ (strcat "\n" i "("))
                (foreach x l (_print x (strcat i "    ")))
                (_princ (strcat "\n" i ")"))
            )
            (_princ (strcat "\n" i (vl-prin1-to-string l)))
        )
    )

    (eval
        (list 'defun '_princ '( x )
            (if (and (= 'str (type f)) (setq d (open f "w")))
                (list 'princ 'x d)
               '(princ x)
            )
        )
    )

    (setq r (vl-catch-all-apply '_print (list l "")))
    (if (= 'file (type d))
        (progn
            (setq d (close d))
            (startapp "notepad" f)
        )
    )
    (if (vl-catch-all-error-p r)
        (prompt (vl-catch-all-error-message r))
        l
    )
)

(defun princl ( l ) (LM:princl l nil) (princ))
(defun princf ( l ) (LM:princl l (vl-filename-mktemp "list" (getvar 'dwgprefix) ".txt")) (princ))
(princ)