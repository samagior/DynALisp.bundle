;; Dyl-LayerKey - Dynalisp layer keys: named keys mapped to a layer and its properties
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

;;  Loaded at startup with the other Remote files, before the Apps.
;;
;;  A layer key is a short name (e.g. "THIN") used by the Apps instead of a layer
;;  name, like the AutoCAD Architecture layer keys but in plain AutoCAD. Each key
;;  gives the layer to use, and the properties to create it with when the drawing
;;  does not have it. An existing layer whose properties differ from those of its key is
;;  updated only when the user says so (asked once per drawing and session, or the answer
;;  remembered, see Remote>>Dyl:LayerKeyCheck).
;;
;;  The keys are saved to Modules\Dynalisp\Res\LayerKeys.csv and edited with the Layer Keys
;;  dialog (Remote>>Dyl:LayerKeyDialog, command Dyl-LayerKeys). Default keys can be
;;  edited and reset, not renamed or deleted; custom keys can be added freely.
;;
;;  A key is a list of strings:
;;  (key layer color linetype lineweight plot description aec keepcolor)
;;  color: ACI 1-255, lineweight: "Default" or millimetres ("0.25"), plot, aec and keepcolor:
;;  "1" or "0". keepcolor "1": its layer keeps the color of the key in every phase (see
;;  Remote>>Dyl:LayerKeyKeepColor), else a phase gives it its phase color.
;;  (LayerKeys.csv of older versions had a Phased column before Aec: it is ignored, see
;;  Remote>>Dyl:LayerKeyFix.)
;;
;;  aec "1": an AEC layer override, a default key of the AutoCAD Architecture layer keys
;;  (*lk:aec*, e.g. DOOR), with the layer and the properties the AIA (256 Color) layer key
;;  style gives it (DOOR -> A-Door, color 31, 0.25 mm). Only its key is locked (as any
;;  default key): the rest is edited as for the other keys. As shipped (its default values),
;;  with AutoCAD Architecture, its layer is the one the layer key style of the drawing gives
;;  it (AECREMAPLAYERS, see Remote>>Dyl:LayerKeyAecLayer); without it, when the style has no
;;  such key, or once edited, its own layer, created with its values.
;;
;;  Every key is phased: while auto-phase is on, a key gives its layer in the active phase of
;;  the drawing (see Dyl-LayerPhase.lsp): THIN -> A-Detl-Thin-E in existing, A-Detl-Thin when
;;  auto-phase is off or the drawing has no active phase. A phase layer is created with the
;;  phase color (existing 20#, demolished 2#), or with the color of its key when the key keeps
;;  its color (keepcolor). Auto-phase also moves the objects
;;  created on the layer of a key to the active phase.
;;
;;  Use in an App:
;;    (Remote>>Dyl:LayerKeyLayer "THIN")         -> layer name, created if missing
;;    (Remote>>Dyl:LayerKeyApply (entlast) "THIN") -> puts an object on that layer


;;  Default keys, restored by the Reset key and Restore defaults buttons:
(setq *lk:defaults* '(("FINE" "A-Detl-Fine" "1" "CONTINUOUS" "0.18" "1" "Detail: Fine Lines" "0" "0")
                      ("THIN" "A-Detl-Thin" "2" "CONTINUOUS" "0.25" "1" "Detail: Thin Lines" "0" "0")
                      ("MED" "A-Detl-Medm" "3" "CONTINUOUS" "0.35" "1" "Detail: Medium Lines" "0" "0")
                      ("WIDE" "A-Detl-Wide" "4" "CONTINUOUS" "0.50" "1" "Detail: Wide Lines" "0" "0")
                      ("XLINE" "A-Detl-XFin" "8" "CONTINUOUS" "0.13" "1" "Detail: Extra Fine Lines" "0" "0")
                      ("HATCH" "A-Detl-Patt" "8" "CONTINUOUS" "0.18" "1" "Detail: Texture Or Hatch Patterns" "0" "0")
                      ("G-DS-ANNO-STD-BACKGROUND_SCREEN" "A-Detl-Scrn" "254" "CONTINUOUS" "0.18" "1"
                       "Detail: Screening Of Coordination Objects And Backgrounds" "0" "0"
                      )
                     )
      ;;  Module Res folder (this file loads before Dyl-Paths.lsp sets *dyl:dylres):
      *lk:file*     (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\LayerKeys.csv")
      *lk:header*   '("Key" "Layer" "Color" "Linetype" "Lineweight" "Plot" "Description" "Aec" "KeepColor")
      *lk:weights*  '("Default" "0.00" "0.05" "0.09" "0.13" "0.15" "0.18" "0.20" "0.25" "0.30" "0.35" "0.40"
                      "0.50" "0.53" "0.60" "0.70" "0.80" "0.90" "1.00" "1.06" "1.20" "1.40" "1.58" "2.00" "2.11"
                     )
)

