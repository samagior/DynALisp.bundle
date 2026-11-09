;;  Polyline Tools
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
;;
;;  Author:  Lee Mac  -  www.lee-mac.com
;;
;;----------------------------------------------------------------------;;

;; Polyline Close  -  Lee Mac
;; Closes all polylines in a selection.

;; Polyline Close
;; Closes every polyline in the selection.

(defun c:Pst-PolylineClose ( / *error* idx sel )

    (defun *error* ( msg )
        (LM:endundo (LM:acdoc))
        (if (and msg (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")))
            (princ (strcat "\nError: " msg))
        )
        (princ)
    )

    (LM:startundo (LM:acdoc))
    (if
        (setq sel
            (LM:ssget "\nSelect open polylines: "
               '(   "_:L"
                    (
                        (0 . "LWPOLYLINE")
                        (-4 . "<NOT")
                            (-4 . "&=") (70 . 1)
                        (-4 . "NOT>")
                    )
                )
            )
        )
        (repeat (setq idx (sslength sel))
            (vla-put-closed (vlax-ename->vla-object (ssname sel (setq idx (1- idx)))) :vlax-true)
        )
    )
    (*error* nil)
    (princ)
)

;; Polyline Join  -  Lee Mac
;; Attempts to join all lines, arcs and polylines in a selection.

;; Polyline Join
;; Joins the selected lines, arcs and polylines into polylines.

(defun c:Pst-PolylineJoin ( / *error* sel val var )
    
    (defun *error* ( msg )
        (mapcar '(lambda ( a b ) (if b (setvar a b))) var val)
        (LM:endundo (LM:acdoc))
        (if (and msg (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")))
            (princ (strcat "\nError: " msg))
        )
        (princ)
    )

    (LM:startundo (LM:acdoc))
    (if
        (setq sel
            (LM:ssget "\nSelect lines, arcs & polylines: "
               '(    "_:L"
                    (
                        (-4 . "<OR")
                             (0 . "LINE,ARC")
                             (-4 . "<AND")
                                 (0 . "LWPOLYLINE")
                                 (-4 . "<NOT")
                                     (-4 . "&=") (70 . 1)
                                 (-4 . "NOT>")
                             (-4 . "AND>")
                         (-4 . "OR>")
                    )
                )
            )
        )
        (progn
            (setq var '(cmdecho peditaccept)
                  val  (mapcar 'getvar var)
            )
            (mapcar '(lambda ( a b c ) (if a (setvar b c))) val var '(0 1))
            (command "_.pedit" "_m" sel "" "_j" "" "")
        )
    )
    (*error* nil)
    (princ)
)

;; Polyline Width  -  Lee Mac
;; Applies a given constant width to all segments in a selection of polylines.

;; Polyline Width
;; Sets the global width of every polyline in the selection.

(defun c:Pst-PolylineWidth ( / *error* idx sel wid )

    (defun *error* ( msg )
        (LM:endundo (LM:acdoc))
        (if (and msg (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")))
            (princ (strcat "\nError: " msg))
        )
        (princ)
    )

    (LM:startundo (LM:acdoc))
    (if (setq sel (LM:ssget "\nSelect polylines: " '("_:L" ((0 . "LWPOLYLINE")))))
        (progn
            (initget 4)
            (setq wid (cond ((getdist "\nSpecify width for all segments <0.0>: ")) (0.0)))
            (repeat (setq idx (sslength sel))
                (vla-put-constantwidth (vlax-ename->vla-object (ssname sel (setq idx (1- idx)))) wid)
            )
        )
    )
    (*error* nil)
    (princ)
)

;; ssget  -  Lee Mac
;; A wrapper for the ssget function to permit the use of a custom selection prompt
;; msg - [str] selection prompt
;; arg - [lst] list of ssget arguments

(defun LM:ssget ( msg arg / sel )
    (princ msg)
    (setvar 'nomutt 1)
    (setq sel (vl-catch-all-apply 'ssget arg))
    (setvar 'nomutt 0)
    (if (not (vl-catch-all-error-p sel)) sel)
)

;; Start Undo  -  Lee Mac
;; Opens an Undo Group.

(defun LM:startundo ( doc )
    (LM:endundo doc)
    (vla-startundomark doc)
)

;; End Undo  -  Lee Mac
;; Closes an Undo Group.

(defun LM:endundo ( doc )
    (while (= 8 (logand 8 (getvar 'undoctl)))
        (vla-endundomark doc)
    )
)

;; Active Document  -  Lee Mac
;; Returns the VLA Active Document Object

(defun LM:acdoc nil
    (eval (list 'defun 'LM:acdoc 'nil (vla-get-activedocument (vlax-get-acad-object))))
    (LM:acdoc)
)
;;; (vl-load-com) (princ)

;;-------------------------=={ DynALisp }==------------------------;;

;;  The commands above are child commands (Pst-*) of LM-PolylineTools, run by their
;;  aliases or picked in its dialog (Dyl:ChildPicker, dynalisp.mnl).

;; Polyline Tools
;; Lists the Polyline Tools commands with their aliases and runs the one picked.

(defun c:LM-PolylineTools ()
  (Dyl:ChildPicker "LM-PolyTools.lsp" "Polyline Tools" "Double-click a tool (or OK), then select the polylines." '*lm-polylinetools:last*)
)
(princ)
