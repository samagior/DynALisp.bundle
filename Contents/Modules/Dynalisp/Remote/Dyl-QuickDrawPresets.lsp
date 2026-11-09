;; Dyl-QuickDrawPresets - Preset spec of Quick Draw
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

;;  Loaded at startup with the other Remote files, so the custom presets made in
;;  the Dyl-QuickDraw dialog have a command (Pst-QuickDrawCustom<Name>) before the
;;  Quick Draw App (Apps\Draw\Dyl-QuickDraw.lsp) is loaded. See Remote\Dyl-Presets.lsp
;;  for the preset engine and the meaning of each property.


(setq *dyl:presetspecs*
  (cons
    '("QuickDraw"
      (file . "QuickDraw.csv")
      ;;  Method: "" draws with the method of the material (its behaviors, with the width of
      ;;  Linear and the sides of Polygon)
      (header "Id" "Group" "Name" "Material" "Method")
      (default . "QD-*")
      (base . "Pst-QuickDraw")
      (cmd . "Pst-QuickDrawCustom")
      (title . "Quick Draw")
      (path . "Dynalisp\\Apps\\Draw\\Dyl-QuickDraw.lsp")
      (info . 3)
      (desc . "draws an outline and fills it with its material.")
      (get . Dyl:QuickDrawGet)
      (run . Dyl:QuickDrawRun)
     )
    (vl-remove (assoc "QuickDraw" *dyl:presetspecs*) *dyl:presetspecs*)
  )
)

(princ)
