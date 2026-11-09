;;  Elevation Marker
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

;;-----------------------=={ Elevation Marker }==-----------------------;;
;;                                                                      ;;
;;  This program continuously prompts the user to specify a point and   ;;
;;  constructs an elevation marker composed of a variable width         ;;
;;  polyline & single-line text object at the specified point, with     ;;
;;  the text content displaying the UCS Y-coordinate of the point.      ;;
;;                                                                      ;;
;;----------------------------------------------------------------------;;
;;  Author:  Lee Mac, Copyright � 2013  -  www.lee-mac.com              ;;
;;----------------------------------------------------------------------;;

;; Elevation Marker
;; Places elevation markers showing the UCS Y coordinate of each picked point.

(defun c:LM-ElevationMarker ( / *error* ang hgt len ocs pt1 pt2 pt3 pt4 str )

    (defun *error* ( msg )
        (if (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*"))
            (princ (strcat "\nError: " msg))
        )
        (princ)
    )

    (setq hgt (getvar 'textsize)
          ocs (trans '(0.0 0.0 1.0) 1 0 t)
          ang (angle '(0.0 0.0) (trans (getvar 'ucsxdir) 0 ocs t))
    )
    (terpri)
    (while (setq pt1 (getpoint "\rSpecify point <exit>: "))
        (setq str (rtos (cadr pt1))
              len (strlen str)
              pt2 (list (car  pt1) (+ (cadr pt1) (* hgt 0.5 (sqrt 3))))
              pt3 (list (- (car pt1) (* hgt len)) (cadr pt2))
              pt4 (list (- (car pt2) (* hgt 0.5 len)) (+ (cadr pt2) hgt))
        )
        (foreach sym '(pt1 pt2 pt3 pt4)
            (set sym (trans (eval sym) 1 ocs))
        )
        (entmake
            (list
               '(000 . "LWPOLYLINE")
               '(100 . "AcDbEntity")
               '(100 . "AcDbPolyline")
               '(090 . 3)
               '(070 . 0)
                (cons 038 (caddr pt1))
                (cons 010 pt1)
               '(040 . 0.0)
                (cons 041 hgt)
                (cons 010 pt2)
                (cons 040 (* hgt 0.05))
                (cons 041 (* hgt 0.05))
                (cons 010 pt3)
                (cons 210 ocs)
            )
        )
        (entmake
            (list
               '(000 . "TEXT")
                (cons 007 (getvar 'textstyle))
                (cons 001 str)
                (cons 050 ang)
                (cons 040 hgt)
                (cons 010 pt4)
                (cons 011 pt4)
               '(072 . 1)
               '(073 . 2)
                (cons 210 ocs)
            )
        )
    )
    (princ)
)