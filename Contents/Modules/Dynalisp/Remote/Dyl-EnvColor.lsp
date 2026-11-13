;; Dyl-EnvColor - Dynalisp model space background color
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
;;  The display settings of Dyl-Settings (Display in Overrides, its open button opening
;;  the display window). Display on (DynalispDisplayOn user setting, off by default),
;;  each drawing opened applies the display settings chosen (Remote>>Dyl:DisplayApply,
;;  run by dynalisp.mnl); off, the display preferences are left as they are.
;;
;;  The model space background color (DynalispBackground, "" or missing: not set, the
;;  current color kept): Black, Default (blue-grey) or White, each with a crosshair
;;  color that stays readable on it. The colors are the display preferences (Options >
;;  Display > Colors, model space context): user profile settings, so they apply to
;;  every drawing. The layout (paper space) background is left as it is.
;;
;;  Use in an App:
;;    (Remote>>Dyl:Background)              -> "Black", "Default" or "White",
;;                                             nil for any other color
;;    (Remote>>Dyl:BackgroundSet "White")   -> sets the background and crosshair
;;    (Remote>>Dyl:DisplayApply)            -> applies the display settings, returns a status line

(vl-load-com)

;;  (NAME BACKGROUND CROSSHAIR), colors as OLE values: R + G*256 + B*65536
(setq *ec:colors* '(("Black" 0 16777215)
                    ("Default" 3155999 16777215) ; RGB 33,40,48
                    ("White" 16777215 0)
                   )
)

(defun ec:display () (vla-get-display (vla-get-preferences (vlax-get-acad-object))))

;;  Name of the current model space background color, nil when it is not one of
;;  *ec:colors*:
(defun Remote>>Dyl:Background (/ c)
  (if
    (not (vl-catch-all-error-p
           (setq c (vl-catch-all-apply
                     '(lambda ()
                        (vlax-variant-value
                          (vlax-variant-change-type (vla-get-graphicswinmodelbackgrndcolor (ec:display)) vlax-vblong)
                        )
                      )
                   )
           )
         )
    )
    (car (vl-some '(lambda (e) (if (= c (cadr e)) e)) *ec:colors*))
  )
)

;;  Set the model space background color and its crosshair color (name of
;;  *ec:colors*):
(defun Remote>>Dyl:BackgroundSet (name / e)
  (if (setq e (assoc name *ec:colors*))
    (progn
      (vlax-put-property (ec:display) 'graphicswinmodelbackgrndcolor (cadr e))
      (vlax-put-property (ec:display) 'modelcrosshaircolor (caddr e))
      name
    )
  )
)

;;-------------------------=={ Display settings }==------------------------;;

;;  T when the display settings are applied (Display in Dyl-Settings, off by default):
(defun Remote>>Dyl:DisplayOn-p ()
  (= "1" (getenv "DynalispDisplayOn"))
)

;;  Turn the display settings on or off:
(defun Remote>>Dyl:DisplayOnSet (on)
  (setenv "DynalispDisplayOn" (if on "1" "0"))
)

;;  Background color chosen (name of *ec:colors*), nil when it is not set:
(defun Remote>>Dyl:BackgroundPref (/ name)
  (setq name (getenv "DynalispBackground"))
  (if (assoc name *ec:colors*) name)
)

;;  Choose the background color (nil: not set, the current color kept):
(defun Remote>>Dyl:BackgroundPrefSet (name)
  (setenv "DynalispBackground" (cond (name) ("")))
)

;;  Apply the display settings chosen while they are on: the background set when it
;;  differs. Returns a status line, nil when no display setting is chosen:
(defun Remote>>Dyl:DisplayApply (/ bkg)
  (cond
    ((not (Remote>>Dyl:DisplayOn-p)) "off (see Dyl-Settings)")
    ((not (setq bkg (Remote>>Dyl:BackgroundPref))) nil)
    ((= bkg (Remote>>Dyl:Background)) (strcat "background " bkg))
    ((Remote>>Dyl:BackgroundSet bkg) (strcat "background set to " bkg))
  )
)

(princ)
