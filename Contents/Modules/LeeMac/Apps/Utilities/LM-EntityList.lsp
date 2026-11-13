;;  Entity List
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

;;---------------------=={ Entity List }==--------------------;;
;;                                                            ;;
;;  Displays the DXF Information for an entity, a variation   ;;
;;  of the program by Michael Puckett of the same name.       ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac - www.lee-mac.com                         ;;
;;------------------------------------------------------------;;
;;  Arguments: entity - entity (ename) / DXF list             ;;
;;------------------------------------------------------------;;

(defun elist ( entity / prin1x princx data xdata )

    (defun prin1x ( x i ) (repeat i (princ "  ")) (prin1 x))
    (defun princx ( x i ) (repeat i (princ "  ")) (princ x))

    (cond
        (   (or
                (and
                    (eq 'ENAME (type entity))
                    (setq data (entget entity))
                )
                (and
                    (listp entity)
                    (setq data entity)
                    (setq entity (cdr (assoc -1 data)))
                )
            )
            (princ "\n\n  (\n")
            (foreach pair data
                (prin1x pair 2)
                (princ "\n")
            )
            (if (setq xdata (assoc -3 (entget entity '("*"))))
                (progn
                    (princx "(" 2)
                    (prin1 (car xdata))
                    (princ "\n")
                    (foreach app (cdr xdata)
                        (princx "(" 3)
                        (princ "\n")
                        (foreach pair app (prin1x pair 4) (princ "\n"))
                        (princx ")" 3)
                        (princ "\n")
                    )
                    (princx ")" 2)
                    (princ "\n")
                )
            )
            (princ "  )")
            (if (= 1 (cdr (assoc 66 data)))
                (while
                    (progn
                        (elist (setq entity (entnext entity)))
                        (not (eq "SEQEND" (cdr (assoc 0 (entget entity)))))
                    )
                )
            )
        )
        (   (print entity)   )
    )
    (princ)
)

;; Entity List
;; Displays the DXF data of a selected entity.

(defun c:LM-EntityList  nil (elist (car (entsel))))

;; Entity List Nested
;; Displays the DXF data of a selected nested entity.

(defun c:Pst-EntityListNested nil (elist (car (nentsel))))