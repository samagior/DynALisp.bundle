;; Dyl-SysVars - Dynalisp system variable profiles: preferred values set in every drawing
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
;;  System variable profiles: one CSV file each in Modules\Dynalisp\Res\SysVars
;;  (Default.csv...), named by the file. Saved profiles go to the user copy of that folder
;;  (User\Modules\Dynalisp\Res\SysVars, see Dyl:UserDirW in dynalisp.mnl). One system
;;  variable per row, its preferred value as text:
;;    Variable;Value
;;    PICKADD;2
;;  A value is read as the type of the current value of its variable: a whole number, a
;;  real, a text, or a point written "x,y" or "x,y,z". The protected variables
;;  (Res\SysVarsProtected.csv, see Remote>>Dyl:SysVarKeep) get their preferred value in
;;  every drawing whatever the profile, and no profile changes them.
;;
;;  While System variables is on (Overrides in Dyl-Settings, DynalispSysVarOn user setting,
;;  off by default), each drawing opened gets the preferred values of the active profile
;;  (DynalispSysVarProfile, chosen in Dyl-SysVars), see Remote>>Dyl:SysVarApply. Every
;;  change saved stamps DynalispSysVarStamp, so the drawings already open apply it when they
;;  are made current (Dyl:SetSync in dynalisp.mnl, while Settings sync is on).
;;
;;  Use in an App:
;;    (Remote>>Dyl:SysVarProfile)      -> name of the active profile ("Default"), nil if none
;;    (Remote>>Dyl:SysVarRead "Default") -> rows of a profile: (("PICKADD" "2") ...)
;;    (Remote>>Dyl:SysVarApply)        -> applies the active profile, returns a status line

(vl-load-com)

