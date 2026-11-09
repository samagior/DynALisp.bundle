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
;;  does not have it (an existing layer is used as is, never modified).
;;
;;  The keys are saved to Modules\Dynalisp\Res\LayerKeys.csv and edited with the Layer Keys
;;  dialog (Remote>>Dyl:LayerKeyDialog, command Dyl-LayerKeys). Default keys can be
;;  edited and reset, not renamed or deleted; custom keys can be added freely.
;;
;;  A key is a list of strings:
;;  (key layer color linetype lineweight plot description phased)
;;  color: ACI 1-255, lineweight: "Default" or millimetres ("0.25"), plot and phased: "1" or "0".
;;
;;  While auto-phase is on, a phased key gives its layer in the active phase of the drawing
;;  (see Dyl-LayerPhase.lsp): THIN -> A-Detl-Thin-E in existing, A-Detl-Thin when auto-phase is
;;  off or the drawing has no active phase. Auto-phase also moves the objects created on the
;;  layer of a phased key to the active phase.
;;
;;  Use in an App:
;;    (Remote>>Dyl:LayerKeyLayer "THIN")         -> layer name, created if missing
;;    (Remote>>Dyl:LayerKeyApply (entlast) "THIN") -> puts an object on that layer


;;  Default keys, restored by the Reset key and Restore defaults buttons:
(setq *lk:defaults* '(("FINE" "A-Detl-Fine" "1" "CONTINUOUS" "0.18" "1" "Detail: Fine Lines" "1")
                      ("THIN" "A-Detl-Thin" "2" "CONTINUOUS" "0.25" "1" "Detail: Thin Lines" "1")
                      ("MED" "A-Detl-Medm" "3" "CONTINUOUS" "0.35" "1" "Detail: Medium Lines" "1")
                      ("WIDE" "A-Detl-Wide" "4" "CONTINUOUS" "0.50" "1" "Detail: Wide Lines" "1")
                      ("XLINE" "A-Detl-XFin" "8" "CONTINUOUS" "0.13" "1" "Detail: Extra Fine Lines" "1")
                      ("HATCH" "A-Detl-Patt" "8" "CONTINUOUS" "0.18" "1" "Detail: Texture Or Hatch Patterns" "1")
                      ("G-DS-ANNO-STD-BACKGROUND_SCREEN" "A-Detl-Scrn" "254" "CONTINUOUS" "0.18" "1"
                       "Detail: Screening Of Coordination Objects And Backgrounds" "0"
                      )
                     )
      ;;  Module Res folder (this file loads before Dyl-Paths.lsp sets *dyl:dylres):
      *lk:file*     (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\LayerKeys.csv")
      *lk:header*   '("Key" "Layer" "Color" "Linetype" "Lineweight" "Plot" "Description" "Phased")
      *lk:weights*  '("Default" "0.00" "0.05" "0.09" "0.13" "0.15" "0.18" "0.20" "0.25" "0.30" "0.35" "0.40"
                      "0.50" "0.53" "0.60" "0.70" "0.80" "0.90" "1.00" "1.06" "1.20" "1.40" "1.58" "2.00" "2.11"
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

;;  Clean a row read from LayerKeys.csv, returns nil when the key or the layer is not valid:
(defun Remote>>Dyl:LayerKeyFix (row / aci)
  (setq aci (atoi (nth 2 row)))
  (if (and (/= "" (car row)) (snvalid (car row)) (/= "" (nth 1 row)) (snvalid (nth 1 row)))
    (list (strcase (car row))
          (nth 1 row)
          (itoa (if (<= 1 aci 255) aci 7))
          (if (= "" (nth 3 row)) "CONTINUOUS" (strcase (nth 3 row)))
          (Remote>>Dyl:LayerKeyWeight (nth 4 row))
          (if (= "0" (nth 5 row)) "0" "1")
          (nth 6 row)
          (if (= "0" (nth 7 row)) "0" "1")
    )
  )
)

;;  Read LayerKeys.csv. Default keys missing from the file are added with their default values:
(defun Remote>>Dyl:LayerKeyRead (/ row lst)
  (foreach x (Remote>>Dyl:CsvRead (Dyl:UserFile *lk:file*) 8)
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

;;  Return the definition of a key, or nil when it is not defined:
(defun Remote>>Dyl:LayerKeyGet (key)
  (assoc (strcase key) (Remote>>Dyl:LayerKeyRead))
)

;;  Create the layer of a key definition with its properties (the linetype is loaded from
;;  acad.lin / acadiso.lin when needed, Continuous is kept when it cannot be loaded):
(defun Remote>>Dyl:LayerKeyMake (rec / doc lin lay)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        lin (findfile (if (= 1 (getvar "MEASUREMENT")) "acadiso.lin" "acad.lin"))
  )
  (if (and lin (not (tblsearch "LTYPE" (nth 3 rec))))
    (vl-catch-all-apply 'vla-Load (list (vla-get-Linetypes doc) (nth 3 rec) lin))
  )
  (if
    (not
      (vl-catch-all-error-p
        (setq lay (vl-catch-all-apply 'vla-Add (list (vla-get-Layers doc) (nth 1 rec))))
      )
    )
    (progn
      (vla-put-Color lay (atoi (nth 2 rec)))
      (if (tblsearch "LTYPE" (nth 3 rec)) (vla-put-Linetype lay (nth 3 rec)))
      (vla-put-Lineweight lay
                          (if (= "Default" (nth 4 rec))
                            acLnWtByLwDefault
                            (fix (+ 0.5 (* 100 (distof (nth 4 rec) 2))))
                          )
      )
      (vla-put-Plottable lay (if (= "1" (nth 5 rec)) :vlax-true :vlax-false))
      (vla-put-Description lay (nth 6 rec))
      (princ (strcat "\nLayer created: " (nth 1 rec) " (layer key " (car rec) ")"))
    )
  )
)

;;  Layer name of a key definition: its layer, followed by the active phase for a phased key
;;  while auto-phase is on (A-Detl-Thin-E):
(defun Remote>>Dyl:LayerKeyName (rec / pha)
  (if (and (= "1" (nth 7 rec)) (Remote>>Dyl:PhaseAuto-p) (setq pha (Remote>>Dyl:PhaseGet)))
    (strcat (nth 1 rec) "-" pha)
    (nth 1 rec)
  )
)

;;  Layers of the phased keys, upper case (auto-phase adds the active phase to them):
(defun Remote>>Dyl:LayerKeyPhased ()
  (mapcar '(lambda (r) (strcase (nth 1 r)))
          (vl-remove-if-not '(lambda (r) (= "1" (nth 7 r))) (Remote>>Dyl:LayerKeyRead))
  )
)

;;  Return the layer of a key, created with the key properties when the drawing does not have it.
;;  A phased key gives its layer in the active phase while auto-phase is on, created with the
;;  phase color.
;;  An undefined key uses the layer of the same name, created with the default properties.
;;  Returns the current layer when the layer cannot be created:
(defun Remote>>Dyl:LayerKeyLayer (key / rec lay)
  (setq rec (cond
              ((Remote>>Dyl:LayerKeyGet key))
              ((list (strcase key) key "7" "CONTINUOUS" "Default" "1" "" "0"))
            )
  )
  (if (/= (setq lay (Remote>>Dyl:LayerKeyName rec)) (nth 1 rec))
    (setq rec (Remote>>Dyl:ListSubst
                (Remote>>Dyl:ListSubst rec 1 lay)
                2
                (itoa (Remote>>Dyl:PhaseColor (atoi (nth 2 rec)) nil (Remote>>Dyl:PhaseGet)))
              )
    )
  )
  (if (not (tblsearch "LAYER" (nth 1 rec)))
    (progn
      (if (not (Remote>>Dyl:LayerKeyGet key))
        (princ (strcat "\nLayer key " key " is not defined (see Dyl-LayerKeys): layer " key " is used."))
      )
      (if (snvalid (nth 1 rec)) (Remote>>Dyl:LayerKeyMake rec))
    )
  )
  (if (tblsearch "LAYER" (nth 1 rec)) (nth 1 rec) (getvar "CLAYER"))
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

;;-------------------------=={ Dialog }==------------------------;;

;;  Tiles of the dialog and index of their value in a key:
(setq *lk:tiles* '(("key" . 0) ("lay" . 1) ("col" . 2) ("ltp" . 3) ("lwt" . 4) ("plt" . 5) ("dsc" . 6) ("phs" . 7)))

;;  Write the dialog definition to a temporary DCL file and return its path:
(defun Remote>>Dyl:LayerKeyDcl (/ path file)
  (setq path (vl-filename-mktemp "lk" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("dyl_lk : dialog { label = \"DynALisp - Layer Keys\";"
      "  : row {"
      "    : column {"
      "      : list_box { label = \"Layer keys:\"; key = \"lst\"; width = 66; height = 18; tabs = \"18 50\"; }"
      "      : row {"
      "        : button { key = \"new\"; label = \"New\"; }"
      "        : button { key = \"cpy\"; label = \"Copy\"; }"
      "        : button { key = \"del\"; label = \"Delete\"; }"
      "      }"
      "      : row {"
      "        : button { key = \"rst\"; label = \"Reset key\"; }"
      "        : button { key = \"all\"; label = \"Restore defaults\"; }"
      "      }"
      "    }"
      "    : boxed_column { label = \"Layer\";"
      "      : edit_box { key = \"key\"; label = \"Key:\"; edit_width = 32; edit_limit = 64; }"
      "      : edit_box { key = \"lay\"; label = \"Layer name:\"; edit_width = 32; edit_limit = 255; }"
      "      : edit_box { key = \"dsc\"; label = \"Description:\"; edit_width = 32; edit_limit = 255; }"
      "      spacer;"
      "      : row {"
      "        : edit_box { key = \"col\"; label = \"Color (1-255):\"; edit_width = 6; }"
      "        : image_button { key = \"sw\"; width = 8; height = 1.4; fixed_width = true; fixed_height = true; }"
      "      }"
      "      : popup_list { key = \"ltp\"; label = \"Linetype:\"; edit_width = 32; }"
      "      : popup_list { key = \"lwt\"; label = \"Lineweight:\"; edit_width = 12; }"
      "      : toggle { key = \"plt\"; label = \"Plot\"; }"
      "      : toggle { key = \"phs\"; label = \"Phased: with auto-phase on, the active phase is added (Layer-E)\"; }"
      "      spacer;"
      "      : text { key = \"src\"; width = 60; }"
      "      : text { key = \"drw\"; width = 60; }"
      "      : text { label = \"Click the color swatch to pick a color.\"; }"
      "    }"
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

;;  Fill the key list:
(defun Remote>>Dyl:LayerKeyDlgList (/ d)
  (start_list "lst")
  (foreach r lk:lst
    (setq d (assoc (car r) *lk:defaults*))
    (add_list
      (strcat (car r)
              "\t"
              (nth 1 r)
              (if (= "1" (nth 7 r)) "-[phase]" "")
              "\t"
              (cond
                ((not d) "custom")
                ((equal r d) "")
                ("modified")
              )
      )
    )
  )
  (end_list)
  (set_tile "lst" (itoa lk:idx))
)

;;  Paint the color swatch:
(defun Remote>>Dyl:LayerKeyDlgSwatch (aci)
  (start_image "sw")
  (fill_image 0 0 (dimx_tile "sw") (dimy_tile "sw") aci)
  (end_image)
)

;;  Refresh the list, the key status, the swatch and the state of the buttons:
(defun Remote>>Dyl:LayerKeyDlgState (/ r d)
  (setq r (nth lk:idx lk:lst)
        d (assoc (car r) *lk:defaults*)
  )
  (Remote>>Dyl:LayerKeyDlgList)
  (set_tile "src"
            (cond
              ((not d) "Custom layer key")
              ((equal r d) "Default layer key")
              ("Default layer key (modified)")
            )
  )
  (set_tile "drw"
            (cond
              ((/= (Remote>>Dyl:LayerKeyName r) (nth 1 r))
               (strcat "Active phase: " (Remote>>Dyl:LayerKeyName r)
                       (if (tblsearch "LAYER" (Remote>>Dyl:LayerKeyName r))
                         " exists, it is used as is."
                         " is missing, it is created when used."
                       )
               )
              )
              ((tblsearch "LAYER" (nth 1 r)) "The layer exists in this drawing: it is used as is.")
              ("The layer is missing in this drawing: it is created with these values when used.")
            )
  )
  (mode_tile "key" (if d 1 0))
  (mode_tile "rst" (if (and d (not (equal r d))) 0 1))
  (mode_tile "del" (if d 1 0))
  (Remote>>Dyl:LayerKeyDlgSwatch (atoi (nth 2 r)))
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
      (setq lk:lst (Remote>>Dyl:ListSubst lk:lst lk:idx (Remote>>Dyl:ListSubst (nth lk:idx lk:lst) i val)))
      (if (not items) (set_tile key val))
      (set_tile "error" "")
      t
    )
  )
)

;;  Store every tile in the selected key, returns T when they are all valid:
(defun Remote>>Dyl:LayerKeyDlgCommit (/ ok)
  (setq ok t)
  (foreach x *lk:tiles*
    (if ok (setq ok (Remote>>Dyl:LayerKeyDlgField (car x) (get_tile (car x)))))
  )
  ok
)

;;  Select another key (the current one must be valid first):
(defun Remote>>Dyl:LayerKeyDlgPick (val)
  (if (Remote>>Dyl:LayerKeyDlgCommit)
    (progn
      (setq lk:idx (atoi val))
      (Remote>>Dyl:LayerKeyDlgShow)
    )
    (set_tile "lst" (itoa lk:idx))
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
      )
      (Remote>>Dyl:LayerKeyDlgShow)
      (mode_tile "key" 2)
      (mode_tile "key" 3)
    )
  )
)

;;  New: custom key with the default layer properties:
(defun Remote>>Dyl:LayerKeyDlgNew ()
  (Remote>>Dyl:LayerKeyDlgAdd (list "NEWKEY" "NewLayer" "7" "CONTINUOUS" "Default" "1" "" "1"))
)

;;  Copy: custom key with the values of the selected key:
(defun Remote>>Dyl:LayerKeyDlgCopy (/ r)
  (setq r (nth lk:idx lk:lst))
  (Remote>>Dyl:LayerKeyDlgAdd (cons (strcat (car r) "-COPY") (cdr r)))
)

;;  Delete the selected custom key:
(defun Remote>>Dyl:LayerKeyDlgDelete ()
  (if
    (Remote>>Dyl:LayerKeyDlgAsk
      (strcat "Delete the custom layer key \"" (car (nth lk:idx lk:lst)) "\"? Its layer is not deleted.")
    )
    (progn
      (setq lk:lst (Remote>>Dyl:ListRemove lk:lst lk:idx)
            lk:idx (min lk:idx (1- (length lk:lst)))
      )
      (Remote>>Dyl:LayerKeyDlgShow)
    )
  )
)

;;  Reset the selected default key to its default values:
(defun Remote>>Dyl:LayerKeyDlgReset ()
  (setq lk:lst (Remote>>Dyl:ListSubst lk:lst lk:idx (assoc (car (nth lk:idx lk:lst)) *lk:defaults*)))
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
(defun Remote>>Dyl:LayerKeyDialog (sel / dcl:pth dcl:sta lk:dcl lk:lst lk:idx lk:ltps lk:found err)
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
    ((Remote>>Dyl:LayerKeyWrite lk:lst))
    ((alert (strcat "\nError: the layer keys could not be saved to\n" (Dyl:UserFileW *lk:file*) "\n(is it open in Excel?)")))
  )
)

;;  Body of Remote>>Dyl:LayerKeyDialog (uses its local variables), sets dcl:sta:
(defun Remote>>Dyl:LayerKeyDlgRun (sel)
  (setq lk:lst   (Remote>>Dyl:LayerKeyRead)
        lk:idx   (cond
                   ((vl-position (assoc (strcase (cond (sel) (""))) lk:lst) lk:lst))
                   (0)
                 )
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
      (action_tile "lst" "(Remote>>Dyl:LayerKeyDlgPick $value)")
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
