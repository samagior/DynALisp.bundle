;;  Circular Wipeout
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

;;-------------------=={ Circular Wipeout }==-----------------;;
;;                                                            ;;
;;  Enables the user to create a circular wipeout with a      ;;
;;  given center and radius. Works in all UCS & Views.        ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright � 2013 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;

;; Circular Wipeout
;; Creates a circular wipeout from a center point and radius.

(defun c:LM-CircularWipeout ( / cen rad )
    (cond
        (   (not
                (or (member "acwipeout.arx" (arx)) (arxload "acwipeout.arx" nil)
                    (member "acismui.arx"   (arx)) (arxload "acismui.arx"   nil) ;; 2013
                )
            )
            (princ "\nUnable to load wipeout arx files.")
        )
        (   (and
                (setq cen (getpoint "\nSpecify Center: "))
                (setq rad (getdist  "\nSpecify Radius: " cen))
            )
            (LM:CircularWipeout cen rad)
        )
    )
    (princ)
)

;;-------------------=={ Circle to Wipeout }==----------------;;
;;                                                            ;;
;;  Enables the user to convert a selection of circles to     ;;
;;  wipeout objects matching the original circle properties.  ;;
;;  Works with circles constructed in any UCS.                ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright � 2013 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;

;; Circle To Wipeout
;; Converts the selected circles into circular wipeouts.

(defun c:Pst-CircleToWipeout ( / ent enx inc sel wip )
    (cond
        (   (not
                (or (member "acwipeout.arx" (arx)) (arxload "acwipeout.arx" nil)
                    (member "acismui.arx"   (arx)) (arxload "acismui.arx"   nil) ;; 2013
                )
            )
            (princ "\nUnable to load wipeout arx files.")
        )
        (   (setq sel (ssget "_:L" '((0 . "CIRCLE"))))
            (repeat (setq inc (sslength sel))
                (setq ent (ssname sel (setq inc (1- inc)))
                      enx (entget ent)
                      wip (LM:CircularWipeout (trans (cdr (assoc 10 enx)) ent 1) (cdr (assoc 40 enx)))
                )
                (if wip
                    (progn
                        (entmod (cons (cons -1 wip) (LM:defaultprops (entget wip))))
                        (entdel ent)
                    )
                )
            )
        )
    )
    (princ)
)

;; Default Properties  -  Lee Mac
;; Returns a list of DXF properties for the supplied DXF data,
;; substituting default values for absent DXF groups

(defun LM:defaultprops ( elist )
    (mapcar
        (function
            (lambda ( pair )
                (cond ((assoc (car pair) elist)) ( pair ))
            )
        )
       '(
            (008 . "0")
            (006 . "BYLAYER")
            (039 . 0.0)
            (062 . 256)
            (048 . 1.0)
            (370 . -1)
        )
    )
)

;; Circular Wipeout  -  Lee Mac
;; Creates a circular wipeout with the given center (UCS) & radius

(defun LM:CircularWipeout ( cen rad / ang inc lst )
    (setq acc 50
          inc (/ pi acc 0.5)
          ang 0.0
    )
    (repeat acc
        (setq lst (cons (list 14 (* 0.5 (cos ang)) (* 0.5 (sin ang))) lst)
              ang (+ ang inc)
        )
    )
    (entmakex
        (append
            (list
               '(000 . "WIPEOUT")
               '(100 . "AcDbEntity")
               '(100 . "AcDbWipeout")
                (cons 10 (trans (mapcar '- cen (list rad rad)) 1 0))
                (cons 11 (trans (list (+ rad rad) 0.0) 1 0 t))
                (cons 12 (trans (list 0.0 (+ rad rad)) 1 0 t))
               '(280 . 1)
               '(071 . 2)
            )
            (cons (last lst) lst)
        )
    )
)
;(princ)