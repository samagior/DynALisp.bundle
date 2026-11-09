;;  Quick Mirror
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

;;---------------------=={ Quick Mirror }==-------------------;;
;;                                                            ;;
;;  Provides functionality to mirror a selection of objects   ;;
;;  or a single object without the need to select two points  ;;
;;  defining a mirror axis.                                   ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright © 2011 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Arguments:                                                ;;
;;  single - if T, mirrors selected object using derivative   ;;
;;           at the selected edge to determine mirror axis,   ;;
;;           else prompts for selection set and object to use ;;
;;           as mirror axis.                                  ;;
;;  delete - if T, selected object or selection set is        ;;
;;           deleted following the mirror operation.          ;;
;;------------------------------------------------------------;;
;;  Returns:  Null.                                           ;;
;;------------------------------------------------------------;;
;;  Version 1.0    -    15-02-2011                            ;;
;;                                                            ;;
;;  First Release.                                            ;;
;;------------------------------------------------------------;;

;;------------------------------------------------------------;;
;;                      Program Shortcuts                     ;;
;;------------------------------------------------------------;;

;; Quick Mirror
;; Mirrors a selection about a selected object without picking a mirror axis.

(defun c:LM-QuickMirror   nil (QuickMirror nil nil))

;; Quick Mirror Delete
;; Mirrors a selection about a selected object and deletes the source selection.

(defun c:Pst-QuickMirrorDelete  nil (QuickMirror nil   t))

;; Quick Mirror Object
;; Mirrors a single object about the point where it was picked.

(defun c:Pst-QuickMirrorObject  nil (QuickMirror   t nil))

;; Quick Mirror Object Delete
;; Mirrors a single object about the point where it was picked and deletes the original.

(defun c:Pst-QuickMirrorObjectDelete nil (QuickMirror   t   t))

;;------------------------------------------------------------;;
;;                   Quick Mirror Subfunction                 ;;
;;------------------------------------------------------------;;

(defun QuickMirror ( single delete / *error* _StartUndo _EndUndo doc ss sel p1 p2 i o ) (vl-load-com)
  ;; © Lee Mac 2011

  (defun *error* ( msg )
    (if doc (_EndUndo doc))
    (or (wcmatch (strcase msg) "*BREAK,*CANCEL*,*EXIT*")
        (princ (strcat "\n** Error: " msg " **")))
    (princ)
  )

  (defun _StartUndo ( doc ) (_EndUndo doc)
    (vla-StartUndoMark doc)
  )

  (defun _EndUndo ( doc )
    (if (= 8 (logand 8 (getvar 'UNDOCTL)))
      (vla-EndUndoMark doc)
    )
  )

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))

  (if (or single (setq ss (ssget "_:L")))
    (while
      (progn (setvar 'ERRNO 0) (setq sel (entsel "\nSelect Mirror Object: "))
        (cond
          (
            (=  7 (getvar 'ERRNO)) (princ "\n** Missed, Try Again **")
          )
          (
            (and sel
              (not
                (vl-catch-all-error-p
                  (setq p1
                    (vl-catch-all-apply 'vlax-curve-getClosestPointto
                      (list (car sel) (trans (cadr sel) 1 0))
                    )
                  )
                )
              )
            )

            (setq p2
              (polar p1
                (angle '(0. 0. 0.)
                  (vlax-curve-getFirstDeriv (car sel)
                    (vlax-curve-getParamatPoint (car sel) p1)
                  )
                )
                1.
              )
            )

            (setq p1 (vlax-3D-point p1) p2 (vlax-3D-point p2))

            (_StartUndo doc)
            (if ss
              (repeat (setq i (sslength ss))
                (vla-mirror (setq o (vlax-ename->vla-object (ssname ss (setq i (1- i))))) p1 p2)
                (if delete  (vla-delete o))
              )
              (progn
                (vla-mirror (setq o (vlax-ename->vla-object (car sel))) p1 p2)
                (if delete  (vla-delete o))
              )
            )
            (_EndUndo doc)
          )
        )
      )
    )
  )
  (princ)
)

;;------------------------------------------------------------;;
;;                          End of File                       ;;
;;------------------------------------------------------------;;
