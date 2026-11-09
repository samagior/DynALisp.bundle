;; GroupCluster - Groups nearby entities into separate groups
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

;;;-----------------------------------------------------------------------
;;; GroupCluster.lsp
;;;
;;; Command: GROUPCLUSTER
;;;
;;; Purpose:
;;;   Builds on GROUPALL, but instead of putting every entity in the
;;;   range into ONE group, it looks at how far entities are from each
;;;   other and automatically splits them into SEVERAL groups - only
;;;   entities that are close enough to each other end up in the same
;;;   group.
;;;
;;;   "Close enough" is transitive/recursive: if A is near B, and B is
;;;   near C, then A, B and C all land in the same group even if A and
;;;   C are far apart on their own (classic single-linkage/connected-
;;;   component clustering, done with a union-find structure). Entities
;;;   with no neighbor inside the distance you give are left ungrouped
;;;   (a "group" of one entity isn't meaningful).
;;;
;;;   Distance between two entities is measured as the gap between
;;;   their bounding boxes (0 if the boxes touch or overlap), which is
;;;   a good general-purpose proximity test regardless of entity type.
;;;   The comparison is planar (X/Y only, Z is ignored).
;;;
;;; Usage:
;;;   1. APPLOAD this file (or drag & drop it into the AutoCAD window).
;;;   2. Type GROUPCLUSTER at the command line.
;;;   3. Either specify two corners to define the range (only entities
;;;      fully enclosed by the window are considered), or press Enter
;;;      at the first-corner prompt to pick objects manually instead.
;;;   4. Enter the maximum gap distance for two entities to be
;;;      considered part of the same group (default 10 drawing units).
;;;   5. The routine reports how many groups it created (all anonymous,
;;;      auto-named by AutoCAD, e.g. *A1, *A2, ...) and how many
;;;      entities were left ungrouped because nothing was near them.
;;;
;;; Notes:
;;;   - Performance is O(n^2) in the number of selected entities (every
;;;     entity is compared against every other one), which is fine for
;;;     selections up to a few hundred/thousand objects but will slow
;;;     down noticeably beyond that.
;;;   - As in GROUPALL, grouping never changes the entities themselves.
;;;-----------------------------------------------------------------------

;; Union-find "find" with path compression. parent is a vlax-vbLong
;; safearray where parent[i] initially = i.
(defun GC:Find (parent i / p r) 
  (setq p (vlax-safearray-get-element parent i))
  (if (= p i) 
    i
    (progn 
      (setq r (GC:Find parent p))
      (vlax-safearray-put-element parent i r)
      r
    )
  )
)

;; Union-find "union" by simply attaching one root under the other.
(defun GC:Union (parent a b / ra rb) 
  (setq ra (GC:Find parent a))
  (setq rb (GC:Find parent b))
  (if (/= ra rb) (vlax-safearray-put-element parent ra rb))
)

;; GetBoundingBox sometimes hands back the min/max points as a raw
;; safearray and sometimes as a variant wrapping a safearray, depending
;; on entity type/CAD version. vlax-variant-p isn't available on all
;; platforms, so just try the direct conversion first and only unwrap
;; via vlax-variant-value if that fails.
(defun GC:SafearrayToList (v / lst)
  (setq lst (vl-catch-all-apply 'vlax-safearray->list (list v)))
  (if (vl-catch-all-error-p lst)
    (vlax-safearray->list (vlax-variant-value v))
    lst
  )
)

;; Edge-to-edge gap (>= 0) between the bounding boxes of entities i and
;; j, both packed into the bbx safearray as 4 doubles each:
;; [minx miny maxx maxy].
(defun GC:BBoxGap (bbx i j / i0 j0 minxi minyi maxxi maxyi minxj minyj maxxj maxyj dx dy) 
  (setq i0 (* i 4)
        j0 (* j 4)
  )
  (setq minxi (vlax-safearray-get-element bbx i0))
  (setq minyi (vlax-safearray-get-element bbx (+ i0 1)))
  (setq maxxi (vlax-safearray-get-element bbx (+ i0 2)))
  (setq maxyi (vlax-safearray-get-element bbx (+ i0 3)))
  (setq minxj (vlax-safearray-get-element bbx j0))
  (setq minyj (vlax-safearray-get-element bbx (+ j0 1)))
  (setq maxxj (vlax-safearray-get-element bbx (+ j0 2)))
  (setq maxyj (vlax-safearray-get-element bbx (+ j0 3)))
  (setq dx (max 0.0 (max (- minxi maxxj) (- minxj maxxi))))
  (setq dy (max 0.0 (max (- minyi maxyj) (- minyj maxyi))))
  (sqrt (+ (* dx dx) (* dy dy)))
)

;; Group Cluster
;; Splits the objects of a window or selection into several groups based on their proximity.

(defun c:Dyl-GroupCluster (/ doc groups p1 p2 ss n objarr bbx parent skipped i j ent obj bb minpt maxpt minlst maxlst thresh 
                       clusters root pair arr gcount memberobjs newgrp res cl singles
                      ) 

  (vl-load-com)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq groups (vla-get-Groups doc))

  (princ "\nGROUPCLUSTER - splits a range into several groups based on proximity.")
  (setq p1 (getpoint "\nSpecify first corner of range (or press Enter to pick objects manually): "))
  (setq ss (if p1 
             (progn 
               (setq p2 (getcorner p1 "\nSpecify opposite corner: "))
               (if p2 (ssget "_W" p1 p2)) ; change "_W" to "_C" for a crossing window
             )
             (ssget)
           )
  )

  (if (or (null ss) (< (sslength ss) 2)) 
    (princ "\nFewer than two objects found - nothing to cluster.")
    (progn 
      (setq thresh (getdist "\nMaximum gap distance between entities to group them together <10>: "))
      (if (null thresh) (setq thresh 10.0))

      (setq n (sslength ss))
      (setq objarr (vlax-make-safearray vlax-vbObject (cons 0 (1- n))))
      (setq bbx (vlax-make-safearray vlax-vbDouble (cons 0 (1- (* n 4)))))
      (setq parent (vlax-make-safearray vlax-vbLong (cons 0 (1- n))))

      ;; Load each entity's bounding box into the arrays, skipping any
      ;; entity that doesn't support GetBoundingBox.
      (setq skipped 0)
      (setq i 0)
      (setq j 0) ; j tracks how many entities were actually loaded
      (while (< i n) 
        (setq ent (ssname ss i))
        (setq obj (vlax-ename->vla-object ent))
        (setq bb (vl-catch-all-apply 'vla-GetBoundingBox (list obj 'minpt 'maxpt)))
        (if (vl-catch-all-error-p bb) 
          (setq skipped (1+ skipped))
          (progn 
            (setq minlst (GC:SafearrayToList minpt))
            (setq maxlst (GC:SafearrayToList maxpt))
            (vlax-safearray-put-element objarr j obj)
            (vlax-safearray-put-element bbx (* j 4) (float (car minlst)))
            (vlax-safearray-put-element bbx (+ (* j 4) 1) (float (cadr minlst)))
            (vlax-safearray-put-element bbx (+ (* j 4) 2) (float (car maxlst)))
            (vlax-safearray-put-element bbx (+ (* j 4) 3) (float (cadr maxlst)))
            (vlax-safearray-put-element parent j j)
            (setq j (1+ j))
          )
        )
        (setq i (1+ i))
      )
      (setq n j) ; actual usable entity count

      (if (< n 2) 
        (princ "\nFewer than two groupable objects remain after filtering - nothing to cluster.")
        (progn 
          ;; Pairwise-compare every entity and union the ones within
          ;; the threshold - this is what makes the clustering
          ;; recursive/transitive (A-B and B-C close means A,B,C join).
          (setq i 0)
          (while (< i n) 
            (setq j (1+ i))
            (while (< j n) 
              (if (<= (GC:BBoxGap bbx i j) thresh) 
                (GC:Union parent i j)
              )
              (setq j (1+ j))
            )
            (setq i (1+ i))
          )

          ;; Bucket entities by their cluster root into an alist of
          ;; (root . (obj obj ...)).
          (setq clusters '())
          (setq i 0)
          (while (< i n) 
            (setq root (GC:Find parent i))
            (setq obj (vlax-safearray-get-element objarr i))
            (setq pair (assoc root clusters))
            (if pair 
              (setq clusters (subst (cons root (cons obj (cdr pair))) pair clusters))
              (setq clusters (cons (cons root (list obj)) clusters))
            )
            (setq i (1+ i))
          )

          ;; Create one anonymous AutoCAD group per cluster of 2+
          ;; members; clusters of 1 are left as-is.
          (setq gcount 0)
          (setq singles 0)
          (foreach cl clusters 
            (setq memberobjs (cdr cl))
            (if (>= (length memberobjs) 2) 
              (progn 
                (setq arr (vlax-make-safearray vlax-vbObject (cons 0 (1- (length memberobjs)))))
                (vlax-safearray-fill arr memberobjs)
                (setq res (vl-catch-all-apply 'vla-Add (list groups "" arr)))
                (if (vl-catch-all-error-p res) 
                  (princ (strcat "\nFailed to create a group: " (vl-catch-all-error-message res)))
                  (progn 
                    (setq gcount (1+ gcount))
                    (princ 
                      (strcat "\n  Created group \"" 
                              (vla-get-Name res)
                              "\" with "
                              (itoa (length memberobjs))
                              " member(s)."
                      )
                    )
                  )
                )
              )
              (setq singles (1+ singles))
            )
          )

          (princ (strcat "\nDone: " (itoa gcount) " group(s) created"))
          (if (> singles 0) 
            (princ (strcat ", " (itoa singles) " entitie(s) had no near neighbor and were left ungrouped"))
          )
          (if (> skipped 0) 
            (princ (strcat ", " (itoa skipped) " entitie(s) skipped (no bounding box)"))
          )
          (princ ".")
        )
      )
    )
  )
  (princ)
)

(princ "\nGroupCluster.lsp loaded. Type Dyl-GroupCluster to run.")
(princ)