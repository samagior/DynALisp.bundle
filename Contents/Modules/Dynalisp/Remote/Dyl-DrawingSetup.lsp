;; Dyl-DrawingSetup - Dynalisp unit and grid presets, and the default ones checked when a drawing opens
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

;;  Loaded at startup with the other Remote files, before the Apps, so that the defaults
;;  are checked in every drawing whether the Set Units and Standard Grid commands are
;;  turned on or not.
;;
;;  The unit and grid presets are set with system variables, so a drawing can be compared
;;  with them. The child commands of Dyl-SetUnits and Dyl-StandardGrid apply them
;;  (Pst-UnitsMetricMm -> (Remote>>Dyl:UnitsApply "MetricMm")).
;;
;;  Defaults: one unit preset and one grid preset for the imperial drawings and for the
;;  metric drawings (MEASUREMENT 0 or 1), user settings chosen in Dyl-Settings:
;;    DynalispUnitsImperial  DynalispUnitsMetric  DynalispGridImperial  DynalispGridMetric
;;  The value is the preset key ("MetricMm", "Inch"...), "" or missing: not checked.
;;  DynalispSetupOn ("1": on, off by default) turns the whole check off, the defaults kept.
;;  When a drawing opens (Remote>>Dyl:SetupWatch, run by dynalisp.mnl), its units and its
;;  grid are compared with the defaults of its kind and set when they differ.
;;
;;  Use in an App:
;;    (Remote>>Dyl:UnitsApply "MetricMm") -> sets the units of a preset
;;    (Remote>>Dyl:GridApply "Inch")      -> sets the grid of a preset
;;    (Remote>>Dyl:SetupWatch)            -> checks the current drawing, returns a status line

(vl-load-com)

;;  Unit presets: (key label ((system variable . value) ...)). AUNITS 0 is decimal degrees,
;;  ANGBASE 0 is East and ANGDIR 0 counter-clockwise; an architectural LUPREC n is a
;;  1/2^n inch precision (4: 1/16"):
(setq *ds:units* '(("MetricMm" "Metric 1 mm"
                    (("LUNITS" . 2) ("LUPREC" . 0) ("AUNITS" . 0) ("AUPREC" . 0) ("ANGBASE" . 0.0) ("ANGDIR" . 0))
                   )
                   ("MetricTenthMm" "Metric 0.1 mm"
                    (("LUNITS" . 2) ("LUPREC" . 1) ("AUNITS" . 0) ("AUPREC" . 1) ("ANGBASE" . 0.0) ("ANGDIR" . 0))
                   )
                   ("MetricHundredthMm" "Metric 0.01 mm"
                    (("LUNITS" . 2) ("LUPREC" . 2) ("AUNITS" . 0) ("AUPREC" . 2) ("ANGBASE" . 0.0) ("ANGDIR" . 0))
                   )
                   ("ImperialSixteenthIn" "Imperial 1/16 in"
                    (("LUNITS" . 4) ("LUPREC" . 4) ("AUNITS" . 0) ("AUPREC" . 0) ("ANGBASE" . 0.0) ("ANGDIR" . 0))
                   )
                  )
      ;;  Grid presets: (key label (snap grid) in inches (snap grid) in mm, grid lines per
      ;;  major line). The inch values are used in imperial drawings, the mm values in
      ;;  metric drawings:
      *ds:grids* '(("Inch" "Inch: 1/4 in grid, 1 in major, 1/8 in snap" (0.125 0.25) (3.175 6.35) 4)
                   ("Foot" "Foot: 1 in grid, 1 ft major, 1/8 in snap" (0.125 1.0) (3.175 25.4) 12)
                   ("Centimeter" "Centimeter: 2 mm grid, 1 cm major, 1 mm snap"
                    (0.0393700787 0.0787401575)
                    (1.0 2.0)
                    5
                   )
                   ("Meter" "Meter: 100 mm grid, 1 m major, 25 mm snap" (0.9842519685 3.9370078740) (25.0 100.0) 10)
                  )
)

;;-------------------------=={ Units }==------------------------;;

;;  Label of a unit preset key, nil when there is no such preset:
(defun Remote>>Dyl:UnitsName (key)
  (cadr (assoc key *ds:units*))
)

