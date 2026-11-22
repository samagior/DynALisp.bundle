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
;;  (*mt:methods* in Remote\Dyl-Materials.lsp). The method is a behavior of the preset
;;  (Material behaviors box of the Quick Draw window), with the width and justification of
;;  Linear and the sides of Polygon (see Dyl:QuickDrawRun). No method: asked when drawn:
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
    ;;  One gap, in drawing units (the metric gap of an older file: see Remote>>Dyl:MaterialFix):
    ((and (setq v (distof (cond ((nth 43 mat)) ("")) 2)) (<= 0 v)) v)
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

;;  Show the line pts and the border of its band while it is drawn (temporary vectors), with
;;  its ends, corners and joints (an assembly: the joins of its layers and its Line layers):
(defun Dyl:QuickDrawPreview (pts w jus / pp opt)
  (redraw)
  (if (cdr pts)
    (progn
      (setq pp  (mapcar 'Dyl:QuickDraw2d pts)
            opt (cond (qd:opt) ((Dyl:QuickDrawBandDefaults)))
      )
      (mapcar '(lambda (a b) (grdraw a b -1 1)) pp (cdr pp))
      (Dyl:QuickDrawGrBand pp nil w jus opt)
    )
  )
)

;;  Preview of the band of the line pp (closed: the last point joins the first), width w,
;;  justification jus (Center, Left, Right), options opt: its border and its joints when
;;  they are drawn; an assembly (qd:layers), the joins of its layers and its Line layers too:
(defun Dyl:QuickDrawGrBand (pp closed w jus opt / g)
  (if qd:layers
    (progn
      (setq g (car (Dyl:QuickDrawLayersBand pp closed jus opt)))
      (foreach b (append (cadr g) (cadddr g)) (Dyl:QdGrPath (car b) (cadr b)))
      (foreach j (caddr g) (grdraw (car j) (cadr j) -1 0))
    )
    (Dyl:QdGrBand (Dyl:QdBand pp closed w jus opt) opt)
  )
)

;;  The side of the band picked last with Edge ("Left": the line is its left border, the band
;;  on its right; "Right": the other way), the band on the left of the line by default:
(defun Dyl:QuickDrawLastSide ()
  (if (member (getenv "DynalispQuickDrawSide") '("Left" "Right")) (getenv "DynalispQuickDrawSide") "Right")
)

;;  Edge: the side of the band of the line pp (2D UCS points) drawn by Linear, width w, picked
;;  as Offset does: the band is previewed on the side of the cursor while it moves (see
;;  Dyl:QuickDrawSidePreview); a click picks that side, Enter, Space or a right click the side
;;  of the cursor, C (Center) centers the band on the line. Returns the justification of the
;;  band: "Left" or "Right" (see Dyl:QuickDrawSideJus), "Center"; the side is remembered:
(defun Dyl:QuickDrawAskSidePts (pp w / g pos res done)
  (princ "\nSide of the band: pick a point on its side or [Center] <side of the cursor>: ")
  (Dyl:QuickDrawPreview pp w (Dyl:QuickDrawLastSide))
  (while (not done)
    (setq g (grread t 15 0))
    (cond
      ((= 5 (car g)) (setq pos (cadr g)) (Dyl:QuickDrawSidePreview nil (list pp nil) nil w pos))
      ((= 3 (car g)) (setq res (Dyl:QuickDrawSideJus pp nil (cadr g)) done t))
      ((and (= 2 (car g)) (member (cadr g) '(67 99))) (setq res "Center" done t))
      ((or (and (= 2 (car g)) (member (cadr g) '(13 32))) (member (car g) '(11 25)))
       (setq res  (if pos (Dyl:QuickDrawSideJus pp nil pos) (Dyl:QuickDrawLastSide))
             done t
       )
      )
    )
  )
  (redraw)
  (if (/= "Center" res) (setenv "DynalispQuickDrawSide" res))
  res
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
;;  them; an assembly: the width of its layers; jus "Ask": asked first, the last one given by
;;  default), both can be changed at the first prompt for this band only. Center: the line
;;  is the center of the band; Edge: one of its borders, the band on the side picked once
;;  the line is drawn, as Offset (see Dyl:QuickDrawAskSidePts), shown meanwhile on the side
;;  picked last. off and aln: the offsets of the hatch origin across the line and along it,
;;  from the start of each segment; sf: the width factor when the hatch scale is the width x
;;  sf (the offsets are then in pattern units, multiplied by that scale, so they follow the
;;  width), else nil.
;;  Returns ((outline angle origin) ...): one closed outline per segment, the angle of the
;;  segment in degrees and the hatch origin on the line (WCS), nil when no line was drawn.
;;  Sets qd:width (local of Dyl:QuickDraw) to the width drawn:
(defun Dyl:QuickDrawLinear (wid jus off aln sf / w wj p q pts)
  ;;  An assembly: the width of its layers (see Dyl:QuickDrawLayersGet):
  (setq wj  (Dyl:QuickDrawWidthJus (if qd:layers (rtos (Dyl:QuickDrawLayersWidth qd:layers) 2 8) wid) jus)
        w   (car wj)
        jus (cadr wj)
  )
  ;;  Start point, or a width / justification / ends / corners for this band (an assembly:
  ;;  its layers flipped in place of the width):
  (if (not qd:opt) (setq qd:opt (Dyl:QuickDrawBandDefaults)))
  (while (and w (not p))
    (initget (if qd:layers "Justification Flip Ends Corners" "Width Justification Ends Corners"))
    (setq p (getpoint (strcat (if qd:layers
                                "\nStart point or [Justification/Flip/Ends/Corners] <assembly "
                                "\nStart point or [Width/Justification/Ends/Corners] <width "
                              )
                              (rtos w)
                              ", "
                              jus
                              ", "
                              (car qd:opt)
                              ", "
                              (nth 3 qd:opt)
                              ">: "
                      )
            )
    )
    (cond
      ((= "Ends" p) (Dyl:QuickDrawAskEnds) (setq p nil))
      ((= "Corners" p) (Dyl:QuickDrawAskCorners) (setq p nil))
      ((= "Flip" p)
       (setq qd:layers (reverse qd:layers)
             p         nil
       )
       (princ (strcat "\nLayers flipped: " (Dyl:QuickDrawLayerName (car qd:layers)) " first."))
      )
      ((= "Width" p)
       (initget 6)
       (if (setq q (getdist (strcat "\nWidth <" (rtos w) ">: ")))
         (progn (setq w q) (setenv "DynalispQuickDrawWidth" (rtos w 2 8)))
       )
       (setq p nil)
      )
      ((= "Justification" p)
       (setq jus (Dyl:QuickDrawAskJus jus))
       (setq p nil)
      )
      ((null p) (setq w nil))
    )
  )
  ;;  The points of the line, shown with the band while they are picked (Edge: on the side
  ;;  picked last):
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
        (Dyl:QuickDrawPreview pts w (if (= "Edge" jus) (Dyl:QuickDrawLastSide) jus))
      )
      (redraw)
    )
  )
  ;;  Edge: the side of the band, picked now:
  (if (and (= "Edge" jus) (cdr pts)) (setq jus (Dyl:QuickDrawAskSidePts (mapcar 'Dyl:QuickDraw2d pts) w)))
  ;;  One closed outline per segment (see Dyl:QuickDrawSegs):
  (setq qd:width w)
  (if (and sf w)
    (setq off (* off w sf)
          aln (* aln w sf)
    )
  )
  (if (cdr pts)
    (Dyl:QuickDrawSegs (mapcar 'Dyl:QuickDraw2d pts) nil w jus off aln (cond ((caddr (car pts))) (0.0)))
  )
)

;;  The justifications the line of the band can be given when it is drawn: Center, Edge, and
;;  Structural for an assembly with a structural layer (qd:layers, see Dyl:QuickDrawLayersCore):
(defun Dyl:QuickDrawJusKeys ()
  (append '("Center" "Edge") (if (Dyl:QuickDrawLayersCore qd:layers) '("Structural")))
)

;;  Ask the justification of the band, jus by default (see Dyl:QuickDrawJusKeys):
(defun Dyl:QuickDrawAskJus (jus / ks q)
  (setq ks (Dyl:QuickDrawJusKeys))
  (if (not (member jus ks)) (setq jus "Center"))
  (initget (Remote>>LM:lst->str ks " "))
  (if (setq q (getkword (strcat "\nLine on the [" (Remote>>LM:lst->str ks "/") "] <" jus ">: "))) q jus)
)

;;  The line of an assembly on its structural layer (Structural layer, see *mt:justify*): the
;;  distance from the line to the left border of the band of the layers lay (see
;;  Dyl:QuickDrawLayersGet), the line in the middle of the structural layer; nil without one:
(defun Dyl:QuickDrawLayersCore (lay / d res)
  (setq d 0.0)
  (foreach l lay
    (if (and (not res) (= "P" (car l)) (nth 8 l)) (setq res (+ d (/ (cadr l) 2.0))))
    (setq d (+ d (cadr l)))
  )
  res
)

;;  The width and the justification of a band (Linear, Offset): the width wid and the
;;  justification jus of the material (wid "": the last width used, asked when there is none;
;;  several widths divided by commas: asked among them; jus "Ask": asked, the last one given
;;  by default; Left and Right of an older preset: Edge). Returns (width justify), width nil
;;  when none was given:
(defun Dyl:QuickDrawWidthJus (wid jus / ws w q)
  (setq ws (Remote>>Dyl:MaterialWidths wid)
        w  (cond
             ((cdr ws) (Dyl:QuickDrawAskWidth ws))
             ((car ws))
             ((distof (cond ((getenv "DynalispQuickDrawWidth")) ("")) 2))
           )
  )
  (if (cdr ws) (setenv "DynalispQuickDrawWidth" (rtos w 2 8)))
  (if (member jus '("Left" "Right")) (setq jus "Edge"))
  (if (not (assoc jus *qd:justify*)) (setq jus "Center"))
  ;;  Structural layer: an assembly with one only (else Center, said):
  (if (and (= "Structural" jus) (not (Dyl:QuickDrawLayersCore qd:layers)))
    (progn (princ "\n--> No structural layer in this assembly: the line is on its center.") (setq jus "Center"))
  )
  ;;  Ask when drawn: the last justification given by default (saved with setenv):
  (if (= "Ask" jus)
    (progn
      (setq jus (getenv "DynalispQuickDrawJustify"))
      (if (not (member jus (Dyl:QuickDrawJusKeys))) (setq jus "Center"))
      (setq jus (Dyl:QuickDrawAskJus jus))
      (setenv "DynalispQuickDrawJustify" jus)
    )
  )
  (if (not w)
    (progn
      (initget 6)
      (if (setq w (getdist "\nWidth of the band: ")) (setenv "DynalispQuickDrawWidth" (rtos w 2 8)))
    )
  )
  (list w jus)
)

;;  The outlines of the band of the line pp (2D UCS points; closed: the last point joins the
;;  first), width w, justification jus, the hatch origin moved by off across the line and aln
;;  along it, at the elevation z: those of the assembly qd:layers when it has one (see
;;  Dyl:QuickDrawLayersSegs), else of one band (see Dyl:QuickDrawBandSegs):
(defun Dyl:QuickDrawSegs (pp closed w jus off aln z)
  (if qd:layers
    (Dyl:QuickDrawLayersSegs pp closed jus z)
    (Dyl:QuickDrawBandSegs pp closed w jus off aln z)
  )
)

;;  One band: ((outlines angle origin temp fixed) ...), an outline per segment (or the
;;  outline of the whole band, see below); temp: hatched as without border (its border made
;;  apart, see Dyl:QuickDrawBorderMake), fixed: from the drawing origin:
(defun Dyl:QuickDrawBandSegs (pp closed w jus off aln z / opt g opn sep line apart d res)
  (setq opt   (cond (qd:opt) ((Dyl:QuickDrawBandDefaults)))
        g     (Dyl:QdBand pp closed w jus opt)
        opn   (and (not closed) (= "Open" (car opt)))
        sep   (= "Interrupted" (nth 6 opt))
        line  (= "Line" (nth 7 opt))
        ;;  The border drawn apart from the outlines hatched: the ends open, or one border
        ;;  around hatches that each follow their segment:
        apart (or opn (and (not sep) line))
        d     (* (if (= "Left" jus) -1.0 1.0) off)
  )
  (setq res
         (if (or sep line)
           ;;  An outline per segment: its angle and its origin on the line (following the
           ;;  line), else the angle of the material and the drawing origin:
           (mapcar
             '(lambda (pc / a b u)
                (setq a (nth (cadr pc) pp)
                      b (nth (rem (1+ (cadr pc)) (length pp)) pp)
                      u (Dyl:QuickDrawUnit (Dyl:QdSub b a))
                )
                (list (Dyl:QdPline (car pc) T z)
                      (if line (/ (* 180.0 (angle a b)) pi) 0.0)
                      (if line
                        (trans (list (+ (car a) (* aln (car u)) (- (* d (cadr u))))
                                     (+ (cadr a) (* aln (cadr u)) (* d (car u)))
                                     z
                               )
                               1
                               0
                        )
                        '(0.0 0.0 0.0)
                      )
                      apart
                      (not line)
                )
              )
             (car g)
           )
           ;;  Uninterrupted from the drawing origin: one outline for the whole band (two
           ;;  around a closed line), the angle of the material:
           (list (list (mapcar '(lambda (x) (Dyl:QdPline x T z)) (cadr g)) 0.0 '(0.0 0.0 0.0) apart T))
         )
  )
  ;;  The border drawn apart, after the hatches (see Dyl:QuickDrawBorderMake): the border of
  ;;  the band, and its joints when they are drawn:
  (if apart
    (setq qd:borders (append qd:borders
                             (mapcar '(lambda (x) (list (car x) (cadr x) z)) (caddr g))
                             (if sep
                               (mapcar '(lambda (j) (list (list (cons (car j) 0.0) (cons (cadr j) 0.0)) nil z)) (cadddr g))
                             )
                     )
    )
  )
  res
)

;;-------------------------=={ Ends and corners }==------------------------;;

;;  The bands of Linear and Offset end as the preset says (see *mt:ends*), turn their corners
;;  (*mt:corners*), draw their joints or not (*mt:joints*), and hatch each segment along it or
;;  the whole band from the drawing origin (*mt:hatchmodes*). The options of a band (qd:opt,
;;  local of Dyl:QuickDraw): (ends extension end-angle corners miter-limit lap joints hatch),
;;  see Dyl:QuickDrawBandOpts. A path is a list of (point . bulge): 2D UCS points, each with
;;  the bulge of the arc to the next point (0.0: a straight line).

;;  2D vectors:
(defun Dyl:QdAdd (a b) (list (+ (car a) (car b)) (+ (cadr a) (cadr b))))
(defun Dyl:QdSub (a b) (list (- (car a) (car b)) (- (cadr a) (cadr b))))
(defun Dyl:QdMul (a s) (list (* (car a) s) (* (cadr a) s)))
(defun Dyl:QdCross (a b) (- (* (car a) (cadr b)) (* (cadr a) (car b))))
(defun Dyl:QdDot (a b) (+ (* (car a) (car b)) (* (cadr a) (cadr b))))
(defun Dyl:QdLeft (u) (list (- (cadr u)) (car u)))

;;  Intersection of the line through a along u and the line through b along v (nil: parallel):
(defun Dyl:QdInters (a u b v)
  (inters a (Dyl:QdAdd a u) b (Dyl:QdAdd b v) nil)
)

;;  Bulge of the arc from a to b around the center c, the shorter way (0.0 when a or b is c):
(defun Dyl:QdBulge (a b c / x y g)
  (setq x (Dyl:QdSub a c)
        y (Dyl:QdSub b c)
  )
  (if (and (< 1e-12 (distance '(0.0 0.0) x)) (< 1e-12 (distance '(0.0 0.0) y)))
    (progn
      (setq g (/ (atan (Dyl:QdCross x y) (Dyl:QdDot x y)) 4.0))
      (/ (sin g) (cos g))
    )
    0.0
  )
)

;;  Bulge of the half circle from a to b that passes on the side of the point q:
(defun Dyl:QdHalf (a b q)
  (if (< (Dyl:QdCross (Dyl:QdSub b a) (Dyl:QdSub q a)) 0.0) 1.0 -1.0)
)

;;  The path p the other way: each arc keeps its bulge, of the other sign, on the point it
;;  now starts from; the last point gets 0.0:
(defun Dyl:QdReverse (p / res prev)
  (setq prev 0.0)
  (foreach x p
    (setq res  (cons (cons (car x) (- prev)) res)
          prev (cdr x)
    )
  )
  res
)

;;  The default options of a band (as before they could be set): square ends, mitered
;;  corners (limit 4), joints drawn, the hatch following the line:
(defun Dyl:QuickDrawBandDefaults ()
  (list "Square" nil (/ pi 4.0) "Mitered" 4.0 "First" "Interrupted" "Line")
)

;;  Ask a key of the list lst (*mt:ends*, *mt:corners*, without Ask) for a band, the last one
;;  given by default (the user setting env, else def):
(defun Dyl:QuickDrawAskKey (msg lst env def / k)
  (if (assoc (getenv env) lst) (setq def (getenv env)))
  (initget (Remote>>LM:lst->str (mapcar 'car lst) " "))
  (if (setq k (getkword (strcat "\n" msg " [" (Remote>>LM:lst->str (mapcar 'car lst) "/") "] <" def ">: ")))
    (setq def k)
  )
  (setenv env def)
  def
)

;;  The options of a band from the material mat (its behavior columns, see *mt:ends*): its
;;  ends and corners asked now when they are Ask when drawn; the extension nil for half the
;;  width, the end angle in radians:
(defun Dyl:QuickDrawBandOpts (mat / e c eo co)
  ;;  Their own ends (61) and corners (62) when they are checked, else the defaults (the
  ;;  ends and corners of the material kept for when they are checked again):
  (setq eo (= "1" (nth 61 mat))
        co (= "1" (nth 62 mat))
        e  (if eo (cond ((nth 51 mat)) ("Square")) "Square")
        c  (if co (cond ((nth 54 mat)) ("Mitered")) "Mitered")
  )
  (if (= "Ask" e) (setq e (Dyl:QuickDrawAskKey "Ends" (cdr *mt:ends*) "DynalispQuickDrawEnds" "Square")))
  (if (= "Ask" c) (setq c (Dyl:QuickDrawAskKey "Corners" (cdr *mt:corners*) "DynalispQuickDrawCorners" "Mitered")))
  (list e
        (if eo (distof (cond ((nth 52 mat)) ("")) 2))
        (* pi (/ (cond ((and eo (distof (cond ((nth 53 mat)) ("")) 2))) (45.0)) 180.0))
        c
        (cond ((and co (distof (cond ((nth 55 mat)) ("")) 2))) (4.0))
        (cond ((and co (nth 56 mat))) ("First"))
        (cond ((and co (nth 57 mat))) ("Interrupted"))
        (cond ((nth 58 mat)) ("Line"))
  )
)

;;  Ends option of the prompts of Linear and Offset: the ends of the next bands (qd:opt), with
;;  the extension of Extended and the angle of Angled:
(defun Dyl:QuickDrawAskEnds (/ k v)
  (initget "Square Open Extended Round Angled")
  (if (setq k (getkword (strcat "\nEnds [Square/Open/Extended/Round/Angled] <" (car qd:opt) ">: ")))
    (setq qd:opt (Remote>>Dyl:ListSubst qd:opt 0 k))
  )
  (cond
    ((= "Extended" (car qd:opt))
     (initget 4)
     (if (setq v (getdist (strcat "\nExtension <" (if (cadr qd:opt) (rtos (cadr qd:opt)) "half the width") ">: ")))
       (setq qd:opt (Remote>>Dyl:ListSubst qd:opt 1 v))
     )
    )
    ((= "Angled" (car qd:opt))
     (if (and (setq v (getreal (strcat "\nEnd angle, -80 to 80 <" (rtos (/ (* 180.0 (caddr qd:opt)) pi) 2 2) ">: ")))
              (<= -80.0 v 80.0)
         )
       (setq qd:opt (Remote>>Dyl:ListSubst qd:opt 2 (* pi (/ v 180.0))))
     )
    )
  )
)

;;  Corners option of the prompts of Linear and Offset: the corners, joints or hatch of the
;;  next bands (qd:opt):
(defun Dyl:QuickDrawAskCorners (/ k)
  (initget "Mitered Beveled Round Lapped Joints Hatch")
  (setq k (getkword (strcat "\nCorners [Mitered/Beveled/Round/Lapped/Joints/Hatch] <" (nth 3 qd:opt) ">: ")))
  (cond
    ((= "Joints" k)
     (initget "Interrupted Uninterrupted")
     (if (setq k (getkword (strcat "\nJoints [Interrupted/Uninterrupted] <" (nth 6 qd:opt) ">: ")))
       (setq qd:opt (Remote>>Dyl:ListSubst qd:opt 6 k))
     )
    )
    ((= "Hatch" k)
     (initget "Line Origin")
     (if (setq k (getkword (strcat "\nHatch following the line or from the drawing origin [Line/Origin] <" (nth 7 qd:opt) ">: ")))
       (setq qd:opt (Remote>>Dyl:ListSubst qd:opt 7 k))
     )
    )
    (k (setq qd:opt (Remote>>Dyl:ListSubst qd:opt 3 k)))
  )
)

;;  The point where the borders at d from the line (positive: on its left) of the segment of
;;  direction ui and of the next one of direction uj meet, at the corner p (the border of the
;;  first segment when they are parallel):
(defun Dyl:QdMiter (p ui uj d / a)
  (setq a (Dyl:QdAdd p (Dyl:QdMul (Dyl:QdLeft ui) d)))
  (cond ((Dyl:QdInters a ui (Dyl:QdAdd p (Dyl:QdMul (Dyl:QdLeft uj) d)) uj)) (a))
)

;;  How the band turns at the corner p, from the segment of direction ui to the next one of
;;  direction uj, its borders at dl and dr (the whole band, see Dyl:QuickDrawSides), width w,
;;  options opt: the corners of opt, Mitered beveled when its miter is longer than the limit
;;  (x the width, from the inner corner); nil when the band goes straight on. The same for
;;  every layer of an assembly, so their corners meet:
(defun Dyl:QdTrim (p ui uj dl dr w opt / turn trim)
  (setq turn (Dyl:QdCross ui uj))
  (if (< 1e-9 (abs turn))
    (progn
      (setq trim (nth 3 opt))
      (if (and (= "Mitered" trim)
               (< (* w (nth 4 opt))
                  (distance (Dyl:QdMiter p ui uj (if (< 0.0 turn) dl dr)) (Dyl:QdMiter p ui uj (if (< 0.0 turn) dr dl)))
               )
          )
        (setq trim "Beveled")
      )
      trim
    )
  )
)

;;  The border at d from the line at the corner p (from the segment of direction ui to the
;;  next one of direction uj), the corners trim (see Dyl:QdTrim). Returns (end start whole
;;  split): the end of that border on the first segment and its start on the next one (paths
;;  along the line), the border of the whole band through the corner (a path), and the point
;;  of it where the outlines of the two segments meet. On the inner side of the turn, with
;;  Mitered and Lapped and when the band goes straight on: the miter point. On the outer side,
;;  Beveled: a line across the corner, Round: an arc around p, both split in their middle:
(defun Dyl:QdBorderAt (p ui uj d trim / ni nj oi oj s m)
  (setq ni (Dyl:QdLeft ui)
        nj (Dyl:QdLeft uj)
  )
  (if (and (member trim '("Beveled" "Round"))
           (< 1e-9 (abs d))
           ;;  The outer side: on the right of a turn to the left, or the other way:
           (if (< 0.0 (Dyl:QdCross ui uj)) (< d 0.0) (< 0.0 d))
      )
    (progn
      (setq oi (Dyl:QdAdd p (Dyl:QdMul ni d))
            oj (Dyl:QdAdd p (Dyl:QdMul nj d))
            s  (if (= "Round" trim)
                 ;;  The middle of the arc, on the side of d:
                 (Dyl:QdAdd p (Dyl:QdMul (Dyl:QuickDrawUnit (Dyl:QdAdd ni nj)) d))
                 (Dyl:QdMul (Dyl:QdAdd oi oj) 0.5)
               )
      )
      (if (= "Round" trim)
        (list (list (cons oi (Dyl:QdBulge oi s p)) (cons s 0.0))
              (list (cons s (Dyl:QdBulge s oj p)) (cons oj 0.0))
              (list (cons oi (Dyl:QdBulge oi oj p)) (cons oj 0.0))
              s
        )
        (list (list (cons oi 0.0) (cons s 0.0))
              (list (cons s 0.0) (cons oj 0.0))
              (list (cons oi 0.0) (cons oj 0.0))
              s
        )
      )
    )
    (progn
      (setq m (Dyl:QdMiter p ui uj d))
      (list (list (cons m 0.0)) (list (cons m 0.0)) (list (cons m 0.0)) m)
    )
  )
)

;;  The corner of a band (or of a layer of an assembly) at the point p of its line, between
;;  the segment of direction ui and the next one of direction uj, its borders at dl and dr
;;  from the line, the corners trim of the whole band (see Dyl:QdTrim), options opt. Returns
;;  (end start left right joint): the end of the outline of the first segment (a path from
;;  its left border to its right one), the start of the outline of the next one (from its
;;  right border to its left one), the left and the right borders at the corner (paths along
;;  the line), and the joint of the two outlines (two points, drawn with Interrupted joints):
(defun Dyl:QdCorner (p ui uj dl dr trim opt / ni nj lft din dout ai aj oi oj c m k io jo l r)
  (setq ni (Dyl:QdLeft ui)
        nj (Dyl:QdLeft uj)
  )
  (cond
    ;;  Straight on: the outlines meet square across the line:
    ((not trim)
     ((lambda (a b)
        (list (list (cons a 0.0) (cons b 0.0)) (list (cons b 0.0) (cons a 0.0)) (list (cons a 0.0)) (list (cons b 0.0)) (list a b))
      )
       (Dyl:QdAdd p (Dyl:QdMul ni dl))
       (Dyl:QdAdd p (Dyl:QdMul ni dr))
     )
    )
    ;;  Lapped: the segment that runs through goes to the outer border of the other one, the
    ;;  other one stops at its inner border; k: where they meet on the outer side. Turning
    ;;  left, the inner side is the left border (the other way turning right):
    ((= "Lapped" trim)
     (setq lft  (< 0.0 (Dyl:QdCross ui uj))
           din  (if lft dl dr)
           dout (if lft dr dl)
           ai   (Dyl:QdAdd p (Dyl:QdMul ni din))
           aj   (Dyl:QdAdd p (Dyl:QdMul nj din))
           oi   (Dyl:QdAdd p (Dyl:QdMul ni dout))
           oj   (Dyl:QdAdd p (Dyl:QdMul nj dout))
           c    (Dyl:QdMiter p ui uj din)
           m    (Dyl:QdMiter p ui uj dout)
     )
     (if (= "First" (nth 5 opt))
       (setq k  (cond ((Dyl:QdInters ai ui oj uj)) (c))
             io (list (cons k 0.0) (cons m 0.0))
             jo (list (cons k 0.0) (cons c 0.0))
       )
       (setq k  (cond ((Dyl:QdInters oi ui aj uj)) (c))
             io (list (cons c 0.0) (cons k 0.0))
             jo (list (cons m 0.0) (cons k 0.0))
       )
     )
     (list (if lft io (Dyl:QdReverse io))
           (if lft jo (Dyl:QdReverse jo))
           (list (cons (if lft c m) 0.0))
           (list (cons (if lft m c) 0.0))
           (list c k)
     )
    )
    ;;  Mitered, Beveled, Round: each border as Dyl:QdBorderAt makes it, the outlines meet
    ;;  on the line from the split of the left border to that of the right one:
    (T
     (setq l (Dyl:QdBorderAt p ui uj dl trim)
           r (Dyl:QdBorderAt p ui uj dr trim)
     )
     (list (append (car l) (Dyl:QdReverse (car r)))
           (append (Dyl:QdReverse (cadr r)) (cadr l))
           (caddr l)
           (caddr r)
           (list (cadddr l) (cadddr r))
     )
    )
  )
)

;;  Bulge of the arc from a to b around the center c that passes on the side of the point q
;;  when it is a half circle (else the shorter way):
(defun Dyl:QdArc (a b c q / x y)
  (setq x (Dyl:QdSub a c)
        y (Dyl:QdSub b c)
  )
  (if (and (< (abs (Dyl:QdCross x y)) (* 1e-9 (max 1.0 (Dyl:QdDot x x)))) (< (Dyl:QdDot x y) 0.0))
    (Dyl:QdHalf a b q)
    (Dyl:QdBulge a b c)
  )
)

;;  The point at d from the line (positive: on its left) of the end of a band at the point a
;;  of its line, its segment of direction u, the borders of the whole band at (dl dr) bd,
;;  width w, options opt. start T: the start of the band, else its end. Square and Open:
;;  across at a; Extended: moved out along the line (by half the width when the extension
;;  is empty); Angled: turned around a (a layer: around its own line); Round: on the half circle across the whole band:
(defun Dyl:QdEndPt (a u d bd w opt start / k e dc)
  (setq k (car opt)
        e 0.0
  )
  (cond
    ((= "Extended" k) (setq e (cond ((cadr opt)) ((/ w 2.0)))))
    ;;  Around the line (a layer of an assembly: its own line, nth 8 of opt):
    ((= "Angled" k) (setq e (* (- d (cond ((nth 8 opt)) (0.0))) (/ (sin (caddr opt)) (cos (caddr opt))))))
    ((= "Round" k)
     (setq dc (/ (+ (car bd) (cadr bd)) 2.0)
           e  (sqrt (max 0.0 (- (* w w 0.25) (* (- d dc) (- d dc)))))
     )
    )
  )
  ;;  Out of the band: back along the line at its start (Angled: the same way at both ends):
  (if (and start (/= "Angled" k)) (setq e (- e)))
  (Dyl:QdAdd (Dyl:QdAdd a (Dyl:QdMul (Dyl:QdLeft u) d)) (Dyl:QdMul u e))
)

;;  The end of a band (or of a layer of an assembly) at the point a of its line, its segment
;;  of direction u, its borders at dl and dr, the borders of the whole band bd, width w (of
;;  the whole band), options opt (see Dyl:QdEndPt). start T: the start of the band, a path
;;  from its right border to its left one; else its end, from its left border to its right
;;  one. Round: its part of the half circle across the whole band, outward (a layer inside
;;  the band reaches it along its borders):
(defun Dyl:QdEnd (a u dl dr bd w opt start / n l r ql qr c)
  (setq n (Dyl:QdLeft u)
        l (Dyl:QdEndPt a u dl bd w opt start)
        r (Dyl:QdEndPt a u dr bd w opt start)
  )
  (if (= "Round" (car opt))
    (setq ql (Dyl:QdAdd a (Dyl:QdMul n dl))
          qr (Dyl:QdAdd a (Dyl:QdMul n dr))
          c  (Dyl:QdAdd a (Dyl:QdMul n (/ (+ (car bd) (cadr bd)) 2.0)))
    )
  )
  (cond
    ((/= "Round" (car opt)) (if start (list (cons r 0.0) (cons l 0.0)) (list (cons l 0.0) (cons r 0.0))))
    (start
     (list (cons qr 0.0) (cons r (Dyl:QdArc r l c (Dyl:QdAdd c (Dyl:QdMul u (- w))))) (cons l 0.0) (cons ql 0.0))
    )
    ((list (cons ql 0.0) (cons l (Dyl:QdArc l r c (Dyl:QdAdd c (Dyl:QdMul u w)))) (cons r 0.0) (cons qr 0.0)))
  )
)

;;  The path p without its repeated points (each keeps the bulge of the last one):
(defun Dyl:QdClean (p / res)
  (foreach x p
    (if (and res (< (distance (car x) (car (car res))) 1e-9))
      (setq res (cons (cons (car (car res)) (cdr x)) (cdr res)))
      (setq res (cons x res))
    )
  )
  (reverse res)
)

;;  The band of the line pp (2D UCS points; closed: the last point joins the first) between
;;  its borders at dl and dr from the line (a layer of an assembly, or the whole band): us,
;;  the direction of each segment; trims, how the band turns at each corner (see
;;  Dyl:QdTrim); bd, the borders of the whole band (dl dr), w its width; options opt. Returns
;;  (pieces unions borders joints): pieces, the outline of each segment ((path index) ...);
;;  unions, the outline of the whole band (one path; two around a closed line, the inner one
;;  an island of the hatch); borders, its border once drawn ((path closed) ...: the union, its
;;  two sides apart when the ends are Open); joints, the joint at each corner ((a b) ...); sides,
;;  the pieces of its border (left right start end): its left and right sides along the line
;;  (paths from its start to its end; around a closed line, loops), the paths across its start
;;  and its end (nil around a closed line), see Dyl:QdLayersBorders:
(defun Dyl:QdBandOne (pp closed us trims dl dr bd w opt / np n i cors sc ec pcs st en lf rt un brd)
  (setq np (length pp)
        n  (length us)
        i  0
  )
  ;;  A corner at the end of each segment, but the last one of an open line:
  (foreach tr trims
    (setq cors (cons (Dyl:QdCorner (nth (rem (1+ i) np) pp) (nth i us) (nth (rem (1+ i) n) us) dl dr tr opt) cors)
          i    (1+ i)
    )
  )
  (setq cors (reverse cors)
        i    0
  )
  (if (not closed)
    (setq sc (Dyl:QdClean (Dyl:QdEnd (car pp) (car us) dl dr bd w opt T))
          ec (Dyl:QdClean (Dyl:QdEnd (last pp) (last us) dl dr bd w opt nil))
    )
  )
  ;;  The outline of each segment: its start, then its end:
  (repeat n
    (setq st  (if (and (not closed) (= i 0)) sc (cadr (nth (rem (+ i n -1) n) cors)))
          en  (if (and (not closed) (= i (1- n))) ec (car (nth i cors)))
          pcs (cons (list (append st en) i) pcs)
          i   (1+ i)
    )
  )
  ;;  The borders along the line:
  (setq lf (apply 'append (mapcar 'caddr cors))
        rt (apply 'append (mapcar 'cadddr cors))
  )
  (if closed
    (setq un  (list lf (Dyl:QdReverse rt))
          brd (list (list lf T) (list rt T))
    )
    ;;  Open: the start, the left border, the end, back along the right border:
    (setq un  (list (append sc lf ec (Dyl:QdReverse rt)))
          brd (if (= "Open" (car opt))
                (list (list (append (list (last sc)) lf (list (cons (car (car ec)) 0.0))) nil)
                      (list (append (list (cons (car (car sc)) 0.0)) rt (list (cons (car (last ec)) 0.0))) nil)
                )
                (list (list (car un) T))
              )
    )
  )
  (list (reverse pcs)
        un
        brd
        (mapcar '(lambda (x) (nth 4 x)) cors)
        (if closed
          (list lf rt nil nil)
          (list (append (list (cons (car (last sc)) 0.0)) lf (list (cons (car (car ec)) 0.0)))
                (append (list (cons (car (car sc)) 0.0)) rt (list (cons (car (last ec)) 0.0)))
                sc
                ec
          )
        )
  )
)

;;  The line at d from the line pp (a join of two layers of an assembly, a Line layer): the
;;  border at d of the band (see Dyl:QdBandOne), from its start to its end. Returns (path
;;  closed):
(defun Dyl:QdLineAt (pp closed us trims d bd w opt / np n i res)
  (setq np (length pp)
        n  (length us)
        i  0
  )
  (foreach tr trims
    (setq res (append res (caddr (Dyl:QdBorderAt (nth (rem (1+ i) np) pp) (nth i us) (nth (rem (1+ i) n) us) d tr)))
          i   (1+ i)
    )
  )
  (if closed
    (list res T)
    (list (append (list (cons (Dyl:QdEndPt (car pp) (car us) d bd w opt T) 0.0))
                  res
                  (list (cons (Dyl:QdEndPt (last pp) (last us) d bd w opt nil) 0.0))
          )
          nil
    )
  )
)

;;  How the band of the line pp (closed: the last point joins the first) turns at each of its
;;  corners (see Dyl:QdTrim), us the direction of each segment, its borders bd (dl dr), width
;;  w, options opt:
(defun Dyl:QdTrims (pp closed us bd w opt / np n i res)
  (setq np (length pp)
        n  (length us)
        i  0
  )
  (repeat (if closed n (1- n))
    (setq res (cons (Dyl:QdTrim (nth (rem (1+ i) np) pp) (nth i us) (nth (rem (1+ i) n) us) (car bd) (cadr bd) w opt) res)
          i   (1+ i)
    )
  )
  (reverse res)
)

;;  The geometry of the band of the line pp (see Dyl:QdBandOne) made of the layers lays,
;;  ((dl dr [lopt [bkey]]) ...) from its left border to its right one, options opt, and the
;;  lines at the distances offs from the line. Every layer turns its corners and ends as the
;;  whole band does, so they meet; a layer with its own options lopt (its own band settings)
;;  turns and ends as a band of its own, across its own thickness. Returns (layers borders
;;  joints lines): layers, the pieces and unions of each layer ((pieces unions) ...);
;;  borders, the border of the whole band ((path closed [key]) ...); joints, those drawn (the
;;  joints Interrupted: (a b [key]) ...); lines, ((path closed) ...) for offs. When a layer
;;  has its own options or its own border (bkey), each layer is outlined apart (see
;;  Dyl:QdLayersBorders):
(defun Dyl:QdBandLayers (pp closed lays opt offs / bd w np n i us trims res bj)
  (setq bd (list (car (car lays)) (cadr (last lays)))
        w  (- (car bd) (cadr bd))
        np (length pp)
        n  (if closed np (1- np))
        i  0
  )
  (repeat n
    (setq us (cons (Dyl:QuickDrawUnit (Dyl:QdSub (nth (rem (1+ i) np) pp) (nth i pp))) us)
          i  (1+ i)
    )
  )
  (setq us    (reverse us)
        trims (Dyl:QdTrims pp closed us bd w opt)
        res   (mapcar '(lambda (ly / sd lw)
                         (if (caddr ly)
                           (progn
                             (setq sd (list (car ly) (cadr ly))
                                   lw (- (car ly) (cadr ly))
                             )
                             (Dyl:QdBandOne pp closed us (Dyl:QdTrims pp closed us sd lw (caddr ly)) (car ly) (cadr ly) sd lw (caddr ly))
                           )
                           (Dyl:QdBandOne pp closed us trims (car ly) (cadr ly) bd w opt)
                         )
                       )
                      lays
              )
        bj    (if (vl-some '(lambda (ly) (or (caddr ly) (cadddr ly))) lays)
                (Dyl:QdLayersBorders lays res opt closed offs)
                (list (caddr (if (cdr lays) (Dyl:QdBandOne pp closed us trims (car bd) (cadr bd) bd w opt) (car res)))
                      (if (= "Interrupted" (nth 6 opt)) (apply 'append (mapcar 'cadddr res)))
                )
              )
  )
  (list (mapcar '(lambda (x) (list (car x) (cadr x))) res)
        (car bj)
        (cadr bj)
        (mapcar '(lambda (d) (Dyl:QdLineAt pp closed us trims d bd w opt)) offs)
  )
)

;;  T when the paths a and b are the same (their points and bulges):
(defun Dyl:QdSamePath (a b)
  (and (= (length a) (length b))
       (vl-every '(lambda (x y) (and (< (distance (car x) (car y)) 1e-8) (equal (cdr x) (cdr y) 1e-8))) a b)
  )
)

;;  The borders and the joints of the layers lays of an assembly ((dl dr lopt bkey) ...) when
;;  some have their own band settings (lopt) or their own border (bkey): res, their geometry
;;  (see Dyl:QdBandOne); opt, the options of the band; offs, where its Line layers are. Each
;;  layer is outlined as it ends: its sides, its start and end (but Open). The line between two
;;  layers is drawn once when they meet on it (twice when they turn their corners apart): by
;;  the layer with its own border (the first one when both have one), else as the border of
;;  the band, but where a Line layer is (the line of that layer is drawn). A layer with its own
;;  border draws its lines on its layer key, its whole outline as one closed polyline when it
;;  has it. The joints of each layer when its joints are drawn (Interrupted), on its key.
;;  Returns (borders joints): ((path closed key) ...), key nil for the border of the band;
;;  ((a b key) ...):
(defun Dyl:QdLayersBorders (lays res opt closed offs / n i ly x o k sd nsd own jts out pcs)
  (setq n   (length lays)
        own (mapcar '(lambda (ly) nil) lays)
        i   0
  )
  (while (< i n)
    (setq ly (nth i lays)
          x  (nth i res)
          o  (cond ((caddr ly)) (opt))
          k  (cadddr ly)
          sd (nth 4 x)
    )
    ;;  Its start and its end:
    (if (and (not closed) (/= "Open" (car o)))
      (setq own (Remote>>Dyl:ListSubst own i (append (nth i own) (list (list (caddr sd) nil) (list (cadddr sd) nil)))))
    )
    ;;  The left side of the first layer, the right side of the last one:
    (if (= i 0) (setq own (Remote>>Dyl:ListSubst own i (append (nth i own) (list (list (car sd) closed))))))
    (if (= i (1- n))
      (setq own (Remote>>Dyl:ListSubst own i (append (nth i own) (list (list (cadr sd) closed)))))
      ;;  Its right side and the left side of the next layer:
      (progn
        (setq nsd (nth 4 (nth (1+ i) res)))
        (cond
          ((not (Dyl:QdSamePath (cadr sd) (car nsd)))
           (setq own (Remote>>Dyl:ListSubst own i (append (nth i own) (list (list (cadr sd) closed))))
                 own (Remote>>Dyl:ListSubst own (1+ i) (append (nth (1+ i) own) (list (list (car nsd) closed))))
           )
          )
          (k (setq own (Remote>>Dyl:ListSubst own i (append (nth i own) (list (list (cadr sd) closed))))))
          ((cadddr (nth (1+ i) lays))
           (setq own (Remote>>Dyl:ListSubst own (1+ i) (append (nth (1+ i) own) (list (list (car nsd) closed)))))
          )
          ((not (vl-some '(lambda (d) (equal d (cadr ly) 1e-9)) offs))
           (setq own (Remote>>Dyl:ListSubst own i (append (nth i own) (list (list (cadr sd) closed)))))
          )
        )
      )
    )
    (if (= "Interrupted" (nth 6 o))
      (setq jts (append jts (mapcar '(lambda (j) (list (car j) (cadr j) k)) (cadddr x))))
    )
    (setq i (1+ i))
  )
  (setq i 0)
  (foreach pcs own
    (setq ly (nth i lays)
          k  (cadddr ly)
          o  (cond ((caddr ly)) (opt))
          i  (1+ i)
    )
    (setq out (append out
                      (if (and k (not closed) (/= "Open" (car o)) (= 4 (length pcs)))
                        (list (list (car (cadr (nth (1- i) res))) T k))
                        (mapcar '(lambda (p) (list (car p) (cadr p) k)) pcs)
                      )
              )
    )
  )
  (list out jts)
)

;;  The geometry of the band of the line pp (closed: the last point joins the first), width
;;  w, justification jus, options opt. Returns (pieces unions borders joints), see
;;  Dyl:QdBandOne:
(defun Dyl:QdBand (pp closed w jus opt / g)
  (setq g (Dyl:QdBandLayers pp closed (list (Dyl:QuickDrawSides w jus)) opt nil))
  (list (car (car (car g))) (cadr (car (car g))) (cadr g) (caddr g))
)

;;  A polyline of the path p (2D UCS points at the elevation z), closed or not, on the current
;;  layer, the repeated points dropped. Returns its ename:
(defun Dyl:QdPline (p closed z / res w)
  (foreach x p
    (if (and res (< (distance (car x) (car (car res))) 1e-9))
      (setq res (cons (cons (car (car res)) (cdr x)) (cdr res)))
      (setq res (cons x res))
    )
  )
  (setq res (reverse res))
  (if (and closed (cddr res) (< (distance (car (car res)) (car (last res))) 1e-9))
    (setq res (reverse (cdr (reverse res))))
  )
  (setq w (mapcar '(lambda (x) (trans (list (car (car x)) (cadr (car x)) z) 1 0)) res))
  (entmakex
    (append (list '(0 . "LWPOLYLINE")
                  '(100 . "AcDbEntity")
                  (cons 8 (getvar "CLAYER"))
                  '(100 . "AcDbPolyline")
                  (cons 90 (length res))
                  (cons 70 (if closed 1 0))
                  (cons 38 (caddr (car w)))
            )
            (apply 'append (mapcar '(lambda (x y) (list (list 10 (car y) (cadr y)) (cons 42 (cdr x)))) res w))
    )
  )
)

;;  The points of the arc from a to b of bulge bu (a straight line: a only), b left out, the
;;  arc as 8 chords:
(defun Dyl:QdArcPts (a b bu / th s d c r a0 i res)
  (if (< (abs bu) 1e-9)
    (list a)
    (progn
      (setq th (* 4.0 (atan bu))
            s  (/ (distance a b) 2.0)
            d  (/ s (/ (sin (/ th 2.0)) (cos (/ th 2.0))))
            c  (Dyl:QdAdd (Dyl:QdMul (Dyl:QdAdd a b) 0.5) (Dyl:QdMul (Dyl:QdLeft (Dyl:QuickDrawUnit (Dyl:QdSub b a))) d))
            r  (distance c a)
            a0 (angle c a)
            i  0
      )
      (repeat 8
        (setq res (cons (polar c (+ a0 (* th (/ i 8.0))) r) res)
              i   (1+ i)
        )
      )
      (reverse res)
    )
  )
)

;;  Draw the path p (closed or not) as temporary vectors:
(defun Dyl:QdGrPath (p closed / pts)
  (if closed (setq p (append p (list (car p)))))
  (while (cdr p)
    (setq pts (append pts (Dyl:QdArcPts (car (car p)) (car (cadr p)) (cdr (car p))))
          p   (cdr p)
    )
  )
  (setq pts (append pts (list (car (car p)))))
  (mapcar '(lambda (a b) (grdraw a b -1 0)) pts (cdr pts))
)

;;  Preview of the band of the geometry g (see Dyl:QdBand) with the options opt: its border,
;;  and its joints when they are drawn:
(defun Dyl:QdGrBand (g opt)
  (foreach b (caddr g) (Dyl:QdGrPath (car b) (cadr b)))
  (if (= "Interrupted" (nth 6 opt))
    (foreach j (cadddr g) (grdraw (car j) (cadr j) -1 0))
  )
)

;;  The borders of the bands drawn apart from their hatches (qd:borders, ((path closed z key)
;;  ...), and qd:borderents, the borders of curves already made, see Dyl:QuickDrawCurveBand:
;;  enames, or (ename . key)), made or brought to the front after the hatches, so they are
;;  drawn over them: on the outline layer key of the material mat with its border settings;
;;  none when it has no border. A border with a key is drawn even without border: a Line
;;  layer of an assembly on its layer key, its properties ByLayer; a layer with its own border
;;  on the key of its border, with the properties it overrides (see Dyl:QuickDrawBorderKey):
(defun Dyl:QuickDrawBorderMake (mat / ss nob e k)
  (setq nob (= "1" (nth 31 mat))
        ss  (ssadd)
  )
  (foreach b qd:borders
    (if (and (or (cadddr b) (not nob)) (setq e (Dyl:QdPline (car b) (cadr b) (caddr b))))
      (if (cadddr b)
        (Dyl:QuickDrawBorderKey e (cadddr b))
        (progn
          (Remote>>Dyl:LayerKeyApply e (nth 7 mat))
          (Remote>>Dyl:MaterialProps e mat 'border)
        )
      )
    )
  )
  (foreach x qd:borderents
    (setq e (if (listp x) (car x) x)
          k (if (listp x) (cdr x))
    )
    (cond
      ((not (entget e)))
      (k (Dyl:QuickDrawBorderKey e k) (ssadd e ss))
      (nob (entdel e))
      (T
       (Remote>>Dyl:LayerKeyApply e (nth 7 mat))
       (Remote>>Dyl:MaterialProps e mat 'border)
       (ssadd e ss)
      )
    )
  )
  (if (< 0 (sslength ss)) (command "_.draworder" ss "" "_f"))
)

;;  The border e on the key k of a line: a layer key (a Line layer), its properties ByLayer;
;;  or the border of a layer of an assembly (see Dyl:QuickDrawLayerBorder), on its layer key
;;  with the properties it overrides:
(defun Dyl:QuickDrawBorderKey (e k)
  (if (listp k)
    (progn
      (Remote>>Dyl:LayerKeyApply e (nth 7 k))
      (Remote>>Dyl:MaterialProps e k 'border)
    )
    (Remote>>Dyl:LayerKeyApply e k)
  )
)

;;-------------------------=={ Assembly }==------------------------;;

;;  An assembly makes the band of Linear of several layers side by side (a wall: gypsum,
;;  studs and insulation, sheathing, an air space, brick...), from its left border to its
;;  right one looking from the start point: the layers of the assembly preset of the preset
;;  (see Remote>>Dyl:MaterialLayers, edited in the Assembly Presets window). A Hatch layer is a
;;  band of its thickness hatched as its Quick Draw preset says: its material, its hatch
;;  scale = width x factor (the thickness as the width), its hatch origin on the line from its
;;  own border or center (its Line on). A Space layer is not hatched; a Line layer is a line
;;  on its own layer key. The width of the band is the total of the layers, the line on its
;;  center or one of its borders (the Line on of the preset). Every layer ends and turns its
;;  corners with the whole band (the ends and corners of the preset), and the borders are
;;  drawn once, apart from the hatches: the border of the band, the joins of its layers and
;;  its joints (Interrupted), with the border settings of the preset.
;;  The layers of the band drawn (qd:layers, local of Dyl:QuickDraw): ((kind thickness mat
;;  key name) ...), see Dyl:QuickDrawLayersGet.

;;  The width of the band of the layers lys (resolved, see Dyl:QuickDrawLayersGet):
(defun Dyl:QuickDrawLayersWidth (lys)
  (apply '+ (cons 0.0 (mapcar 'cadr lys)))
)

;;  The layers of the assembly of the material mat (its behaviors, see Dyl:QuickDrawMat: its
;;  assembly preset, see Dyl:QuickDrawAsmLayers), nil
;;  when its assembly is off or has no thickness: ((kind thickness mat key name lopt bkey
;;  ljus core) ...). A Hatch layer (P) has the material of its preset with the behaviors of that
;;  preset, its name, the options of its own band settings when they are on (see
;;  Dyl:QuickDrawLayerOpts, nil: those of the band), its own border when it has one (nil: none;
;;  see Dyl:QuickDrawLayerBorder), the line of the layer its own band settings align its hatch to
;;  (Center: its middle, Edge: its border nearer to the line of the band, Hatch aligned to
;;  Layer center or Layer edge, see Dyl:QuickDrawLayerPivot and Dyl:QuickDrawLayerHatch; nil:
;;  none, its middle) and T when it is the structural layer (see Dyl:QuickDrawLayersCore);
;;  a Line layer (L) its layer key and no thickness. A Hatch layer
;;  whose preset no longer exists is drawn as a space (S), with a message:
(defun Dyl:QuickDrawLayersGet (mat / res rec m w)
  (if (= "1" (nth 59 mat))
    (progn
      (foreach l (Remote>>Dyl:MaterialLayers (Dyl:QuickDrawAsmLayers (nth *mt:layerscol* mat)))
        (setq w (cond ((distof (caddr l) 2)) (0.0)))
        (cond
          ((= "L" (car l)) (setq res (cons (list "L" 0.0 nil (cadr l) "") res)))
          ((= "S" (car l)) (setq res (cons (list "S" w nil nil "") res)))
          ((and (setq rec (Dyl:QuickDrawGet (cadr l))) (setq m (Remote>>Dyl:MaterialGet (nth 3 rec))))
           (setq m (Dyl:QuickDrawMat m rec))
           ;;  The layer's own hatch: its layer key in place of the one of its preset (index 8),
           ;;  the properties it overrides, No hatch when it has none (Has a hatch of the
           ;;  Assembly Presets window; the hatch of its preset as the preset says, but its No
           ;;  hatch):
           (setq m (Remote>>Dyl:MaterialHatchOver m (cons (cond ((cadddr l)) ("")) (cdr (nth 7 l))))
                 m (Remote>>Dyl:MaterialNoHatch m (= "0" (car (nth 7 l))))
           )
           (setq res (cons (list "P" w m nil (nth 2 rec)
                                 (if (= "1" (car (nth 4 l))) (Dyl:QuickDrawLayerOpts (nth 4 l)))
                                 (Dyl:QuickDrawLayerBorder (nth 5 l))
                                 (if (= "1" (car (nth 4 l))) (if (= "Edge" (cadr (nth 4 l))) "Edge" "Center"))
                                 (= "1" (nth 6 l))
                           )
                           res
                     )
           )
          )
          (T
           (princ (strcat "\n--> Assembly: the preset of a layer no longer exists (" (cadr l) "), drawn as a space."))
           (setq res (cons (list "S" w nil nil "") res))
          )
        )
      )
      (setq res (reverse res))
      (if (< 0.0 (Dyl:QuickDrawLayersWidth res))
        res
        (progn (princ "\n--> Assembly: no layer with a thickness, drawn as one band.") nil)
      )
    )
  )
)

;;  The own border d of a layer of an assembly (see Remote>>Dyl:MaterialLayers: on key, then
;;  the properties it overrides) as the border columns of a material (its layer key at 7, its
;;  overrides from 12, see Remote>>Dyl:MaterialProps), nil when it has none:
(defun Dyl:QuickDrawLayerBorder (d)
  (if (and (= "1" (car d)) (/= "" (cadr d)))
    (append '(nil nil nil nil nil nil nil) (list (cadr d)) '(nil nil nil nil)
            (if (= 12 (length d)) (cddr d) (Remote>>LM:sublst *mt:new* 12 10))
    )
  )
)

;;  The options of a band (see Dyl:QuickDrawBandOpts) of the own band settings b of a layer of
;;  an assembly (see Remote>>Dyl:MaterialLayers: on hatch ends extension angle corners miter
;;  lap joints), never asked (Ask: the default):
(defun Dyl:QuickDrawLayerOpts (b / e c)
  (setq e (if (assoc (nth 2 b) (cdr *mt:ends*)) (nth 2 b) "Square")
        c (if (assoc (nth 5 b) (cdr *mt:corners*)) (nth 5 b) "Mitered")
  )
  (list e
        (distof (nth 3 b) 2)
        (* pi (/ (cond ((distof (nth 4 b) 2)) (45.0)) 180.0))
        c
        (cond ((distof (nth 6 b) 2)) (4.0))
        (if (assoc (nth 7 b) *mt:laps*) (nth 7 b) "First")
        (if (assoc (nth 8 b) *mt:joints*) (nth 8 b) "Interrupted")
        (if (assoc (nth 1 b) *mt:hatchmodes*) (nth 1 b) "Line")
  )
)

;;  What the layer l is, for the messages:
(defun Dyl:QuickDrawLayerName (l)
  (cond
    ((= "P" (car l)) (nth 4 l))
    ((= "S" (car l)) "a space")
    ((strcat "a line (" (cadddr l) ")"))
  )
)

;;  The options lopt of the layer l of an assembly (see Dyl:QuickDrawLayersGet) between dl
;;  and dr from the line, with the line of the layer after them (nth 8: the distance its
;;  Angled ends turn around, see Dyl:QdEndPt): its middle (its justification Center), or its
;;  border nearer to the line of the band (Edge); nil without its own band settings:
(defun Dyl:QuickDrawLayerPivot (l dl dr / mid)
  (setq mid (/ (+ dl dr) 2.0))
  (if (nth 5 l)
    (append (Remote>>LM:sublst (nth 5 l) 0 8)
            (list (cond ((/= "Edge" (nth 7 l)) mid) ((<= 0.0 mid) dr) (dl)))
    )
  )
)

;;  The layers qd:layers across the band of the line pp (closed: the last point joins the
;;  first), justification jus, options opt: from the left border of the band to its right one
;;  (Center, Structural: the line on the middle of the structural layer), from the line toward
;;  the band when the line is a border ("Right": the band on its left, the layers then the
;;  other way). Returns (g bands sides keys): g, the geometry of
;;  the bands of the Hatch and Space layers (see Dyl:QdBandLayers), with their lines: the
;;  joins of two of them (but where a Line layer is; none when a layer has its own band
;;  settings or border: each layer is outlined then), then the Line layers; bands, those
;;  layers; sides, their borders ((dl dr lopt bkey) ...); keys, the layer key of each line
;;  (nil: the border of the preset):
(defun Dyl:QuickDrawLayersBand (pp closed jus opt / cur own lays bands lnat joins lines keys)
  (setq cur (cond ((and (= "Structural" jus) (Dyl:QuickDrawLayersCore qd:layers)))
                  ((car (Dyl:QuickDrawSides (Dyl:QuickDrawLayersWidth qd:layers) jus)))
            )
        own (vl-some '(lambda (l) (or (nth 5 l) (nth 6 l))) qd:layers)
  )
  (foreach l (if (= "Right" jus) (reverse qd:layers) qd:layers)
    (if (= "L" (car l))
      (setq lines (cons cur lines)
            keys  (cons (cadddr l) keys)
            lnat  (cons cur lnat)
      )
      (progn
        (if (and bands (not own) (not (vl-some '(lambda (x) (equal x cur 1e-9)) lnat))) (setq joins (cons cur joins)))
        (setq lays  (cons (list cur (- cur (cadr l)) (Dyl:QuickDrawLayerPivot l cur (- cur (cadr l))) (nth 6 l)) lays)
              bands (cons l bands)
              cur   (- cur (cadr l))
        )
      )
    )
  )
  (list (Dyl:QdBandLayers pp closed (reverse lays) opt (append (reverse joins) (reverse lines)))
        (reverse bands)
        (reverse lays)
        (append (mapcar '(lambda (x) nil) joins) (reverse keys))
  )
)

;;  The hatch origin (WCS) on a segment from a, of direction u (2D UCS), at the elevation z:
;;  moved by aln along it and by d across it (positive: on its left):
(defun Dyl:QuickDrawSegOrigin (a u d aln z)
  (trans (list (+ (car a) (* aln (car u)) (- (* d (cadr u)))) (+ (cadr a) (* aln (cadr u)) (* d (car u))) z) 1 0)
)

;;  The outlines to hatch of the Hatch layer ly of an assembly: geo, its pieces and unions
;;  (see Dyl:QdBandLayers), sd its borders (dl dr), pp the line, sep: Interrupted joints,
;;  line: the hatch following the line, z the elevation. As Dyl:QuickDrawSegs, each with the
;;  material of the layer and its hatch scale (the thickness x the width factor of its preset,
;;  nil: the scale of its material): ((outlines angle origin T fixed mat scale) ...), hatched
;;  without border (the borders are drawn apart). The hatch origin of the layer: on its line,
;;  its center (Center, and without its own band settings) or its border nearer to the line
;;  of the band (Edge), as its own band settings say, moved into the layer by its offset:
(defun Dyl:QuickDrawLayerHatch (pp geo ly sd sep line z / m sc mid d aln)
  (setq m   (caddr ly)
        sc  (if (= "1" (nth 37 m)) (* (cadr ly) (cond ((distof (nth 38 m) 2)) (1.0))))
        mid (/ (+ (car sd) (cadr sd)) 2.0)
        d   (* (cond ((distof (nth 40 m) 2)) (0.0)) (cond (sc) (1.0)))
        ;;  Across: from the center or the border of the layer, then into it (positive: to
        ;;  the left of the line from the center):
        d   (cond
              ((/= "Edge" (nth 7 ly)) (+ mid d))
              ((<= 0.0 mid) (+ (cadr sd) d))
              ((- (car sd) d))
            )
        aln (* (cond ((distof (nth 46 m) 2)) (0.0)) (cond (sc) (1.0)))
  )
  (if (or sep line)
    (mapcar
      '(lambda (pc / a b)
         (setq a (nth (cadr pc) pp)
               b (nth (rem (1+ (cadr pc)) (length pp)) pp)
         )
         (list (Dyl:QdPline (car pc) T z)
               (if line (/ (* 180.0 (angle a b)) pi) 0.0)
               (if line (Dyl:QuickDrawSegOrigin a (Dyl:QuickDrawUnit (Dyl:QdSub b a)) d aln z) '(0.0 0.0 0.0))
               T
               (not line)
               m
               sc
         )
       )
      (car geo)
    )
    (list (list (mapcar '(lambda (x) (Dyl:QdPline x T z)) (cadr geo)) 0.0 '(0.0 0.0 0.0) T T m sc))
  )
)

;;  The outlines of the assembly qd:layers along the line pp (see Dyl:QuickDrawSegs): those of
;;  each Hatch layer (its joints and its hatch following the line or not as its own band
;;  settings say, else as the band); the border of the band, the joins of its layers (or the
;;  outline of each one, on its own border key when it has one), its Line layers and its
;;  joints (Interrupted) go to qd:borders, drawn after the hatches (see
;;  Dyl:QuickDrawBorderMake):
(defun Dyl:QuickDrawLayersSegs (pp closed jus z / opt r g res)
  (setq opt (cond (qd:opt) ((Dyl:QuickDrawBandDefaults)))
        r   (Dyl:QuickDrawLayersBand pp closed jus opt)
        g   (car r)
  )
  (mapcar '(lambda (geo ly sd / o)
             (setq o (cond ((nth 5 ly)) (opt)))
             (if (= "P" (car ly))
               (setq res (append res (Dyl:QuickDrawLayerHatch pp geo ly sd (= "Interrupted" (nth 6 o)) (= "Line" (nth 7 o)) z)))
             )
           )
          (car g)
          (cadr r)
          (caddr r)
  )
  (setq qd:borders (append qd:borders
                           (mapcar '(lambda (x) (list (car x) (cadr x) z (caddr x))) (cadr g))
                           (mapcar '(lambda (x k) (list (car x) (cadr x) z k)) (cadddr g) (cadddr r))
                           (mapcar '(lambda (j) (list (list (cons (car j) 0.0) (cons (cadr j) 0.0)) nil z (caddr j))) (caddr g))
                   )
  )
  res
)

;;-------------------------=={ Offset }==------------------------;;

;;  Offset makes the band of Linear along existing objects (lines, polylines, rectangles,
;;  polygons, circles, arcs, ellipses, splines), with the behaviors of Linear (width, hatch
;;  scale from the width, hatch origin). As the OFFSET command of AutoCAD, a point picked on
;;  a side of each object gives the side of its band: the object is one border of the band,
;;  the band goes toward the point. Both sides: the object is the center of the band. The
;;  objects are kept as they are.
(setq *qd:offsettypes* "LINE,ARC,CIRCLE,ELLIPSE,SPLINE,LWPOLYLINE,POLYLINE")

;;  The vertices (2D UCS) of e when it is made of straight segments only (a line, a polyline
;;  without arcs), with whether it is closed and its elevation: (points closed z), nil for a
;;  curved object. Repeated vertices are dropped:
(defun Dyl:QuickDrawStraight (e / ed typ pts closed res)
  (setq ed  (entget e)
        typ (cdr (assoc 0 ed))
  )
  (cond
    ((= "LINE" typ)
     (setq pts (list (trans (cdr (assoc 10 ed)) 0 1) (trans (cdr (assoc 11 ed)) 0 1)))
    )
    ((and (= "LWPOLYLINE" typ) (not (vl-some '(lambda (x) (and (= 42 (car x)) (not (equal 0.0 (cdr x) 1e-9)))) ed)))
     (setq closed (= 1 (logand 1 (cdr (assoc 70 ed))))
           pts    (mapcar '(lambda (x) (trans (list (cadr x) (caddr x) (cdr (assoc 38 ed))) e 1))
                          (vl-remove-if-not '(lambda (x) (= 10 (car x))) ed)
                  )
     )
    )
  )
  (if pts
    (progn
      (foreach p pts
        (if (or (not res) (< 1e-8 (distance (Dyl:QuickDraw2d p) (Dyl:QuickDraw2d (car res))))) (setq res (cons p res)))
      )
      (setq res (reverse res))
      (if (and closed (cddr res) (< (distance (Dyl:QuickDraw2d (car res)) (Dyl:QuickDraw2d (last res))) 1e-8))
        (setq res (reverse (cdr (reverse res))))
      )
      (if (and closed (not (cddr res))) (setq closed nil))
      (if (cdr res) (list (mapcar 'Dyl:QuickDraw2d res) closed (caddr (car res))))
    )
  )
)

;;  The justification of the band of the line pp (2D UCS points, closed: the last point joins
;;  the first) for the side point p (UCS, nil: both sides): the side of p from the segment
;;  nearest to it. On its left: the line is the right border of the band ("Right"); on its
;;  right: "Left"; no point: "Center":
(defun Dyl:QuickDrawSideJus (pp closed p / segs best bd a b u t0 q d)
  (if (not p)
    "Center"
    (progn
      (setq p    (Dyl:QuickDraw2d p)
            segs (mapcar 'list pp (append (cdr pp) (if closed (list (car pp)))))
      )
      (foreach s segs
        (setq a  (car s)
              b  (cadr s)
              u  (mapcar '- b a)
              ;;  The point of the segment nearest to p:
              t0 (max 0.0 (min 1.0 (/ (+ (* (- (car p) (car a)) (car u)) (* (- (cadr p) (cadr a)) (cadr u)))
                                       (+ (* (car u) (car u)) (* (cadr u) (cadr u)))
                                    )
                          )
                 )
              q  (list (+ (car a) (* t0 (car u))) (+ (cadr a) (* t0 (cadr u))))
              d  (distance p q)
        )
        (if (or (not bd) (< d bd)) (setq bd d best s))
      )
      (setq u (mapcar '- (cadr best) (car best)))
      (if (< 0.0 (- (* (car u) (- (cadr p) (cadr (car best)))) (* (cadr u) (- (car p) (car (car best))))))
        "Right"
        "Left"
      )
    )
  )
)

;;  The curves made by offsetting e by d (enames, nil when AutoCAD cannot offset it), the
;;  corners of the band (qd:opt); d 0: a copy of e:
(defun Dyl:QuickDrawOffsetCurve (e d / o r g)
  (setq o (vlax-ename->vla-object e))
  (cond
    ((equal d 0.0 1e-12)
     (if (not (vl-catch-all-error-p (setq r (vl-catch-all-apply 'vla-Copy (list o)))))
       (list (vlax-vla-object->ename r))
     )
    )
    (T
     ;;  The corners of a polyline with arcs as those of the band (OFFSETGAPTYPE: 0 extended,
     ;;  as Mitered and Lapped; 1 Round; 2 Beveled), restored after:
     (setq g (getvar "OFFSETGAPTYPE"))
     (setvar "OFFSETGAPTYPE" (cond ((= "Round" (nth 3 qd:opt)) 1) ((= "Beveled" (nth 3 qd:opt)) 2) (0)))
     (setq r (vl-catch-all-apply 'vla-Offset (list o d)))
     (setvar "OFFSETGAPTYPE" g)
     (if (not (vl-catch-all-error-p r))
       (mapcar 'vlax-vla-object->ename (vlax-safearray->list (vlax-variant-value r)))
     )
    )
  )
)

;;  Distance from the point p (UCS) to the curve e:
(defun Dyl:QuickDrawDistTo (e p / w)
  (setq w (trans p 1 0))
  (distance w (vlax-curve-getClosestPointTo e w))
)

;;  The two borders of the band of the curved object e (an arc, a circle, a polyline with
;;  arcs...), width w: toward the side point p (UCS) as OFFSET does, the copy of e and its
;;  offset by w on the side of p (both offsets made, the one nearer to p kept); no point: the
;;  offsets of e by w / 2 on each side. Returns (border border), nil when they cannot be made:
(defun Dyl:QuickDrawCurveBorders (e w p / a b)
  (if p
    (progn
      (setq a (Dyl:QuickDrawOffsetCurve e w)
            b (Dyl:QuickDrawOffsetCurve e (- w))
      )
      (cond
        ((and a b (= 1 (length a)) (= 1 (length b)))
         (if (< (Dyl:QuickDrawDistTo (car a) p) (Dyl:QuickDrawDistTo (car b) p))
           (progn (entdel (car b)) (setq b (Dyl:QuickDrawOffsetCurve e 0.0)))
           (progn (entdel (car a)) (setq a (Dyl:QuickDrawOffsetCurve e 0.0)))
         )
        )
        ;;  Only one side can be offset (an arc on its inner side...): that one when it is the
        ;;  side of the point (nearer to it than the object), else none:
        ((and (= 1 (length a)) (not b) (< (Dyl:QuickDrawDistTo (car a) p) (Dyl:QuickDrawDistTo e p)))
         (setq b (Dyl:QuickDrawOffsetCurve e 0.0))
        )
        ((and (= 1 (length b)) (not a) (< (Dyl:QuickDrawDistTo (car b) p) (Dyl:QuickDrawDistTo e p)))
         (setq a (Dyl:QuickDrawOffsetCurve e 0.0))
        )
        (T (foreach x (append a b) (entdel x)) (setq a nil b nil))
      )
    )
    (setq a (Dyl:QuickDrawOffsetCurve e (/ w 2.0))
          b (Dyl:QuickDrawOffsetCurve e (/ w -2.0))
    )
  )
  ;;  One curve per border (an offset that splits into several pieces is not used):
  (if (and (= 1 (length a)) (= 1 (length b)))
    (list (car a) (car b))
    (progn (foreach x (append a b) (if (entget x) (entdel x))) nil)
  )
)

;;  The closing piece of the band of the curved object e between the ends a and b (WCS) of
;;  its borders: a line, or a half circle outward for Round ends (a polyline arc, on the side
;;  of the end of e it is nearer to); sq T: a line. Extended and Angled ends are square on a
;;  curve:
(defun Dyl:QuickDrawCurveEnd (e a b sq / m sp ep u q)
  (if (and (not sq) (= "Round" (car qd:opt)))
    (progn
      (setq m  (Dyl:QdMul (Dyl:QdAdd a b) 0.5)
            sp (vlax-curve-getStartPoint e)
            ep (vlax-curve-getEndPoint e)
            u  (if (< (distance m sp) (distance m ep))
                 (Dyl:QdMul (Dyl:QuickDrawUnit (Dyl:QuickDraw2d (vlax-curve-getFirstDeriv e (vlax-curve-getStartParam e)))) -1.0)
                 (Dyl:QuickDrawUnit (Dyl:QuickDraw2d (vlax-curve-getFirstDeriv e (vlax-curve-getEndParam e))))
               )
            q  (Dyl:QdAdd m (Dyl:QdMul u (/ (distance (Dyl:QuickDraw2d a) (Dyl:QuickDraw2d b)) 2.0)))
      )
      (entmakex (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 (getvar "CLAYER")) '(100 . "AcDbPolyline")
                      '(90 . 2) '(70 . 0) (cons 38 (caddr a))
                      (list 10 (car a) (cadr a)) (cons 42 (Dyl:QdHalf (Dyl:QuickDraw2d a) (Dyl:QuickDraw2d b) q))
                      (list 10 (car b) (cadr b)) '(42 . 0.0)
                )
      )
    )
    (entmakex (list '(0 . "LINE") (cons 8 (getvar "CLAYER")) (cons 10 a) (cons 11 b)))
  )
)

;;  The ends of the curves a and b (WCS), the start of a with the nearest end of b:
;;  (start-a end-a end-of-b-near-start-a other-end-of-b):
(defun Dyl:QuickDrawCurveEnds (a b / ends)
  (setq ends (list (vlax-curve-getStartPoint a) (vlax-curve-getEndPoint a)
                   (vlax-curve-getStartPoint b) (vlax-curve-getEndPoint b)
             )
  )
  (if (> (distance (car ends) (caddr ends)) (distance (car ends) (cadddr ends)))
    (list (car ends) (cadr ends) (cadddr ends) (caddr ends))
    ends
  )
)

;;  The outline between the two borders a and b of the band of the curved object e: closed,
;;  both (the inner one an island of the hatch); open, one closed outline, the borders joined
;;  by their ends (see Dyl:QuickDrawCurveEnd, sq T: lines across) with JOIN. Returns the
;;  outlines (enames), nil when they cannot be joined (a, b and the ends erased):
(defun Dyl:QuickDrawCurveOutline (e a b sq / ends l1 l2 mark res)
  (if (vlax-curve-isClosed e)
    (list a b)
    (progn
      (setq ends (Dyl:QuickDrawCurveEnds a b)
            l1   (Dyl:QuickDrawCurveEnd e (car ends) (caddr ends) sq)
            l2   (Dyl:QuickDrawCurveEnd e (cadr ends) (cadddr ends) sq)
            mark (entlast)
      )
      (command "_.join" a b l1 l2 "")
      (while (< 0 (logand 1 (getvar "CMDACTIVE"))) (command ""))
      ;;  JOIN made a new object (lines and arcs: a polyline), or joined them into a:
      (setq res (cond
                  ((not (eq mark (entlast))) (entlast))
                  ((entget a) a)
                )
      )
      (if (and res (entget res) (vlax-curve-isClosed res))
        (list res)
        (progn (foreach x (list res a b l1 l2) (if (and x (entget x)) (entdel x))) nil)
      )
    )
  )
)

;;  The band of the curved object e, width w, side point p (see Dyl:QuickDrawCurveBorders).
;;  Closed: both borders, the inner one an island of the hatch. Open: one closed outline, the
;;  borders joined by their ends (see Dyl:QuickDrawCurveOutline). Returns the outlines
;;  (enames), nil with a message when it cannot be made:
(defun Dyl:QuickDrawCurveBand (e w p / brd cp res)
  (if (not (setq brd (Dyl:QuickDrawCurveBorders e w p)))
    (progn
      (princ "\n--> Offset: this object cannot be offset by the width of the band, skipped.")
      nil
    )
    (progn
      ;;  Open ends: the two borders kept as the border of the band (copies, brought over the
      ;;  hatch after, see Dyl:QuickDrawBorderMake), the outline joined only to be hatched:
      (if (and (= "Open" (car qd:opt)) (not (vlax-curve-isClosed e)))
        (setq cp            (append (Dyl:QuickDrawOffsetCurve (car brd) 0.0) (Dyl:QuickDrawOffsetCurve (cadr brd) 0.0))
              qd:borderents (append qd:borderents cp)
        )
      )
      (if (setq res (Dyl:QuickDrawCurveOutline e (car brd) (cadr brd) nil))
        res
        (progn
          (foreach x cp (if (entget x) (entdel x)))
          (setq qd:borderents (vl-remove-if '(lambda (x) (member x cp)) qd:borderents))
          (princ "\n--> Offset: the borders of the band could not be joined into one closed outline, skipped.")
          nil
        )
      )
    )
  )
)

;;  The sign of the offsets of the curve e toward the point p (UCS): 1 or -1 (as in
;;  Dyl:QuickDrawCurveBorders: the offset by w nearer to p), nil when e cannot be offset by w
;;  on that side:
(defun Dyl:QuickDrawCurveSign (e w p / a b res)
  (setq a   (Dyl:QuickDrawOffsetCurve e w)
        b   (Dyl:QuickDrawOffsetCurve e (- w))
        res (cond
              ((and (= 1 (length a)) (= 1 (length b)))
               (if (< (Dyl:QuickDrawDistTo (car a) p) (Dyl:QuickDrawDistTo (car b) p)) 1.0 -1.0)
              )
              ((and (= 1 (length a)) (not b) (< (Dyl:QuickDrawDistTo (car a) p) (Dyl:QuickDrawDistTo e p))) 1.0)
              ((and (= 1 (length b)) (not a) (< (Dyl:QuickDrawDistTo (car b) p) (Dyl:QuickDrawDistTo e p))) -1.0)
            )
  )
  (foreach x (append a b) (if (entget x) (entdel x)))
  res
)

;;  The places across the assembly qd:layers, from its first layer: (bands lines): bands,
;;  ((from to layer) ...) for its Hatch and Space layers; lines, ((at . key) ...) for its Line
;;  layers (the distances from the start of the first layer):
(defun Dyl:QuickDrawLayersPlaces (/ cur bands lines)
  (setq cur 0.0)
  (foreach l qd:layers
    (if (= "L" (car l))
      (setq lines (cons (cons cur (cadddr l)) lines))
      (setq bands (cons (list cur (+ cur (cadr l)) l) bands)
            cur   (+ cur (cadr l))
      )
    )
  )
  (list (reverse bands) (reverse lines))
)

;;  The assembly qd:layers along the curved object e (an arc, a circle, a spline, a polyline
;;  with arcs), side point p (UCS, nil: both sides): the first layer on e, the others toward p;
;;  both sides: centered on e, the first layer on its left (looking along it). A curve made at
;;  every place across it (the offsets of e, see Dyl:QuickDrawOffsetCurve): each Hatch layer
;;  is the outline between its two curves (see Dyl:QuickDrawCurveOutline, its ends square),
;;  hatched with the angle of its material (from the drawing origin with Drawing origin,
;;  its own or that of the band);
;;  the curves are the borders of the band (its edges and the joins of its layers, the Line
;;  layers on their layer key), with lines across its ends but Open (qd:borderents). When a
;;  layer has its own band settings or border, the lines across the ends are those of each
;;  layer (but Open, its own or the band's), and a curve on the side of a layer with its own
;;  border is on that border's layer key (but where a Line layer is), as Dyl:QdLayersBorders.
;;  Returns ((outlines angle origin T fixed mat scale) ...) as Dyl:QuickDrawLayerHatch, nil
;;  with a message when the curves cannot be made:
(defun Dyl:QuickDrawCurveLayers (e p / w k smp org pl we cums crvs ok res c a b q ln lst ends m sc own bk)
  (setq w   (Dyl:QuickDrawLayersWidth qd:layers)
        own (vl-some '(lambda (l) (or (nth 5 l) (nth 6 l))) qd:layers)
        pl  (Dyl:QuickDrawLayersPlaces)
        ;;  The place of the far edge (the end of the last layer):
        we  (cadr (last (car pl)))
  )
  ;;  The sign of the offsets toward the side (both sides: toward the left of e):
  (if p
    (setq k (Dyl:QuickDrawCurveSign e w p))
    (setq smp (car (Dyl:QuickDrawCurveSamples e))
          k   (Dyl:QuickDrawCurveSign e
                                      (/ w 2.0)
                                      (append (Dyl:QdAdd (car smp) (Dyl:QdMul (cadr smp) (/ w 2.0)))
                                              (list (caddr (trans (vlax-curve-getStartPoint e) 0 1)))
                                      )
              )
    )
  )
  ;;  A curve at each place, one each (a place: the distance from the start of the first layer):
  (setq cums (cons 0.0 (append (mapcar 'cadr (car pl)) (mapcar 'car (cadr pl))))
        ok   k
  )
  (foreach c cums
    (if (and ok (not (assoc c crvs)))
      (if (= 1 (length (setq q (Dyl:QuickDrawOffsetCurve e (if p (* k c) (* k (- (/ w 2.0) c)))))))
        (setq crvs (cons (cons c (car q)) crvs))
        (progn (foreach x q (entdel x)) (setq ok nil))
      )
    )
  )
  (if (not ok)
    (progn
      (foreach x crvs (if (entget (cdr x)) (entdel (cdr x))))
      (princ "\n--> Offset: this object cannot be offset by the width of the assembly, skipped.")
      nil
    )
    (progn
      ;;  Each Hatch layer: the outline between copies of its curves:
      (foreach bd (car pl)
        (if (= "P" (car (caddr bd)))
          (progn
            (setq a   (car (Dyl:QuickDrawOffsetCurve (cdr (assoc (car bd) crvs)) 0.0))
                  b   (car (Dyl:QuickDrawOffsetCurve (cdr (assoc (cadr bd) crvs)) 0.0))
                  org (= "Origin" (nth 7 (cond ((nth 5 (caddr bd))) (qd:opt))))
                  m   (caddr (caddr bd))
                  sc (if (= "1" (nth 37 m)) (* (cadr (caddr bd)) (cond ((distof (nth 38 m) 2)) (1.0))))
            )
            (if (and a b (setq q (Dyl:QuickDrawCurveOutline e a b T)))
              (setq res (cons (list q 0.0 (if org '(0.0 0.0 0.0)) T org m sc) res))
              (progn
                (foreach x (list a b) (if (and x (entget x)) (entdel x)))
                (princ (strcat "\n--> Offset: a layer (" (Dyl:QuickDrawLayerName (caddr bd)) ") could not be made, skipped."))
              )
            )
          )
        )
      )
      ;;  The curves, borders of the band: its edges (a Line layer there: a copy on its key)
      ;;  and the joins of its layers (a Line layer there: on its key):
      (foreach x crvs
        (setq ln (vl-remove-if-not '(lambda (y) (equal (car y) (car x) 1e-9)) (cadr pl))
              ;;  The key of the own border of a layer on that side (the one before it first):
              bk (if own
                   (cond
                     ((vl-some '(lambda (bd) (if (and (nth 6 (caddr bd)) (equal (cadr bd) (car x) 1e-9)) (nth 6 (caddr bd)))) (car pl)))
                     ((vl-some '(lambda (bd) (if (and (nth 6 (caddr bd)) (equal (car bd) (car x) 1e-9)) (nth 6 (caddr bd)))) (car pl)))
                   )
                 )
        )
        (cond
          ((or (equal (car x) 0.0 1e-9) (equal (car x) we 1e-9))
           (setq lst (cons (if bk (cons (cdr x) bk) (cdr x)) lst))
           (foreach y ln
             (setq lst (append (mapcar '(lambda (z) (cons z (cdr y))) (Dyl:QuickDrawOffsetCurve (cdr x) 0.0)) lst))
           )
          )
          (ln
           (setq lst (cons (cons (cdr x) (cdr (car ln))) lst))
           (foreach y (cdr ln)
             (setq lst (append (mapcar '(lambda (z) (cons z (cdr y))) (Dyl:QuickDrawOffsetCurve (cdr x) 0.0)) lst))
           )
          )
          ;;  On the side of a layer with its own border:
          (bk (setq lst (cons (cons (cdr x) bk) lst)))
          ((setq lst (cons (cdr x) lst)))
        )
      )
      ;;  The lines across the ends of an open object, but Open: across the whole band, or
      ;;  across each layer when one has its own band settings or border (on its key):
      (cond
        ((vlax-curve-isClosed e))
        (own
         (foreach bd (car pl)
           (if (/= "Open" (car (cond ((nth 5 (caddr bd))) (qd:opt))))
             (progn
               (setq ends (Dyl:QuickDrawCurveEnds (cdr (assoc (car bd) crvs)) (cdr (assoc (cadr bd) crvs)))
                     bk   (nth 6 (caddr bd))
               )
               (foreach q (list (Dyl:QuickDrawCurveEnd e (car ends) (caddr ends) T) (Dyl:QuickDrawCurveEnd e (cadr ends) (cadddr ends) T))
                 (setq lst (cons (if bk (cons q bk) q) lst))
               )
             )
           )
         )
        )
        ((/= "Open" (car qd:opt))
         (setq ends (Dyl:QuickDrawCurveEnds (cdr (assoc 0.0 crvs)) (cdr (assoc we crvs))))
         (setq lst (cons (Dyl:QuickDrawCurveEnd e (car ends) (caddr ends) T)
                         (cons (Dyl:QuickDrawCurveEnd e (cadr ends) (cadddr ends) T) lst)
                   )
         )
        )
      )
      (setq qd:borderents (append qd:borderents lst))
      (reverse res)
    )
  )
)

;;  Points along the curved object e for its preview: ((point normal) ...), 2D UCS, the
;;  normal of unit length to its left, 64 intervals of equal length:
(defun Dyl:QuickDrawCurveSamples (e / len n i par p dv u res)
  (setq len (vlax-curve-getDistAtParam e (vlax-curve-getEndParam e))
        n   64
        i   0
  )
  (repeat (1+ n)
    (setq par (if (= i n)
                (vlax-curve-getEndParam e)
                (cond ((vlax-curve-getParamAtDist e (* len (/ i (float n))))) ((vlax-curve-getEndParam e)))
              )
          p   (Dyl:QuickDraw2d (trans (vlax-curve-getPointAtParam e par) 0 1))
          dv  (Dyl:QuickDraw2d (trans (vlax-curve-getFirstDeriv e par) 0 1 t))
          i   (1+ i)
    )
    (if (< 1e-12 (distance '(0.0 0.0) dv))
      (setq u   (Dyl:QuickDrawUnit dv)
            res (cons (list p (list (- (cadr u)) (car u))) res)
      )
    )
  )
  (reverse res)
)

;;  Draw a polyline of the points pts as temporary vectors:
(defun Dyl:QuickDrawGrLine (pts)
  (mapcar '(lambda (a b) (grdraw a b -1 0)) pts (cdr pts))
)

;;  Preview of the band of the object e, width w, for the cursor at p (UCS): its borders on the
;;  side of p (temporary vectors, the object highlighted; e nil: the line of Linear drawn).
;;  st: its straight segments (see Dyl:QuickDrawStraight), else smp: the samples of the curve
;;  (see Dyl:QuickDrawCurveSamples), the far border drawn from them (an assembly: the joins of
;;  its layers too):
(defun Dyl:QuickDrawSidePreview (e st smp w p / near nd k far pl)
  (redraw)
  (if e (redraw e 3) (mapcar '(lambda (a b) (grdraw a b -1 1)) (car st) (cdr (car st))))
  (setq p (Dyl:QuickDraw2d p))
  (if st
    ;;  The band with its ends, corners and joints:
    (Dyl:QuickDrawGrBand (car st) (cadr st) w (Dyl:QuickDrawSideJus (car st) (cadr st) p) qd:opt)
    (if smp
      (progn
        ;;  The side of p from the sample nearest to it:
        (foreach x smp
          (if (or (not nd) (< (distance p (car x)) nd)) (setq nd (distance p (car x)) near x))
        )
        (setq k   (if (< 0.0 (+ (* (- (car p) (car (car near))) (car (cadr near)))
                                (* (- (cadr p) (cadr (car near))) (cadr (cadr near)))
                             )
                      )
                    1.0
                    -1.0
                  )
              far (mapcar '(lambda (x) (mapcar '+ (car x) (mapcar '(lambda (c) (* k w c)) (cadr x)))) smp)
        )
        (Dyl:QuickDrawGrLine far)
        ;;  The joins of the layers of an assembly:
        (if qd:layers
          (foreach bd (cdr (car (Dyl:QuickDrawLayersPlaces)))
            (Dyl:QuickDrawGrLine (mapcar '(lambda (x) (mapcar '+ (car x) (mapcar '(lambda (c) (* k (car bd) c)) (cadr x)))) smp))
          )
        )
        (if (not (vlax-curve-isClosed e))
          (progn
            (grdraw (car (car smp)) (car far) -1 0)
            (grdraw (car (last smp)) (last far) -1 0)
          )
        )
      )
    )
  )
)

;;  Ask the side of the band of the object e, width w, as OFFSET does: the band is previewed
;;  on the side of the cursor while it moves (see Dyl:QuickDrawSidePreview); a click picks
;;  that side, Enter, Space, a right click or B (Both sides) centers the band on the object.
;;  Returns the point picked (UCS), nil for both sides:
(defun Dyl:QuickDrawAskSide (e w / st smp g res done)
  (setq st  (Dyl:QuickDrawStraight e)
        smp (if (not st) (Dyl:QuickDrawCurveSamples e))
  )
  (redraw e 3)
  (princ "\nSpecify point on side to offset or [Both sides] <Both sides>: ")
  (while (not done)
    (setq g (grread t 15 0))
    (cond
      ((= 5 (car g)) (Dyl:QuickDrawSidePreview e st smp w (cadr g)))
      ((= 3 (car g)) (setq res (cadr g) done t))
      ((= 2 (car g)) (if (member (cadr g) '(13 32 66 98)) (setq done t)))
      ((member (car g) '(11 25)) (setq done t))
    )
  )
  (redraw)
  (redraw e 4)
  res
)

;;  The band of the object o, width w, side point side (see Dyl:QuickDrawAskSide), made now
;;  (its outlines shown before the next object is picked): ((outlines angle origin) ...), see
;;  Dyl:QuickDrawOffsetBands. An assembly (qd:layers): its layers from the object toward the
;;  side (see Dyl:QuickDrawLayersBand, Dyl:QuickDrawCurveLayers):
(defun Dyl:QuickDrawOffsetOne (o w side off aln sf / st q org)
  (setq org (= "Origin" (nth 7 qd:opt)))
  (cond
    ;;  Straight segments: the bands of Linear, justified to the side picked, the origin
    ;;  offsets scaled as there:
    ((setq st (Dyl:QuickDrawStraight o))
     (Dyl:QuickDrawSegs (car st)
                        (cadr st)
                        w
                        (Dyl:QuickDrawSideJus (car st) (cadr st) side)
                        (if sf (* off w sf) off)
                        (if sf (* aln w sf) aln)
                        (cond ((caddr st)) (0.0))
     )
    )
    ;;  A curve, an assembly: its layers:
    (qd:layers (Dyl:QuickDrawCurveLayers o side))
    ;;  A curve: one outline (an outline to hatch only with Open ends), the angle of the
    ;;  material, the drawing origin with Drawing origin:
    ((setq q (Dyl:QuickDrawCurveBand o w side))
     (list (list q
                 0.0
                 (if org '(0.0 0.0 0.0))
                 (and (= "Open" (car qd:opt)) (not (vlax-curve-isClosed o)))
                 org
           )
     )
    )
  )
)

;;  Offset: the bands of the objects selected before the command (PICKFIRST), else of the
;;  objects picked one by one (the width can be changed at each pick; an assembly: its layers
;;  flipped), each with the side of its band (see Dyl:QuickDrawAskSide), made as soon as its
;;  side is picked. The parameters are those of Dyl:QuickDrawLinear (its justification is not
;;  used: the side is picked). Returns ((outlines angle origin) ...): for an object made of
;;  straight segments, one outline per segment as Linear (see Dyl:QuickDrawSegs); for a curved
;;  one, its outlines, the angle 0.0 (the angle of the material) and no origin. Sets qd:width
;;  (local of Dyl:QuickDraw) to the width used:
(defun Dyl:QuickDrawOffsetBands (wid jus off aln sf / ss w objs p q segs)
  ;;  The objects selected before the command, read before any prompt (an assembly: the width
  ;;  of its layers):
  (setq ss (ssget "_I" (list (cons 0 *qd:offsettypes*)))
        w  (car (Dyl:QuickDrawWidthJus (if qd:layers (rtos (Dyl:QuickDrawLayersWidth qd:layers) 2 8) wid) "Center"))
  )
  (sssetfirst nil nil)
  (setvar "ERRNO" 0)
  (if (not qd:opt) (setq qd:opt (Dyl:QuickDrawBandDefaults)))
  (if ss
    (foreach e (Dyl:QuickDrawSsList ss)
      (if w (setq segs (append segs (Dyl:QuickDrawOffsetOne e w (Dyl:QuickDrawAskSide e w) off aln sf))))
    )
    ;;  The objects picked one by one, each with its side, or a width for the next ones:
    (while (and w
                (progn
                  (initget (if qd:layers "Flip Ends Corners" "Width Ends Corners"))
                  (setq p (entsel (strcat (if qd:layers
                                            "\nSelect an object to offset or [Flip/Ends/Corners] <done, assembly "
                                            "\nSelect an object to offset or [Width/Ends/Corners] <done, width "
                                          )
                                          (rtos w)
                                          ", "
                                          (car qd:opt)
                                          ", "
                                          (nth 3 qd:opt)
                                          ">: "
                                  )
                          )
                  )
                  (or p (= 7 (getvar "ERRNO")))
                )
           )
      (cond
        ((= "Ends" p) (Dyl:QuickDrawAskEnds))
        ((= "Corners" p) (Dyl:QuickDrawAskCorners))
        ((= "Flip" p)
         (setq qd:layers (reverse qd:layers))
         (princ (strcat "\nLayers flipped: " (Dyl:QuickDrawLayerName (car qd:layers)) " first, on the object."))
        )
        ((= "Width" p)
         (initget 6)
         (if (setq q (getdist (strcat "\nWidth <" (rtos w) ">: ")))
           (progn (setq w q) (setenv "DynalispQuickDrawWidth" (rtos w 2 8)))
         )
        )
        ((null p) (setvar "ERRNO" 0))
        ((not (wcmatch (cdr (assoc 0 (entget (car p)))) *qd:offsettypes*))
         (princ "\nNot a line, polyline, circle, arc, ellipse or spline.")
        )
        ((member (car p) objs) (princ "\nAlready selected."))
        ;;  Its band made now, shown while the next object is picked:
        (T
         (setq objs (cons (car p) objs)
               segs (append segs (Dyl:QuickDrawOffsetOne (car p) w (Dyl:QuickDrawAskSide (car p) w) off aln sf))
         )
        )
      )
    )
  )
  (setq qd:width w)
  segs
)

;;-------------------------=={ Draw }==------------------------;;

;;  Replace: the hatches selected before the command (PICKFIRST), else those selected now (not
;;  on a locked layer), get the hatch of the material mat (see Remote>>Dyl:MaterialReplace):
;;  their boundary is kept, the border settings of the preset are not used:
(defun Dyl:QuickDrawReplace (mat / ss n bad)
  (setq ss  (cond
              ((ssget "_I" '((0 . "HATCH"))))
              (T
               (princ "\nSelect the hatches to replace:")
               (ssget "_:L" '((0 . "HATCH")))
              )
            )
        n   0
        bad 0
  )
  (sssetfirst nil nil)
  (if ss
    (progn
      (foreach e (Dyl:QuickDrawSsList ss)
        (if (Remote>>Dyl:MaterialReplace mat e) (setq n (1+ n)) (setq bad (1+ bad)))
      )
      (princ (strcat "\n" (itoa n) " hatch(es) replaced" (if (< 0 bad) (strcat ", " (itoa bad) " not replaced") "") "."))
    )
    (princ "\nNo hatch selected.")
  )
)

;;  Make the outlines with the method mode (asked when it is not a method of *qd:modes*), then
;;  hatch them with the material mat (see Remote>>Dyl:MaterialHatch). The behaviors of the
;;  material give the band of Linear (width and justify, see Dyl:QuickDrawLinear, each
;;  segment hatched along its angle) and the sides of Polygon:
(defun Dyl:QuickDraw (mat mode / *error* doc lyr out bad segs mt:keepouts mt:scale mt:origin qd:width qd:opt
                    qd:borders qd:borderents qd:layers scl m
                   )

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

  ;;  Replace: no outline, the hatches selected get the hatch of the material:
  (if (= "Replace" mode)
    (Dyl:QuickDrawReplace mat)
    (progn
      ;;  Make the outlines on the layer of the outline layer key (created if missing, see Dyl-LayerKeys):
      (setq lyr (getvar "CLAYER"))
      (vl-catch-all-apply 'setvar (list "CLAYER" (Remote>>Dyl:LayerKeyLayer (nth 7 mat))))
      (princ (strcat "\nQuick Draw - " (cadr (assoc mode *qd:modes*)) ":"))
      ;;  Linear and Offset: the bands of a line drawn / of existing objects, with the same
      ;;  behaviors (width, justify, origin, scale from the width):
      (if (member mode '("Linear" "Offset"))
        (setq qd:opt    (Dyl:QuickDrawBandOpts mat)
              ;;  The layers of its assembly (nil: one band):
              qd:layers (Dyl:QuickDrawLayersGet mat)
              segs      ((if (= "Linear" mode) Dyl:QuickDrawLinear Dyl:QuickDrawOffsetBands)
                     (cond ((nth 34 mat)) (""))
                     (cond ((nth 35 mat)) ("Center"))
                     (cond ((distof (cond ((nth 40 mat)) ("")) 2)) (0.0))
                     (cond ((distof (cond ((nth 46 mat)) ("")) 2)) (0.0))
                     (if (= "1" (nth 37 mat)) (cond ((distof (cond ((nth 38 mat)) ("")) 2)) (1.0)))
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
        ;;  Linear and Offset: each segment hatched along its angle (a curved band of Offset:
        ;;  its outlines, the angle of the material):
        ((member mode '("Linear" "Offset"))
         (if segs
           (progn
             ;;  The behaviors of Linear: the hatch scale from the width (width x factor, in place
             ;;  of the scales of the material), the hatch origin on the line:
             (setq scl (if (and (= "1" (nth 37 mat)) qd:width)
                         (* qd:width (cond ((distof (cond ((nth 38 mat)) ("")) 2)) (1.0)))
                       )
             )
             ;;  Each outline: its origin (fixed: the drawing origin; else on the line when the
             ;;  preset says so); an outline to hatch only (temp) hatched as with No border:
             ;;  erased once hatched, the border made apart, over the hatches. A layer of an
             ;;  assembly: its material and its scale (see Dyl:QuickDrawLayerHatch):
             (foreach s segs
               (setq m         (cond ((nth 5 s)) (mat))
                     mt:scale  (if (nth 5 s) (nth 6 s) scl)
                     mt:origin (cond ((nth 4 s) (caddr s)) ((= "1" (nth 39 m)) (caddr s)))
               )
               (Remote>>Dyl:MaterialHatchAt (if (nth 3 s) (Remote>>Dyl:ListSubst m 31 "1") m)
                                            (if (listp (car s)) (car s) (list (car s)))
                                            (cadr s)
               )
             )
             (Dyl:QuickDrawBorderMake mat)
           )
           (princ (if (= "Linear" mode) "\nNo line drawn." "\nNo object offset."))
         )
        )
        (out (Remote>>Dyl:MaterialHatch mat out))
        ((princ "\nNo outline to hatch."))
      )
    )
  )
  (vla-EndUndoMark doc)
  (princ)
)

;;  Draw a preset: its material gives the hatch, the preset how it is drawn and its border
;;  (its behaviors and border settings, put in the columns of the material):
(defun Dyl:QuickDrawRun (rec / mat)
  (if (setq mat (Remote>>Dyl:MaterialGet (nth 3 rec)))
    (progn
      (Dyl:QuickDrawRecentAdd (car rec))
      (setq mat (Dyl:QuickDrawMat mat rec))
      (Dyl:QuickDraw mat (cond ((nth 33 mat)) ("")))
    )
    (alert (strcat "\nError: the material of the preset \""
                   (nth 2 rec)
                   "\" no longer exists ("
                   (nth 3 rec)
                   ").\nPick another one in Dyl-QuickDraw."
           )
    )
  )
)

;;  The presets drawn last, the last one first (their ids, 12 at most), for the Recent group
;;  of the gallery: kept on the blackboard, so every drawing of the session shares them:
(defun Dyl:QuickDrawRecent ()
  (vl-bb-ref '*qd:recent*)
)

(defun Dyl:QuickDrawRecentAdd (id / l u res)
  (setq u (strcase id)
        l (cons id (vl-remove-if '(lambda (x) (= u (strcase x))) (Dyl:QuickDrawRecent)))
  )
  (while (and l (< (length res) 12))
    (setq res (cons (car l) res)
          l   (cdr l)
    )
  )
  (vl-bb-set '*qd:recent* (reverse res))
)

;;-------------------------=={ Presets }==------------------------;;

;;  A preset is a list of strings (see Remote\Dyl-Presets.lsp for the preset engine):
;;  (id group name material method override width justify sides scale-width width-factor
;;   origin-on-line origin-offset gap gap-on gap-metric origin-along
;;   outline-key border-settings... no-border
;;   ends extension end-angle corners miter-limit lap joints hatch assembly-on assembly
;;   ends-on corners-on band-on)
;;  id is the id of a default preset (e.g. "qd-Demolition", run by Pst-QuickDrawDemolition), or
;;  a custom id (cu-...). material is the id of a material (see Remote\Dyl-Materials.lsp), so
;;  several presets can share it (e.g. QD-BRICK and PL-BRICK). The behaviors (method, then
;;  the columns after override, see *qd:tiles*) are those of the preset: override is always
;;  "1" (a preset of an older file with "0", drawn with the behaviors of its material, gets
;;  them, see Dyl:QuickDrawFix). The border (outline-key, its optional settings, no-border,
;;  index 17 to 28: the values of the border columns of a material, see *mt:bordertiles*) is
;;  that of the preset too; a preset of an older file, without it, gets the border of its
;;  material.
;;  The assembly (Linear, Offset): on/off, then the id of its assembly preset (index 38, picked
;;  in the list beside Assembly; the layers of an older file, see Dyl:QuickDrawAsmMigrate).
;;  The presets are saved to Res\QuickDraw.csv (spec in Remote\Dyl-QuickDrawPresets.lsp).

;;  Material behaviors of a preset: tile of the Quick Draw window and index of its value in a
;;  preset (the index in a material: *mt:behaviortiles* of Remote\Dyl-Materials.lsp):
(setq *qd:behaviors* '(("mth" . 4) ("mwd" . 6) ("mjs" . 7) ("msd" . 8) ("msw" . 9) ("mfc" . 10)
                       ("mor" . 11) ("mof" . 12) ("mgp" . 13) ("mgo" . 14) ("moa" . 16)
                       ;;  The bands of Linear and Offset (after the border): ends, extension, end
                       ;;  angle, corners, miter limit, lap, joints, hatch:
                       ("men" . 29) ("mex" . 30) ("mea" . 31) ("mco" . 32) ("mml" . 33) ("mlt" . 34)
                       ("mjo" . 35) ("mht" . 36)
                       ;;  The assembly of Linear (its layers: *qd:layerscol*):
                       ("mas" . 37)
                       ;;  Their own ends and corners (off: the defaults, see Dyl:QuickDrawBandOpts):
                       ("meo" . 39) ("mcn" . 40)
                      )
)

;;  The behaviors set in the Band Settings window (see Dyl:QuickDrawBandDialog), not tiles
;;  of the Quick Draw window: the hatch alignment of the band, its ends and corners, the scale
;;  and the origin of its hatch (the justification, the line drawn, is a tile of the Behaviors
;;  box):
(setq *qd:subtiles* '("mht" "men" "mex" "mea" "mco" "mml" "mlt" "mjo" "meo" "mcn" "msw" "mfc" "mor" "moa" "mof"))

;;  The assembly preset of a preset (its id, see Dyl:QuickDrawAsmLayers):
(setq *qd:layerscol* 38)

;;  Custom band settings (Behaviors box): on, the bands of Linear and Offset are drawn with the
;;  hatch alignment, ends, corners, hatch scale and origin of the Band Settings
;;  window; off, with the defaults (Line, Square, Mitered, the scales of the material, the
;;  drawing origin), the values of the window kept for when it is on again (see
;;  Dyl:QuickDrawMat). Ends-on and corners-on (39, 40) follow it. An assembly is drawn with
;;  the band settings of each layer: it is greyed out while Assembly is checked. A preset of an
;;  older file, without it, gets it on when its band was not the defaults (Dyl:QuickDrawFix):
(setq *qd:bandon* 41)

;;  The border of a preset: its columns from 17 (the layer key, then its optional settings,
;;  see Remote>>Dyl:MaterialBorderTiles), No border at 28:
(setq *qd:border* 17
      *qd:noborder* 28
)

;;  The hatch of a preset (Has a hatch, its Hatch Settings window): its columns from 42 (the
;;  layer key, "": the hatch layer key of its material, then the properties of the key it
;;  overrides, see *mt:hatchtiles*), No hatch at 53 ("1": the outline only, kept as the
;;  border). An assembly has the hatches of its layers: Has a hatch is greyed out:
(setq *qd:hatch* 42
      *qd:nohatch* 53
)

;;  The hatch of a preset of an older file, without it: the key of its material, the
;;  properties of the material, a hatch:
(setq *qd:hatchnew* (append '("") (Remote>>LM:sublst *mt:new* 12 10) '("0")))

;;  Tiles of the Quick Draw window: the behaviors and the border:
(setq *qd:tiles* (append (vl-remove-if '(lambda (x) (member (car x) *qd:subtiles*)) *qd:behaviors*)
                         (Remote>>Dyl:MaterialBorderTiles *qd:border*)
                 )
)

;;  The defaults of a new preset (its behaviors and border), the material of a preset whose
;;  material no longer exists:
(setq *qd:matnew* *mt:new*)

;;  The material mat with the behaviors and the border of the preset r in its columns, its
;;  band as it is drawn: its own while Custom band settings is on (its ends and corners on, 61
;;  and 62), else the defaults (hatch along the line, ends and corners off, see
;;  Dyl:QuickDrawBandOpts; the scales of the material and the drawing origin: Scale by
;;  width and Origin on line off). An assembly has the defaults: its layers have their own
;;  band settings (see Dyl:QuickDrawLayerPivot). The justification (the line drawn, 35) is
;;  the preset's, whatever Custom band settings is, an assembly's included. An assembly has
;;  no border of the preset either (No border, 31): its layers have their own (Has a border of
;;  the Assembly Presets window), its Line layers their key. The hatch of the preset (its key
;;  and the properties it overrides, see Remote>>Dyl:MaterialHatchOver) goes in the hatch
;;  columns of mat (not for Replace hatches, which gives its material as it is: Has a hatch
;;  is greyed out), No hatch in its column *mt:nohatch* (never for Replace hatches, nor for an
;;  assembly: its layers have their own hatch, see Dyl:QuickDrawLayersGet):
(defun Dyl:QuickDrawMat (mat r / asm on)
  (setq asm (and (member (nth 4 r) '("Linear" "Offset" "")) (= "1" (nth 37 r)))
        on  (and (not asm) (= "1" (nth *qd:bandon* r)))
        mat (Dyl:QuickDrawMatRaw mat r)
        mat (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst mat 61 (if on "1" "0")) 62 (if on "1" "0"))
        mat (if (= "Replace" (nth 4 r)) mat (Remote>>Dyl:MaterialHatchOver mat (Dyl:QuickDrawHatchOf r)))
        mat (Remote>>Dyl:MaterialNoHatch mat (and (not asm) (Dyl:QuickDrawNoHatch-p r)))
  )
  (if asm (setq mat (Remote>>Dyl:ListSubst mat 31 "1")))
  (if on
    mat
    (progn
      (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst mat 58 "Line") 37 "0") 39 "0")
    )
  )
)

;;  The hatch of the preset r: its key and the properties it overrides (11 values, see
;;  *mt:hatchtiles*), nil for a preset without its hatch columns:
(defun Dyl:QuickDrawHatchOf (r)
  (if (nth *qd:nohatch* r) (Remote>>LM:sublst r *qd:hatch* 11))
)

;;  T when the preset r is drawn without hatch (No hatch, not Replace hatches):
(defun Dyl:QuickDrawNoHatch-p (r)
  (and (= "1" (nth *qd:nohatch* r)) (/= "Replace" (nth 4 r)))
)

;;  The material mat with the behaviors and the border of the preset r in its columns, as
;;  they are stored (the values of the Band Settings window even while it is off):
(defun Dyl:QuickDrawMatRaw (mat r)
  (foreach x *qd:behaviors*
    (setq mat (Remote>>Dyl:ListSubst mat (cdr (assoc (car x) *mt:behaviortiles*)) (nth (cdr x) r)))
  )
  (setq mat (Remote>>Dyl:ListSubst mat *mt:layerscol* (nth *qd:layerscol* r)))
  (Remote>>Dyl:MaterialBorderPut mat r *qd:border* *qd:noborder*)
)

;;  The preset r with the behaviors and the border of the material mat:
(defun Dyl:QuickDrawFrom (r mat)
  (foreach x *qd:behaviors*
    (setq r (Remote>>Dyl:ListSubst r (cdr x) (nth (cdr (assoc (car x) *mt:behaviortiles*)) mat)))
  )
  (setq r (Remote>>Dyl:ListSubst r *qd:layerscol* (nth *mt:layerscol* mat)))
  (Remote>>Dyl:MaterialBorderOf r mat *qd:border* *qd:noborder*)
)

;;  The preset r with behaviors of its own (ovr T), those of the material mat (nil: the
;;  defaults of a new preset), Override "1"; ovr nil: its behaviors emptied, Override "0":
(defun Dyl:QuickDrawOverride (r ovr mat)
  (Remote>>Dyl:ListSubst (Dyl:QuickDrawFrom r (if (and ovr mat) mat *qd:matnew*)) 5 (if ovr "1" "0"))
)

;;  A row of the presets file with its 54 columns (the band, assembly, ends, corners, Custom
;;  band settings and hatch columns of an older file: empty, given their defaults by
;;  Dyl:QuickDrawFix; ends and corners on when they are not the defaults, see
;;  Remote>>Dyl:MaterialFix):
(defun Dyl:QuickDrawPad (row)
  (while (< (length row) 54) (setq row (append row (list ""))))
  row
)

;;  Values of a row of the presets file: the behaviors checked as those of a material (see
;;  Remote>>Dyl:MaterialFix). A preset of an older file drawn with the behaviors of its
;;  material (Override "0", or no Override column: written before the presets had
;;  behaviors) gets those of its material (the material as edited), and keeps a method of
;;  its own when it had one; Override is then "1". A preset of a file without the border
;;  columns (no outline key) gets the border of its material. Its group as in the groups
;;  (any case; a group not listed there is kept, as in the Materials window):
(defun Dyl:QuickDrawFix (row / m)
  (setq row (Dyl:QuickDrawPad row))
  ;;  One gap (13), in drawing units: the metric gap (15) of an older file is its gap when it
  ;;  has none, then no longer used:
  (if (= "" (vl-string-trim " " (nth 13 row))) (setq row (Remote>>Dyl:ListSubst row 13 (nth 15 row))))
  (setq row (Remote>>Dyl:ListSubst row 15 ""))
  (setq row (Remote>>Dyl:ListSubst row 1 (Remote>>Dyl:GroupCase (nth 1 row))))
  (setq row (Remote>>Dyl:ListSubst row
                                   4
                                   (cond ((car (vl-some '(lambda (x) (if (= (strcase (nth 4 row)) (strcase (car x))) x)) *qd:modes*)))
                                         ("")
                                   )
            )
  )
  (if (/= "1" (nth 5 row))
    (progn
      (setq m   (if (/= "0" (nth 5 row)) (nth 4 row) "")
            row (Dyl:QuickDrawOverride row T (Remote>>Dyl:MaterialGet (nth 3 row)))
      )
      (if (/= "" m) (setq row (Remote>>Dyl:ListSubst row 4 m)))
    )
  )
  (if (= "" (nth *qd:border* row))
    (setq row (Remote>>Dyl:MaterialBorderOf row
                                            (cond ((Remote>>Dyl:MaterialGet (nth 3 row))) (*qd:matnew*))
                                            *qd:border*
                                            *qd:noborder*
              )
    )
  )
  (setq row (Dyl:QuickDrawFrom row (Remote>>Dyl:MaterialFix (Dyl:QuickDrawMatRaw *qd:matnew* row))))
  (Dyl:QuickDrawHatchFix (Dyl:QuickDrawBandFix row))
)

;;  The hatch of the preset row (see *qd:hatch*): a preset of an older file, without it, gets a
;;  hatch with the key and the properties of its material; the key in upper case, No hatch
;;  "1" or "0":
(defun Dyl:QuickDrawHatchFix (row / i)
  (if (not (member (nth *qd:nohatch* row) '("0" "1")))
    (progn
      (setq i (1- *qd:hatch*))
      (foreach v *qd:hatchnew* (setq row (Remote>>Dyl:ListSubst row (setq i (1+ i)) v)))
    )
  )
  (Remote>>Dyl:ListSubst row *qd:hatch* (strcase (vl-string-trim " " (nth *qd:hatch* row))))
)

;;  Custom band settings of the preset row ("1" or "0"), ends-on and corners-on (39, 40) the
;;  same. A preset of an older file, without it, gets it on when its band was not drawn as the
;;  defaults (its own ends or corners, the hatch from the drawing origin, scaled by the width or from an origin on the line), the ends or corners it
;;  did not have of its own set to the defaults, so it draws as before:
(defun Dyl:QuickDrawBandFix (row / on)
  (if (member (nth *qd:bandon* row) '("0" "1"))
    (setq on (= "1" (nth *qd:bandon* row)))
    (progn
      (setq on (or (= "1" (nth 39 row))
                   (= "1" (nth 40 row))
                   (= "Origin" (nth 36 row))
                   (= "1" (nth 9 row))
                   (= "1" (nth 11 row))
               )
      )
      (if (and on (/= "1" (nth 39 row)))
        (setq row (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst row 29 "Square") 30 "") 31 "45"))
      )
      (if (and on (/= "1" (nth 40 row)))
        (setq row (Remote>>Dyl:ListSubst
                    (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst row 32 "Mitered") 33 "4") 34 "First")
                    35
                    "Interrupted"
                  )
        )
      )
    )
  )
  (setq on (if on "1" "0"))
  (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst row *qd:bandon* on) 39 on) 40 on)
)

;;  A default preset (id group name material): the behaviors and border of its default material
;;  (Res\Materials.csv as shipped, see Remote>>Dyl:MaterialDefs):
(defun Dyl:QuickDrawDefault (row)
  (Dyl:QuickDrawFix (Dyl:QuickDrawOverride (Dyl:QuickDrawPad row) T (assoc (nth 3 row) (Remote>>Dyl:MaterialDefs))))
)

;;  Default presets, restored by the Reset Selected and Reset All buttons (the behaviors and
;;  border of their default material, see Dyl:QuickDrawDefault):
(setq *qd:defaults*
  (mapcar 'Dyl:QuickDrawDefault
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

;;  The Quick Draw window (Res\Dyl-QuickDraw.xaml, shown by DynALisp.Windows.dll) is a window
;;  of the preset engine (Remote>>Dyl:PresetDialog, (window . "Dyl-QuickDraw.xaml"), see
;;  Remote\Dyl-Presets.lsp): its list and its buttons are those of every preset window; its
;;  values are the material of the preset, its behaviors (the Behaviors box) and its border
;;  (the Border box), tiles *qd:tiles*, edited in the window itself. Its open buttons close it
;;  with their code (the Band Settings window, Pick..., the Assembly Presets window, the
;;  Layer Keys window, the color of AutoCAD), see Dyl:QuickDrawDlgStatus; then it opens again.
;;  The functions below use the local variables of Remote>>Dyl:PresetDialog (pst:lst,
;;  pst:idx, pst:mats) and those of Dyl:QuickDrawDialog: mt:keys (the layer keys of the
;;  border list), qg:all (the presets with their material, for the previews, as in the
;;  Gallery, see Dyl:QuickDrawGallerySpec).

;;  Error message of an invalid behavior, nil when it is valid (as in the Materials
;;  window): the values got back from the window are checked again before they are saved:
(defun Dyl:QuickDrawDlgCheck (key val)
  (if (assoc key *qd:tiles*) (Remote>>Dyl:MaterialDlgCheck key val))
)

;;  Why the preset r is not valid (nil: it is): a preset draws a hatch or a border (but an
;;  assembly, its layers have their own); Structural layer is the line of an assembly that has
;;  a structural layer (Linear, see Dyl:QuickDrawLayersCore):
(defun Dyl:QuickDrawDlgRowCheck (r)
  (if (and (Dyl:QuickDrawNoHatch-p r) (= "1" (nth *qd:noborder* r)) (not (Dyl:QuickDrawDlgAssembly-p r)))
    "it has neither a hatch nor a border: check Has a hatch or Has a border."
    (Dyl:QuickDrawDlgRowCheckJus r)
  )
)

;;  Why the justification of the preset r is not valid (nil: it is):
(defun Dyl:QuickDrawDlgRowCheckJus (r)
  (if (and (= "Structural" (nth (cdr (assoc "mjs" *qd:behaviors*)) r))
           (member (nth 4 r) '("Linear" ""))
           (not (and (Dyl:QuickDrawDlgAssembly-p r)
                     (vl-some '(lambda (l) (= "1" (nth 6 l))) (Remote>>Dyl:MaterialLayers (Dyl:QuickDrawAsmLayers (nth *qd:layerscol* r))))
                )
           )
      )
    (if (Dyl:QuickDrawDlgAssembly-p r)
      "its assembly has no structural layer: check Structural on one of its layers in the Assembly Presets window, or pick another Justification."
      "Structural layer is the line of an assembly: check Assembly, or pick another Justification."
    )
  )
)

;;  Material of the preset r in the window (pst:mats), the defaults when it no longer exists:
(defun Dyl:QuickDrawDlgMat (r)
  (cond ((assoc (nth 3 r) pst:mats)) (*qd:matnew*))
)

;;  T when the preset r is drawn as an assembly (Linear, Offset, or a method asked when drawn):
(defun Dyl:QuickDrawDlgAssembly-p (r)
  (and (member (nth 4 r) '("Linear" "Offset" "")) (= "1" (nth 37 r)))
)

;;  The columns the window shows after those of a preset r (54 to 60, read only, never saved):
;;  what the layers of its assembly preset are, its own ends and corners (under Custom band
;;  settings, shown while it is on), the width of its layers (Width, for an assembly), the
;;  preview of its layers side by side (as an assembly even while Assembly is off: the window
;;  shows it once it is on; its outline added by the window, Has a border as it is:
;;  pst/outline), and the description of the assembly under the preview (see
;;  Dyl:QuickDrawAsmShow), then the summary of its border under Has a border (59, see
;;  Dyl:QuickDrawBorderText) and of its hatch under Has a hatch (60, see
;;  Dyl:QuickDrawHatchText). The window gives the columns 54, 56, 57 and 58 those of the
;;  assembly picked in its list (pst/follow, see Dyl:QuickDrawWinVals):
(defun Dyl:QuickDrawWinExtra (r / a)
  (setq a (Dyl:QuickDrawAsmShow (Dyl:QuickDrawAsmLayers (nth *qd:layerscol* r))))
  (list (car a)
        (Remote>>Dyl:MaterialBandText (Dyl:QuickDrawMat (Dyl:QuickDrawDlgMat r) (Remote>>Dyl:ListSubst r *qd:bandon* "1")))
        (cadr a)
        (caddr a)
        (cadddr a)
        (Dyl:QuickDrawBorderText r)
        (Dyl:QuickDrawHatchText r)
  )
)

;;  The summary of the border of the preset r (its border columns from *qd:border*, see
;;  Remote>>Dyl:MaterialBorderTiles): its layer key, then each property it overrides
;;  (MED, Color 1, Lineweight 0.35 mm, see Dyl:QuickDrawPropsText):
(defun Dyl:QuickDrawBorderText (r)
  (Dyl:QuickDrawPropsText (cond ((nth *qd:border* r)) ("")) (Remote>>LM:sublst r (1+ *qd:border*) 10))
)

;;  The summary of the hatch of the preset r (its hatch columns from *qd:hatch*): its layer
;;  key (From material when it has none: the material can change in the window), then
;;  each property it overrides:
(defun Dyl:QuickDrawHatchText (r)
  (Dyl:QuickDrawPropsText (cond ((/= "" (cond ((nth *qd:hatch* r)) (""))) (nth *qd:hatch* r)) ("From material"))
                          (Remote>>LM:sublst r (1+ *qd:hatch*) 10)
  )
)

;;  A layer key k and the properties of it overridden v (10 values: color on, color, linetype
;;  on, linetype, linetype scale on, scale, lineweight on, lineweight, transparency on,
;;  transparency) as a summary: MED, Color 1, Lineweight 0.35 mm:
(defun Dyl:QuickDrawPropsText (k v / res)
  (setq res (list k))
  (foreach x '((0 "Color ") (2 "Linetype ") (4 "Linetype scale ") (6 "Lineweight ") (8 "Transparency "))
    (if (= "1" (nth (car x) v))
      (setq res (cons (strcat (cadr x)
                              (if (= 6 (car x))
                                (strcat (rtos (/ (atoi (cond ((nth 7 v)) ("0"))) 100.0) 2 2) " mm")
                                (cond ((nth (1+ (car x)) v)) (""))
                              )
                      )
                      res
                )
      )
    )
  )
  (Remote>>LM:lst->str (reverse res) ", ")
)

;;  The description of the assembly of the layers ls (see Remote>>Dyl:MaterialLayers) under
;;  its preview: its total thickness, then each layer on a line of its own, from its left
;;  border, with its thickness (a line: its layer key; the structural layer marked), in the
;;  units of the drawing; "" without layers:
(defun Dyl:QuickDrawLayersDesc (ls / rec)
  (if ls
    (apply 'strcat
           (cons (strcat "Total thickness  "
                         (rtos (apply '+ (cons 0.0 (mapcar '(lambda (l) (cond ((distof (caddr l) 2)) (0.0))) ls))))
                 )
                 (mapcar '(lambda (l)
                            (strcat "\n"
                                    (cond ((= "L" (car l)) (strcat "Line  " (cadr l)))
                                          ((= "S" (car l)) (strcat "Space  " (rtos (distof (caddr l) 2))))
                                          (T
                                           (setq rec (vl-some '(lambda (x) (if (= (strcase (cadr l)) (strcase (car (car x)))) (car x))) qg:all))
                                           (strcat (if rec (nth 2 rec) (cadr l)) "  " (rtos (distof (caddr l) 2)) (if (= "1" (nth 6 l)) "  (structural)" ""))
                                          )
                                    )
                            )
                          )
                         ls
                 )
           )
    )
    ""
  )
)

;;  The preview of a material mat, as it plots (see Dyl:QuickDrawGalleryBand):
(defun Dyl:QuickDrawWinMatSpec (mat)
  (Dyl:QuickDrawGalleryBand "P" mat 1.0)
)

;;  Before the window is shown: the presets with their material (qg:all, for the previews of
;;  the layers of an assembly) and the layer keys of the border list (mt:keys):
(defun Dyl:QuickDrawWinPrep (/ mat)
  (setq qg:all nil)
  (foreach r pst:lst
    (if (setq mat (assoc (nth 3 r) pst:mats)) (setq qg:all (cons (cons r (Dyl:QuickDrawMat mat r)) qg:all)))
  )
  (setq qg:all (reverse qg:all))
  (Remote>>Dyl:MaterialDlgKeys nil (mapcar '(lambda (r) (nth *qd:border* r)) (append *qd:defaults* pst:lst)))
)

;;  The lists of the window: the labels of their items (key/list) and the values they store
;;  (key/vals): the methods, the justifications (the line drawn), the assembly presets (by
;;  name; one a preset has that no longer exists marked missing) with what the window shows of
;;  each one (pst/follow: the columns 54, 56, 57 and 58, see Dyl:QuickDrawWinExtra), the layer
;;  keys (marked when they are not defined), the lineweights:
(defun Dyl:QuickDrawWinVals (/ lks asms ids)
  (setq lks  (Remote>>Dyl:LayerKeyRead)
        asms (vl-sort (Dyl:QuickDrawAsmRead)
                      '(lambda (a b) (< (strcase (strcat (nth 1 a) "\t" (nth 2 a))) (strcase (strcat (nth 1 b) "\t" (nth 2 b)))))
             )
        ids  (mapcar 'car asms)
  )
  (foreach r pst:lst
    (if (and (/= "" (nth *qd:layerscol* r))
             (not (vl-string-search ":" (nth *qd:layerscol* r)))
             (not (member (strcase (nth *qd:layerscol* r)) (mapcar 'strcase ids)))
        )
      (setq ids  (append ids (list (nth *qd:layerscol* r)))
            asms (append asms (list (list (nth *qd:layerscol* r) "" (strcat (nth *qd:layerscol* r) "   (missing assembly)") "")))
      )
    )
  )
  (list (cons "mak/list" (mapcar 'caddr asms))
        (cons "mak/vals" ids)
        (cons "pst/follow" "38:54,56,57,58")
        (cons "pst/follow/rows" (mapcar '(lambda (a) (cons (car a) (Dyl:QuickDrawAsmShow (nth 3 a)))) asms))
        (cons "mth/list" (mapcar 'cadr (cons '("" "Ask when drawn") *mt:methods*)))
        (cons "mth/vals" (cons "" (mapcar 'car *mt:methods*)))
        (cons "mjs/list" (mapcar 'cadr *mt:justify*))
        (cons "mjs/vals" (mapcar 'car *mt:justify*))
        (cons "out/list" (mapcar '(lambda (k) (if (assoc k lks) k (strcat k "   (not defined)"))) mt:keys))
        (cons "out/vals" mt:keys)
        (cons "bwt/list" (mapcar '(lambda (w) (strcat (rtos (/ (atoi w) 100.0) 2 2) " mm")) *mt:weights*))
        (cons "bwt/vals" *mt:weights*)
  )
)

;;  The open buttons of the window (code sta, the preset shown r). The open button of the
;;  assembly: the Assembly Presets window, the assembly selected there on OK given to every
;;  preset selected (see Remote>>Dyl:PresetDlgPut):
(defun Dyl:QuickDrawDlgStatus (sta r / v i)
  (if (and (= *mt:layerspick* sta) (setq v (Dyl:QuickDrawAsmDialog pst:lst r)))
    (Remote>>Dyl:PresetDlgPut *qd:layerscol* (car v))
  )
  ;;  The open button of Custom band settings: its window, its values given to every preset
  ;;  selected on OK:
  (if (and (= *mt:bandpick* sta) (setq v (Dyl:QuickDrawBandDialog r)))
    (foreach p v (Remote>>Dyl:PresetDlgPut (cdr (assoc (car p) *qd:behaviors*)) (cdr p)))
  )
  ;;  The open button of Has a border: the Border Settings window, its values given to every
  ;;  preset selected on OK:
  (if (and (= *mt:borderpick* sta) (setq v (Dyl:QuickDrawBorderDialog r)))
    (foreach p v (Remote>>Dyl:PresetDlgPut (car p) (cdr p)))
  )
  ;;  The open button of Has a hatch: the Hatch Settings window, the same way:
  (if (and (= *mt:hatchsetpick* sta) (setq v (Dyl:QuickDrawHatchDialog r)))
    (foreach p v (Remote>>Dyl:PresetDlgPut (car p) (cdr p)))
  )
  nil
)

;;  Show the Quick Draw window. Draw and Save write the presets file and the aliases.
;;  Returns the preset to draw, or nil on Save / Cancel:
(defun Dyl:QuickDrawDialog (/ mt:keys qg:all)
  (Dyl:QuickDrawAsmMigrate)
  (Remote>>Dyl:PresetDialog
    "QuickDraw"
    (list (cons 'defs *qd:defaults*)
          (cons 'fix 'Dyl:QuickDrawFix)
          (cons 'tiles *qd:tiles*)
          ;;  The Group list of the Materials window (the other groups used by a preset are
          ;;  added to it):
          '(groups . T)
          '(material . 3)
          '(upper "out" "blt")
          '(window . "Dyl-QuickDraw.xaml")
          ;;  Has a border (No border, inverted), Has a hatch (No hatch, inverted), Custom band
          ;;  settings, the assembly preset, the columns of Dyl:QuickDrawWinExtra:
          '(wtiles . "hbr:28:inv,hha:53:inv,mbs:41,mak:38,mei:55,mwl:56,mld:58,hbi:59,hhi:60")
          '(extra . Dyl:QuickDrawWinExtra)
          ;;  The preview of an assembly: its layers side by side:
          '(spec 57 . "mas,mth=Linear|Offset|")
          ;;  The preview of a preset without Has a hatch (not Replace hatches): a space:
          '(blank . "!hha,mth!=Replace")
          ;;  The preview outlined while Has a border is checked, as in the gallery (an assembly
          ;;  never: its layers have their own):
          '(outline . "hbr,!mas;hbr,mth!=Linear|Offset|")
          '(mspec . Dyl:QuickDrawWinMatSpec)
          ;;  The text put in the new alias box: PL- for a preset drawn with a polyline, QD- for
          ;;  the others (see CONVENTIONS.md, Preset aliases):
          '(wprefix . "4|Polyline=PL-|*=QD-")
          '(wprep . Dyl:QuickDrawWinPrep)
          '(wvals . Dyl:QuickDrawWinVals)
          ;;  A new preset: the defaults of a new preset for its behaviors:
          (cons 'new (Dyl:QuickDrawFix (Dyl:QuickDrawOverride (Dyl:QuickDrawPad '("" "" "New preset" "mt-Brick" "")) T nil)))
          '(check . Dyl:QuickDrawDlgCheck)
          '(rowcheck . Dyl:QuickDrawDlgRowCheck)
          '(status . Dyl:QuickDrawDlgStatus)
    )
  )
)

;;-------------------------=={ Band Settings window }==------------------------;;

;;  The open button of Custom band settings (Behaviors box) opens the Band Settings window
;;  (Res\Dyl-QuickDrawBandSettings.xaml, shown by DynALisp.Windows.dll) on the preset shown:
;;  the tiles of *mt:bandwindows*, their values those of the material of the preset with its
;;  behaviors as stored (Dyl:QuickDrawMatRaw; the button is greyed out while Custom band
;;  settings is off). The window greys out the values what is picked does not use, checks the
;;  numbers and sketches the ends and the corners; OK gives them to every preset selected (see
;;  Dyl:QuickDrawDlgStatus).

;;  The values of the window for the tiles of a band window, the material m: a popup its
;;  labels, the keys of its items and the index of the one picked, an edit box its text:
(defun Dyl:QuickDrawBandVals (tiles m / v res)
  (foreach x tiles
    (setq v   (cond ((nth (cdr (assoc (car x) *mt:behaviortiles*)) m)) (""))
          res (append res
                      (if (= 'edit (caddr x))
                        (list (cons (car x) v))
                        (list (cons (strcat (car x) "/list") (mapcar 'cadr (caddr x)))
                              (cons (strcat (car x) "/vals") (mapcar 'car (caddr x)))
                              (cons (car x) (itoa (cond ((vl-position v (mapcar 'car (caddr x)))) (0))))
                        )
                      )
              )
    )
  )
  res
)

;;  The Band Settings window on the preset r. Returns its values ((key . value) ...) on OK,
;;  nil on Cancel (or when the window cannot be shown). The method of the preset (mth, no
;;  control), its justification (mjs, no control: the line of the sketches) and solid ("1": a SOLID hatch, without scale or
;;  origin) are given with them. Pick... closes it with *mt:originpick*: the hatch origin is
;;  picked on a sample band of the material with the values of the window (see
;;  Remote>>Dyl:MaterialOriginPick), and the window opens again on it. The values are checked
;;  again (see Remote>>Dyl:MaterialDlgCheck; the factor and the offsets only while their
;;  checkbox is on): one not valid is said, nothing given:
(defun Dyl:QuickDrawBandDialog (r / tiles m res vals msg p)
  (setq tiles (cddr (assoc "BandSettings" *mt:bandwindows*))
        m     (Dyl:QuickDrawMatRaw (Dyl:QuickDrawDlgMat r) r)
  )
  (while
    (progn
      (setq res  (Dyl:WinShow "Dyl-QuickDrawBandSettings.xaml"
                              (append (list (cons "mth" (cond ((nth 4 r)) ("")))
                                            ;;  (for the sketches: the line drawn)
                                            (cons "mjs" (cond ((nth (cdr (assoc "mjs" *qd:behaviors*)) r)) ("")))
                                            (Dyl:WinTog "solid" (= "SOLID" (strcase (cond ((nth 3 m)) ("")))))
                                      )
                                      (Dyl:QuickDrawBandVals tiles m)
                              )
                 )
            vals (if (member (car res) (list 1 *mt:originpick*))
                   (mapcar '(lambda (x)
                              (cons (car x)
                                    (if (= 'edit (caddr x))
                                      (vl-string-trim " " (cond ((Dyl:WinGet res (car x))) ("")))
                                      (car (nth (Dyl:WinIdx res (car x)) (caddr x)))
                                    )
                              )
                            )
                           tiles
                   )
                 )
      )
      (= *mt:originpick* (car res))
    )
    ;;  Pick...: the values of the window in the material, then the origin picked:
    (foreach v vals (setq m (Remote>>Dyl:ListSubst m (cdr (assoc (car v) *mt:behaviortiles*)) (cdr v))))
    (if (setq p (Remote>>Dyl:MaterialOriginPick m))
      (foreach v p (setq m (Remote>>Dyl:ListSubst m (cdr (assoc (car v) *mt:behaviortiles*)) (cdr v))))
    )
  )
  (if (= 1 (car res))
    (progn
      (foreach v vals
        (if (and (not msg)
                 (not (and (= "mfc" (car v)) (/= "1" (cdr (assoc "msw" vals)))))
                 (not (and (member (car v) '("moa" "mof")) (/= "1" (cdr (assoc "mor" vals)))))
            )
          (setq msg (Remote>>Dyl:MaterialDlgCheck (car v) (cdr v)))
        )
      )
      (if msg (progn (alert msg) nil) vals)
    )
  )
)

;;-------------------------=={ Border Settings window }==------------------------;;

;;  The open button of Has a border (Parameters box) opens the Border Settings window
;;  (Res\Dyl-QuickDrawBorderSettings.xaml) on the border of the preset shown: its layer key
;;  and the properties of the key it overrides, the border columns of the preset (from
;;  *qd:border*, in the order of *mt:bordertiles*). The open button of Has a hatch opens the
;;  Hatch Settings window (Res\Dyl-QuickDrawHatchSettings.xaml) the same way on the hatch of
;;  the preset (from *qd:hatch*, in the order of *mt:hatchtiles*: its layer key, "" for the
;;  hatch layer key of its material, From material in the window). The open buttons of
;;  those windows close them (the layer key: the Layer Keys window, *mt:borderkeypick*; the
;;  color: the color window of AutoCAD, *mt:colorpick*), and they open again on what was
;;  picked. OK gives the values to every preset selected (see Dyl:QuickDrawDlgStatus). The same
;;  windows edit the border and the hatch of a Hatch layer of an assembly, opened by the
;;  Assembly Presets window itself (sub "1").

;;  The tiles of the Hatch Settings window with the column of their value in a preset:
(defun Dyl:QuickDrawHatchTiles (/ i)
  (setq i (1- *qd:hatch*))
  (mapcar '(lambda (x) (cons (car x) (setq i (1+ i)))) *mt:hatchtiles*)
)

;;  The values of a window of tiles (the border tiles, the hatch tiles) for the columns of the
;;  preset r, the layer keys keys ("": From material) and the layer keys defined lks:
(defun Dyl:QuickDrawPropsVals (r tiles keys lks / res)
  (foreach x tiles
    (setq res (append res
                      (cond
                        ((member (car x) '("out" "hky"))
                         (list (cons (strcat (car x) "/list")
                                     (mapcar '(lambda (k)
                                                (cond ((= "" k) "From material") ((assoc k lks) k) ((strcat k "   (not defined)")))
                                              )
                                             keys
                                     )
                               )
                               (cons (strcat (car x) "/vals") keys)
                               (cons (car x) (itoa (cond ((vl-position (nth (cdr x) r) keys)) (0))))
                         )
                        )
                        ((= "bwt" (car x))
                         (list (cons "bwt/list" (mapcar '(lambda (w) (strcat (rtos (/ (atoi w) 100.0) 2 2) " mm")) *mt:weights*))
                               (cons "bwt/vals" *mt:weights*)
                               (cons "bwt" (itoa (cond ((vl-position (nth (cdr x) r) *mt:weights*)) (0))))
                         )
                        )
                        ((list (cons (car x) (cond ((nth (cdr x) r)) (""))))))
              )
    )
  )
  res
)

;;  The window file of tiles (their first one the layer key) on the preset r. Returns its
;;  values ((column . value) ...) on OK, nil on Cancel (or when the window cannot be shown).
;;  An override on is checked again (see Remote>>Dyl:MaterialDlgCheck): one not valid is said,
;;  nothing given. The layer key of a hatch may be "" (From material), not that of a
;;  border:
(defun Dyl:QuickDrawPropsDialog (r file tiles / hatch col lks keys res k v msg)
  (setq hatch (= "hky" (caar tiles))
        col   (cdar tiles)
        lks   (Remote>>Dyl:LayerKeyRead)
        keys  (if hatch (cons "" mt:keys) mt:keys)
  )
  (while
    (progn
      (if (and (/= "" (nth col r)) (not (member (nth col r) keys)))
        (setq keys (append keys (list (nth col r))))
      )
      (setq res (Dyl:WinShow file (cons (cons "sub" "0") (Dyl:QuickDrawPropsVals r tiles keys lks))))
      (if (member (car res) (list 1 *mt:borderkeypick* *mt:colorpick*))
        (foreach x tiles
          (setq v (cond ((= col (cdr x)) (cond ((nth (Dyl:WinIdx res (car x)) keys)) ("")))
                        ((= "bwt" (car x)) (nth (Dyl:WinIdx res "bwt") *mt:weights*))
                        ((vl-string-trim " " (cond ((Dyl:WinGet res (car x))) (""))))
                  )
                r (Remote>>Dyl:ListSubst r (cdr x) (if (= "blt" (car x)) (strcase v) v))
          )
        )
      )
      (member (car res) (list *mt:borderkeypick* *mt:colorpick*))
    )
    (cond
      ((= *mt:borderkeypick* (car res))
       (if (setq k (Remote>>Dyl:LayerKeyPick (nth col r))) (setq r (Remote>>Dyl:ListSubst r col k)))
      )
      ((setq v (Remote>>Dyl:MaterialColorPick (nth (cdr (assoc "bcv" tiles)) r)))
       (setq r (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst r (cdr (assoc "bcv" tiles)) v) (cdr (assoc "bco" tiles)) "1"))
      )
    )
  )
  (if (= 1 (car res))
    (progn
      (foreach x '(("bco" . "bcv") ("blo" . "blt") ("bso" . "bsc") ("bto" . "btr"))
        (if (and (not msg) (= "1" (nth (cdr (assoc (car x) tiles)) r)))
          (setq msg (Remote>>Dyl:MaterialDlgCheck (cdr x) (nth (cdr (assoc (cdr x) tiles)) r)))
        )
      )
      (cond
        (msg (alert msg) nil)
        ((and (not hatch) (= "" (nth col r))) (alert "No layer key for the border: add one in the Layer Keys window.") nil)
        ((mapcar '(lambda (x) (cons (cdr x) (nth (cdr x) r))) tiles))
      )
    )
  )
)

;;  The Border Settings window on the preset r (see Dyl:QuickDrawPropsDialog):
(defun Dyl:QuickDrawBorderDialog (r)
  (Dyl:QuickDrawPropsDialog r "Dyl-QuickDrawBorderSettings.xaml" (Remote>>Dyl:MaterialBorderTiles *qd:border*))
)

;;  The Hatch Settings window on the preset r (see Dyl:QuickDrawPropsDialog):
(defun Dyl:QuickDrawHatchDialog (r)
  (Dyl:QuickDrawPropsDialog r "Dyl-QuickDrawHatchSettings.xaml" (Dyl:QuickDrawHatchTiles))
)

;;-------------------------=={ Layers of an assembly }==------------------------;;

;;  The layers of an assembly preset (see Remote>>Dyl:MaterialLayers) are edited in the
;;  Assembly Presets window (see below): add, edit, remove, order and flip them, in the window
;;  itself (a list of rows, Installer\Windows\Engine\Rows.cs). A Hatch layer uses a Quick Draw
;;  preset saved (a new preset gets its id once saved) that is not an assembly itself.

;;  The kinds of layers: (kind label):
(setq *qd:layerkinds* '(("P" "Hatch") ("S" "Space") ("L" "Line")))

;;  The rows of the window for the layers lst ((kind ref thickness [hatch-key [band
;;  [border [structural]]]]) ...): (kind preset thickness hatch-key line-key band... border...
;;  structural): the band settings of a Hatch layer in the columns 5 to 13 (on hatch ends
;;  extension angle corners miter lap joints; hatch: see *qd:layerhatch*), its border in 14
;;  and 15 (on key), Structural in 16 ("1": the structural layer, see
;;  Dyl:QuickDrawLayersCore), the properties its border overrides in 17 to 26 (as the border
;;  of a preset, see *mt:bordertiles*: color on, color, linetype on, linetype, linetype scale
;;  on, scale, lineweight on, lineweight, transparency on, transparency; edited in the Border
;;  Settings window), Has a hatch in 27 ("0": no hatch, the outline only) and the properties
;;  its hatch overrides in 28 to 37 (in the same order; edited with its layer key, column 3, in
;;  the Hatch Settings window). The columns a layer of its kind does not use taken from the new
;;  layer def (a row of the same columns), so that it can become another kind:
(defun Dyl:QuickDrawLayersRows (lst def)
  (mapcar '(lambda (l)
             (cond
               ((= "P" (car l))
                (append (list "P" (cadr l) (caddr l) (cond ((cadddr l)) ("")) (nth 4 def))
                        (if (nth 4 l) (Remote>>LM:sublst (nth 4 l) 0 9) (Remote>>LM:sublst def 5 9))
                        (Remote>>LM:sublst (cond ((nth 5 l)) ((Dyl:QuickDrawLayersDefBorder def))) 0 2)
                        (list (if (= "1" (nth 6 l)) "1" "0"))
                        (Remote>>LM:sublst (cond ((nth 5 l)) ((Dyl:QuickDrawLayersDefBorder def))) 2 10)
                        (Remote>>LM:sublst (cond ((nth 7 l)) ((Remote>>LM:sublst def 27 11))) 0 11)
                )
               )
               ((= "S" (car l)) (append (list "S" (nth 1 def) (caddr l) "" (nth 4 def)) (Remote>>LM:sublst def 5 nil)))
               ((append (list "L" (nth 1 def) (nth 2 def) "" (cadr l)) (Remote>>LM:sublst def 5 nil)))
             )
           )
          lst
  )
)

;;  The border of the row r of a layer (see Dyl:QuickDrawLayersRows) as the layers keep it
;;  (see Remote>>Dyl:MaterialLayers): on key, then the properties it overrides:
(defun Dyl:QuickDrawLayersDefBorder (r)
  (append (Remote>>LM:sublst r 14 2) (Remote>>LM:sublst r 17 10))
)

;;  The band settings of a layer of an assembly when they are the defaults (see
;;  Dyl:QuickDrawBandDefaults): kept off, they are not written:
(setq *qd:layerband* '("Line" "Square" "" "45" "Mitered" "4" "First" "Interrupted"))

;;  The layers of the rows of the window, each one as its kind keeps it (see
;;  Remote>>Dyl:MaterialLayers): (layers), or (nil message) for the first one not valid. The
;;  band settings of a Hatch layer when they are on, or off but not the defaults (kept for
;;  when they are on again); its border when it is on, or off on another key than the new
;;  layer def or overriding a property; "1" when it is the structural layer; its hatch (Has a
;;  hatch and the properties it overrides, see Remote>>Dyl:MaterialLayerHatchStr):
(defun Dyl:QuickDrawLayersOf (rows def / res msg b d h)
  (foreach r rows
    (setq b (Remote>>LM:sublst r 5 9)
          d (Dyl:QuickDrawLayersDefBorder r)
          h (Remote>>LM:sublst r 27 11)
    )
    (if (< (length h) 11) (setq h (Remote>>LM:sublst def 27 11)))
    (cond
      (msg)
      ((and (/= "L" (car r)) (not (Remote>>Dyl:MaterialScale-p (caddr r))))
       (setq msg "The thickness must be a number greater than 0.")
      )
      ((and (= "P" (car r)) (= "" (cadr r)))
       (setq msg "No preset to use: save the preset first (a new one gets its id once saved).")
      )
      ((and (= "P" (car r))
            (= "1" (car b))
            (setq msg (vl-some '(lambda (k v) (Remote>>Dyl:MaterialDlgCheck k v)) '("mex" "mea" "mml") (list (nth 3 b) (nth 4 b) (nth 6 b))))
       )
      )
      ((and (= "P" (car r)) (= "1" (car d)) (= "" (cadr d)))
       (setq msg "No layer key for the border: add one in the Layer Keys window.")
      )
      ((and (= "P" (car r)) (/= "1" (car d)) (= "0" (car h)))
       (setq msg "A Hatch layer has neither a hatch nor a border: check Has a hatch or Has a border, or make it a Space.")
      )
      ((and (= "P" (car r))
            (= "1" (car h))
            (setq msg (vl-some '(lambda (i k) (if (= "1" (nth i h)) (Remote>>Dyl:MaterialDlgCheck k (nth (1+ i) h))))
                               '(1 3 5 9)
                               '("bcv" "blt" "bsc" "btr")
                      )
            )
       )
      )
      ((and (= "P" (car r))
            (= "1" (car d))
            (setq msg (vl-some '(lambda (i k) (if (= "1" (nth i d)) (Remote>>Dyl:MaterialDlgCheck k (nth (1+ i) d))))
                               '(2 4 6 10)
                               '("bcv" "blt" "bsc" "btr")
                      )
            )
       )
      )
      ((= "P" (car r))
       (setq res (cons (list "P"
                             (cadr r)
                             (caddr r)
                             (cadddr r)
                             (if (or (= "1" (car b)) (not (equal (cdr b) *qd:layerband*))) b)
                             (if (or (= "1" (car d)) (/= (cadr d) (nth 15 def)) (vl-some '(lambda (i) (= "1" (nth i d))) '(2 4 6 8 10)))
                               (Remote>>Dyl:ListSubst d 5 (strcase (nth 5 d)))
                             )
                             (if (= "1" (nth 16 r)) "1")
                             (Remote>>Dyl:ListSubst h 4 (strcase (nth 4 h)))
                       )
                       res
                 )
       )
      )
      ((= "S" (car r)) (setq res (cons (list "S" "" (caddr r)) res)))
      ((= "" (nth 4 r)) (setq msg "No layer key: add one in the Layer Keys window."))
      ((setq res (cons (list "L" (nth 4 r) "") res)))
    )
  )
  (if msg (list nil msg) (list (reverse res)))
)

;;  The inches of a drawing unit (INSUNITS, else MEASUREMENT: millimeters or inches), for the
;;  preview of an assembly:
(defun Dyl:QuickDrawUnitInches (/ u)
  (setq u (getvar "INSUNITS"))
  (cond
    ((= u 1) 1.0)
    ((= u 2) 12.0)
    ((= u 4) (/ 1.0 25.4))
    ((= u 5) (/ 1.0 2.54))
    ((= u 6) (/ 1000.0 25.4))
    ((= 1 (getvar "MEASUREMENT")) (/ 1.0 25.4))
    (1.0)
  )
)

;;  The preview of the preset x (a row of pst:lst) in the preview of an assembly (see
;;  Installer\Windows\Engine\Assembly.cs): its hatch as in the Gallery (see
;;  Dyl:QuickDrawGalleryBand); its hatch scale from its thickness (Hatch scale from width), its
;;  ppu "w" and the ppu of a unit of thickness, at the drawing scale:
(defun Dyl:QuickDrawLayersSpec (x / m f)
  (if (setq m (Remote>>Dyl:MaterialGet (nth 3 x)))
    (progn
      ;;  Its hatch whatever its No hatch: a layer has its own Has a hatch (a space in the
      ;;  preview when it is off, see Rows.cs):
      (setq m (Remote>>Dyl:MaterialNoHatch (Dyl:QuickDrawMat m x) nil)
            f (Remote>>LM:str->lst (Dyl:QuickDrawGalleryBand "P" m 1.0) "?")
      )
      (if (and (= "P" (car f)) (= 7 (length f)) (= "1" (nth 37 m)))
        (setq f (Remote>>Dyl:ListSubst
                  (Remote>>Dyl:ListSubst f 4 (strcat "w" (Remote>>Dyl:MaterialNumP (/ (* (cond ((distof (nth 38 m) 2)) (1.0)) (Dyl:QuickDrawUnitInches)) (Remote>>Dyl:MaterialDrawScale)) 10)))
                  6
                  (Remote>>Dyl:MaterialNumP (Remote>>Dyl:MaterialDrawScale) 4)
                )
        )
      )
      (Remote>>LM:lst->str f "?")
    )
    "X?1"
  )
)

;;  What the hatch of a layer of an assembly is aligned to (Hatch aligned to of its own band
;;  settings): the line of the layer, its middle (Line) or its border nearer to the line of
;;  the band (Edge), the line its hatch starts on and its Angled ends turn around (see
;;  Dyl:QuickDrawLayerPivot), or the drawing origin:
(setq *qd:layerhatch* '(("Line" "Layer center") ("Edge" "Layer edge") ("Origin" "Drawing origin")))

;;  The lists of the Band Settings window of a layer (see Dyl:QuickDrawBandVals): never Ask,
;;  Hatch aligned to that of a layer (*qd:layerhatch*):
(defun Dyl:QuickDrawLayersBandLists (/ res)
  (setq res (list (cons "mht/list" (mapcar 'cadr *qd:layerhatch*)) (cons "mht/vals" (mapcar 'car *qd:layerhatch*))))
  (foreach x (cddr (assoc "BandSettings" *mt:bandwindows*))
    (if (and (/= 'edit (caddr x)) (/= "mht" (car x)))
      (setq res (append res
                        (list (cons (strcat (car x) "/list") (mapcar 'cadr (Dyl:QuickDrawNoAsk (car x) (caddr x))))
                              (cons (strcat (car x) "/vals") (mapcar 'car (Dyl:QuickDrawNoAsk (car x) (caddr x))))
                        )
                )
      )
    )
  )
  res
)

;;  The items lst of the list key of the Band Settings window of a layer, without Ask:
(defun Dyl:QuickDrawNoAsk (key lst)
  (if (= "Ask" (car (car lst))) (cdr lst) lst)
)

;;-------------------------=={ Assembly Presets window }==------------------------;;

;;  The Assembly Presets window (Res\Dyl-AssemblyPresets.xaml, shown by DynALisp.Windows.dll):
;;  a preset window of the preset engine (Remote>>Dyl:PresetDialog, spec "QuickDrawAssembly"
;;  of Remote\Dyl-QuickDrawPresets.lsp, file Res\QuickDrawAssemblies.csv), its presets the
;;  assemblies (id group name layers), opened by the open button of Assembly in the Quick
;;  Draw window on the assembly of the preset shown. The layers of the assembly shown are a list
;;  of rows of the window (Win.RowsIn: the column 4 the window gets, see Dyl:QuickDrawAsmExtra),
;;  edited in the window itself; OK gives the assembly selected to every Quick Draw preset
;;  selected. The functions below use the local variables of Dyl:QuickDrawAsmDialog: qa:qd (the
;;  presets of the Quick Draw window), qa:r (its preset shown), qa:pre (the presets of the
;;  Preset list of a layer: (id label width) ...), qa:def (the row Add starts from) and mt:keys
;;  (the layer keys of its lists).

;;  The assembly presets as saved (read again once their file changed), and the one of id:
(defun Dyl:QuickDrawAsmRead (/ f s)
  (setq f (Remote>>Dyl:PresetFile "QuickDrawAssembly")
        s (list f (vl-file-systime f))
  )
  (if (not (and *qd:asmcache* (equal s (car *qd:asmcache*))))
    (setq *qd:asmcache* (cons s (Remote>>Dyl:PresetRead "QuickDrawAssembly" nil 'Dyl:QuickDrawAsmFix)))
  )
  (cdr *qd:asmcache*)
)

(defun Dyl:QuickDrawAsmGet (id)
  (vl-some '(lambda (a) (if (= (strcase id) (strcase (car a))) a)) (Dyl:QuickDrawAsmRead))
)

;;  A row of the assemblies file: its group as in the groups, its layers those that are valid:
(defun Dyl:QuickDrawAsmFix (row)
  (setq row (Remote>>Dyl:ListSubst row 1 (Remote>>Dyl:GroupCase (nth 1 row))))
  (Remote>>Dyl:ListSubst row 3 (Remote>>Dyl:MaterialLayersStr (Remote>>Dyl:MaterialLayers (nth 3 row))))
)

;;  The layers (a text, see Remote>>Dyl:MaterialLayers) of the assembly v of a preset (its
;;  column 38, the column 60 of its material): those of the assembly preset of that id, ""
;;  when it no longer exists; in a preset of an older file, the layers themselves (they hold
;;  ":", see Dyl:QuickDrawAsmMigrate):
(defun Dyl:QuickDrawAsmLayers (v / a)
  (cond
    ((/= 'STR (type v)) "")
    ((vl-string-search ":" v) v)
    ((= "" v) "")
    ((setq a (Dyl:QuickDrawAsmGet v)) (nth 3 a))
    ("")
  )
)

;;  The presets of an older file with the layers of their assembly in their column 38 get an
;;  assembly preset of their own (named after the preset, in its group; one with the same
;;  layers is used again), its id in their column 38. Both files saved now (when the Quick
;;  Draw window opens): a file that cannot be written leaves them as they were (their layers
;;  still drawn, see Dyl:QuickDrawAsmLayers):
(defun Dyl:QuickDrawAsmMigrate (/ rows asms new l a n i nam)
  (setq rows (Dyl:QuickDrawRead))
  (if (vl-some '(lambda (r) (vl-string-search ":" (nth *qd:layerscol* r))) rows)
    (progn
      (setq asms (Dyl:QuickDrawAsmRead))
      (foreach r rows
        (setq l (nth *qd:layerscol* r))
        (if (and (vl-string-search ":" l) (not (vl-some '(lambda (x) (if (= l (nth 3 x)) x)) asms)))
          (progn
            (setq n   (nth 2 r)
                  nam n
                  i   1
            )
            (while (vl-some '(lambda (x) (= (strcase nam) (strcase (nth 2 x)))) asms)
              (setq nam (strcat n " (" (itoa (setq i (1+ i))) ")"))
            )
            (setq asms (append asms (list (list "" (nth 1 r) nam l)))
                  new  T
            )
          )
        )
      )
      (setq asms (Remote>>Dyl:PresetIds asms))
      (if (or (not new) (Remote>>Dyl:PresetWrite "QuickDrawAssembly" asms))
        (progn
          (setq *qd:asmcache* nil
                rows          (mapcar '(lambda (r / x)
                                         (setq l (nth *qd:layerscol* r))
                                         (if (and (vl-string-search ":" l) (setq x (vl-some '(lambda (y) (if (= l (nth 3 y)) y)) asms)))
                                           (Remote>>Dyl:ListSubst r *qd:layerscol* (car x))
                                           r
                                         )
                                       )
                                      rows
                              )
          )
          (if (Remote>>Dyl:PresetWrite "QuickDraw" rows)
            (princ "\nThe assemblies of the Quick Draw presets are now assembly presets (Assembly Presets window).")
          )
        )
      )
    )
  )
)

;;  What the Quick Draw window shows of the assembly of the layers text ls (the columns 54, 56,
;;  57 and 58 of a preset, see Dyl:QuickDrawWinExtra): what its layers are, their width, its
;;  preview (its layers side by side, see Dyl:QuickDrawGalleryLayers; "" without layers) and
;;  its description (see Dyl:QuickDrawLayersDesc):
(defun Dyl:QuickDrawAsmShow (ls / lst)
  (setq lst (Remote>>Dyl:MaterialLayers ls))
  (list (Remote>>Dyl:MaterialLayersText ls)
        (Remote>>Dyl:MaterialNum (apply '+ (cons 0.0 (mapcar '(lambda (l) (cond ((distof (caddr l) 2)) (0.0))) lst))))
        (if lst (Dyl:QuickDrawGalleryLayers lst) "")
        (Dyl:QuickDrawLayersDesc lst)
  )
)

;;  The rows of a layers text (see Dyl:QuickDrawLayersRows) in the column of the window that
;;  holds them (Win.RowsIn): a row on each line, its columns divided by tabs; and back:
(defun Dyl:QuickDrawAsmEncode (rows)
  (cond ((Remote>>LM:lst->str (mapcar '(lambda (r) (Remote>>LM:lst->str r "\t")) rows) "\n")) (""))
)

(defun Dyl:QuickDrawAsmDecode (str)
  (mapcar '(lambda (l) (Remote>>LM:str->lst l "\t"))
          (vl-remove-if '(lambda (l) (= "" (vl-string-trim " \t\r" l))) (Remote>>LM:str->lst str "\n"))
  )
)

;;  The column the window adds to an assembly r: its layers as rows (4). Rows got back that
;;  were not valid are kept as they were edited (their column 3 holds them, see
;;  Dyl:QuickDrawAsmWinGet):
(defun Dyl:QuickDrawAsmExtra (r)
  (list (if (vl-string-search "\t" (nth 3 r))
          (nth 3 r)
          (Dyl:QuickDrawAsmEncode (Dyl:QuickDrawLayersRows (Remote>>Dyl:MaterialLayers (nth 3 r)) qa:def))
        )
  )
)

;;  An assembly got back from the window: its layers from its rows (column 4, see
;;  Dyl:QuickDrawLayersOf), or its rows themselves in its column 3 when one is not valid (said
;;  by Dyl:QuickDrawAsmCheck, the window shown again on them):
(defun Dyl:QuickDrawAsmWinGet (r / out)
  (setq out (Dyl:QuickDrawLayersOf (Dyl:QuickDrawAsmDecode (cond ((nth 4 r)) (""))) qa:def))
  (Remote>>Dyl:ListSubst r 3 (if (cadr out) (nth 4 r) (Remote>>Dyl:MaterialLayersStr (car out))))
)

;;  Why the assembly r is not valid (nil: it is):
(defun Dyl:QuickDrawAsmCheck (r)
  (cond
    ((vl-string-search "\t" (nth 3 r)) (cadr (Dyl:QuickDrawLayersOf (Dyl:QuickDrawAsmDecode (nth 3 r)) qa:def)))
    ((not (vl-remove-if '(lambda (l) (= "L" (car l))) (Remote>>Dyl:MaterialLayers (nth 3 r))))
     "No layer with a thickness: add a Hatch or a Space layer."
    )
  )
)

;;  Before the window is shown: the presets of the Preset list of a layer (qa:pre: those of
;;  the Quick Draw window saved, with an id, that are not assemblies, by group and name, then
;;  those of the layers that no longer exist, marked), the layer keys (mt:keys: those of the
;;  layers kept when they are not defined) and the row Add starts from (qa:def: a Hatch layer
;;  of the first preset, its width, a Line on the border layer key of the Quick Draw preset;
;;  its band settings off, the defaults; its border off, on that key, overriding nothing; its
;;  hatch on, on the key of its preset, overriding nothing):
(defun Dyl:QuickDrawAsmWinPrep (/ w ls bk)
  (setq qa:pre (mapcar '(lambda (x)
                          (list (car x)
                                (strcat (nth 1 x) " - " (nth 2 x))
                                (if (setq w (car (Remote>>Dyl:MaterialWidths (nth 6 x)))) (Remote>>Dyl:MaterialNum w) "")
                          )
                        )
                       (vl-sort (vl-remove-if '(lambda (x) (or (= "" (car x)) (= "1" (nth 37 x)))) qa:qd)
                                '(lambda (a b)
                                   (< (strcase (strcat (nth 1 a) "\t" (nth 2 a))) (strcase (strcat (nth 1 b) "\t" (nth 2 b))))
                                 )
                       )
               )
        ls     (apply 'append (mapcar '(lambda (a) (Remote>>Dyl:MaterialLayers (nth 3 a))) pst:lst))
  )
  (foreach l ls
    (if (and (= "P" (car l)) (not (assoc (cadr l) qa:pre)))
      (setq qa:pre (append qa:pre (list (list (cadr l) (strcat "(missing) " (cadr l)) ""))))
    )
  )
  (Remote>>Dyl:MaterialDlgKeys nil
                               (append (mapcar '(lambda (l) (if (= "L" (car l)) (cadr l) (cadddr l))) ls)
                                       (mapcar '(lambda (l) (cadr (nth 5 l))) ls)
                               )
  )
  (setq bk     (cond ((car (member (nth *qd:border* qa:r) mt:keys))) ((car mt:keys)) (""))
        qa:def (append (list "P"
                             (cond ((car (car qa:pre))) (""))
                             (cond ((/= "" (cond ((caddr (car qa:pre))) (""))) (caddr (car qa:pre))) ("10"))
                             ""
                             bk
                             "0"
                       )
                       *qd:layerband*
                       (list "0" bk "0")
                       (Remote>>LM:sublst *mt:new* 12 10)
                       (list "1")
                       (Remote>>LM:sublst *mt:new* 12 10)
               )
  )
)

;;  The values of the window: the lists of the fields of a layer, the preview of each preset
;;  (lp/specs, see Dyl:QuickDrawLayersSpec), the ends of the whole band (ll/ends: the
;;  defaults, see Dyl:QuickDrawMat), the drawing units and scale (ll/paper), the lists of
;;  the Band Settings window of a layer (the method "Layer", see Dyl:QuickDrawLayersBandLists)
;;  and those of its Border Settings and Hatch Settings windows (sub "1": their open buttons,
;;  which close them for the Lisp, greyed out):
(defun Dyl:QuickDrawAsmWinVals (/ lks mark)
  (setq lks  (Remote>>Dyl:LayerKeyRead)
        mark (mapcar '(lambda (k) (if (assoc k lks) k (strcat k "   (not defined)"))) mt:keys)
  )
  (append (list (list "ll/new" qa:def)
                (cons "lk/list" (mapcar 'cadr *qd:layerkinds*))
                (cons "lk/vals" (mapcar 'car *qd:layerkinds*))
                (cons "lp/list" (mapcar 'cadr qa:pre))
                (cons "lp/vals" (mapcar 'car qa:pre))
                (cons "lp/widths/list" (mapcar 'caddr qa:pre))
                (cons "hky/list" (cons "From preset" mark))
                (cons "hky/vals" (cons "" mt:keys))
                (cons "ly/list" mark)
                (cons "ly/vals" mt:keys)
                (cons "out/list" mark)
                (cons "out/vals" mt:keys)
                (cons "bwt/list" (mapcar '(lambda (w) (strcat (rtos (/ (atoi w) 100.0) 2 2) " mm")) *mt:weights*))
                (cons "bwt/vals" *mt:weights*)
                (cons "sub" "1")
                (cons "lp/specs" (mapcar '(lambda (p) (cond ((assoc (car p) qa:qd) (Dyl:QuickDrawLayersSpec (assoc (car p) qa:qd))) ("X?1"))) qa:pre))
                (cons "ll/ends" (list (nth 1 *qd:layerband*) (nth 2 *qd:layerband*) (nth 3 *qd:layerband*)))
                (cons "ll/paper" (list (Remote>>Dyl:MaterialNumP (Dyl:QuickDrawUnitInches) 10) (Remote>>Dyl:MaterialNumP (Remote>>Dyl:MaterialDrawScale) 4)))
                (cons "mth" "Layer")
          )
          (Dyl:QuickDrawLayersBandLists)
          (Dyl:WinOff "lp" (not qa:pre))
          (Dyl:WinOff "ly" (not mt:keys))
          (Dyl:WinOff "out" (not mt:keys))
  )
)

;;  The Assembly Presets window, opened from the Quick Draw window (its presets qd, its preset
;;  shown r), on the assembly of r. Returns the assembly selected on OK, saved, nil on Cancel:
(defun Dyl:QuickDrawAsmDialog (qd r / qa:qd qa:r qa:pre qa:def mt:keys res)
  (setq qa:qd qd
        qa:r  r
        res   (Remote>>Dyl:PresetDialog
                "QuickDrawAssembly"
                (list '(defs)
                      (cons 'fix 'Dyl:QuickDrawAsmFix)
                      '(tiles)
                      '(groups . T)
                      '(noun . "assemblies")
                      '(window . "Dyl-AssemblyPresets.xaml")
                      (cons 'select (if (not (or (= "" (nth *qd:layerscol* r)) (vl-string-search ":" (nth *qd:layerscol* r)))) (nth *qd:layerscol* r)))
                      '(new "" "Wall" "New assembly" "")
                      '(extra . Dyl:QuickDrawAsmExtra)
                      '(wget . Dyl:QuickDrawAsmWinGet)
                      '(rowcheck . Dyl:QuickDrawAsmCheck)
                      '(wprep . Dyl:QuickDrawAsmWinPrep)
                      '(wvals . Dyl:QuickDrawAsmWinVals)
                )
              )
        *qd:asmcache* nil
  )
  res
)

;;-------------------------=={ Gallery }==------------------------;;

;;  The Quick Draw Gallery window (Pst-QuickDrawGallery, Res\Dyl-QuickDrawGallery.xaml,
;;  shown by DynALisp.Windows.dll): a tile for each preset, the preview of its hatch as it
;;  plots (drawn by the plugin from its pattern, see Dyl:QuickDrawGalleryBand), its name and
;;  its group under it. The group picked and the text searched filter the tiles in the window
;;  itself. A click draws the preset.
;;  *qd:gallerygroup*: the group to open on, set by the ribbon (the groups under the arrow of
;;  the Quick Draw button run (setq *qd:gallerygroup* "Section") Pst-QuickDrawGallery), used
;;  once; else the group shown last (*qd:gallerylast*, for the session).
;;  The functions below use the local variable qg:all of Dyl:QuickDrawGallery: the presets
;;  ((rec . mat) ...), mat: the material of the preset with its behaviors and border (see
;;  Dyl:QuickDrawMat).

;;  The group of the groups gs matching g (the ribbon gives a default group): the same name
;;  (any case), else one starting with it or that it starts with ("Floor" -> "Floors"):
(defun Dyl:QuickDrawGalleryMatch (g gs / u)
  (setq u (strcase g))
  (cond
    ((vl-some '(lambda (x) (if (= u (strcase x)) x)) gs))
    ((vl-some '(lambda (x) (if (or (wcmatch (strcase x) (strcat u "*")) (wcmatch u (strcat (strcase x) "*"))) x)) gs))
  )
)

;;  The items of the Group list: All, then every group (see Remote>>Dyl:Groups), also the
;;  ones without a preset (the gallery shows a pill only for a group with presets), a group
;;  typed in the presets file that is not one of them, then Recent:
(defun Dyl:QuickDrawGalleryGroups (/ res)
  (setq res (reverse (Remote>>Dyl:Groups)))
  (foreach x qg:all
    (if (not (member (strcase (nth 1 (car x))) (mapcar 'strcase res))) (setq res (cons (nth 1 (car x)) res)))
  )
  ;;  Recent last, when presets of the gallery were drawn in this session:
  (setq res (cons "All" (reverse res)))
  (if (vl-some '(lambda (x) (Dyl:QuickDrawGalleryRank (car x))) qg:all)
    (append res (list "Recent"))
    res
  )
)

;;  The rank of the preset rec among the presets drawn last ("1": the last one), "" when it
;;  is not one of them:
(defun Dyl:QuickDrawGalleryRank (rec / u i)
  (setq u (strcase (car rec))
        i (vl-position u (mapcar 'strcase (Dyl:QuickDrawRecent)))
  )
  (if i (itoa (1+ i)))
)

;;  The material of the preset id among the presets of the gallery (any case), nil when none:
(defun Dyl:QuickDrawGalleryMat (id)
  (vl-some '(lambda (x) (if (= (strcase id) (strcase (car (car x)))) (cdr x))) qg:all)
)

;;  A band of the preview of a tile (see Installer\Windows\Engine\Hatch.cs), w wide: kind
;;  "P" the hatch of the material mat (nil: missing, crossed out), "S" a space, "L" a line.
;;  A hatch: "P?w?pattern?file?ppu?angle?scale", ppu the inches on paper of one unit of its
;;  pattern: its scale in inches (a metric pattern: in mm), divided by the drawing scale
;;  unless it keeps its size on paper (annotative or adaptive scaling: a Drafting hatch
;;  preset; a Model one never does), as it plots:
(defun Dyl:QuickDrawGalleryBand (kind mat w / pat u s ds)
  (setq w (Remote>>Dyl:MaterialNumP w 6))
  (cond
    ((member kind '("S" "L")) (strcat kind "?" w))
    ((not mat) (strcat "X?" w))
    ;;  No hatch (see *mt:nohatch*): a space, outlined when it has a border:
    ((= "1" (nth *mt:nohatch* mat)) (strcat "S?" w))
    ((= "SOLID" (setq pat (strcase (nth 3 mat)))) (strcat "F?" w))
    (T
     (setq u  (Remote>>Dyl:MaterialPatUnits pat)
           s  (cond ((distof (nth 4 mat) 2)) (1.0))
           ds (if (or (= "1" (nth 9 mat)) (= "1" (nth 10 mat))) 1.0 (Remote>>Dyl:MaterialDrawScale))
     )
     (if (= "Metric" (car u)) (setq s (/ s 25.4)))
     (strcat "P?" w "?" pat "?" (cond ((cdr u)) ("")) "?" (Remote>>Dyl:MaterialNumP (/ s ds) 8)
             "?" (Remote>>Dyl:MaterialNumP (cond ((distof (nth 6 mat) 2)) (0.0)) 4)
             "?" (Remote>>Dyl:MaterialNumP ds 4)
     )
    )
  )
)

;;  The preview of the preset x ((rec . mat), see qg:all), as the gallery and the Quick Draw
;;  window show it: its bands (Dyl:QuickDrawGalleryBands), outlined ("O*" first, see
;;  Installer\Windows\Engine\Hatch.cs) when it has a border (an assembly never: its layers
;;  have their own):
(defun Dyl:QuickDrawGallerySpec (x)
  (strcat (if (and (/= "1" (nth *qd:noborder* (car x))) (not (Dyl:QuickDrawDlgAssembly-p (car x)))) "O*" "")
          (Dyl:QuickDrawGalleryBands x)
  )
)

;;  The bands of the preview of the preset x: an assembly (Linear, its Assembly checked) as
;;  the layers of its assembly preset (see Dyl:QuickDrawGalleryLayers); any other preset as
;;  its hatch. The bands divided by "*":
(defun Dyl:QuickDrawGalleryBands (x / rec ls)
  (setq rec (car x))
  (if (and (= "1" (nth 37 rec)) (setq ls (Remote>>Dyl:MaterialLayers (Dyl:QuickDrawAsmLayers (nth *qd:layerscol* rec)))))
    (Dyl:QuickDrawGalleryLayers ls)
    (Dyl:QuickDrawGalleryBand "P" (cdr x) 1.0)
  )
)

;;  The layers ls of an assembly side by side (see Remote>>Dyl:MaterialLayers), each band the
;;  hatch of its own preset (qg:all; a space without Has a hatch), a layer with a border of its
;;  own between two lines:
(defun Dyl:QuickDrawGalleryLayers (ls / res b m)
  (foreach l ls
    (setq b   (Dyl:QuickDrawGalleryBand
                (if (and (= "P" (car l)) (= "0" (car (nth 7 l)))) "S" (car l))
                (if (and (= "P" (car l)) (setq m (Dyl:QuickDrawGalleryMat (cadr l)))) (Remote>>Dyl:MaterialNoHatch m nil))
                (if (= "L" (car l)) 0.0 (cond ((distof (caddr l) 2)) (0.0)))
              )
          res (if (= "1" (car (nth 5 l))) (append (list "L?0" b "L?0") res) (cons b res))
    )
  )
  (setq res (reverse res))
  (apply 'strcat (cons (car res) (mapcar '(lambda (b) (strcat "*" b)) (cdr res))))
)

;;  The kind of the preset x ((rec . mat), see qg:all), for the kind pills of the gallery:
;;  Assembly, else the type of its material (Drafting, Model, see *mt:types*):
(defun Dyl:QuickDrawGalleryKind (x)
  (cond
    ((Dyl:QuickDrawDlgAssembly-p (car x)) "Assembly")
    ((= "Model" (nth 63 (cdr x))) "Model")
    ("Drafting")
  )
)

;;  The methods the preset rec can be drawn with, for the method pills of the gallery: Linear
;;  and Offset for an assembly (its layers are bands), else Ask when drawn ("") and every
;;  method of *qd:modes*:
(defun Dyl:QuickDrawGalleryMethods (rec)
  (if (Dyl:QuickDrawDlgAssembly-p rec)
    '("Linear" "Offset")
    (cons "" (mapcar 'car *qd:modes*))
  )
)

;;  The Quick Draw Gallery window. Returns the preset double-clicked (or selected on Draw),
;;  its method the one picked in the gallery (drawn by the caller), nil when closed; the Quick
;;  Draw Manager button opens the Quick Draw window in its place:
(defun Dyl:QuickDrawGallery (/ qg:all qg:grps g mat mats res sta i m)
  ;;  The materials read once (Remote>>Dyl:MaterialGet would read the file for each preset):
  (setq mats (Remote>>Dyl:MaterialRead))
  (foreach r (Dyl:QuickDrawRead)
    (if (setq mat (assoc (nth 3 r) mats))
      (setq qg:all (cons (cons r (Dyl:QuickDrawMat mat r)) qg:all))
    )
  )
  (setq qg:all  (reverse qg:all)
        qg:grps (Dyl:QuickDrawGalleryGroups)
        g       *qd:gallerygroup*
  )
  ;;  The group asked by the ribbon (once), else the one shown last:
  (setq *qd:gallerygroup* nil
        g                 (cond
                            ((not g) (cond ((Dyl:QuickDrawGalleryMatch (cond (*qd:gallerylast*) ("All")) qg:grps)) ("All")))
                            ((Dyl:QuickDrawGalleryMatch g qg:grps))
                            (T (princ (strcat "\nNo Quick Draw group " g ": all the presets are shown.")) "All")
                          )
        res               (Dyl:WinShow "Dyl-QuickDrawGallery.xaml"
                                       (append (Dyl:WinList "grp" qg:grps (cond ((vl-position g qg:grps)) (0)))
                                               (list (cons "gal/kinds/list" '("Drafting" "Model" "Assembly"))
                                                     ;;  The methods: value, label, tooltip:
                                                     (cons "gal/methods/list"
                                                           (cons "\tAsk\tAsk when drawn"
                                                                 (mapcar '(lambda (x) (strcat (car x) "\t" (car x) "\t" (cadr x))) *qd:modes*)
                                                           )
                                                     )
                                                     (cons "gal/list"
                                                           (mapcar '(lambda (x) (strcat (nth 2 (car x)) "\t" (nth 1 (car x)) "\t" (Dyl:QuickDrawGallerySpec x)
                                                                                   "\t" (cond ((Dyl:QuickDrawGalleryRank (car x))) (""))
                                                                                   "\t" (Dyl:QuickDrawGalleryKind x)
                                                                                   "\t" (Remote>>LM:lst->str (Dyl:QuickDrawGalleryMethods (car x)) ",")
                                                                                   "\t" (nth 4 (car x))))
                                                                   qg:all
                                                           )
                                                     )
                                               )
                                       )
                          )
  )
  (if res
    (setq sta               (car res)
          *qd:gallerylast*  (nth (Dyl:WinIdx res "grp") qg:grps)
          i                 (atoi (cond ((Dyl:WinGet res "gal")) ("-1")))
          m                 (Dyl:WinGet res "gal.method")
    )
  )
  (cond
    ((= 2 sta) (Dyl:QuickDrawDialog))
    ((and (= 1 sta) (<= 0 i) (< i (length qg:all)))
     ;;  The method picked, when the preset can be drawn with it (else its own):
     (if (and m (member m (Dyl:QuickDrawGalleryMethods (car (nth i qg:all)))))
       (Remote>>Dyl:ListSubst (car (nth i qg:all)) 4 m)
       (car (nth i qg:all))
     )
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

;; Quick Draw Gallery
;; Opens the gallery of the quick draw presets by group and kind, and draws the one
;; double-clicked with the method picked.

(defun c:Pst-QuickDrawGallery (/ rec)
  (if (setq rec (Dyl:QuickDrawGallery)) (Dyl:QuickDrawRun rec))
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
