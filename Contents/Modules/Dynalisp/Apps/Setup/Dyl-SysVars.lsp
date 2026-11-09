;; Dyl-SysVars - Dynalisp system variable profiles: the System Variable Monitor of DynALisp
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

;;  The window (Modules\Dynalisp\Res\Dyl-SysVars.dcl), like the System Variable Monitor of
;;  AutoCAD: the system variables of a profile with their preferred value, their current
;;  value and whether they differ. Profiles are created, copied, renamed and deleted here;
;;  the one shown on OK becomes the active profile. Reset all sets the preferred values in
;;  the current drawing right away.
;;
;;  The profiles, their files and the override that sets them in every drawing are in
;;  Modules\Dynalisp\Remote\Dyl-SysVars.lsp (System variables in Dyl-Settings, off by
;;  default; its ... button runs this command).

;;  The functions below run inside c:Dyl-SysVars and use its local variables:
;;    sv:sets - the profiles being edited: ((name (variable value) ...) ...)
;;    sv:pst  - index in sv:sets of the profile shown (the active one on OK)
;;    sv:old  - names of the profiles when the window opened (their files)
;;    sv:idx  - index of the row selected in the profile list
;;    sv:keep - the protected variables being edited: ((variable value) ...), sorted. Their
;;              value is set in every drawing whatever the profile, no profile changes
;;              them ("": protected only, not set; see Remote>>Dyl:SysVarKeep)
;;    sv:kidx - index of the protected variable selected
;;  Both lists show the same three columns: Variable, Preferred value, Current value. The
;;  current value is marked when the variable does not have its preferred value (see
;;  sv:state): "*" it differs, "(value not valid)", "(protected)" a profile row of a
;;  protected variable, "(unknown)" not a system variable of this AutoCAD.

;;  Rows of the profile shown:
(defun sv:rows () (cdr (nth sv:pst sv:sets)))

;;  Replace the rows of the profile shown:
(defun sv:store (rows)
  (setq sv:sets (Remote>>Dyl:ListSubst sv:sets sv:pst (cons (car (nth sv:pst sv:sets)) rows)))
)

