;; ColorBylayer - Sets the color of the selected objects to ByLayer
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

;; Color ByLayer
;; Sets the color of the selected objects to ByLayer.

(defun c:Dyl-ColorByLayer (/ ss) 
  (setq ss (ssget))
  (if ss 
    (progn 
      (command "_.chprop" ss "" "_c" "_bylayer")
      (princ "\nObjects' color changed to Bylayer.")
    )
    (princ "\nNothing selected.")
  )
)


;; Change Color
;; Sets the color of the selected objects to a color picked in the color dialog.

(defun c:Pst-ChangeColor (/ usercol ss) 
  (while (not (setq usercol (acad_colordlg 256))))
  (prompt "Select all object to change to one color.")
  (if (setq ss (ssget)) 
    (command "_.ChProp" ss "" "_C" usercol "")
  )
  (princ)
)