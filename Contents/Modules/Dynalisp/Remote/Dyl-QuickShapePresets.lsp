;; Dyl-QuickShapePresets - Preset spec of Quick Shape
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

;;  Loaded at startup with the other Remote files, so the custom presets made in the
;;  Dyl-QuickShape dialog have a command (Pst-QuickShapeCustom<Name>) before the
;;  Quick Shape App (Apps\Draw\Dyl-QuickShape.lsp) is loaded. See
;;  Remote\Dyl-Presets.lsp for the preset engine and the meaning of each property.


(setq *dyl:presetspecs*
  (cons
    '("QuickShape"
      (file . "QuickShape.csv")
      ;;  Then the border of the preset (the values of the border columns of Materials.csv, a
      ;;  shape always has its border; a row of an older file without them gets the border of
      ;;  its material, see Dyl:QuickShapeFix):
      (header "Id" "Group" "Name" "Material" "Shape" "Scale"
              "OutlineKey" "BorderColorOn" "BorderColor" "BorderLinetypeOn" "BorderLinetype"
              "BorderLtScaleOn" "BorderLtScale" "BorderLineweightOn" "BorderLineweight"
              "BorderTransparencyOn" "BorderTransparency"
      )
      (default . "QS-*")
      (base . "Pst-QuickShape")
      (cmd . "Pst-QuickShapeCustom")
      (title . "Quick Shape")
      (path . "Dynalisp\\Apps\\Draw\\Dyl-QuickShape.lsp")
      (info . 4)
      (desc . "inserts its shape and fills it with its material.")
      (get . Dyl:QuickShapeGet)
      (run . Dyl:QuickShapeRun)
     )
    (vl-remove (assoc "QuickShape" *dyl:presetspecs*) *dyl:presetspecs*)
  )
)

(princ)
