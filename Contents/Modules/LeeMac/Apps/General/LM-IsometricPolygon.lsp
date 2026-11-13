;;  Isometric Polygon
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

;;------------------=={ Isometric Polygon }==-----------------;;
;;                                                            ;;
;;  Enables the user to construct a regular polygon projected ;;
;;  in the active isometric plane.                            ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright � 2012 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;

;; Isometric Polygon
;; Draws a regular polygon projected in the active isometric plane.

(defun c:LM-IsometricPolygon ( / a b c i l m p r s )
    (if (null n) (setq n 6))
    (while
        (< (setq n (cond ((getint (strcat "\nSpecify Number of Sides <" (itoa n) ">: "))) ( n ))) 3)
        (princ "\nRequires an integer greater than or equal to 3.")
    )
    (if (and (setq c (getpoint "\nSpecify Center of Polygon: "))
             (progn
                 (initget 6)
                 (setq r (getdist c "\nSpecify Radius: "))
             )
        )
        (progn
            (if (= 0 (getvar 'snapstyl))
                (setq a 1.0
                      b 1.0
                )
                (setq a (/ (sqrt 3.0) (sqrt 2.0))
                      b (/ 1.0 (sqrt 2.0))
                )
            )
            (setq i (/ (+ pi pi) n)
                  c (trans c 1 0)
                  p (/ pi 3.0)
                  s 0.0
            )
            (repeat n
                (setq l (cons (list (* a r (cos s)) (* b r (sin s))) l)
                      s (+ i s)
                )
            )
            (if (= 0 (getvar 'snapstyl))
                (setq m '((1.0 0.0) (0.0 1.0)))
                (setq m
                    (cdr
                        (assoc (getvar 'snapisopair)
                            (list
                                (list 0 (list (cos p) (sin p)) (list (sin (- p)) (cos p)))
                               '(1 (1.0 0.0) (0.0 1.0))
                                (list 2 (list (cos p) (sin (- p))) (list (sin p) (cos p)))
                            )
                        )
                    )
                )
            )
            (entmake
                (append
                    (list
                       '(0 . "LWPOLYLINE")
                       '(100 . "AcDbEntity")
                       '(100 . "AcDbPolyline")
                        (cons 90 n)
                       '(70 . 1)
                    )
                    (mapcar '(lambda ( p ) (cons 10 (mapcar '+ (mxv m p) c))) l)
                )
            )
        )
    )
    (princ)
)

;; Matrix x Vector  -  Vladimir Nesterovsky
;; Args: m - nxn matrix, v - vector in R^n

(defun mxv ( m v )
    (mapcar '(lambda ( r ) (apply '+ (mapcar '* r v))) m)
)
;(princ)