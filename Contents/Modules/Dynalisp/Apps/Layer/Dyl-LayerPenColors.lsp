;; LayerPenColors - Switches the layer colors from the 255 colors to the pen colors 1 to 7 by their lineweight, and back
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

;;; Pens: the color of each layer is given by its current lineweight only (its color is not
;;; read), the standard lineweight nearest to it:
;;;     0.13 -> 30   0.18 -> 1   0.25 -> 2   0.35 -> 3
;;;     0.50 -> 4    0.70 -> 5   1.00 -> 6   1.40 -> 7
;;; except the layers matching a rule of Res\Layer\PenColors.csv (the first rule matching):
;;;   Name ; Layers ; Colors ; Color ; Description
;;;   - Layers: layer names (wildcards, upper or lower case), "" any layer
;;;   - Colors: current ACI colors (wildcards: 20# is 200 to 209), "" any color
;;;   - Color : the color given to the layer, "" keeps its color as is
;;; Layers with lineweight Default or 2.00 (no pen) are left as they are and listed.
;;; The color of a layer is saved in the layer (ldata "dyl-pens") the first time it is
;;; changed, true colors and color books too. Restore gives it back and forgets it, so Pens
;;; can run again on new layers without losing the colors saved before.

;; Pen color of the standard lineweights (1/100 mm), nil for 2.00:
(setq LPC:pens '((13 . 30) (18 . 1) (25 . 2) (35 . 3) (50 . 4) (70 . 5) (100 . 6) (140 . 7) (200)))

;; Rules when Res\Layer\PenColors.csv is missing: ((name layers colors color) ...)
(setq LPC:defaults '(("Non-plotting" "" "140" nil)
                     ("Text and notes" "" "41" nil)
                     ("Dimensions" "" "211" nil)
                     ("Existing to remain" "" "20#" nil)
                     ("Patterns" "*-PATT,*-PATT-*" "" 40)
                     ("Screened" "*-SCRN,*-SCRN-*" "" 8)
                     ("Existing" "*-EXST,*-EXST-*" "" 9)
                    )
)

;; Rules of Res\Layer\PenColors.csv (user copy first): ((name layers colors color) ...),
;; layers in upper case, color nil to keep the color as is:
(defun LPC:Rules (/ fle lst)
  (setq fle (Dyl:UserFile (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\Layer\\PenColors.csv")))
  (foreach r (if (and Remote>>Dyl:CsvRead (findfile fle)) (Remote>>Dyl:CsvRead fle 4))
    (if (and (/= "" (car r)) (or (/= "" (cadr r)) (/= "" (caddr r))))
      (setq lst (cons (list (car r) (strcase (cadr r)) (caddr r) (if (/= "" (cadddr r)) (atoi (cadddr r)))) lst))
    )
  )
  (cond ((reverse lst)) (LPC:defaults))
)

;; First rule matching the layer name nam and its ACI color aci (nil: true color, the
;; rules on colors do not match it):
(defun LPC:Rule (nam aci rules)
  (vl-some
    '(lambda (r)
       (if
         (and (or (= "" (cadr r)) (wcmatch (strcase nam) (cadr r)))
              (or (= "" (caddr r)) (and aci (wcmatch (itoa aci) (caddr r))))
         )
         r
       )
     )
    rules
  )
)

;; Pen color of the lineweight lw (1/100 mm), nil for Default, ByLayer, ByBlock and 2.00:
(defun LPC:PenOf (lw / best)
  (if (<= 0 lw)
    (progn
      (foreach p LPC:pens
        (if (or (not best) (< (abs (- lw (car p))) (abs (- lw (car best))))) (setq best p))
      )
      (cdr best)
    )
  )
)

;; Color of the layer lay (vla) as saved: (method index red green blue book name):
(defun LPC:ColorGet (lay / c)
  (setq c (vla-get-TrueColor lay))
  (list (vla-get-ColorMethod c) (vla-get-ColorIndex c) (vla-get-Red c) (vla-get-Green c) (vla-get-Blue c)
        (vla-get-BookName c) (vla-get-ColorName c)
  )
)

;; Give the layer lay (vla) the ACI color aci, or the color sav saved by LPC:ColorGet:
(defun LPC:ColorPut (lay aci sav / c)
  (setq c (vla-get-TrueColor lay))
  (cond
    (aci (vla-put-ColorIndex c aci))
    ((= acColorMethodByRGB (car sav))
     (vla-SetRGB c (nth 2 sav) (nth 3 sav) (nth 4 sav))
     (if (/= "" (nth 5 sav)) (vl-catch-all-apply 'vla-SetColorBookColor (list c (nth 5 sav) (nth 6 sav))))
    )
    ((vla-put-ColorIndex c (nth 1 sav)))
  )
  (vla-put-TrueColor lay c)
)

;; Layer names (upper case) of the objects selected, nil when nothing is selected:
(defun LPC:SelLayers (/ ss i lay lst)
  (if (setq ss (ssget))
    (repeat (setq i (sslength ss))
      (setq lay (strcase (cdr (assoc 8 (entget (ssname ss (setq i (1- i))))))))
      (if (not (member lay lst)) (setq lst (cons lay lst)))
    )
  )
  lst
)

;; Switch the layer colors to the pen colors (restore nil), or give them back their saved
;; color (restore T), on every layer or on the layers of the selected objects:
(defun LPC:Run (restore / *error* doc scp sel rules nam c aci rule new sav n ok kept none bad)
  (defun *error* (msg)
    (if doc (vla-EndUndoMark doc))
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*EXIT*")) (princ (strcat "\nError: " msg)))
    (princ)
  )
  (initget "All Select")
  (setq scp (cond ((getkword "\nLayers [All/Select] <All>: ")) ("All")))
  (if (or (= scp "All") (setq sel (LPC:SelLayers)))
    (progn
      (setq doc   (vla-get-ActiveDocument (vlax-get-acad-object))
            rules (if (not restore) (LPC:Rules))
            n     0
            ok    0
            kept  0
            none  0
      )
      (vla-StartUndoMark doc)
      (vlax-for lay (vla-get-Layers doc)
        (setq nam (vla-get-Name lay))
        (if (and (or (not sel) (member (strcase nam) sel)) (not (wcmatch nam "*|*")))
          (if restore
            (cond
              ((not (setq sav (vlax-ldata-get lay "dyl-pens"))) (setq none (1+ none)))
              ((not (vl-catch-all-error-p (vl-catch-all-apply 'LPC:ColorPut (list lay nil sav))))
               (vlax-ldata-delete lay "dyl-pens")
               (setq n (1+ n))
              )
              ((setq bad (cons nam bad)))
            )
            (progn
              (setq c    (vla-get-TrueColor lay)
                    aci  (if (= acColorMethodByACI (vla-get-ColorMethod c)) (vla-get-ColorIndex c))
                    rule (LPC:Rule nam aci rules)
              )
              (cond
                ((and rule (not (cadddr rule))) (setq kept (1+ kept)))
                ((not (setq new (if rule (cadddr rule) (LPC:PenOf (vla-get-Lineweight lay))))) (setq bad (cons nam bad)))
                ((= new aci) (setq ok (1+ ok)))
                ((progn
                   (if (not (vlax-ldata-get lay "dyl-pens")) (vlax-ldata-put lay "dyl-pens" (LPC:ColorGet lay)))
                   (not (vl-catch-all-error-p (vl-catch-all-apply 'LPC:ColorPut (list lay new nil))))
                 )
                 (setq n (1+ n))
                )
                ((setq bad (cons nam bad)))
              )
            )
          )
        )
      )
      (vla-EndUndoMark doc)
      (if restore
        (progn
          (princ (strcat "\nColor restored on " (itoa n) " layer(s), " (itoa none) " without a saved color."))
          (if bad
            (princ (strcat "\nNot restored (" (itoa (length bad)) "): " (Remote>>LM:lst->str (acad_strlsort bad) ", ")))
          )
        )
        (progn
          (princ (strcat "\nPen colors set on " (itoa n) " layer(s), " (itoa ok) " already matching, "
                         (itoa kept) " kept by a rule (Res\\Layer\\PenColors.csv)."
                 )
          )
          (if bad
            (princ (strcat "\nNot changed (" (itoa (length bad)) ", lineweight Default or 2.00): "
                           (Remote>>LM:lst->str (acad_strlsort bad) ", ")
                   )
            )
          )
          (if (< 0 n) (princ "\nRun Pst-LayerColorsRestore (UNPENS) to give the layers back their colors."))
        )
      )
    )
    (princ "\nNothing selected.")
  )
  (princ)
)

;; Layer Pen Colors
;; Switches the layer colors to the pen colors 1 to 7 from their lineweight, or restores their saved colors.

(defun c:Dyl-LayerPenColors (/ mode)
  (initget "Pens Restore")
  (setq mode (cond ((getkword "\nLayer colors [Pens/Restore] <Pens>: ")) ("Pens")))
  (LPC:Run (= mode "Restore"))
)


;; Layer Colors To Pens
;; Sets the layer colors to the pen colors 1 to 7 from their lineweight (30 for 0.13), saving their colors.

(defun c:Pst-LayerColorsToPens () (LPC:Run nil))


;; Layer Colors Restore
;; Gives the layers back the colors saved when they were switched to the pen colors.

(defun c:Pst-LayerColorsRestore () (LPC:Run T))