;;  AEC layer overrides: the keys of the AutoCAD Architecture layer key styles (key layer
;;  color linetype lineweight plot description), default keys (see above). Their layer and properties are those of the AIA (256 Color) layer
;;  key style (AecLayerStd.dwg of AutoCAD Architecture 2027, read with AECREMAPLAYERS);
;;  MASS ELEM is not in that style: its layer is named after it. The keys of the details (FINE, THIN, MED, WIDE, XLINE, HATCH) stay the
;;  DynALisp keys above:
(setq *lk:aec* '(("ANNDTOBJ" "G-Detl-Iden" "31" "CONTINUOUS" "0.25" "1" "Detail marks")
                  ("ANNELKEY" "G-Elev-Iden" "151" "CONTINUOUS" "0.25" "1" "Elevation marks")
                  ("ANNELOBJ" "G-Elev-Line" "141" "CONTINUOUS" "0.25" "0" "Elevation Definition Lines")
                  ("ANNMASK" "G-Anno-Mask" "170" "CONTINUOUS" "0.18" "1" "Aec Masking Objects")
                  ("ANNMATCH" "G-Anno-Matc" "214" "CONTINUOUS" "0.70" "1" "Match Lines")
                  ("ANNOBJ" "G-Anno-Note" "231" "CONTINUOUS" "0.25" "1" "Notes, leaders, etc.")
                  ("ANNREV" "G-Anno-Revs" "71" "CONTINUOUS" "0.25" "1" "Revisions")
                  ("ANNSXKEY" "G-Sect-Iden" "191" "CONTINUOUS" "0.25" "1" "Section marks")
                  ("ANNSXOBJ" "G-Sect-Line" "181" "CONTINUOUS" "0.18" "0" "Section lines")
                  ("ANNSYMOBJ" "G-Anno-Symb" "131" "CONTINUOUS" "0.25" "1" "Annotation marks")
                  ("APPL" "A-Appl" "11" "CONTINUOUS" "0.25" "1" "Appliances")
                  ("CASE" "A-Case" "31" "CONTINUOUS" "0.25" "1" "Casework")
                  ("CASENO" "A-Case-Iden" "31" "CONTINUOUS" "0.25" "1" "Casework tags")
                  ("CEILGRID" "A-Clng-Grid" "72" "CONTINUOUS" "0.50" "1" "Ceiling grids")
                  ("CEILOBJ" "A-Clng" "13" "CONTINUOUS" "0.50" "1" "Ceiling objects")
                  ("CHASE" "A-Wall-Chas" "91" "CONTINUOUS" "0.25" "1" "Chases")
                  ("COGO" "AS-Ctrl" "7" "CONTINUOUS" "0.18" "1" "Control Points")
                  ("COLUMN" "S-Cols" "112" "CONTINUOUS" "0.50" "1" "Columns")
                  ("COMMUN" "T-Comm" "130" "CONTINUOUS" "0.18" "1" "Communication")
                  ("CONTROL" "T-Ctrl" "230" "CONTINUOUS" "0.18" "1" "Control systems")
                  ("CWLAYOUT" "A-Glaz-Curt" "52" "CONTINUOUS" "0.50" "1" "Curtain Walls")
                  ("CWUNIT" "A-Glaz-Curt-Unit" "51" "CONTINUOUS" "0.25" "1" "Curtain Wall Units")
                  ("DIMLINE" "G-Anno-Dims" "211" "CONTINUOUS" "0.25" "1" "Dimensions")
                  ("DIMMAN" "G-Anno-Dims" "211" "CONTINUOUS" "0.25" "1" "Dimensions (AutoCAD points)")
                  ("DISPTHEME" "G-Anno-Them" "52" "CONTINUOUS" "0.50" "1" "Display Theme Legends")
                  ("DOOR" "A-Door" "31" "CONTINUOUS" "0.25" "1" "Doors")
                  ("DOORNO" "A-Door-Iden" "31" "CONTINUOUS" "0.25" "1" "Door tags")
                  ("DRAINAGE" "P-Pipe-Dran" "150" "CONTINUOUS" "0.18" "1" "Drainage")
                  ("ELEC" "E-Elec" "71" "CONTINUOUS" "0.25" "1" "Electrical")
                  ("ELECNO" "E-Elec-Iden" "31" "CONTINUOUS" "0.25" "1" "Electrical tags")
                  ("ELEV" "G-Elev" "111" "CONTINUOUS" "0.50" "1" "Elevations")
                  ("ELEVAT" "A-Evtr" "172" "CONTINUOUS" "0.35" "1" "Elevators")
                  ("ELEVHIDE" "G-Elev" "111" "CONTINUOUS" "0.50" "1" "Elevations (2D)")
                  ("EQUIP" "G-Eqpm" "71" "CONTINUOUS" "0.25" "1" "Equipment")
                  ("EQUIPNO" "G-Eqpm-Iden" "31" "CONTINUOUS" "0.25" "1" "Equipment tags")
                  ("FINCEIL" "A-Clng-Iden" "31" "CONTINUOUS" "0.25" "1" "Ceiling tags")
                  ("FINFLOOR" "A-Flor-Iden" "31" "CONTINUOUS" "0.25" "1" "Finish tags")
                  ("FIRE" "F-Eqpm" "91" "CONTINUOUS" "0.25" "1" "Fire system equip.")
                  ("FURN" "I-Furn" "30" "CONTINUOUS" "0.18" "1" "Furniture")
                  ("FURNNO" "I-Furn-Iden" "31" "CONTINUOUS" "0.25" "1" "Furniture tags")
                  ("G-DS-ANNO-STD-NON_PLOTTABLE_OBJECTS" "G-Anno-Stnd-Nplt" "140" "CONTINUOUS" "0.18" "0" "General Annotation Layer Key: Non-Plottable Objects")
                  ("G-DS-ANNO-STD-NON_PLOTTABLE_OBJECTS_SCREEN" "G-Anno-Stnd-Nplt-Scrn" "8" "CONTINUOUS" "0.18" "0" "General Annotation Layer Key: Non-Plottable Screened Objects")
                  ("GRIDBUB" "S-Grid-Iden" "31" "CENTER" "0.25" "1" "Plan grid bubbles")
                  ("GRIDLINE" "S-Grid" "191" "CENTER" "0.25" "1" "Column Grids")
                  ("HIDDEN" "G-Detl-Hidd" "1" "HIDDEN2" "0.18" "1" "Hidden lines")
                  ("LAYGRID" "G-Grid-Nplt" "200" "DASHED" "0.18" "0" "Layout grids")
                  ("LIGHTCLG" "E-Lite-Clng" "193" "CONTINUOUS" "0.50" "1" "Ceiling lighting")
                  ("LIGHTW" "E-Lite-Wall" "53" "CONTINUOUS" "0.50" "1" "Wall lighting")
                  ("MASS ELEM" "MASS ELEM" "7" "CONTINUOUS" "Default" "1" "Massing elements")
                  ("MASSGRPS" "G-Mass-Grps" "13" "CONTINUOUS" "0.50" "1" "Massing groups")
                  ("MASSSLCE" "G-Mass-Slce" "51" "DASHED" "0.25" "1" "Massing Slices")
                  ("OPENING" "A-Wall-Open" "31" "CONTINUOUS" "0.25" "1" "Wall openings")
                  ("PEOPLE" "A-Elev-Pepl" "30" "CONTINUOUS" "0.18" "1" "People")
                  ("PFIXT" "P-Fixt" "131" "CONTINUOUS" "0.25" "1" "Plumbing fixtures")
                  ("PLANTS" "L-Site-Plnt" "71" "CONTINUOUS" "0.25" "1" "Plants - outdoor")
                  ("PLANTSI" "I-Furn-Plnt" "70" "CONTINUOUS" "0.18" "1" "Plants - indoor")
                  ("POLYGON" "G-Poly" "110" "CONTINUOUS" "0.50" "1" "AEC Polygons")
                  ("POWER" "E-Wire-Powr" "113" "CONTINUOUS" "0.50" "1" "Electrical power")
                  ("PRCL" "AS-Prop" "7" "CONTINUOUS" "0.18" "1" "Property")
                  ("PRK-SYM" "C-Site-Prkg" "70" "CONTINUOUS" "0.18" "1" "Parking symbols")
                  ("RBFINISHID" "G-Spce-Stnd-Iden" "31" "CONTINUOUS" "0.25" "1" "Room Book Layer Key: Finish ID's")
                  ("RBQUANTITYID" "G-Spce-Stnd-Iden" "31" "CONTINUOUS" "0.25" "1" "Room Book Layer Key: Quantity ID's")
                  ("ROOF" "A-Roof" "132" "CONTINUOUS" "0.35" "1" "Rooflines")
                  ("ROOFSLAB" "A-Roof-Slab" "12" "CONTINUOUS" "0.35" "1" "Roof Slabs")
                  ("ROOMNO" "A-Area-Room-Iden" "31" "CONTINUOUS" "0.25" "1" "Room tags")
                  ("SCHEDOBJ" "G-Schd" "231" "CONTINUOUS" "0.25" "1" "Schedule tables")
                  ("SEATNO" "I-Furn-Iden" "31" "CONTINUOUS" "0.25" "1" "Seating tags")
                  ("SECT" "G-Sect" "73" "CONTINUOUS" "0.50" "1" "Miscellaneous sections")
                  ("SECTHIDE" "G-Sect" "73" "CONTINUOUS" "0.50" "1" "Sections (2D)")
                  ("SITE" "C-Site" "91" "CONTINUOUS" "0.25" "1" "Site")
                  ("SLAB" "A-Slab" "192" "CONTINUOUS" "0.35" "1" "Slabs")
                  ("SPACENO" "G-Area-Spce-Iden" "31" "CONTINUOUS" "0.25" "1" "Space numbers")
                  ("SPACEOBJ" "G-Area-Spce" "52" "CONTINUOUS" "0.50" "1" "Spaces")
                  ("STAIR" "A-Flor-Strs" "31" "CONTINUOUS" "0.25" "1" "Stairs")
                  ("STAIRH" "A-Flor-Strs-Hral" "11" "CONTINUOUS" "0.25" "1" "Stair handrails")
                  ("STRUCTBEAM" "S-Beam" "72" "CONTINUOUS" "0.50" "1" "Structural Beams")
                  ("STRUCTBEAMIDEN" "S-Beam-Iden" "31" "CONTINUOUS" "0.25" "1" "Structural Beam Tags")
                  ("STRUCTBRACE" "S-Cols-Brcg" "92" "DASHED" "0.35" "1" "Structural Braces")
                  ("STRUCTBRACEIDEN" "S-Cols-Brcg-Iden" "31" "CONTINUOUS" "0.25" "1" "Structural Brace Tags")
                  ("STRUCTCOLS" "S-Cols" "112" "CONTINUOUS" "0.50" "1" "Structural Columns")
                  ("STRUCTCOLSIDEN" "S-Cols-Iden" "31" "CONTINUOUS" "0.25" "1" "Structural Column Tags")
                  ("SWITCH" "E-Devc-Swch" "11" "CONTINUOUS" "0.25" "1" "Electrical switches")
                  ("TINN" "AS-Tinn" "7" "CONTINUOUS" "0.18" "1" "Triangulated irregular network")
                  ("TITSCALE" "G-Anno-Titl-Scal" "231" "CONTINUOUS" "0.25" "1" "Graphical Scales")
                  ("TITTEXT" "G-Anno-Ttlb" "213" "CONTINUOUS" "0.50" "1" "Border and title block")
                  ("TITTEXT-DWG" "G-Anno-Titl-Text" "233" "CONTINUOUS" "0.50" "1" "Drawing title text")
                  ("TOILACC" "P-Flor-Spcl" "90" "CONTINUOUS" "0.18" "1" "Arch. specialties")
                  ("TOILNO" "P-Flor-Fixt-Iden" "31" "CONTINUOUS" "0.25" "1" "Toilet tags")
                  ("TOPO" "AS-Topo" "7" "CONTINUOUS" "0.18" "1" "Topography")
                  ("UTIL" "C-Site-Util" "91" "CONTINUOUS" "0.25" "1" "Site utilities")
                  ("VEHICLES" "C-Site-Vhcl" "30" "CONTINUOUS" "0.18" "1" "Vehicles")
                  ("VIEWPORT" "G-View-Nplt" "140" "CONTINUOUS" "0.18" "0" "Sheet View viewports")
                  ("WALL" "A-Wall" "113" "CONTINUOUS" "0.50" "1" "Walls")
                  ("WALLFIRE" "F-Wall-Fire-Patt" "152" "DASHED" "0.35" "1" "Fire wall patterning")
                  ("WALLNO" "A-Anno-Wall-Iden" "31" "CONTINUOUS" "0.25" "1" "Wall tags")
                  ("WIND" "A-Glaz" "51" "CONTINUOUS" "0.25" "1" "Windows")
                  ("WINDASSEM" "A-Glaz-Assm" "71" "CONTINUOUS" "0.25" "1" "Window Assemblies")
                  ("WINDNO" "A-Glaz-Iden" "31" "CONTINUOUS" "0.25" "1" "Window tags")
                  ("ZONE" "G-Area-Zone" "52" "CONTINUOUS" "0.50" "1" "Zones")
                  ("ZONENO" "G-Area-Zone-Iden" "31" "CONTINUOUS" "0.25" "1" "Zone tags")
                 )
)
;;  Keys no longer used: dropped when LayerKeys.csv is read (see Remote>>Dyl:LayerKeyFix):
(setq *lk:removed* '("G_DS_ANNO_STD_ANNOTATION_SCREEN"))

;;  Keys kept for compatibility only (the display configurations of AutoCAD Architecture),
;;  never given to a material: out of the layer key popups of the Materials window, refused
;;  by a double-click in the Layer Keys window opened from it, and replaced by HATCH in a
;;  material that has one (see Remote>>Dyl:MaterialFix):
(setq *lk:nomaterial* "G-DS-ANNO-STD-*")

;;  T when the key can be given to a material (see *lk:nomaterial*):
(defun Remote>>Dyl:LayerKeyMaterial-p (key)
  (not (wcmatch (strcase key) *lk:nomaterial*))
)

(setq *lk:defaults*
       (append *lk:defaults*
               (mapcar '(lambda (x) (append x '("1" "0"))) *lk:aec*)
       )
)

;;-------------------------=={ Keys }==------------------------;;

