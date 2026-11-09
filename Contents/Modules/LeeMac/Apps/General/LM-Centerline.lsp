;;  Centerline
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

;;--------------------=={ Centerline }==----------------------;;
;;                                                            ;;
;;  Creates a pair of centerlines for Arcs, Circles, Ellipses ;;
;;  and Elliptical arcs with a user-defined length and angle. ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2013 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Version 1.2    -    13-08-2013                            ;;
;;------------------------------------------------------------;;

;; Centerline
;; Draws a pair of centerlines on arcs, circles and ellipses with a set length and angle.

(defun c:LM-Centerline ( / ang dis ent pt1 pt2 )
    (if
        (and
            (progn
                (while
                    (progn (setvar 'errno 0) (setq ent (car (entsel "\nSelect Arc, Circle or Ellipse: ")))
                        (cond
                            (   (= 7 (getvar 'errno))
                                (princ "\nMissed, try again.")
                            )
                            (   (= 'ename (type ent))
                                (if (not (wcmatch (cdr (assoc 0 (entget ent))) "CIRCLE,ARC,ELLIPSE"))
                                    (princ "\nInvalid Object Selected.")
                                )
                            )
                        )
                    )
                )
                (= 'ename (type ent))
            )
            (setq pt1 (trans (cdr (assoc 10 (entget ent))) ent 1))
            (setq pt2 (getpoint "\nSpecify Length & Direction of Centreline: " pt1))
            (setq ang (angle pt1 pt2)
                  dis (distance pt1 pt2)
            )
        )
        (repeat 2
            (entmake
                (list
                   '(0 . "LINE")
                    (cons 10 (trans (polar pt1 ang dis) 1 0))
                    (cons 11 (trans (polar pt1 ang (- dis)) 1 0))
                )
            )
            (setq ang (+ ang (/ pi 2.0))
                  dis (- dis)
            )
        )
    )
    (princ)
)
(princ)