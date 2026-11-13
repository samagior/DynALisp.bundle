;; Materials - Create and edit the Dynalisp materials used by the drawing tools
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

;;  The hatch presets (called materials in the code: Materials.csv, hatching, dialog) are in
;;  Modules\Dynalisp\Remote\Dyl-Materials.lsp, loaded at startup for every App. The same
;;  window opens from the Quick Draw and Quick Shape windows (the open button beside Hatch preset).

;;-------------------------=={ Commands }==------------------------;;

;; Hatch Presets
;; Opens a dialog to create and edit the hatch presets (pattern, scale and layer key of a hatch) used by Quick Draw and Quick Shape.

(defun c:Dyl-HatchPresets ()
  (Remote>>Dyl:MaterialDialog nil)
  (princ)
)

(princ)
