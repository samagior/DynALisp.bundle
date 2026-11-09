;; LayerColorWeight - Matches the lineweight of the layers with their color, or their color with their lineweight (Dyl Standard.ctb)
;; Copyright (C) 2026  Samuel Martineau
;;
;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.
;;
;;-------------------------=={ End of Licence }==------------------------;;

;;; The Dyl Standard (Res\Layer\Dyl Standard.pdf, Res\Printers\Plot Styles\Dyl Standard.ctb):
;;;   - colors 10 to 249: the last digit gives the lineweight, the tens the hue
;;;       ##0 0.13   ##1 0.18   ##2 0.25   ##3 0.35   ##4 0.50
;;;       ##5 0.70   ##6 1.00   ##7 1.40   ##8 2.00   ##9 0.13 (dark grey)
;;;   - colors 1 to 7 (pens): 1 0.18, 2 0.25, 3 0.35, 4 0.50, 5 0.70, 6 1.00, 7 1.40
;;;   - greys 8, 9 and 250 to 255: 0.13
;;; Color -> lineweight: every color has its lineweight. Lineweight -> color: the color keeps
;;; its hue and takes the last digit of the lineweight (11 -> 13 for 0.35). The pens 1 to 6
;;; go to their hue (1 red -> 13), black and the greys to the pen of the lineweight (7 -> 3
;;; for 0.35). A lineweight that is not in the standard takes the nearest one.
;;; Skipped: layers in true color or color book, xref layers, and lineweight Default when
;;; matching the color.

;; Lineweights (1/100 mm) of the last digits 0 to 9:
(setq LCW:weights '(13 18 25 35 50 70 100 140 200 13))

;; Lineweight (1/100 mm) of the ACI color aci:
(defun LCW:WeightOf (aci)
  (cond
    ((<= 1 aci 7) (nth aci LCW:weights))
    ((<= 10 aci 249) (nth (rem aci 10) LCW:weights))
    (13)
  )
)

;; Last digit (0 to 8) of the standard lineweight nearest to lw (1/100 mm), nil for
;; Default, ByLayer and ByBlock:
(defun LCW:Digit (lw / d i)
  (if (<= 0 lw)
    (progn
      (setq i 0)
      (repeat 9
        (if (or (not d) (< (abs (- lw (nth i LCW:weights))) (abs (- lw (nth d LCW:weights)))))
          (setq d i)
        )
        (setq i (1+ i))
      )
      d
    )
  )
)

;; ACI color of the lineweight lw (1/100 mm) keeping the hue of the color aci: aci when it
;; already matches, nil when there is none (Default lineweight, 0.13 or 2.00 on a pen or grey):
(defun LCW:ColorOf (aci lw / d)
  (cond
    ((not (setq d (LCW:Digit lw))) nil)
    ((= (LCW:WeightOf aci) (nth d LCW:weights)) aci)
    ((<= 10 aci 249) (+ (* 10 (/ aci 10)) d))
    ((<= 1 aci 6) (+ (nth aci '(0 10 50 90 130 170 210)) d))
    ((<= 1 d 7) d)
  )
)

;; Layer names (upper case) of the objects selected, nil when nothing is selected:
(defun LCW:SelLayers (/ ss i lay lst)
  (if (setq ss (ssget))
    (repeat (setq i (sslength ss))
      (setq lay (strcase (cdr (assoc 8 (entget (ssname ss (setq i (1- i))))))))
      (if (not (member lay lst)) (setq lst (cons lay lst)))
    )
  )
  lst
)

;; Match the lineweight of the layers with their color (tocolor nil), or their color with
;; their lineweight (tocolor T), on every layer or on the layers of the selected objects:
(defun LCW:Run (tocolor / *error* doc scp sel ed nam aci lw new n ok bad)
  (defun *error* (msg)
    (if doc (vla-EndUndoMark doc))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*")) (princ (strcat "\nError: " msg)))
    (princ)
  )
  (initget "All Select")
  (setq scp (cond ((getkword "\nLayers [All/Select] <All>: ")) ("All")))
  (if (or (= scp "All") (setq sel (LCW:SelLayers)))
    (progn
      (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
            n   0
            ok  0
      )
      (vla-StartUndoMark doc)
      (while (setq ed (tblnext "LAYER" (not ed)))
        (setq nam (cdr (assoc 2 ed)))
        (if
          (and (or (not sel) (member (strcase nam) sel))
               (/= 16 (logand 16 (cdr (assoc 70 ed))))
          )
          (progn
            (setq ed  (entget (tblobjname "LAYER" nam))
                  aci (abs (cdr (assoc 62 ed)))
                  lw  (cdr (assoc 370 ed))
                  new (cond
                        ((or (assoc 420 ed) (assoc 430 ed)) nil)
                        (tocolor (LCW:ColorOf aci lw))
                        ((LCW:WeightOf aci))
                      )
            )
            (cond
              ((not new) (setq bad (cons nam bad)))
              ((= new (if tocolor aci lw)) (setq ok (1+ ok)))
              ((entmod
                 (if tocolor
                   (subst (cons 62 (if (minusp (cdr (assoc 62 ed))) (- new) new)) (assoc 62 ed) ed)
                   (subst (cons 370 new) (assoc 370 ed) ed)
                 )
               )
               (setq n (1+ n))
              )
              ((setq bad (cons nam bad)))
            )
          )
        )
      )
      (vla-EndUndoMark doc)
      (princ (strcat "\n" (if tocolor "Color" "Lineweight") " matched on " (itoa n) " layer(s), "
                     (itoa ok) " already matching."
             )
      )
      (if bad
        (princ (strcat "\nNot changed (" (itoa (length bad)) ", true color, xref or no "
                       (if tocolor "color for this lineweight" "lineweight") "): "
                       (Remote>>LM:lst->str (acad_strlsort bad) ", ")
               )
        )
      )
    )
    (princ "\nNothing selected.")
  )
  (princ)
)

;; Layer Color Weight
;; Matches the lineweight of the layers with their color, or their color with their lineweight (Dyl Standard).

(defun c:Dyl-LayerColorWeight (/ mode)
  (initget "Lineweight Color")
  (setq mode (cond ((getkword "\nMatch the layer [Lineweight/Color] to the other <Lineweight>: ")) ("Lineweight")))
  (LCW:Run (= mode "Color"))
)


;; Layer Lineweight By Color
;; Sets the lineweight of the layers from their color (Dyl Standard: color ##0 = 0.13, ##1 = 0.18...).

(defun c:Pst-LayerWeightByColor () (LCW:Run nil))


;; Layer Color By Lineweight
;; Sets the last digit of the layer colors from their lineweight, keeping their hue (Dyl Standard).

(defun c:Pst-LayerColorByWeight () (LCW:Run T))
