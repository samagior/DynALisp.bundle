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
              ;;  Linear and Offset: the assembly, a band of several layers: on, and the id of
              ;;  its assembly preset (below; an older file: its layers, see
              ;;  Remote>>Dyl:MaterialLayers and Dyl:QuickDrawAsmMigrate):
              "AssemblyOn" "Assembly"
              ;;  Linear and Offset: their own ends / corners (off: the defaults), the same
              ;;  as Custom band settings:
              "EndsOn" "CornersOn"
              ;;  Custom band settings: the justification, hatch alignment, ends and corners
              ;;  of the Band Settings window (off: the defaults, see Dyl:QuickDrawMat):
              "BandOn"
              ;;  The hatch of the preset (Has a hatch, its Hatch Settings window): its layer
              ;;  key ("": that of its material), the properties of the key it overrides (in
              ;;  place of those of its material), then No hatch (the outline only):
              "HatchKey" "HatchColorOn" "HatchColor" "HatchLinetypeOn" "HatchLinetype"
              "HatchLtScaleOn" "HatchLtScale" "HatchLineweightOn" "HatchLineweight"
              "HatchTransparencyOn" "HatchTransparency" "NoHatch"
              ;;  The view of the preset, the hatch preset of its material it is drawn with:
              ;;  Cut (in section) or Surface (in elevation; an older file: Surface for a preset
              ;;  of the Elevation group, see Remote>>Dyl:MaterialView):
              "View"
      )
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

;;  The assembly presets of Quick Draw, picked by a preset with Assembly checked: each one its
;;  layers (see Remote>>Dyl:MaterialLayers), its Border lines (its two faces and its ends) and
;;  its Dividing lines (between its layers; see Remote>>Dyl:MaterialLines), each replaced by
;;  the own border of a layer, edited in the Assembly Presets window (opened from
;;  the Quick Draw window, see Dyl:QuickDrawAsmDialog). No commands of their own: OK gives the
;;  assembly selected to the Quick Draw presets selected. Then the units of their thicknesses
;;  (Units: "" the units of the drawing, those the user makes; "mm" millimetres, converted to
;;  the units of the drawing when they are read, see Dyl:QuickDrawAsmToDwg), and what the
;;  assembly is worth by the building code: its description, its fire-resistance ratings in
;;  minutes (load-bearing, non-load-bearing), its sound transmission class (STC) and its
;;  impact insulation class (IIC). The default assemblies (as-*) are the typical assemblies of
;;  the building code (NBC Tables 9.10.3.1.-A and -B), named by their number (W1a, F4c...),
;;  their thicknesses in millimetres:
(setq *dyl:presetspecs*
  (cons
    '("QuickDrawAssembly"
      (file . "QuickDrawAssemblies.csv")
      (header "Id" "Group" "Name" "Layers" "BorderLines" "DividingLines" "Exterior" "Units" "Description" "FireRating"
              "FireRatingNLB" "STC" "IIC"
      )
      (default . "AS-*")
      (title . "Assembly Presets")
      (doc . "Draw\\Dyl-AssemblyPresets.htm")
     )
    (vl-remove (assoc "QuickDrawAssembly" *dyl:presetspecs*) *dyl:presetspecs*)
  )
)

(princ)
