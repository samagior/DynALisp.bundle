;; Dyl-ObjectLayerKeys - Assign a layer key to the new objects of each kind (dimensions, leaders, text...)
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

;;  The kinds of objects, their keys (ObjectLayerKeys.csv) and the Auto layer keys setting are
;;  in Modules\Dynalisp\Remote\Dyl-LayerKey.lsp (Object layer keys); the reactors that move
;;  the new objects in Modules\Dynalisp\Reactor\Dyl-ObjectLayerKeys.lsp.

;;-------------------------=={ Object Layer Keys window }==------------------------;;

;;  The functions below run inside Dyl:ObjectKeysDialog and use its local variables: ol:lst
;;  (the keys of the kinds being edited, ((id key) ...) in the order of *olk:objects*), ol:sel
;;  (the indexes of the kinds selected), ol:keys (the keys of the Layer key popup, "" first:
;;  none), ol:lks (the layer keys, see Remote>>Dyl:LayerKeyRead).

;;  Write the window to a temporary DCL file, returns its path:
(defun Dyl:ObjectKeysDcl (/ path file)
  (setq path (vl-filename-mktemp "olk" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("dyl_olk : dialog { label = \"DynALisp - Object Layer Keys\";"
      "  : text { label = \"The layer key of the new objects of each kind (several can be selected):\"; }"
      ;;  Its column titles: a disabled one-line list with the same tabs:
      "  : list_box { key = \"hdr\"; width = 96; height = 2; fixed_height = true; tabs = \"26 48\"; is_enabled = false; }"
      "  : list_box { key = \"ol\"; width = 96; height = 14; tabs = \"26 48\"; multiple_select = true; }"
      "  : boxed_column { key = \"obx\"; label = \"Layer key (12 selected)\";"
      "    : row {"
      "      : text { label = \"Layer key:\"; width = 12; fixed_width = true; }"
      "      : image_button { key = \"oke\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
      "      : popup_list { key = \"okk\"; edit_width = 48; }"
      "    }"
      "    : text { key = \"oly\"; width = 92; }"
      "  }"
      "  : row { fixed_width = true; alignment = left;"
      "    : button { key = \"rst\"; label = \"Reset Selected\"; width = 16; }"
      "    : button { key = \"all\"; label = \"Reset All\"; width = 16; }"
      "  }"
      "  : text { key = \"ons\"; width = 96; is_enabled = false; }"
      "  : row { fixed_width = true; alignment = right;"
      "    : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 12; fixed_width = true; }"
      "    : button { key = \"cancel\"; label = \"Cancel\"; is_cancel = true; width = 12; fixed_width = true; }"
      "    : button { key = \"docs\"; label = \"Open Docs\"; width = 12; fixed_width = true; }"
      "  }"
      "}"
     )
    (write-line line file)
  )
  (close file)
  path
)

;;  The layer the key key gives in this drawing (in the active phase while auto-phase is on),
;;  as text: missing layers say so, an undefined key too:
(defun Dyl:ObjectKeysLayer (key / rec lay)
  (cond
    ((= "" key) "Current layer")
    ((not (setq rec (assoc key ol:lks))) (strcat key " (key not defined)"))
    ((tblsearch "LAYER" (setq lay (Remote>>Dyl:LayerKeyName rec))) lay)
    ((strcat lay " (created when used)"))
  )
)

;;  Line of the list of the kind at index i:
(defun Dyl:ObjectKeysLine (i / o k)
  (setq o (nth i *olk:objects*)
        k (cadr (nth i ol:lst))
  )
  (strcat (cadr o) "\t" (if (= "" k) "(none)" k) "\t" (Dyl:ObjectKeysLayer k))
)

;;  Fill the list (the kinds ol:sel selected) and show the key of the first one selected:
(defun Dyl:ObjectKeysFill (/ i)
  (start_list "ol")
  (setq i -1)
  (repeat (length ol:lst) (add_list (Dyl:ObjectKeysLine (setq i (1+ i)))))
  (end_list)
  (set_tile "ol" (cond ((Remote>>LM:lst->str (mapcar 'itoa ol:sel) " ")) ("")))
  (Dyl:ObjectKeysShow)
)

;;  The fields: the key of the kind shown (the first one selected), its layer, the number of
;;  kinds selected in the heading; greyed out when none is selected:
(defun Dyl:ObjectKeysShow (/ k)
  (setq k (if ol:sel (cadr (nth (car ol:sel) ol:lst)) ""))
  (set_tile "obx" (cond ((cdr ol:sel) (strcat "Layer key (" (itoa (length ol:sel)) " selected)")) ("Layer key")))
  (set_tile "okk" (itoa (cond ((vl-position k ol:keys)) (0))))
  (set_tile "oly" (if ol:sel (strcat "Layer in this drawing: " (Dyl:ObjectKeysLayer k)) "Select a kind of object in the list."))
  (mode_tile "okk" (if ol:sel 0 1))
  (Dyl:MoreTile "oke" (and ol:sel T))
  (mode_tile "rst" (if ol:sel 0 1))
)

;;  The selection of the list changed:
(defun Dyl:ObjectKeysPick (val)
  (setq ol:sel (read (strcat "(" (cond (val) ("")) ")")))
  (Dyl:ObjectKeysShow)
)

;;  Give the key k to the kinds selected:
(defun Dyl:ObjectKeysPut (k)
  (foreach i ol:sel (setq ol:lst (Remote>>Dyl:ListSubst ol:lst i (list (car (nth i ol:lst)) k))))
  (Dyl:ObjectKeysFill)
)

;;  Reset Selected (all nil) / Reset All (all T): the default keys:
(defun Dyl:ObjectKeysReset (all / d i)
  (setq d (Remote>>Dyl:ObjectKeysDefaults)
        i -1
  )
  (setq ol:lst (mapcar '(lambda (x) (if (or all (member (setq i (1+ i)) ol:sel)) (assoc (car x) d) x)) ol:lst))
  (Dyl:ObjectKeysFill)
)

;;  The keys of the Layer key popup: none, then the layer keys and the keys of the kinds that
;;  are not defined, sorted:
(defun Dyl:ObjectKeysKeys (/ lst)
  (setq lst (mapcar 'car ol:lks))
  (foreach x ol:lst (if (and (/= "" (cadr x)) (not (member (cadr x) lst))) (setq lst (cons (cadr x) lst))))
  (cons "" (vl-sort lst '(lambda (a b) (< (strcase a) (strcase b)))))
)

;;  The Object Layer Keys window: the key of the new objects of each kind (see *olk:objects*).
;;  The open button of the key: the Layer Keys window (closes this one, opens it again), a key
;;  double-clicked there given to the kinds selected. OK saves ObjectLayerKeys.csv. Returns T
;;  when saved:
(defun Dyl:ObjectKeysDialog (/ ol:lst ol:sel ol:keys ol:lks dcl id sta k)
  (setq ol:lst (Remote>>Dyl:ObjectKeysRead)
        dcl    (Dyl:ObjectKeysDcl)
        id     (load_dialog dcl)
        sta    3
  )
  ;;  Code 3: the Layer Keys window, then this one again:
  (while (= 3 sta)
    (setq sta     nil
          ol:lks  (Remote>>Dyl:LayerKeyRead)
          ol:keys (Dyl:ObjectKeysKeys)
    )
    (if (and (<= 0 id) (new_dialog "dyl_olk" id))
      (progn
        (start_list "hdr")
        (add_list "Object\tLayer key\tLayer")
        (end_list)
        (start_list "okk")
        (foreach x ol:keys
          (add_list (cond ((= "" x) "(None: the current layer)") ((assoc x ol:lks) x) ((strcat x "   (not defined)"))))
        )
        (end_list)
        (Dyl:ObjectKeysFill)
        (set_tile "ons"
                  (cond
                    ((not (Remote>>Dyl:ObjectKeysAuto-p)) "Auto layer keys is off: turn it on in Dyl-Settings (Reactors) to use these keys.")
                    ((not (Dyl:ReactorsOn-p)) "Auto layer keys is on, but the DynALisp reactors are off (Dyl-Settings).")
                    ("Auto layer keys is on: the objects made by a command go to these layer keys when it ends.")
                  )
        )
        (Dyl:DocsTile "Layer\\Dyl-ObjectLayerKeys.htm")
        (action_tile "ol" "(Dyl:ObjectKeysPick $value)")
        (action_tile "okk" "(Dyl:ObjectKeysPut (nth (atoi $value) ol:keys))")
        (action_tile "oke" "(done_dialog 3)")
        (action_tile "rst" "(Dyl:ObjectKeysReset nil)")
        (action_tile "all" "(Dyl:ObjectKeysReset T)")
        (action_tile "accept" "(done_dialog 1)")
        (setq sta (start_dialog))
      )
      (alert "\nError: the Object Layer Keys window could not be loaded")
    )
    ;;  A key double-clicked in the Layer Keys window, to the kinds selected:
    (if (and (= 3 sta) (setq k (Remote>>Dyl:LayerKeyPick (cadr (nth (car ol:sel) ol:lst)))))
      (foreach i ol:sel (setq ol:lst (Remote>>Dyl:ListSubst ol:lst i (list (car (nth i ol:lst)) k))))
    )
  )
  (if (<= 0 id) (unload_dialog id))
  (vl-file-delete dcl)
  (cond
    ((/= 1 sta) nil)
    ((Remote>>Dyl:ObjectKeysWrite ol:lst) (princ "\nObject layer keys saved.") T)
    ((alert (strcat "\nError: the object layer keys could not be saved to\n" (Dyl:UserFileW *olk:file*) "\n(is it open in Excel?)")))
  )
)

;;-------------------------=={ Commands }==------------------------;;

;; Object Layer Keys
;; Opens a window to assign a layer key to the new dimensions, leaders, text and other common objects.

(defun c:Dyl-ObjectLayerKeys ()
  (Dyl:ObjectKeysDialog)
  (princ)
)
