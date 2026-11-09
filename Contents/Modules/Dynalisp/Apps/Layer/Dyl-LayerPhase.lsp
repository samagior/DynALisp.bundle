;; LayerPhase - Monitor and switch the active phase of the drawing, and auto-phase new objects
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

;;  The phases themselves (active phase, phase layers) are in
;;  Modules\Dynalisp\Remote\Dyl-LayerPhase.lsp and the auto-phase reactors in
;;  Modules\Dynalisp\Reactor\Dyl-LayerPhase.lsp, both loaded at startup (the reactors only
;;  while the DynALisp reactors are on, see Dyl-Settings) so that auto-phase works in every
;;  drawing without running a command first.

;;-------------------------=={ Phases }==------------------------;;

;;  Phase of a layer name for the dialog: its phase code, "" when it is not phased:
(defun ph:of (lay codes)
  (cond ((Remote>>Dyl:PhaseOf lay codes)) (""))
)

;;  Phases of the drawing: ((code description layers objects visibility) ...), code "" being
;;  the unphased layers. visibility: "Shown", "Hidden", "Partial" or "-" (no layer).
(defun ph:stats (codes / tbl rec pha on cnt ss all)
  (setq tbl (mapcar '(lambda (c) (list (car c) 0 0)) codes))
  (while (setq rec (tblnext "LAYER" (not rec)))
    (if (setq cnt (assoc (setq pha (ph:of (cdr (assoc 2 rec)) codes)) tbl))
      (setq on  (and (< 0 (cdr (assoc 62 rec))) (= 0 (logand 1 (cdr (assoc 70 rec)))))
            tbl (subst (list pha (1+ (cadr cnt)) (+ (caddr cnt) (if on 1 0))) cnt tbl)
      )
    )
  )
  (setq tbl (mapcar '(lambda (c / n)
                       (setq n (assoc (car c) tbl))
                       (list (car c)
                             (cadr c)
                             (cadr n)
                             (if
                               (and (/= "" (car c))
                                    (< 0 (cadr n))
                                    (setq ss (ssget "_X" (list (cons 8 (strcat "*?-" (car c))))))
                               )
                               (sslength ss)
                               0
                             )
                             (cond
                               ((= 0 (cadr n)) "-")
                               ((= (cadr n) (caddr n)) "Shown")
                               ((= 0 (caddr n)) "Hidden")
                               ("Partial")
                             )
                       )
                     )
                    codes
            )
        ;;  Unphased objects: every object of the drawing less the phased ones:
        all (if (setq ss (ssget "_X")) (sslength ss) 0)
  )
  (mapcar '(lambda (r)
             (if (= "" (car r))
               (Remote>>Dyl:ListSubst r 3 (max 0 (- all (apply '+ (mapcar 'cadddr tbl)))))
               r
             )
           )
          tbl
  )
)