(setq *sv:header* '("Variable" "Value"))

;;-------------------------=={ Profiles }==------------------------;;

;;  Default folder of the profiles:
(defun Remote>>Dyl:SysVarDefaultDir ()
  (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\SysVars")
)

;;  Folder of the profiles: the user copy once the profiles were saved, else the default
;;  folder (see Dyl:UserDir in dynalisp.mnl):
(defun Remote>>Dyl:SysVarDir ()
  (Dyl:UserDir (Remote>>Dyl:SysVarDefaultDir))
)

;;  Folder where the profiles are saved: the user copy, made from the default profiles the
;;  first time:
(defun Remote>>Dyl:SysVarDirW ()
  (Dyl:UserDirW (Remote>>Dyl:SysVarDefaultDir))
)

;;  CSV file of the profile name:
(defun Remote>>Dyl:SysVarFile (name)
  (strcat (Remote>>Dyl:SysVarDir) "\\" name ".csv")
)

;;  Names of the profiles (their file names), sorted:
(defun Remote>>Dyl:SysVarProfiles ()
  (acad_strlsort (mapcar 'vl-filename-base (vl-directory-files (Remote>>Dyl:SysVarDir) "*.csv" 1)))
)

;;  Active profile: the one chosen when its file exists, else Default, else the first one
;;  (nil: there is none):
(defun Remote>>Dyl:SysVarProfile (/ p)
  (cond
    ((and (setq p (getenv "DynalispSysVarProfile")) (/= "" p) (findfile (Remote>>Dyl:SysVarFile p))) p)
    ((findfile (Remote>>Dyl:SysVarFile "Default")) "Default")
    ((car (Remote>>Dyl:SysVarProfiles)))
  )
)

;;  Make name the active profile:
(defun Remote>>Dyl:SysVarProfileSet (name)
  (setenv "DynalispSysVarProfile" (cond (name) ("")))
)

;;  Rows of the profile name: (("VARIABLE" "value") ...) in file order, the names in upper
;;  case, the empty or repeated names skipped:
(defun Remote>>Dyl:SysVarRead (name / fle var lst)
  (if (and name Remote>>Dyl:CsvRead (findfile (setq fle (Remote>>Dyl:SysVarFile name))))
    (foreach r (Remote>>Dyl:CsvRead fle 2)
      (if (and (/= "" (setq var (strcase (car r)))) (not (assoc var lst)))
        (setq lst (cons (list var (cadr r)) lst))
      )
    )
  )
  (reverse lst)
)

;;-------------------------=={ Protected variables }==------------------------;;

;;  The protected variables: their preferred value is set in every drawing whatever the
;;  active profile, and no profile changes them. Variable;Value rows of
;;  Modules\Dynalisp\Res\SysVarsProtected.csv (its user copy once saved, see Dyl:UserFile in
;;  dynalisp.mnl), outside the profiles folder so it is not a profile. An empty value: the
;;  variable is protected only (no profile changes it, it is not set).

;;  Default file of the protected variables:
(defun Remote>>Dyl:SysVarKeepFile ()
  (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\SysVarsProtected.csv")
)

;;  Rows of the protected variables: (("VARIABLE" "value") ...), sorted by name:
(defun Remote>>Dyl:SysVarKeep (/ var lst)
  (if Remote>>Dyl:CsvRead
    (foreach r (Remote>>Dyl:CsvRead (Dyl:UserFile (Remote>>Dyl:SysVarKeepFile)) 2)
      (if (and (/= "" (setq var (strcase (car r)))) (not (assoc var lst))) (setq lst (cons (list var (cadr r)) lst)))
    )
  )
  (vl-sort lst '(lambda (a b) (< (car a) (car b))))
)

;;  Save rows ((variable value) ...) as the protected variables. T on success, nil when the
;;  file cannot be written:
(defun Remote>>Dyl:SysVarKeepWrite (rows)
  (Remote>>LM:writecsv (cons *sv:header* rows) (Dyl:UserFileW (Remote>>Dyl:SysVarKeepFile)))
)

;;-------------------------=={ Values }==------------------------;;

;;  Value of the text str for the system variable var, of the type of its current value.
;;  nil when var is not a system variable or str is not a valid value for it:
(defun Remote>>Dyl:SysVarValue (var str / cur v)
  (setq cur (getvar var)
        str (vl-string-trim " " str)
  )
  (cond
    ((= 'STR (type cur)) str)
    ((= 'INT (type cur))
     (if (and (setq v (distof str 2)) (equal v (fix v) 1e-9)) (fix v))
    )
    ((= 'REAL (type cur)) (distof str 2))
    ((= 'LIST (type cur))
     (setq v (vl-catch-all-apply 'read (list (strcat "(" (vl-string-translate "," " " str) ")"))))
     (if (and (listp v) (= (length v) (length cur)) (vl-every 'numberp v)) (mapcar 'float v))
    )
  )
)

;;  Text of a value: a whole number, a real without its trailing zeros, a text, a point
;;  "x,y" or "x,y,z" (nil: ""):
(defun Remote>>Dyl:SysVarText (val / s)
  (cond
    ((= 'STR (type val)) val)
    ((= 'INT (type val)) (itoa val))
    ((= 'REAL (type val))
     (setq s (rtos val 2 6))
     (if (vl-string-search "." s) (vl-string-right-trim "." (vl-string-right-trim "0" s)) s)
    )
    ((= 'LIST (type val)) (Remote>>LM:lst->str (mapcar 'Remote>>Dyl:SysVarText val) ","))
    ("")
  )
)

;;  T when the system variable var already has the value val (texts in any case):
(defun Remote>>Dyl:SysVarSame-p (var val / cur)
  (setq cur (getvar var))
  (if (= 'STR (type cur)) (= (strcase cur) (strcase val)) (equal cur val 1e-6))
)

;;  T when the system variable var can be set (not read-only): its own value set back:
(defun Remote>>Dyl:SysVarWritable-p (var)
  (not (vl-catch-all-error-p (vl-catch-all-apply 'setvar (list var (getvar var)))))
)

;;  Set the system variables of rows ((var text) ...) that differ from their preferred
;;  value, but the protected ones (keep: their names). Returns (set failed): the names
;;  set, the names that could not be (unknown variable, value not valid, read-only):
(defun Remote>>Dyl:SysVarSet (rows keep / val done bad)
  (foreach r rows
    (cond
      ((member (car r) keep))
      ((not (setq val (Remote>>Dyl:SysVarValue (car r) (cadr r)))) (setq bad (cons (car r) bad)))
      ((Remote>>Dyl:SysVarSame-p (car r) val))
      ((vl-catch-all-error-p (vl-catch-all-apply 'setvar (list (car r) val))) (setq bad (cons (car r) bad)))
      ((setq done (cons (car r) done)))
    )
  )
  (list (reverse done) (reverse bad))
)

;;  Set the protected variables keep ((var text) ...: those with a value) and the rows of a
;;  profile (its protected variables skipped). Returns (set failed) as Remote>>Dyl:SysVarSet:
(defun Remote>>Dyl:SysVarSetAll (rows keep / a b)
  (setq a (Remote>>Dyl:SysVarSet (vl-remove-if '(lambda (r) (= "" (cadr r))) keep) nil)
        b (Remote>>Dyl:SysVarSet rows (mapcar 'car keep))
  )
  (list (append (car a) (car b)) (append (cadr a) (cadr b)))
)

;;-------------------------=={ Override }==------------------------;;

;;  T when the preferred values are set in every drawing (System variables in Dyl-Settings,
;;  DynalispSysVarOn user setting, off by default):
(defun Remote>>Dyl:SysVarOn-p ()
  (= "1" (getenv "DynalispSysVarOn"))
)

;;  Turn the override on or off (the drawings already open follow, see the stamp):
(defun Remote>>Dyl:SysVarOnSet (on)
  (setenv "DynalispSysVarOn" (if on "1" "0"))
  (Remote>>Dyl:SysVarStampSet)
)

;;  Stamp of the last change saved (override, active profile or its values): a drawing
;;  already open applies the profile again when it changed (see Dyl:SetSync):
(defun Remote>>Dyl:SysVarStamp () (getenv "DynalispSysVarStamp"))
(defun Remote>>Dyl:SysVarStampSet () (setenv "DynalispSysVarStamp" (rtos (getvar "CDATE") 2 8)))

;;  Set the preferred values of the active profile in the current drawing while the
;;  override is on. The drawing is not marked as modified by it. Returns a status line:
(defun Remote>>Dyl:SysVarApply (/ pro res)
  (cond
    ((not (Remote>>Dyl:SysVarOn-p)) "off (see Dyl-Settings)")
    (T
     (setq pro (Remote>>Dyl:SysVarProfile))
     (if acad-push-dbmod (acad-push-dbmod))
     (setq res (Remote>>Dyl:SysVarSetAll (Remote>>Dyl:SysVarRead pro) (Remote>>Dyl:SysVarKeep)))
     (if acad-pop-dbmod (acad-pop-dbmod))
     (strcat (cond (pro) ("no profile"))
             ": "
             (if (car res)
               (strcat (itoa (length (car res))) " set (" (Remote>>LM:lst->str (car res) ", ") ")")
               "every variable already set"
             )
             (if (cadr res) (strcat ", not set: " (Remote>>LM:lst->str (cadr res) ", ")) "")
     )
    )
  )
)

(princ)
