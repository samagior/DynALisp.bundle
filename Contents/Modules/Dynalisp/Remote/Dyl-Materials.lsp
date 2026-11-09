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
;;  pattern, scales, angle, annotative, outline and hatch layer keys. The materials are
;;  presets of the preset engine (Remote\Dyl-Presets.lsp) without commands, saved to
;;  Res\Materials.csv, and are used by the presets of the drawing tools by their id
;;  (e.g. the Quick Draw presets QD-BRICK and PL-BRICK both use the material mt-Brick).
;;
;;  A material is a list of strings:
;;  (id group name pattern scale-imperial scale-metric angle outline-key hatch-key annotative
;;   scale-drawing scale-ref)
;;  id is the id of a default material (e.g. "mt-Brick") or a custom id (cu-...).
;;  scale-drawing "1": a hatch that is not annotative follows the drawing scale (the
;;  annotation scale CANNOSCALE, set by Dyl-SwitchDrawingScale). scale-ref is the drawing
;;  scale its scales were set for ("10": 1:10): its scale is multiplied by the drawing scale
;;  divided by scale-ref, set for 1:10 and drawn at 1:50 -> x5 (see Remote>>Dyl:MaterialScale).
;;  Then the optional settings of the border and of the hatch, each one an on/off ("1": used,
;;  else the layer or AutoCAD default is kept) and its value, and the behaviors (see
;;  *mt:extra*, index 12 to 36):
;;   border: color, linetype, linetype scale, lineweight, transparency
;;   hatch:  color, background color, lineweight, transparency
;;   associative ("1" by default), no border (outline erased), behind border (draw order)
;;   behaviors, how Quick Draw draws the material: method (a key of *mt:methods*, "": ask
;;   when drawn), width ("": the last width used) and justify (key of *mt:justify*) of the
;;   Linear method, sides of the Polygon method ("": asked by POLYGON); then for Linear: the
;;   hatch scale from the width ("1": scale = width x factor, in place of the scales of the
;;   material) and the hatch origin on the line ("1": at the start of each segment, moved by
;;   offset across the line, positive into the band; see Dyl:QuickDrawLinear); then the
;;   existing phase background of the hatch (on/off, color): used in place of the background
;;   color while auto-phase is on and the active phase is E (see Remote>>Dyl:MaterialExisting-p)
;;  A color is an AutoCAD color number (1-255) or a true color "r,g,b", a lineweight in
;;  hundredths of mm ("25": 0.25 mm), a transparency 0 to 90.
;;
;;  For a tool (see Apps\Draw\Dyl-QuickDraw.lsp):
;;    (Remote>>Dyl:MaterialGet id)              -> material, nil when it no longer exists
;;    (Remote>>Dyl:MaterialDialog id)           -> Materials dialog opened on id, returns the
;;                                                 material selected on OK (nil on Cancel)
;;    (Remote>>Dyl:MaterialPopup tile mats ids) -> fill a material popup of a dialog
;;    (Remote>>Dyl:MaterialSummary mat)         -> one line describing a material


(setq *dyl:presetspecs*
  (cons
    '("Material"
      (file . "Materials.csv")
      (header "Id" "Group" "Name" "Pattern" "ScaleImperial" "ScaleMetric" "Angle" "OutlineKey" "HatchKey"
              "Annotative" "ScaleDrawing" "ScaleRef"
              ;;  Optional settings: each one an On column ("1": used) and its value (see *mt:extra*):
              "BorderColorOn" "BorderColor" "BorderLinetypeOn" "BorderLinetype" "BorderLtScaleOn" "BorderLtScale"
              "BorderLineweightOn" "BorderLineweight" "BorderTransparencyOn" "BorderTransparency"
              "HatchColorOn" "HatchColor" "BackgroundOn" "Background" "HatchLineweightOn" "HatchLineweight"
              "HatchTransparencyOn" "HatchTransparency"
              ;;  Hatch and border: associative, no border, behind border:
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
      )
      (default . "MT-*")
      (title . "Materials")
      ;;  Page of the Documentation button (Docs folder of the Dynalisp module):
      (doc . "Draw\\Dyl-Materials.htm")
     )
    (vl-remove (assoc "Material" *dyl:presetspecs*) *dyl:presetspecs*)
  )
)

