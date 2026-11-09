;; QuickDraw - Draw closed outlines with AutoCAD tools and fill them with predefined hatches and layers
;; Copyright (C) 2023  Samuel Martineau
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

;;-------------------------=={ Functions }==------------------------;;

;;  Ways to make the outline of the hatch: (method label keyword), the list of the materials
;;  (*mt:methods* in Remote\Dyl-Materials.lsp). The method is a behavior of the material
;;  (Material behaviors of the Materials window), with the width and justification of
;;  Linear and the sides of Polygon; a preset can draw its material with another method
;;  (Method column, "": the method of the material). No method at all: asked when drawn:
(setq *qd:modes*   *mt:methods*
      ;;  Linear: where the line drawn is in its band: (justify label)
      *qd:justify* *mt:justify*
)

;;  Main entities created after the entity mark (nil: from the start of the drawing):
(defun Dyl:QuickDrawAfter (mark / lst)
  (while (setq mark (if mark (entnext mark) (entnext)))
    (if
      (and (entget mark)
           (not (member (cdr (assoc 0 (entget mark))) '("ATTRIB" "VERTEX" "SEQEND")))
      )
      (setq lst (cons mark lst))
    )
  )
  (reverse lst)
)

;;  Run a drawing command and let the user finish it, returns the entities it created:
(defun Dyl:QuickDrawDraw (cmd / mark)
  (setq mark (entlast))
  (apply 'command cmd)
  (while (= 1 (logand 1 (getvar "CMDACTIVE"))) (command pause))
  (Dyl:QuickDrawAfter mark)
)

;;  Selection set -> list of enames:
(defun Dyl:QuickDrawSsList (ss / i lst)
  (if ss (repeat (setq i (sslength ss)) (setq lst (cons (ssname ss (setq i (1- i))) lst))))
  lst
)

;;  Ask the method of a preset that has none, the last one given by default (saved with setenv):
(defun Dyl:QuickDrawAsk (/ def kw)
  (setq def (cond
              ((assoc (getenv "DynalispQuickDrawMode") *qd:modes*) (getenv "DynalispQuickDrawMode"))
              ("Polyline")
            )
  )
  (initget (Remote>>LM:lst->str (mapcar 'caddr *qd:modes*) " "))
  (if (setq kw (getkword (strcat "\nDraw with ["
                                 (Remote>>LM:lst->str (mapcar 'caddr *qd:modes*) "/")
                                 "] <"
                                 def
                                 ">: "
                         )
               )
      )
    (setq def (car (vl-some '(lambda (x) (if (= (strcase kw) (strcase (car x))) x)) *qd:modes*)))
  )
  (setenv "DynalispQuickDrawMode" def)
  def
)

;;  Make the outlines of the hatch with a method of *qd:modes*, returns their enames:
;;  sides: the number of sides of Polygon (text, "": asked by POLYGON):
;;  Shrinkwrap gap tolerance of the material mat: 0.0 when its gap override is off (the gap
;;  step of Dyl-Settings is tried when no outline is found), else its gap of the drawing units
;;  (MEASUREMENT: imperial, metric), nil when that gap is empty (asked at every Shrinkwrap):
(defun Dyl:QuickDrawGap (mat / v)
  (cond
    ((/= "1" (nth 44 mat)) 0.0)
    ((and (setq v (distof (cond ((nth (if (= 1 (getvar "MEASUREMENT")) 45 43) mat)) ("")) 2)) (<= 0 v)) v)
  )
)

;;  Ask the gap tolerance (0 by default; larger gaps tried when no outline is found):
(defun Dyl:QuickDrawGapAsk ()
  (initget 4)
  (cond
    ((getdist "\nGap tolerance, objects closer than it are joined (0: exact, larger ones tried if needed) <0>: "))
    (0.0)
  )
)

(defun Dyl:QuickDrawOutlines (mode sides gap)
  (cond
    ((= "Rectangle" mode) (Dyl:QuickDrawDraw '("_.rectang")))
    ((= "Circle" mode) (Dyl:QuickDrawDraw '("_.circle")))
    ((= "Polygon" mode) (Dyl:QuickDrawDraw (if (/= "" sides) (list "_.polygon" sides) '("_.polygon"))))
    ((= "Ellipse" mode) (Dyl:QuickDrawDraw '("_.ellipse")))
    ;;  BOUNDARY: one polyline per pick (plus its islands), with the island detection set by the user:
    ((= "Pick" mode) (Dyl:QuickDrawDraw '("_.-boundary" "_a" "_o" "_p" "")))
    ;;  gap: the gap tolerance (a number, nil: asked now, see Dyl:QuickDrawGap):
    ((= "Shrinkwrap" mode)
     (princ "\nSelect the objects to shrinkwrap:")
     (Dyl:QuickDrawSsList
       (Remote>>Dyl:ShrinkwrapGap
         (cond
           ((ssget '((-4 . "<NOT") (0 . "POINT,XLINE,RAY,VIEWPORT") (-4 . "NOT>"))))
           ((ssadd))
         )
         (cond (gap) ((Dyl:QuickDrawGapAsk)))
       )
     )
    )
    ((= "Select" mode)
     (princ "\nSelect the closed objects to hatch:")
     (Dyl:QuickDrawSsList (ssget '((0 . "LWPOLYLINE,POLYLINE,CIRCLE,ELLIPSE,SPLINE"))))
    )
    ((Dyl:QuickDrawDraw '("_.pline")))
  )
)

;;-------------------------=={ Linear }==------------------------;;

;;  Linear draws a line (one or more segments) and makes a band of a width along it: the line
;;  is its center, its left border or its right border (looking from the start point). Each
;;  segment is a closed outline (mitered with the next one) with its own hatch, turned by the
;;  angle of the segment, so the hatch follows the line.

;;  Point without its Z, vector of unit length:
(defun Dyl:QuickDraw2d (p) (list (car p) (cadr p)))
(defun Dyl:QuickDrawUnit (v / l)
  (setq l (distance '(0.0 0.0) v))
  (mapcar '(lambda (x) (/ x l)) v)
)

;;  Distances of the left and right borders of a band of width w to the line (positive: on
;;  its left), the line drawn from jus (see *qd:justify*):
(defun Dyl:QuickDrawSides (w jus)
  (cond
    ((= "Left" jus) (list 0.0 (- w)))
    ((= "Right" jus) (list w 0.0))
    ((list (/ w 2.0) (/ w -2.0)))
  )
)

;;  Points (2D) of the line pts offset by d (positive: on its left), mitered at the corners
;;  (a straight corner keeps the offset point of the next segment):
(defun Dyl:QuickDrawOffset (pts d / segs res)
  (setq segs (mapcar '(lambda (a b / u nv)
                        (setq u  (Dyl:QuickDrawUnit (mapcar '- b a))
                              nv (list (* d (- (cadr u))) (* d (car u)))
                        )
                        (list (mapcar '+ a nv) (mapcar '+ b nv))
                      )
                     pts
                     (cdr pts)
             )
        res  (list (car (car segs)))
  )
  (mapcar '(lambda (s1 s2)
             (setq res (cons (cond ((inters (car s1) (cadr s1) (car s2) (cadr s2) nil)) ((car s2))) res))
           )
          segs
          (cdr segs)
  )
  (reverse (cons (cadr (last segs)) res))
)

;;  Show the line pts and the borders of its band while it is drawn (temporary vectors):
(defun Dyl:QuickDrawPreview (pts w jus / pp sd l r)
  (redraw)
  (if (cdr pts)
    (progn
      (setq pp (mapcar 'Dyl:QuickDraw2d pts)
            sd (Dyl:QuickDrawSides w jus)
      )
      (mapcar '(lambda (a b) (grdraw a b -1 1)) pp (cdr pp))
      (foreach side (list (Dyl:QuickDrawOffset pp (car sd)) (Dyl:QuickDrawOffset pp (cadr sd)))
        (mapcar '(lambda (a b) (grdraw a b -1 0)) side (cdr side))
      )
      (setq l (Dyl:QuickDrawOffset pp (car sd))
            r (Dyl:QuickDrawOffset pp (cadr sd))
      )
      (grdraw (car l) (car r) -1 0)
      (grdraw (last l) (last r) -1 0)
    )
  )
)

;;  Closed polyline of the points pts (UCS, with their Z) on the current layer:
(defun Dyl:QuickDrawBand (pts / w)
  (setq w (mapcar '(lambda (p) (trans p 1 0)) pts))
  (entmakex (append (list '(0 . "LWPOLYLINE")
                          '(100 . "AcDbEntity")
                          (cons 8 (getvar "CLAYER"))
                          '(100 . "AcDbPolyline")
                          (cons 90 (length w))
                          '(70 . 1)
                          (cons 38 (caddr (car w)))
                    )
                    (mapcar '(lambda (p) (list 10 (car p) (cadr p))) w)
            )
  )
)

;;  Ask a width among the widths lst (numbers): one of them, or any other one typed. Enter
;;  keeps the default: the last width used when it is one of them, else the first:
(defun Dyl:QuickDrawAskWidth (lst / txt last def res)
  (setq txt  (mapcar '(lambda (v) (rtos v 2 (if (equal v (fix v) 1e-9) 0 4))) lst)
        last (distof (cond ((getenv "DynalispQuickDrawWidth")) ("")) 2)
        def  (cond ((and last (vl-some '(lambda (v) (equal v last 1e-9)) lst)) last) ((car lst)))
  )
  (initget 6 (Remote>>LM:lst->str txt " "))
  (setq res (getdist (strcat "\nWidth [" (Remote>>LM:lst->str txt "/") "] <" (rtos def) ">: ")))
  (cond
    ((numberp res) res)
    ((= 'STR (type res)) (distof res 2))
    (def)
  )
)

;;  Draw a Linear band: the width wid and the justification jus of the material (wid "": the
;;  last width used, asked when there is none; several widths divided by commas: asked among
;;  them; jus "Ask": asked first, the last one given by default), both can be changed at the
;;  first prompt for this band only. off: the offset of the hatch origin from the line.
;;  Returns ((outline angle origin) ...): one closed outline per segment, the angle of the
;;  segment in degrees and the hatch origin on the line (WCS), nil when no line was drawn.
;;  Sets qd:width (local of Dyl:QuickDraw) to the width drawn:
(defun Dyl:QuickDrawLinear (wid jus off / w ws p q pts pp sd l r z d u i segs)
  (setq ws (Remote>>Dyl:MaterialWidths wid)
        w  (cond
             ((cdr ws) (Dyl:QuickDrawAskWidth ws))
             ((car ws))
             ((distof (cond ((getenv "DynalispQuickDrawWidth")) ("")) 2))
           )
  )
  (if (cdr ws) (setenv "DynalispQuickDrawWidth" (rtos w 2 8)))
  (if (not (assoc jus *qd:justify*)) (setq jus "Center"))
  ;;  Ask when drawn: the last justification given by default (saved with setenv):
  (if (= "Ask" jus)
    (progn
      (setq jus (if (member (getenv "DynalispQuickDrawJustify") '("Center" "Left" "Right"))
                  (getenv "DynalispQuickDrawJustify")
                  "Center"
                )
      )
      (initget "Center Left Right")
      (if (setq q (getkword (strcat "\nLine on the [Center/Left/Right] <" jus ">: "))) (setq jus q))
      (setenv "DynalispQuickDrawJustify" jus)
    )
  )
  (if (not w)
    (progn
      (initget 6)
      (if (setq w (getdist "\nWidth of the band: ")) (setenv "DynalispQuickDrawWidth" (rtos w 2 8)))
    )
  )
  ;;  Start point, or a width / justification for this band:
  (while (and w (not p))
    (initget "Width Justification")
    (setq p (getpoint (strcat "\nStart point or [Width/Justification] <width "
                              (rtos w)
                              ", "
                              (cadr (assoc jus *qd:justify*))
                              ">: "
                      )
            )
    )
    (cond
      ((= "Width" p)
       (initget 6)
       (if (setq q (getdist (strcat "\nWidth <" (rtos w) ">: ")))
         (progn (setq w q) (setenv "DynalispQuickDrawWidth" (rtos w 2 8)))
       )
       (setq p nil)
      )
      ((= "Justification" p)
       (initget "Center Left Right")
       (if (setq q (getkword (strcat "\nLine on the [Center/Left/Right] <" jus ">: "))) (setq jus q))
       (setq p nil)
      )
      ((null p) (setq w nil))
    )
  )
  ;;  The points of the line, shown with the band while they are picked:
  (if p
    (progn
      (setq pts (list p))
      (while
        (progn
          (initget "Undo")
          (setq q (getpoint (last pts) (if (cdr pts) "\nNext point or [Undo] <done>: " "\nNext point: ")))
        )
        (cond
          ((= "Undo" q) (if (cdr pts) (setq pts (reverse (cdr (reverse pts))))))
          ((< 1e-8 (distance (Dyl:QuickDraw2d q) (Dyl:QuickDraw2d (last pts)))) (setq pts (append pts (list q))))
        )
        (Dyl:QuickDrawPreview pts w jus)
      )
      (redraw)
    )
  )
  ;;  One closed outline per segment, with the angle of the segment and the hatch origin on
  ;;  the line: the start of the segment moved by off across it, into the band (to the left
  ;;  of the line for Center):
  (setq qd:width w)
  (if (cdr pts)
    (progn
      (setq pp (mapcar 'Dyl:QuickDraw2d pts)
            sd (Dyl:QuickDrawSides w jus)
            l  (Dyl:QuickDrawOffset pp (car sd))
            r  (Dyl:QuickDrawOffset pp (cadr sd))
            z  (cond ((caddr (car pts))) (0.0))
            d  (* (if (= "Left" jus) -1.0 1.0) off)
            i  0
      )
      (repeat (1- (length pp))
        (setq u    (Dyl:QuickDrawUnit (mapcar '- (nth (1+ i) pp) (nth i pp)))
              segs (cons (list (Dyl:QuickDrawBand
                                 (mapcar '(lambda (p) (list (car p) (cadr p) z))
                                         (list (nth i l) (nth (1+ i) l) (nth (1+ i) r) (nth i r))
                                 )
                               )
                               (/ (* 180.0 (angle (nth i pp) (nth (1+ i) pp))) pi)
                               (trans (list (- (car (nth i pp)) (* d (cadr u))) (+ (cadr (nth i pp)) (* d (car u))) z) 1 0)
                         )
                         segs
                   )
              i    (1+ i)
        )
      )
      (reverse segs)
    )
  )
)

;;-------------------------=={ Draw }==------------------------;;

;;  Make the outlines with the method mode (asked when it is not a method of *qd:modes*), then
;;  hatch them with the material mat (see Remote>>Dyl:MaterialHatch). The behaviors of the
;;  material give the band of Linear (width and justify, see Dyl:QuickDrawLinear, each
;;  segment hatched along its angle) and the sides of Polygon:
(defun Dyl:QuickDraw (mat mode / *error* doc lyr out bad segs mt:keepouts mt:scale mt:origin qd:width)

  (defun *error* (msg)
    (redraw)
    (if lyr (setvar "CLAYER" lyr))
    (vla-EndUndoMark doc)
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (vla-StartUndoMark doc)
  (if (not (assoc mode *qd:modes*)) (setq mode (Dyl:QuickDrawAsk)))

  ;;  Make the outlines on the layer of the outline layer key (created if missing, see Dyl-LayerKeys):
  (setq lyr (getvar "CLAYER"))
  (vl-catch-all-apply 'setvar (list "CLAYER" (Remote>>Dyl:LayerKeyLayer (nth 7 mat))))
  (princ (strcat "\nQuick Draw - " (cadr (assoc mode *qd:modes*)) ":"))
  (if (= "Linear" mode)
    (setq segs (Dyl:QuickDrawLinear (cond ((nth 34 mat)) (""))
                                    (cond ((nth 35 mat)) ("Center"))
                                    (cond ((distof (cond ((nth 40 mat)) ("")) 2)) (0.0))
               )
    )
    (setq out (Dyl:QuickDrawOutlines mode (cond ((nth 36 mat)) ("")) (Dyl:QuickDrawGap mat)))
  )
  (setvar "CLAYER" lyr)
  (setq lyr nil)

  ;;  Only closed curves can be hatched (drawn ones that are open are erased, selected ones are kept):
  (foreach e out
    (if (not (Remote>>Dyl:MaterialClosed-p e))
      (progn
        (setq bad t
              out (vl-remove e out)
        )
        (if (/= "Select" mode) (entdel e))
      )
    )
  )
  (if bad (alert "\nError: only closed outlines can be hatched (open ones were skipped)"))
  ;;  The objects selected by the user are kept with a material without border:
  (setq mt:keepouts (= "Select" mode))
  (cond
    ;;  Linear: each segment hatched along its angle:
    ((= "Linear" mode)
     (if segs
       (progn
         ;;  The behaviors of Linear: the hatch scale from the width (width x factor, in place
         ;;  of the scales of the material), the hatch origin on the line:
         (setq mt:scale (if (and (= "1" (nth 37 mat)) qd:width)
                          (* qd:width (cond ((distof (cond ((nth 38 mat)) ("")) 2)) (1.0)))
                        )
         )
         (foreach s segs
           (setq mt:origin (if (= "1" (nth 39 mat)) (caddr s)))
           (Remote>>Dyl:MaterialHatchAt mat (list (car s)) (cadr s))
         )
       )
       (princ "\nNo line drawn.")
     )
    )
    (out (Remote>>Dyl:MaterialHatch mat out))
    ((princ "\nNo outline to hatch."))
  )
  (vla-EndUndoMark doc)
  (princ)
)

;;  Draw a preset: its material gives the hatch, the layer keys and how it is drawn (its
;;  behaviors), the method of the preset replacing the one of the material when it has one:
(defun Dyl:QuickDrawRun (rec / mat)
  (if (setq mat (Remote>>Dyl:MaterialGet (nth 3 rec)))
    (Dyl:QuickDraw mat (if (/= "" (nth 4 rec)) (nth 4 rec) (cond ((nth 33 mat)) (""))))
    (alert (strcat "\nError: the material of the preset \""
                   (nth 2 rec)
                   "\" no longer exists ("
                   (nth 3 rec)
                   ").\nPick another one in Dyl-QuickDraw."
           )
    )
  )
)

;;-------------------------=={ Presets }==------------------------;;

;;  A preset is a list of strings (see Remote\Dyl-Presets.lsp for the preset engine):
;;  (id group name material method)
;;  id is the id of a default preset (e.g. "qd-Demolition", run by Pst-QuickDrawDemolition), or
;;  a custom id (cu-...). material is the id of a material (see Remote\Dyl-Materials.lsp), so
;;  several presets can share it (e.g. QD-BRICK and PL-BRICK). method is a method of *qd:modes*
;;  that replaces the one of the material, or "" to use the method of the material (its
;;  behaviors, with the width of Linear and the sides of Polygon; asked when drawn when the
;;  material has none either).
;;  The presets are saved to Res\QuickDraw.csv (spec in Remote\Dyl-QuickDrawPresets.lsp).

;;  Default presets, restored by the Reset Selected and Reset All buttons:
(setq *qd:defaults*
  '(("qd-Demolition" "Phase" "Demolition" "mt-Demolition" "")
    ("qd-NotInContract" "Phase" "Not In Contract" "mt-NotInContract" "")
    ("qd-Existing" "Phase" "Existing" "mt-Existing" "")
    ("qd-Concrete" "Section" "Concrete" "mt-Concrete" "")
    ("qd-LightweightConcrete" "Section" "Lightweight Concrete" "mt-LightweightConcrete" "")
    ("qd-Mortar" "Section" "Mortar" "mt-Mortar" "")
    ("qd-Brick" "Section" "Brick" "mt-Brick" "")
    ("qd-Stone" "Section" "Stone" "mt-Stone" "")
    ("qd-CMU" "Section" "CMU" "mt-CMU" "")
    ("qd-Firebrick" "Section" "Firebrick" "mt-Firebrick" "")
    ("qd-Marble" "Section" "Marble" "mt-Marble" "")
    ("qd-Grout" "Section" "Grout" "mt-Grout" "")
    ("qd-Iron" "Section" "Iron" "mt-Iron" "")
    ("qd-Steel" "Section" "Steel" "mt-Steel" "")
    ("qd-Bronze" "Section" "Bronze" "mt-Bronze" "")
    ("qd-Lead" "Section" "Lead" "mt-Lead" "")
    ("qd-Aluminium" "Section" "Aluminium" "mt-Aluminium" "")
    ("qd-Plywood" "Section" "Plywood" "mt-Plywood" "")
    ("qd-WoodPlank" "Section" "Wood Plank" "mt-WoodPlank" "")
    ("qd-WoodFrame" "Section" "Wood Frame" "mt-WoodFrame" "")
    ("qd-Particleboard" "Section" "Particleboard" "mt-Particleboard" "")
    ("qd-Hardboard" "Section" "Hardboard" "mt-Hardboard" "")
    ("qd-Plastic" "Section" "Plastic" "mt-Plastic" "")
    ("qd-LooseInsulation" "Section" "Loose Insulation" "mt-LooseInsulation" "")
    ("qd-SprayInsulation" "Section" "Spray Insulation" "mt-SprayInsulation" "")
    ("qd-RigidInsulation" "Section" "Rigid Insulation" "mt-RigidInsulation" "")
    ("qd-Gypsum" "Section" "Gypsum" "mt-Gypsum" "")
    ("qd-Plaster" "Section" "Plaster" "mt-Plaster" "")
    ("qd-CompactedSoil" "Section" "Compacted Soil" "mt-CompactedSoil" "")
    ("qd-Topsoil" "Section" "Topsoil" "mt-Topsoil" "")
    ("qd-UndisturbedSoil" "Section" "Undisturbed Soil" "mt-UndisturbedSoil" "")
    ("qd-Sand" "Section" "Sand" "mt-Sand" "")
    ("qd-Asphalt" "Section" "Asphalt" "mt-Asphalt" "")
    ("qd-Gravel" "Section" "Gravel" "mt-Gravel" "")
    ("qd-CrushedStone" "Section" "Crushed Stone" "mt-CrushedStone" "")
   )
)

;;  Values of a row of the presets file: method of *qd:modes* or "" (the method of the
;;  material). The Width and Justify of a file written before they moved to the material
;;  are dropped:
(defun Dyl:QuickDrawFix (row)
  (while (< (length row) 5) (setq row (append row (list ""))))
  (Remote>>Dyl:ListSubst (list (nth 0 row) (nth 1 row) (nth 2 row) (nth 3 row) (nth 4 row))
                         4
                         (cond
                           ((car (vl-some '(lambda (x) (if (= (strcase (nth 4 row)) (strcase (car x))) x))
                                          *qd:modes*
                                 )
                            )
                           )
                           ("")
                         )
  )
)

;;  Read the presets file. Default presets missing from the file are added with their default values:
(defun Dyl:QuickDrawRead ()
  (Remote>>Dyl:PresetRead "QuickDraw" *qd:defaults* 'Dyl:QuickDrawFix)
)

;;  Return the preset id, with the values edited by the user:
(defun Dyl:QuickDrawGet (id)
  (Remote>>Dyl:PresetGet "QuickDraw" *qd:defaults* 'Dyl:QuickDrawFix id)
)

;;-------------------------=={ Dialog }==------------------------;;

;;  The preset dialog is made by Remote>>Dyl:PresetDialog (Remote\Dyl-Presets.lsp): its
;;  Parameters column has the Material popup (made by the engine, see (material . 3)), then
;;  the Draw with popup below.

;;  Tiles of Quick Draw and index of their value in a preset:
(setq *qd:tiles* '(("mth" . 4)))

;;  Popup tiles -> list of their values (nil for the other tiles):
(defun Dyl:QuickDrawDlgItems (key)
  (if (= "mth" key) (cons "" (mapcar 'car *qd:modes*)))
)

;;  Fill the Draw with popup (each time the dialog is shown):
(defun Dyl:QuickDrawDlgInit ()
  (start_list "mth")
  (foreach x (cons '("" "Method of the material") *qd:modes*) (add_list (cadr x)))
  (end_list)
)

;;  Method a preset r is drawn with: its own, else the one of its material (pst:mats, the
;;  materials of the preset dialog), "" when neither has one:
(defun Dyl:QuickDrawDlgMethod (r / m)
  (cond
    ((/= "" (nth 4 r)) (nth 4 r))
    ((and (setq m (assoc (nth 3 r) pst:mats)) (nth 33 m)))
    ("")
  )
)

;;  Text put in the new alias box: PL- for a preset drawn with a polyline, QD- for the others:
(defun Dyl:QuickDrawDlgPrefix (r)
  (if (= "Polyline" (Dyl:QuickDrawDlgMethod r)) "PL-" "QD-")
)

;;  Show the preset dialog. Draw and Save write the presets file and the aliases.
;;  Returns the preset to draw, or nil on Save / Cancel:
(defun Dyl:QuickDrawDialog ()
  (Remote>>Dyl:PresetDialog
    "QuickDraw"
    (list (cons 'defs *qd:defaults*)
          (cons 'fix 'Dyl:QuickDrawFix)
          (cons 'tiles *qd:tiles*)
          '(material . 3)
          ;;  The method of the material (its behaviors, Edit materials...), or another one:
          '(params "      : popup_list { key = \"mth\"; label = \"Draw with:\"; edit_width = 32; }")
          '(new "" "" "New preset" "mt-Brick" "")
          '(items . Dyl:QuickDrawDlgItems)
          '(init . Dyl:QuickDrawDlgInit)
          '(prefix . Dyl:QuickDrawDlgPrefix)
    )
  )
)

;;-------------------------=={ Commands }==------------------------;;

;; Quick Draw
;; Opens a dialog to edit, create and draw the quick draw presets.

(defun c:Dyl-QuickDraw (/ rec)
  (if (setq rec (Dyl:QuickDrawDialog)) (Dyl:QuickDrawRun rec))
  (princ)
)

;#region phase

;; Quick Draw Demolition
;; Draws a closed outline and fills it with the demolition phase hatch.

(defun c:Pst-QuickDrawDemolition () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Demolition")))

;; Quick Draw Not In Contract
;; Draws a closed outline and fills it with the not in contract phase hatch.

(defun c:Pst-QuickDrawNotInContract () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-NotInContract")))

;; Quick Draw Existing
;; Draws a closed outline and fills it with the existing phase background screen.

(defun c:Pst-QuickDrawExisting () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Existing")))
;#endregion
;#region section

;; Quick Draw Concrete
;; Draws a closed outline and fills it with the concrete section hatch.

(defun c:Pst-QuickDrawConcrete () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Concrete")))

;; Quick Draw Lightweight Concrete
;; Draws a closed outline and fills it with the lightweight concrete section hatch.

(defun c:Pst-QuickDrawLightweightConcrete () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-LightweightConcrete")))

;; Quick Draw Mortar
;; Draws a closed outline and fills it with the mortar section hatch.

(defun c:Pst-QuickDrawMortar () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Mortar")))

;; Quick Draw Brick
;; Draws a closed outline and fills it with the brick section hatch.

(defun c:Pst-QuickDrawBrick () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Brick")))

;; Quick Draw Stone
;; Draws a closed outline and fills it with the stone section hatch.

(defun c:Pst-QuickDrawStone () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Stone")))

;; Quick Draw CMU
;; Draws a closed outline and fills it with the concrete masonry unit section hatch.

(defun c:Pst-QuickDrawCMU () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-CMU")))

;; Quick Draw Firebrick
;; Draws a closed outline and fills it with the firebrick section hatch.

(defun c:Pst-QuickDrawFirebrick () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Firebrick")))

;; Quick Draw Marble
;; Draws a closed outline and fills it with the marble section hatch.

(defun c:Pst-QuickDrawMarble () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Marble")))

;; Quick Draw Grout
;; Draws a closed outline and fills it with the grout section hatch.

(defun c:Pst-QuickDrawGrout () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Grout")))

;; Quick Draw Iron
;; Draws a closed outline and fills it with the iron section hatch.

(defun c:Pst-QuickDrawIron () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Iron")))

;; Quick Draw Steel
;; Draws a closed outline and fills it with the steel section hatch.

(defun c:Pst-QuickDrawSteel () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Steel")))

;; Quick Draw Bronze
;; Draws a closed outline and fills it with the bronze section hatch.

(defun c:Pst-QuickDrawBronze () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Bronze")))

;; Quick Draw Lead
;; Draws a closed outline and fills it with the lead section hatch.

(defun c:Pst-QuickDrawLead () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Lead")))

;; Quick Draw Aluminium
;; Draws a closed outline and fills it with the aluminium section hatch.

(defun c:Pst-QuickDrawAluminium () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Aluminium")))

;; Quick Draw Plywood
;; Draws a closed outline and fills it with the plywood section hatch.

(defun c:Pst-QuickDrawPlywood () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Plywood")))

;; Quick Draw Wood Plank
;; Draws a closed outline and fills it with the wood plank section hatch.

(defun c:Pst-QuickDrawWoodPlank () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-WoodPlank")))

;; Quick Draw Wood Frame
;; Draws a closed outline and fills it with the wood framing section hatch.

(defun c:Pst-QuickDrawWoodFrame () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-WoodFrame")))

;; Quick Draw Particleboard
;; Draws a closed outline and fills it with the particleboard section hatch.

(defun c:Pst-QuickDrawParticleboard () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Particleboard")))

;; Quick Draw Hardboard
;; Draws a closed outline and fills it with the hardboard section hatch.

(defun c:Pst-QuickDrawHardboard () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Hardboard")))

;; Quick Draw Plastic
;; Draws a closed outline and fills it with the plastic section hatch.

(defun c:Pst-QuickDrawPlastic () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Plastic")))

;; Quick Draw Loose Insulation
;; Draws a closed outline and fills it with the loose fill insulation section hatch.

(defun c:Pst-QuickDrawLooseInsulation () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-LooseInsulation")))

;; Quick Draw Spray Insulation
;; Draws a closed outline and fills it with the spray foam insulation section hatch.

(defun c:Pst-QuickDrawSprayInsulation () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-SprayInsulation")))

;; Quick Draw Rigid Insulation
;; Draws a closed outline and fills it with the rigid insulation section hatch.

(defun c:Pst-QuickDrawRigidInsulation () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-RigidInsulation")))

;; Quick Draw Gypsum
;; Draws a closed outline and fills it with the gypsum board section hatch.

(defun c:Pst-QuickDrawGypsum () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Gypsum")))

;; Quick Draw Plaster
;; Draws a closed outline and fills it with the plaster section hatch.

(defun c:Pst-QuickDrawPlaster () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Plaster")))

;; Quick Draw Compacted Soil
;; Draws a closed outline and fills it with the compacted soil section hatch.

(defun c:Pst-QuickDrawCompactedSoil () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-CompactedSoil")))

;; Quick Draw Topsoil
;; Draws a closed outline and fills it with the topsoil section hatch.

(defun c:Pst-QuickDrawTopsoil () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Topsoil")))

;; Quick Draw Undisturbed Soil
;; Draws a closed outline and fills it with the undisturbed soil section hatch.

(defun c:Pst-QuickDrawUndisturbedSoil () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-UndisturbedSoil")))

;; Quick Draw Sand
;; Draws a closed outline and fills it with the sand section hatch.

(defun c:Pst-QuickDrawSand () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Sand")))

;; Quick Draw Asphalt
;; Draws a closed outline and fills it with the asphalt section hatch.

(defun c:Pst-QuickDrawAsphalt () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Asphalt")))

;; Quick Draw Gravel
;; Draws a closed outline and fills it with the gravel section hatch.

(defun c:Pst-QuickDrawGravel () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-Gravel")))

;; Quick Draw Crushed Stone
;; Draws a closed outline and fills it with the crushed stone section hatch.

(defun c:Pst-QuickDrawCrushedStone () (Dyl:QuickDrawRun (Dyl:QuickDrawGet "qd-CrushedStone")))
;#endregion
