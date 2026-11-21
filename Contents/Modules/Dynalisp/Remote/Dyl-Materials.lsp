;; Dyl-Materials - Hatch materials shared by the drawing tools (Quick Draw...)
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

;;  Loaded at startup with the other Remote files. A material is the hatch of an outline:
;;  pattern, scales, angle, annotative, hatch layer key. The materials are
;;  presets of the preset engine (Remote\Dyl-Presets.lsp) without commands, saved to
;;  Res\Materials.csv, and are used by the presets of the drawing tools by their id
;;  (e.g. the Quick Draw presets QD-BRICK and PL-BRICK both use the material mt-Brick).
;;
;;  A material is a list of strings:
;;  (id group name pattern scale unused angle outline-key hatch-key annotative scale-drawing
;;   scale-ref)
;;  scale: the one scale of the hatch, in the units of the pattern (see
;;  Remote>>Dyl:MaterialScale: x25.4 for an imperial pattern in a metric drawing). unused:
;;  the metric scale of the older files (emptied, see Remote>>Dyl:MaterialFix), kept so the
;;  columns after it keep their place.
;;  id is the id of a default material (e.g. "mt-Brick") or a custom id (cu-...).
;;  scale-drawing "1": a hatch that is not annotative follows the drawing scale (the
;;  annotation scale CANNOSCALE, set by Dyl-SwitchDrawingScale): the scales of a material are
;;  always set for 1:1, its scale multiplied by the drawing scale, x50 at 1:50 (see
;;  Remote>>Dyl:MaterialScale). scale-ref is always "1": an older row set for another drawing
;;  scale gets its scales converted to 1:1 (see Remote>>Dyl:MaterialFix).
;;  outline-key, the border settings (12 to 21) and no border (31): no longer edited in the
;;  Materials window: each Quick Draw and Quick Shape preset has its own border; read only to
;;  give it to the presets of an older file that used the border of their material, and the
;;  slots where a preset puts its border when it is drawn (see the Border settings box below,
;;  Remote>>Dyl:MaterialBorderPut).
;;  Then the optional settings of the border and of the hatch, each one an on/off ("1": used,
;;  else the layer or AutoCAD default is kept) and its value, and the behaviors (see
;;  *mt:extra*, index 12 to 50):
;;   border: color, linetype, linetype scale, lineweight, transparency
;;   hatch:  color, background color, lineweight, transparency (its linetype and linetype
;;           scale: the last columns)
;;   associative ("1" by default), no border (outline erased), behind border (no longer
;;   used: the hatch is always behind its border; kept so the columns after it keep their
;;   place)
;;   behaviors (no longer edited in the Materials window: each Quick Draw preset has its
;;   own; read only to give them to the presets of an older Quick Draw file that used those
;;   of their material, see Dyl:QuickDrawFix, and the slots where Dyl:QuickDraw reads the
;;   behaviors of a preset, see Dyl:QuickDrawMat): method (a key of *mt:methods*, "": ask
;;   when drawn), width ("": the last width used) and justify (key of *mt:justify*) of the
;;   Linear method, sides of the Polygon method ("": asked by POLYGON); then for Linear: the
;;   hatch scale from the width ("1": scale = width x factor, in place of the scales of the
;;   material) and the hatch origin on the line ("1": at the start of each segment, moved by
;;   offset across the line, positive into the band; see Dyl:QuickDrawLinear); then the
;;   existing phase background of the hatch (on/off, color): used in place of the background
;;   color while auto-phase is on and the active phase is E (see Remote>>Dyl:MaterialExisting-p);
;;   then the Shrinkwrap gaps, and the offset of the hatch origin along the line (OriginAlong,
;;   from the start of each segment; both offsets can be picked on a sample band, see
;;   Remote>>Dyl:MaterialOriginPick). With the hatch scale from the width, both offsets are
;;   in pattern units (multiplied by that scale, so they follow the width); then the
;;   linetype and linetype scale of the hatch (on/off, value each, as those of the border);
;;   then the bands of Linear and Offset (index 51 to 58, see *mt:ends*): their ends (a key
;;   of *mt:ends*), the extension of Extended ("": half the width), the angle of Angled
;;   (degrees), their corners (a key of *mt:corners*), the miter limit (x the width), the
;;   segment that runs through a Lapped corner (*mt:laps*), the joints (*mt:joints*) and the
;;   hatch (*mt:hatchmodes*); then the assembly of Linear and Offset (index 59 and 60, on/off and its
;;   layers, see Remote>>Dyl:MaterialLayers): a band made of several layers side by side
;;  A color is an AutoCAD color number (1-255) or a true color "r,g,b", a lineweight in
;;  hundredths of mm ("25": 0.25 mm), a transparency 0 to 90.
;;
;;  For a tool (see Apps\Draw\Dyl-QuickDraw.lsp):
;;    (Remote>>Dyl:MaterialGet id)              -> material, nil when it no longer exists
;;    (Remote>>Dyl:MaterialDialog id)           -> Materials dialog opened on id, returns the
;;                                                 material selected on OK (nil on Cancel)
;;    (Remote>>Dyl:MaterialPopup tile mats ids grp) -> fill a material popup of a dialog
;;    (Remote>>Dyl:MaterialSummary mat)         -> one line describing a material


(setq *dyl:presetspecs*
  (cons
    '("Material"
      (file . "Materials.csv")
      (header "Id" "Group" "Name" "Pattern" "Scale" "ScaleMetric" "Angle" "OutlineKey" "HatchKey"
              "Annotative" "ScaleDrawing" "ScaleRef"
              ;;  Optional settings: each one an On column ("1": used) and its value (see *mt:extra*):
              "BorderColorOn" "BorderColor" "BorderLinetypeOn" "BorderLinetype" "BorderLtScaleOn" "BorderLtScale"
              "BorderLineweightOn" "BorderLineweight" "BorderTransparencyOn" "BorderTransparency"
              "HatchColorOn" "HatchColor" "BackgroundOn" "Background" "HatchLineweightOn" "HatchLineweight"
              "HatchTransparencyOn" "HatchTransparency"
              ;;  Hatch and border: associative, no border, behind border (not used):
              "Associative" "NoBorder" "BehindBorder"
              ;;  Behaviors: how the material is drawn by Quick Draw (see *mt:methods*):
              "Method" "Width" "Justify" "Sides"
              ;;  Linear: hatch scale from the width (factor), hatch origin on the line (offset):
              "ScaleWidth" "WidthFactor" "OriginOnLine" "OriginOffset"
              ;;  Hatch: background color while auto-phase is on in the existing phase (E):
              "ExistingBackgroundOn" "ExistingBackground"
              ;;  Behaviors: gap tolerance of the Shrinkwrap method (see Remote>>Dyl:ShrinkwrapGap):
              ;;  imperial drawings, override on, metric drawings (see Dyl:QuickDrawGap):
              "ShrinkGap" "ShrinkGapOn" "ShrinkGapMetric"
              ;;  Linear: offset of the hatch origin along the line (OriginOffset: across it):
              "OriginAlong"
              ;;  Hatch: linetype and linetype scale (optional settings, as those of the border):
              "HatchLinetypeOn" "HatchLinetype" "HatchLtScaleOn" "HatchLtScale"
              ;;  Linear and Offset bands: their ends, corners, joints and hatch (see *mt:ends*):
              "Ends" "EndExtension" "EndAngle" "Corners" "MiterLimit" "LapThrough" "Joints" "HatchFollows"
              ;;  Linear: the assembly, a band of several layers (see Remote>>Dyl:MaterialLayers):
              "AssemblyOn" "Assembly"
              ;;  Linear and Offset: their own ends / corners ("1"), else the defaults (see
              ;;  Dyl:QuickDrawBandOpts): "" in an older file (see Remote>>Dyl:MaterialFix):
              "EndsOn" "CornersOn"
              ;;  Drafting (a size on paper: annotative or adaptive scaling) or Model (a real
              ;;  size: never annotative nor adaptive), see Remote>>Dyl:MaterialFix:
              "Type"
      )
      (default . "MT-*")
      (title . "Hatch Presets")
      ;;  Page of the Documentation button (Docs folder of the Dynalisp module):
      (doc . "Draw\\Dyl-HatchPresets.htm")
     )
    (vl-remove (assoc "Material" *dyl:presetspecs*) *dyl:presetspecs*)
  )
)

;;  Default materials, restored by the Reset Selected and Reset All buttons (their outline key
;;  and border settings: the border given to the presets of their material, see
;;  Dyl:QuickDrawDefault):
(setq *mt:defaults*
  '(("mt-Demolition" "Phase" "Demolition" "ANSI31" "0.5" "0.5" "90.0" "THIN" "HATCH" "1")
    ("mt-NotInContract" "Phase" "Not In Contract" "ANSI31" "1.5" "1.5" "90.0" "XLINE" "HATCH" "1")
    ("mt-Existing" "Phase" "Existing" "SOLID" "1.0" "1.0" "0" "XLINE" "HATCH" "0")
    ("mt-Concrete" "Section" "Concrete" "CONCRETE_C" "1.0" "2.5" "0" "WIDE" "HATCH" "1")
    ("mt-LightweightConcrete" "Section" "Lightweight Concrete" "CONCRETE" "1.0" "2.5" "0" "THIN" "HATCH" "1")
    ("mt-Mortar" "Section" "Mortar" "GENERAL_STIPPLE" "1.0" "2.54" "0" "FINE" "HATCH" "1")
    ("mt-Brick" "Section" "Brick" "ANSI31" "1.0" "1.0" "0" "MED" "HATCH" "1")
    ("mt-Stone" "Section" "Stone" "ANSI33" "1.0" "1.0" "0" "WIDE" "HATCH" "1")
    ("mt-CMU" "Section" "CMU" "ANSI37" "1.0" "1.0" "0" "WIDE" "HATCH" "1")
    ("mt-Firebrick" "Section" "Firebrick" "ANSI35" "0.5" "0.5" "0" "MED" "HATCH" "1")
    ("mt-Marble" "Section" "Marble" "ANSI36" "0.5" "0.5" "0" "MED" "HATCH" "1")
    ("mt-Grout" "Section" "Grout" "GENERAL_STIPPLE" "2.0" "50.8" "0" "XLINE" "HATCH" "1")
    ("mt-Iron" "Section" "Iron" "ANSI31" "0.5" "0.5" "0" "MED" "HATCH" "1")
    ("mt-Steel" "Section" "Steel" "ANSI32" "0.5" "0.5" "0" "MED" "HATCH" "1")
    ("mt-Bronze" "Section" "Bronze" "ANSI33" "0.5" "0.5" "0" "MED" "HATCH" "1")
    ("mt-Lead" "Section" "Lead" "ANSI37" "0.5" "0.5" "0" "MED" "HATCH" "1")
    ("mt-Aluminium" "Section" "Aluminium" "ANSI38" "0.5" "0.5" "0" "MED" "HATCH" "1")
    ("mt-Plywood" "Section" "Plywood" "WOOD_GLU-LAMBEAM" "1.0" "1.0" "0" "MED" "HATCH" "1")
    ("mt-WoodPlank" "Section" "Wood Plank" "WOOD_2" "0.1875" "7.8" "0" "MED" "HATCH" "1")
    ("mt-WoodFrame" "Section" "Wood Frame" "WOOD_1" "0.75" "7.5" "0" "MED" "HATCH" "1")
    ("mt-Particleboard" "Section" "Particleboard" "GENERAL_TEXTURE" "3.0" "76.2" "0" "MED" "HATCH" "1")
    ("mt-Hardboard" "Section" "Hardboard" "ANSI31" "1.0" "1.0" "0" "MED" "HATCH" "1")
    ("mt-Plastic" "Section" "Plastic" "ANSI34" "0.5" "0.5" "0" "MED" "HATCH" "1")
    ("mt-LooseInsulation" "Section" "Loose Insulation" "NET3" "1.0" "1.0" "0" "HATCH" "HATCH" "1")
    ("mt-SprayInsulation" "Section" "Spray Insulation" "HONEY" "0.5" "0.5" "0" "HATCH" "HATCH" "1")
    ("mt-RigidInsulation" "Section" "Rigid Insulation" "ANSI37" "1.0" "1.0" "45" "HATCH" "HATCH" "1")
    ("mt-Gypsum" "Section" "Gypsum" "GENERAL_TEXTURE" "0.5" "12.7" "0" "MED" "HATCH" "1")
    ("mt-Plaster" "Section" "Plaster" "GENERAL_TEXTURE" "3.0" "76.2" "0" "THIN" "HATCH" "1")
    ("mt-CompactedSoil" "Section" "Compacted Soil" "SITEWORK_EARTH" "1.0" "25.4" "45.0" "XLINE" "HATCH" "1")
    ("mt-Topsoil" "Section" "Topsoil" "SITEWORK_EARTH" "1.0" "25.4" "0.0" "XLINE" "HATCH" "1")
    ("mt-UndisturbedSoil" "Section" "Undisturbed Soil" "SITEWORK_EARTH" "1.0" "25.4" "0.0" "XLINE" "HATCH" "1")
    ("mt-Sand" "Section" "Sand" "GENERAL_STIPPLE" "1.0" "25.4" "0.0" "FINE" "HATCH" "1")
    ("mt-Asphalt" "Section" "Asphalt" "SITEWORK_ASPHALT" "1" "25.4" "90.0" "MED" "HATCH" "1")
    ("mt-Gravel" "Section" "Gravel" "SITEWORK_GRAVEL" "3.0" "76.2" "22.5" "FINE" "HATCH" "0")
    ("mt-CrushedStone" "Section" "Crushed Stone" "SITEWORK_GRAVEL" "3.0" "76.2" "22.5" "FINE" "HATCH" "0")
   )
)

;;-------------------------=={ Materials }==------------------------;;

;;  The groups of the materials are those of every preset tool: Res\Groups.csv, edited in the
;;  Preset Groups window (see Remote\Dyl-Groups.lsp). A group typed in the materials file that
;;  is not one of them is kept.