;;  Default materials, restored by the Reset Selected and Reset All buttons:
(setq *mt:defaults*
  '(("mt-Demolition" "Phase" "Demolition" "ANSI31" "0.5" "0.5" "90.0" "THIN" "HATCH" "1")
    ("mt-NotInContract" "Phase" "Not In Contract" "ANSI31" "1.5" "1.5" "90.0" "XLINE" "HATCH" "1")
    ("mt-Existing" "Phase" "Existing" "SOLID" "1.0" "1.0" "0" "XLINE" "G-DS-ANNO-STD-BACKGROUND_SCREEN" "0")
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

;;  Groups of the materials (Group popup of the materials dialog), by the kind of drawing they
;;  are used in, the plans by their type. A group typed in the materials file that is not
;;  listed here is kept:
(setq *mt:groups* '("Floor" "Ceiling" "Roof" "Finish" "Structural" "Site"
                    "Elevation" "Section" "Detail" "Annotation" "Phase" "Area" "Generic"
                   )
)

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

;;  T when the text str is a number greater than 0 (a scale):
(defun Remote>>Dyl:MaterialScale-p (str / v)
  (and (= 'STR (type str)) (setq v (distof str 2)) (< 0 v))
)

;;  Default values of the columns 12 to 36 (optional settings off, their value shown greyed
;;  out until they are turned on; associative on, as before these settings; the method
;;  asked when drawn):
(setq *mt:extra* '("0" "7" "0" "CONTINUOUS" "0" "1" "0" "25" "0" "50"
                   "0" "7" "0" "254" "0" "13" "0" "50"
                   "1" "0" "0"
                   "" "" "Center" ""
                   "0" "1" "0" "0"
                   "0" "253"
                   "" "0" ""
                  )
)

;;  Ways Quick Draw makes the outline of a material (Method column, "": ask when drawn):
;;  (method label keyword). Quick Draw uses this list (*qd:modes*):
(setq *mt:methods* '(("Polyline" "Polyline" "Polyline")
                     ("Rectangle" "Rectangle" "Rectangle")
                     ("Circle" "Circle" "Circle")
                     ("Polygon" "Polygon" "pOlygon")
                     ("Ellipse" "Ellipse" "Ellipse")
                     ("Shrinkwrap" "Shrinkwrap (select objects)" "sHrinkwrap")
                     ("Pick" "Pick internal points" "pIck")
                     ("Select" "Select closed objects" "Select")
                     ("Linear" "Linear (band along a line)" "Linear")
                    )
)

;;  Linear: where the line drawn is in its band (Justify column): (justify label). "Ask":
;;  asked each time the band is drawn (see Dyl:QuickDrawLinear):
(setq *mt:justify* '(("Ask" "Ask when drawn")
                     ("Center" "Center (on the line)")
                     ("Left" "Left border")
                     ("Right" "Right border")
                    )
)

