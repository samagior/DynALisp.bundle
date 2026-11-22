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
      (if (= "Interrupted" (nth 6 opt)) (foreach j (caddr g) (grdraw (car j) (cadr j) -1 0)))
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
       (initget "Center Edge")
       (if (setq q (getkword (strcat "\nLine on the [Center/Edge] <" jus ">: "))) (setq jus q))
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
  ;;  Ask when drawn: the last justification given by default (saved with setenv):
  (if (= "Ask" jus)
    (progn
      (setq jus (if (member (getenv "DynalispQuickDrawJustify") '("Center" "Edge"))
                  (getenv "DynalispQuickDrawJustify")
                  "Center"
                )
      )
      (initget "Center Edge")
      (if (setq q (getkword (strcat "\nLine on the [Center/Edge] <" jus ">: "))) (setq jus q))
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
;;  is empty); Angled: turned around a; Round: on the half circle across the whole band:
(defun Dyl:QdEndPt (a u d bd w opt start / k e dc)
  (setq k (car opt)
        e 0.0
  )
  (cond
    ((= "Extended" k) (setq e (cond ((cadr opt)) ((/ w 2.0)))))
    ((= "Angled" k) (setq e (* d (/ (sin (caddr opt)) (cos (caddr opt))))))
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
;;  two sides apart when the ends are Open); joints, the joint at each corner ((a b) ...):
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
  (list (reverse pcs) un brd (mapcar '(lambda (x) (nth 4 x)) cors))
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

;;  The geometry of the band of the line pp (see Dyl:QdBandOne) made of the layers lays,
;;  ((dl dr) ...) from its left border to its right one, options opt, and the lines at the
;;  distances offs from the line. Every layer turns its corners and ends as the whole band
;;  does, so they meet. Returns (layers borders joints lines): layers, the pieces and unions
;;  of each layer ((pieces unions) ...); borders, the border of the whole band; joints, the
;;  joints of every layer; lines, ((path closed) ...) for offs:
(defun Dyl:QdBandLayers (pp closed lays opt offs / bd w np n i us trims res)
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
  (setq us (reverse us)
        i  0
  )
  (repeat (if closed n (1- n))
    (setq trims (cons (Dyl:QdTrim (nth (rem (1+ i) np) pp) (nth i us) (nth (rem (1+ i) n) us) (car bd) (cadr bd) w opt) trims)
          i     (1+ i)
    )
  )
  (setq trims (reverse trims)
        res   (mapcar '(lambda (ly) (Dyl:QdBandOne pp closed us trims (car ly) (cadr ly) bd w opt)) lays)
  )
  (list (mapcar '(lambda (x) (list (car x) (cadr x))) res)
        (caddr (if (cdr lays) (Dyl:QdBandOne pp closed us trims (car bd) (cadr bd) bd w opt) (car res)))
        (apply 'append (mapcar 'cadddr res))
        (mapcar '(lambda (d) (Dyl:QdLineAt pp closed us trims d bd w opt)) offs)
  )
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
;;  none when it has no border. A border with a key (a Line layer of an assembly) is on that
;;  layer key, its properties ByLayer, drawn even without border:
(defun Dyl:QuickDrawBorderMake (mat / ss nob e k)
  (setq nob (= "1" (nth 31 mat))
        ss  (ssadd)
  )
  (foreach b qd:borders
    (if (and (or (cadddr b) (not nob)) (setq e (Dyl:QdPline (car b) (cadr b) (caddr b))))
      (if (cadddr b)
        (Remote>>Dyl:LayerKeyApply e (cadddr b))
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
      (k (Remote>>Dyl:LayerKeyApply e k) (ssadd e ss))
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

;;-------------------------=={ Assembly }==------------------------;;

;;  An assembly makes the band of Linear of several layers side by side (a wall: gypsum,
;;  studs and insulation, sheathing, an air space, brick...), from its left border to its
;;  right one looking from the start point: the layers of the preset (see
;;  Remote>>Dyl:MaterialLayers, edited in the Assembly Layers window). A Hatch layer is a
;;  band of its thickness hatched as its Quick Draw preset says: its hatch preset, its hatch
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

;;  The layers of the assembly of the material mat (its behaviors, see Dyl:QuickDrawMat), nil
;;  when its assembly is off or has no thickness: ((kind thickness mat key name) ...). A Hatch
;;  layer (P) has the material of its preset with the behaviors of that preset, its name;
;;  a Line layer (L) its layer key and no thickness. A Hatch layer whose preset no longer
;;  exists is drawn as a space (S), with a message:
(defun Dyl:QuickDrawLayersGet (mat / res rec m w)
  (if (= "1" (nth 59 mat))
    (progn
      (foreach l (Remote>>Dyl:MaterialLayers (nth *mt:layerscol* mat))
        (setq w (cond ((distof (caddr l) 2)) (0.0)))
        (cond
          ((= "L" (car l)) (setq res (cons (list "L" 0.0 nil (cadr l) "") res)))
          ((= "S" (car l)) (setq res (cons (list "S" w nil nil "") res)))
          ((and (setq rec (Dyl:QuickDrawGet (cadr l))) (setq m (Remote>>Dyl:MaterialGet (nth 3 rec))))
           (setq m (Dyl:QuickDrawMat m rec))
           ;;  The layer's own hatch layer key, in place of the one of its preset (index 8):
           (if (and (cadddr l) (/= "" (cadddr l))) (setq m (Remote>>Dyl:ListSubst m 8 (cadddr l))))
           (setq res (cons (list "P" w m nil (nth 2 rec)) res))
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

;;  What the layer l is, for the messages:
(defun Dyl:QuickDrawLayerName (l)
  (cond
    ((= "P" (car l)) (nth 4 l))
    ((= "S" (car l)) "a space")
    ((strcat "a line (" (cadddr l) ")"))
  )
)

;;  The layers qd:layers across the band of the line pp (closed: the last point joins the
;;  first), justification jus, options opt: from the left border of the band to its right one
;;  (Center), from the line toward the band when the line is a border ("Right": the band on
;;  its left, the layers then the other way). Returns (g bands sides keys): g, the geometry of
;;  the bands of the Hatch and Space layers (see Dyl:QdBandLayers), with their lines: the
;;  joins of two of them (but where a Line layer is), then the Line layers; bands, those
;;  layers; sides, their borders ((dl dr) ...); keys, the layer key of each line (nil: the
;;  border of the preset):
(defun Dyl:QuickDrawLayersBand (pp closed jus opt / cur lays bands lnat joins lines keys)
  (setq cur (car (Dyl:QuickDrawSides (Dyl:QuickDrawLayersWidth qd:layers) jus)))
  (foreach l (if (= "Right" jus) (reverse qd:layers) qd:layers)
    (if (= "L" (car l))
      (setq lines (cons cur lines)
            keys  (cons (cadddr l) keys)
            lnat  (cons cur lnat)
      )
      (progn
        (if (and bands (not (vl-some '(lambda (x) (equal x cur 1e-9)) lnat))) (setq joins (cons cur joins)))
        (setq lays  (cons (list cur (- cur (cadr l))) lays)
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
;;  without border (the borders are drawn apart). The hatch origin of the layer: on its
;;  center (its preset on Center), or on its border nearer to the line of the band (Edge),
;;  moved into the layer by its offset:
(defun Dyl:QuickDrawLayerHatch (pp geo ly sd sep line z / m sc mid d aln)
  (setq m   (caddr ly)
        sc  (if (= "1" (nth 37 m)) (* (cadr ly) (cond ((distof (nth 38 m) 2)) (1.0))))
        mid (/ (+ (car sd) (cadr sd)) 2.0)
        d   (* (cond ((distof (nth 40 m) 2)) (0.0)) (cond (sc) (1.0)))
        ;;  Across: from the center or the border of the layer, then into it (positive: to
        ;;  the left of the line from the center):
        d   (cond
              ((not (member (nth 35 m) '("Edge" "Left" "Right"))) (+ mid d))
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
;;  each Hatch layer; the border of the band, the joins of its layers, its Line layers and
;;  its joints (Interrupted) go to qd:borders, drawn after the hatches (see
;;  Dyl:QuickDrawBorderMake):
(defun Dyl:QuickDrawLayersSegs (pp closed jus z / opt sep line r g res)
  (setq opt  (cond (qd:opt) ((Dyl:QuickDrawBandDefaults)))
        sep  (= "Interrupted" (nth 6 opt))
        line (= "Line" (nth 7 opt))
        r    (Dyl:QuickDrawLayersBand pp closed jus opt)
        g    (car r)
  )
  (mapcar '(lambda (geo ly sd)
             (if (= "P" (car ly)) (setq res (append res (Dyl:QuickDrawLayerHatch pp geo ly sd sep line z))))
           )
          (car g)
          (cadr r)
          (caddr r)
  )
  (setq qd:borders (append qd:borders
                           (mapcar '(lambda (x) (list (car x) (cadr x) z)) (cadr g))
                           (mapcar '(lambda (x k) (list (car x) (cadr x) z k)) (cadddr g) (cadddr r))
                           (if sep
                             (mapcar '(lambda (j) (list (list (cons (car j) 0.0) (cons (cadr j) 0.0)) nil z)) (caddr g))
                           )
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
;;  hatched with the angle of its hatch preset (from the drawing origin with Drawing origin);
;;  the curves are the borders of the band (its edges and the joins of its layers, the Line
;;  layers on their layer key), with lines across its ends but Open (qd:borderents). Returns
;;  ((outlines angle origin T fixed mat scale) ...) as Dyl:QuickDrawLayerHatch, nil with a
;;  message when the curves cannot be made:
(defun Dyl:QuickDrawCurveLayers (e p / w k smp org pl we cums crvs ok res c a b q ln lst ends m sc)
  (setq w   (Dyl:QuickDrawLayersWidth qd:layers)
        org (= "Origin" (nth 7 qd:opt))
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
            (setq a  (car (Dyl:QuickDrawOffsetCurve (cdr (assoc (car bd) crvs)) 0.0))
                  b  (car (Dyl:QuickDrawOffsetCurve (cdr (assoc (cadr bd) crvs)) 0.0))
                  m  (caddr (caddr bd))
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
        (setq ln (vl-remove-if-not '(lambda (y) (equal (car y) (car x) 1e-9)) (cadr pl)))
        (cond
          ((or (equal (car x) 0.0 1e-9) (equal (car x) we 1e-9))
           (setq lst (cons (cdr x) lst))
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
          ((setq lst (cons (cdr x) lst)))
        )
      )
      ;;  The lines across the ends of an open object, but Open:
      (if (and (not (vlax-curve-isClosed e)) (/= "Open" (car qd:opt)))
        (progn
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
    (alert (strcat "\nError: the hatch preset of the preset \""
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
;;  The assembly (Linear): on/off, then its layers (index 38, a text, see
;;  Remote>>Dyl:MaterialLayers), edited in the Assembly Layers window, not a tile.
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
;;  of the Quick Draw window (what the hatch is aligned to is shown there all the same, hidden,
;;  for the rules of the hatch origin: mht in wtiles of Dyl:QuickDrawDialog):
(setq *qd:subtiles* '("mjs" "mht" "men" "mex" "mea" "mco" "mml" "mlt" "mjo" "meo" "mcn"))

;;  The layers of the assembly in a preset (see Remote>>Dyl:MaterialLayers):
(setq *qd:layerscol* 38)

;;  Custom band settings (Behaviors box): on, the bands of Linear and Offset are drawn with the
;;  justification, hatch alignment, ends and corners of the Band Settings window; off, with
;;  the defaults (Center, Line, Square, Mitered), the values of the window kept for when it is
;;  on again (see Dyl:QuickDrawMat). Ends-on and corners-on (39, 40) follow it. A preset of an
;;  older file, without it, gets it on when its band was not the defaults (Dyl:QuickDrawFix):
(setq *qd:bandon* 41)

;;  The border of a preset: its columns from 17 (the layer key, then its optional settings,
;;  see Remote>>Dyl:MaterialBorderTiles), No border at 28:
(setq *qd:border* 17
      *qd:noborder* 28
)

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
;;  and 62), else the defaults (justification Center, hatch along the line, ends and corners
;;  off, see Dyl:QuickDrawBandOpts):
(defun Dyl:QuickDrawMat (mat r / on)
  (setq on  (= "1" (nth *qd:bandon* r))
        mat (Dyl:QuickDrawMatRaw mat r)
        mat (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst mat 61 (if on "1" "0")) 62 (if on "1" "0"))
  )
  (if on mat (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst mat 35 "Center") 58 "Line"))
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

;;  A row of the presets file with its 42 columns (the band, assembly, ends, corners and
;;  Custom band settings columns of an older file: empty, given their defaults by
;;  Dyl:QuickDrawFix; ends and corners on when they are not the defaults, see
;;  Remote>>Dyl:MaterialFix):
(defun Dyl:QuickDrawPad (row)
  (while (< (length row) 42) (setq row (append row (list ""))))
  row
)

;;  Values of a row of the presets file: the behaviors checked as those of a material (see
;;  Remote>>Dyl:MaterialFix). A preset of an older file drawn with the behaviors of its
;;  material (Override "0", or no Override column: written before the presets had
;;  behaviors) gets those of its material (the material as edited), and keeps a method of
;;  its own when it had one; Override is then "1". A preset of a file without the border
;;  columns (no outline key) gets the border of its material. Its group as in the groups
;;  (any case; a group not listed there is kept, as in the Hatch Presets window):
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
  (Dyl:QuickDrawBandFix row)
)

;;  Custom band settings of the preset row ("1" or "0"), ends-on and corners-on (39, 40) the
;;  same. A preset of an older file, without it, gets it on when its band was not drawn as the
;;  defaults (its own ends or corners, a justification other than Center, the hatch from the
;;  drawing origin), the ends or corners it did not have of its own set to the defaults, so it
;;  draws as before:
(defun Dyl:QuickDrawBandFix (row / on)
  (if (member (nth *qd:bandon* row) '("0" "1"))
    (setq on (= "1" (nth *qd:bandon* row)))
    (progn
      (setq on (or (= "1" (nth 39 row))
                   (= "1" (nth 40 row))
                   (not (member (nth 7 row) '("Center" "")))
                   (= "Origin" (nth 36 row))
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
;;  values are the hatch preset of the preset, its behaviors (the Behaviors box) and its border
;;  (the Border box), tiles *qd:tiles*, edited in the window itself. Its open buttons close it
;;  with their code (the Band Settings window, Pick..., the Assembly Layers window, the
;;  Layer Keys window, the color of AutoCAD), see Dyl:QuickDrawDlgStatus; then it opens again.
;;  The functions below use the local variables of Remote>>Dyl:PresetDialog (pst:lst,
;;  pst:idx, pst:mats) and those of Dyl:QuickDrawDialog: mt:keys (the layer keys of the
;;  border list), qg:all (the presets with their material, for the previews, as in the
;;  Gallery, see Dyl:QuickDrawGallerySpec).

;;  Error message of an invalid behavior, nil when it is valid (as in the Hatch Presets
;;  window): the values got back from the window are checked again before they are saved:
(defun Dyl:QuickDrawDlgCheck (key val)
  (if (assoc key *qd:tiles*) (Remote>>Dyl:MaterialDlgCheck key val))
)

;;  Material of the preset r in the window (pst:mats), the defaults when it no longer exists:
(defun Dyl:QuickDrawDlgMat (r)
  (cond ((assoc (nth 3 r) pst:mats)) (*qd:matnew*))
)

;;  T when the preset r is drawn as an assembly (Linear, Offset, or a method asked when drawn):
(defun Dyl:QuickDrawDlgAssembly-p (r)
  (and (member (nth 4 r) '("Linear" "Offset" "")) (= "1" (nth 37 r)))
)

;;  The width of the layers of the preset r, as text:
(defun Dyl:QuickDrawDlgLayersWidth (r)
  (Remote>>Dyl:MaterialNum
    (apply '+ (cons 0.0 (mapcar '(lambda (l) (cond ((distof (caddr l) 2)) (0.0))) (Remote>>Dyl:MaterialLayers (nth *qd:layerscol* r)))))
  )
)

;;  The columns the window shows after those of a preset r (42 to 45, read only, never saved):
;;  what its layers are (beside Assembly of layers), its own justification, ends and corners
;;  (under Custom band settings, shown while it is on), the width of its layers (Width, for an
;;  assembly), and the preview of its layers side by side (an assembly with layers):
(defun Dyl:QuickDrawWinExtra (r)
  (list (Remote>>Dyl:MaterialLayersText (nth *qd:layerscol* r))
        (Remote>>Dyl:MaterialBandText (Dyl:QuickDrawMat (Dyl:QuickDrawDlgMat r) (Remote>>Dyl:ListSubst r *qd:bandon* "1")))
        (Dyl:QuickDrawDlgLayersWidth r)
        ;;  (as an assembly even while Assembly of layers is off: the window shows it once it is on)
        (if (Remote>>Dyl:MaterialLayers (nth *qd:layerscol* r)) (Dyl:QuickDrawGallerySpec (list (Remote>>Dyl:ListSubst r 37 "1"))) "")
  )
)

;;  The preview of a hatch preset mat, as it plots (see Dyl:QuickDrawGalleryBand):
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
;;  (key/vals): the methods, the layer keys (marked when they are not defined), the
;;  lineweights. What the hatch is aligned to (mht, hidden) has no list: a rule reads its key:
(defun Dyl:QuickDrawWinVals (/ lks)
  (setq lks (Remote>>Dyl:LayerKeyRead))
  (list (cons "mth/list" (mapcar 'cadr (cons '("" "Ask when drawn") *mt:methods*)))
        (cons "mth/vals" (cons "" (mapcar 'car *mt:methods*)))
        (cons "out/list" (mapcar '(lambda (k) (if (assoc k lks) k (strcat k "   (not defined)"))) mt:keys))
        (cons "out/vals" mt:keys)
        (cons "bwt/list" (mapcar '(lambda (w) (strcat (rtos (/ (atoi w) 100.0) 2 2) " mm")) *mt:weights*))
        (cons "bwt/vals" *mt:weights*)
  )
)

;;  The open buttons of the window (code sta, the preset shown r). Pick...: the hatch origin
;;  picked on a sample band of its material with its behaviors, put in the presets selected
;;  (see Remote>>Dyl:MaterialOriginPick). The open button of the assembly: the Assembly Layers
;;  window, its layers given to every preset selected on OK (see Remote>>Dyl:PresetDlgPut).
;;  The open button of the border layer key: the Layer Keys window (see
;;  Remote>>Dyl:MaterialDlgBorderStatus). The open button of the border color: the color
;;  window of AutoCAD:
(defun Dyl:QuickDrawDlgStatus (sta r / v i)
  (if (= *mt:originpick* sta) (Remote>>Dyl:MaterialOriginPick (Dyl:QuickDrawMat (Dyl:QuickDrawDlgMat r) r) *qd:tiles*))
  (if (and (= *mt:layerspick* sta) (setq v (Dyl:QuickDrawLayersDialog r)))
    (Remote>>Dyl:PresetDlgPut *qd:layerscol* v)
  )
  ;;  The open button of Custom band settings: its window, its values given to every preset
  ;;  selected on OK:
  (if (and (= *mt:bandpick* sta) (setq v (Dyl:QuickDrawBandDialog r)))
    (foreach p v (Remote>>Dyl:PresetDlgPut (cdr (assoc (car p) *qd:behaviors*)) (cdr p)))
  )
  (if (and (= *mt:colorpick* sta) (setq i (cdr (assoc "bcv" *qd:tiles*)) v (Remote>>Dyl:MaterialColorPick (nth i r))))
    (Remote>>Dyl:PresetDlgPut i v)
  )
  (Remote>>Dyl:MaterialDlgBorderStatus sta r *qd:border*)
  nil
)

;;  Show the Quick Draw window. Draw and Save write the presets file and the aliases.
;;  Returns the preset to draw, or nil on Save / Cancel:
(defun Dyl:QuickDrawDialog (/ mt:keys qg:all)
  (Remote>>Dyl:PresetDialog
    "QuickDraw"
    (list (cons 'defs *qd:defaults*)
          (cons 'fix 'Dyl:QuickDrawFix)
          (cons 'tiles *qd:tiles*)
          ;;  The Group list of the Hatch Presets window (the other groups used by a preset are
          ;;  added to it):
          '(groups . T)
          '(material . 3)
          '(upper "out" "blt")
          '(window . "Dyl-QuickDraw.xaml")
          ;;  Has a border (No border, inverted), Custom band settings, the columns of
          ;;  Dyl:QuickDrawWinExtra, and what the hatch is aligned to (hidden, for the rules):
          '(wtiles . "hbr:28:inv,mbs:41,mai:42,mei:43,mwl:44,mht:36")
          '(extra . Dyl:QuickDrawWinExtra)
          ;;  The preview of an assembly: its layers side by side:
          '(spec 45 . "mas,mth=Linear|Offset|")
          '(mspec . Dyl:QuickDrawWinMatSpec)
          ;;  The text put in the new alias box: PL- for a preset drawn with a polyline, QD- for
          ;;  the others (see CONVENTIONS.md, Preset aliases):
          '(wprefix . "4|Polyline=PL-|*=QD-")
          '(wprep . Dyl:QuickDrawWinPrep)
          '(wvals . Dyl:QuickDrawWinVals)
          ;;  A new preset: the defaults of a new preset for its behaviors:
          (cons 'new (Dyl:QuickDrawFix (Dyl:QuickDrawOverride (Dyl:QuickDrawPad '("" "" "New preset" "mt-Brick" "")) T nil)))
          '(check . Dyl:QuickDrawDlgCheck)
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
;;  nil on Cancel (or when the window cannot be shown). The method of the preset (mth, no control: the justification is
;;  for Linear) is given with them. The values are checked again (see
;;  Remote>>Dyl:MaterialDlgCheck): one not valid is said, nothing given:
(defun Dyl:QuickDrawBandDialog (r / tiles m res vals msg)
  (setq tiles (cddr (assoc "BandSettings" *mt:bandwindows*))
        m     (Dyl:QuickDrawMatRaw (Dyl:QuickDrawDlgMat r) r)
        res   (Dyl:WinShow "Dyl-QuickDrawBandSettings.xaml"
                           (cons (cons "mth" (cond ((nth 4 r)) (""))) (Dyl:QuickDrawBandVals tiles m))
              )
  )
  (if (= 1 (car res))
    (progn
      (setq vals (mapcar '(lambda (x)
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
      (foreach v vals (if (not msg) (setq msg (Remote>>Dyl:MaterialDlgCheck (car v) (cdr v)))))
      (if msg (progn (alert msg) nil) vals)
    )
  )
)

;;-------------------------=={ Assembly Layers window }==------------------------;;

;;  The open button of Assembly of layers (Behaviors box) opens the Assembly Layers window
;;  (Res\Dyl-AssemblyLayers.xaml, shown by DynALisp.Windows.dll) on the layers of the preset
;;  shown (see Remote>>Dyl:MaterialLayers): add, edit, remove, order and flip them, in the
;;  window itself (a list of rows, Installer\Windows\Engine\Rows.cs); OK gives them to every
;;  preset selected. A Hatch layer uses a Quick Draw preset saved (a new preset gets its id
;;  once saved) that is not an assembly itself.

;;  The kinds of layers: (kind label):
(setq *qd:layerkinds* '(("P" "Hatch") ("S" "Space") ("L" "Line")))

;;  The rows of the window for the layers lst ((kind ref thickness [hatch-key]) ...): (kind
;;  preset thickness hatch-key line-key), the columns a layer of its kind does not use taken
;;  from the new layer def (a row of the same columns), so that it can become another kind:
(defun Dyl:QuickDrawLayersRows (lst def)
  (mapcar '(lambda (l)
             (cond
               ((= "P" (car l)) (list "P" (cadr l) (caddr l) (cond ((cadddr l)) ("")) (nth 4 def)))
               ((= "S" (car l)) (list "S" (nth 1 def) (caddr l) "" (nth 4 def)))
               ((list "L" (nth 1 def) (nth 2 def) "" (cadr l)))
             )
           )
          lst
  )
)

;;  The layers of the rows of the window, each one as its kind keeps it (see
;;  Remote>>Dyl:MaterialLayers): (layers), or (nil message) for the first one not valid:
(defun Dyl:QuickDrawLayersOf (rows / res msg)
  (foreach r rows
    (cond
      (msg)
      ((and (/= "L" (car r)) (not (Remote>>Dyl:MaterialScale-p (caddr r))))
       (setq msg "The thickness must be a number greater than 0.")
      )
      ((and (= "P" (car r)) (= "" (cadr r)))
       (setq msg "No preset to use: save the preset first (a new one gets its id once saved).")
      )
      ((= "P" (car r)) (setq res (cons (list "P" (cadr r) (caddr r) (cadddr r)) res)))
      ((= "S" (car r)) (setq res (cons (list "S" "" (caddr r)) res)))
      ((= "" (nth 4 r)) (setq msg "No layer key: add one in the Layer Keys window."))
      ((setq res (cons (list "L" (nth 4 r) "") res)))
    )
  )
  (if msg (list nil msg) (list (reverse res)))
)

;;  The Assembly Layers window on the layers of the preset r (see Remote>>Dyl:MaterialLayers),
;;  the presets of the Quick Draw window (pst:lst, local of Remote>>Dyl:PresetDialog) for its
;;  Preset list: those saved (with an id) but r, not assemblies, sorted by group and name, then
;;  the presets of its layers that no longer exist (marked). Shown again on the layers edited
;;  while one is not valid. Returns the text of the layers on OK (see
;;  Remote>>Dyl:MaterialLayersStr), nil on Cancel:
(defun Dyl:QuickDrawLayersDialog (r / lst pre lks mark def rows sel res out w)
  (setq lst (Remote>>Dyl:MaterialLayers (nth *qd:layerscol* r))
        pre (mapcar '(lambda (x)
                       (list (car x)
                             (strcat (nth 1 x) " - " (nth 2 x))
                             (if (setq w (car (Remote>>Dyl:MaterialWidths (nth 6 x)))) (Remote>>Dyl:MaterialNum w) "")
                       )
                     )
                    (vl-sort (vl-remove-if '(lambda (x) (or (= "" (car x)) (= (car x) (car r)) (= "1" (nth 37 x)))) pst:lst)
                             '(lambda (a b)
                                (< (strcase (strcat (nth 1 a) "\t" (nth 2 a))) (strcase (strcat (nth 1 b) "\t" (nth 2 b))))
                              )
                    )
            )
  )
  (foreach l lst
    (if (and (= "P" (car l)) (not (assoc (cadr l) pre)))
      (setq pre (append pre (list (list (cadr l) (strcat "(missing) " (cadr l)) ""))))
    )
  )
  ;;  The layer keys, those of the layers kept when they are not defined (marked):
  (Remote>>Dyl:MaterialDlgKeys nil (mapcar '(lambda (l) (if (= "L" (car l)) (cadr l) (cadddr l))) lst))
  (setq lks  (Remote>>Dyl:LayerKeyRead)
        mark (mapcar '(lambda (k) (if (assoc k lks) k (strcat k "   (not defined)"))) mt:keys)
        ;;  A new layer: a Hatch layer of the first preset (its width), a Line on the border
        ;;  layer key of the preset:
        def  (list "P"
                   (cond ((car (car pre))) (""))
                   (cond ((/= "" (cond ((caddr (car pre))) (""))) (caddr (car pre))) ("10"))
                   ""
                   (cond ((car (member (nth *qd:border* r) mt:keys))) ((car mt:keys)) (""))
             )
        rows (Dyl:QuickDrawLayersRows lst def)
  )
  (while
    (and
      (= 1 (car (setq res (Dyl:WinShow "Dyl-AssemblyLayers.xaml"
                                       (append (list (cons "ll/rows" rows)
                                                     (list "ll/new" def)
                                                     (cons "ll.sel" (cond (sel) ("")))
                                                     (cons "lk/list" (mapcar 'cadr *qd:layerkinds*))
                                                     (cons "lk/vals" (mapcar 'car *qd:layerkinds*))
                                                     (cons "lp/list" (mapcar 'cadr pre))
                                                     (cons "lp/vals" (mapcar 'car pre))
                                                     (cons "lp/widths/list" (mapcar 'caddr pre))
                                                     (cons "lh/list" (cons "From preset" mark))
                                                     (cons "lh/vals" (cons "" mt:keys))
                                                     (cons "ly/list" mark)
                                                     (cons "ly/vals" mt:keys)
                                               )
                                               (Dyl:WinOff "lp" (not pre))
                                               (Dyl:WinOff "ly" (not mt:keys))
                                       )
                          )
                )
           )
      )
      (setq rows (cdr (assoc "ll/rows" (cdr res)))
            sel  (Dyl:WinGet res "ll.sel")
            out  (Dyl:QuickDrawLayersOf rows)
      )
      (cadr out)
    )
    (alert (cadr out))
  )
  (if (= 1 (car res)) (Remote>>Dyl:MaterialLayersStr (car out)))
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

;;  The preview of the preset x ((rec . mat), see qg:all): an assembly (Linear, its Assembly
;;  of layers checked) as its layers side by side, each band the hatch of its own preset;
;;  any other preset as its hatch. The bands divided by "*":
(defun Dyl:QuickDrawGallerySpec (x / rec ls res)
  (setq rec (car x))
  (if (and (= "1" (nth 37 rec)) (setq ls (Remote>>Dyl:MaterialLayers (nth *qd:layerscol* rec))))
    (progn
      (foreach l ls
        (setq res (cons (Dyl:QuickDrawGalleryBand
                          (car l)
                          (if (= "P" (car l)) (Dyl:QuickDrawGalleryMat (cadr l)))
                          (if (= "L" (car l)) 0.0 (cond ((distof (caddr l) 2)) (0.0)))
                        )
                        res
                  )
        )
      )
      (setq res (reverse res))
      (apply 'strcat (cons (car res) (mapcar '(lambda (b) (strcat "*" b)) (cdr res))))
    )
    (Dyl:QuickDrawGalleryBand "P" (cdr x) 1.0)
  )
)

;;  The kind of the preset x ((rec . mat), see qg:all), for the kind pills of the gallery:
;;  Assembly, else the type of its hatch preset (Drafting, Model, see *mt:types*):
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