;;  Show (T) or hide (nil) the layers of the phases in the list sel ("" for the unphased
;;  layers), xref layers included. Hidden layers are turned off and frozen (the current
;;  layer is only turned off):
(defun ph:show (sel show codes / cur)
  (setq cur (strcase (getvar "CLAYER")))
  (vlax-for l (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object)))
    (if (member (ph:of (vla-get-Name l) codes) sel)
      (if show
        (progn
          (vla-put-LayerOn l :vlax-true)
          (vl-catch-all-apply 'vla-put-Freeze (list l :vlax-false))
        )
        (progn
          (vla-put-LayerOn l :vlax-false)
          (if (/= cur (strcase (vla-get-Name l))) (vl-catch-all-apply 'vla-put-Freeze (list l :vlax-true)))
        )
      )
    )
  )
)

;;  Phases switched by Pst-PhaseNext: existing, demolition, new and future work, then the
;;  other phases that have layers in the drawing:
(defun ph:cycle (codes / rec pha lst)
  (setq lst '("E" "D" "N" "F"))
  (while (setq rec (tblnext "LAYER" (not rec)))
    (if (and (setq pha (Remote>>Dyl:PhaseOf (cdr (assoc 2 rec)) codes)) (not (member pha lst)))
      (setq lst (cons pha lst))
    )
  )
  (vl-remove-if-not '(lambda (c) (member c lst)) (mapcar 'car codes))
)

;;  Set the active phase, given by its code (nil: no phase):
(defun ph:switch (code)
  (Remote>>Dyl:PhaseSet code)
  (princ)
)

;;-------------------------=={ Dialog }==------------------------;;

;;  Write the dialog definition to a temporary DCL file and return its path:
(defun ph:dcl (/ path file)
  (setq path (vl-filename-mktemp "ph" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("dyl_ph : dialog { label = \"DynALisp - Layer Phases\";"
      "  : text { key = \"act\"; width = 80; }"
      "  : text { label = \"Double-click a phase to set it as the active phase (Unphased: no active phase).\"; }"
      "  : list_box { label = \"Phases (layers ending with -code):\"; key = \"lst\"; width = 80; height = 16;"
      "               tabs = \"6 36 48 60\"; multiple_select = true; }"
      "  : row {"
      "    : row { fixed_width = true;"
      "      : button { key = \"vis\"; label = \"Show\"; width = 10; fixed_width = true; }"
      "      : button { key = \"hid\"; label = \"Hide\"; width = 10; fixed_width = true; }"
      "    }"
      "    : button { key = \"iso\"; label = \"Isolate phase\"; }"
      "  }"
      "  : row { fixed_width = true;"
      "    : button { key = \"lks\"; label = \"Layer keys Editor\"; }"
      "  }"
      "  : row { fixed_width = true; alignment = centered;"
      "    : button { key = \"accept\"; label = \"Close\"; is_default = true; is_cancel = true; width = 12; }"
      "    : button { key = \"docs\"; label = \"Open Docs\"; width = 12; fixed_width = true; }"
      "  }"
      "}"
     )
    (write-line line file)
  )
  (close file)
  path
)

;;  The functions below run inside c:Dyl-LayerPhase and use its local variables:
;;  ph:codes (phases of Phase.csv, after ("" "Unphased") for the unphased layers), ph:sel (codes of the selected phases), ph:stat (phases of
;;  the drawing, see ph:stats), ph:regen (T when the drawing could not be regenerated while
;;  the dialog was open).

;;  Codes of the phases selected in the list:
(defun ph:dlgsel (/ str pos lst)
  (setq str (get_tile "lst"))
  (while (/= "" (setq str (vl-string-left-trim " " str)))
    (setq pos (cond ((vl-string-search " " str)) ((strlen str)))
          lst (cons (car (nth (atoi (substr str 1 pos)) ph:codes)) lst)
          str (substr str (1+ pos))
    )
  )
  (reverse lst)
)

;;  Fill the dialog with the phases of the drawing, the selected ones kept selected:
(defun ph:dlgfill (/ code sel i)
  (setq code (Remote>>Dyl:PhaseGet)
        i    -1
  )
  (set_tile "act"
            (strcat "Active phase: "
                    (if code (strcat code " - " (Remote>>Dyl:PhaseName code)) "none")
                    "      Current layer: "
                    (getvar "CLAYER")
            )
  )
  (setq ph:stat (ph:stats ph:codes))
  (start_list "lst")
  (foreach r ph:stat
    (add_list
      (strcat (if (= (cond (code) ("")) (car r)) "> " "   ")
              (car r)
              "\t"
              (nth 1 r)
              "\t"
              (itoa (nth 2 r))
              " layer(s)\t"
              (itoa (nth 3 r))
              " object(s)\t"
              (nth 4 r)
      )
    )
  )
  (end_list)
  (foreach c ph:sel
    (if (setq i (vl-position (assoc c ph:codes) ph:codes)) (setq sel (cons (itoa i) sel)))
  )
  (if sel (set_tile "lst" (Remote>>LM:lst->str (reverse sel) " ")))
  (ph:dlgvis)
)

;;  Double-click: the phase clicked, Unphased ("") clears the active phase:
(defun ph:dlgset (code)
  (ph:switch (if (/= "" code) code))
  (ph:dlgfill)
)

;;  T when every selected phase that has layers is shown (the Show / Hide button hides them):
(defun ph:dlgshown-p (/ lst)
  (setq lst (vl-remove-if '(lambda (r) (or (not (member (car r) ph:sel)) (= "-" (nth 4 r)))) ph:stat))
  (and lst (vl-every '(lambda (r) (= "Shown" (nth 4 r))) lst))
)

;;  Label of the Show / Hide button for the selected phases (disabled when none has layers).
;;  Hide is disabled when none of them is shown, even partly:
(defun ph:dlgvis (/ on)
  (set_tile "vis" (if (ph:dlgshown-p) "Hide" "Show"))
  (setq on (if (vl-some '(lambda (r) (and (member (car r) ph:sel) (/= "-" (nth 4 r)))) ph:stat) 0 1))
  (mode_tile "vis" on)
  (mode_tile "hid"
             (if (vl-some '(lambda (r) (and (member (car r) ph:sel) (wcmatch (nth 4 r) "Shown,Partial"))) ph:stat) 0 1)
  )
)

;;  Regenerate the drawing at once, so the change shows behind the dialog (done when the
;;  dialog closes if it cannot be done now):
(defun ph:dlgregen ()
  (if
    (vl-catch-all-error-p
      (vl-catch-all-apply 'vla-Regen (list (vla-get-ActiveDocument (vlax-get-acad-object)) acAllViewports))
    )
    (setq ph:regen t)
  )
)

;;  Show / Hide ('toggle), hide ('hide) or isolate ('only) the selected phases:
(defun ph:dlgshow (mode)
  (if (setq ph:sel (ph:dlgsel))
    (progn
      (cond
        ((= 'only mode)
         ;;  The other phases are hidden, never the unphased layers (shown when Unphased is selected):
         (ph:show (vl-remove-if '(lambda (c) (or (= "" c) (member c ph:sel))) (mapcar 'car ph:codes)) nil ph:codes)
         (ph:show ph:sel t ph:codes)
        )
        ((= 'hide mode) (ph:show ph:sel nil ph:codes))
        ((ph:show ph:sel (not (ph:dlgshown-p)) ph:codes))
      )
      (ph:dlgregen)
      (ph:dlgfill)
    )
  )
)

;;-------------------------=={ Commands }==------------------------;;

;;  The child commands Pst-Phase* below switch the active phase in one go, run by their
;;  aliases (PH-E, PH-N...).

;; Layer Phase
;; Lists the phases of the drawing to set the active phase and show or hide them.

(defun c:Dyl-LayerPhase (/ dcl:pth dcl:id sta ph:codes ph:sel ph:stat ph:regen)
  (setq ph:codes (cons '("" "Unphased") (Remote>>Dyl:PhaseList))
        ph:sel   (list (cond ((Remote>>Dyl:PhaseGet)) ("")))
        dcl:pth  (ph:dcl)
        dcl:id   (load_dialog dcl:pth)
        sta      2
  )
  ;;  Layer keys Editor closes the dialog (3), it opens again once the keys are edited:
  (while (and (< 1 sta) (<= 0 dcl:id) (new_dialog "dyl_ph" dcl:id))
    (ph:dlgfill)
    (action_tile "lst" "(setq ph:sel (ph:dlgsel)) (if (= 4 $reason) (ph:dlgset (car ph:sel)) (ph:dlgvis))")
    (action_tile "vis" "(ph:dlgshow 'toggle)")
    (action_tile "hid" "(ph:dlgshow 'hide)")
    (action_tile "iso" "(ph:dlgshow 'only)")
    (action_tile "lks" "(setq ph:sel (ph:dlgsel)) (done_dialog 3)")
    (Dyl:DocsTile "Layer\\Dyl-LayerPhase.htm")
    (setq sta (start_dialog))
    (if (= 3 sta) (Remote>>Dyl:LayerKeyDialog nil))
  )
  (if (> 0 dcl:id) (princ "\n--> Unable to load the Layer Phases dialog."))
  (if (<= 0 dcl:id) (unload_dialog dcl:id))
  (vl-file-delete dcl:pth)
  (if ph:regen (vla-Regen (vla-get-ActiveDocument (vlax-get-acad-object)) acAllViewports))
  (princ)
)

;; Phase Existing
;; Sets existing to remain (E) as the active phase: new objects and phased layer keys go to the -E layers.

(defun c:Pst-PhaseExisting () (ph:switch "E"))

;; Phase Demolition
;; Sets existing to demolish (D) as the active phase: new objects and phased layer keys go to the -D layers.

(defun c:Pst-PhaseDemolition () (ph:switch "D"))

;; Phase New Work
;; Sets new work (N) as the active phase: new objects and phased layer keys go to the -N layers.

(defun c:Pst-PhaseNewWork () (ph:switch "N"))

;; Phase Future Work
;; Sets future work (F) as the active phase: new objects and phased layer keys go to the -F layers.

(defun c:Pst-PhaseFutureWork () (ph:switch "F"))

;; Phase Temporary Work
;; Sets temporary work (T) as the active phase: new objects and phased layer keys go to the -T layers.

(defun c:Pst-PhaseTemporaryWork () (ph:switch "T"))

;; Phase None
;; Clears the active phase: phased layer keys give their layer without phase and auto-phase does nothing.

(defun c:Pst-PhaseNone () (ph:switch nil))

;; Phase Next
;; Switches to the next phase: existing, demolition, new and future work, then the other phases used in the drawing.

(defun c:Pst-PhaseNext (/ codes lst)
  (setq codes (Remote>>Dyl:PhaseList)
        lst   (ph:cycle codes)
  )
  (ph:switch (cond ((cadr (member (Remote>>Dyl:PhaseGet) lst))) ((car lst))))
)

;; Phase Auto Toggle
;; Turns auto-phase on or off in every drawing: objects created by a command go to the active phase.

(defun c:Pst-PhaseAutoToggle ()
  (Remote>>Dyl:PhaseAutoSet (not (Remote>>Dyl:PhaseAuto-p)))
  (princ)
)

(princ)
