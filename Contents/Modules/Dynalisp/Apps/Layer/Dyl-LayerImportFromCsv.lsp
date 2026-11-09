;; LayerImportFromCsv - Applies layer properties from CSV presets
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

;; ============================================================
;; IMPORT-LAYERS-FROM-CSV  (Dedicated preset commands)
;;
;; Each command loads a named CSV from the same folder as this
;; LSP, applies all layer properties to matching layers, then
;; manages a named Layer State in the drawing.
;;
;; COMMANDS:
;;   A-FLOR  - Architectural Floor Plan
;;   A-CEIL  - Architectural Ceiling Plan
;;   A-ROOF  - Architectural Roof Plan
;;   I-FURN  - Interior Furnishing Plan
;;   I-FNSH - Interior Finish Plan
;;   L-PLNT  - Landscape Plantings Identification Plan
;;   C-FLOR  - Civil Property Plan
;;   S-FLOR  - Structural Floor Plan
;;   E-FLOR  - Electrical Floor Plan
;;   P-FLOR  - Plumbing Floor Plan
;;   M-FLOR  - Mechanical Floor Plan
;;   IMPORTLAYERS - Browse for any CSV (no layer state)
;;
;; Preset CSV files must live in the same folder as this LSP.
;; CSV format matches the EXPORTLAYERS companion routine:
;;   Layer Name,Color,Lineweight,Linetype,Plot,Transparency,
;;   On/Off,Freeze,New VP Freeze,Description
;; ============================================================


;; ==================================================================
;; CAPTURE LSP FOLDER AT LOAD TIME
;; ==================================================================
(setq *il-lsp-folder* (cond 
                        ((findfile "import_layers_from_csv.lsp")
                         (strcat 
                           (vl-filename-directory 
                             (findfile "import_layers_from_csv.lsp")
                           )
                           "\\"
                         )
                        )
                        (T (getvar "DWGPREFIX"))
                      )
)


;; ==================================================================
;; SHARED UTILITIES
;; ==================================================================

