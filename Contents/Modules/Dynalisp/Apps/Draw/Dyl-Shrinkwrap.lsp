;; Shrinkwrap - Closed polylines around the outside of the selected objects, in any AutoCAD
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

;;  The outline itself is built by Remote>>Dyl:Shrinkwrap
;;  (Modules\Dynalisp\Remote\Dyl-Shrinkwrap.lsp, loaded at startup for every App).

;;-------------------------=={ Commands }==------------------------;;

;; Shrinkwrap
;; Draws closed polylines around the outside of the selected objects (replaces AECLINEWORKSHRINKWRAP).

(defun c:Dyl-Shrinkwrap (/ *error* doc ss out gap g)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (defun *error* (msg)
    (vla-EndUndoMark doc)
    (if (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*,*EXIT*"))
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )
  ;;  Gap tolerance: objects closer than it are joined, 0 by default (exact: when no outline is
  ;;  found, larger gaps are tried, see Remote>>Dyl:ShrinkwrapGap):
  (setq gap 0.0)
  (initget 4)
  (if (setq g (getdist "\nGap tolerance, objects closer than it are joined (0: exact, larger ones tried if needed) <0>: "))
    (setq gap g)
  )
  (if (setq ss (ssget '((-4 . "<NOT") (0 . "POINT,XLINE,RAY,VIEWPORT") (-4 . "NOT>"))))
    (progn
      (vla-StartUndoMark doc)
      (if (setq out (Remote>>Dyl:ShrinkwrapGap ss gap))
        (progn
          (princ (strcat "\n" (itoa (sslength out)) " outline(s) created on layer " (getvar "CLAYER") "."))
          (sssetfirst nil out)
        )
        (princ "\nNo outline could be created.")
      )
      (vla-EndUndoMark doc)
    )
  )
  (princ)
)
