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
      ;;  The behaviors of the preset: Method, then the columns after Override (the same
      ;;  values as the behavior columns of Materials.csv). Override is always "1"; a row of
      ;;  an older file with "0" gets the behaviors of its material (see Dyl:QuickDrawFix).
      ;;  Then the border of the preset (the values of the border columns of Materials.csv; a
      ;;  row of an older file without them gets the border of its material):
      (header "Id" "Group" "Name" "Material" "Method" "Override"
              "Width" "Justify" "Sides" "ScaleWidth" "WidthFactor" "OriginOnLine" "OriginOffset"
              "ShrinkGap" "ShrinkGapOn" "ShrinkGapMetric" "OriginAlong"
              "OutlineKey" "BorderColorOn" "BorderColor" "BorderLinetypeOn" "BorderLinetype"
              "BorderLtScaleOn" "BorderLtScale" "BorderLineweightOn" "BorderLineweight"
              "BorderTransparencyOn" "BorderTransparency" "NoBorder"
              ;;  The bands of Linear and Offset: their ends, corners, joints and hatch:
              "Ends" "EndExtension" "EndAngle" "Corners" "MiterLimit" "LapThrough" "Joints" "HatchFollows"
              ;;  Linear: the assembly, a band of several layers (see Remote>>Dyl:MaterialLayers):
              "AssemblyOn" "Assembly"
              ;;  Linear and Offset: their own ends / corners (off: the defaults), turned on
              ;;  by the Band Settings window:
              "EndsOn" "CornersOn"
      )
      (default . "QD-*")
      (base . "Pst-QuickDraw")
      (cmd . "Pst-QuickDrawCustom")
      (title . "Quick Draw")
      (path . "Dynalisp\\Apps\\Draw\\Dyl-QuickDraw.lsp")
      (info . 3)
      (desc . "draws an outline and fills it with its hatch preset.")
      (get . Dyl:QuickDrawGet)
      (run . Dyl:QuickDrawRun)
     )
    (vl-remove (assoc "QuickDraw" *dyl:presetspecs*) *dyl:presetspecs*)
  )
)

(princ)
