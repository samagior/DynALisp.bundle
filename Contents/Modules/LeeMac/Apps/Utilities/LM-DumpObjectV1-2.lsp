;;  Dump Object
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

;; Dump Object  -  Lee Mac
;; Lists the ActiveX properties & methods of a supplied VLA-Object
;; or VLA-Object equivalent of a supplied ename, handle, or DXF data list
;; obj - [vla/ent/lst/str] VLA-Object, Entity Name, DXF List, or Handle

;; Dump Object
;; Lists the ActiveX properties and methods of a selected object.

(defun c:LM-DumpObject  nil (LM:dump (car (entsel))))

;; Dump Nested Object
;; Lists the ActiveX properties and methods of a selected nested object.

(defun c:Pst-DumpNestedObject nil (LM:dump (car (nentsel))))

(defun LM:dump ( arg )
    (cond
        (   (= 'vla-object (type arg))
            (vlax-dump-object arg t)
        )
        (   (= 'ename (type arg))
            (LM:dump (vlax-ename->vla-object arg))
        )
        (   (= 'list (type arg))
            (LM:dump (cdr (assoc -1 arg)))
        )
        (   (= 'str  (type arg))
            (LM:dump (handent arg))
        )
    )
    (princ)
)
(vl-load-com) (princ)