;;  T when the current drawing has the units of the preset key:
(defun Remote>>Dyl:Units-p (key)
  (vl-every '(lambda (p) (equal (getvar (car p)) (cdr p) 1e-8)) (caddr (assoc key *ds:units*)))
)

;;  Set the units of the preset key in the current drawing:
(defun Remote>>Dyl:UnitsApply (key)
  (foreach p (caddr (assoc key *ds:units*)) (setvar (car p) (cdr p)))
  (princ)
)

;;-------------------------=={ Grid }==------------------------;;

;;  Label of a grid preset key, nil when there is no such preset:
(defun Remote>>Dyl:GridName (key)
  (cadr (assoc key *ds:grids*))
)

;;  (snap grid major) of the preset key in the units of the current drawing:
(defun Remote>>Dyl:GridValues (key / g)
  (setq g (assoc key *ds:grids*))
  (append (if (= 1 (getvar "MEASUREMENT")) (cadddr g) (caddr g)) (list (last g)))
)

;;  T when the current viewport has the snap, grid and major lines of the preset key:
(defun Remote>>Dyl:Grid-p (key / v)
  (setq v (Remote>>Dyl:GridValues key))
  (and (equal (getvar "SNAPUNIT") (list (car v) (car v)) 1e-6)
       (equal (getvar "GRIDUNIT") (list (cadr v) (cadr v)) 1e-6)
       (= (getvar "GRIDMAJOR") (caddr v))
  )
)

;;  Set the grid of the preset key in the current viewport, turn it on, with grid snap,
;;  AUTOSNAP 15 and ortho off:
(defun Remote>>Dyl:GridApply (key / v)
  (setq v (Remote>>Dyl:GridValues key))
  (setvar "SNAPUNIT" (list (car v) (car v)))
  (setvar "GRIDUNIT" (list (cadr v) (cadr v)))
  (setvar "GRIDMAJOR" (caddr v))
  (setvar "GRIDMODE" 1)
  (setvar "SNAPTYPE" 0)
  (setvar "AUTOSNAP" 15)
  (setvar "ORTHOMODE" 0)
  (princ)
)

;;-------------------------=={ Defaults }==------------------------;;

;;  "Imperial" or "Metric", the kind of the current drawing (MEASUREMENT 0 or 1):
(defun Remote>>Dyl:SetupKind ()
  (if (= 1 (getvar "MEASUREMENT")) "Metric" "Imperial")
)

;;  Default preset key of what ("Units" or "Grid") for kind ("Imperial" or "Metric"),
;;  nil when it is not checked (or the preset no longer exists):
(defun Remote>>Dyl:SetupDefault (what kind / key)
  (setq key (getenv (strcat "Dynalisp" what kind)))
  (if (and key (assoc key (if (= "Units" what) *ds:units* *ds:grids*))) key)
)

;;  Make key (nil: not checked) the default of what for kind:
(defun Remote>>Dyl:SetupDefaultSet (what kind key)
  (setenv (strcat "Dynalisp" what kind) (cond (key) ("")))
)

;;  T when the drawings are checked against the defaults (Drawing defaults in Dyl-Settings,
;;  DynalispSetupOn user setting, off by default). Off, the defaults are kept but unused:
(defun Remote>>Dyl:SetupOn-p ()
  (= "1" (getenv "DynalispSetupOn"))
)

;;  Turn the check of the drawings against the defaults on or off:
(defun Remote>>Dyl:SetupOnSet (on)
  (setenv "DynalispSetupOn" (if on "1" "0"))
)

;;  Check the current drawing against the defaults of its kind and set what differs. The
;;  drawing is not marked as modified by it (a drawing only looked at is not asked to be
;;  saved), it is set again the next time it opens. Returns a status line, nil when no
;;  default is set for the kind of the drawing, "off..." when the check is off:
(defun Remote>>Dyl:SetupWatch (/ kind u g done)
  (setq kind (Remote>>Dyl:SetupKind)
        u    (Remote>>Dyl:SetupDefault "Units" kind)
        g    (Remote>>Dyl:SetupDefault "Grid" kind)
  )
  (cond
   ((not (Remote>>Dyl:SetupOn-p)) "off (see Dyl-Settings)")
   ((or u g)
    (progn
      (if acad-push-dbmod (acad-push-dbmod))
      (if (and u (not (Remote>>Dyl:Units-p u)))
        (if (not (vl-catch-all-error-p (vl-catch-all-apply 'Remote>>Dyl:UnitsApply (list u))))
          (setq done (cons (strcat "units set to " (Remote>>Dyl:UnitsName u)) done))
        )
      )
      (if (and g (not (Remote>>Dyl:Grid-p g)))
        (if (not (vl-catch-all-error-p (vl-catch-all-apply 'Remote>>Dyl:GridApply (list g))))
          (setq done (cons (strcat "grid set to " (Remote>>Dyl:GridName g)) done))
        )
      )
      (if acad-pop-dbmod (acad-pop-dbmod))
      (strcat (strcase kind t)
              " drawing: "
              (cond
                (done (Remote>>LM:lst->str (reverse done) ", "))
                ((and u g) "units and grid already set")
                (u "units already set")
                ("grid already set")
              )
      )
    )
   )
  )
)

(princ)
