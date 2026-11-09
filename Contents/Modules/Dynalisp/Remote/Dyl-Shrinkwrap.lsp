;; Dyl-Shrinkwrap - Outline (shrink-wrap) of a selection of objects, in any AutoCAD
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

;;  Loaded at startup with the other Remote files, before the Apps.
;;
;;  Replaces AECLINEWORKSHRINKWRAP (AutoCAD Architecture only): creates closed polylines
;;  around the outside of the selected objects, one per group of touching or overlapping
;;  objects, on the current layer. The selected objects are not changed.
;;
;;  Same technique as Lee Mac's Outline Objects (LeeMac module): a temporary frame is drawn
;;  around the selection and the BOUNDARY command, with island detection, traces the islands
;;  inside the frame, i.e. the outlines of the objects; the frame outline is then deleted.
;;  BOUNDARY only sees geometry, so temporary objects are added to the boundary set:
;;    - a rectangle around each text, mtext and visible block attribute,
;;    - the pieces of exploded copies of blocks, dimensions, multileaders and tables
;;      (so the text inside them is wrapped too),
;;    - the boundary of each hatch (recreated with -HATCHEDIT),
;;    - the bounding box of images, wipeouts and OLE frames.
;;  Every temporary object is deleted at the end.
;;
;;  Objects that do not close an area, or leave gaps between them, are outlined with a gap
;;  tolerance: they are thickened to bands of that width, traced, and the outline is offset
;;  back inwards by half of it (see Gap tolerance below).
;;
;;  Use in an App:
;;    (Remote>>Dyl:Shrinkwrap ss)        -> selection set of the new polylines, or nil
;;    (Remote>>Dyl:ShrinkwrapGap ss 20.0) -> same, objects less than 20 apart joined

;;  Make a temporary closed rectangle from 4 corners (WCS), returns its ename:
(defun Remote>>Dyl:ShrinkwrapRect (pts / ent)
  (if
    (setq ent (entmakex
                (append '((0 . "LWPOLYLINE") (100 . "AcDbEntity") (100 . "AcDbPolyline") (90 . 4) (70 . 1))
                        (mapcar '(lambda (p) (list 10 (car p) (cadr p))) pts)
                )
              )
    )
    (setq sw:tmp (cons ent sw:tmp))
  )
  ent
)

;;  Corners of a box given in text coordinates (lower-left ll, upper-right ur), rotated by
;;  ang around the text origin org:
(defun Remote>>Dyl:ShrinkwrapCorners (ll ur ang org)
  (mapcar '(lambda (p) (polar org (+ ang (angle '(0 0) p)) (distance '(0 0) p)))
          (list ll (list (car ur) (cadr ll)) ur (list (car ll) (cadr ur)))
  )
)

