;; Dyl-CmdOptimizer - Prepares the drawing before the save and print commands and REGEN
;; Copyright (C) 2023  Samuel Martineau
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

;;  Output prep redefinitions: the native save commands (SAVE, QSAVE, SAVEAS, +SAVEAS),
;;  print commands (PLOT, PUBLISH, EXPORTPDF, EXPORTDWF, EXPORTDWFX), PREVIEW and REGEN are
;;  undefined at startup when the output prep is on in Dyl-Settings and their command
;;  below is turned on in Dyl-Suite (see MAJ:Redefine in Resources\dynalisp.mnl), so
;;  they run these commands. Each one runs the prep steps checked for it in
;;  Dyl-Settings (MAJ:PrepFor, skipped when the output prep is off or not loaded),
;;  then the native command: the "_." prefix always calls it (even when undefined),
;;  and (initdia) forces its dialog box to be displayed.
;;  The commands of a group share its steps: the All saves column for the saves, All
;;  prints for the prints (MAJ:groups and MAJ:PrepCol). REGEN
;;  runs by default only the draw order (the active preset applied to the drawing,
;;  while auto draw order is on).
;;  Dyl-CmdOptimizer turns the redefinition on or off, as the "Command optimizer"
;;  checkbox of Dyl-Settings does (MAJ:RedefineSet, for every drawing).

;;-------------------------=={ Commands }==------------------------;;

;; Command Optimizer
;; Turns the redefinition of the save and print commands and REGEN on or off, as in Dyl-Settings.
(defun c:Dyl-CmdOptimizer (/ cur new)
  (if (not MAJ:RedefineSet)
    (princ "\n--> Output prep not loaded in this drawing (see the DynALisp startup log).")
    (progn
      (setq cur (MAJ:Redefine-p))
      (princ (strcat "\n" (MAJ:Status) "."))
      (initget "On Off")
      (setq new (getkword (strcat "\nCommand optimizer, for every drawing [On/Off] <" (if cur "Off" "On") ">: "))
            new (if new (= "On" new) (not cur))
      )
      (if (eq new cur)
        (princ (strcat "\nCommand optimizer already " (if cur "on" "off") "."))
        (MAJ:RedefineSet new)
      )
    )
  )
  (princ)
)

;; Save
;; Runs the output prep steps checked for All saves in Dyl-Settings, then the native SAVE dialog.
;;  The steps of the output prep before the native command cmd, caught: a step that fails
;;  is said, any command it left running is cancelled, and the native command runs all the
;;  same, so a drawing is always saved and plotted (an error stopped the save):
(defun MAJ:PrepSafe (cmd / res)
  (if (and MAJ:PrepFor (vl-catch-all-error-p (setq res (vl-catch-all-apply 'MAJ:PrepFor (list cmd)))))
    (progn
      (if (< 0 (logand 1 (getvar "CMDACTIVE"))) (vl-catch-all-apply 'command nil))
      (princ (strcat "\n--> Output prep before " cmd " failed (" (vl-catch-all-error-message res) "): " cmd " runs without it."))
    )
  )
)

(defun c:SAVE ()
  (MAJ:PrepSafe "SAVE")
  (initdia)
  (vl-cmdf "_.SAVE")
  (princ)
)

;; Quick Save
;; Runs the output prep steps checked for All saves in Dyl-Settings, then the native QSAVE.
(defun c:QSAVE ()
  (MAJ:PrepSafe "QSAVE")
  ;; a drawing never saved: QSAVE shows the Save As dialog (no dialog is shown to a
  ;; command run by Lisp without initdia: it asked for the file name on the command line)
  (if (= 0 (getvar "DWGTITLED")) (initdia))
  (vl-cmdf "_.QSAVE")
  (princ)
)

;; Save As
;; Runs the output prep steps checked for All saves in Dyl-Settings, then the native SAVEAS dialog.
(defun c:SAVEAS ()
  (MAJ:PrepSafe "SAVEAS")
  (initdia)
  (vl-cmdf "_.SAVEAS")
  (princ)
)

;; Save As Options
;; Runs the output prep steps checked for All saves in Dyl-Settings, then the native +SAVEAS (its prompts left to the user or menu macro).
(defun c:+SAVEAS ()
  (MAJ:PrepSafe "+SAVEAS")
  (initdia)
  (vl-cmdf "_.+SAVEAS")
  (princ)
)

;; Plot
;; Runs the output prep steps checked for All prints in Dyl-Settings, then the native PLOT dialog.
(defun c:PLOT ()
  (MAJ:PrepSafe "PLOT")
  (initdia)
  (vl-cmdf "_.PLOT")
  (princ)
)

;; Publish
;; Runs the output prep steps checked for All prints in Dyl-Settings, then the native PUBLISH dialog.
(defun c:PUBLISH ()
  (MAJ:PrepSafe "PUBLISH")
  (initdia)
  (vl-cmdf "_.PUBLISH")
  (princ)
)

;; Plot Preview
;; Runs the output prep steps checked for PREVIEW in Dyl-Settings, then the native PREVIEW.
(defun c:PREVIEW ()
  (MAJ:PrepSafe "PREVIEW")
  (vl-cmdf "_.PREVIEW")
  (princ)
)

;; Export PDF
;; Runs the output prep steps checked for All prints in Dyl-Settings, then the native EXPORTPDF dialog.
(defun c:EXPORTPDF ()
  (MAJ:PrepSafe "EXPORTPDF")
  (initdia)
  (vl-cmdf "_.EXPORTPDF")
  (princ)
)

;; Export DWF
;; Runs the output prep steps checked for All prints in Dyl-Settings, then the native EXPORTDWF dialog.
(defun c:EXPORTDWF ()
  (MAJ:PrepSafe "EXPORTDWF")
  (initdia)
  (vl-cmdf "_.EXPORTDWF")
  (princ)
)

;; Export DWFx
;; Runs the output prep steps checked for All prints in Dyl-Settings, then the native EXPORTDWFX dialog.
(defun c:EXPORTDWFX ()
  (MAJ:PrepSafe "EXPORTDWFX")
  (initdia)
  (vl-cmdf "_.EXPORTDWFX")
  (princ)
)

;; Regen
;; Runs the output prep steps checked for REGEN in Dyl-Settings (the draw order by default), then the native REGEN.
(defun c:REGEN ()
  (MAJ:PrepSafe "REGEN")
  (vl-cmdf "_.REGEN")
  (princ)
)

(princ)