;;  Index in sv:sets of the profile named nam (nil: none):
(defun sv:nameidx (nam)
  (if nam (vl-position (strcase nam) (mapcar '(lambda (s) (strcase (car s))) sv:sets)))
)

;;  rows ((variable value) ...) with var set to val (added or replaced), sorted by name:
(defun sv:addrow (rows var val)
  (vl-sort (cons (list var val) (vl-remove-if '(lambda (r) (= var (car r))) rows))
           '(lambda (a b) (< (car a) (car b)))
  )
)

;;  State of a row of the profile (kind 'profile) or of the protected variables ('keep):
;;  'same, 'differs, 'invalid (value not valid), 'unknown, 'protected (a profile row of a
;;  protected variable) or 'novalue (protected only):
(defun sv:state (r kind / val)
  (cond
    ((null (getvar (car r))) 'unknown)
    ((and (= kind 'profile) (assoc (car r) sv:keep)) 'protected)
    ((and (= kind 'keep) (= "" (cadr r))) 'novalue)
    ((null (setq val (Remote>>Dyl:SysVarValue (car r) (cadr r)))) 'invalid)
    ((Remote>>Dyl:SysVarSame-p (car r) val) 'same)
    ('differs)
  )
)

;;  List line of a row: variable, preferred value, current value with its mark:
(defun sv:line (r kind / st)
  (setq st (sv:state r kind))
  (strcat (car r)
          "\t"
          (cadr r)
          "\t"
          (if (= st 'unknown) "(unknown)" (Remote>>Dyl:SysVarText (getvar (car r))))
          ;;  No mark when the variable has its preferred value (or has none):
          (cond ((cdr (assoc st '((differs . "  *") (invalid . "  (value not valid)") (protected . "  (protected)"))))) (""))
  )
)

;;  Error of the variable var with the value val for a row of kind ('profile or 'keep),
;;  nil when the row can be added. A protected variable can have no value (protected only):
(defun sv:check (var val kind)
  (cond
    ((= "" var) "Type a system variable name.")
    ((null (getvar var)) (strcat var " is not a system variable."))
    ((and (= kind 'profile) (assoc var sv:keep))
     (strcat var " is protected: change its value in the protected variables.")
    )
    ((and (= kind 'keep) (= "" val)) nil)
    ((not (Remote>>Dyl:SysVarWritable-p var)) (strcat var " is read-only: it cannot be set."))
    ((null (Remote>>Dyl:SysVarValue var val))
     (strcat "Not a valid value for "
             var
             " (a "
             (cdr (assoc (type (getvar var)) '((INT . "whole number") (REAL . "number") (LIST . "point x,y or x,y,z") (STR . "text"))))
             ")."
     )
    )
  )
)

;;  Set the tiles from the values being edited:
(defun sv:fill (/ rows n)
  (start_list "pro")
  (foreach s sv:sets (add_list (car s)))
  (end_list)
  (set_tile "pro" (itoa sv:pst))
  (mode_tile "pdl" (if (cdr sv:sets) 0 1))
  (foreach k '("hdr" "khd")
    (start_list k)
    (add_list "Variable\tPreferred value\tCurrent value")
    (end_list)
  )
  (setq rows   (sv:rows)
        sv:idx (max 0 (min sv:idx (1- (length rows))))
  )
  (start_list "lst")
  (foreach r rows (add_list (sv:line r 'profile)))
  (end_list)
  (if rows (sv:pick sv:idx) (foreach k '("var" "val") (set_tile k "")))
  (mode_tile "del" (if rows 0 1))
  (mode_tile "rst" (if (or rows sv:keep) 0 1))
  (sv:fillkeep)
  (setq n (+ (length (vl-remove-if-not '(lambda (r) (= 'differs (sv:state r 'profile))) rows))
             (length (vl-remove-if-not '(lambda (r) (= 'differs (sv:state r 'keep))) sv:keep))
          )
  )
  (set_tile "msg"
            (cond
              ((not (or rows sv:keep)) "No variable: type one and its preferred value, then Add.")
              ((= 0 n) "Every variable has its preferred value.")
              ((strcat (itoa n) " variable(s) differ from their preferred value (marked *)."))
            )
  )
)

;;  Select the row i of the profile and show it in its edit boxes:
(defun sv:pick (i / r)
  (setq sv:idx i)
  (if (setq r (nth i (sv:rows)))
    (progn
      (set_tile "lst" (itoa i))
      (set_tile "var" (car r))
      (set_tile "val" (cadr r))
    )
  )
)

;;  Add the variable of the edit boxes to the profile, or replace its value when the
;;  profile has it. An error is shown and nothing changes:
(defun sv:add (/ var val rows err)
  (setq var (strcase (vl-string-trim " " (get_tile "var")))
        val (vl-string-trim " " (get_tile "val"))
  )
  (if (setq err (sv:check var val 'profile))
    (set_tile "msg" err)
    (progn
      (sv:store (setq rows (sv:addrow (sv:rows) var val)))
      (setq sv:idx (vl-position var (mapcar 'car rows)))
      (sv:fill)
    )
  )
)

;;  Put the current value of the variable of the box vkey in the value box key:
(defun sv:usecur (vkey key / var)
  (setq var (strcase (vl-string-trim " " (get_tile vkey))))
  (if (and (/= "" var) (getvar var))
    (set_tile key (Remote>>Dyl:SysVarText (getvar var)))
    (set_tile "msg" (strcat (if (= "" var) "Type" (strcat var " is not")) " a system variable."))
  )
)

;;  Remove the row selected of the profile:
(defun sv:remove ()
  (sv:store (Remote>>Dyl:ListRemove (sv:rows) sv:idx))
  (sv:fill)
)

;;  Reset all: set the preferred values in this drawing now, the protected variables and
;;  those of the profile shown (the protected ones of the profile skipped):
(defun sv:reset (/ res)
  (setq res (Remote>>Dyl:SysVarSetAll (sv:rows) sv:keep))
  (sv:fill)
  (set_tile "msg"
            (strcat (if (car res) (strcat (itoa (length (car res))) " variable(s) set.") "Nothing to set.")
                    (if (cadr res) (strcat " Not set: " (Remote>>LM:lst->str (cadr res) ", ") ".") "")
            )
  )
)

;;-------------------------=={ Protected variables }==------------------------;;

;;  Fill the protected variables list:
(defun sv:fillkeep ()
  (setq sv:kidx (max 0 (min sv:kidx (1- (length sv:keep)))))
  (start_list "kls")
  (foreach r sv:keep (add_list (sv:line r 'keep)))
  (end_list)
  (if sv:keep (sv:kpick sv:kidx) (foreach k '("kvr" "kvl") (set_tile k "")))
  (mode_tile "kdl" (if sv:keep 0 1))
)

;;  Select the protected variable i and show it in its edit boxes:
(defun sv:kpick (i / r)
  (setq sv:kidx i)
  (if (setq r (nth i sv:keep))
    (progn
      (set_tile "kls" (itoa i))
      (set_tile "kvr" (car r))
      (set_tile "kvl" (cadr r))
    )
  )
)

;;  Add the variable of the edit boxes to the protected variables, or replace its value
;;  (empty: protected only, not set). An error is shown and nothing changes:
(defun sv:keepadd (/ var val err)
  (setq var (strcase (vl-string-trim " " (get_tile "kvr")))
        val (vl-string-trim " " (get_tile "kvl"))
  )
  (if (setq err (sv:check var val 'keep))
    (set_tile "msg" err)
    (progn
      (setq sv:keep (sv:addrow sv:keep var val)
            sv:kidx (vl-position var (mapcar 'car sv:keep))
      )
      (sv:fill)
      (set_tile "msg"
                (strcat var
                        " protected"
                        (if (= "" val) " (no value: not set)" (strcat ", set to " val " in every drawing"))
                        ": no profile changes it."
                )
      )
    )
  )
)

;;  Remove the protected variable selected:
(defun sv:keepremove ()
  (if (nth sv:kidx sv:keep)
    (progn
      (setq sv:keep (Remote>>Dyl:ListRemove sv:keep sv:kidx))
      (sv:fill)
    )
  )
)

;;-------------------------=={ System variable list }==------------------------;;

;;  The list of every system variable is the one of the Express Tools (SYSVDLG command):
;;  Express\sysvdlg.dat of the AutoCAD installation, read where it is (not copied). Two
;;  lines per variable, the first starting with ! (can be set) or # (read-only):
;;    !PICKADD|Integer|Registry|2
;;    Controls whether subsequent selections replace ...\n\nValue\tDescription\n0\t\t...

;;  The file of this AutoCAD, nil without the Express Tools:
(defun sv:catfile (/ f)
  (cond
    ((findfile (setq f (strcat (vla-get-Path (vlax-get-acad-object)) "\\Express\\sysvdlg.dat"))) f)
    ((findfile "sysvdlg.dat"))
  )
)

;;  Text of the file with its \t written as spaces:
(defun sv:untab (s)
  (while (vl-string-search "\\t" s) (setq s (vl-string-subst "  " "\\t" s)))
  s
)

;;  Text cut to n characters ("..." added when cut):
(defun sv:cut (s n)
  (if (> (strlen s) n) (strcat (substr s 1 (- n 3)) "...") s)
)

;;  Every system variable: ((NAME short read-only type saved initial description) ...),
;;  sorted by name. short: the first paragraph of the description. Read once per session
;;  (*sv:catalog*), nil without the file:
(defun sv:catalog (/ f des hdr str fld pos lst)
  (cond
    (*sv:catalog*)
    ((and (setq f (sv:catfile)) (setq des (open f "r")))
     (while (setq str (read-line des))
       (cond
         ((and (not hdr) (member (substr str 1 1) '("!" "#")) (vl-string-search "|" str))
          (setq hdr str)
         )
         (hdr
          (setq fld (Remote>>LM:str->lst (substr hdr 2) "|"))
          ;;  The *_ names (*_TOOLPALETTEPATH) are not read with getvar:
          (if (not (wcmatch (car fld) "`**"))
            (setq pos (vl-string-search "\\n" str)
                  lst (cons (list (strcase (car fld))
                                  (sv:untab (if pos (substr str 1 pos) str))
                                  (= "#" (substr hdr 1 1))
                                  (cond ((cadr fld)) (""))
                                  (cond ((caddr fld)) (""))
                                  (cond ((cadddr fld)) (""))
                                  str
                            )
                            lst
                      )
            )
          )
          (setq hdr nil)
         )
       )
     )
     (close des)
     (setq *sv:catalog* (vl-sort lst '(lambda (a b) (< (car a) (car b)))))
    )
  )
)

;;  The functions below run inside sv:browse and use its local variables:
;;    br:all - every system variable (sv:catalog), br:lst - the ones listed (search),
;;    br:idx - index in br:lst of the variable selected

;;  Current value of a variable of the list, as listed:
(defun sv:brcur (v / c)
  (if (setq c (getvar (car v))) (sv:cut (Remote>>Dyl:SysVarText c) 15) "(not available)")
)

;;  List the variables whose name or short description has the search text flt:
(defun sv:brfill (flt / f)
  (setq f      (strcase (vl-string-trim " " flt))
        br:lst (if (= "" f)
                 br:all
                 (vl-remove-if-not '(lambda (v) (or (vl-string-search f (car v)) (vl-string-search f (strcase (cadr v)))))
                                   br:all
                 )
               )
        br:idx 0
  )
  (start_list "lst")
  (foreach v br:lst (add_list (strcat (car v) "\t" (sv:brcur v) "\t" (cadr v))))
  (end_list)
  (set_tile "cnt" (strcat (itoa (length br:lst)) " of " (itoa (length br:all)) " variables"))
  (if br:lst
    (progn (set_tile "lst" "0") (sv:brpick 0))
    (foreach k '("inf" "ds1" "ds2" "ds3") (set_tile k ""))
  )
)

;;  Show the variable i of the list: its type, where it is saved, its initial value and
;;  the first paragraphs of its description:
(defun sv:brpick (i / v pars)
  (setq br:idx i)
  (if (setq v (nth i br:lst))
    (progn
      (set_tile "inf"
                (strcat (car v) "  -  " (nth 3 v) ", saved in: " (nth 4 v) ", initial value: " (nth 5 v) (if (nth 2 v) "  (read-only)" ""))
      )
      (setq pars (vl-remove "" (Remote>>LM:str->lst (nth 6 v) "\\n")))
      (foreach k '("ds1" "ds2" "ds3")
        (set_tile k (if pars (sv:cut (sv:untab (car pars)) 140) ""))
        (setq pars (cdr pars))
      )
      (set_tile "msg" "")
    )
  )
)

;;  Add the variable selected to the list the window was opened from (mode): the profile
;;  shown ('profile) or the protected variables ('keep), its current value as preferred
;;  value. The result is shown in the window:
(defun sv:bradd (mode / v var cur rows)
  (if (setq v (nth br:idx br:lst))
    (set_tile
      "msg"
      (progn
        (setq var (car v))
        (cond
          ((assoc var (if (= mode 'keep) sv:keep (sv:rows)))
           (strcat var (if (= mode 'keep) " is already protected." " is already in the profile."))
          )
          ((and (= mode 'profile) (assoc var sv:keep))
           (strcat var " is protected: change its value in the protected variables.")
          )
          ((null (setq cur (getvar var))) (strcat var " is not available in this AutoCAD."))
          ((or (nth 2 v) (not (Remote>>Dyl:SysVarWritable-p var))) (strcat var " is read-only: it cannot be set."))
          ((= mode 'keep)
           (setq sv:keep (sv:addrow sv:keep var (Remote>>Dyl:SysVarText cur))
                 sv:kidx (vl-position var (mapcar 'car sv:keep))
           )
           (strcat var " protected with its current value (" (sv:cut (Remote>>Dyl:SysVarText cur) 30) "): change it in the protected variables.")
          )
          (T
           (sv:store (setq rows (sv:addrow (sv:rows) var (Remote>>Dyl:SysVarText cur))))
           (setq sv:idx (vl-position var (mapcar 'car rows)))
           (strcat var " added to the profile with its current value (" (sv:cut (Remote>>Dyl:SysVarText cur) 30) "): change it in the profile.")
          )
        )
      )
    )
  )
)

;;  Open the AutoCAD documentation of the variable selected (help.autodesk.com, in the
;;  release and language of this AutoCAD):
(defun sv:brdoc (/ v pth pos yr shl)
  (if (setq v (nth br:idx br:lst))
    (progn
      (setq pth (vla-get-Path (vlax-get-acad-object))
            pos (vl-string-search "AUTOCAD 20" (strcase pth))
            yr  (if pos (substr pth (+ pos 9) 4) "")
            yr  (if (wcmatch yr "####") yr "2026")
            shl (vl-catch-all-apply 'vla-getinterfaceobject (list (vlax-get-acad-object) "Shell.Application"))
      )
      (if
        (or (vl-catch-all-error-p shl)
            (vl-catch-all-error-p
              (vl-catch-all-apply
                'vlax-invoke-method
                (list shl
                      'ShellExecute
                      (strcat "https://help.autodesk.com/view/ACD/" yr "/" (getvar "LOCALE") "/?query=" (car v) "%20(System%20Variable)")
                      ""
                      ""
                      "open"
                      1
                )
              )
            )
        )
        (set_tile "msg" "Unable to open the documentation (no web browser?).")
      )
      (if (not (vl-catch-all-error-p shl)) (vlax-release-object shl))
    )
  )
)

;;  The list window (dyl_sysvars_list) over the main one. mode: 'profile when opened from
;;  the profile, 'keep from the protected variables: Add adds the variable selected to it
;;  (the window stays open to add others), a double-click closes the window and returns
;;  the variable, to put in the variable box (see sv:browsefill). nil otherwise:
(defun sv:browse (mode / br:all br:lst br:idx)
  (setq br:all (sv:catalog)
        br:idx 0
  )
  (if (new_dialog "dyl_sysvars_list" dcl:id)
    (progn
      (set_tile "ttl"
                (if (= mode 'keep)
                  "DynALisp - System Variables: add to the protected variables"
                  (strcat "DynALisp - System Variables: add to the profile " (car (nth sv:pst sv:sets)))
                )
      )
      (start_list "hdr")
      (add_list "Variable\tCurrent value\tDescription")
      (end_list)
      (sv:brfill "")
      (if (not br:all)
        (progn
          (set_tile "msg" "No list: Express\\sysvdlg.dat not found in this AutoCAD (install the Express Tools).")
          (foreach k '("flt" "add" "doc") (mode_tile k 1))
        )
      )
      (action_tile "flt" "(sv:brfill $value)")
      (action_tile "lst" "(sv:brpick (atoi $value)) (if (= 4 $reason) (done_dialog 2))")
      (action_tile "add" "(sv:bradd mode)")
      (action_tile "doc" "(sv:brdoc)")
      (Dyl:DocsTile "Setup\\Dyl-SysVars.htm")
      (if (= 2 (start_dialog)) (car (nth br:idx br:lst)))
    )
  )
)

;;  List... of the profile ('profile) or of the protected variables ('keep): the list
;;  window, then the variable double-clicked put in the variable box of that list (the
;;  row of the profile selected when it has the variable), ready to Add:
(defun sv:browsefill (mode / var i keys)
  (setq var  (sv:browse mode)
        keys (if (= mode 'keep) '("kvr" "kvl") '("var" "val"))
  )
  (sv:fill)
  (cond
    ((not var))
    ((setq i (vl-position var (mapcar 'car (if (= mode 'keep) sv:keep (sv:rows)))))
     (if (= mode 'keep) (sv:kpick i) (sv:pick i))
     (mode_tile (cadr keys) 2)
     (set_tile "msg" (strcat var (if (= mode 'keep) " is already protected" " is already in the profile") ": change its value, then Add."))
    )
    ;;  A new variable: its current value proposed as preferred value:
    (T
     (set_tile (car keys) var)
     (set_tile (cadr keys) (if (getvar var) (Remote>>Dyl:SysVarText (getvar var)) ""))
     (mode_tile (cadr keys) 2)
     (set_tile "msg" (strcat var ": its current value is proposed, change it if needed, then Add."))
    )
  )
)

;;-------------------------=={ Profiles }==------------------------;;

;;  Check a profile name, returns it trimmed, nil when it is not valid (the error is shown).
;;  skip: index of the profile being renamed (its own name is allowed):
(defun sv:namecheck (nam skip / n msg)
  (setq nam (vl-string-trim " \t." nam)
        n   -1
        msg (cond
              ((= "" nam) "The profile name cannot be empty.")
              ((vl-some '(lambda (c) (vl-string-search c nam)) '("\\" "/" ":" "*" "?" "\"" "<" ">" "|"))
               "A profile name cannot contain \\ / : * ? \" < > |"
              )
              ((vl-some '(lambda (s) (and (/= skip (setq n (1+ n))) (= (strcase nam) (strcase (car s))))) sv:sets)
               "Another profile already has this name."
              )
            )
  )
  (if msg
    (progn (set_tile "error" msg) (mode_tile "nam" 2) nil)
    nam
  )
)

;;  Ask a profile name (ttl: title of the window, nam: the name proposed, skip: see
;;  sv:namecheck). Returns nil on Cancel:
(defun sv:dlgname (ttl nam skip / res)
  (if (new_dialog "dyl_sysvars_name" dcl:id)
    (progn
      (set_tile "ttl" ttl)
      (set_tile "nam" nam)
      (mode_tile "nam" 2)
      (action_tile "accept" "(if (setq res (sv:namecheck (get_tile \"nam\") skip)) (done_dialog 1))")
      (if (= 1 (start_dialog)) res)
    )
  )
)

;;  New (mode 'new, no variable), Copy ('copy, the variables of the profile shown) or
;;  Rename ('rename) a profile:
(defun sv:profile (mode / cur nam)
  (setq cur (car (nth sv:pst sv:sets)))
  (if
    (setq nam (sv:dlgname (cond ((= mode 'new) "New Profile") ((= mode 'copy) "Copy Profile") ("Rename Profile"))
                          (cond ((= mode 'new) "") ((= mode 'copy) (strcat cur " - Copy")) (cur))
                          (if (= mode 'rename) sv:pst -1)
              )
    )
    (progn
      (setq sv:sets (if (= mode 'rename)
                      (Remote>>Dyl:ListSubst sv:sets sv:pst (cons nam (sv:rows)))
                      (append sv:sets (list (cons nam (if (= mode 'copy) (sv:rows)))))
                    )
            sv:sets (vl-sort sv:sets '(lambda (a b) (< (strcase (car a)) (strcase (car b)))))
            sv:pst  (sv:nameidx nam)
            sv:idx  0
      )
    )
  )
)

;;  Delete the profile shown (the last one cannot be):
(defun sv:delete ()
  (if (cdr sv:sets)
    (setq sv:sets (Remote>>Dyl:ListRemove sv:sets sv:pst)
          sv:pst  (min sv:pst (1- (length sv:sets)))
          sv:idx  0
    )
  )
  (sv:fill)
)

;;  Write the profiles: the files of the profiles sv:old deleted or renamed are deleted,
;;  every profile written, the one shown made active. Returns the names of the files that
;;  could not be written (open in Excel):
(defun sv:save (/ names err)
  ;;  The profiles are saved in the user copy of the folder (made the first time):
  (Remote>>Dyl:SysVarDirW)
  (setq names (mapcar '(lambda (s) (strcase (car s))) sv:sets))
  (foreach n sv:old
    (if (not (member (strcase n) names)) (vl-file-delete (Remote>>Dyl:SysVarFile n)))
  )
  (foreach s sv:sets
    (if (not (Remote>>LM:writecsv (cons *sv:header* (cdr s)) (Remote>>Dyl:SysVarFile (car s))))
      (setq err (cons (car s) err))
    )
  )
  (if (not (Remote>>Dyl:SysVarKeepWrite sv:keep)) (setq err (cons "protected variables" err)))
  (Remote>>Dyl:SysVarProfileSet (car (nth sv:pst sv:sets)))
  ;;  The drawings already open apply the change when made current (Dyl:SetSync):
  (Remote>>Dyl:SysVarStampSet)
  (setq SV:synced (Remote>>Dyl:SysVarStamp))
  (reverse err)
)

;; System Variables
;; Edits the system variable profiles: the preferred values set in every drawing while System variables is on (Dyl-Settings).

(defun c:Dyl-SysVars (/ dcl:id sv:sets sv:pst sv:old sv:idx sv:keep sv:kidx sta err)
  (setq sv:keep (Remote>>Dyl:SysVarKeep)
        sv:kidx 0
        sv:old  (Remote>>Dyl:SysVarProfiles)
        sv:sets (cond ((mapcar '(lambda (n) (cons n (Remote>>Dyl:SysVarRead n))) sv:old)) ((list (list "Default"))))
        sv:pst  (cond ((sv:nameidx (Remote>>Dyl:SysVarProfile))) (0))
        sv:idx  0
        dcl:id  (load_dialog (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\Dyl-SysVars.dcl"))
  )
  (cond
    ((> 0 dcl:id) (princ "\n--> Unable to load the dialog : Dyl-SysVars.dcl"))
    ((not (new_dialog "dyl_sysvars" dcl:id)) (princ "\n--> Unable to show the dialog : Dyl-SysVars.dcl"))
    (T
     (sv:fill)
     (action_tile "pro" "(setq sv:pst (atoi $value) sv:idx 0) (sv:fill)")
     (action_tile "pnw" "(sv:profile 'new) (sv:fill)")
     (action_tile "pcp" "(sv:profile 'copy) (sv:fill)")
     (action_tile "prn" "(sv:profile 'rename) (sv:fill)")
     (action_tile "pdl" "(sv:delete)")
     (action_tile "lst" "(sv:pick (atoi $value)) (set_tile \"msg\" \"\")")
     (action_tile "add" "(sv:add)")
     (action_tile "cur" "(sv:usecur \"var\" \"val\")")
     (action_tile "del" "(sv:remove)")
     (action_tile "rst" "(sv:reset)")
     (action_tile "kls" "(sv:kpick (atoi $value)) (set_tile \"msg\" \"\")")
     (action_tile "kad" "(sv:keepadd)")
     (action_tile "kcu" "(sv:usecur \"kvr\" \"kvl\")")
     ;; The list of every system variable, adding to the profile or to the protected ones:
     (action_tile "brw" "(sv:browsefill 'profile)")
     (action_tile "kbr" "(sv:browsefill 'keep)")
     (action_tile "kdl" "(sv:keepremove)")
     (action_tile "accept" "(done_dialog 1)")
     (action_tile "cancel" "(done_dialog 0)")
     (Dyl:DocsTile "Setup\\Dyl-SysVars.htm")
     (setq sta (start_dialog))
    )
  )
  (if (<= 0 dcl:id) (unload_dialog dcl:id))
  (cond
    ((/= 1 sta) (if (= 0 sta) (princ "\nSystem variables unchanged.")))
    ((setq err (sv:save))
     (princ (strcat "\n--> Not saved (file open in another program?): " (Remote>>LM:lst->str err ", ")))
    )
    ((Remote>>Dyl:SysVarOn-p)
     (princ (strcat "\nSystem variables saved, " (Remote>>Dyl:SysVarApply) "."))
    )
    ((princ (strcat "\nSystem variables saved (profile " (car (nth sv:pst sv:sets)) "). They are set in the drawings once System variables is on in Dyl-Settings.")))
  )
  (princ)
)

(princ)