;;  Temporary rectangle on the bounding box of an object, returns its ename or nil:
(defun Remote>>Dyl:ShrinkwrapBoxRect (ent / a b)
  (if
    (not
      (vl-catch-all-error-p
        (vl-catch-all-apply 'vla-GetBoundingBox (list (vlax-ename->vla-object ent) 'a 'b))
      )
    )
    (progn
      (setq a (vlax-safearray->list a)
            b (vlax-safearray->list b)
      )
      (Remote>>Dyl:ShrinkwrapRect (list a (list (car b) (cadr a)) b (list (car a) (cadr b))))
    )
  )
)

;;  Temporary rectangle around a text (TEXT, ATTDEF, ATTRIB, MTEXT), following its rotation.
;;  Falls back on its bounding box. Returns the ename or nil:
(defun Remote>>Dyl:ShrinkwrapTextRect (ent / enx typ box w h a col row)
  (setq enx (entget ent)
        typ (cdr (assoc 0 enx))
  )
  (cond
    ((and (= "MTEXT" typ)
          (setq w (cdr (assoc 42 enx))
                h (cdr (assoc 43 enx))
          )
          (< 0 w)
          (< 0 h)
     )
     ;;  Attachment point 1-9: column 0 left / 1 center / 2 right, row 0 top / 1 middle / 2 bottom:
     (setq a   (cdr (assoc 71 enx))
           col (rem (1- a) 3)
           row (/ (1- a) 3)
     )
     (Remote>>Dyl:ShrinkwrapRect
       (Remote>>Dyl:ShrinkwrapCorners
         (list (* -0.5 col w) (- (* 0.5 row h) h))
         (list (- w (* 0.5 col w)) (* 0.5 row h))
         (cond
           ((assoc 11 enx) (angle '(0 0) (cdr (assoc 11 enx))))
           ((cdr (assoc 50 enx)))
           (0.0)
         )
         (cdr (assoc 10 enx))
       )
     )
    )
    ((and (member typ '("TEXT" "ATTDEF" "ATTRIB"))
          (/= "" (vl-string-trim " " (cdr (assoc 1 enx))))
          (not (assoc 101 enx)) ; multiline attribute: bounding box below
          (setq box (textbox enx))
     )
     (Remote>>Dyl:ShrinkwrapRect
       (Remote>>Dyl:ShrinkwrapCorners (car box)
                                       (cadr box)
                                       (cond ((cdr (assoc 50 enx))) (0.0))
                                       (cdr (assoc 10 enx))
       )
     )
    )
    ((Remote>>Dyl:ShrinkwrapBoxRect ent))
  )
)

;;  End the command running: Enter while an ordinary command waits for input (CMDACTIVE bit
;;  1), never while a dialog or a message is shown (bit 8: (command) there is a "bad order
;;  function" error, e.g. the BOUNDARY error message on open objects):
(defun Remote>>Dyl:ShrinkwrapEnd (/ n)
  (setq n 0)
  (while (and (= 1 (logand 1 (getvar "CMDACTIVE"))) (= 0 (logand 8 (getvar "CMDACTIVE"))) (< (setq n (1+ n)) 50))
    (vl-catch-all-apply 'command '(""))
  )
)

;;  Run the command of args (its whole input: name, options, objects, points) with
;;  command-s (AutoCAD 2015 and later): it runs the command to its end and returns, a
;;  command that stops halfway leaves nothing pending (with command, the next command calls
;;  failed with "bad order function: COMMAND", e.g. after an EXPLODE or a BOUNDARY that did
;;  not end). command, ended with Enter, on an older release. Never raises an error:
(defun Remote>>Dyl:ShrinkwrapCmd (args)
  (if command-s
    (vl-catch-all-apply 'command-s args)
    (progn
      (vl-catch-all-apply 'command args)
      (Remote>>Dyl:ShrinkwrapEnd)
    )
  )
)

;;  Run a command and return the main entities it created (as temporary objects):
(defun Remote>>Dyl:ShrinkwrapNew (cmd / mark lst)
  (setq mark (entlast))
  (Remote>>Dyl:ShrinkwrapCmd cmd)
  (while (setq mark (entnext mark))
    (if
      (and (entget mark)
           (not (member (cdr (assoc 0 (entget mark))) '("ATTRIB" "VERTEX" "SEQEND")))
      )
      (setq lst    (cons mark lst)
            sw:tmp (cons mark sw:tmp)
      )
    )
  )
  lst
)

;;  Pieces of an exploded copy of an object (nil when it cannot be exploded). The copy is put
;;  on the current layer first, so objects on locked layers can be exploded too:
(defun Remote>>Dyl:ShrinkwrapExplode (ent / cpy lst)
  (if
    (not
      (vl-catch-all-error-p
        (setq cpy (vl-catch-all-apply 'vla-Copy (list (vlax-ename->vla-object ent))))
      )
    )
    (progn
      (vl-catch-all-apply 'vla-put-Layer (list cpy (getvar "CLAYER")))
      (setq cpy (vlax-vla-object->ename cpy)
            lst (Remote>>Dyl:ShrinkwrapNew (list "_.explode" cpy))
      )
      (if (entget cpy) (entdel cpy)) ; not exploded: remove the copy
      lst
    )
  )
)

;;  Visible attributes of a block reference:
(defun Remote>>Dyl:ShrinkwrapAttribs (ent / enx lst)
  (if (= 1 (cdr (assoc 66 (entget ent))))
    (while (= "ATTRIB" (cdr (assoc 0 (setq enx (entget (setq ent (entnext ent)))))))
      (if (zerop (logand 1 (cdr (assoc 70 enx)))) (setq lst (cons ent lst)))
    )
  )
  lst
)

;;  Add an object to the boundary set sw:set, or the temporary objects that stand for it:
(defun Remote>>Dyl:ShrinkwrapAdd (ent / typ rect pieces)
  (setq typ (cdr (assoc 0 (entget ent))))
  (cond
    ((wcmatch typ "POINT,XLINE,RAY,VIEWPORT"))
    ((wcmatch typ "TEXT,ATTDEF,ATTRIB,MTEXT")
     (if (setq rect (Remote>>Dyl:ShrinkwrapTextRect ent)) (ssadd rect sw:set))
    )
    ((wcmatch typ "INSERT,DIMENSION,MULTILEADER,ACAD_TABLE")
     (if (= "INSERT" typ) (foreach att (Remote>>Dyl:ShrinkwrapAttribs ent) (Remote>>Dyl:ShrinkwrapAdd att)))
     (if (setq pieces (Remote>>Dyl:ShrinkwrapExplode ent))
       ;;  Exploded attribute definitions show the tags, not the values: skipped
       (foreach p pieces
         (if (/= "ATTDEF" (cdr (assoc 0 (entget p)))) (Remote>>Dyl:ShrinkwrapAdd p))
       )
       (ssadd ent sw:set)
     )
    )
    ((= "HATCH" typ)
     (foreach p (Remote>>Dyl:ShrinkwrapNew (list "_.-hatchedit" ent "_b" "_p" "_n"))
       (ssadd p sw:set)
     )
    )
    ((wcmatch typ "IMAGE,WIPEOUT,OLE2FRAME")
     (if (setq rect (Remote>>Dyl:ShrinkwrapBoxRect ent)) (ssadd rect sw:set))
    )
    ((ssadd ent sw:set))
  )
)

;;  Extents of the objects of a selection set: (lower-left upper-right) or nil:
(defun Remote>>Dyl:ShrinkwrapExtents (ss / i a b lls urs)
  (repeat (setq i (sslength ss))
    (if
      (not
        (vl-catch-all-error-p
          (vl-catch-all-apply 'vla-GetBoundingBox
                              (list (vlax-ename->vla-object (ssname ss (setq i (1- i)))) 'a 'b)
          )
        )
      )
      (setq lls (cons (vlax-safearray->list a) lls)
            urs (cons (vlax-safearray->list b) urs)
      )
    )
  )
  (if lls
    (list (apply 'mapcar (cons 'min lls)) (apply 'mapcar (cons 'max urs)))
  )
)

;;  Trace the outlines of the boundary set sw:set, returns a selection set or nil:
(defun Remote>>Dyl:ShrinkwrapTrace (/ app box d p1 p2 frm are mark out obj)
  (if (and (< 0 (sslength sw:set)) (setq box (Remote>>Dyl:ShrinkwrapExtents sw:set)))
    (progn
      (setq app (vlax-get-acad-object)
            d   (max 1e-6 (/ (distance (car box) (cadr box)) 20.0))
            p1  (mapcar '- (car box) (list d d 0.0))
            p2  (mapcar '+ (cadr box) (list d d 0.0))
            are (* (- (car p2) (car p1)) (- (cadr p2) (cadr p1)))
            frm (Remote>>Dyl:ShrinkwrapRect (list p1 (list (car p2) (cadr p1)) p2 (list (car p1) (cadr p2))))
      )
      (ssadd frm sw:set)
      ;;  BOUNDARY only analyses what is on screen:
      (vlax-invoke app 'ZoomWindow (mapcar '- p1 (list d d 0.0)) (mapcar '+ p2 (list d d 0.0)))
      (setq mark (entlast)
            out  (ssadd)
      )
      ;;  Pick point between the extents of the objects and the frame:
      (Remote>>Dyl:ShrinkwrapCmd
        (list "_.-boundary" "_a" "_b" "_n" sw:set "" "_i" "_y" "_o" "_p" "" "_non"
              (trans (mapcar '- (car box) (list (* 0.5 d) (* 0.5 d) 0.0)) 0 1) ""
        )
      )
      ;;  The outline of the frame is deleted, the outlines of the islands are kept:
      (while (setq mark (entnext mark))
        (if (entget mark)
          (if
            (and (vlax-property-available-p (setq obj (vlax-ename->vla-object mark)) 'Area)
                 (equal (vla-get-Area obj) are (* 1e-6 are))
            )
            (entdel mark)
            (ssadd mark out)
          )
        )
      )
      (vla-ZoomPrevious app)
      (if (< 0 (sslength out)) out)
    )
  )
)

;;-------------------------=={ Gap tolerance }==------------------------;;

;;  With a gap tolerance gap > 0, each object of the boundary set is replaced by bands of
;;  half-width gap/2 along it (one closed rectangle per piece of the object, with square
;;  ends), so objects that do not touch, or do not close an area, are joined when they are
;;  less than gap apart. The outline traced around the bands is then offset inwards by
;;  gap/2: it follows the objects within about gap/2.

;;  Points along the curve e, at most step apart (the vertices of the straight pieces of a
;;  polyline, its arcs and the other curves divided), nil when e is not a curve:
(defun Remote>>Dyl:ShrinkwrapPoints (e step / enx typ len n i lst)
  (setq enx (entget e)
        typ (cdr (assoc 0 enx))
  )
  (cond
    ;;  Straight pieces: their ends only (a line, a polyline without arcs):
    ((= "LINE" typ) (list (cdr (assoc 10 enx)) (cdr (assoc 11 enx))))
    ((and (= "LWPOLYLINE" typ) (vl-every '(lambda (x) (or (/= 42 (car x)) (equal 0.0 (cdr x) 1e-9))) enx))
     (setq i -1)
     (repeat (1+ (fix (+ 0.5 (vlax-curve-getEndParam e))))
       (setq lst (cons (vlax-curve-getPointAtParam e (setq i (1+ i))) lst))
     )
     (reverse (vl-remove nil lst))
    )
    ;;  The other curves divided:
    ((and (not (vl-catch-all-error-p (setq len (vl-catch-all-apply 'vlax-curve-getDistAtParam
                                                                 (list e (vlax-curve-getEndParam e))
                                                     )
                                     )
               )
          )
          len
          (< 0 len)
     )
      ;;  At most 2000 points per object:
      (setq n (min 2000 (max 1 (fix (+ 0.999999 (/ len step)))))
            i -1
      )
      (repeat (1+ n)
        (setq lst (cons (vlax-curve-getPointAtDist e (* len (/ (setq i (1+ i)) (float n)))) lst))
      )
      (reverse (vl-remove nil lst))
    )
  )
)

;;  Bands of half-width h along the points pts (temporary closed rectangles, square ends):
(defun Remote>>Dyl:ShrinkwrapBands (pts h / u nv a b)
  (mapcar
    '(lambda (p q)
       (if (< 1e-9 (distance (list (car p) (cadr p)) (list (car q) (cadr q))))
         (progn
           (setq u  (mapcar '(lambda (x) (/ x (distance (list (car p) (cadr p)) (list (car q) (cadr q)))))
                            (list (- (car q) (car p)) (- (cadr q) (cadr p)))
                    )
                 nv (list (* h (- (cadr u))) (* h (car u)))
                 a  (list (- (car p) (* h (car u))) (- (cadr p) (* h (cadr u))))
                 b  (list (+ (car q) (* h (car u))) (+ (cadr q) (* h (cadr u))))
           )
           (Remote>>Dyl:ShrinkwrapRect (list (mapcar '+ a nv) (mapcar '+ b nv) (mapcar '- b nv) (mapcar '- a nv)))
         )
       )
     )
    pts
    (cdr pts)
  )
)

;;  Selection set of the enames of lst that still exist:
(defun Remote>>Dyl:ShrinkwrapSs (lst / ss)
  (setq ss (ssadd))
  (foreach e lst (if (and e (entget e)) (ssadd e ss)))
  ss
)

;;  Replace the objects of the boundary set sw:set by their bands (gap: the gap tolerance),
;;  merged into one shape: the bands are made regions and united (UNION), so they no longer
;;  overlap, and the united regions are exploded to their outlines (lines and arcs), which
;;  BOUNDARY traces reliably (it failed on many overlapping bands). An object that is not a
;;  curve (a solid, a region...) is kept as it is:
(defun Remote>>Dyl:ShrinkwrapBuffer (gap / old i e pts bands regs cur)
  (setq old    sw:set
        sw:set (ssadd)
  )
  (repeat (setq i (sslength old))
    (setq e (ssname old (setq i (1- i))))
    (if (setq pts (Remote>>Dyl:ShrinkwrapPoints e (max (/ gap 2.0) 1e-6)))
      (foreach r (Remote>>Dyl:ShrinkwrapBands pts (/ gap 2.0)) (if r (setq bands (cons r bands))))
      (ssadd e sw:set)
    )
  )
  (if bands
    (progn
      ;;  Regions of the bands, united (the regions UNION removes are gone, the others stay):
      (setq regs (Remote>>Dyl:ShrinkwrapNew (list "_.region" (Remote>>Dyl:ShrinkwrapSs bands) "")))
      (if (cdr regs) (Remote>>Dyl:ShrinkwrapNew (list "_.union" (Remote>>Dyl:ShrinkwrapSs regs) "")))
      ;;  Their outlines: an exploded region gives its lines and arcs (a region of several
      ;;  separate shapes may give smaller regions first: exploded again, 5 levels at most):
      (setq i 0)
      (while (and regs (< (setq i (1+ i)) 6))
        (setq cur regs
              regs nil
        )
        (foreach r cur
          (if (entget r)
            (foreach c (Remote>>Dyl:ShrinkwrapNew (list "_.explode" r))
              (cond
                ((= "REGION" (cdr (assoc 0 (entget c)))) (setq regs (cons c regs)))
                ((wcmatch (cdr (assoc 0 (entget c))) "LINE,ARC,CIRCLE,ELLIPSE,SPLINE,LWPOLYLINE,POLYLINE")
                 (ssadd c sw:set)
                )
              )
            )
          )
        )
      )
      (setq regs (< 0 (sslength sw:set)))
      ;;  No region made (REGION failed): the bands themselves, as before:
      (if (not regs) (foreach r bands (if (entget r) (ssadd r sw:set))))
    )
  )
)

;;  Offset each outline of the selection set out inwards by d: the side whose new outlines
;;  have the smaller area. Returns the selection set of the outlines kept (an outline that
;;  cannot be offset is kept as it is):
(defun Remote>>Dyl:ShrinkwrapShrink (out d / res i e o a b area keep)
  (defun area (lst) (apply '+ (mapcar '(lambda (x) (if (vlax-property-available-p x 'Area) (vla-get-Area x) 0.0)) lst)))
  (defun keep (r) (if (vl-catch-all-error-p r) nil (vlax-safearray->list (vlax-variant-value r))))
  (setq res (ssadd))
  (repeat (setq i (sslength out))
    (setq e (ssname out (setq i (1- i)))
          o (vlax-ename->vla-object e)
          a (keep (vl-catch-all-apply 'vla-Offset (list o d)))
          b (keep (vl-catch-all-apply 'vla-Offset (list o (- d))))
    )
    (cond
      ((and a b)
       (if (< (area a) (area b))
         (progn (foreach x b (vla-Delete x)) (setq b a))
         (foreach x a (vla-Delete x))
       )
       (foreach x b (ssadd (vlax-vla-object->ename x) res))
       (entdel e)
      )
      ((or a b)
       ;;  One side only (the other one vanished): kept when it is the inner one:
       (setq b (cond (a) (b)))
       (if (< (area b) (vla-get-Area o))
         (progn (foreach x b (ssadd (vlax-vla-object->ename x) res)) (entdel e))
         (progn (foreach x b (vla-Delete x)) (ssadd e res))
       )
      )
      ((ssadd e res))
    )
  )
  (if (< 0 (sslength res)) res)
)

;;-------------------------=={ Shrinkwrap }==------------------------;;

;;  Create closed polylines around the outside of the objects of a selection set, on the
;;  current layer. Returns a selection set of the new polylines, or nil:
(defun Remote>>Dyl:Shrinkwrap (ss)
  (Remote>>Dyl:ShrinkwrapGap ss 0.0)
)

;;  Gap step of the automatic tries (Drawing Settings of Dyl-Settings), kind "Imperial" or
;;  "Metric" (nil: the kind of the current drawing, MEASUREMENT): DynalispShrinkGapImperial
;;  (1, inches) or DynalispShrinkGapMetric (25, mm):
(defun Remote>>Dyl:ShrinkwrapStep (kind / v)
  (if (not kind) (setq kind (if (= 1 (getvar "MEASUREMENT")) "Metric" "Imperial")))
  (if (and (setq v (distof (cond ((getenv (strcat "DynalispShrinkGap" kind))) ("")) 2)) (< 0 v))
    v
    (if (= "Metric" kind) 25.0 1.0)
  )
)

;;  Set the gap step of kind (text, a number > 0):
(defun Remote>>Dyl:ShrinkwrapStepSet (kind val)
  (setenv (strcat "DynalispShrinkGap" kind) val)
)

;;  Number of automatic tries with a larger gap when no outline is found:
(setq *sw:tries* 10)

;;  One try with the gap tolerance gap (see Remote>>Dyl:ShrinkwrapGap). Returns the selection
;;  set of the new polylines, nil when none was found or something failed (nothing printed,
;;  the temporary objects deleted):
(defun Remote>>Dyl:ShrinkwrapTry (ss gap / sw:set sw:tmp cmd res i)
  (setq sw:set (ssadd)
        cmd    (getvar "CMDECHO")
  )
  (setvar "CMDECHO" 0)
  (setq res (vl-catch-all-apply
              '(lambda (/ out)
                 (repeat (setq i (sslength ss)) (Remote>>Dyl:ShrinkwrapAdd (ssname ss (setq i (1- i)))))
                 (if (< 0 gap) (Remote>>Dyl:ShrinkwrapBuffer gap))
                 (setq out (Remote>>Dyl:ShrinkwrapTrace))
                 (if (and out (< 0 gap)) (Remote>>Dyl:ShrinkwrapShrink out (/ gap 2.0)) out)
               )
            )
  )
  ;;  Temporary objects are deleted even when something failed (an erased one is skipped:
  ;;  entdel on an erased object would restore it):
  (foreach e sw:tmp (if (entget e) (entdel e)))
  (setvar "CMDECHO" cmd)
  ;;  *sw:error*: the error of this try (nil: none), printed when no try finds an outline:
  (setq *sw:error* (if (vl-catch-all-error-p res) (vl-catch-all-error-message res)))
  (if (not (vl-catch-all-error-p res)) res)
)

;;  Same, with a gap tolerance gap (drawing units, 0: the objects as they are): objects less
;;  than gap apart are joined, the outlines follow the objects within about gap/2 (see Gap
;;  tolerance above). When no outline is found (or a try fails), it is tried again with the
;;  gap made larger by the gap step of the drawing (Remote>>Dyl:ShrinkwrapStep), up to
;;  *sw:tries* times; the gap used is printed:
(defun Remote>>Dyl:ShrinkwrapGap (ss gap / step n g res)
  (setq gap  (if (and (numberp gap) (< 0 gap)) (float gap) 0.0)
        step (Remote>>Dyl:ShrinkwrapStep nil)
        n    0
        g    gap
  )
  (while (and (not (setq res (Remote>>Dyl:ShrinkwrapTry ss g))) (< n *sw:tries*))
    (setq n (1+ n)
          g (+ gap (* n step))
    )
  )
  (cond
    ((and res (< 0 n))
     (princ (strcat "\nShrinkwrap: no outline with a gap of " (rtos gap)
                    ", found with a gap tolerance of " (rtos g)
                    " (" (itoa n) " step(s) of " (rtos step) ", see Dyl-Settings > Drawing Settings)."
            )
     )
    )
    ((and res (< 0 gap)) (princ (strcat "\nShrinkwrap: gap tolerance " (rtos g) ".")))
    ((not res)
     (princ (strcat "\nShrinkwrap: no outline found, even with a gap tolerance of " (rtos g)
                    (if *sw:error* (strcat " (last error: " *sw:error* ")") "")
                    ": select fewer objects, or make the gap step larger in Dyl-Settings > Drawing Settings."
            )
     )
    )
  )
  res
)

(princ)
