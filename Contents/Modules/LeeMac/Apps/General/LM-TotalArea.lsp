;;  Total Area
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

;;---------------------=={ Total Area }==---------------------;;
;;                                                            ;;
;;  Displays the total area of selected objects at the        ;;
;;  command line. The precision of the printed result is      ;;
;;  dependent on the setting of the LUPREC system variable.   ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2013 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;

;; Total Area
;; Displays the total area of the selected objects at the command line.

(defun c:LM-TotalArea (/ a i s) 
  (if 
    (setq s (ssget 
              '((0 . "CIRCLE,ELLIPSE,*POLYLINE,SPLINE")
                (-4 . "<NOT")
                (-4 . "<AND")
                (0 . "POLYLINE")
                (-4 . "&")
                (70 . 80)
                (-4 . "AND>")
                (-4 . "NOT>")
               )
            )
    )
    (progn 
      (setq a 0.0)
      (repeat (setq i (sslength s)) 
        (setq a (+ a (vlax-curve-getarea (ssname s (setq i (1- i))))))
      )
      (princ "\nTotal Area: ")
      (princ (rtos a 2))
    )
  )
  (princ)
)
;;; (vl-load-com)
;;; (princ)