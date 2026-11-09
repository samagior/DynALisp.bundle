;;  Multi-Polyline
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

;;------------------------=={ Multi-Polyline  }==-----------------------;;
;;                                                                      ;;
;;  This program enables the user to create objects with the appearance ;;
;;  of multilines, however, which are composed of standard polylines.   ;;
;;                                                                      ;;
;;  The program will invoke the standard AutoCAD MLINE command,         ;;
;;  allowing the user to construct the object with the real-time        ;;
;;  dynamic preview afforded by the MLINE command, with the resulting   ;;
;;  multiline automatically exploded & joined to form standard 2D       ;;
;;  polylines.                                                          ;;
;;----------------------------------------------------------------------;;
;;  Author:  Lee Mac, Copyright � 2010  -  www.lee-mac.com              ;;
;;----------------------------------------------------------------------;;
;;  Version 1.0    -    2010-06-19                                      ;;
;;                                                                      ;;
;;  First release.                                                      ;;
;;----------------------------------------------------------------------;;
;;  Version 1.1    -    2015-09-12                                      ;;
;;                                                                      ;;
;;  Program rewritten.                                                  ;;
;;----------------------------------------------------------------------;;

;; Multi-Polyline
;; Draws a multiline that is automatically exploded and joined into polylines.

(defun c:LM-MultiPolyline ( / *error* ent sel val var )

    (defun *error* ( msg )
        (mapcar 'setvar var val)
        (LM:endundo (LM:acdoc))
        (if (and msg (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")))
            (princ (strcat "\nError: " msg))
        )
        (princ)
    )

    (LM:startundo (LM:acdoc))
    (setq ent (entlast))
    (vl-cmdf "_.mline")
    (while (= 1 (logand 1 (getvar 'cmdactive)))
        (vl-cmdf "\\")
    )
    (if (not (eq ent (setq ent (entlast))))
        (progn
            (setq var '(cmdecho peditaccept qaflags)
                  val  (mapcar 'getvar var)
                  sel  (ssadd)
            )
            (mapcar 'setvar var '(0 1 0))
            (vl-cmdf "_.explode" ent)
            (while (setq ent (entnext ent)) (ssadd ent sel))
            (vl-cmdf "_.pedit" "_m" sel "" "_j" "" "")
        )
    )
    (*error* nil)
    (princ)
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

;;----------------------------------------------------------------------;;
;;                             End of File                              ;;
;;----------------------------------------------------------------------;;