;;  Lineweight cell -> item of *lk:weights* ("Default" when it is not a valid lineweight):
(defun Remote>>Dyl:LayerKeyWeight (str / mm)
  (cond
    ((not (setq mm (distof str 2))) "Default")
    ((vl-some '(lambda (w) (if (equal mm (distof w 2) 1e-6) w)) (cdr *lk:weights*)))
    ("Default")
  )
)

;;  Clean a row read from LayerKeys.csv, returns nil when the key or the layer is not valid,
;;  or when the key is no longer used (*lk:removed*):
(defun Remote>>Dyl:LayerKeyFix (row / aci)
  (setq aci (atoi (nth 2 row)))
  (if (and (/= "" (car row))
           (snvalid (car row))
           (/= "" (nth 1 row))
           (snvalid (nth 1 row))
           (not (member (strcase (car row)) *lk:removed*))
      )
    (list (strcase (car row))
          (nth 1 row)
          (itoa (if (<= 1 aci 255) aci 7))
          (if (= "" (nth 3 row)) "CONTINUOUS" (strcase (nth 3 row)))
          (Remote>>Dyl:LayerKeyWeight (nth 4 row))
          (if (= "0" (nth 5 row)) "0" "1")
          (nth 6 row)
          (if (assoc (strcase (car row)) *lk:aec*) "1" "0")
          (if (= "1" (nth 8 row)) "1" "0")
    )
  )
)

;;  Read LayerKeys.csv. Default keys missing from the file are added with their default values:
(defun Remote>>Dyl:LayerKeyRead (/ row lst)
  (foreach x (Remote>>Dyl:CsvRead (Dyl:UserFile *lk:file*) 9)
    (if (and (setq row (Remote>>Dyl:LayerKeyFix x)) (not (assoc (car row) lst)))
      (setq lst (cons row lst))
    )
  )
  (setq lst (reverse lst))
  (foreach x *lk:defaults*
    (if (not (assoc (car x) lst)) (setq lst (append lst (list x))))
  )
  lst
)

;;  Write LayerKeys.csv (its user copy), returns T on success (nil if the file is open in Excel):
(defun Remote>>Dyl:LayerKeyWrite (lst)
  (Remote>>LM:writecsv (cons *lk:header* lst) (Dyl:UserFileW *lk:file*))
)

;;  T when the key rec is an AEC layer override (see above):
(defun Remote>>Dyl:LayerKeyAec-p (rec)
  (= "1" (nth 7 rec))
)

;;  Layer the layer key style of the drawing gives the AEC key key, with AutoCAD Architecture
;;  (command AECREMAPLAYERS: a temporary point remapped to the key, its layer read, then
;;  erased; the command creates the layer when the drawing does not have it). nil without
;;  AutoCAD Architecture, while a command or a dialog is active (no command can run then),
;;  or when the style has no such key (the point stays on layer 0):
(defun Remote>>Dyl:LayerKeyAecLayer (key / e lay cmd)
  ;;  Not from a reactor (*lk:noask*, see Reactor\Dyl-ObjectLayerKeys.lsp): no command there:
  (if (and (not *lk:noask*)
           (getcname "_AECREMAPLAYERS")
           (= 0 (logand 11 (getvar "CMDACTIVE")))
           (setq e (entmakex (list '(0 . "POINT") '(8 . "0") '(10 0.0 0.0 0.0))))
      )
    (progn
      (setq cmd (getvar "CMDECHO"))
      (setvar "CMDECHO" 0)
      (vl-catch-all-apply 'vl-cmdf (list "_.AECREMAPLAYERS" e "" key))
      ;;  A key the style does not have is asked again: the command is cancelled:
      (repeat 3 (if (< 0 (logand 3 (getvar "CMDACTIVE"))) (command)))
      (setvar "CMDECHO" cmd)
      (setq lay (cdr (assoc 8 (entget e))))
      (entdel e)
      (if (and lay (/= "0" lay)) lay)
    )
  )
)

;;  Return the definition of a key, or nil when it is not defined:
(defun Remote>>Dyl:LayerKeyGet (key)
  (assoc (strcase key) (Remote>>Dyl:LayerKeyRead))
)

;;  Lineweight of a key (rec) as AutoCAD stores it: hundredths of mm, -3 for Default:
(defun Remote>>Dyl:LayerKeyLw (rec)
  (if (= "Default" (nth 4 rec)) -3 (fix (+ 0.5 (* 100 (distof (nth 4 rec) 2)))))
)

;;  Give the layer lay (a vla object) the color, linetype, lineweight and plot of the key
;;  definition rec (the linetype is loaded from acad.lin / acadiso.lin when needed, the
;;  linetype of the layer is kept when it cannot be loaded):
(defun Remote>>Dyl:LayerKeyProps (lay rec / doc lin)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        lin (findfile (if (= 1 (getvar "MEASUREMENT")) "acadiso.lin" "acad.lin"))
  )
  (if (and lin (not (tblsearch "LTYPE" (nth 3 rec))))
    (vl-catch-all-apply 'vla-Load (list (vla-get-Linetypes doc) (nth 3 rec) lin))
  )
  (vla-put-Color lay (atoi (nth 2 rec)))
  (if (tblsearch "LTYPE" (nth 3 rec)) (vla-put-Linetype lay (nth 3 rec)))
  (vla-put-Lineweight lay (Remote>>Dyl:LayerKeyLw rec))
  (vla-put-Plottable lay (if (= "1" (nth 5 rec)) :vlax-true :vlax-false))
)

;;  Create the layer of a key definition with its properties (see Remote>>Dyl:LayerKeyProps)
;;  and its description:
(defun Remote>>Dyl:LayerKeyMake (rec / lay)
  (if
    (not
      (vl-catch-all-error-p
        (setq lay (vl-catch-all-apply
                    'vla-Add
                    (list (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object))) (nth 1 rec))
                  )
        )
      )
    )
    (progn
      (Remote>>Dyl:LayerKeyProps lay rec)
      (vla-put-Description lay (nth 6 rec))
      (princ (strcat "\nLayer created: " (nth 1 rec) " (layer key " (car rec) ")"))
    )
  )
)

;;-------------------------=={ Layers that differ from their key }==------------------------;;

;;  A layer of a key that exists in the drawing with other properties (color, linetype,
;;  lineweight, plot; the description is not compared) is checked the first time the key
;;  gives it in the drawing with those values (once per session and values, *lk:checked*: the
;;  layers checked with the values they were checked against, a global of the drawing, see
;;  Remote>>Dyl:LayerKeyChecked; a key edited is checked again, and OK in the Layer Keys window
;;  forgets them all). The user is asked whether to update it to its key (Yes / No), unless the
;;  answer was remembered ("Remember my answer", the Layer keys section of Dyl-Settings):
;;  DynalispLayerKeyUpdate "1", updated without asking; DynalispLayerKeyKeep "1", kept
;;  without asking (one of them at most, both off on a new installation: asked).

;;  The remembered answer: "Update", "Keep", nil (asked):
(defun Remote>>Dyl:LayerKeyMatch ()
  (cond
    ((= "1" (getenv "DynalispLayerKeyUpdate")) "Update")
    ((= "1" (getenv "DynalispLayerKeyKeep")) "Keep")
  )
)

;;  Remember the answer m ("Update", "Keep"; nil: ask again):
(defun Remote>>Dyl:LayerKeyMatchSet (m)
  (setenv "DynalispLayerKeyUpdate" (if (= "Update" m) "1" "0"))
  (setenv "DynalispLayerKeyKeep" (if (= "Keep" m) "1" "0"))
)

;;  Lineweight as text (hundredths of mm, -3 Default, -1 / -2 ByLayer / ByBlock):
(defun Remote>>Dyl:LayerKeyLwText (lw)
  (cond
    ((= -3 lw) "Default")
    ((< lw 0) "By layer")
    ((strcat (rtos (/ lw 100.0) 2 2) " mm"))
  )
)

;;  The properties of the layer of rec (its layer in the drawing, see
;;  Remote>>Dyl:LayerKeyInDrawing) that differ from rec: ("Color: 5 (layer key: 2)" ...), nil
;;  when they are the same or the layer is missing:
(defun Remote>>Dyl:LayerKeyDiffs (rec / e ed c lt lw pl res)
  (if (setq e (tblobjname "LAYER" (nth 1 rec)))
    (progn
      (setq ed (entget e)
            c  (abs (cdr (assoc 62 ed)))
            lt (cond ((cdr (assoc 6 ed))) ("CONTINUOUS"))
            lw (cond ((cdr (assoc 370 ed))) (-3))
            pl (if (= 0 (cdr (assoc 290 ed))) "0" "1")
      )
      (if (or (assoc 420 ed) (/= c (atoi (nth 2 rec))))
        (setq res (cons (strcat "Color: " (if (assoc 420 ed) "a true color" (itoa c)) " (layer key: " (nth 2 rec) ")") res))
      )
      (if (/= (strcase lt) (strcase (nth 3 rec)))
        (setq res (cons (strcat "Linetype: " lt " (layer key: " (nth 3 rec) ")") res))
      )
      (if (/= lw (Remote>>Dyl:LayerKeyLw rec))
        (setq res (cons (strcat "Lineweight: " (Remote>>Dyl:LayerKeyLwText lw) " (layer key: "
                                (Remote>>Dyl:LayerKeyLwText (Remote>>Dyl:LayerKeyLw rec)) ")"
                        )
                        res
                  )
        )
      )
      (if (/= pl (nth 5 rec))
        (setq res (cons (strcat "Plot: " (if (= "1" pl) "Yes" "No") " (layer key: " (if (= "1" (nth 5 rec)) "Yes" "No") ")") res))
      )
      (reverse res)
    )
  )
)

;;  Update the layer of rec to its properties (see Remote>>Dyl:LayerKeyProps):
(defun Remote>>Dyl:LayerKeyUpdate (rec / lay)
  (if (not (vl-catch-all-error-p
             (setq lay (vl-catch-all-apply
                         'vla-Item
                         (list (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object))) (nth 1 rec))
                       )
             )
           )
      )
    (if (vl-catch-all-error-p (vl-catch-all-apply 'Remote>>Dyl:LayerKeyProps (list lay rec)))
      (princ (strcat "\n--> The layer " (nth 1 rec) " could not be updated to its layer key " (car rec) "."))
      (princ (strcat "\nLayer updated to its layer key " (car rec) ": " (nth 1 rec) "."))
    )
  )
)

;;  Ask whether to update the layer of rec, whose properties dif differ from it (see
;;  Remote>>Dyl:LayerKeyDiffs): Yes / No, Remember my answer (the answer then remembered,
;;  see Remote>>Dyl:LayerKeyMatchSet). Returns T on Yes:
(defun Remote>>Dyl:LayerKeyAsk (rec dif / path file id sta rem i)
  (setq path (vl-filename-mktemp "lkd" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("dyl_lkdiff : dialog { label = \"DynALisp - Layer Key\";"
      "  : text { key = \"m0\"; width = 76; }"
      "  : paragraph {"
      "    : text_part { key = \"d1\"; width = 76; }"
      "    : text_part { key = \"d2\"; width = 76; }"
      "    : text_part { key = \"d3\"; width = 76; }"
      "    : text_part { key = \"d4\"; width = 76; }"
      "  }"
      "  : spacer { height = 0.5; }"
      "  : text { label = \"Update the layer to the values of its layer key?\"; }"
      "  : toggle { key = \"rem\"; label = \"Remember my answer and do not ask again (Dyl-Settings, Layer keys)\"; }"
      "  : row { fixed_width = true; alignment = right;"
      "    : button { key = \"yes\"; label = \"Yes\"; is_default = true; width = 12; fixed_width = true; }"
      "    : button { key = \"no\"; label = \"No\"; is_cancel = true; width = 12; fixed_width = true; }"
      "  }"
      "}"
     )
    (write-line line file)
  )
  (close file)
  (setq id (load_dialog path))
  (if (and (<= 0 id) (new_dialog "dyl_lkdiff" id))
    (progn
      (set_tile "m0" (strcat "The layer " (nth 1 rec) " differs from its layer key " (car rec) ":"))
      (setq i 0)
      (foreach k '("d1" "d2" "d3" "d4")
        (set_tile k (if (nth i dif) (strcat "    " (nth i dif)) ""))
        (setq i (1+ i))
      )
      (action_tile "yes" "(setq rem (get_tile \"rem\")) (done_dialog 1)")
      (action_tile "no" "(setq rem (get_tile \"rem\")) (done_dialog 2)")
      (setq sta (start_dialog))
    )
  )
  (if (<= 0 id) (unload_dialog id))
  (vl-file-delete path)
  (if (and (= "1" rem) (member sta '(1 2)))
    (progn
      (Remote>>Dyl:LayerKeyMatchSet (if (= 1 sta) "Update" "Keep"))
      (princ (strcat "\nAnswer remembered: the layers that differ from their layer key are "
                     (if (= 1 sta) "updated" "kept")
                     " without asking (Dyl-Settings, Layer keys)."
             )
      )
    )
  )
  (= 1 sta)
)

;;  Check the layer of rec (its layer in the drawing) against rec, once per session: when it
;;  differs, it is updated or kept as remembered, else the user is asked (only while no
;;  command runs: else asked the next time the key is used):
;;  What *lk:checked* keeps of the layer of rec: its name and the values it is checked against
;;  (a key edited since, e.g. Keep this color in every phase checked, gives other values: the
;;  layer is checked again):
(defun Remote>>Dyl:LayerKeyChecked (rec)
  (list (strcase (nth 1 rec)) (nth 2 rec) (strcase (nth 3 rec)) (nth 4 rec) (nth 5 rec))
)

(defun Remote>>Dyl:LayerKeyCheck (rec / nam dif m)
  (setq nam (Remote>>Dyl:LayerKeyChecked rec))
  (cond
    ((member nam *lk:checked*))
    ((not (setq dif (Remote>>Dyl:LayerKeyDiffs rec))) (setq *lk:checked* (cons nam *lk:checked*)))
    ((= "Keep" (setq m (Remote>>Dyl:LayerKeyMatch))) (setq *lk:checked* (cons nam *lk:checked*)))
    ((= "Update" m)
     (setq *lk:checked* (cons nam *lk:checked*))
     (Remote>>Dyl:LayerKeyUpdate rec)
    )
    ;;  Not from a reactor (*ph:busy*, *lk:noask*: no window there):
    ((and (= 0 (logand 15 (getvar "CMDACTIVE"))) (not *ph:busy*) (not *lk:noask*))
     (setq *lk:checked* (cons nam *lk:checked*))
     (if (Remote>>Dyl:LayerKeyAsk rec dif) (Remote>>Dyl:LayerKeyUpdate rec))
    )
  )
)

;;  Color the layer lay (its name without phase) keeps in every phase: the color of the key
;;  whose layer it is when that key keeps its color (keepcolor), nil otherwise (the phase
;;  gives the color, see Remote>>Dyl:PhaseMake):
(defun Remote>>Dyl:LayerKeyKeepColor (lay)
  (vl-some '(lambda (r) (if (and (= "1" (nth 8 r)) (= (strcase lay) (strcase (nth 1 r)))) (atoi (nth 2 r))))
           (Remote>>Dyl:LayerKeyRead)
  )
)

;;  The layer key whose layer is base (a layer name without its phase), nil when none:
(defun Remote>>Dyl:LayerKeyOfLayer (base)
  (vl-some '(lambda (r) (if (= (strcase base) (strcase (nth 1 r))) r)) (Remote>>Dyl:LayerKeyRead))
)

;;  What the layer lay should be when it is the layer of a key (base, its name without phase)
;;  in the phase code (nil: unphased): the key definition with the name lay and the color of
;;  that phase (the color of the key when it keeps it, or unphased); nil when base is not the
;;  layer of a key. To check a layer an App did not get from its key (Dyl-LayerTransfer, see
;;  Remote>>Dyl:LayerKeyCheck):
(defun Remote>>Dyl:LayerKeyExpected (lay base code / rec)
  (if (setq rec (Remote>>Dyl:LayerKeyOfLayer base))
    (Remote>>Dyl:ListSubst
      (Remote>>Dyl:ListSubst rec 1 lay)
      2
      (if (or (= "1" (nth 8 rec)) (not code)) (nth 2 rec) (itoa (Remote>>Dyl:PhaseColor (atoi (nth 2 rec)) nil code)))
    )
  )
)

;;  The key definition rec as its layer is in this drawing:the layer in the active phase
;;  while auto-phase is on, with the color of that phase (the color of the key when it keeps
;;  it):
(defun Remote>>Dyl:LayerKeyInDrawing (rec / lay)
  (if (/= (setq lay (Remote>>Dyl:LayerKeyName rec)) (nth 1 rec))
    (Remote>>Dyl:ListSubst
      (Remote>>Dyl:ListSubst rec 1 lay)
      2
      (if (= "1" (nth 8 rec)) (nth 2 rec) (itoa (Remote>>Dyl:PhaseColor (atoi (nth 2 rec)) nil (Remote>>Dyl:PhaseGet))))
    )
    rec
  )
)

;;  Layer name of a key definition: its layer, followed by the active phase while auto-phase
;;  is on (A-Detl-Thin-E):
(defun Remote>>Dyl:LayerKeyName (rec / pha)
  (if (and (Remote>>Dyl:PhaseAuto-p) (setq pha (Remote>>Dyl:PhaseGet)))
    (strcat (nth 1 rec) "-" pha)
    (nth 1 rec)
  )
)

;;  Layer lay in the active phase while auto-phase is on, created from lay (with the phase
;;  color) when missing; else lay:
(defun Remote>>Dyl:LayerKeyInPhase (lay / pha new)
  (if (and (Remote>>Dyl:PhaseAuto-p)
           (setq pha (Remote>>Dyl:PhaseGet))
           (Remote>>Dyl:PhaseMake lay (setq new (strcat lay "-" pha)) nil pha)
      )
    new
    lay
  )
)

;;  Layers of the keys (all phased), upper case (auto-phase adds the active phase to them):
(defun Remote>>Dyl:LayerKeyPhased ()
  (mapcar '(lambda (r) (strcase (nth 1 r))) (Remote>>Dyl:LayerKeyRead))
)

;;  Thaw the layer lay and turn it on when it is frozen or off, so the objects an App draws on
;;  it are seen and can be used (a frozen layer cannot be made current, and the objects on it
;;  cannot be selected: the outlines of a hatch drawn there could not be hatched). A message
;;  says what was done; the view is regenerated when it was thawed, so the objects already on
;;  it show. Returns lay:
(defun Remote>>Dyl:LayerKeyThaw (lay / doc o fx)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (if (and lay
           (tblsearch "LAYER" lay)
           (not (vl-catch-all-error-p (setq o (vl-catch-all-apply 'vla-Item (list (vla-get-Layers doc) lay)))))
      )
    (progn
      (if (and (= :vlax-true (vla-get-Freeze o))
               (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-Freeze (list o :vlax-false))))
          )
        (setq fx (list "thawed"))
      )
      (if (and (= :vlax-false (vla-get-LayerOn o))
               (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-put-LayerOn (list o :vlax-true))))
          )
        (setq fx (append fx (list "turned on")))
      )
      (if fx
        (progn
          (princ (strcat "\nLayer " lay " " (Remote>>LM:lst->str fx " and ") " to draw on it."))
          (if (and (member "thawed" fx) (not *lk:noask*)) (vl-catch-all-apply 'vla-Regen (list doc acActiveViewport)))
        )
      )
    )
  )
  lay
)

;;  Return the layer of a key, created with the key properties when the drawing does not have it.
;;  While auto-phase is on, the key gives its layer in the active phase, created with the
;;  phase color (the color of the key when it keeps it). The layer given is thawed and turned
;;  on when it is frozen or off (see Remote>>Dyl:LayerKeyThaw). A layer that exists with other
;;  properties is checked (see Remote>>Dyl:LayerKeyCheck).
;;  An undefined key uses the layer of the same name, created with the default properties.
;;  An AEC layer override as shipped (its default values) uses the layer of the layer key
;;  style of the drawing (see Remote>>Dyl:LayerKeyAecLayer), else (edited) its own layer.
;;  Returns the current layer when the layer cannot be created:
(defun Remote>>Dyl:LayerKeyLayer (key)
  (Remote>>Dyl:LayerKeyThaw (Remote>>Dyl:LayerKeyLayerOf key))
)

;;  The layer of a key, as Remote>>Dyl:LayerKeyLayer gives it (not thawed):
(defun Remote>>Dyl:LayerKeyLayerOf (key / rec lay)
  (setq rec (cond
              ((Remote>>Dyl:LayerKeyGet key))
              ((list (strcase key) key "7" "CONTINUOUS" "Default" "1" "" "0"))
            )
  )
  (cond
    ((and (Remote>>Dyl:LayerKeyAec-p rec)
          (equal rec (assoc (car rec) *lk:defaults*))
          (setq lay (Remote>>Dyl:LayerKeyAecLayer (car rec)))
     )
     (Remote>>Dyl:LayerKeyInPhase lay)
    )
    (T
      (setq rec (Remote>>Dyl:LayerKeyInDrawing rec))
      (if (not (tblsearch "LAYER" (nth 1 rec)))
        (progn
          (if (not (Remote>>Dyl:LayerKeyGet key))
            (princ (strcat "\nLayer key " key " is not defined (see Dyl-LayerKeys): layer " key " is used."))
          )
          (if (snvalid (nth 1 rec)) (Remote>>Dyl:LayerKeyMake rec))
          ;;  Made with its values: not checked again:
          (setq *lk:checked* (cons (Remote>>Dyl:LayerKeyChecked rec) *lk:checked*))
        )
        ;;  An existing layer of a defined key, checked against it:
        (if (Remote>>Dyl:LayerKeyGet key) (Remote>>Dyl:LayerKeyCheck rec))
      )
      (if (tblsearch "LAYER" (nth 1 rec)) (nth 1 rec) (getvar "CLAYER"))
     )
  )
)

;;  Put an object on the layer of a key:
(defun Remote>>Dyl:LayerKeyApply (ent key)
  (if ent
    (vl-catch-all-apply 'vla-put-Layer
                        (list (vlax-ename->vla-object ent) (Remote>>Dyl:LayerKeyLayer key))
    )
  )
)

;;  Linetypes of the .lin files of the support path and of the drawing (upper case, sorted):
(defun Remote>>Dyl:LayerKeyLinetypes (/ lst rec nam)
  (setq lst (Remote>>Dyl:SupportDefs "lin"))
  (while (setq rec (tblnext "LTYPE" (not rec)))
    (setq nam (strcase (cdr (assoc 2 rec))))
    (if (and (not (wcmatch nam "BYLAYER,BYBLOCK,*|*")) (not (member nam lst)))
      (setq lst (cons nam lst))
    )
  )
  (if (not (member "CONTINUOUS" lst)) (setq lst (cons "CONTINUOUS" lst)))
  (acad_strlsort lst)
)

;;-------------------------=={ Object layer keys }==------------------------;;

;;  Auto layer keys: the new objects of a kind (dimensions, leaders, text...) go to the layer
;;  of the layer key assigned to that kind, as the layer keys of AutoCAD Architecture do. The
;;  keys of the kinds are edited in the Object Layer Keys window (Dyl-ObjectLayerKeys, opened
;;  from Dyl-Settings too) and saved to Modules\Dynalisp\Res\ObjectLayerKeys.csv (its user
;;  copy, see Dyl:UserFile): one row per kind, its id and its key ("": none, the object stays
;;  on the current layer). The objects are moved by the reactors of
;;  Modules\Dynalisp\Reactor\Dyl-ObjectLayerKeys.lsp, while Auto layer keys is on
;;  (DynalispObjectKeys, off by default, see Dyl-Settings) and the DynALisp reactors are on.

;;  The kinds of objects: (id label types commands key): types, the entity types (wcmatch
;;  pattern of the DXF names); commands, the commands that make them (pattern, nil: any
;;  command, e.g. a revision cloud is a polyline made by REVCLOUD); key, the default key (the
;;  AEC layer keys of the AIA layer key style, see *lk:aec*). The first kind that matches an
;;  object is its kind:
(setq *olk:objects* '(("Dimension" "Dimensions" "DIMENSION,ARC_DIMENSION,LARGE_RADIAL_DIMENSION" nil "DIMLINE")
                      ("Tolerance" "Geometric tolerances" "TOLERANCE" nil "DIMLINE")
                      ("Leader" "Leaders" "LEADER" nil "ANNOBJ")
                      ("Multileader" "Multileaders" "MULTILEADER" nil "ANNOBJ")
                      ("Text" "Text" "TEXT" nil "ANNOBJ")
                      ("Mtext" "Mtext" "MTEXT" nil "ANNOBJ")
                      ("Table" "Tables" "ACAD_TABLE" nil "SCHEDOBJ")
                      ("RevisionCloud" "Revision clouds" "LWPOLYLINE,POLYLINE" "REVCLOUD" "ANNREV")
                      ("Hatch" "Hatches" "HATCH" nil "HATCH")
                      ("Wipeout" "Wipeouts" "WIPEOUT" nil "ANNMASK")
                      ("Viewport" "Viewports" "VIEWPORT" nil "VIEWPORT")
                      ("Image" "Raster images" "IMAGE" nil "")
                     )
      ;;  Module Res folder (this file loads before Dyl-Paths.lsp sets *dyl:dylres):
      *olk:file*    (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\ObjectLayerKeys.csv")
      *olk:header*  '("Object" "Key")
      ;;  Commands whose new objects are left on their layer (wcmatch pattern, with those of
      ;;  auto-phase, see Remote>>Dyl:ObjectKeysSkip): those that copy objects (a copy keeps
      ;;  the layer of its original), bring them in or rebuild them:
      *olk:skip*    (strcat "COPY,MIRROR,ARRAY*,-ARRAY*,OFFSET,ROTATE,SCALE,MOVE,STRETCH,GRIP_*,COPYCLIP,"
                            "CUTCLIP,COPYBASE,INSERT,-INSERT,CLASSICINSERT,XATTACH,XREF,-XREF,IMAGEATTACH,"
                            "BLOCK,-BLOCK,WBLOCK,ATTSYNC,BATTMAN,DIMDISASSOCIATE,DIMREASSOCIATE,DIMBREAK,"
                            "DIMSPACE,TXT2MTXT,TEXTALIGN,MLEADERCOLLECT,MLEADERALIGN,COPYM,LAYOUT,-LAYOUT,"
                            "LAYOUTWIZARD,MVSETUP,CHSPACE,MATCHPROP,PURGE,-PURGE,UNDO,U"
                    )
)

;;  The commands whose new objects are left on their layer: *olk:skip* and those of auto-phase
;;  (*ph:skip*, they edit, split or bring in objects; Remote\Dyl-LayerPhase.lsp loads after
;;  this file, so read when used):
(defun Remote>>Dyl:ObjectKeysSkip ()
  (strcat *olk:skip* (if *ph:skip* (strcat "," *ph:skip*) ""))
)

;;  The keys of the kinds by default: ((id key) ...):
(defun Remote>>Dyl:ObjectKeysDefaults ()
  (mapcar '(lambda (o) (list (car o) (nth 4 o))) *olk:objects*)
)

;;  The keys of the kinds ((id key) ...), in the order of *olk:objects*: those of
;;  ObjectLayerKeys.csv, a kind missing from it (or of an older file) its default key:
(defun Remote>>Dyl:ObjectKeysRead (/ rows r)
  (setq rows (mapcar '(lambda (x) (cons (strcase (car x)) (strcase (cadr x))))
                     (cond ((Remote>>Dyl:CsvRead (Dyl:UserFile *olk:file*) 2)) ('()))
             )
  )
  (mapcar '(lambda (o) (list (car o) (if (setq r (assoc (strcase (car o)) rows)) (cdr r) (nth 4 o))))
          *olk:objects*
  )
)

;;  Write the keys of the kinds lst (its user copy), T on success (nil if the file is open
;;  in Excel):
(defun Remote>>Dyl:ObjectKeysWrite (lst)
  (Remote>>LM:writecsv (cons *olk:header* lst) (Dyl:UserFileW *olk:file*))
)

;;  The kind of an object of the entity type typ made by the command cmd (upper case): its
;;  row of *olk:objects*, nil when it is none of them:
(defun Remote>>Dyl:ObjectKeysKind (typ cmd)
  (vl-some '(lambda (o) (if (and (wcmatch typ (nth 2 o)) (or (not (nth 3 o)) (wcmatch cmd (nth 3 o)))) o))
           *olk:objects*
  )
)

;;  T when Auto layer keys is on (user setting, off by default):
(defun Remote>>Dyl:ObjectKeysAuto-p ()
  (= "1" (getenv "DynalispObjectKeys"))
)

;;  T when Auto layer keys runs: on, and the DynALisp reactors on too (Dyl-Settings), since its
;;  reactors are in Modules\Dynalisp\Reactor\Dyl-ObjectLayerKeys.lsp:
(defun Remote>>Dyl:ObjectKeysAutoOn-p ()
  (and (Remote>>Dyl:ObjectKeysAuto-p) (Dyl:ReactorsOn-p))
)

;;  Turn Auto layer keys on or off (every drawing, from the next one made current):
(defun Remote>>Dyl:ObjectKeysAutoSet (on)
  (setenv "DynalispObjectKeys" (if on "1" "0"))
  (if Reactor>>Dyl:ObjectKeysReactors (vl-catch-all-apply 'Reactor>>Dyl:ObjectKeysReactors (list on)))
  (princ (strcat "\nAuto layer keys "
                 (if on "on" "off")
                 (if (and on (not (Dyl:ReactorsOn-p))) " (it runs once the DynALisp reactors are on, Dyl-Settings)." ".")
         )
  )
)

;;-------------------------=={ Dialog }==------------------------;;

;;  Tiles of the dialog and index of their value in a key:
(setq *lk:tiles* '(("key" . 0) ("lay" . 1) ("col" . 2) ("ltp" . 3) ("lwt" . 4) ("plt" . 5) ("dsc" . 6) ("kpc" . 8)))

;;  Write the dialog definition to a temporary DCL file and return its path:
(defun Remote>>Dyl:LayerKeyDcl (/ path file)
  (setq path (vl-filename-mktemp "lk" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("dyl_lk : dialog { label = \"DynALisp - Layer Keys\";"
      ;;  The list, one column per value (the key column fits the longest default key,
      ;;  G-DS-ANNO-STD-NON_PLOTTABLE_OBJECTS_SCREEN); its column titles: a disabled one-line
      ;;  list with the same tabs, so they line up with the list:
      ;;  Filter and sort of the list (see Remote>>Dyl:LayerKeyDlgView), over it:
      "  : column {"
      "    : row { fixed_width = true; alignment = left;"
      "      : edit_box { key = \"flt\"; label = \"Filter:\"; edit_width = 24; edit_limit = 64; }"
      "      : popup_list { key = \"srt\"; label = \"Sort by:\"; edit_width = 14; }"
      "      : text { key = \"pcn\"; width = 14; }"
      "    }"
      "    : text { key = \"lkt\"; label = \"Layer keys: double-click a key to use it (the keys are saved, as with OK).\"; }"
      "    : list_box { key = \"hdr\"; width = 164; height = 2; fixed_height = true; tabs = \"52 76 83 98 109 115 127\"; is_enabled = false; }"
      "    : list_box { key = \"lst\"; width = 164; height = 14; tabs = \"52 76 83 98 109 115 127\"; multiple_select = true; }"
      "    : row { fixed_width = true; alignment = left;"
      "      : button { key = \"new\"; label = \"New\"; width = 12; }"
      "      : button { key = \"cpy\"; label = \"Copy\"; width = 12; }"
      "      : button { key = \"del\"; label = \"Delete\"; width = 12; }"
      "      : button { key = \"rst\"; label = \"Reset key\"; width = 12; }"
      "      : button { key = \"all\"; label = \"Restore defaults\"; }"
      "    }"
      "  }"
      ;;  The values of the key shown, under the list, in two columns divided by a vertical
      ;;  line. Its heading gives the status of the key (the longest label first, so the
      ;;  others have room, see Remote>>Dyl:LayerKeyDlgState):
      "  : boxed_column { key = \"lbx\"; label = \"Parameters (AEC layer override, modified)\";"
      "    : row {"
      "      : column {"
      "        : edit_box { key = \"key\"; label = \"Key:\"; edit_width = 32; edit_limit = 64; }"
      "        : edit_box { key = \"lay\"; label = \"Layer name:\"; edit_width = 32; edit_limit = 255; }"
      "        : edit_box { key = \"dsc\"; label = \"Description:\"; edit_width = 32; edit_limit = 255; }"
      "        : spacer { }"
      "      }"
      "      : image { key = \"vln\"; width = 2; height = 1; fixed_width = true; color = -15; }"
      "      : column {"
      "        : row {"
      "          : edit_box { key = \"col\"; label = \"Color (1-255):\"; edit_width = 6; }"
      "          : image_button { key = \"sw\"; width = 8; height = 1.4; fixed_width = true; fixed_height = true; }"
      "        }"
      "        : popup_list { key = \"ltp\"; label = \"Linetype:\"; edit_width = 32; }"
      "        : popup_list { key = \"lwt\"; label = \"Lineweight:\"; edit_width = 12; }"
      "        : toggle { key = \"plt\"; label = \"Plot\"; }"
      ;;  Its layer keeps this color in every phase (see Remote>>Dyl:LayerKeyKeepColor):
      "        : toggle { key = \"kpc\"; label = \"Keep this color in every phase\"; }"
      "        : spacer { }"
      "      }"
      "    }"
      "    : text { key = \"drw\"; width = 120; }"
      "  }"
      ;;  Greyed out note under the box, for an AEC layer override:
      "  : paragraph {"
      "    : text_part { key = \"aec1\"; width = 120; is_enabled = false; }"
      "    : text_part { key = \"aec2\"; width = 120; is_enabled = false; }"
      "  }"
      "  : row { fixed_width = true; alignment = right;"
      "    : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 12; fixed_width = true; }"
      "    : button { key = \"cancel\"; label = \"Cancel\"; is_cancel = true; width = 12; fixed_width = true; }"
      "    : button { key = \"docs\"; label = \"Open Docs\"; width = 12; fixed_width = true; }"
      "  }"
      "  errtile;"
      "}"
      "dyl_lk_ask : dialog { label = \"DynALisp - Layer Keys\";"
      "  : text { key = \"msg\"; width = 72; }"
      "  ok_cancel;"
      "}"
     )
    (write-line line file)
  )
  (close file)
  path
)

;;  The functions below run inside Remote>>Dyl:LayerKeyDialog and use its local variables:
;;  lk:lst (keys being edited), lk:idx (index of the selected key), lk:dcl (dialog id),
;;  lk:ltps (linetypes of the Linetype popup), lk:found (linetypes found in the .lin files or the drawing).

;;  Several keys can be selected in the list (Ctrl / Shift click) and edited at once (see
;;  CONVENTIONS.md, Windows): lk:sel (indexes of the keys selected, lk:idx included). The
;;  fields show the key lk:idx; a value changed is given to every key selected (see
;;  Remote>>Dyl:LayerKeyDlgPut); the key name and Copy are for one key only; Delete and Reset
;;  key act on all of them.

;;  Indexes of the keys selected, the one shown (lk:idx) included:
(defun Remote>>Dyl:LayerKeyDlgSel ()
  (if (member lk:idx lk:sel) lk:sel (list lk:idx))
)

;;  Give the value val to the column i of every key selected (lk:one T, see
;;  Remote>>Dyl:LayerKeyDlgCommit: to the key shown only):
(defun Remote>>Dyl:LayerKeyDlgPut (i val)
  (foreach j (if lk:one (list lk:idx) (Remote>>Dyl:LayerKeyDlgSel))
    (setq lk:lst (Remote>>Dyl:ListSubst lk:lst j (Remote>>Dyl:ListSubst (nth j lk:lst) i val)))
  )
)

;;-------------------------=={ Sort and filter }==------------------------;;

;;  The list shows lk:view: the indexes in lk:lst of the keys listed, in their order.
;;  lk:flt: the filter text (the keys with it in any of their values, any case; "": every
;;  key), lk:srt: the sort (an item of *lk:sorts*, "Key" by default, kept for the session in
;;  *lk:sort*). The key shown (lk:idx) is always listed, so the fields shown are those of a
;;  line of the list.
(setq *lk:sorts* '("Key" "Layer" "Color" "Linetype" "Lineweight" "Description" "Status"))

;;  Status of the key r, for the Status sort: custom, then modified, then AEC layer
;;  overrides, then the default keys as shipped:
(defun Remote>>Dyl:LayerKeyDlgRank (r / d)
  (setq d (assoc (car r) *lk:defaults*))
  (cond
    ((not d) "1")
    ((not (equal r d)) "2")
    ((Remote>>Dyl:LayerKeyAec-p r) "3")
    ("4")
  )
)

;;  Sort key of the key at index i (see lk:srt), in upper case, the key last:
(defun Remote>>Dyl:LayerKeyDlgKey (i / r)
  (setq r (nth i lk:lst))
  (strcase
    (strcat
      (cond
        ((= "Layer" lk:srt) (nth 1 r))
        ((= "Color" lk:srt) (substr (strcat "00" (nth 2 r)) (strlen (nth 2 r))))
        ((= "Linetype" lk:srt) (nth 3 r))
        ;;  "Default" first, then the lineweights ("0.25": all of the same length):
        ((= "Lineweight" lk:srt) (if (= "Default" (nth 4 r)) "" (nth 4 r)))
        ((= "Description" lk:srt) (nth 6 r))
        ((= "Status" lk:srt) (Remote>>Dyl:LayerKeyDlgRank r))
        ("")
      )
      "\t"
      (car r)
    )
  )
)

;;  T when the key at index a is listed before the one at index b:
(defun Remote>>Dyl:LayerKeyDlgBefore (a b / ka kb)
  (setq ka (Remote>>Dyl:LayerKeyDlgKey a)
        kb (Remote>>Dyl:LayerKeyDlgKey b)
  )
  (if (= ka kb) (< a b) (< ka kb))
)

;;  Indexes of the keys to list: those of the filter, and the key shown when pin is T, in
;;  the order of the sort:
(defun Remote>>Dyl:LayerKeyDlgView (pin / f i lst)
  (setq f (strcase (vl-string-trim " " (cond (lk:flt) (""))))
        i -1
  )
  (foreach r lk:lst
    (setq i (1+ i))
    (if (or (and pin (= i lk:idx))
            (= "" f)
            (vl-string-search f (strcase (Remote>>Dyl:LayerKeyDlgLine r)))
        )
      (setq lst (cons i lst))
    )
  )
  (vl-sort (reverse lst) 'Remote>>Dyl:LayerKeyDlgBefore)
)

;;  Lines of the list of the keys selected, "0 3 5" ("": not listed):
(defun Remote>>Dyl:LayerKeyDlgPos (/ l)
  (setq l (vl-remove nil (mapcar '(lambda (i) (vl-position i lk:view)) (Remote>>Dyl:LayerKeyDlgSel))))
  (if l (Remote>>LM:lst->str (mapcar 'itoa (vl-sort l '<)) " ") "")
)

;;  Filter typed: the keys of the filter listed, the key shown kept when it has the text,
;;  else the first one that has it:
(defun Remote>>Dyl:LayerKeyDlgFilter (val / m)
  (if (Remote>>Dyl:LayerKeyDlgCommit)
    (progn
      (setq lk:flt val
            m      (Remote>>Dyl:LayerKeyDlgView nil)
      )
      (if (and m (not (member lk:idx m))) (setq lk:idx (car m)))
      (setq lk:sel (list lk:idx))
      (Remote>>Dyl:LayerKeyDlgShow)
    )
    (set_tile "flt" (cond (lk:flt) ("")))
  )
)

;;  Sort picked, kept for the session:
(defun Remote>>Dyl:LayerKeyDlgSort (val)
  (setq lk:srt  (cond ((nth (atoi val) *lk:sorts*)) ("Key"))
        *lk:sort* lk:srt
  )
  (Remote>>Dyl:LayerKeyDlgList)
)

;;  T when another key than the one at index skip is already named key:
(defun Remote>>Dyl:LayerKeyTaken-p (key skip / n)
  (setq n -1)
  (vl-some '(lambda (r) (and (/= skip (setq n (1+ n))) (= (strcase key) (car r)))) lk:lst)
)

;;  Return key, followed by "-2", "-3"... when it is already taken:
(defun Remote>>Dyl:LayerKeyUnique (key / i new)
  (setq i   1
        new key
  )
  (while (Remote>>Dyl:LayerKeyTaken-p new nil)
    (setq new (strcat key "-" (itoa (setq i (1+ i)))))
  )
  new
)

;;  Ask a yes / no question in a sub-dialog, returns T on OK:
(defun Remote>>Dyl:LayerKeyDlgAsk (msg)
  (if (new_dialog "dyl_lk_ask" lk:dcl)
    (progn
      (set_tile "msg" msg)
      (= 1 (start_dialog))
    )
  )
)

;;  Popup tiles -> list of their values (nil for the other tiles):
(defun Remote>>Dyl:LayerKeyDlgItems (key)
  (cond
    ((= "ltp" key) lk:ltps)
    ((= "lwt" key) *lk:weights*)
  )
)

;;  Line of the list of a key: one column per value (see the column titles, "hdr"):
(defun Remote>>Dyl:LayerKeyDlgLine (r)
  (strcat (car r)
          "\t"
          (nth 1 r)
          "\t"
          (nth 2 r)
          "\t"
          (nth 3 r)
          "\t"
          (if (= "Default" (nth 4 r)) "Default" (strcat (nth 4 r) " mm"))
          "\t"
          (if (= "1" (nth 5 r)) "Yes" "No")
          "\t"
          (if (= "1" (nth 8 r)) "Same color" "Phase color")
          "\t"
          (nth 6 r)
  )
)

;;  Fill the key list with the keys of the filter, in the order of the sort, and their count:
(defun Remote>>Dyl:LayerKeyDlgList (/ n)
  (setq lk:view (Remote>>Dyl:LayerKeyDlgView T))
  (start_list "lst")
  (foreach i lk:view (add_list (Remote>>Dyl:LayerKeyDlgLine (nth i lk:lst))))
  (end_list)
  (set_tile "lst" (Remote>>Dyl:LayerKeyDlgPos))
  (setq n (length (Remote>>Dyl:LayerKeyDlgView nil)))
  (set_tile "pcn"
            (cond
              ((= "" (vl-string-trim " " (cond (lk:flt) ("")))) (strcat (itoa (length lk:lst)) " keys"))
              ((= 0 n) "No match")
              ((strcat (itoa n) " of " (itoa (length lk:lst))))
            )
  )
)

;;  Paint the color swatch:
(defun Remote>>Dyl:LayerKeyDlgSwatch (aci)
  (start_image "sw")
  (fill_image 0 0 (dimx_tile "sw") (dimy_tile "sw") aci)
  (end_image)
)

;;  Refresh the list, the key status, the swatch and the state of the buttons. The key of a
;;  default key is locked; for an AEC layer override, a greyed out note under the values says
;;  where its layer comes from:
(defun Remote>>Dyl:LayerKeyDlgState (/ r d aec sel)
  (setq r   (nth lk:idx lk:lst)
        d   (assoc (car r) *lk:defaults*)
        aec (Remote>>Dyl:LayerKeyAec-p r)
        sel (mapcar '(lambda (j) (nth j lk:lst)) (Remote>>Dyl:LayerKeyDlgSel))
  )
  (Remote>>Dyl:LayerKeyDlgList)
  ;;  The heading gives the number of keys selected, or the status of the key shown (nothing
  ;;  for a default key as shipped):
  (set_tile "lbx"
            (cond
              ((cdr sel) (strcat "Parameters (" (itoa (length sel)) " selected)"))
              ((and aec (equal r d)) "Parameters (AEC layer override)")
              (aec "Parameters (AEC layer override, modified)")
              ((not d) "Parameters (custom)")
              ((equal r d) "Parameters")
              ("Parameters (modified)")
            )
  )
  ;;  The layer in this drawing (in the active phase): missing, the same, or what differs:
  (setq d (Remote>>Dyl:LayerKeyDiffs (Remote>>Dyl:LayerKeyInDrawing r)))
  (set_tile "drw"
            (strcat
              (if (/= (Remote>>Dyl:LayerKeyName r) (nth 1 r)) (strcat "Active phase: " (Remote>>Dyl:LayerKeyName r) " ") "The layer ")
              (cond
                ((not (tblsearch "LAYER" (Remote>>Dyl:LayerKeyName r))) "is missing in this drawing: it is created with these values when used.")
                (d (strcat "differs in this drawing (" (Remote>>LM:lst->str d "; ") "): updating it is offered when it is used."))
                ("exists in this drawing with these values.")
              )
            )
  )
  (setq d (assoc (car r) *lk:defaults*))
  ;;  The key name and Copy for one key only; Reset key: a modified default key selected;
  ;;  Delete: custom keys only:
  (mode_tile "key" (if (or d (cdr sel)) 1 0))
  (mode_tile "cpy" (if (cdr sel) 1 0))
  (mode_tile "rst"
             (if (vl-some '(lambda (x / y) (and (setq y (assoc (car x) *lk:defaults*)) (not (equal x y)))) sel) 0 1)
  )
  (mode_tile "del" (if (vl-some '(lambda (x) (assoc (car x) *lk:defaults*)) sel) 1 0))
  (Remote>>Dyl:LayerKeyDlgSwatch (atoi (nth 2 r)))
  (mapcar '(lambda (k s) (set_tile k (if aec s "")))
          '("aec1" "aec2")
          '("AEC layer override: AIA (256 Color) values, key locked."
            "As shipped, in AutoCAD Architecture it follows the layer key style of the drawing; edited, its own values are used."
           )
  )
)

;;  Show the values of the selected key:
(defun Remote>>Dyl:LayerKeyDlgShow (/ r items)
  (setq r (nth lk:idx lk:lst))
  (foreach x *lk:tiles*
    (set_tile (car x)
              (if (setq items (Remote>>Dyl:LayerKeyDlgItems (car x)))
                (itoa (cond ((vl-position (nth (cdr x) r) items)) (0)))
                (nth (cdr x) r)
              )
    )
  )
  (set_tile "error" "")
  (Remote>>Dyl:LayerKeyDlgState)
)

;;  Validate the value of a tile and store it in the selected key, returns T when valid:
(defun Remote>>Dyl:LayerKeyDlgField (key val / i items msg)
  ;;  The popups return the index of the value in their list:
  (if (setq items (Remote>>Dyl:LayerKeyDlgItems key))
    (setq val (cond ((nth (atoi val) items)) ("")))
  )
  (setq i   (cdr (assoc key *lk:tiles*))
        val (vl-string-trim " \t" val)
  )
  (if (member key '("key" "ltp")) (setq val (strcase val)))
  (setq msg (cond
              ((and (= "key" key) (= "" val)) "The key cannot be empty.")
              ((and (= "key" key) (not (snvalid val))) "The key contains characters that are not allowed.")
              ((and (= "key" key) (Remote>>Dyl:LayerKeyTaken-p val lk:idx))
               (strcat "Another layer key is already named \"" val "\".")
              )
              ((and (= "lay" key) (= "" val)) "The layer name cannot be empty.")
              ((and (= "lay" key) (not (snvalid val))) "The layer name contains characters that are not allowed.")
              ((and (= "col" key) (not (and (wcmatch val "#,##,###") (<= 1 (atoi val) 255))))
               "The color must be a number from 1 to 255."
              )
            )
  )
  (if msg
    (progn
      (set_tile "error" msg)
      (mode_tile key 2)
      nil
    )
    (progn
      (if (= "col" key) (setq val (itoa (atoi val))))
      ;;  To every key selected (the key shown only for the key name, and while committing):
      (if (= "key" key)
        (setq lk:lst (Remote>>Dyl:ListSubst lk:lst lk:idx (Remote>>Dyl:ListSubst (nth lk:idx lk:lst) i val)))
        (Remote>>Dyl:LayerKeyDlgPut i val)
      )
      (if (not items) (set_tile key val))
      (set_tile "error" "")
      t
    )
  )
)

;;  Store every tile in the key shown, returns T when they are all valid. Only in the key
;;  shown (lk:one): a value changed was given to every key selected by the action of its tile:
(defun Remote>>Dyl:LayerKeyDlgCommit (/ ok lk:one)
  (setq lk:one t
        ok     t
  )
  (foreach x *lk:tiles*
    (if ok (setq ok (Remote>>Dyl:LayerKeyDlgField (car x) (get_tile (car x)))))
  )
  ok
)

;;  Select other keys (the current one must be valid first): lines val of the list ("3" or
;;  "0 3 5"). The key shown stays when it is still selected, else the first one selected.
;;  Opened to pick a key (lk:pick, see Remote>>Dyl:LayerKeyPick), a double-click (reason 4)
;;  on a key closes the dialog as OK does, with that key picked (lk:picked):
(defun Remote>>Dyl:LayerKeyDlgPick (val reason / l)
  (setq l (vl-remove nil (mapcar '(lambda (n) (nth n lk:view)) (read (strcat "(" (cond (val) ("")) ")")))))
  (if (and l (Remote>>Dyl:LayerKeyDlgCommit))
    (progn
      (setq lk:sel l
            lk:idx (if (member lk:idx l) lk:idx (car l))
      )
      (Remote>>Dyl:LayerKeyDlgShow)
      (if (and lk:pick (= 4 reason))
        (if (Remote>>Dyl:LayerKeyMaterial-p (car (nth lk:idx lk:lst)))
          (progn
            (setq lk:picked (car (nth lk:idx lk:lst)))
            (done_dialog 1)
          )
          (set_tile "error" "This key is kept for compatibility only: it cannot be given to a hatch preset or a border.")
        )
      )
    )
    (set_tile "lst" (Remote>>Dyl:LayerKeyDlgPos))
  )
)

;;  Pick the color in the AutoCAD color dialog:
(defun Remote>>Dyl:LayerKeyDlgColor (/ aci)
  (if (setq aci (acad_colordlg (max 1 (atoi (get_tile "col"))) nil))
    (progn
      (set_tile "col" (itoa aci))
      (if (Remote>>Dyl:LayerKeyDlgField "col" (itoa aci)) (Remote>>Dyl:LayerKeyDlgState))
    )
  )
)

;;  Add a custom key after the selected one and select its name:
(defun Remote>>Dyl:LayerKeyDlgAdd (rec)
  (if (Remote>>Dyl:LayerKeyDlgCommit)
    (progn
      (setq lk:idx (1+ lk:idx)
            lk:lst (Remote>>Dyl:ListInsert lk:lst lk:idx (cons (Remote>>Dyl:LayerKeyUnique (car rec)) (cdr rec)))
            lk:sel (list lk:idx)
      )
      (Remote>>Dyl:LayerKeyDlgShow)
      (mode_tile "key" 2)
      (mode_tile "key" 3)
    )
  )
)

;;  New: custom key with the default layer properties:
(defun Remote>>Dyl:LayerKeyDlgNew ()
  (Remote>>Dyl:LayerKeyDlgAdd (list "NEWKEY" "NewLayer" "7" "CONTINUOUS" "Default" "1" "" "0" "0"))
)

;;  Copy: custom key with the values of the selected key:
(defun Remote>>Dyl:LayerKeyDlgCopy (/ r)
  (setq r (nth lk:idx lk:lst))
  (Remote>>Dyl:LayerKeyDlgAdd (Remote>>Dyl:ListSubst (cons (strcat (car r) "-COPY") (cdr r)) 7 "0"))
)

;;  Delete the custom keys selected:
(defun Remote>>Dyl:LayerKeyDlgDelete (/ sel i)
  (setq sel (Remote>>Dyl:LayerKeyDlgSel))
  (if
    (Remote>>Dyl:LayerKeyDlgAsk
      (if (cdr sel)
        (strcat "Delete the " (itoa (length sel)) " custom layer keys selected? Their layers are not deleted.")
        (strcat "Delete the custom layer key \"" (car (nth lk:idx lk:lst)) "\"? Its layer is not deleted.")
      )
    )
    (progn
      (setq i      -1
            lk:lst (vl-remove-if '(lambda (r) (member (setq i (1+ i)) sel)) lk:lst)
            lk:idx (min (apply 'min sel) (1- (length lk:lst)))
            lk:sel (list lk:idx)
      )
      (Remote>>Dyl:LayerKeyDlgShow)
    )
  )
)

;;  Reset the default keys selected to their default values (the custom ones are left as
;;  they are):
(defun Remote>>Dyl:LayerKeyDlgReset (/ d)
  (foreach j (Remote>>Dyl:LayerKeyDlgSel)
    (if (setq d (assoc (car (nth j lk:lst)) *lk:defaults*)) (setq lk:lst (Remote>>Dyl:ListSubst lk:lst j d)))
  )
  (Remote>>Dyl:LayerKeyDlgShow)
)

;;  Reset every default key to its default values (custom keys are kept):
(defun Remote>>Dyl:LayerKeyDlgRestore ()
  (if
    (Remote>>Dyl:LayerKeyDlgAsk
      "Reset every default layer key to its default values? Custom keys are kept."
    )
    (progn
      (setq lk:lst (mapcar '(lambda (r) (cond ((assoc (car r) *lk:defaults*)) (r))) lk:lst))
      (Remote>>Dyl:LayerKeyDlgShow)
    )
  )
)

;;  Show the Layer Keys dialog, with the key sel selected first (nil: first key).
;;  OK writes LayerKeys.csv. Returns T when the keys were saved:
(defun Remote>>Dyl:LayerKeyDialog (sel / dcl:pth dcl:sta lk:dcl lk:lst lk:idx lk:sel lk:view lk:flt lk:srt lk:ltps
                                     lk:found err
                                  )
  (setq dcl:pth (Remote>>Dyl:LayerKeyDcl)
        lk:dcl  (load_dialog dcl:pth)
  )
  ;;  Any error closes the dialog cleanly and is reported on the command line:
  (setq err (vl-catch-all-apply 'Remote>>Dyl:LayerKeyDlgRun (list sel)))
  (if (vl-catch-all-error-p err)
    (progn
      (term_dialog)
      (setq dcl:sta nil)
      (princ (strcat "\nLayer Keys dialog error: " (vl-catch-all-error-message err)))
    )
  )
  (if (>= lk:dcl 0) (unload_dialog lk:dcl))
  (vl-file-delete dcl:pth)
  (cond
    ((/= 1 dcl:sta) nil)
    ;;  Saved: the layers of the keys are checked again against the keys as saved:
    ((Remote>>Dyl:LayerKeyWrite lk:lst) (setq *lk:checked* nil) T)
    ((alert (strcat "\nError: the layer keys could not be saved to\n" (Dyl:UserFileW *lk:file*) "\n(is it open in Excel?)")))
  )
)

;;  Show the Layer Keys dialog to pick a key (from the Materials window), on the key sel: the
;;  same dialog, where a double-click on a key also saves the keys and closes it (see
;;  Remote>>Dyl:LayerKeyDlgPick). Returns the key double-clicked once saved, nil on OK or
;;  Cancel:
(defun Remote>>Dyl:LayerKeyPick (sel / lk:pick lk:picked)
  (setq lk:pick t)
  (if (Remote>>Dyl:LayerKeyDialog sel) lk:picked)
)

;;  Body of Remote>>Dyl:LayerKeyDialog (uses its local variables), sets dcl:sta:
(defun Remote>>Dyl:LayerKeyDlgRun (sel)
  (setq lk:lst   (Remote>>Dyl:LayerKeyRead)
        lk:idx   (cond
                   ((vl-position (assoc (strcase (cond (sel) (""))) lk:lst) lk:lst))
                   (0)
                 )
        lk:sel   (list lk:idx)
        lk:flt   ""
        lk:srt   (if (member *lk:sort* *lk:sorts*) *lk:sort* "Key")
        lk:found (Remote>>Dyl:LayerKeyLinetypes)
        lk:ltps  lk:found
  )
  ;;  The linetypes used by the keys stay selectable even when they are not found:
  (foreach r (append *lk:defaults* lk:lst)
    (if (not (member (nth 3 r) lk:ltps)) (setq lk:ltps (cons (nth 3 r) lk:ltps)))
  )
  (setq lk:ltps (acad_strlsort lk:ltps))
  (if (and (>= lk:dcl 0) (new_dialog "dyl_lk" lk:dcl))
    (progn
      (Dyl:LineTile "vln")
      (start_list "srt")
      (foreach s *lk:sorts* (add_list s))
      (end_list)
      (set_tile "srt" (itoa (vl-position lk:srt *lk:sorts*)))
      (set_tile "flt" lk:flt)
      (action_tile "flt" "(Remote>>Dyl:LayerKeyDlgFilter $value)")
      (action_tile "srt" "(Remote>>Dyl:LayerKeyDlgSort $value)")
      (start_list "hdr")
      (add_list "Key\tLayer\tColor\tLinetype\tLineweight\tPlot\tIn phases\tDescription")
      (end_list)
      (start_list "ltp")
      (foreach x lk:ltps (add_list (if (member x lk:found) x (strcat x "   (not found)"))))
      (end_list)
      (start_list "lwt")
      (foreach x *lk:weights* (add_list (if (= "Default" x) x (strcat x " mm"))))
      (end_list)
      (Remote>>Dyl:LayerKeyDlgShow)
      (foreach x *lk:tiles*
        (action_tile (car x) "(if (Remote>>Dyl:LayerKeyDlgField $key $value) (Remote>>Dyl:LayerKeyDlgState))")
      )
      (set_tile "lkt" (if lk:pick "Layer keys: double-click a key to use it (the keys are saved, as with OK)." "Layer keys:"))
      (action_tile "lst" "(Remote>>Dyl:LayerKeyDlgPick $value $reason)")
      (action_tile "sw" "(Remote>>Dyl:LayerKeyDlgColor)")
      (action_tile "new" "(Remote>>Dyl:LayerKeyDlgNew)")
      (action_tile "cpy" "(Remote>>Dyl:LayerKeyDlgCopy)")
      (action_tile "del" "(Remote>>Dyl:LayerKeyDlgDelete)")
      (action_tile "rst" "(Remote>>Dyl:LayerKeyDlgReset)")
      (action_tile "all" "(Remote>>Dyl:LayerKeyDlgRestore)")
      (action_tile "accept" "(if (Remote>>Dyl:LayerKeyDlgCommit) (done_dialog 1))")
      (Dyl:DocsTile "Layer\\Dyl-LayerKeys.htm")
      (setq dcl:sta (start_dialog))
    )
    (alert "\nError: Layer Keys dialog could not be loaded")
  )
)

(princ)
