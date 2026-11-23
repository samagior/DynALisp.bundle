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

;;  The materials (Materials.csv, their hatch presets, the hatching, the window
;;  Res\Dyl-Materials.xaml) are in Modules\Dynalisp\Remote\Dyl-Materials.lsp, loaded at
;;  startup for every App. The same window opens from the Quick Draw and Quick Shape windows
;;  (the open button beside Material).

;;-------------------------=={ Commands }==------------------------;;

;; Materials
;; Opens a window to create and edit the materials used by Quick Draw and Quick Shape: their hatch presets and their data.

(defun c:Dyl-Materials ()
  (Remote>>Dyl:MaterialDialog nil)
  (princ)
)

(princ)