;;  Indexes of the on/off columns (annotative, scale-drawing, the On of each optional
;;  setting, the behaviors):
(setq *mt:toggles* '(9 10 12 14 16 18 20 22 24 26 28 30 31 32 37 39 41 44))

;;  Values of a row of the materials file: group as in *mt:groups* (any case), pattern,
;;  layer keys and linetype in upper case, the on/off columns "1" or "0", scale-ref a number
;;  greater than 0 ("1" when it is not), an empty optional value its default. A row of an
;;  older file (without the last columns, or with a scale source in place of scale-ref)
;;  gets them:
(defun Remote>>Dyl:MaterialFix (row / g v)
  (while (< (length row) 12) (setq row (append row (list ""))))
  (while (< (length row) 46) (setq row (append row (list (nth (- (length row) 12) *mt:extra*)))))
  ;;  Shrinkwrap gap tolerances (imperial, metric): a number >= 0, "" when it is not (asked
  ;;  when drawn while the gap override is on):
  (foreach i '(43 45)
    (if (not (and (setq v (distof (nth i row) 2)) (<= 0 v))) (setq row (Remote>>Dyl:ListSubst row i "")))
  )
  ;;  Linear: a width factor > 0 ("1" when it is not), an origin offset ("0" when it is not a number):
  (if (not (Remote>>Dyl:MaterialScale-p (nth 38 row))) (setq row (Remote>>Dyl:ListSubst row 38 "1")))
  (if (not (distof (nth 40 row) 2)) (setq row (Remote>>Dyl:ListSubst row 40 "0")))
  ;;  Behaviors: a method of *mt:methods* or "", a width > 0 or "", a justify of
  ;;  *mt:justify*, sides 3 to 1024 or "":
  (setq row (Remote>>Dyl:ListSubst row 33 (cond ((car (vl-some '(lambda (x) (if (= (strcase (nth 33 row)) (strcase (car x))) x)) *mt:methods*))) (""))))
  (if (not (Remote>>Dyl:MaterialWidths (nth 34 row))) (setq row (Remote>>Dyl:ListSubst row 34 "")))
  (setq row (Remote>>Dyl:ListSubst row 35 (cond ((car (vl-some '(lambda (x) (if (= (strcase (nth 35 row)) (strcase (car x))) x)) *mt:justify*))) ("Center"))))
  (if (not (and (wcmatch (nth 36 row) "#,##,###,####") (<= 3 (atoi (nth 36 row)) 1024))) (setq row (Remote>>Dyl:ListSubst row 36 "")))
  (if (setq g (vl-some '(lambda (x) (if (= (strcase x) (strcase (nth 1 row))) x)) *mt:groups*))
    (setq row (Remote>>Dyl:ListSubst row 1 g))
  )
  (foreach i '(3 7 8 15) (setq row (Remote>>Dyl:ListSubst row i (strcase (nth i row)))))
  (foreach i *mt:toggles* (setq row (Remote>>Dyl:ListSubst row i (if (= "1" (nth i row)) "1" "0"))))
  (if (not (Remote>>Dyl:MaterialScale-p (nth 11 row))) (setq row (Remote>>Dyl:ListSubst row 11 "1")))
  (foreach i '(13 15 17 19 21 23 25 27 29 42)
    (if (= "" (nth i row)) (setq row (Remote>>Dyl:ListSubst row i (nth (- i 12) *mt:extra*))))
  )
  row
)

;;  The default materials get the last columns too (not scaled with the drawing, set for
;;  1:1, the optional settings off). Not with Remote>>Dyl:MaterialFix: Dyl-Sub.lsp
;;  (Remote>>Dyl:ListSubst) loads after this file:
(setq *mt:defaults* (mapcar '(lambda (r) (if (< (length r) 12) (append r (list "0" "1") *mt:extra*) r)) *mt:defaults*))

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
               ;;  A SOLID hatch has no lineweight (see *mt:solidoff*):
               (if (= "SOLID" (nth 3 mat)) '((22 color) (28 transp)) '((22 color) (26 lweight) (28 transp)))
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
(defun Remote>>Dyl:MaterialNum (v / s)
  (setq s (rtos v 2 4))
  (if (vl-string-search "." s) (vl-string-right-trim "." (vl-string-right-trim "0" s)) s)
)

;;  Factor of the hatch scale of a material set for the drawing scale 1:ref (ref: text) in
;;  the current drawing: the drawing scale divided by ref, set for 1:10 and drawn at
;;  1:50 -> 5.0:
(defun Remote>>Dyl:MaterialFactor (ref)
  (/ (Remote>>Dyl:MaterialDrawScale) (if (Remote>>Dyl:MaterialScale-p ref) (distof ref 2) 1.0))
)

;;  T when the hatch of the material mat follows the drawing scale (not annotative, not SOLID):
(defun Remote>>Dyl:MaterialScaled-p (mat)
  (and (= "1" (nth 10 mat)) (/= "1" (nth 9 mat)) (/= "SOLID" (nth 3 mat)))
)

;;  Hatch scale of the material mat in the current drawing: its imperial or metric scale
;;  (MEASUREMENT), multiplied by the drawing scale divided by the scale it was set for when
;;  it follows the drawing scale (see Remote>>Dyl:MaterialFactor):
(defun Remote>>Dyl:MaterialScale (mat / s)
  (setq s (distof (if (= 1 (getvar "MEASUREMENT")) (nth 5 mat) (nth 4 mat)) 2))
  (if (not s) (setq s 1.0))
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
;;  island), using the pattern, scale (imperial or metric from MEASUREMENT, multiplied by the
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

;;  Move the pattern origin of the hatch e to the point p (WCS), the pattern made again:
(defun Remote>>Dyl:MaterialOrigin (e p / o)
  (setq o (vlax-ename->vla-object e))
  (vl-catch-all-apply
    '(lambda ()
       (vla-put-Origin o (vlax-make-variant (vlax-safearray-fill (vlax-make-safearray vlax-vbDouble '(0 . 1)) (list (car p) (cadr p)))))
       (vla-Evaluate o)
     )
  )
)

;;  The optional settings of the material (see Remote>>Dyl:MaterialProps) are given to the
;;  outlines and to the hatch: its draw order (behind its border) set while it is made
;;  (HPDRAWORDER, restored after), its background color once it is made (its BackgroundColor,
;;  see Remote>>Dyl:MaterialBackgroundPut). With No border, the
;;  hatch is not associative and the outlines are erased once it is made, but those the user
;;  selected (mt:keepouts T, set by the caller, e.g. Quick Draw Select closed objects):
(defun Remote>>Dyl:MaterialHatchAt (mat outs ang / ss mark nob asc vars c)
  (setq ss  (ssadd)
        nob (= "1" (nth 31 mat))
        asc (and (= "1" (nth 30 mat)) (not nob))
  )
  (foreach e outs
    (Remote>>Dyl:LayerKeyApply e (nth 7 mat))
    (if (not nob) (Remote>>Dyl:MaterialProps e mat 'border))
    (if (Remote>>Dyl:MaterialClosed-p e) (ssadd e ss))
  )
  (if (< 0 (sslength ss))
    (progn
      ;;  Draw order of the new hatch (its background color is set once it is made, see below):
      ;;  A SOLID hatch has no background color (see *mt:solidoff*):
      (setq vars (list (cons "HPDRAWORDER" (getvar "HPDRAWORDER")))
            c    (if (/= "SOLID" (nth 3 mat)) (Remote>>Dyl:MaterialBackground mat))
      )
      (if (and (= "1" (nth 32 mat)) (not nob)) (vl-catch-all-apply 'setvar '("HPDRAWORDER" 3)))
      (setq mark (entlast))
      (if (/= "SOLID" (nth 3 mat))
        (command "-hatch"
                 "s"
                 ss
                 ""
                 "an"
                 (if (= "1" (nth 9 mat)) "y" "n")
                 "p"
                 (nth 3 mat)
                 ;;  mt:scale: a scale given by the caller (Quick Draw Linear: width x factor):
                 (if (numberp mt:scale) mt:scale (Remote>>Dyl:MaterialScale mat))
                 (rtos (+ (cond ((distof (nth 6 mat) 2)) (0.0)) ang) 2 6)
                 "a"
                 "a"
                 (if asc "y" "n")
                 ""
                 ""
        )
        (command "-hatch" "s" ss "" "an" "n" "p" (nth 3 mat) "a" "a" (if asc "y" "n") "" "")
      )
      (foreach v vars (if (cdr v) (vl-catch-all-apply 'setvar (list (car v) (cdr v)))))
      ;;  Put the hatch on the layer of the hatch layer key, with the hatch settings:
      (while (setq mark (entnext mark))
        (Remote>>Dyl:LayerKeyApply mark (nth 8 mat))
        (Remote>>Dyl:MaterialProps mark mat 'hatch)
        (if (= "HATCH" (cdr (assoc 0 (entget mark))))
          (progn
            ;;  mt:origin: an origin given by the caller (WCS point, Quick Draw Linear: on the line):
            (if (and mt:origin (/= "SOLID" (nth 3 mat))) (Remote>>Dyl:MaterialOrigin mark mt:origin))
            ;;  The background color (the existing phase background while it applies), given
            ;;  to the hatch made rather than with HPBACKGROUNDCOLOR before -HATCH, last (after
            ;;  the pattern is made again for its origin):
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

;;  One line describing the material mat:
(defun Remote>>Dyl:MaterialSummary (mat)
  (strcat (nth 3 mat)
          (if (= "SOLID" (nth 3 mat))
            ""
            (strcat ", scale "
                    (nth 4 mat)
                    " / "
                    (nth 5 mat)
                    ", angle "
                    (nth 6 mat)
                    (cond
                      ((= "1" (nth 9 mat)) ", annotative")
                      ((Remote>>Dyl:MaterialScaled-p mat) (strcat ", follows the drawing scale (set for 1:" (nth 11 mat) ")"))
                      ("")
                    )
            )
          )
          (if (= "1" (nth 31 mat)) " - no border" (strcat " - outline " (nth 7 mat)))
          ", hatch "
          (nth 8 mat)
          ;;  How it is drawn (behaviors):
          (if (assoc (nth 33 mat) *mt:methods*)
            (strcat " - "
                    (nth 33 mat)
                    (if (and (= "Linear" (nth 33 mat)) (/= "" (nth 34 mat)))
                      (strcat " " (nth 34 mat) (if (vl-string-search "," (nth 34 mat)) " wide (asked)" " wide"))
                      ""
                    )
            )
            ""
          )
  )
)

;;  Fill the material popup tile of a dialog with the materials mats (see Remote>>Dyl:MaterialRead),
;;  then the ids of ids that are not a material (deleted: they stay selectable, marked missing).
;;  Returns the ids of the popup, in its order:
(defun Remote>>Dyl:MaterialPopup (tile mats ids / lst m)
  (setq lst (mapcar 'car mats))
  (foreach id ids
    (if (and (/= "" id) (not (member id lst))) (setq lst (append lst (list id))))
  )
  (start_list tile)
  (foreach id lst
    (add_list (if (setq m (assoc id mats))
                (strcat (nth 1 m) " - " (nth 2 m))
                (strcat id "   (missing material)")
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
(setq *mt:tiles* '(("pat" . 3) ("simp" . 4) ("smet" . 5) ("ang" . 6) ("out" . 7) ("hat" . 8) ("ano" . 9)
                   ("sdw" . 10) ("sref" . 11)
                   ;;  Border settings (checkbox, value):
                   ("bco" . 12) ("bcv" . 13) ("blo" . 14) ("blt" . 15) ("bso" . 16) ("bsc" . 17)
                   ("bwo" . 18) ("bwt" . 19) ("bto" . 20) ("btr" . 21)
                   ;;  Hatch settings (checkbox, value):
                   ("hco" . 22) ("hcl" . 23) ("hbo" . 24) ("hbg" . 25) ("hwo" . 26) ("hwt" . 27)
                   ("hto" . 28) ("htr" . 29)
                   ;;  Associative, behind border (hatch), no border (border):
                   ("asc" . 30) ("nob" . 31) ("bhd" . 32)
                   ;;  Behaviors: method, Linear width and justify, Polygon sides:
                   ("mth" . 33) ("mwd" . 34) ("mjs" . 35) ("msd" . 36)
                   ;;  Linear: scale from the width (checkbox, factor), origin on the line (checkbox, offset):
                   ("msw" . 37) ("mfc" . 38) ("mor" . 39) ("mof" . 40)
                   ;;  Hatch: existing phase background (checkbox, color):
                   ("hxo" . 41) ("hxb" . 42)
                   ;;  Behaviors: gap tolerance of Shrinkwrap:
                   ("mgp" . 43) ("mgo" . 44) ("mgm" . 45)
                  )
)

;;  Optional settings: (checkbox value-tiles...): the value tiles (and the ... color button)
;;  are greyed out until the checkbox is checked:
(setq *mt:optional* '(("bco" "bcv" "bcp") ("blo" "blt") ("bso" "bsc") ("bwo" "bwt") ("bto" "btr")
                      ("hco" "hcl" "hcp") ("hbo" "hbg" "hbp") ("hxo" "hxb" "hxp") ("hwo" "hwt") ("hto" "htr")
                     )
)

;;  Optional hatch settings a SOLID hatch does not use (greyed out, not set): background
;;  color, existing phase background, lineweight:
(setq *mt:solidoff* '("hbo" "hxo" "hwo"))

;;  Lineweights of AutoCAD, in hundredths of mm:
(setq *mt:weights* '("0" "5" "9" "13" "15" "18" "20" "25" "30" "35" "40" "50" "53" "60" "70" "80" "90"
                     "100" "106" "120" "140" "158" "200" "211"
                    )
)

;;  Popup tiles -> list of their values (nil for the other tiles):
(defun Remote>>Dyl:MaterialDlgItems (key)
  (cond
    ((= "pat" key) mt:pats)
    ((member key '("out" "hat")) mt:keys)
    ((member key '("bwt" "hwt")) *mt:weights*)
    ((= "mth" key) (cons "" (mapcar 'car *mt:methods*)))
    ((= "mjs" key) (mapcar 'car *mt:justify*))
  )
)

;;  ... button of a color: the AutoCAD color dialog on the color of the tile key, the color
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
    ((and (member key '("simp" "smet")) (not (and (distof val) (< 0 (distof val)))))
     "The scale must be a number greater than 0."
    )
    ((and (= "sref" key) (not (Remote>>Dyl:MaterialScale-p val)))
     "The drawing scale must be a number greater than 0 (10 for 1:10)."
    )
    ((and (member key '("bcv" "hcl" "hbg" "hxb")) (not (Remote>>Dyl:MaterialColorParse val)))
     "A color is an AutoCAD color number 1-255 or r,g,b (0-255 each), or use the ... button."
    )
    ((and (= "blt" key) (= "" val)) "The linetype cannot be empty.")
    ((and (= "bsc" key) (not (Remote>>Dyl:MaterialScale-p val))) "The linetype scale must be a number greater than 0.")
    ((and (member key '("btr" "htr")) (not (and (wcmatch val "#,##") (<= 0 (atoi val) 90))))
     "The transparency must be a whole number from 0 to 90."
    )
    ((and (= "mwd" key) (/= "" val) (not (Remote>>Dyl:MaterialWidths val)))
     "Widths must be numbers greater than 0, divided by commas (empty: the last width used)."
    )
    ((and (= "mfc" key) (not (Remote>>Dyl:MaterialScale-p val))) "The width factor must be a number greater than 0.")
    ((and (member key '("mgp" "mgm")) (/= "" val) (not (and (distof val 2) (<= 0 (distof val 2)))))
     "The gap tolerance must be a number, 0 or more (empty: asked when drawn)."
    )
    ((and (= "mof" key) (not (distof val 2))) "The origin offset must be a number (0: on the line).")
    ((and (= "msd" key) (/= "" val) (not (and (wcmatch val "#,##,###,####") (<= 3 (atoi val) 1024))))
     "The number of sides must be a whole number from 3 to 1024 (empty: asked when drawn)."
    )
    ((and (= "ang" key) (not (distof val))) "The angle must be a number.")
  )
)

;;  Fill the layer key popups: keys of LayerKeys.csv, then the keys used by a material but not
;;  defined (drawn on a layer of the same name):
(defun Remote>>Dyl:MaterialDlgKeys (/ lks)
  (setq lks     (Remote>>Dyl:LayerKeyRead)
        mt:keys (mapcar 'car lks)
  )
  (foreach r (append (Remote>>Dyl:MaterialDefs) pst:lst)
    (foreach k (list (nth 7 r) (nth 8 r))
      (if (not (member k mt:keys)) (setq mt:keys (append mt:keys (list k))))
    )
  )
  (foreach tile '("out" "hat")
    (start_list tile)
    (foreach k mt:keys
      (add_list (if (assoc k lks) (strcat k "   (" (nth 1 (assoc k lks)) ")") (strcat k "   (not defined)")))
    )
    (end_list)
  )
)

;;  Fill the popups and set the action of the Edit layer keys button (each time the dialog is shown):
(defun Remote>>Dyl:MaterialDlgInit ()
  (if (not mt:pats)
    (progn
      (setq mt:found (Remote>>Dyl:SupportDefs "pat")
            mt:pats  mt:found
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
  (Remote>>Dyl:MaterialDlgKeys)
  ;;  Lineweight popups, in mm:
  (foreach tile '("bwt" "hwt")
    (start_list tile)
    (foreach w *mt:weights* (add_list (strcat (rtos (/ (atoi w) 100.0) 2 2) " mm")))
    (end_list)
  )
  ;;  Behaviors: the Draw with and Line on popups:
  (start_list "mth")
  (foreach x (cons '("" "Ask when drawn") *mt:methods*) (add_list (cadr x)))
  (end_list)
  (start_list "mjs")
  (foreach x *mt:justify* (add_list (cadr x)))
  (end_list)
  ;;  ... buttons of the colors:
  (action_tile "bcp" "(Remote>>Dyl:MaterialDlgColor \"bcv\")")
  (action_tile "hcp" "(Remote>>Dyl:MaterialDlgColor \"hcl\")")
  (action_tile "hbp" "(Remote>>Dyl:MaterialDlgColor \"hbg\")")
  (action_tile "hxp" "(Remote>>Dyl:MaterialDlgColor \"hxb\")")
  ;;  Edit layer keys: close the dialog with code 3, see Remote>>Dyl:MaterialDlgStatus:
  (action_tile "lkd" "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog 3))")
)

;;  SOLID ignores the scale, angle and annotative values. The drawing scale applies only to
;;  a hatch that is not annotative, the scale it was set for only while it is checked. The
;;  line under it gives the factor in the current drawing (set for 1:10, here 1:50 -> x5):
;;  An optional setting has its value greyed out until its checkbox is checked. No border
;;  greys out the border settings, Associative and Hatch behind its border:
(defun Remote>>Dyl:MaterialDlgState (r / solid ano on nob tog)
  (setq solid (= "SOLID" (nth 3 r))
        ano   (= "1" (nth 9 r))
        on    (and (not solid) (not ano) (= "1" (nth 10 r)))
        nob   (= "1" (nth 31 r))
  )
  (foreach k '("simp" "smet" "ang" "ano") (mode_tile k (if solid 1 0)))
  (mode_tile "sdw" (if (or solid ano) 1 0))
  (mode_tile "sref" (if on 0 1))
  (foreach x *mt:optional*
    (setq tog (= "1" (nth (cdr (assoc (car x) *mt:tiles*)) r)))
    (if
      (or
        ;;  The border settings: off with No border:
        (and nob (= "b" (substr (car x) 1 1)))
        ;;  A SOLID hatch has no background, no existing phase background, no lineweight:
        (and solid (member (car x) *mt:solidoff*))
      )
      (foreach k x (mode_tile k 1))
      (progn
        (mode_tile (car x) 0)
        (foreach k (cdr x) (mode_tile k (if tog 0 1)))
      )
    )
  )
  (foreach k '("asc" "bhd") (mode_tile k (if nob 1 0)))
  ;;  Behaviors: the width and justify of Linear, the sides of Polygon, set for their method
  ;;  and for Ask when drawn (the method picked when drawn uses them too). The hatch scale
  ;;  from the width and the hatch origin on the line: not for a SOLID hatch:
  (foreach k '("mwd" "mjs") (mode_tile k (if (member (nth 33 r) '("Linear" "")) 0 1)))
  (foreach k '("msw" "mor") (mode_tile k (if (and (not solid) (member (nth 33 r) '("Linear" ""))) 0 1)))
  (mode_tile "msd" (if (member (nth 33 r) '("Polygon" "")) 0 1))
  ;;  Shrinkwrap gap override, its imperial and metric gaps until it is checked:
  (mode_tile "mgo" (if (member (nth 33 r) '("Shrinkwrap" "")) 0 1))
  (foreach k '("mgp" "mgm")
    (mode_tile k (if (and (member (nth 33 r) '("Shrinkwrap" "")) (= "1" (nth 44 r))) 0 1))
  )
  ;;  The width factor and the origin offset, until their checkbox is checked:
  (mode_tile "mfc" (if (and (not solid) (member (nth 33 r) '("Linear" "")) (= "1" (nth 37 r))) 0 1))
  (mode_tile "mof" (if (and (not solid) (member (nth 33 r) '("Linear" "")) (= "1" (nth 39 r))) 0 1))
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

;;  Code 3 = Edit layer keys: the Layer Keys dialog is shown (not nested in the materials dialog),
;;  then the materials dialog is shown again with the materials being edited:
(defun Remote>>Dyl:MaterialDlgStatus (sta r)
  (if (= 3 sta) (Remote>>Dyl:LayerKeyDialog (nth 7 r)))
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
          (cons 'groups *mt:groups*)
          '(upper "pat" "out" "hat" "blt")
          ;;  Three groups: the hatch and border settings (the basic ones first, then the
          ;;  optional ones, a checkbox each), and the behaviors of the material:
          '(params
            "      : row {"
            "        : boxed_column { label = \"Hatch settings\";"
            "          : popup_list { key = \"pat\"; label = \"Pattern:\"; edit_width = 26; }"
            "          : edit_box { key = \"simp\"; label = \"Scale (imperial):\"; edit_width = 12; }"
            "          : edit_box { key = \"smet\"; label = \"Scale (metric):\"; edit_width = 12; }"
            "          : edit_box { key = \"ang\"; label = \"Angle:\"; edit_width = 12; }"
            "          : popup_list { key = \"hat\"; label = \"Layer key:\"; edit_width = 26; }"
            "          spacer;"
            "          : row { : toggle { key = \"hco\"; label = \"Color:\"; width = 28; fixed_width = true; }"
            "                  : edit_box { key = \"hcl\"; edit_width = 11; }"
            "                  : button { key = \"hcp\"; label = \"...\"; width = 4; fixed_width = true; } }"
            "          : row { : toggle { key = \"hbo\"; label = \"Background color:\"; width = 28; fixed_width = true; }"
            "                  : edit_box { key = \"hbg\"; edit_width = 11; }"
            "                  : button { key = \"hbp\"; label = \"...\"; width = 4; fixed_width = true; } }"
            ;;  In place of the background color while auto-phase is on in the existing phase (E):
            "          : row { : toggle { key = \"hxo\"; label = \"Existing phase background:\"; width = 28; fixed_width = true; }"
            "                  : edit_box { key = \"hxb\"; edit_width = 11; }"
            "                  : button { key = \"hxp\"; label = \"...\"; width = 4; fixed_width = true; } }"
            "          : row { : toggle { key = \"hwo\"; label = \"Lineweight:\"; width = 28; fixed_width = true; }"
            "                  : popup_list { key = \"hwt\"; edit_width = 12; } }"
            "          : row { : toggle { key = \"hto\"; label = \"Transparency (0-90):\"; width = 28; fixed_width = true; }"
            "                  : edit_box { key = \"htr\"; edit_width = 6; } }"
            "          spacer;"
            ;;  How the hatch is scaled and made (see Remote>>Dyl:MaterialScale, Remote>>Dyl:MaterialHatchAt):
            "          : toggle { key = \"ano\"; label = \"Annotative hatch\"; }"
            "          : toggle { key = \"sdw\"; label = \"Follow the drawing scale (not annotative)\"; }"
            "          : edit_box { key = \"sref\"; label = \"Scales set for a drawing scale of 1:\"; edit_width = 8; }"
            "          : text { key = \"sinf\"; width = 44; }"
            "          : toggle { key = \"asc\"; label = \"Associative hatch\"; }"
            "          : toggle { key = \"bhd\"; label = \"Hatch behind its border\"; }"
            "          : text { label = \"SOLID: no scale, angle, background or lineweight.\"; }"
            "        }"
            "        : column {"
            "          : boxed_column { label = \"Border settings\";"
            "            : popup_list { key = \"out\"; label = \"Layer key:\"; edit_width = 26; }"
            "            spacer;"
            "            : row { : toggle { key = \"bco\"; label = \"Color:\"; width = 22; fixed_width = true; }"
            "                    : edit_box { key = \"bcv\"; edit_width = 11; }"
            "                    : button { key = \"bcp\"; label = \"...\"; width = 4; fixed_width = true; } }"
            "            : row { : toggle { key = \"blo\"; label = \"Linetype:\"; width = 22; fixed_width = true; }"
            "                    : edit_box { key = \"blt\"; edit_width = 16; } }"
            "            : row { : toggle { key = \"bso\"; label = \"Linetype scale:\"; width = 22; fixed_width = true; }"
            "                    : edit_box { key = \"bsc\"; edit_width = 8; } }"
            "            : row { : toggle { key = \"bwo\"; label = \"Lineweight:\"; width = 22; fixed_width = true; }"
            "                    : popup_list { key = \"bwt\"; edit_width = 12; } }"
            "            : row { : toggle { key = \"bto\"; label = \"Transparency (0-90):\"; width = 22; fixed_width = true; }"
            "                    : edit_box { key = \"btr\"; edit_width = 6; } }"
            "            : toggle { key = \"nob\"; label = \"No border (outline erased once hatched)\"; }"
            "            : button { key = \"lkd\"; label = \"Edit layer keys...\"; fixed_width = true; alignment = right; }"
            "          }"
            ;;  The behaviors: how Quick Draw draws the material (see Dyl:QuickDrawRun):
            "          : boxed_column { label = \"Material behaviors\";"
            "            : popup_list { key = \"mth\"; label = \"Draw with:\"; edit_width = 30; }"
            "            : edit_box { key = \"mwd\"; label = \"Width (Linear):\"; edit_width = 16; edit_limit = 128; }"
            "            : popup_list { key = \"mjs\"; label = \"Line on the (Linear):\"; edit_width = 22; }"
            "            : row { : toggle { key = \"msw\"; label = \"Hatch scale = width x\"; width = 30; fixed_width = true; }"
            "                    : edit_box { key = \"mfc\"; edit_width = 8; } }"
            "            : row { : toggle { key = \"mor\"; label = \"Hatch origin on the line, offset:\"; width = 30; fixed_width = true; }"
            "                    : edit_box { key = \"mof\"; edit_width = 8; } }"
            "            : edit_box { key = \"msd\"; label = \"Sides (Polygon):\"; edit_width = 6; }"
            ;;  Shrinkwrap gap: off, the gap step of Dyl-Settings from 0; on, the gap of the
            ;;  drawing units (MEASUREMENT), asked when drawn when it is empty:
            "            : toggle { key = \"mgo\"; label = \"Gap override (Shrinkwrap)\"; }"
            "            : row { : edit_box { key = \"mgp\"; label = \"Imperial:\"; edit_width = 8; }"
            "                    : edit_box { key = \"mgm\"; label = \"Metric:\"; edit_width = 8; } }"
            "            : text { label = \"Widths: 100 or 100,150 (asked). Empty: the last one.\"; }"
            "            : text { label = \"Empty sides or gap: asked. Gap off: Dyl-Settings step.\"; }"
            "          }"
            "        }"
            "      }"
           )
          ;;  A new material: the optional settings off, associative:
          (cons 'new (append '("" "" "New material" "ANSI31" "1.0" "1.0" "0" "THIN" "HATCH" "1" "0" "1") *mt:extra*))
          '(items . Remote>>Dyl:MaterialDlgItems)
          '(check . Remote>>Dyl:MaterialDlgCheck)
          '(init . Remote>>Dyl:MaterialDlgInit)
          '(state . Remote>>Dyl:MaterialDlgState)
          '(status . Remote>>Dyl:MaterialDlgStatus)
          ;;  A list as tall as the three groups of parameters beside it:
          '(height . 30)
    )
  )
)

(princ)
