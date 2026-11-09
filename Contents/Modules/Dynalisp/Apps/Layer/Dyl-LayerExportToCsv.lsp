;; LayerExportToCsv - Exports the layers of the current drawing to a CSV file
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
;; EXPORT-LAYERS-TO-CSV
;; Reads all layers in the current drawing and exports:
;;   Layer Name, Color, Lineweight, Linetype, Plot, Transparency,
;;   On/Off, Freeze/Thaw, New VP Freeze, Description
;; Output: CSV file in the user's Windows Downloads folder
;; Usage: Load the file, then type EXPORTLAYERS at the command prompt
;; ============================================================

;; Export Layers To CSV
;; Exports every layer of the drawing with its properties to a CSV file in the Downloads folder.

(defun C:Dyl-EXPORTLAYERS (/ *error* doc layers layer-obj i layer-name layer-color layer-lw layer-lt layer-plot 
                           layer-trans layer-desc layer-on layer-freeze layer-vpfreeze layer-list row csv-path 
                           file-handle lw-val lw-str color-val color-str trans-val trans-str plot-val plot-str on-val 
                           on-str freeze-val freeze-str vpfreeze-val vpfreeze-str username downloads-path
                          ) 

  ;; ---- Error handler ----
  (defun *error* (msg) 
    (if file-handle (close file-handle))
    (if (and msg (not (wcmatch (strcase msg) "*CANCEL*,*EXIT*"))) 
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  ;; ---- Helper: convert AutoCAD lineweight integer to readable string ----
  (defun lw->string (lw) 
    (cond 
      ((= lw -3) "Default")
      ((= lw -2) "ByBlock")
      ((= lw -1) "ByLayer")
      ((= lw 0) "0.00 mm")
      ((= lw 5) "0.05 mm")
      ((= lw 9) "0.09 mm")
      ((= lw 13) "0.13 mm")
      ((= lw 15) "0.15 mm")
      ((= lw 18) "0.18 mm")
      ((= lw 20) "0.20 mm")
      ((= lw 25) "0.25 mm")
      ((= lw 30) "0.30 mm")
      ((= lw 35) "0.35 mm")
      ((= lw 40) "0.40 mm")
      ((= lw 50) "0.50 mm")
      ((= lw 53) "0.53 mm")
      ((= lw 60) "0.60 mm")
      ((= lw 70) "0.70 mm")
      ((= lw 80) "0.80 mm")
      ((= lw 90) "0.90 mm")
      ((= lw 100) "1.00 mm")
      ((= lw 106) "1.06 mm")
      ((= lw 120) "1.20 mm")
      ((= lw 140) "1.40 mm")
      ((= lw 158) "1.58 mm")
      ((= lw 200) "2.00 mm")
      ((= lw 211) "2.11 mm")
      (T (strcat (itoa lw) " (raw)"))
    )
  )

  ;; ---- Helper: convert ACI color index to readable string ----
  (defun color->string (col) 
    (cond 
      ((= col 0) "ByBlock")
      ((= col 256) "ByLayer")
      ((= col 1) "Red (1)")
      ((= col 2) "Yellow (2)")
      ((= col 3) "Green (3)")
      ((= col 4) "Cyan (4)")
      ((= col 5) "Blue (5)")
      ((= col 6) "Magenta (6)")
      ((= col 7) "White/Black (7)")
      (T (strcat "ACI " (itoa col)))
    )
  )

  ;; ---- Helper: escape a string for CSV (wrap in quotes if needed) ----
  (defun csv-escape (s) 
    (if 
      (or (vl-string-search "," s) 
          (vl-string-search "\"" s)
          (vl-string-search (chr 10) s)
      )
      (strcat "\"" (vl-string-subst "\"\"" "\"" s) "\"")
      s
    )
  )

  ;; ---- Resolve Windows Downloads folder path ----
  ;; Try environment variables in order of preference
  (setq username (getenv "USERNAME"))
  (setq downloads-path (cond 
                         ;; USERPROFILE gives C:\Users\<name>
                         ((getenv "USERPROFILE")
                          (strcat (getenv "USERPROFILE") "\\Downloads\\")
                         )
                         ;; Fallback: construct from HOMEDRIVE + HOMEPATH
                         ((and (getenv "HOMEDRIVE") (getenv "HOMEPATH"))
                          (strcat (getenv "HOMEDRIVE") (getenv "HOMEPATH") "\\Downloads\\")
                         )
                         ;; Last resort: current drawing folder
                         (T (getvar "DWGPREFIX"))
                       )
  )

  ;; Build full CSV file path with timestamp to avoid overwriting
  ;; CDATE returns a real number in YYYYMMDD.HHMMSSmmm format - convert to string first
  (setq csv-path (strcat downloads-path 
                         "layers_"
                         (substr (rtos (getvar "CDATE") 2 0) 1 8)
                         ".csv"
                 )
  )

  (princ (strcat "\nExporting layers to: " csv-path))

  ;; ---- Collect layer data ----
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq layers (vla-get-Layers doc))
  (setq layer-list '())

  (vlax-for layer-obj layers 
    (setq layer-name (vla-get-Name layer-obj))
    (setq color-val (vla-get-color layer-obj))
    (setq lw-val (vla-get-Lineweight layer-obj))
    (setq layer-lt (vla-get-Linetype layer-obj))
    (setq plot-val (vla-get-Plottable layer-obj))

    ;; Transparency (0-90). Property may not exist in older AutoCAD
    (setq trans-val (if (vlax-property-available-p layer-obj 'LayerTransparency) 
                      (vla-get-LayerTransparency layer-obj)
                      0
                    )
    )

    ;; Description - available in AutoCAD 2016+
    (setq layer-desc (if (vlax-property-available-p layer-obj 'Description) 
                       (vla-get-Description layer-obj)
                       ""
                     )
    )

    ;; On/Off state (:vlax-true = On, :vlax-false = Off)
    (setq on-val (if (vlax-property-available-p layer-obj 'LayerOn) 
                   (vla-get-LayerOn layer-obj)
                   :vlax-true
                 )
    )

    ;; Freeze/Thaw (:vlax-true = Frozen, :vlax-false = Thawed)
    (setq freeze-val (if (vlax-property-available-p layer-obj 'Freeze) 
                       (vla-get-Freeze layer-obj)
                       :vlax-false
                     )
    )

    ;; New Viewport Freeze - ViewportDefault (:vlax-true = frozen in new VPs)
    (setq vpfreeze-val (if (vlax-property-available-p layer-obj 'ViewportDefault) 
                         (vla-get-ViewportDefault layer-obj)
                         :vlax-false
                       )
    )

    ;; Convert raw values to readable strings
    (setq color-str (color->string color-val))
    (setq lw-str (lw->string lw-val))
    (setq plot-str (if (= plot-val :vlax-true) "Yes" "No"))
    (setq trans-str (strcat (itoa (fix trans-val)) "%"))
    (setq on-str (if (= on-val :vlax-true) "On" "Off"))
    (setq freeze-str (if (= freeze-val :vlax-true) "Frozen" "Thawed"))
    (setq vpfreeze-str (if (= vpfreeze-val :vlax-true) "VP Frozen" "VP Thawed"))

    ;; Build one row as a list of strings
    (setq row (list layer-name color-str lw-str layer-lt plot-str trans-str on-str freeze-str vpfreeze-str layer-desc))

    ;; Accumulate
    (setq layer-list (cons row layer-list))
  )

  ;; Sort by layer name
  (setq layer-list (vl-sort layer-list 
                            '(lambda (a b) (< (strcase (car a)) (strcase (car b))))
                   )
  )

  ;; ---- Write CSV file ----
  (setq file-handle (open csv-path "w"))

  (if (null file-handle) 
    (progn 
      (princ (strcat "\nERROR: Cannot write to " csv-path))
      (princ "\nPlease check that the Downloads folder exists and is writable.")
      (exit)
    )
  )

  ;; Write BOM for Excel UTF-8 compatibility + header row
  (write-line 
    (strcat (chr 239) 
            (chr 187)
            (chr 191)
            "Layer Name,Color,Lineweight,Linetype,Plot,Transparency,On/Off,Freeze,New VP Freeze,Description"
    )
    file-handle
  )

  ;; Write each layer row
  (foreach row layer-list 
    (write-line 
      (apply 'strcat 
             (list 
               (csv-escape (nth 0 row))
               ","
               (csv-escape (nth 1 row))
               ","
               (csv-escape (nth 2 row))
               ","
               (csv-escape (nth 3 row))
               ","
               (csv-escape (nth 4 row))
               ","
               (csv-escape (nth 5 row))
               ","
               (csv-escape (nth 6 row))
               ","
               (csv-escape (nth 7 row))
               ","
               (csv-escape (nth 8 row))
               ","
               (csv-escape (nth 9 row))
             )
      )
      file-handle
    )
  )

  (close file-handle)
  (setq file-handle nil)

  (princ (strcat "\nDone! " (itoa (length layer-list)) " layer(s) exported to:"))
  (princ (strcat "\n" csv-path))
  (princ "\nOpen the file in Excel or any CSV viewer.")
  (princ)
)

;; ---- Auto-load message ----
(princ "\nEXPORT-LAYERS-TO-CSV loaded. Type EXPORTLAYERS to run.")
(princ)
