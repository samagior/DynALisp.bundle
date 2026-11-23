;; Hatch Presets - Create and edit the hatches that the Dynalisp materials share
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


;;  The hatch presets (HatchPresets.csv, the hatching, the window) are in
;;  Modules\Dynalisp\Remote\Dyl-Materials.lsp with the materials, loaded at startup for every
;;  App: a material names its hatch preset, and several materials can share one.

;;-------------------------=={ Commands }==------------------------;;

;; Hatch Presets
;; Opens a dialog to create and edit the hatch presets (pattern, scale and layer key of a hatch) that the materials share.

(defun c:Dyl-HatchPresets ()
  (Remote>>Dyl:Manager "HatchPresets")
  (princ)
)

(princ)