;;  Widths of the Linear method of a material (Width column): the numbers of the text str
;;  divided by commas ("100" or "100,150,200"), nil when it is empty or one of them is not a
;;  number greater than 0:
(defun Remote>>Dyl:MaterialWidths (str / lst)
  (if (and (= 'STR (type str)) (/= "" (vl-string-trim " " str)))
    (progn
      (setq lst (mapcar '(lambda (x) (distof (vl-string-trim " " x) 2)) (Remote>>LM:str->lst str ",")))
      (if (vl-every '(lambda (v) (and v (< 0 v))) lst) lst)
    )
  )
)

;;  The layers of an assembly (Assembly column, Linear): a band made of several layers side by
;;  side, from its left border to its right one (looking from the start of the line). Each
;;  layer is kind:ref:thickness, the layers divided by | (never ; or , : the separators of
;;  the CSV files). Its kind: P, a band hatched as a Quick Draw preset (ref: its id) draws
;;  it; S, a space (no hatch); L, a line (ref: its layer key, no thickness). The thickness of
;;  P and S in drawing units. A P layer can have a fourth field, the layer key of its hatch
;;  in place of the hatch layer key of its preset (P:qd-Brick:90:HATCH). Returns
;;  ((kind ref thickness [hatch-key]) ...), the layers that are valid only (ref and layer key
;;  in upper case for L; the hatch key in upper case, "" for the key of the preset):
(defun Remote>>Dyl:MaterialLayers (str / res k r w)
  (if (= 'STR (type str))
    (foreach x (Remote>>LM:str->lst str "|")
      (setq x (mapcar '(lambda (y) (vl-string-trim " " y)) (Remote>>LM:str->lst x ":")))
      (if (member (length x) '(3 4))
        (progn
          (setq k (strcase (car x))
                r (cadr x)
                w (caddr x)
          )
          (cond
            ((and (= "P" k) (/= "" r) (Remote>>Dyl:MaterialScale-p w))
             (setq res (cons (list "P" r w (strcase (cond ((cadddr x)) ("")))) res))
            )
            ((and (= "S" k) (Remote>>Dyl:MaterialScale-p w)) (setq res (cons (list "S" "" w) res)))
            ((and (= "L" k) (/= "" r)) (setq res (cons (list "L" (strcase r) "") res)))
          )
        )
      )
    )
  )
  (reverse res)
)

;;  The text of the layers lst (see Remote>>Dyl:MaterialLayers) for the Assembly column:
(defun Remote>>Dyl:MaterialLayersStr (lst)
  (cond
    ((Remote>>LM:lst->str
       (mapcar '(lambda (l)
                  (strcat (car l) ":" (cadr l) ":" (caddr l)
                          ;;  The hatch layer key of a P layer, only when it has one:
                          (if (and (= "P" (car l)) (cadddr l) (/= "" (cadddr l))) (strcat ":" (cadddr l)) "")
                  )
                )
               lst
       )
       "|"
     )
    )
    ("")
  )
)

;;  What the layers of the text str are, for the Behaviors box: "3 layers", "No layers":
(defun Remote>>Dyl:MaterialLayersText (str / n)
  (setq n (length (vl-remove-if '(lambda (l) (= "L" (car l))) (Remote>>Dyl:MaterialLayers str))))
  (cond
    ((= 0 n) "No layers")
    ((= 1 n) "1 layer")
    ((strcat (itoa n) " layers"))
  )
)

;;  T when the text str is a number greater than 0 (a scale):
(defun Remote>>Dyl:MaterialScale-p (str / v)
  (and (= 'STR (type str)) (setq v (distof str 2)) (< 0 v))
)

;;  Default values of the columns 12 to 62 (optional settings off, their value shown greyed
;;  out until they are turned on; associative on, as before these settings; the method
;;  asked when drawn; the hatch origin on the line, not moved along it; no assembly; the
;;  ends and corners on when they are not the defaults, see Remote>>Dyl:MaterialFix):
(setq *mt:extra* '("0" "7" "0" "CONTINUOUS" "0" "1" "0" "25" "0" "50"
                   "0" "7" "0" "254" "0" "13" "0" "50"
                   "1" "0" "0"
                   "" "" "Center" ""
                   "0" "1" "0" "0"
                   "0" "253"
                   "" "0" ""
                   "0"
                   "0" "CONTINUOUS" "0" "1"
                   "Square" "" "45" "Mitered" "4" "First" "Interrupted" "Line"
                   "0" ""
                   "" ""
                   "Drafting"
                  )
)

;;  Ways Quick Draw makes the outline of a material (Method column, "": ask when drawn):
;;  (method label keyword). Quick Draw uses this list (*qd:modes*):
(setq *mt:methods* '(("Polyline" "Polyline" "Polyline")
                     ("Rectangle" "Rectangle" "Rectangle")
                     ("Circle" "Circle" "Circle")
                     ("Polygon" "Polygon" "pOlygon")
                     ("Ellipse" "Ellipse" "Ellipse")
                     ("Shrinkwrap" "Shrinkwrap" "sHrinkwrap")
                     ("Pick" "Pick internal points" "pIck")
                     ("Select" "Select closed objects" "Select")
                     ("Linear" "Linear" "Linear")
                     ;;  The band of Linear along existing objects (see Dyl:QuickDrawOffsetBands):
                     ("Offset" "Offset" "oFfset")
                     ;;  No outline: the hatches selected get the hatch of the material (see
                     ;;  Remote>>Dyl:MaterialReplace):
                     ("Replace" "Replace hatches" "replAce")
                    )
)

;;  Linear: where the line drawn is in its band (Justify column): (justify label). "Ask":
;;  asked each time the band is drawn; "Edge": the line is a border of the band, the band
;;  on the side picked once the line is drawn, as Offset (see Dyl:QuickDrawLinear). The Left
;;  and Right of an older file are Edge (see Remote>>Dyl:MaterialFix):
(setq *mt:justify* '(("Ask" "Ask when drawn")
                     ("Center" "Center")
                     ("Edge" "Edge")
                    )
)

;;  Linear and Offset: how a band ends (Ends column), how two of its segments meet (Corners),
;;  which segment runs through a Lapped corner, whether the joints are drawn, and how the
;;  hatch is laid: (key label). "Ask": asked when the band is drawn (see Dyl:QuickDrawBandOpts):
(setq *mt:ends* '(("Ask" "Ask when drawn")
                  ("Square" "Square")
                  ("Open" "Open")
                  ("Extended" "Extended")
                  ("Round" "Round")
                  ("Angled" "Angled")
                 )
      *mt:corners* '(("Ask" "Ask when drawn")
                     ("Mitered" "Mitered")
                     ("Beveled" "Beveled")
                     ("Round" "Round")
                     ("Lapped" "Lapped")
                    )
      *mt:laps* '(("First" "First segment") ("Second" "Next segment"))
      *mt:joints* '(("Interrupted" "Interrupted") ("Uninterrupted" "Uninterrupted"))
      *mt:hatchmodes* '(("Line" "Line") ("Origin" "Drawing origin"))
)

;;  Indexes of the on/off columns (annotative, scale-drawing, the On of each optional
;;  setting, the behaviors):
(setq *mt:toggles* '(9 10 12 14 16 18 20 22 24 26 28 30 31 32 37 39 41 44 47 49 59))

;;  T when the ends of the bands of the row are the defaults (Square, the extension and
;;  the end angle as a new one: see *mt:extra*):
(defun Remote>>Dyl:MaterialEndsDefault-p (row)
  (and (= "SQUARE" (strcase (nth 51 row))) (= "" (nth 52 row)) (equal 45.0 (distof (nth 53 row) 2) 1e-9))
)

;;  T when the corners of the bands of the row are the defaults (Mitered, miter limit 4, the
;;  first segment through a lap, joints drawn):
(defun Remote>>Dyl:MaterialCornersDefault-p (row)
  (and (= "MITERED" (strcase (nth 54 row)))
       (equal 4.0 (distof (nth 55 row) 2) 1e-9)
       (= "FIRST" (strcase (nth 56 row)))
       (= "INTERRUPTED" (strcase (nth 57 row)))
  )
)

;;  Values of a row of the materials file: group as in the groups (any case), pattern,
;;  layer keys and linetype in upper case, the on/off columns "1" or "0", scale-ref "1", an
;;  empty optional value its default. A row of an older file (without the last columns, or
;;  with a scale source in place of scale-ref) gets them. A row set for another drawing scale
;;  (scale-ref 1:10) that follows the drawing scale gets its scales divided by it, to draw at
;;  the same size with the scales set for 1:1:
(defun Remote>>Dyl:MaterialFix (row / v)
  (while (< (length row) 12) (setq row (append row (list ""))))
  (while (< (length row) 64) (setq row (append row (list (nth (- (length row) 12) *mt:extra*)))))
  ;;  Its type (63): Drafting or Model (any case), Drafting in an older file. A Model hatch
  ;;  is drawn at its real size: never annotative (9) nor scaled with the drawing (10):
  (setq row (Remote>>Dyl:ListSubst row 63 (if (= "MODEL" (strcase (nth 63 row))) "Model" "Drafting")))
  (if (= "Model" (nth 63 row)) (foreach i '(9 10) (setq row (Remote>>Dyl:ListSubst row i "0"))))
  ;;  The layers of the assembly, those that are valid only:
  (setq row (Remote>>Dyl:ListSubst row 60 (Remote>>Dyl:MaterialLayersStr (Remote>>Dyl:MaterialLayers (nth 60 row)))))
  ;;  Bands: a key of each list (else its default), an extension >= 0 or "", an end angle
  ;;  between -80 and 80, a miter limit of 1 or more:
  (foreach x (list (list 51 *mt:ends*) (list 54 *mt:corners*) (list 56 *mt:laps*) (list 57 *mt:joints*) (list 58 *mt:hatchmodes*))
    (setq row (Remote>>Dyl:ListSubst row
                                     (car x)
                                     (cond ((car (vl-some '(lambda (y) (if (= (strcase (nth (car x) row)) (strcase (car y))) y)) (cadr x))))
                                           ((nth (- (car x) 12) *mt:extra*))
                                     )
              )
    )
  )
  (if (not (and (setq v (distof (nth 52 row) 2)) (<= 0 v))) (setq row (Remote>>Dyl:ListSubst row 52 "")))
  (if (not (and (setq v (distof (nth 53 row) 2)) (<= -80 v 80))) (setq row (Remote>>Dyl:ListSubst row 53 "45")))
  (if (not (and (setq v (distof (nth 55 row) 2)) (<= 1 v))) (setq row (Remote>>Dyl:ListSubst row 55 "4")))
  ;;  Its own ends (61) and corners (62): "1" or "0"; a row of an older file ("") gets "1"
  ;;  when they are not the defaults, so it draws as before:
  (if (not (member (nth 61 row) '("0" "1")))
    (setq row (Remote>>Dyl:ListSubst row 61 (if (Remote>>Dyl:MaterialEndsDefault-p row) "0" "1")))
  )
  (if (not (member (nth 62 row) '("0" "1")))
    (setq row (Remote>>Dyl:ListSubst row 62 (if (Remote>>Dyl:MaterialCornersDefault-p row) "0" "1")))
  )
  ;;  Shrinkwrap gap tolerances (imperial, metric): a number >= 0, "" when it is not (asked
  ;;  when drawn while the gap override is on):
  (foreach i '(43 45)
    (if (not (and (setq v (distof (nth i row) 2)) (<= 0 v))) (setq row (Remote>>Dyl:ListSubst row i "")))
  )
  ;;  One gap (43), in drawing units: the metric gap (45) of an older file is its gap when it
  ;;  has none, then no longer used:
  (if (= "" (nth 43 row)) (setq row (Remote>>Dyl:ListSubst row 43 (nth 45 row))))
  (setq row (Remote>>Dyl:ListSubst row 45 ""))
  ;;  Linear: a width factor > 0 ("1" when it is not), origin offsets across and along the
  ;;  line ("0" when it is not a number):
  (if (not (Remote>>Dyl:MaterialScale-p (nth 38 row))) (setq row (Remote>>Dyl:ListSubst row 38 "1")))
  (foreach i '(40 46)
    (if (not (distof (nth i row) 2)) (setq row (Remote>>Dyl:ListSubst row i "0")))
  )
  ;;  Behaviors: a method of *mt:methods* or "", a width > 0 or "", a justify of
  ;;  *mt:justify*, sides 3 to 1024 or "":
  (setq row (Remote>>Dyl:ListSubst row 33 (cond ((car (vl-some '(lambda (x) (if (= (strcase (nth 33 row)) (strcase (car x))) x)) *mt:methods*))) (""))))
  (if (not (Remote>>Dyl:MaterialWidths (nth 34 row))) (setq row (Remote>>Dyl:ListSubst row 34 "")))
  (if (member (strcase (nth 35 row)) '("LEFT" "RIGHT")) (setq row (Remote>>Dyl:ListSubst row 35 "Edge")))
  (setq row (Remote>>Dyl:ListSubst row 35 (cond ((car (vl-some '(lambda (x) (if (= (strcase (nth 35 row)) (strcase (car x))) x)) *mt:justify*))) ("Center"))))
  (if (not (and (wcmatch (nth 36 row) "#,##,###,####") (<= 3 (atoi (nth 36 row)) 1024))) (setq row (Remote>>Dyl:ListSubst row 36 "")))
  (setq row (Remote>>Dyl:ListSubst row 1 (Remote>>Dyl:GroupCase (nth 1 row))))
  (foreach i '(3 7 8 15 48) (setq row (Remote>>Dyl:ListSubst row i (strcase (nth i row)))))
  ;;  A layer key kept for compatibility only (see *lk:nomaterial*) is never the key of a
  ;;  material: HATCH in its place (of its border or its hatch):
  (foreach i '(7 8)
    (if (not (Remote>>Dyl:LayerKeyMaterial-p (nth i row))) (setq row (Remote>>Dyl:ListSubst row i "HATCH")))
  )
  (foreach i *mt:toggles* (setq row (Remote>>Dyl:ListSubst row i (if (= "1" (nth i row)) "1" "0"))))
  (if (and (Remote>>Dyl:MaterialScale-p (nth 11 row))
           (/= 1.0 (setq v (distof (nth 11 row) 2)))
           (= "1" (nth 10 row))
      )
    (if (Remote>>Dyl:MaterialScale-p (nth 4 row))
      (setq row (Remote>>Dyl:ListSubst row 4 (Remote>>Dyl:MaterialNumP (/ (distof (nth 4 row) 2) v) 6)))
    )
  )
  (setq row (Remote>>Dyl:ListSubst row 11 "1"))
  ;;  One scale (4), in the units of the pattern: the metric scale of an older file (5) is
  ;;  not used:
  (if (not (Remote>>Dyl:MaterialScale-p (nth 4 row))) (setq row (Remote>>Dyl:ListSubst row 4 "1")))
  (setq row (Remote>>Dyl:ListSubst row 5 ""))
  (foreach i '(13 15 17 19 21 23 25 27 29 42 48 50)
    (if (= "" (nth i row)) (setq row (Remote>>Dyl:ListSubst row i (nth (- i 12) *mt:extra*))))
  )
  row
)

;;  The default materials get the last columns too (not scaled with the drawing, set for
;;  1:1, the optional settings off). Not with Remote>>Dyl:MaterialFix: Dyl-Sub.lsp
;;  (Remote>>Dyl:ListSubst) loads after this file:
(setq *mt:defaults* (mapcar '(lambda (r) (if (< (length r) 12) (append r (list "0" "1") *mt:extra*) r)) *mt:defaults*))

;;  A new material (the optional settings off, associative), and the material of a preset
;;  whose material no longer exists (the border and behaviors of a new preset):
(setq *mt:new* (append '("" "" "New hatch preset" "ANSI31" "1.0" "1.0" "0" "THIN" "HATCH" "1" "0" "1") *mt:extra*))

;;-------------------------=={ Optional settings }==------------------------;;

;;  Color of a text: (n) for an AutoCAD color 1-255, (r g b) for "r,g,b", nil when it is not one:
(defun Remote>>Dyl:MaterialColorParse (s / l n)
  (setq s (vl-string-trim " " (cond (s) (""))))
  (cond
    ((and (wcmatch s "#,##,###") (<= 1 (setq n (atoi s)) 255)) (list n))
    ((and (= 3 (length (setq l (Remote>>LM:str->lst s ","))))
          (vl-every '(lambda (x) (and (wcmatch (setq x (vl-string-trim " " x)) "#,##,###") (<= 0 (atoi x) 255))) l)
     )
     (mapcar '(lambda (x) (atoi (vl-string-trim " " x))) l)
    )
  )
)

;;  T while the new objects go to the existing phase: auto-phase on (with the DynALisp
;;  reactors) and the active phase of the drawing E (see Remote\Dyl-LayerPhase.lsp):
(defun Remote>>Dyl:MaterialExisting-p ()
  (and Remote>>Dyl:PhaseAutoOn-p
       Remote>>Dyl:PhaseGet
       (Remote>>Dyl:PhaseAutoOn-p)
       (= "E" (Remote>>Dyl:PhaseGet))
  )
)

;;  Background color of the hatch of the material mat (see Remote>>Dyl:MaterialColorParse),
;;  nil for none: the existing phase background while it applies, else the background color:
(defun Remote>>Dyl:MaterialBackground (mat)
  ;;  The color itself is returned (and would return T):
  (cond
    ((and (= "1" (nth 41 mat)) (Remote>>Dyl:MaterialExisting-p) (Remote>>Dyl:MaterialColorParse (nth 42 mat)))
     (Remote>>Dyl:MaterialColorParse (nth 42 mat))
    )
    ((and (= "1" (nth 24 mat)) (Remote>>Dyl:MaterialColorParse (nth 25 mat)))
     (Remote>>Dyl:MaterialColorParse (nth 25 mat))
    )
  )
)

;;  Color c (see above) as a HPBACKGROUNDCOLOR value: "1" or "RGB:255,0,0":
(defun Remote>>Dyl:MaterialColorStr (c)
  (if (= 1 (length c))
    (itoa (car c))
    (strcat "RGB:" (itoa (car c)) "," (itoa (cadr c)) "," (itoa (caddr c)))
  )
)

;;  Give the color c (see above) to the object o:
(defun Remote>>Dyl:MaterialColorPut (o c / tc)
  (if (= 1 (length c))
    (vla-put-Color o (car c))
    (progn
      (setq tc (vla-get-TrueColor o))
      (vla-SetRGB tc (car c) (cadr c) (caddr c))
      (vla-put-TrueColor o tc)
    )
  )
)

;;  T when the linetype name can be used: ByLayer, ByBlock, in the drawing, or loaded from
;;  acad.lin / acadiso.lin (MEASUREMENT):
(defun Remote>>Dyl:MaterialLinetype (name)
  (or (member (strcase name) '("BYLAYER" "BYBLOCK"))
      (tblsearch "LTYPE" name)
      (progn
        (vl-catch-all-apply 'vla-Load
                            (list (vla-get-Linetypes (vla-get-ActiveDocument (vlax-get-acad-object)))
                                  name
                                  (if (= 1 (getvar "MEASUREMENT")) "acadiso.lin" "acad.lin")
                            )
        )
        (tblsearch "LTYPE" name)
      )
  )
)

;;  Set the optional settings of the material mat that are on to the entity e: those of the
;;  border (kind 'border) or of the hatch ('hatch, its background is set when it is made).
;;  A setting that cannot be set (linetype not found...) is skipped:
(defun Remote>>Dyl:MaterialProps (e mat kind / o v)
  (setq o (vlax-ename->vla-object e))
  (foreach x (if (= kind 'border)
               '((12 color) (14 linetype) (16 ltscale) (18 lweight) (20 transp))
               ;;  A SOLID hatch has no lineweight and no linetype (see *mt:solidoff*):
               (if (= "SOLID" (nth 3 mat))
                 '((22 color) (28 transp))
                 '((22 color) (47 linetype) (49 ltscale) (26 lweight) (28 transp))
               )
             )
    (if (= "1" (nth (car x) mat))
      (progn
        (setq v (nth (1+ (car x)) mat))
        (vl-catch-all-apply
          '(lambda ()
             (cond
               ((= 'color (cadr x)) (if (setq v (Remote>>Dyl:MaterialColorParse v)) (Remote>>Dyl:MaterialColorPut o v)))
               ((= 'linetype (cadr x)) (if (Remote>>Dyl:MaterialLinetype v) (vla-put-Linetype o v)))
               ((= 'ltscale (cadr x)) (if (Remote>>Dyl:MaterialScale-p v) (vla-put-LinetypeScale o (distof v 2))))
               ((= 'lweight (cadr x)) (vla-put-Lineweight o (atoi v)))
               ((= 'transp (cadr x)) (vla-put-EntityTransparency o v))
             )
           )
        )
      )
    )
  )
)

;;  The drawing scale of the current drawing: the annotation scale (CANNOSCALE, set by
;;  Dyl-SwitchDrawingScale) as a number, 1:50 -> 50.0. 1.0 when it cannot be read:
(defun Remote>>Dyl:MaterialDrawScale (/ v)
  (if (and (numberp (setq v (getvar "CANNOSCALEVALUE"))) (< 0 v)) (/ 1.0 v) 1.0)
)

;;  Number as text without its trailing zeros (50.0 -> "50", 2.5 -> "2.5"):
(defun Remote>>Dyl:MaterialNum (v)
  (Remote>>Dyl:MaterialNumP v 4)
)

;;  Same, with n decimals at most:
(defun Remote>>Dyl:MaterialNumP (v n / s)
  (setq s (rtos v 2 n))
  (if (vl-string-search "." s) (vl-string-right-trim "." (vl-string-right-trim "0" s)) s)
)

;;  Factor of the hatch scale of a material set for the drawing scale 1:ref (ref: text, always
;;  "1" now, see Remote>>Dyl:MaterialFix) in the current drawing: the drawing scale divided by
;;  ref, drawn at 1:50 -> 50.0:
(defun Remote>>Dyl:MaterialFactor (ref)
  (/ (Remote>>Dyl:MaterialDrawScale) (if (Remote>>Dyl:MaterialScale-p ref) (distof ref 2) 1.0))
)

;;  T when the hatch of the material mat follows the drawing scale (not annotative, not SOLID):
(defun Remote>>Dyl:MaterialScaled-p (mat)
  (and (= "1" (nth 10 mat)) (/= "1" (nth 9 mat)) (/= "SOLID" (nth 3 mat)))
)

;;  Units of the pattern nam as AutoCAD loads it in the current drawing: ("Imperial" or
;;  "Metric" . full path of the .pat file defining it), nil when no file defines it. AutoCAD looks
;;  for it in acadiso.pat in a metric drawing (MEASUREMENT 1), in acad.pat in an imperial one,
;;  then in its own file nam.pat on the support path. acad.pat is imperial, acadiso.pat
;;  metric. A file of its own is metric when it says so (a comment line ;%UNITS=MM, as
;;  Dyl-RebuildPat writes it; ;%UNITS=INCH: imperial), else when the name of the file or of
;;  its folder has ISO or METRIC in it; else imperial, like the patterns of AutoCAD and its
;;  toolsets. Kept in *mt:patunits* (emptied each time the Materials window opens, see
;;  Remote>>Dyl:MaterialDlgInit):
(defun Remote>>Dyl:MaterialPatUnits (nam / key std fle res)
  (setq key (strcat (strcase nam) "|" (itoa (getvar "MEASUREMENT"))))
  (if (assoc key *mt:patunits*)
    (cdr (assoc key *mt:patunits*))
    (progn
      (setq std (if (= 1 (getvar "MEASUREMENT")) "acadiso.pat" "acad.pat")
            res (cond
                  ((and (setq fle (findfile std)) (Remote>>Dyl:MaterialPatIn nam fle))
                   (cons (if (= 1 (getvar "MEASUREMENT")) "Metric" "Imperial") fle)
                  )
                  ((setq fle (findfile (strcat nam ".pat")))
                   (cons (Remote>>Dyl:MaterialPatFileUnits fle) fle)
                  )
                )
      )
      (setq *mt:patunits* (cons (cons key res) *mt:patunits*))
      res
    )
  )
)

;;  T when the .pat file fle defines the pattern nam (a line *nam, or *nam, description):
(defun Remote>>Dyl:MaterialPatIn (nam fle / des str pos res)
  (setq nam (strcase nam))
  (if (setq des (open fle "r"))
    (progn
      (while (and (not res) (setq str (read-line des)))
        (if (and (= "*" (substr str 1 1))
                 (= nam
                    (strcase (vl-string-trim " \t" (if (setq pos (vl-string-search "," str)) (substr str 2 (1- pos)) (substr str 2))))
                 )
            )
          (setq res T)
        )
      )
      (close des)
    )
  )
  res
)

;;  "Metric" or "Imperial": the units of fle, the .pat file of its own of a pattern (see
;;  Remote>>Dyl:MaterialPatUnits):
(defun Remote>>Dyl:MaterialPatFileUnits (fle / des str res)
  (if (setq des (open fle "r"))
    (progn
      (while (and (not res) (setq str (read-line des)))
        (setq str (strcase (vl-string-trim " \t" str)))
        (if (and (wcmatch str ";*%UNITS*=*") (vl-string-search "=" str))
          (setq res (if (wcmatch (vl-string-trim " \t" (substr str (+ 2 (vl-string-search "=" str)))) "M*,CM*")
                      "Metric"
                      "Imperial"
                    )
          )
        )
      )
      (close des)
    )
  )
  (cond
    (res)
    ((wcmatch (strcase (strcat (vl-filename-base fle) "|" (vl-filename-base (vl-filename-directory fle)))) "*ISO*,*METRIC*")
     "Metric"
    )
    ("Imperial")
  )
)

;;  Factor of the scale of the material mat for the units of its pattern in the current
;;  drawing (see Remote>>Dyl:MaterialPatUnits): 25.4 for an imperial pattern in a metric
;;  drawing (MEASUREMENT 1), 1 / 25.4 for a metric pattern in an imperial drawing, else 1.0
;;  (also for SOLID and for a pattern no file defines):
(defun Remote>>Dyl:MaterialUnitFactor (mat / u m)
  (setq u (if (/= "SOLID" (nth 3 mat)) (car (Remote>>Dyl:MaterialPatUnits (nth 3 mat))))
        m (= 1 (getvar "MEASUREMENT"))
  )
  (cond
    ((and m (= "Imperial" u)) 25.4)
    ((and (not m) (= "Metric" u)) (/ 1.0 25.4))
    (1.0)
  )
)

;;  Line under the scale in the Materials window: the units of the pattern of the material r
;;  and the factor of its scale in the current drawing (see Remote>>Dyl:MaterialUnitFactor):
(defun Remote>>Dyl:MaterialUnitText (r / u f)
  (setq u (car (Remote>>Dyl:MaterialPatUnits (nth 3 r)))
        f (Remote>>Dyl:MaterialUnitFactor r)
  )
  (cond
    ((not u) "Pattern file not found: scale as is.")
    ((< 1.0 f) (strcat u " pattern: x25.4 here (metric)."))
    ((> 1.0 f) (strcat u " pattern: /25.4 here (imperial)."))
    ((strcat u " pattern, like this drawing."))
  )
)

;;  Open button of that line: the .pat file defining the pattern nam (see
;;  Remote>>Dyl:MaterialPatUnits) opened in Notepad to inspect it, the window left open (a
;;  .pat file has no Windows association):
(defun Remote>>Dyl:MaterialPatOpen (nam / fle)
  (if (setq fle (cdr (Remote>>Dyl:MaterialPatUnits nam)))
    (startapp "notepad" (strcat "\"" fle "\""))
  )
)

;;  Hatch scale of the material mat in the current drawing: its scale (set for 1:1, in the
;;  units of its pattern), multiplied by the factor of the units of its pattern (see
;;  Remote>>Dyl:MaterialUnitFactor) and by the drawing scale when it follows the drawing
;;  scale (see Remote>>Dyl:MaterialFactor):
(defun Remote>>Dyl:MaterialScale (mat / s)
  (setq s (distof (nth 4 mat) 2))
  (if (not s) (setq s 1.0))
  (setq s (* s (Remote>>Dyl:MaterialUnitFactor mat)))
  (if (Remote>>Dyl:MaterialScaled-p mat) (* s (Remote>>Dyl:MaterialFactor (nth 11 mat))) s)
)

;;  The default materials: the rows of the default materials file (Res\Materials.csv under
;;  Contents, never its user copy), so the status of a material (default / modified), Reset
;;  Selected and Reset All follow that file. Read again when it changes (*mt:defstamp*).
;;  *mt:defaults* (above) when the file cannot be read:
(defun Remote>>Dyl:MaterialDefs (/ fle stm rows)
  (setq fle (Remote>>Dyl:PresetDefault "Material")
        stm (if (findfile fle) (vl-file-systime fle))
  )
  (cond
    ((and stm *mt:defcache* (equal stm *mt:defstamp*)) *mt:defcache*)
    ((and stm
          Remote>>Dyl:CsvRead
          (setq rows (vl-remove-if '(lambda (r) (or (= "" (car r)) (= "" (nth 2 r))))
                                   (mapcar 'Remote>>Dyl:MaterialFix
                                           (Remote>>Dyl:CsvRead fle (length (Remote>>Dyl:PresetProp "Material" 'header)))
                                   )
                     )
          )
     )
     (setq *mt:defstamp* stm
           *mt:defcache* rows
     )
    )
    (*mt:defaults*)
  )
)

;;  Read the materials file. Default materials missing from the file are added with their
;;  default values:
(defun Remote>>Dyl:MaterialRead ()
  (Remote>>Dyl:PresetRead "Material" (Remote>>Dyl:MaterialDefs) 'Remote>>Dyl:MaterialFix)
)

;;  Return the material id, with the values edited by the user (nil when it no longer exists):
(defun Remote>>Dyl:MaterialGet (id)
  (Remote>>Dyl:PresetGet "Material" (Remote>>Dyl:MaterialDefs) 'Remote>>Dyl:MaterialFix id)
)

;;  T when the entity e is a closed curve that can be hatched:
(defun Remote>>Dyl:MaterialClosed-p (e)
  (and (wcmatch (cdr (assoc 0 (entget e))) "LWPOLYLINE,POLYLINE,CIRCLE,ELLIPSE,SPLINE")
       (vlax-curve-isClosed e)
  )
)

;;  Put the entities outs on the layer of the outline layer key of the material mat and hatch
;;  their closed curves with one associative hatch (an outline inside another one stays open:
;;  island), using the pattern, scale (for the units of the pattern, multiplied by the
;;  drawing scale when the material follows it, see Remote>>Dyl:MaterialScale), angle and
;;  annotative of mat, on the layer of its hatch layer key. Layers are created if missing
;;  (see Dyl-LayerKeys):
(defun Remote>>Dyl:MaterialHatch (mat outs)
  (Remote>>Dyl:MaterialHatchAt mat outs 0.0)
)

;;  Same as Remote>>Dyl:MaterialHatch, the hatch turned by ang degrees more than the angle of
;;  the material (e.g. the angle of the line of a Quick Draw Linear band):
;;  Give the background color c (see Remote>>Dyl:MaterialColorParse) to the hatch e: a new
;;  AcCmColor of this release set to c (the one of a hatch without background is "none" and
;;  may not take a color), else the one of the hatch. A message when it cannot be set:
(defun Remote>>Dyl:MaterialBackgroundPut (e c / o res mt:bgset)
  (setq o (vlax-ename->vla-object e))
  (defun mt:bgset (bc)
    (if (= 1 (length c))
      (vla-put-ColorIndex bc (car c))
      (vla-SetRGB bc (car c) (cadr c) (caddr c))
    )
    (vla-put-BackgroundColor o bc)
    (vla-Update o)
    T
  )
  (setq res (vl-catch-all-apply
              '(lambda ()
                 (mt:bgset (vla-GetInterfaceObject (vlax-get-acad-object)
                                                   (strcat "AutoCAD.AcCmColor." (substr (getvar "ACADVER") 1 2))
                           )
                 )
               )
            )
  )
  (if (vl-catch-all-error-p res)
    (setq res (vl-catch-all-apply '(lambda () (mt:bgset (vla-get-BackgroundColor o))))))
  (if (vl-catch-all-error-p res)
    (princ (strcat "\n--> Hatch background color not set: " (vl-catch-all-error-message res)))
  )
)

;;  The point p (WCS) in the current UCS, without its Z (a HPORIGIN value):
(defun Remote>>Dyl:MaterialUcs2d (p / u)
  (setq u (trans p 0 1))
  (list (car u) (cadr u))
)

;;  A message when the pattern origin of the hatch e is not the point p (WCS) it was made
;;  with (its Origin, in the coordinates of its plane):
(defun Remote>>Dyl:MaterialOriginCheck (e p / o q)
  (setq o (vl-catch-all-apply
            '(lambda () (vlax-safearray->list (vlax-variant-value (vla-get-Origin (vlax-ename->vla-object e)))))
          )
        q (trans p 0 (cond ((cdr (assoc 210 (entget e)))) ('(0.0 0.0 1.0))))
  )
  (if (and (listp o) (not (equal (list (car o) (cadr o)) (list (car q) (cadr q)) 1e-6)))
    (princ (strcat "\n--> Hatch origin not applied: "
                   (rtos (car o) 2 4) "," (rtos (cadr o) 2 4)
                   " in place of " (rtos (car q) 2 4) "," (rtos (cadr q) 2 4)
           )
    )
  )
)

;;  The optional settings of the material (see Remote>>Dyl:MaterialProps) are given to the
;;  outlines and to the hatch: its draw order (always behind its border) set while it is made
;;  (HPDRAWORDER, restored after; HPLAYER set to the current layer meanwhile, so a frozen
;;  HPLAYER layer never stops -HATCH), its background color once it is made (its BackgroundColor,
;;  see Remote>>Dyl:MaterialBackgroundPut). With No border, the
;;  hatch is not associative and the outlines are erased once it is made, but those the user
;;  selected (mt:keepouts T, set by the caller, e.g. Quick Draw Select closed objects). The
;;  boxes of a legend (mt:legend T, see Remote>>Dyl:MaterialLegend) are kept as drawn: no
;;  layer key, no border settings:
(defun Remote>>Dyl:MaterialHatchAt (mat outs ang / ss mark nob asc vars c org)
  (setq ss  (ssadd)
        nob (= "1" (nth 31 mat))
        asc (and (= "1" (nth 30 mat)) (not nob))
  )
  (foreach e outs
    (if (not mt:legend)
      (progn
        (Remote>>Dyl:LayerKeyApply e (nth 7 mat))
        (if (not nob) (Remote>>Dyl:MaterialProps e mat 'border))
      )
    )
    (if (Remote>>Dyl:MaterialClosed-p e) (ssadd e ss))
  )
  (if (< 0 (sslength ss))
    (progn
      ;;  Draw order of the new hatch (its background color is set once it is made, see below):
      ;;  A SOLID hatch has no background color (see *mt:solidoff*):
      (setq vars (list (cons "HPDRAWORDER" (getvar "HPDRAWORDER")))
            c    (if (/= "SOLID" (nth 3 mat)) (Remote>>Dyl:MaterialBackground mat))
      )
      (if (not nob) (vl-catch-all-apply 'setvar '("HPDRAWORDER" 3)))
      ;;  HPLAYER (the layer of new hatches, saved in the drawing): -HATCH makes that layer
      ;;  current while it hatches and fails when it is frozen ("Layer ... is frozen. Cannot
      ;;  be current layer until thawed."). The hatch goes to the layer of its hatch layer key
      ;;  once it is made (see below), so -HATCH uses the current layer ("."), restored after:
      (if (and (getvar "HPLAYER") (/= "." (getvar "HPLAYER")))
        (progn
          (setq vars (append vars (list (cons "HPLAYER" (getvar "HPLAYER")))))
          (vl-catch-all-apply 'setvar '("HPLAYER" "."))
        )
      )
      ;;  mt:origin: an origin given by the caller (WCS point, Quick Draw Linear: on the line),
      ;;  given to the hatch as it is made with the Origin option of -HATCH (Set new origin, in
      ;;  the UCS, no object snap, not stored as the default; HPORIGIN and HPORIGINMODE restored
      ;;  after), checked once it is made (see Remote>>Dyl:MaterialOriginCheck). Not moved once
      ;;  it is made: a failed Origin put left the hatch on the drawing origin:
      (setq org (if (and mt:origin (/= "SOLID" (nth 3 mat))) mt:origin))
      (if org
        (setq vars (append vars (list (cons "HPORIGINMODE" (getvar "HPORIGINMODE")) (cons "HPORIGIN" (getvar "HPORIGIN")))))
      )
      (setq mark (entlast))
      (if (/= "SOLID" (nth 3 mat))
        (apply 'command
               (append
                 '("_.-hatch")
                 (if org (list "_o" "_s" "_non" (Remote>>Dyl:MaterialUcs2d org) "_n"))
                 (list "_s"
                       ss
                       ""
                       "_an"
                       ;;  mt:scale: a scale given by the caller (Quick Draw Linear: width x factor),
                       ;;  a model size: never annotative (AutoCAD would multiply it by the
                       ;;  annotation scale, 25 wide drawn at 1:50 -> 1250):
                       (if (and (= "1" (nth 9 mat)) (not (numberp mt:scale))) "_y" "_n")
                       "_p"
                       (nth 3 mat)
                       (if (numberp mt:scale) mt:scale (Remote>>Dyl:MaterialScale mat))
                       (rtos (+ (cond ((distof (nth 6 mat) 2)) (0.0)) ang) 2 6)
                       "_a"
                       "_a"
                       (if asc "_y" "_n")
                       ""
                       ""
                 )
               )
        )
        (command "_.-hatch" "_s" ss "" "_an" "_n" "_p" (nth 3 mat) "_a" "_a" (if asc "_y" "_n") "" "")
      )
      (foreach v vars (if (cdr v) (vl-catch-all-apply 'setvar (list (car v) (cdr v)))))
      ;;  Put the hatch on the layer of the hatch layer key, with the hatch settings:
      (while (setq mark (entnext mark))
        (Remote>>Dyl:LayerKeyApply mark (nth 8 mat))
        (Remote>>Dyl:MaterialProps mark mat 'hatch)
        (if (= "HATCH" (cdr (assoc 0 (entget mark))))
          (progn
            (if org (Remote>>Dyl:MaterialOriginCheck mark org))
            ;;  The background color (the existing phase background while it applies), given
            ;;  to the hatch made rather than with HPBACKGROUNDCOLOR before -HATCH:
            (if c (Remote>>Dyl:MaterialBackgroundPut mark c))
          )
        )
      )
      ;;  No border: the closed outlines the hatch was made from are erased (not the other
      ;;  objects of outs, e.g. the lines of a Quick Shape shape):
      (if (and nob (not mt:keepouts))
        (foreach e (Remote>>LM:ss->ent ss) (if (entget e) (entdel e)))
      )
    )
  )
  (princ)
)

;;  T when the hatch e is annotative (its AcadAnnotative extended data):
(defun Remote>>Dyl:MaterialAnno-p (e)
  (if (assoc -3 (entget e '("AcadAnnotative"))) t)
)

;;  Make the hatch e annotative (on T) or not, with the ANnotative option of -HATCHEDIT, when
;;  it is not already. The command is ended whatever it asks:
(defun Remote>>Dyl:MaterialAnnoPut (e on / n)
  (if (/= on (Remote>>Dyl:MaterialAnno-p e))
    (progn
      (command "_.-hatchedit" e "_an" (if on "_y" "_n"))
      (setq n 0)
      (while (and (< 0 (logand 1 (getvar "CMDACTIVE"))) (< (setq n (1+ n)) 10)) (command ""))
    )
  )
)

;;  Replace the hatch of the existing hatch e by the one of the material mat (Quick Draw
;;  Replace, see *mt:methods*): its pattern, scale (see Remote>>Dyl:MaterialScale), angle and
;;  annotative, the layer of the hatch layer key, and the optional hatch settings. Its
;;  overrides are reset first (ByLayer, no background), so only those of the material are
;;  left. Its boundary, associativity, origin and draw order are kept; a gradient becomes a
;;  pattern hatch. Returns T, nil when it could not be changed (on a locked layer, pattern not
;;  found...), with a message:
(defun Remote>>Dyl:MaterialReplace (mat e / o pat res c)
  (setq o   (vlax-ename->vla-object e)
        pat (nth 3 mat)
  )
  ;;  Annotative first: the scale of an annotative hatch is a paper size (as when it is made):
  (vl-catch-all-apply 'Remote>>Dyl:MaterialAnnoPut (list e (and (/= "SOLID" pat) (= "1" (nth 9 mat)))))
  (setq res
         (vl-catch-all-apply
           '(lambda ()
              (if (= 1 (vla-get-HatchObjectType o)) (vla-put-HatchObjectType o 0))
              ;;  A pattern of acad.pat / acadiso.pat, else of its own .pat file:
              (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-SetPattern (list o acHatchPatternTypePreDefined pat)))
                (vla-SetPattern o acHatchPatternTypeCustomDefined pat)
              )
              (if (/= "SOLID" pat)
                (progn
                  (vla-put-PatternScale o (Remote>>Dyl:MaterialScale mat))
                  (vla-put-PatternAngle o (* pi (/ (cond ((distof (nth 6 mat) 2)) (0.0)) 180.0)))
                )
              )
              (vla-Evaluate o)
              ;;  The overrides of the hatch reset, then those of the material:
              (vla-put-Color o acByLayer)
              (vl-catch-all-apply 'vla-put-Linetype (list o "ByLayer"))
              (vl-catch-all-apply 'vla-put-LinetypeScale (list o 1.0))
              (vl-catch-all-apply 'vla-put-Lineweight (list o acLnWtByLayer))
              (vl-catch-all-apply 'vla-put-EntityTransparency (list o "ByLayer"))
              (vl-catch-all-apply
                '(lambda (/ bc)
                   (setq bc (vla-get-BackgroundColor o))
                   (vla-put-ColorMethod bc 200) ; acColorMethodNone: no background
                   (vla-put-BackgroundColor o bc)
                 )
              )
              (Remote>>Dyl:LayerKeyApply e (nth 8 mat))
              (Remote>>Dyl:MaterialProps e mat 'hatch)
              (if (and (/= "SOLID" pat) (setq c (Remote>>Dyl:MaterialBackground mat)))
                (Remote>>Dyl:MaterialBackgroundPut e c)
              )
              (vla-Update o)
              T
            )
         )
  )
  (if (vl-catch-all-error-p res)
    (progn
      (princ (strcat "\n--> Hatch not replaced: " (vl-catch-all-error-message res)))
      nil
    )
    T
  )
)

;;  One line describing the material mat:
(defun Remote>>Dyl:MaterialSummary (mat)
  (strcat (nth 3 mat)
          (if (= "SOLID" (nth 3 mat))
            ""
            (strcat ", scale "
                    (nth 4 mat)
                    ", angle "
                    (nth 6 mat)
                    (cond
                      ((= "1" (nth 9 mat)) ", annotative")
                      ((Remote>>Dyl:MaterialScaled-p mat) ", follows the drawing scale")
                      ("")
                    )
            )
          )
          " - layer key "
          (nth 8 mat)
  )
)

;;  Fill the material popup tile of a dialog with the materials mats (see
;;  Remote>>Dyl:MaterialRead), then the ids of ids that are not a material (deleted: they stay
;;  selectable, marked missing). A material of the group grp is shown by its name, the others
;;  "group - name" (grp nil: all of them, see Remote>>Dyl:PresetDlgMatFill). Returns the ids
;;  of the popup, in its order:
(defun Remote>>Dyl:MaterialPopup (tile mats ids grp / lst m)
  (setq lst (mapcar 'car mats))
  (foreach id ids
    (if (and (/= "" id) (not (member id lst))) (setq lst (append lst (list id))))
  )
  (start_list tile)
  (foreach id lst
    (add_list (cond
                ((not (setq m (assoc id mats))) (strcat id "   (missing hatch preset)"))
                ((and grp (= (strcase grp) (strcase (nth 1 m)))) (nth 2 m))
                ((strcat (nth 1 m) " - " (nth 2 m)))
              )
    )
  )
  (end_list)
  lst
)

;;-------------------------=={ Dialog }==------------------------;;

;;  The materials dialog is made by Remote>>Dyl:PresetDialog (Remote\Dyl-Presets.lsp), with the
;;  tiles below in its Parameters column. The functions below run inside it and use its local
;;  variable pst:lst, and the local variables of Remote>>Dyl:MaterialDialog: mt:pats (patterns
;;  of the Pattern popup), mt:found (patterns found in the .pat files), mt:keys (layer keys of
;;  the layer key popups).

;;  Tiles of the materials and index of their value in a material:
(setq *mt:tiles* '(("pat" . 3) ("typ" . 63) ("simp" . 4) ("ang" . 6) ("hat" . 8) ("ano" . 9)
                   ("sdw" . 10)
                   ;;  Hatch settings (checkbox, value; the border settings: in the presets,
                   ;;  see *mt:bordertiles*):
                   ("hco" . 22) ("hcl" . 23) ("hbo" . 24) ("hbg" . 25) ("hwo" . 26) ("hwt" . 27)
                   ("hto" . 28) ("htr" . 29)
                   ;;  Associative (a hatch without border, see the presets, is not):
                   ("asc" . 30)
                   ;;  Hatch: existing phase background (checkbox, color):
                   ("hxo" . 41) ("hxb" . 42)
                   ;;  Hatch settings: linetype and linetype scale (checkbox, value):
                   ("hlo" . 47) ("hlt" . 48) ("hso" . 49) ("hsc" . 50)
                  )
)

;;  Optional settings: (checkbox value-tiles...): the value tiles (and the open button of a
;;  color, see *mt:more*) are greyed out until the checkbox is checked:
(setq *mt:optional* '(("hco" "hcl" "hcp") ("hlo" "hlt") ("hso" "hsc") ("hbo" "hbg" "hbp") ("hxo" "hxb" "hxp")
                      ("hwo" "hwt") ("hto" "htr")
                     )
)

;;  Optional hatch settings a SOLID hatch does not use (greyed out, not set): background
;;  color, existing phase background, lineweight, linetype and linetype scale:
(setq *mt:solidoff* '("hbo" "hxo" "hwo" "hlo" "hso"))

;;  The open buttons of the colors (the color dialog) and of the layer keys (the Layer Keys
;;  window), their icon drawn by Dyl:MoreTile
;;  (dynalisp.mnl), greyed out with it in place of mode_tile:
(setq *mt:more* '("bcp" "hcp" "hbp" "hxp" "hkp" "okp" "suo"))

;;  mode_tile of the tile key (m: 0 on, 1 off), the icon of an open button redrawn:
(defun Remote>>Dyl:MaterialDlgMode (key m)
  (if (member key *mt:more*) (Dyl:MoreTile key (= 0 m)) (mode_tile key m))
)

;;  Lineweights of AutoCAD, in hundredths of mm:
(setq *mt:weights* '("0" "5" "9" "13" "15" "18" "20" "25" "30" "35" "40" "50" "53" "60" "70" "80" "90"
                     "100" "106" "120" "140" "158" "200" "211"
                    )
)

;;  Types of a material (Type column): a size on paper, or a real size (see
;;  Remote>>Dyl:MaterialFix):
(setq *mt:types* '("Drafting" "Model"))

;;  Popup tiles -> list of their values (nil for the other tiles):
(defun Remote>>Dyl:MaterialDlgItems (key)
  (cond
    ((= "pat" key) mt:pats)
    ((= "typ" key) *mt:types*)
    ((member key '("out" "hat")) mt:keys)
    ((member key '("bwt" "hwt")) *mt:weights*)
    ((= "mth" key) (cons "" (mapcar 'car *mt:methods*)))
    ((= "mjs" key) (mapcar 'car *mt:justify*))
    ((= "men" key) (mapcar 'car *mt:ends*))
    ((= "mco" key) (mapcar 'car *mt:corners*))
    ((= "mlt" key) (mapcar 'car *mt:laps*))
    ((= "mjo" key) (mapcar 'car *mt:joints*))
    ((= "mht" key) (mapcar 'car *mt:hatchmodes*))
  )
)

;;  Open button of a color: the AutoCAD color dialog on the color of the tile key, the color
;;  picked put in it ("n" or "r,g,b") and stored:
(defun Remote>>Dyl:MaterialDlgColor (key / c r tc val)
  (setq c (Remote>>Dyl:MaterialColorParse (get_tile key))
        r (acad_truecolordlg
            (if (= 3 (length c))
              (cons 420 (+ (* 65536 (car c)) (* 256 (cadr c)) (caddr c)))
              (cons 62 (if c (car c) 7))
            )
            nil
          )
  )
  (if r
    (progn
      (setq val (if (setq tc (cdr (assoc 420 r)))
                  (strcat (itoa (lsh tc -16)) "," (itoa (logand (lsh tc -8) 255)) "," (itoa (logand tc 255)))
                  (itoa (cdr (assoc 62 r)))
                )
      )
      (set_tile key val)
      (if (Remote>>Dyl:PresetDlgField key val) (Remote>>Dyl:PresetDlgState))
    )
  )
)

;;  Error message of an invalid value, nil when it is valid:
(defun Remote>>Dyl:MaterialDlgCheck (key val)
  (cond
    ((and (= "" val) (= "pat" key)) "The pattern cannot be empty.")
    ((and (= "" val) (member key '("out" "hat"))) "The layer key cannot be empty.")
    ((and (= "simp" key) (not (and (distof val) (< 0 (distof val)))))
     "The scale must be a number greater than 0."
    )
    ((and (member key '("bcv" "hcl" "hbg" "hxb")) (not (Remote>>Dyl:MaterialColorParse val)))
     "A color is an AutoCAD color number 1-255 or r,g,b (0-255 each), or use the open button beside it."
    )
    ((and (member key '("blt" "hlt")) (= "" val)) "The linetype cannot be empty.")
    ((and (member key '("bsc" "hsc")) (not (Remote>>Dyl:MaterialScale-p val))) "The linetype scale must be a number greater than 0.")
    ((and (member key '("btr" "htr")) (not (and (wcmatch val "#,##") (<= 0 (atoi val) 90))))
     "The transparency must be a whole number from 0 to 90."
    )
    ((and (= "mwd" key) (/= "" val) (not (Remote>>Dyl:MaterialWidths val)))
     "Widths must be numbers greater than 0, divided by commas (empty: the last width used)."
    )
    ((and (= "mfc" key) (not (Remote>>Dyl:MaterialScale-p val))) "The width factor must be a number greater than 0.")
    ((and (= "mgp" key) (/= "" val) (not (and (distof val 2) (<= 0 (distof val 2)))))
     "The gap tolerance must be a number, 0 or more (empty: asked when drawn)."
    )
    ((and (= "mof" key) (not (distof val 2))) "The origin Y offset must be a number (0: on the line).")
    ((and (= "moa" key) (not (distof val 2))) "The origin X offset must be a number (0: at the start of the segment).")
    ((and (= "msd" key) (/= "" val) (not (and (wcmatch val "#,##,###,####") (<= 3 (atoi val) 1024))))
     "The number of sides must be a whole number from 3 to 1024 (empty: asked when drawn)."
    )
    ((and (= "ang" key) (not (distof val))) "The angle must be a number.")
    ((and (= "mex" key) (/= "" val) (not (and (distof val 2) (<= 0 (distof val 2)))))
     "The extension must be a number, 0 or more (empty: half the width)."
    )
    ((and (= "mea" key) (not (and (distof val 2) (<= -80 (distof val 2) 80))))
     "The end angle must be a number from -80 to 80 (0: square)."
    )
    ((and (= "mml" key) (not (and (distof val 2) (<= 1 (distof val 2)))))
     "The miter limit must be a number, 1 or more (x the width)."
    )
  )
)

;;  Fill the layer key popups tiles (the hatch key of the Materials window, the border key of
;;  the Border settings box) and mt:keys: keys of LayerKeys.csv and the keys of used (those of
;;  the materials or presets) that are not defined (drawn on a layer of the same name, marked
;;  "(not defined)"), sorted by key. The keys only, without their layer: a clean list. The
;;  keys kept for compatibility only are left out (see Remote>>Dyl:LayerKeyMaterial-p):
(defun Remote>>Dyl:MaterialDlgKeys (tiles used / lks)
  (setq lks     (Remote>>Dyl:LayerKeyRead)
        mt:keys (vl-remove-if-not 'Remote>>Dyl:LayerKeyMaterial-p (mapcar 'car lks))
  )
  (foreach k used
    (if (and (= 'STR (type k)) (/= "" k) (not (member k mt:keys)) (Remote>>Dyl:LayerKeyMaterial-p k))
      (setq mt:keys (append mt:keys (list k)))
    )
  )
  (setq mt:keys (vl-sort mt:keys '(lambda (a b) (< (strcase a) (strcase b)))))
  (foreach tile tiles
    (start_list tile)
    (foreach k mt:keys (add_list (if (assoc k lks) k (strcat k "   (not defined)"))))
    (end_list)
  )
)

;;  Fill the popups and set the action of the open buttons (each time the dialog is shown):
(defun Remote>>Dyl:MaterialDlgInit ()
  (if (not mt:pats)
    (progn
      (setq mt:found       (Remote>>Dyl:SupportDefs "pat")
            mt:pats        mt:found
            ;;  The units of the patterns found again (a .pat file added or changed):
            *mt:patunits* nil
      )
      ;;  The patterns used by the materials stay selectable even when no .pat file defines them:
      (foreach nam (append '("SOLID" "ANSI31") (mapcar 'cadddr (Remote>>Dyl:MaterialDefs)) (mapcar 'cadddr pst:lst))
        (if (not (member nam mt:pats)) (setq mt:pats (cons nam mt:pats)))
      )
      (setq mt:pats (acad_strlsort mt:pats))
    )
  )
  (start_list "pat")
  (foreach nam mt:pats
    (add_list (if (member nam mt:found) nam (strcat nam "   (not found on the support path)")))
  )
  (end_list)
  (Remote>>Dyl:MaterialDlgKeys '("hat") (mapcar '(lambda (r) (nth 8 r)) (append (Remote>>Dyl:MaterialDefs) pst:lst)))
  (start_list "typ")
  (foreach x *mt:types* (add_list x))
  (end_list)
  ;;  Lineweight popup, in mm:
  (start_list "hwt")
  (foreach w *mt:weights* (add_list (strcat (rtos (/ (atoi w) 100.0) 2 2) " mm")))
  (end_list)
  ;;  Open buttons of the colors:
  (action_tile "hcp" "(Remote>>Dyl:MaterialDlgColor \"hcl\")")
  (action_tile "hbp" "(Remote>>Dyl:MaterialDlgColor \"hbg\")")
  (action_tile "hxp" "(Remote>>Dyl:MaterialDlgColor \"hxb\")")
  ;;  Open button of the layer key: close the dialog with code 5, see Remote>>Dyl:MaterialDlgStatus:
  (action_tile "hkp" "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog 5))")
  ;;  Draw legend...: close the dialog with *mt:legendcode*, see Remote>>Dyl:MaterialDlgStatus:
  (action_tile "leg" (strcat "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog " (itoa *mt:legendcode*) "))"))
  ;;  Pick hatch...: close the dialog with *mt:hatchpickcode*, see Remote>>Dyl:MaterialDlgStatus:
  (action_tile "hpk" (strcat "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog " (itoa *mt:hatchpickcode*) "))"))
  (action_tile "suo" "(Remote>>Dyl:MaterialPatOpen (nth 3 (nth pst:idx pst:lst)))")
  ;;  The dividing line over the title of the sub-section (dynalisp.mnl):
  (Dyl:LineTile "hsep")
)

;;-------------------------=={ Border settings box }==------------------------;;

;;  The Border settings box of the Quick Draw and Quick Shape windows: the border of a preset
;;  (its layer key, the overrides of its properties, its transparency and, in Quick Draw, Has
;;  a border). Each preset has its own; they are put in the border columns of its material
;;  when it is drawn (Remote>>Dyl:MaterialBorderPut), so Remote>>Dyl:MaterialHatchAt and the
;;  box read them at the index of a material. Kept here with the materials, whose columns
;;  they use (no longer in the Materials window).

;;  Tiles of the box, with the index of their value in a material (No border, 31, is not a
;;  tile: the Has a border checkbox shows it inverted, see Remote>>Dyl:MaterialDlgBorder):
(setq *mt:bordertiles* '(("out" . 7) ("bco" . 12) ("bcv" . 13) ("blo" . 14) ("blt" . 15) ("bso" . 16)
                         ("bsc" . 17) ("bwo" . 18) ("bwt" . 19) ("bto" . 20) ("btr" . 21)
                        )
)

;;  Optional settings of the box: (checkbox value-tiles...), as *mt:optional*:
(setq *mt:borderoptional* '(("bco" "bcv" "bcp") ("blo" "blt") ("bso" "bsc") ("bwo" "bwt") ("bto" "btr")))

;;  Code the open button of the layer key of the box closes the window with (the status
;;  function of the tool calls Remote>>Dyl:MaterialDlgBorderStatus for it):
(setq *mt:borderkeypick* 6)

;;  Tiles of the box with the index of their value in a preset whose border columns start at
;;  start (the layer key, then the optional settings, in the order of *mt:bordertiles*):
(defun Remote>>Dyl:MaterialBorderTiles (start / i)
  (setq i (1- start))
  (mapcar '(lambda (x) (cons (car x) (setq i (1+ i)))) *mt:bordertiles*)
)

;;  The material mat with the border of the preset r (its border columns from start, its No
;;  border at index nob; nob nil: always a border) in its border columns:
(defun Remote>>Dyl:MaterialBorderPut (mat r start nob / i)
  (setq i (1- start))
  (foreach x *mt:bordertiles*
    (setq mat (Remote>>Dyl:ListSubst mat (cdr x) (nth (setq i (1+ i)) r)))
  )
  (Remote>>Dyl:ListSubst mat 31 (if nob (nth nob r) "0"))
)

;;  The preset r with the border of the material mat (see Remote>>Dyl:MaterialBorderPut):
(defun Remote>>Dyl:MaterialBorderOf (r mat start nob / i)
  (setq i (1- start))
  (foreach x *mt:bordertiles*
    (setq r (Remote>>Dyl:ListSubst r (setq i (1+ i)) (nth (cdr x) mat)))
  )
  (if nob (Remote>>Dyl:ListSubst r nob (nth 31 mat)) r)
)

;;  DCL lines of the box (under the shape in Quick Shape, under the Behaviors box in Quick
;;  Draw). nob T: with the Has a border checkbox (Quick Draw; a Quick Shape shape always has
;;  its border). wide T: in two columns (Quick Draw), else one column. Each sub-section a
;;  column of fixed height, the spacers between them take the extra height (see
;;  CONVENTIONS.md, Windows):
(defun Remote>>Dyl:MaterialBorderDcl (nob wide / key ovr opt)
  ;;  The layer key (and Has a border: off, No border, the outlines erased once hatched, the
  ;;  rest of the box greyed out):
  (setq key (append
              (if nob '("            : row { : toggle { key = \"hbr\"; label = \"Has a border\"; } }"))
              '(;;  The layer key, its open button the Layer Keys window (see Remote>>Dyl:MaterialDlgBorderStatus):
                "            : row { : text { key = \"outl\"; label = \"Layer key:\"; }"
                "                    : image_button { key = \"okp\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
                "                    : popup_list { key = \"out\"; edit_width = 28; fixed_width = true; } }"
               )
            )
        ;;  The settings that override the properties of the layer key:
        ovr '("            : row { : text { key = \"bovt\"; label = \"Layer key overrides:\"; } }"
              "            : row { : toggle { key = \"bco\"; label = \"Color:\"; width = 28; }"
              "                    : image_button { key = \"bcp\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
              "                    : edit_box { key = \"bcv\"; edit_width = 12; fixed_width = true; } }"
              "            : row { : toggle { key = \"blo\"; label = \"Linetype:\"; width = 28; }"
              "                    : edit_box { key = \"blt\"; edit_width = 12; fixed_width = true; } }"
              "            : row { : toggle { key = \"bso\"; label = \"Linetype scale:\"; width = 28; }"
              "                    : edit_box { key = \"bsc\"; edit_width = 12; fixed_width = true; } }"
              "            : row { : toggle { key = \"bwo\"; label = \"Lineweight:\"; width = 28; }"
              "                    : popup_list { key = \"bwt\"; edit_width = 12; fixed_width = true; } }"
             )
        ;;  The settings that are not a property of the layer key, a dividing line over them:
        opt '("            : image { key = \"bsep2\"; height = 0.8; fixed_height = true; color = -15; }"
              "            : row { : text { key = \"bopt\"; label = \"Optional settings:\"; } }"
              "            : row { : toggle { key = \"bto\"; label = \"Transparency:\"; width = 28; }"
              "                    : edit_box { key = \"btr\"; edit_width = 12; fixed_width = true; } }"
             )
  )
  (append
    '("          : boxed_column { label = \"Border settings\";")
    (if wide
      ;;  Two columns: the layer key and the optional settings, then the overrides, divided by
      ;;  a vertical line (bsep, drawn by Dyl:LineTile as the line of the one column box):
      (append '("            : row {" "            : column {" "            : column { fixed_height = true;")
              key
              '("            }" "            : spacer { }" "            : column { fixed_height = true;")
              opt
              '("            }" "            }"
                "            : image { key = \"bsep\"; width = 2; height = 1; fixed_width = true; color = -15; }"
                "            : column {" "            : column { fixed_height = true;"
               )
              ovr
              '("            }" "            : spacer { }" "            }" "            }")
      )
      ;;  One column: the layer key, the overrides, the optional settings, a dividing line
      ;;  over the title of the last two:
      (append '("            : column { fixed_height = true;")
              key
              '("            }" "            : spacer { }" "            : column { fixed_height = true;"
                "            : image { key = \"bsep\"; height = 0.8; fixed_height = true; color = -15; }"
               )
              ovr
              '("            }" "            : spacer { }" "            : column { fixed_height = true;")
              opt
              '("            }")
      )
    )
    '("          }")
  )
)

;;  The layer keys of the box, the Lineweight popup, the open buttons of the color and of the
;;  layer key, the dividing lines, and Has a border (nob: the index of No border in a preset,
;;  nil without the checkbox). used: the layer keys of the presets (kept in the popup when
;;  they are not defined). Each time the dialog is shown:
(defun Remote>>Dyl:MaterialDlgBorderInit (used nob)
  (Remote>>Dyl:MaterialDlgKeys '("out") used)
  (start_list "bwt")
  (foreach w *mt:weights* (add_list (strcat (rtos (/ (atoi w) 100.0) 2 2) " mm")))
  (end_list)
  (action_tile "bcp" "(Remote>>Dyl:MaterialDlgColor \"bcv\")")
  (action_tile "okp" (strcat "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog " (itoa *mt:borderkeypick*) "))"))
  (foreach k '("bsep" "bsep2") (Dyl:LineTile k))
  (if nob (action_tile "hbr" (strcat "(Remote>>Dyl:MaterialDlgBorder $value " (itoa nob) ")")))
)

;;  Has a border checkbox (value val): No border (index i in a preset) of the presets
;;  selected, its inverse (see Remote>>Dyl:PresetDlgPut):
(defun Remote>>Dyl:MaterialDlgBorder (val i)
  (Remote>>Dyl:PresetDlgPut i (if (= "1" val) "0" "1"))
  (Remote>>Dyl:PresetDlgState)
)

;;  Enable the tiles of the box for the border of the material m (the material of a preset
;;  with its border, see Remote>>Dyl:MaterialBorderPut). nob T: with Has a border, unchecked
;;  it greys out the rest of the box. An optional setting has its value greyed out until its
;;  checkbox is checked:
(defun Remote>>Dyl:MaterialDlgBorderState (m nob / off tog)
  (setq off (and nob (= "1" (nth 31 m))))
  (foreach x *mt:borderoptional*
    (setq tog (= "1" (nth (cdr (assoc (car x) *mt:bordertiles*)) m)))
    (if off
      (foreach k x (Remote>>Dyl:MaterialDlgMode k 1))
      (progn
        (mode_tile (car x) 0)
        (foreach k (cdr x) (Remote>>Dyl:MaterialDlgMode k (if tog 0 1)))
      )
    )
  )
  (if nob (set_tile "hbr" (if off "0" "1")))
  (foreach k '("out" "outl" "okp" "bovt" "bopt") (Remote>>Dyl:MaterialDlgMode k (if off 1 0)))
)

;;  Code *mt:borderkeypick* = the open button of the layer key of the box: the Layer Keys
;;  dialog is shown on the key of the preset r (column i), then the dialog of the tool again;
;;  a key double-clicked in it becomes the border layer key of every preset selected:
(defun Remote>>Dyl:MaterialDlgBorderStatus (sta r i / k)
  (if (and (= sta *mt:borderkeypick*) (setq k (Remote>>Dyl:LayerKeyPick (nth i r))))
    (Remote>>Dyl:PresetDlgPut i k)
  )
)


;;-------------------------=={ Material behaviors box }==------------------------;;

;;  The Material behaviors box of the Quick Draw window: how a preset is drawn (see
;;  Dyl:QuickDrawRun, Apps\Draw\Dyl-QuickDraw.lsp). Each preset has its own behaviors; they
;;  are put in the behavior columns of its material when it is drawn (Dyl:QuickDrawMat), so
;;  the box and Dyl:QuickDraw read them at the index of a material. Kept here with the
;;  materials, whose columns they use (no longer in the Materials window).

;;  Tiles of the box, with the index of their value in a material:
(setq *mt:behaviortiles* '(("mth" . 33) ("mwd" . 34) ("mjs" . 35) ("msd" . 36) ("msw" . 37) ("mfc" . 38)
                           ("mor" . 39) ("mof" . 40) ("mgp" . 43) ("mgo" . 44) ("moa" . 46)
                           ;;  Bands: ends, extension, end angle, corners, miter limit, lap,
                           ;;  joints, hatch:
                           ("men" . 51) ("mex" . 52) ("mea" . 53) ("mco" . 54) ("mml" . 55) ("mlt" . 56)
                           ("mjo" . 57) ("mht" . 58)
                           ;;  The assembly of Linear (on/off; its layers, column 60, are edited
                           ;;  in the Assembly Layers window, see *mt:layerspick*):
                           ("mas" . 59)
                           ;;  Its own ends and corners (their values: the Ends and Corners
                           ;;  windows, see *mt:endspick*):
                           ("meo" . 61) ("mcn" . 62)
                          )
)

;;  The layers of the assembly in a material (see Remote>>Dyl:MaterialLayers):
(setq *mt:layerscol* 60)

;;  Code the Pick... button of the box closes the window with (the status function of the
;;  Quick Draw window calls Remote>>Dyl:MaterialOriginPick for it), and the code of the open
;;  button of the assembly (the Assembly Layers window, see Dyl:QuickDrawLayersDialog):
(setq *mt:originpick* 4
      *mt:layerspick* 5
      ;;  The open buttons of the ends and of the corners: the Ends and Corners windows (see
      ;;  Dyl:QuickDrawBandDialog):
      *mt:endspick* 3
      *mt:cornerspick* 7
)

;;  DCL lines of the Behaviors box (see the parameters of Dyl:QuickDrawDialog): a row for
;;  each value, its box at the right, in two columns divided by a vertical line (drawn by
;;  Dyl:LineTile, see Remote>>Dyl:MaterialDlgBehaviorsInit). The left column: the hatch preset
;;  of the preset (the rows of the preset engine, same keys, see (matinparams . T) in
;;  Remote\Dyl-Presets.lsp; greyed out for an assembly: each layer is hatched as its own
;;  preset says), the assembly of layers (Linear, Offset), the method and the values of
;;  Polygon and Shrinkwrap. The right column: the bands of Linear and Offset (their width,
;;  where the line is, their own ends and corners, set in the Ends and Corners windows by the
;;  open buttons, see *mt:endspick*) and the hatch along the line. Each sub-section a column
;;  of fixed height, the spacers between them take the extra height:
(setq *mt:behaviordcl*
  '("          : boxed_column { label = \"Behaviors\";"
    "            : row {"
    "            : column {"
    "            : column { fixed_height = true;"
    "            : row { : popup_list { key = \"mth\"; label = \"Draw with:\"; edit_width = 28; } }"
    "            : row { : text { key = \"matl\"; label = \"Hatch preset:\"; }"
    "                    : image_button { key = \"edm\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
    "                    : popup_list { key = \"mat\"; edit_width = 28; fixed_width = true; } }"
    ;;  A band of several layers (Linear, Offset; its width: their total, shown in Width),
    ;;  edited in the Assembly Layers window (the open button):
    "            : row { : toggle { key = \"mas\"; label = \"Assembly of layers\"; width = 20; }"
    "                    : image_button { key = \"mae\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
    "                    : text { key = \"mai\"; width = 12; fixed_width = true; } }"
    "            : row { : edit_box { key = \"msd\"; label = \"Sides:\"; edit_width = 12; } }"
    ;;  Shrinkwrap gap: off, the gap step of Dyl-Settings from 0; on, the gap of the
    ;;  drawing units (MEASUREMENT), asked when drawn when it is empty:
    "            : row { : toggle { key = \"mgo\"; label = \"Gap override\"; } }"
    ;;  One gap, in drawing units whatever they are (the metric gap of an older file: see
    ;;  Remote>>Dyl:MaterialFix):
    "            : row { : edit_box { key = \"mgp\"; label = \"Gap:\"; edit_width = 12; } }"
    "            }"
    "            : spacer { }"
    "            }"
    "            : image { key = \"mbv\"; width = 2; height = 1; fixed_width = true; color = -15; }"
    "            : column {"
    "            : column { fixed_height = true;"
    ;;  At the top of the column: its title only (the border of the box above it):
    "            : text { label = \"Bands:\"; }"
    ;;  Width: the total of the layers of an assembly, greyed out:
    "            : row { : edit_box { key = \"mwd\"; label = \"Width:\"; edit_width = 12; edit_limit = 128; } }"
    "            : row { : popup_list { key = \"mjs\"; label = \"Justification:\"; edit_width = 28; } }"
    ;;  Off: square ends, mitered corners (see Dyl:QuickDrawBandOpts); on: those of the
    ;;  Ends / Corners window (the open button), summed up beside it:
    "            : row { : toggle { key = \"meo\"; label = \"Custom ends\"; width = 20; }"
    "                    : image_button { key = \"mee\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
    "                    : text { key = \"mei\"; width = 24; fixed_width = true; } }"
    "            : row { : toggle { key = \"mcn\"; label = \"Custom corners\"; width = 20; }"
    "                    : image_button { key = \"mce\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
    "                    : text { key = \"mci\"; width = 24; fixed_width = true; } }"
    "            }"
    "            : spacer { }"
    "            : column { fixed_height = true;"
    "            : image { key = \"mbs2\"; height = 0.8; fixed_height = true; color = -15; }"
    "            : text { label = \"Hatch:\"; }"
    "            : row { : popup_list { key = \"mht\"; label = \"Align to:\"; edit_width = 28; } }"
    "            : row { : toggle { key = \"msw\"; label = \"Scale by width\"; width = 28; }"
    "                    : edit_box { key = \"mfc\"; edit_width = 12; fixed_width = true; } }"
    ;;  Hatch origin on the line, offset X along the line and Y across it (Pick...: picked on
    ;;  a sample band, see Remote>>Dyl:MaterialOriginPick):
    "            : row { : toggle { key = \"mor\"; label = \"Origin on line\"; width = 28; }"
    "                    : button { key = \"mop\"; label = \"Pick...\"; width = 12; fixed_width = true; } }"
    "            : row { : edit_box { key = \"moa\"; label = \"Offset X:\"; edit_width = 12; } }"
    "            : row { : edit_box { key = \"mof\"; label = \"Offset Y:\"; edit_width = 12; } }"
    "            }"
    "            }"
    "            }"
    "          }"
   )
)

;;  The tiles of the Ends and of the Corners windows (Dyl:QuickDrawBandDialog), not tiles of
;;  the Behaviors box: kind -> (title (key label kind) ...), kind of a tile: list (a popup of
;;  the list), edit (an edit box):
(setq *mt:bandwindows*
  (list (list "Ends" "Ends"
              (list "men" "Ends:" *mt:ends*)
              (list "mex" "Extension:" 'edit)
              (list "mea" "Angle:" 'edit)
        )
        (list "Corners" "Corners"
              (list "mco" "Corners:" *mt:corners*)
              (list "mml" "Miter limit:" 'edit)
              (list "mlt" "Lap:" *mt:laps*)
              (list "mjo" "Joints:" *mt:joints*)
        )
  )
)

;;  A summary of the ends (61) or corners (62) of the material r, beside their checkbox:
(defun Remote>>Dyl:MaterialBandText (r kind / on)
  (setq on (= "1" (nth (if (= "Ends" kind) 61 62) r)))
  (cond
    ((= "Ends" kind)
     (if on
       (strcat (cond ((cadr (assoc (nth 51 r) *mt:ends*))) ((nth 51 r)))
               (cond
                 ((= "Extended" (nth 51 r)) (if (= "" (nth 52 r)) ", half width" (strcat ", " (nth 52 r))))
                 ((= "Angled" (nth 51 r)) (strcat ", " (nth 53 r) " deg"))
                 ("")
               )
       )
       "Square"
     )
    )
    (on
     (strcat (cond ((cadr (assoc (nth 54 r) *mt:corners*))) ((nth 54 r)))
             (if (= "Uninterrupted" (nth 57 r)) ", one border" "")
     )
    )
    ("Mitered")
  )
)

;;  Fill the Draw with and Line on popups of the box, set the action of Pick... (the values
;;  typed must be valid first):
(defun Remote>>Dyl:MaterialDlgBehaviorsInit ()
  (start_list "mth")
  (foreach x (cons '("" "Ask when drawn") *mt:methods*) (add_list (cadr x)))
  (end_list)
  (start_list "mjs")
  (foreach x *mt:justify* (add_list (cadr x)))
  (end_list)
  ;;  (the ends and corners: in their own windows, see Dyl:QuickDrawBandDialog)
  (start_list "mht")
  (foreach y *mt:hatchmodes* (add_list (cadr y)))
  (end_list)
  (foreach k '("mbs2" "mbv") (Dyl:LineTile k))
  (action_tile "mop" (strcat "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog " (itoa *mt:originpick*) "))"))
  (action_tile "mae" (strcat "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog " (itoa *mt:layerspick* ) "))"))
  (action_tile "mee" (strcat "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog " (itoa *mt:endspick* ) "))"))
  (action_tile "mce" (strcat "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog " (itoa *mt:cornerspick* ) "))"))
)

;;  Repeat of the pattern of the hatch e, in drawing units (its scale and angle applied): the
;;  largest one of its pattern lines, the offset between two lines plus the length of the
;;  dashes along them; 0.0 for a hatch without pattern lines (SOLID):
(defun Remote>>Dyl:MaterialRepeat (e / res o p)
  (setq res 0.0)
  (foreach g (append (member (assoc 53 (entget e)) (entget e)) '((53 . 0.0)))
    (cond
      ((= 53 (car g))
       (if o (setq res (max res (+ (distance '(0.0 0.0) o) p))))
       (setq o '(0.0 0.0)
             p 0.0
       )
      )
      ((= 45 (car g)) (setq o (list (cdr g) (cadr o))))
      ((= 46 (car g)) (setq o (list (car o) (cdr g))))
      ((= 49 (car g)) (setq p (+ p (abs (cdr g)))))
    )
  )
  res
)

;;  Line from a to b (UCS) of the color col, on the current layer:
(defun Remote>>Dyl:MaterialLine (a b col)
  (entmakex (list '(0 . "LINE") (cons 8 (getvar "CLAYER")) (cons 62 col) (cons 10 (trans a 1 0)) (cons 11 (trans b 1 0))))
)

;;  Sample band of Remote>>Dyl:MaterialOriginPick: the material mat hatched (as Quick Draw
;;  does, see Dyl:QuickDraw) in a band from s to e (the line, UCS, at the elevation z) and
;;  from hi to lo across it, from the origin of the line (moved by aln along it, sgn x off
;;  across it). The line and its start (a circle of the width w / 8) in red; rb, the borders
;;  of the real band (hi lo) when the sample is wider, in green; the current origin of the
;;  hatch, a magenta cross (a width / 2 wide). Uses mt:scale and mt:keepouts of the caller.
;;  Returns the entities made:
(defun Remote>>Dyl:MaterialSample (mat s e hi lo rb w sgn off aln z / mt:origin mark ents o k)
  (setq mark      (entlast)
        o         (list (+ (car s) aln) (+ (cadr s) (* sgn off)) z)
        k         (/ w 4.0)
        mt:origin (trans o 1 0)
  )
  (Remote>>Dyl:MaterialHatchAt
    mat
    (list (entmakex (append (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") (cons 8 (getvar "CLAYER"))
                                  '(100 . "AcDbPolyline") '(90 . 4) '(70 . 1)
                                  (cons 38 (caddr (trans s 1 0)))
                            )
                            (mapcar '(lambda (p) (setq p (trans p 1 0)) (list 10 (car p) (cadr p)))
                                    (list (list (car s) hi z) (list (car e) hi z) (list (car e) lo z) (list (car s) lo z))
                            )
                    )
          )
    )
    0.0
  )
  (Remote>>Dyl:MaterialLine s e 1)
  (entmakex (list '(0 . "CIRCLE") (cons 8 (getvar "CLAYER")) '(62 . 1) (cons 10 (trans s 1 0)) (cons 40 (/ w 8.0))))
  (foreach y rb (Remote>>Dyl:MaterialLine (list (car s) y z) (list (car e) y z) 3))
  (Remote>>Dyl:MaterialLine (list (- (car o) k) (cadr o) z) (list (+ (car o) k) (cadr o) z) 6)
  (Remote>>Dyl:MaterialLine (list (car o) (- (cadr o) k) z) (list (car o) (+ (cadr o) k) z) 6)
  (while (setq mark (if mark (entnext mark) (entnext))) (setq ents (cons mark ents)))
  ents
)

;;  Pick... of the box (the window closed with *mt:originpick*): a sample Linear band of the
;;  material mat (the values being edited) is drawn in the middle of the view along the X
;;  axis of the UCS, from its start (the red circle on the red line), with the width (the
;;  first one; none: the last one used, else asked) and the justify of mat, hatched from its
;;  current origin, and zoomed to. The sample is at least 8 widths long, and long and wide
;;  enough to show the whole pattern 2.5 times (see Remote>>Dyl:MaterialRepeat): wider than
;;  the band, its real borders are shown in green. The point picked is a point of the pattern
;;  as drawn (e.g. the edge of an insulation), to put on the line (the chosen border or the
;;  center line) at its start: the origin is moved by the start of the line minus that point.
;;  Its new offsets from the start of the line, X along it and Y across it (positive into
;;  the band; with Hatch scale = width x, in pattern units: divided by the hatch scale of the
;;  sample, see Dyl:QuickDrawLinear), go to the selected row of pst:lst (local of Remote>>Dyl:PresetDialog) with
;;  Hatch origin on the line checked; tiles gives the index in that row of each tile of the
;;  box (*mt:behaviortiles*, *qd:tiles*). The sample is erased and the view restored after,
;;  Esc included:
(defun Remote>>Dyl:MaterialOriginPick (mat tiles / mt:scale mt:keepouts doc w jus sd sgn off aln c z
                                       len hi lo shi slo rep m s e ents p r x y cmd u)
  (setq w (car (Remote>>Dyl:MaterialWidths (nth 34 mat))))
  (if (not w) (setq w (distof (cond ((getenv "DynalispQuickDrawWidth")) ("")) 2)))
  (if (not (and w (< 0 w)))
    (progn
      (initget 6)
      (setq w (vl-catch-all-apply 'getdist '("\nWidth of the sample band: ")))
      (if (not (numberp w)) (setq w nil))
    )
  )
  (if w
    (progn
      ;;  The justify of mat ("Ask": the last one given, see Dyl:QuickDrawLinear); the sides of
      ;;  the band from the line (positive: on its left, as Dyl:QuickDrawSides):
      (setq jus (nth 35 mat))
      (if (= "Ask" jus) (setq jus (getenv "DynalispQuickDrawJustify")))
      ;;  Edge: the band on the left of the line (above it), the line its right border:
      (setq jus (if (member jus '("Edge" "Left" "Right")) "Right" "Center"))
      (setq sd          (cond ((= "Left" jus) (list 0.0 (- w))) ((= "Right" jus) (list w 0.0)) ((list (/ w 2.0) (/ w -2.0))))
            sgn         (if (= "Left" jus) -1.0 1.0)
            off         (cond ((distof (nth 40 mat) 2)) (0.0))
            aln         (cond ((distof (nth 46 mat) 2)) (0.0))
            ;;  The line in the middle of the view (UCS), 8 widths long to start with:
            c           (getvar "VIEWCTR")
            z           (getvar "ELEVATION")
            len         (* 8.0 w)
            s           (list (- (car c) (/ len 2.0)) (cadr c) z)
            e           (list (+ (car c) (/ len 2.0)) (cadr c) z)
            hi          (+ (cadr c) (car sd))
            lo          (+ (cadr c) (cadr sd))
            shi         hi
            slo         lo
            mt:keepouts T
            mt:scale    (if (= "1" (nth 37 mat)) (* w (cond ((distof (nth 38 mat) 2)) (1.0))))
            ;;  The offsets in drawing units: x the hatch scale when it is the width x factor:
            u           (cond (mt:scale) (1.0))
            doc         (vla-get-ActiveDocument (vlax-get-acad-object))
            cmd         (getvar "CMDECHO")
      )
      (vla-StartUndoMark doc)
      (setvar "CMDECHO" 0)
      (setq ents (Remote>>Dyl:MaterialSample mat s e hi lo nil w sgn (* u off) (* u aln) z)
            ;;  The whole pattern 2.5 times along and across the sample:
            rep  (* 2.5
                    (cond
                      ((vl-some '(lambda (x) (if (= "HATCH" (cdr (assoc 0 (entget x)))) (Remote>>Dyl:MaterialRepeat x))) ents))
                      (0.0)
                    )
                 )
      )
      (if (or (< len rep) (< (- hi lo) rep))
        (progn
          (foreach x ents (if (entget x) (entdel x)))
          (setq len (max len rep)
                s   (list (- (car c) (/ len 2.0)) (cadr c) z)
                e   (list (+ (car c) (/ len 2.0)) (cadr c) z)
          )
          (if (< (- hi lo) rep)
            (setq shi (+ hi (/ (- rep (- hi lo)) 2.0))
                  slo (- lo (/ (- rep (- hi lo)) 2.0))
            )
          )
          (setq ents (Remote>>Dyl:MaterialSample mat s e shi slo (if (/= shi hi) (list hi lo)) w sgn (* u off) (* u aln) z))
        )
      )
      (setq m (max w (* 0.05 len)))
      (vl-catch-all-apply 'vl-cmdf (list "_.zoom" "_w" (list (- (car s) m) (- slo m)) (list (+ (car e) m) (+ shi m))))
      (princ (strcat "\nSample band of \"" (nth 2 mat) "\": the line in red starts at the circle, the magenta cross is the current origin (X "
                     (Remote>>Dyl:MaterialNum aln) ", Y " (Remote>>Dyl:MaterialNum off) ")."))
      (if (/= shi hi) (princ " Wider than the band to show the whole pattern: its borders are in green."))
      (setq p (vl-catch-all-apply 'getpoint '("\nPick the point of the pattern to put at the start of the line (red circle) <cancel>: ")))
      ;;  The sample erased, the view restored:
      (foreach x ents (if (entget x) (entdel x)))
      (vl-catch-all-apply 'vl-cmdf '("_.zoom" "_p"))
      (setvar "CMDECHO" cmd)
      (vla-EndUndoMark doc)
      (redraw)
      (if (and p (listp p))
        (progn
          ;;  The pattern moved by the start of the line minus p: the point of the pattern
          ;;  picked lands on the start of the line (the origin moved by as much):
          (setq x (Remote>>Dyl:MaterialNumP (- aln (/ (- (car p) (car s)) u)) 6)
                y (Remote>>Dyl:MaterialNumP (- off (/ (* sgn (- (cadr p) (cadr s))) u)) 6)
          )
          ;;  To every preset selected (see Remote>>Dyl:PresetDlgPut):
          (foreach v (list (cons "mor" "1") (cons "moa" x) (cons "mof" y))
            (Remote>>Dyl:PresetDlgPut (cdr (assoc (car v) tiles)) (cdr v))
          )
          (princ (strcat "\nHatch origin on the line: X (along) " x ", Y (across) " y
                         (if mt:scale " (pattern units: x the hatch scale, width x factor)." ".")
                 )
          )
        )
        (princ "\nHatch origin not changed.")
      )
    )
  )
  (princ)
)

;;  Enable the tiles of the box for the behaviors of the material r (on nil: all greyed out).
;;  The width and justify of Linear, the sides of Polygon, set for their method and for Ask
;;  when drawn (the method picked when drawn uses them too). The hatch scale from the width
;;  and the hatch origin on the line: not for a SOLID hatch:
(defun Remote>>Dyl:MaterialDlgBehaviors (r on / solid m asm)
  (setq solid (= "SOLID" (nth 3 r))
        m     (nth 33 r)
        ;;  An assembly (Linear, Offset): each layer is hatched as its preset says, the width
        ;;  is the total of the layers: the width and the hatch along the line of the preset
        ;;  unused:
        asm   (and on (member m '("Linear" "Offset" "")) (= "1" (nth 59 r)))
  )
  (mode_tile "mth" (if on 0 1))
  ;;  Offset: the side of the band is picked, its justification is not used:
  (mode_tile "mwd" (if (and on (not asm) (member m '("Linear" "Offset" ""))) 0 1))
  (mode_tile "mjs" (if (and on (member m '("Linear" ""))) 0 1))
  ;;  The assembly, its open button until it is checked:
  (mode_tile "mas" (if (and on (member m '("Linear" "Offset" ""))) 0 1))
  (Dyl:MoreTile "mae" asm)
  (set_tile "mai" (Remote>>Dyl:MaterialLayersText (nth 60 r)))
  (if asm (setq solid T))
  (foreach k '("msw" "mor" "mop") (mode_tile k (if (and on (not solid) (member m '("Linear" "Offset" ""))) 0 1)))
  (mode_tile "msd" (if (and on (member m '("Polygon" ""))) 0 1))
  ;;  Shrinkwrap gap override, its imperial and metric gaps until it is checked:
  (mode_tile "mgo" (if (and on (member m '("Shrinkwrap" ""))) 0 1))
  (foreach k '("mgp")
    (mode_tile k (if (and on (member m '("Shrinkwrap" "")) (= "1" (nth 44 r))) 0 1))
  )
  ;;  The width factor and the origin offsets, until their checkbox is checked (Pick... checks it):
  (mode_tile "mfc" (if (and on (not solid) (member m '("Linear" "Offset" "")) (= "1" (nth 37 r))) 0 1))
  (foreach k '("moa" "mof")
    (mode_tile k (if (and on (not solid) (member m '("Linear" "Offset" "")) (= "1" (nth 39 r)) (/= "Origin" (nth 58 r))) 0 1))
  )
  ;;  Ends and corners: for Linear and Offset; the value each choice uses only with it (or
  ;;  Ask when drawn). The hatch origin on the line only with the hatch following the line:
  (setq on (and on (member m '("Linear" "Offset" ""))))
  (mode_tile "mht" (if on 0 1))
  ;;  Their own ends and corners, the open button of each one until it is checked, and what
  ;;  they are beside it (the ends and corners themselves: in their own windows):
  (foreach x '(("meo" "mee" "mei" 61 "Ends") ("mcn" "mce" "mci" 62 "Corners"))
    (mode_tile (car x) (if on 0 1))
    (Dyl:MoreTile (cadr x) (and on (= "1" (nth (cadddr x) r))))
    (set_tile (caddr x) (Remote>>Dyl:MaterialBandText r (last x)))
  )
  (foreach k '("mor" "mop")
    (mode_tile k (if (and on (not solid) (/= "Origin" (nth 58 r))) 0 1))
  )
)

;;  SOLID ignores the scale, angle and annotative values. The drawing scale applies only to
;;  a hatch that is not annotative. A Model hatch is neither (its real size): both greyed
;;  out and turned off. The line under it gives the factor in the current drawing
;;  (the scales set for 1:1, here 1:50 -> x50):
;;  An optional setting has its value greyed out until its checkbox is checked:
(defun Remote>>Dyl:MaterialDlgState (r / solid model ano on tog)
  (setq solid (= "SOLID" (nth 3 r))
        model (= "Model" (nth 63 r))
  )
  (if model
    (foreach x '(("ano" . 9) ("sdw" . 10))
      (if (= "1" (nth (cdr x) r))
        (progn (Remote>>Dyl:PresetDlgPut (cdr x) "0") (set_tile (car x) "0") (setq r (Remote>>Dyl:ListSubst r (cdr x) "0")))
      )
    )
  )
  (setq ano (= "1" (nth 9 r))
        on  (and (not solid) (not ano) (= "1" (nth 10 r)))
  )
  (foreach k '("simp" "ang") (mode_tile k (if solid 1 0)))
  (mode_tile "typ" (if solid 1 0))
  (mode_tile "ano" (if (or solid model) 1 0))
  ;;  The units of the pattern, the factor of the scale in this drawing:
  (set_tile "sunt" (if solid "" (Remote>>Dyl:MaterialUnitText r)))
  ;;  Its open button: the .pat file of the pattern, greyed out when no file defines it:
  (Remote>>Dyl:MaterialDlgMode "suo" (if (and (not solid) (cdr (Remote>>Dyl:MaterialPatUnits (nth 3 r)))) 0 1))
  (mode_tile "sdw" (if (or solid ano model) 1 0))
  (foreach x *mt:optional*
    (setq tog (= "1" (nth (cdr (assoc (car x) *mt:tiles*)) r)))
    ;;  A SOLID hatch has no background, no existing phase background, no lineweight:
    (if (and solid (member (car x) *mt:solidoff*))
      (foreach k x (Remote>>Dyl:MaterialDlgMode k 1))
      (progn
        (mode_tile (car x) 0)
        (foreach k (cdr x) (Remote>>Dyl:MaterialDlgMode k (if tog 0 1)))
      )
    )
  )
  (Remote>>Dyl:MaterialDlgMode "hkp" 0)
  (set_tile "sinf"
            (if on
              (strcat "This drawing is at 1:"
                      (Remote>>Dyl:MaterialNum (Remote>>Dyl:MaterialDrawScale))
                      ": hatch scale x"
                      (Remote>>Dyl:MaterialNum (Remote>>Dyl:MaterialFactor (nth 11 r)))
                      "."
              )
              ""
            )
  )
)

;;-------------------------=={ Legend }==------------------------;;

;;  Code the Draw legend... button of the Hatch Presets window closes it with (see
;;  Remote>>Dyl:MaterialDlgStatus):
(setq *mt:legendcode* 7)

;;  Sizes of the legend at 1:1, in paper units (millimetres in a metric drawing, MEASUREMENT 1,
;;  else inches): (box-width box-height gap-between-rows gap-box-text text-height). They are
;;  multiplied by the drawing scale (see Remote>>Dyl:MaterialDrawScale: x50 at 1:50), so the
;;  legend plots at the same size at every drawing scale:
(setq *mt:legendsizes* '((20.0 10.0 5.0 4.0 2.5) (0.75 0.375 0.1875 0.15 0.09375)))

;;  Draw the legend of the materials mats from a point picked (the top left corner of the first
;;  box): one box under the other, each one hatched with its material (as Quick Draw does, see
;;  Remote>>Dyl:MaterialHatch), its name beside it. The boxes and the texts are on the current
;;  layer, in the current text style, along the X axis of the UCS; the hatches on the layer of
;;  their hatch layer key, behind their box (their border, mt:legend: kept as drawn). Returns
;;  the number of boxes drawn (nil: no point picked):
(defun Remote>>Dyl:MaterialLegend (mats / mt:legend mt:keepouts mt:scale mt:origin doc p sz s bw bh gap tg th
                                   ang lay cmd x y z n e u)
  (setq p (vl-catch-all-apply 'getpoint '("\nTop left corner of the legend <cancel>: ")))
  (if (and mats p (listp p))
    (progn
      (setq sz        (mapcar '(lambda (v) (* v (Remote>>Dyl:MaterialDrawScale)))
                              (if (= 1 (getvar "MEASUREMENT")) (car *mt:legendsizes*) (cadr *mt:legendsizes*))
                      )
            bw        (nth 0 sz)
            bh        (nth 1 sz)
            gap       (nth 2 sz)
            tg        (nth 3 sz)
            th        (nth 4 sz)
            x         (car p)
            y         (cadr p)
            z         (caddr p)
            lay       (getvar "CLAYER")
            ;;  The X axis of the UCS in the WCS, the angle of the texts:
            ang       (angle (trans '(0.0 0.0 0.0) 1 0) (trans '(1.0 0.0 0.0) 1 0))
            mt:legend T
            n         0
            doc       (vla-get-ActiveDocument (vlax-get-acad-object))
            cmd       (getvar "CMDECHO")
      )
      (vla-StartUndoMark doc)
      (setvar "CMDECHO" 0)
      (foreach m mats
        ;;  The box (UCS points: the command draws it in the UCS, no object snap):
        (command "_.pline" "_non" (list x y z) "_non" (list (+ x bw) y z) "_non" (list (+ x bw) (- y bh) z)
                 "_non" (list x (- y bh) z) "_c"
        )
        (setq e (entlast))
        ;;  Hatched with the material, always behind its box (Has a border):
        (Remote>>Dyl:MaterialHatch (Remote>>Dyl:ListSubst m 31 "0") (list e))
        ;;  The name, middle left, beside the box:
        (setq u (trans (list (+ x bw tg) (- y (/ bh 2.0)) z) 1 0))
        (entmakex (list '(0 . "TEXT")
                        (cons 8 lay)
                        (cons 7 (getvar "TEXTSTYLE"))
                        (cons 10 u)
                        (cons 11 u)
                        (cons 40 th)
                        (cons 50 ang)
                        (cons 1 (nth 2 m))
                        '(72 . 0)
                        '(73 . 2)
                  )
        )
        (setq y (- y bh gap)
              n (1+ n)
        )
      )
      (setvar "CMDECHO" cmd)
      (vla-EndUndoMark doc)
      (princ (strcat "\nLegend: " (itoa n) " hatch preset(s) drawn."))
      n
    )
  )
)

;;  The materials selected in the Hatch Presets window, in the order of its list (pst:view,
;;  pst:lst: locals of Remote>>Dyl:PresetDialog), the materials being edited:
(defun Remote>>Dyl:MaterialDlgSelected (/ sel)
  (setq sel (Remote>>Dyl:PresetDlgSel))
  (mapcar '(lambda (i) (nth i pst:lst))
          (append (vl-remove-if-not '(lambda (i) (member i sel)) pst:view)
                  (vl-remove-if '(lambda (i) (member i pst:view)) sel)
          )
  )
)

;;-------------------------=={ Pick hatch }==------------------------;;

;;  Code the Pick hatch... button of the Hatch Presets window closes it with (see
;;  Remote>>Dyl:MaterialDlgStatus; 8 and 9 are the codes of the preset engine):
(setq *mt:hatchpickcode* 10)

;;  The color of the hatch o as a color of a material ("n" or "r,g,b"), nil when it is
;;  ByLayer, ByBlock or none. bg T: its background color:
(defun Remote>>Dyl:MaterialColorOf (o bg / c m)
  (setq c (vl-catch-all-apply (if bg 'vla-get-BackgroundColor 'vla-get-TrueColor) (list o)))
  (if (not (vl-catch-all-error-p c))
    (cond
      ((= acColorMethodByRGB (setq m (vla-get-ColorMethod c)))
       (strcat (itoa (vla-get-Red c)) "," (itoa (vla-get-Green c)) "," (itoa (vla-get-Blue c)))
      )
      ((and (= acColorMethodByACI m) (<= 1 (vla-get-ColorIndex c) 255)) (itoa (vla-get-ColorIndex c)))
    )
  )
)

;;  The material r with the hatch settings of the hatch e: its pattern, scale (in the units of
;;  the pattern, at 1:1 when the material follows the drawing scale: the inverse of
;;  Remote>>Dyl:MaterialScale), angle, annotative and associative, the layer key whose layer
;;  is its layer (in any phase; kept when there is none, with a message), the layer key
;;  overrides and the background color it has (off when it has none). The other values of r
;;  (name, group, adaptive scaling, existing phase background) are kept. Returns
;;  ((index . value) ...), the values to give to the materials selected, nil (with a
;;  message) when e cannot be a material (a gradient, a user-defined pattern):
(defun Remote>>Dyl:MaterialFromHatch (e r / o ed pat res put s v lay rec lw tr)
  (setq o   (vlax-ename->vla-object e)
        ed  (entget e)
        pat (strcase (vla-get-PatternName o))
  )
  (defun put (i val) (setq res (cons (cons i val) res) r (Remote>>Dyl:ListSubst r i val)))
  (cond
    ((= 1 (vla-get-HatchObjectType o)) (princ "\nA gradient is not a hatch pattern: nothing copied.") nil)
    ((or (= acHatchPatternTypeUserDefined (vla-get-PatternType o)) (= "_USER" pat))
     (princ "\nA user-defined hatch has no pattern of a .pat file: nothing copied.")
     nil
    )
    (T
     (put 3 pat)
     (put 9 (if (Remote>>Dyl:MaterialAnno-p e) "1" "0"))
     ;;  An annotative hatch is a size on paper:
     (if (Remote>>Dyl:MaterialAnno-p e) (put 63 "Drafting"))
     (put 30 (if (= :vlax-true (vla-get-AssociativeHatch o)) "1" "0"))
     (if (/= "SOLID" pat)
       (progn
         ;;  The scale back in the units of the pattern, at 1:1 (r has its pattern and annotative):
         (setq s (/ (vla-get-PatternScale o) (Remote>>Dyl:MaterialUnitFactor r)))
         (if (Remote>>Dyl:MaterialScaled-p r) (setq s (/ s (Remote>>Dyl:MaterialFactor (nth 11 r)))))
         (put 4 (Remote>>Dyl:MaterialNumP s 6))
         (put 6 (Remote>>Dyl:MaterialNumP (* 180.0 (/ (vla-get-PatternAngle o) pi)) 4))
       )
     )
     ;;  The layer key of its layer (its name without phase), never a key kept for compatibility:
     (setq lay (cdr (assoc 8 ed)))
     (if (and (setq rec (Remote>>Dyl:LayerKeyOfLayer (Remote>>Dyl:PhaseBase lay (Remote>>Dyl:PhaseList))))
              (Remote>>Dyl:LayerKeyMaterial-p (car rec))
         )
       (put 8 (car rec))
       (princ (strcat "\nLayer " lay " is not the layer of a layer key: the hatch layer key " (nth 8 r) " is kept."))
     )
     ;;  The layer key overrides, on when the hatch has one:
     (if (setq v (Remote>>Dyl:MaterialColorOf o nil)) (progn (put 22 "1") (put 23 v)) (put 22 "0"))
     (if (and (setq v (cdr (assoc 6 ed))) (not (member (strcase v) '("BYLAYER" "BYBLOCK"))))
       (progn (put 47 "1") (put 48 (strcase v)))
       (put 47 "0")
     )
     (if (and (setq v (cdr (assoc 48 ed))) (not (equal 1.0 v 1e-9)))
       (progn (put 49 "1") (put 50 (Remote>>Dyl:MaterialNumP v 6)))
       (put 49 "0")
     )
     (if (and (setq lw (cdr (assoc 370 ed))) (member (itoa lw) *mt:weights*))
       (progn (put 26 "1") (put 27 (itoa lw)))
       (put 26 "0")
     )
     (setq tr (vl-catch-all-apply 'vla-get-EntityTransparency (list o)))
     (if (and (= 'STR (type tr)) (wcmatch tr "#,##"))
       (progn (put 28 "1") (put 29 tr))
       (put 28 "0")
     )
     ;;  Its background color (a SOLID hatch has none, see *mt:solidoff*):
     (if (and (/= "SOLID" pat) (setq v (Remote>>Dyl:MaterialColorOf o T)))
       (progn (put 24 "1") (put 25 v))
       (put 24 "0")
     )
     (reverse res)
    )
  )
)

;;  The Apps file of Dyl-RebuildPat (its PATH in StartupSuite.csv), whose rpat:rebuild-hatch
;;  rebuilds the pattern of a hatch picked that no .pat file has:
(setq *mt:rebuildpat* "Dynalisp\\Apps\\Utilities\\Dyl-RebuildPat.lsp")

;;  Pick hatch...: the pattern pat of the hatch e is in no .pat file of the support path, so a
;;  hatch preset could not draw it. Asked whether to rebuild it from the hatch (see
;;  Dyl-RebuildPat); when Dyl-RebuildPat is turned off in the Startup Suite, asked to turn it
;;  on (and it is loaded: an App turned on is only autoloaded, see Dyl:SuiteFileLoad). The
;;  pattern rebuilt is read again (its units, its preview). Returns T when it was rebuilt:
(defun Remote>>Dyl:MaterialPatRebuild (e pat / key)
  (cond
    ((not (Dyl:Ask (list (strcat "Pattern " pat " is missing: no .pat file of the support path has it.")
                         (strcat "Rebuild " pat ".pat from the lines stored in this hatch?")
                         "Unexpected results may happen: check the hatches it draws."
                   )
                   "Yes"
                   "No"
          )
     )
     (princ (strcat "\nPattern " pat " not rebuilt: a hatch preset cannot draw it until a .pat file has it (see RPAT)."))
     nil
    )
    ((not (or (Dyl:SuiteFileOn-p *mt:rebuildpat*)
              (and (Dyl:SuiteAsk (list "Rebuild Patterns (Dyl-RebuildPat) is turned off in the Startup Suite."
                                       (strcat "Turn it on and load it, then rebuild " pat ".pat?")
                                 )
                                 "Yes"
                                 "No"
                   )
                   (Dyl:SuiteFileOn *mt:rebuildpat*)
              )
          )
     )
     (princ (strcat "\nPattern " pat " not rebuilt: Dyl-RebuildPat is turned off in the Startup Suite (Dyl-Suite)."))
     nil
    )
    ((not (or rpat:rebuild-hatch (and (Dyl:SuiteFileLoad *mt:rebuildpat*) rpat:rebuild-hatch)))
     (princ (strcat "\nPattern " pat " not rebuilt: " *mt:rebuildpat* " could not be loaded."))
     nil
    )
    ((rpat:rebuild-hatch e)
     ;;  Its units read again from the new file (they were kept as not found):
     (setq key           (strcase pat)
           *mt:patunits* (vl-remove-if '(lambda (x) (= (strcat key "|") (substr (car x) 1 (1+ (strlen key))))) *mt:patunits*)
     )
     (if (not (member key mt:found)) (setq mt:found (cons key mt:found)))
     T
    )
  )
)

;;  Pick hatch...: a hatch picked in the drawing gives its hatch settings to the hatch presets
;;  selected (see Remote>>Dyl:MaterialFromHatch, Remote>>Dyl:PresetDlgPut). A pattern that no
;;  .pat file has can be rebuilt first (see Remote>>Dyl:MaterialPatRebuild), so its scale is
;;  read in the units of the file rebuilt. Its pattern is added to the Pattern popup when the
;;  list does not have it:
(defun Remote>>Dyl:MaterialPickHatch (r / e o pat vals)
  (while (and (not e) (progn (setvar "ERRNO" 0) (or (setq e (entsel "\nSelect a hatch to copy <cancel>: ")) (= 7 (getvar "ERRNO")))))
    (cond
      ((not e) (princ "\nNothing selected."))
      ((/= "HATCH" (cdr (assoc 0 (entget (car e))))) (princ "\nThat is not a hatch.") (setq e nil))
    )
  )
  (if e
    (progn
      (setq o   (vlax-ename->vla-object (car e))
            pat (strcase (vla-get-PatternName o))
      )
      (if (and (/= 1 (vla-get-HatchObjectType o))
               (/= acHatchPatternTypeUserDefined (vla-get-PatternType o))
               (not (member pat '("SOLID" "_USER" "")))
               (not (cdr (Remote>>Dyl:MaterialPatUnits pat)))
          )
        (Remote>>Dyl:MaterialPatRebuild (car e) pat)
      )
    )
  )
  (if (and e (setq vals (Remote>>Dyl:MaterialFromHatch (car e) r)))
    (progn
      (foreach x vals (Remote>>Dyl:PresetDlgPut (car x) (cdr x)))
      (if (not (member (cdr (assoc 3 vals)) mt:pats)) (setq mt:pats (acad_strlsort (cons (cdr (assoc 3 vals)) mt:pats))))
      (princ (strcat "\nHatch copied: " (Remote>>Dyl:MaterialSummary (nth pst:idx pst:lst)) "."))
    )
  )
)

;;  Code *mt:hatchpickcode* = Pick hatch...: a hatch picked in the drawing gives its settings to
;;  the hatch presets selected, then the dialog is shown again.
;;  Code *mt:legendcode* = Draw legend...: the legend of the hatch presets selected (as they are
;;  being edited) is drawn from a point picked, then the dialog is shown again.
;;  Code 5 = the open button of the hatch layer key: the Layer Keys dialog is shown on that key
;;  (not nested in the materials dialog), then the materials dialog is shown again with the
;;  materials being edited. A key double-clicked in it becomes the hatch layer key of every
;;  material selected (see Remote>>Dyl:PresetDlgPut):
(defun Remote>>Dyl:MaterialDlgStatus (sta r / k)
  (if (and (= 5 sta) (setq k (Remote>>Dyl:LayerKeyPick (nth 8 r)))) (Remote>>Dyl:PresetDlgPut 8 k))
  (if (= *mt:legendcode* sta) (Remote>>Dyl:MaterialLegend (Remote>>Dyl:MaterialDlgSelected)))
  (if (= *mt:hatchpickcode* sta) (Remote>>Dyl:MaterialPickHatch r))
  nil
)

;;  Show the materials dialog, on the material id (nil: the last one). OK writes the
;;  materials file. Returns the material selected on OK, or nil on Cancel:
(defun Remote>>Dyl:MaterialDialog (id / mt:pats mt:found mt:keys)
  (Remote>>Dyl:PresetDialog
    "Material"
    (list (cons 'defs (Remote>>Dyl:MaterialDefs))
          (cons 'fix 'Remote>>Dyl:MaterialFix)
          (cons 'tiles *mt:tiles*)
          (cons 'select id)
          '(groups . T)
          '(upper "pat" "hat" "hlt")
          ;;  The hatch settings, in two columns: the basic settings and the layer key overrides
          ;;  on the left, the optional settings on the right (the border and the behaviors,
          ;;  how a preset is drawn, are in the Quick Draw and Quick Shape windows). Each value is a row of its own, its box (the open button of a
          ;;  color just before it) at the right of the row: a box with an edit_width is
          ;;  right-justified in the space of its tile, and the label (or checkbox) takes the
          ;;  rest, so every box of a column ends at the same distance from its right border
          ;;  (see CONVENTIONS.md, Windows):
          (cons 'params '(
            "      : column {"
            "        : boxed_column { label = \"Hatch settings\";"
            "          : row {"
            ;;  Each sub-section a column of fixed height, its rows close together; a spacer between
            ;;  them takes the extra height of the column (as tall as its neighbour), spread evenly:
            "            : column {"
            "              : column { fixed_height = true;"
            "              : row { : popup_list { key = \"pat\"; label = \"Pattern:\"; edit_width = 28; } }"
            ;;  Drafting (a size on paper) or Model (a real size, see Remote>>Dyl:MaterialFix):
            "              : row { : popup_list { key = \"typ\"; label = \"Type:\"; edit_width = 12; } }"
            ;;  One scale, in the units of the pattern; the line under it: those units and the
            ;;  factor in this drawing (see Remote>>Dyl:MaterialUnitText), its open button the
            ;;  .pat file of the pattern (see Remote>>Dyl:MaterialPatOpen):
            "              : row { : edit_box { key = \"simp\"; label = \"Scale:\"; edit_width = 12; } }"
            "              : row { : text { key = \"sunt\"; width = 40; }"
            "                      : image_button { key = \"suo\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; } }"
            "              : row { : edit_box { key = \"ang\"; label = \"Angle:\"; edit_width = 12; } }"
            ;;  The layer keys, their open button the Layer Keys window (see Remote>>Dyl:MaterialDlgStatus):
            "              : row { : text { key = \"hatl\"; label = \"Layer key:\"; }"
            "                      : image_button { key = \"hkp\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
            "                      : popup_list { key = \"hat\"; edit_width = 28; fixed_width = true; } }"
            "              }"
            "              : spacer { }"
            "              : column { fixed_height = true;"
            ;;  A dividing line and the title of the settings that override the properties of the layer key:
            "              : image { key = \"hsep\"; height = 0.8; fixed_height = true; color = -15; }"
            "              : row { : text { label = \"Layer key overrides:\"; } }"
            "              : row { : toggle { key = \"hco\"; label = \"Color:\"; width = 28; }"
            "                      : image_button { key = \"hcp\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
            "                      : edit_box { key = \"hcl\"; edit_width = 12; fixed_width = true; } }"
            "              : row { : toggle { key = \"hlo\"; label = \"Linetype:\"; width = 28; }"
            "                      : edit_box { key = \"hlt\"; edit_width = 12; fixed_width = true; } }"
            "              : row { : toggle { key = \"hso\"; label = \"Linetype scale:\"; width = 28; }"
            "                      : edit_box { key = \"hsc\"; edit_width = 12; fixed_width = true; } }"
            "              : row { : toggle { key = \"hwo\"; label = \"Lineweight:\"; width = 28; }"
            "                      : popup_list { key = \"hwt\"; edit_width = 12; fixed_width = true; } }"
            "              }"
            "            }"
            ;;  The settings that are not a property of the layer key, at the top of their column
            ;;  (their title only: the border of the group is just above it):
            "            : column {"
            "              : column { fixed_height = true;"
            "              : row { : text { label = \"Optional settings:\"; } }"
            "              : row { : toggle { key = \"hbo\"; label = \"Background color:\"; width = 28; }"
            "                      : image_button { key = \"hbp\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
            "                      : edit_box { key = \"hbg\"; edit_width = 12; fixed_width = true; } }"
            ;;  In place of the background color while auto-phase is on in the existing phase (E):
            "              : row { : toggle { key = \"hxo\"; label = \"Existing phase background:\"; width = 28; }"
            "                      : image_button { key = \"hxp\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
            "                      : edit_box { key = \"hxb\"; edit_width = 12; fixed_width = true; } }"
            "              : row { : toggle { key = \"hto\"; label = \"Transparency (0-90):\"; width = 28; }"
            "                      : edit_box { key = \"htr\"; edit_width = 12; fixed_width = true; } }"
            ;;  How the hatch is scaled and made (see Remote>>Dyl:MaterialScale, Remote>>Dyl:MaterialHatchAt):
            "              : row { : toggle { key = \"ano\"; label = \"Annotative\"; } }"
            "              : row { : toggle { key = \"sdw\"; label = \"Adaptive scaling (see Docs)\"; } }"
            "              : row { : text { key = \"sinf\"; width = 44; } }"
            "              : row { : toggle { key = \"asc\"; label = \"Associative\"; } }"
            "              }"
            "              : spacer { }"
            "            }"
            "          }"
            "        }"
            ;;  The legend of the hatch presets selected, drawn in the drawing (see
            ;;  Remote>>Dyl:MaterialLegend):
            ;;  Pick hatch...: the hatch settings of a hatch of the drawing (see
            ;;  Remote>>Dyl:MaterialFromHatch):
            "        : row { fixed_width = true; alignment = right;"
            "          : button { key = \"hpk\"; label = \"Pick hatch...\"; }"
            "          : button { key = \"leg\"; label = \"Draw legend...\"; }"
            "        }"
            "      }"
           ))
          ;;  A new material: the optional settings off, associative:
          (cons 'new *mt:new*)
          '(items . Remote>>Dyl:MaterialDlgItems)
          '(check . Remote>>Dyl:MaterialDlgCheck)
          '(init . Remote>>Dyl:MaterialDlgInit)
          '(state . Remote>>Dyl:MaterialDlgState)
          '(status . Remote>>Dyl:MaterialDlgStatus)
          ;;  A narrow list, group and name only (the status of the hatch preset shown is in the
          ;;  Parameters heading), as tall as the group of parameters beside it:
          ;;  OK asks first when more than 5 materials were changed:
          '(warn . 5)
          '(noun . "hatch presets")
          '(height . 17)
    )
  )
)

(princ)
