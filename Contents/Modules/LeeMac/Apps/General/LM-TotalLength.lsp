;;  Total Length
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

;;--------------------=={ Total Length }==--------------------;;
;;                                                            ;;
;;  Displays the total length of selected objects at the      ;;
;;  command line. The units and precision format of the       ;;
;;  printed result is dependent upon the settings of the      ;;
;;  LUNITS & LUPREC system variables respectively.            ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2013 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;

;; Total Length
;; Displays the total length of the selected objects at the command line.

(defun c:LM-TotalLength (/ e i l s) 
    (if 
        (setq s (ssget 
                    '((0 . "ARC,CIRCLE,ELLIPSE,LINE,*POLYLINE,SPLINE")
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
            (setq l 0.0)
            (repeat (setq i (sslength s)) 
                (setq e (ssname s (setq i (1- i)))
                      l (+ l (vlax-curve-getdistatparam e (vlax-curve-getendparam e)))
                )
            )
            (princ "\nTotal Length: ")
            (princ (rtos l))
        )
    )
    (princ)
)
;;; (vl-load-com)
;;; (princ)