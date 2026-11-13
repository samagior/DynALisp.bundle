;;  Multilines to LWPolylines
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

;;--------------=={ Multilines to LWPolylines }==-------------;;
;;                                                            ;;
;;  Converts a selection of Multiline (MLINE) objects into    ;;
;;  LWPolylines.                                              ;;
;;------------------------------------------------------------;;
;;  Author: Lee Mac, Copyright � 2012 - www.lee-mac.com       ;;
;;------------------------------------------------------------;;
;;  Version 1.1    -    10-06-2012                            ;;
;;------------------------------------------------------------;;

;; Multilines To Polylines
;; Converts the selected multilines into polylines.

(defun c:LM-MultilinesToPolylines ( / *error* doc el en i s1 s2 val var )

    (defun *error* ( msg )
        (if val (mapcar 'setvar var val))
        (if doc (LM:endundo doc))
        (if (not (wcmatch (strcase msg) "*BREAK,*CANCEL*,*EXIT*"))
            (princ (strcat "\nError: " msg))
        )
        (princ)
    )
    
    (setq doc (vla-get-activedocument (vlax-get-acad-object))
          var '("CMDECHO" "PEDITACCEPT" "QAFLAGS")
          val  (mapcar 'getvar var)
    )
    (if (setq s1 (ssget "_:L" '((0 . "MLINE"))))
        (progn
            (LM:startundo doc)
            (mapcar 'setvar var '(0 1 0))
            (repeat (setq i (sslength s1))
                (setq en (ssname s1 (setq i (1- i)))
                      el (entlast)
                      s2 (ssadd)
                )
                (command "_.explode" en)
                (while (setq el (entnext el))
                    (ssadd el s2)
                )
                (command "_.pedit" "_M" s2 "" "_J" "" "")
                (setq s2 nil)
            )
            (mapcar 'setvar var val)
            (LM:endundo doc)
        )
    )
    (princ)
)

(defun LM:startundo ( doc )
    (LM:endundo doc)
    (vla-startundomark doc)
)

(defun LM:endundo ( doc )
    (while (= 8 (logand 8 (getvar 'undoctl)))
        (vla-endundomark doc)
    )
)

;;; (vl-load-com)
;;; (princ)