;; Trim leading/trailing whitespace and CR/LF
(defun il:trim (s) 
  (while 
    (and (> (strlen s) 0) 
         (member (ascii (substr s 1 1)) '(32 9 13 10))
    )
    (setq s (substr s 2))
  )
  (while 
    (and (> (strlen s) 0) 
         (member (ascii (substr s (strlen s) 1)) '(32 9 13 10))
    )
    (setq s (substr s 1 (1- (strlen s))))
  )
  s
)

;; Strip UTF-8 BOM from first line
(defun il:strip-bom (s) 
  (while 
    (and (> (strlen s) 0) 
         (member (ascii (substr s 1 1)) '(239 187 191 65279))
    )
    (setq s (substr s 2))
  )
  s
)

;; Split a CSV line into a list of strings, handles quoted fields
(defun il:csv-split (line / fields ch i len in-quote field) 
  (setq fields   '()
        field    ""
        in-quote nil
        i        0
        len      (strlen line)
  )
  (while (<= (setq i (1+ i)) len) 
    (setq ch (substr line i 1))
    (cond 
      (in-quote
       (cond 
         ((and (= ch "\"") (< i len) (= (substr line (+ i 1) 1) "\""))
          (setq field (strcat field "\"")
                i     (1+ i)
          )
         )
         ((= ch "\"") (setq in-quote nil))
         (T (setq field (strcat field ch)))
       )
      )
      (T
       (cond 
         ((= ch "\"") (setq in-quote T))
         ((= ch ",")
          (setq fields (append fields (list field))
                field  ""
          )
         )
         (T (setq field (strcat field ch)))
       )
      )
    )
  )
  (append fields (list field))
)

;; Parse color string -> ACI integer
(defun il:parse-color (cs / uc ns) 
  (setq uc (strcase (il:trim cs)))
  (cond 
    ((= uc "BYLAYER") 256)
    ((= uc "BYBLOCK") 0)
    ((= uc "RED (1)") 1)
    ((= uc "YELLOW (2)") 2)
    ((= uc "GREEN (3)") 3)
    ((= uc "CYAN (4)") 4)
    ((= uc "BLUE (5)") 5)
    ((= uc "MAGENTA (6)") 6)
    ((= uc "WHITE/BLACK (7)") 7)
    ((wcmatch uc "ACI *")
     (setq ns (il:trim (substr cs 5)))
     (if (> (strlen ns) 0) (atoi ns) nil)
    )
    (T (if (> (strlen (il:trim cs)) 0) (atoi (il:trim cs)) nil))
  )
)

;; Parse lineweight string -> AutoCAD lw integer (hundredths mm)
(defun il:parse-lw (lws / uc ms mv) 
  (setq uc (strcase (il:trim lws)))
  (cond 
    ((= uc "BYLAYER") -3)
    ((= uc "BYBLOCK") -2)
    ((= uc "DEFAULT") -3)
    ((wcmatch uc "*.* MM")
     (setq ms (il:trim (vl-string-subst "" " MM" uc)))
     (fix (+ (* (atof ms) 100) 0.5))
    )
    (T (if (> (strlen (il:trim lws)) 0) (atoi (il:trim lws)) -3))
  )
)

;; Parse transparency string -> integer 0-90
(defun il:parse-trans (ts / c) 
  (setq c (il:trim ts))
  (if (= (substr c (strlen c) 1) "%") 
    (setq c (substr c 1 (1- (strlen c))))
  )
  (atoi (il:trim c))
)

;; Return linetype VLA object or nil
(defun il:find-lt (nm doc / r) 
  (setq r nil)
  (vlax-for lt (vla-get-Linetypes doc) 
    (if (= (strcase (vla-get-Name lt)) (strcase nm)) (setq r lt))
  )
  r
)

;; Try to load linetype from acad.lin / acadiso.lin
(defun il:load-lt (nm doc / sp lf ok) 
  (setq ok nil)
  (foreach lf '("acad.lin" "acadiso.lin") 
    (if (not ok) 
      (progn 
        (setq sp (findfile lf))
        (if sp 
          (progn 
            (vl-catch-all-apply 'vla-Load 
                                (list (vla-get-Linetypes doc) nm sp)
            )
            (if (il:find-lt nm doc) (setq ok T))
          )
        )
      )
    )
  )
  ok
)

;; Split a string on a single-char delimiter, return list
(defun il:split-str (s delim / parts cur i ch) 
  (setq parts '()
        cur   ""
        i     0
  )
  (while (<= (setq i (1+ i)) (strlen s)) 
    (setq ch (substr s i 1))
    (if (= ch delim) 
      (progn (setq parts (append parts (list cur))) (setq cur ""))
      (setq cur (strcat cur ch))
    )
  )
  (append parts (list cur))
)

;; Check if a named layer state exists in the drawing
(defun il:state-exists-p (sname doc / lsm names ok err)
  (setq ok nil)
  (setq err
    (vl-catch-all-apply
      '(lambda ()
         ;; Correct API: LayerStateManager is a property of the document
         (setq lsm (vla-get-LayerStateManager doc))
         (setq names (vla-GetLayerStateNames lsm))
         (if (and names (> (strlen names) 0))
           (foreach n (il:split-str names (chr 10))
             (if (= (strcase (il:trim n)) (strcase sname))
               (setq ok T)
             )
           )
         )
       )
      nil
    )
  )
  ok
)

;; Restore a named layer state
(defun il:state-restore (sname doc / lsm err)
  (setq err
    (vl-catch-all-apply
      '(lambda ()
         (setq lsm (vla-get-LayerStateManager doc))
         ;; Flag 8191 = restore all layer properties
         (vla-RestoreLayerState lsm sname 8191 "")
       )
      nil
    )
  )
  (if (vl-catch-all-error-p err)
    (princ (strcat "\nERROR restoring state \"" sname "\": "
                   (vl-catch-all-error-message err)))
    (princ (strcat "\nLayer state \"" sname "\" restored."))
  )
)

;; Save (or overwrite) a named layer state from current layer settings
(defun il:state-save (sname doc / lsm err)
  (setq err
    (vl-catch-all-apply
      '(lambda ()
         (setq lsm (vla-get-LayerStateManager doc))
         ;; Delete existing state with same name if present (ignore error if absent)
         (vl-catch-all-apply 'vla-Delete (list lsm sname))
         ;; Save all layer properties into the new state
         ;; 8191 = acLsAll: color, lineweight, linetype, plot, on/off,
         ;;        freeze, lock, transparency, vp properties, description
         (vla-Save lsm sname 8191)
       )
      nil
    )
  )
  (if (vl-catch-all-error-p err)
    (princ (strcat "\nERROR saving state \"" sname "\": "
                   (vl-catch-all-error-message err)))
    (princ (strcat "\nLayer state \"" sname "\" saved."))
  )
)

;; Ask user: use existing state or import new CSV?
;; Uses plain command-line prompt (no DCL) for reliability
(defun il:ask-conflict (sname / ans) 
  (princ (strcat "\nLayer state \"" sname "\" already exists in this drawing."))
  (princ "\n  [U] Use existing layer state")
  (princ "\n  [I] Import CSV and update layer state")
  (princ "\n  [C] Cancel")
  (setq ans (il:trim (strcase (getstring "\nChoose [U/I/C]: "))))
  (cond 
    ((= ans "U") "USE-EXISTING")
    ((= ans "I") "IMPORT-NEW")
    (T "CANCEL")
  )
)


;; ==================================================================
;; CORE ENGINE: apply a CSV file to the current drawing layers
;; Returns number of layers updated.
;; ==================================================================
(defun il:apply-csv (csv-path / file-handle raw-line rows header-skipped col-list layer-name color-str lw-str lt-str 
                     plot-str trans-str on-str freeze-str vpfreeze-str desc-str doc layers layer-obj aci-val lw-val 
                     trans-val plot-val on-val freeze-val vpfreeze-val lt-obj updated missing skipped log
                    ) 

  (setq file-handle    (open csv-path "r")
        rows           '()
        header-skipped nil
  )
  (if (null file-handle) 
    (progn (princ (strcat "\nERROR: Cannot open: " csv-path)) (exit))
  )

  ;; Read all rows
  (while (setq raw-line (read-line file-handle)) 
    (if (= (substr raw-line (strlen raw-line) 1) (chr 13)) 
      (setq raw-line (substr raw-line 1 (1- (strlen raw-line))))
    )
    (if (not header-skipped) (setq raw-line (il:strip-bom raw-line)))
    (if (> (strlen (il:trim raw-line)) 0) 
      (progn 
        (setq col-list (il:csv-split raw-line))
        (if (not header-skipped) 
          (if (wcmatch (strcase (il:trim (car col-list))) "LAYER NAME*") 
            (setq header-skipped T)
            (progn (setq header-skipped T) (setq rows (cons col-list rows)))
          )
          (setq rows (cons col-list rows))
        )
      )
    )
  )
  (close file-handle)
  (setq rows (reverse rows))
  (princ (strcat "\n  Parsed " (itoa (length rows)) " row(s) from CSV."))

  ;; Apply to layers
  (setq doc     (vla-get-ActiveDocument (vlax-get-acad-object))
        layers  (vla-get-Layers doc)
        updated 0
        missing 0
        skipped 0
        log     '()
  )

  (foreach row rows 
    (while (< (length row) 10) (setq row (append row (list ""))))
    (setq layer-name   (il:trim (nth 0 row))
          color-str    (il:trim (nth 1 row))
          lw-str       (il:trim (nth 2 row))
          lt-str       (il:trim (nth 3 row))
          plot-str     (il:trim (nth 4 row))
          trans-str    (il:trim (nth 5 row))
          on-str       (il:trim (nth 6 row))
          freeze-str   (il:trim (nth 7 row))
          vpfreeze-str (il:trim (nth 8 row))
          desc-str     (il:trim (nth 9 row))
    )

    (if (= (strlen layer-name) 0) 
      (setq skipped (1+ skipped))
      (progn 
        (setq layer-obj nil)
        (vlax-for lyr layers 
          (if (= (strcase (vla-get-Name lyr)) (strcase layer-name)) 
            (setq layer-obj lyr)
          )
        )
        (if (null layer-obj) 
          (progn 
            (setq missing (1+ missing))
            (setq log (cons (strcat "MISSING: " layer-name) log))
          )
          (progn 
            (setq aci-val (il:parse-color color-str))
            (if aci-val 
              (vl-catch-all-apply 'vla-put-Color (list layer-obj aci-val))
            )
            (setq lw-val (il:parse-lw lw-str))
            (if lw-val 
              (vl-catch-all-apply 'vla-put-Lineweight (list layer-obj lw-val))
            )
            (if 
              (and (> (strlen lt-str) 0) 
                   (not (= (strcase lt-str) "CONTINUOUS"))
              )
              (progn 
                (setq lt-obj (il:find-lt lt-str doc))
                (if (null lt-obj) 
                  (if (il:load-lt lt-str doc) 
                    (setq lt-obj (il:find-lt lt-str doc))
                    (setq log (cons (strcat "LT NOT FOUND: " lt-str " (" layer-name ")") log))
                  )
                )
                (if lt-obj 
                  (vl-catch-all-apply 'vla-put-Linetype (list layer-obj lt-str))
                )
              )
              (if (> (strlen lt-str) 0) 
                (vl-catch-all-apply 'vla-put-Linetype (list layer-obj "Continuous"))
              )
            )
            (setq plot-val (if (= (strcase plot-str) "YES") :vlax-true :vlax-false))
            (vl-catch-all-apply 'vla-put-Plottable (list layer-obj plot-val))
            (setq trans-val (il:parse-trans trans-str))
            (if (vlax-property-available-p layer-obj 'LayerTransparency) 
              (vl-catch-all-apply 'vla-put-LayerTransparency (list layer-obj trans-val))
            )
            (setq on-val (if (= (strcase on-str) "ON") :vlax-true :vlax-false))
            (if (vlax-property-available-p layer-obj 'LayerOn) 
              (vl-catch-all-apply 'vla-put-LayerOn (list layer-obj on-val))
            )
            (setq freeze-val (if (= (strcase freeze-str) "FROZEN") :vlax-true :vlax-false))
            (if (vlax-property-available-p layer-obj 'Freeze) 
              (vl-catch-all-apply 'vla-put-Freeze (list layer-obj freeze-val))
            )
            (setq vpfreeze-val (if (= (strcase vpfreeze-str) "VP FROZEN") :vlax-true :vlax-false))
            (if (vlax-property-available-p layer-obj 'ViewportDefault) 
              (vl-catch-all-apply 'vla-put-ViewportDefault (list layer-obj vpfreeze-val))
            )
            (if (vlax-property-available-p layer-obj 'Description) 
              (vl-catch-all-apply 'vla-put-Description (list layer-obj desc-str))
            )
            (setq updated (1+ updated))
          )
        )
      )
    )
  )

  (princ (strcat "\n  Updated : " (itoa updated) " layer(s)"))
  (princ (strcat "\n  Missing : " (itoa missing) " layer(s) not in drawing"))
  (if log 
    (progn (princ "\n  Notes:") 
           (foreach ln (reverse log) (princ (strcat "\n    " ln)))
    )
  )
  updated
)


;; ==================================================================
;; MASTER DISPATCHER
;; Called by every preset command with its specific parameters.
;; csv-file   - filename only (must be in *il-lsp-folder*)
;; state-name - AutoCAD layer state name (nil = no state management)
;; disp-label - human-readable label for command-line messages
;; ==================================================================
(defun il:run-preset (csv-file state-name disp-label / csv-path doc decision) 

  (princ (strcat "\n--- " disp-label " ---"))

  ;; Resolve full CSV path
  (setq csv-path (strcat *il-lsp-folder* csv-file))
  (if (not (findfile csv-path)) 
    (progn 
      (princ (strcat "\nWARNING: Preset CSV not found:\n  " csv-path))
      (princ "\nFalling back to file browser...")
      (setq csv-path (getfiled "Select Layer CSV File" *il-lsp-folder* "csv" 4))
      (if (null csv-path) (progn (princ "\nCancelled.") (exit)))
    )
  )

  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))

  (if (null state-name) 
    ;; No layer state management - just apply CSV
    (progn 
      (il:apply-csv csv-path)
      (vla-Regen doc acAllViewports)
      (princ "\n--- Done ---")
    )
    ;; Layer state management
    (progn 
      (if (il:state-exists-p state-name doc) 
        ;; State already exists - ask user
        (progn 
          (setq decision (il:ask-conflict state-name))
          (cond 
            ((= decision "USE-EXISTING")
             (il:state-restore state-name doc)
             (vla-Regen doc acAllViewports)
             (princ 
               (strcat "\n--- Done: Applied existing state \"" 
                       state-name
                       "\" ---"
               )
             )
            )
            ((= decision "IMPORT-NEW")
             (princ "\n  Importing CSV...")
             (il:apply-csv csv-path)
             (vla-Regen doc acAllViewports)
             (il:state-save state-name doc)
             (princ 
               (strcat "\n--- Done: Layers updated, state \"" 
                       state-name
                       "\" overwritten ---"
               )
             )
            )
            (T (princ "\nCancelled."))
          )
        )
        ;; State does not exist - apply CSV and create state
        (progn 
          (il:apply-csv csv-path)
          (vla-Regen doc acAllViewports)
          (il:state-save state-name doc)
          (princ 
            (strcat "\n--- Done: Layers applied, state \"" 
                    state-name
                    "\" created ---"
            )
          )
        )
      )
    )
  )
  (princ)
)


;; ==================================================================
;; PRESET COMMANDS
;; ==================================================================

;; --- ARCHITECTURAL ---

;; Architectural Floor Plan Layers
;; Imports the architectural floor plan layers from their preset CSV and saves a layer state.

(defun c:Pst-ArchitecturalFloorPlanLayers () (il:run-preset "preset_arch_floor.csv" "ARCH-FLOOR" "Architectural - Floor Plan"))

;; Architectural Ceiling Plan Layers
;; Imports the architectural ceiling plan layers from their preset CSV and saves a layer state.

(defun c:Pst-ArchitecturalCeilingPlanLayers () (il:run-preset "preset_arch_ceiling.csv" "ARCH-CEILING" "Architectural - Ceiling Plan"))

;; Architectural Roof Plan Layers
;; Imports the architectural roof plan layers from their preset CSV and saves a layer state.

(defun c:Pst-ArchitecturalRoofPlanLayers () (il:run-preset "preset_arch_roof.csv" "ARCH-ROOF" "Architectural - Roof Plan"))

;; --- INTERIOR ---

;; Interior Furnishing Plan Layers
;; Imports the interior furnishing plan layers from their preset CSV and saves a layer state.

(defun c:Pst-InteriorFurnishingPlanLayers () (il:run-preset "preset_int_furnish.csv" "INT-FURNISH" "Interior - Furnishing Plan"))

;; Interior Finish Plan Layers
;; Imports the interior finish plan layers from their preset CSV and saves a layer state.

(defun c:Pst-InteriorFinishPlanLayers () (il:run-preset "preset_int_finish.csv" "INT-FINISH" "Interior - Finish Plan"))

;; --- LANDSCAPE ---

;; Landscape Plantings Plan Layers
;; Imports the landscape plantings plan layers from their preset CSV and saves a layer state.

(defun c:Pst-LandscapePlantingsPlanLayers () (il:run-preset "preset_landscape.csv" "LANDSCAPE" "Landscape Plantings Identification Plan"))

;; --- CIVIL ---

;; Civil Property Plan Layers
;; Imports the civil property plan layers from their preset CSV and saves a layer state.

(defun c:Pst-CivilPropertyPlanLayers () (il:run-preset "preset_civil.csv" "CIVIL" "Civil Property Plan"))

;; --- STRUCTURAL ---

;; Structural Floor Plan Layers
;; Imports the structural floor plan layers from their preset CSV and saves a layer state.

(defun c:Pst-StructuralFloorPlanLayers () (il:run-preset "preset_structural.csv" "STRUCTURAL" "Structural Floor Plan"))

;; --- ELECTRICAL ---

;; Electrical Floor Plan Layers
;; Imports the electrical floor plan layers from their preset CSV and saves a layer state.

(defun c:Pst-ElectricalFloorPlanLayers () (il:run-preset "preset_electrical.csv" "ELECTRICAL" "Electrical Floor Plan"))

;; --- PLUMBING ---

;; Plumbing Floor Plan Layers
;; Imports the plumbing floor plan layers from their preset CSV and saves a layer state.

(defun c:Pst-PlumbingFloorPlanLayers () (il:run-preset "preset_plumbing.csv" "PLUMBING" "Plumbing Floor Plan"))

;; --- MECHANICAL ---

;; Mechanical Floor Plan Layers
;; Imports the mechanical floor plan layers from their preset CSV and saves a layer state.

(defun c:Pst-MechanicalFloorPlanLayers () (il:run-preset "preset_mechanical.csv" "MECHANICAL" "Mechanical Floor Plan"))

;; --- BROWSE (no layer state) ---

;; Import Layers From CSV
;; Imports layers from a browsed CSV file without saving a layer state.

(defun c:Dyl-LayerImportFromCsv (/ csv-path) 
  (princ "\n--- Import Layers from CSV (Browse) ---")
  (setq csv-path (getfiled "Select Layer CSV File" 
                           (cond 
                             ((getenv "USERPROFILE")
                              (strcat (getenv "USERPROFILE") "\\Downloads\\")
                             )
                             (T *il-lsp-folder*)
                           )
                           "csv"
                           4
                 )
  )
  (if (null csv-path) 
    (princ "\nCancelled.")
    (progn 
      (il:apply-csv csv-path)
      (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) acAllViewports)
      (princ "\n--- Done ---")
    )
  )
  (princ)
)


;; ==================================================================
;; LOAD MESSAGE
;; ==================================================================
(princ "\n=== IMPORT-LAYERS-FROM-CSV loaded ===")
(princ (strcat "\n  Preset folder : " *il-lsp-folder*))
(princ "\n  Commands:")
(princ "\n    A-FLOR   Architectural Floor Plan")
(princ "\n    A-CEIL   Architectural Ceiling Plan")
(princ "\n    A-ROOF   Architectural Roof Plan")
(princ "\n    I-FURN   Interior Furnishing Plan")
(princ "\n    I-FNSH   Interior Finish Plan")
(princ "\n    L-PLNT   Landscape Plantings Identification Plan")
(princ "\n    C-PROP   Civil Property Plan")
(princ "\n    S-FLOR   Structural Floor Plan")
(princ "\n    E-FLOR   Electrical Floor Plan")
(princ "\n    P-FLOR   Plumbing Floor Plan")
(princ "\n    M-FLOR   Mechanical Floor Plan")
(princ "\n    IMPORTLAYERS  Browse for any CSV")
(princ)
