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

;;  The window (Modules\Dynalisp\Res\Dyl-SysVars.xaml), like the System Variable Monitor of
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
;;    sv:idx  - index of the row shown in the edit boxes of the profile list
;;    sv:sel  - indexes of the rows selected in the profile list (Ctrl / Shift click, see
;;              CONVENTIONS.md, Windows): Remove removes them all; the edit boxes show
;;              the first one (a value is for one variable: Add adds or replaces one)
;;    sv:keep - the protected variables being edited: ((variable value) ...), sorted. Their
;;              value is set in every drawing whatever the profile, no profile changes
;;              them ("": protected only, not set; see Remote>>Dyl:SysVarKeep)
;;    sv:kidx - index of the protected variable shown, sv:ksel - those selected (as sv:sel)
;;    sv:box  - the texts of the boxes kept when the window opens again: ((key . text) ...)
;;              (typed, or put by Use current or List...); a box without one shows the row
;;              picked
;;    sv:msg  - the line under the lists after a button (an error, what was done)
;;  The window runs alone while it is open: each button closes it with its number, and
;;  c:Dyl-SysVars does its work on these variables and shows it again (sv:vals, sv:get).
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

;;  Indexes picked in a list ("3" or "0 3 5", see Dyl:WinShow), and back:
(defun sv:lines (val)
  (read (strcat "(" (cond (val) ("")) ")"))
)
(defun sv:linestr (l)
  (if l (Remote>>LM:lst->str (mapcar 'itoa l) " ") "")
)

;;  The text of a box: the one kept (sv:box, typed or put by an action), else the field n
;;  of the row r:
(defun sv:boxval (key r n)
  (cond
    ((assoc key sv:box) (cdr (assoc key sv:box)))
    ((nth n r))
    ("")
  )
)

;;  Forget the texts of the boxes keys (they show the row picked again):
(defun sv:boxdrop (keys)
  (setq sv:box (vl-remove-if '(lambda (b) (member (car b) keys)) sv:box))
)

;;  Keep the text of the box key:
(defun sv:boxput (key val)
  (setq sv:box (cons (cons key val) (vl-remove-if '(lambda (b) (= key (car b))) sv:box)))
)

;;  The values of the window (Res\Dyl-SysVars.xaml) from the values being edited: the
;;  rows picked kept in range (the first one picked fills the boxes), the line under the
;;  lists (sv:msg, else how many variables differ):
(defun sv:vals (/ rows n)
  (setq rows    (sv:rows)
        sv:sel  (vl-remove-if-not '(lambda (i) (nth i rows)) sv:sel)
        sv:ksel (vl-remove-if-not '(lambda (i) (nth i sv:keep)) sv:ksel)
  )
  (if (and rows (not sv:sel)) (setq sv:sel (list (max 0 (min sv:idx (1- (length rows)))))))
  (if (and sv:keep (not sv:ksel)) (setq sv:ksel (list (max 0 (min sv:kidx (1- (length sv:keep)))))))
  (setq sv:idx  (cond ((car sv:sel)) (0))
        sv:kidx (cond ((car sv:ksel)) (0))
        n       (+ (length (vl-remove-if-not '(lambda (r) (= 'differs (sv:state r 'profile))) rows))
                   (length (vl-remove-if-not '(lambda (r) (= 'differs (sv:state r 'keep))) sv:keep))
                )
  )
  (append
    (Dyl:WinList "pro" (mapcar 'car sv:sets) sv:pst)
    (Dyl:WinOff "pdl" (not (cdr sv:sets)))
    (Dyl:WinOff "rst" (not (or rows sv:keep)))
    (list (cons "lst/list" (mapcar '(lambda (r) (sv:line r 'profile)) rows))
          (cons "lst" (sv:linestr sv:sel))
          (cons "var" (sv:boxval "var" (if sv:sel (nth sv:idx rows)) 0))
          (cons "val" (sv:boxval "val" (if sv:sel (nth sv:idx rows)) 1))
          (cons "kls/list" (mapcar '(lambda (r) (sv:line r 'keep)) sv:keep))
          (cons "kls" (sv:linestr sv:ksel))
          (cons "kvr" (sv:boxval "kvr" (if sv:ksel (nth sv:kidx sv:keep)) 0))
          (cons "kvl" (sv:boxval "kvl" (if sv:ksel (nth sv:kidx sv:keep)) 1))
          (cons "msg"
                (cond
                  (sv:msg)
                  ((not (or rows sv:keep)) "No variable: type one and its preferred value, then Add.")
                  ((= 0 n) "Every variable has its preferred value.")
                  ((strcat (itoa n) " variable(s) differ from their preferred value (marked *)."))
                )
          )
    )
  )
)

;;  The values got back: the profile shown, the rows picked and the texts of the boxes
;;  (kept, so a text typed is not lost when the window opens again):
(defun sv:get (res)
  (setq sv:pst  (min (Dyl:WinIdx res "pro") (1- (length sv:sets)))
        sv:sel  (sv:lines (Dyl:WinGet res "lst"))
        sv:ksel (sv:lines (Dyl:WinGet res "kls"))
        sv:idx  (cond ((car sv:sel)) (sv:idx))
        sv:kidx (cond ((car sv:ksel)) (sv:kidx))
        sv:box  (mapcar '(lambda (k) (cons k (cond ((Dyl:WinGet res k)) ("")))) '("var" "val" "kvr" "kvl"))
        sv:msg  nil
  )
)

;;  Add the variable of the boxes to the profile, or replace its value when the profile
;;  has it. An error is shown and nothing changes:
(defun sv:add (/ var val rows err)
  (setq var (strcase (vl-string-trim " " (sv:boxval "var" nil 0)))
        val (vl-string-trim " " (sv:boxval "val" nil 1))
  )
  (if (setq err (sv:check var val 'profile))
    (setq sv:msg err)
    (progn
      (sv:store (setq rows (sv:addrow (sv:rows) var val)))
      (setq sv:idx (vl-position var (mapcar 'car rows))
            sv:sel (list sv:idx)
      )
      (sv:boxdrop '("var" "val"))
    )
  )
)

;;  Put the current value of the variable of the box vkey in the value box key:
(defun sv:usecur (vkey key / var)
  (setq var (strcase (vl-string-trim " " (sv:boxval vkey nil 0))))
  (if (and (/= "" var) (getvar var))
    (sv:boxput key (Remote>>Dyl:SysVarText (getvar var)))
    (setq sv:msg (strcat (if (= "" var) "Type" (strcat var " is not")) " a system variable."))
  )
)

;;  Remove the rows selected of the profile:
(defun sv:remove (/ i)
  (if sv:sel
    (progn
      (setq i -1)
      (sv:store (vl-remove-if '(lambda (r) (member (setq i (1+ i)) sv:sel)) (sv:rows)))
      (setq sv:idx (apply 'min sv:sel)
            sv:sel nil
      )
      (sv:boxdrop '("var" "val"))
    )
  )
)

;;  Reset all: set the preferred values in this drawing now, the protected variables and
;;  those of the profile shown (the protected ones of the profile skipped):
(defun sv:reset (/ res)
  (setq res    (Remote>>Dyl:SysVarSetAll (sv:rows) sv:keep)
        sv:msg (strcat (if (car res) (strcat (itoa (length (car res))) " variable(s) set.") "Nothing to set.")
                       (if (cadr res) (strcat " Not set: " (Remote>>LM:lst->str (cadr res) ", ") ".") "")
               )
  )
)

;;-------------------------=={ Protected variables }==------------------------;;

;;  Add the variable of the boxes to the protected variables, or replace its value
;;  (empty: protected only, not set). An error is shown and nothing changes:
(defun sv:keepadd (/ var val err)
  (setq var (strcase (vl-string-trim " " (sv:boxval "kvr" nil 0)))
        val (vl-string-trim " " (sv:boxval "kvl" nil 1))
  )
  (if (setq err (sv:check var val 'keep))
    (setq sv:msg err)
    (progn
      (setq sv:keep (sv:addrow sv:keep var val)
            sv:kidx (vl-position var (mapcar 'car sv:keep))
            sv:ksel (list sv:kidx)
            sv:msg  (strcat var
                            " protected"
                            (if (= "" val) " (no value: not set)" (strcat ", set to " val " in every drawing"))
                            ": no profile changes it."
                    )
      )
      (sv:boxdrop '("kvr" "kvl"))
    )
  )
)

;;  Remove the protected variables selected:
(defun sv:keepremove (/ i)
  (if sv:ksel
    (progn
      (setq i       -1
            sv:keep (vl-remove-if '(lambda (r) (member (setq i (1+ i)) sv:ksel)) sv:keep)
            sv:kidx (apply 'min sv:ksel)
            sv:ksel nil
      )
      (sv:boxdrop '("kvr" "kvl"))
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

;;  Current value of a variable of the list, as listed:
(defun sv:brcur (v / c)
  (if (setq c (getvar (car v))) (sv:cut (Remote>>Dyl:SysVarText c) 15) "(not available)")
)

;;  What a variable of the list is: its type, where it is saved, its initial value:
(defun sv:brinfo (v)
  (strcat (car v) "  -  " (nth 3 v) ", saved in: " (nth 4 v) ", initial value: " (nth 5 v) (if (nth 2 v) "  (read-only)" ""))
)

;;  The first paragraphs of the description of a variable, one per line:
(defun sv:brdesc (v / pars res)
  (setq pars (vl-remove "" (Remote>>LM:str->lst (nth 6 v) "\\n")))
  (repeat (min 3 (length pars))
    (setq res  (cons (sv:cut (sv:untab (car pars)) 300) res)
          pars (cdr pars)
    )
  )
  (Remote>>LM:lst->str (reverse res) "\n")
)

;;  Line of a variable in the list: name, current value, short description, then what it
;;  is and its description (not shown in the list: they fill the Description box). No tab
;;  in a field (the columns are divided by tabs):
(defun sv:brline (v)
  (Remote>>LM:lst->str
    (mapcar '(lambda (s) (vl-string-translate "\t" " " s))
            (list (car v) (sv:brcur v) (cadr v) (sv:brinfo v) (sv:brdesc v))
    )
    "\t"
  )
)

;;  Add the variable v of the list to the list the window was opened from (mode): the
;;  profile shown ('profile) or the protected variables ('keep), its current value as
;;  preferred value. Returns what was done, shown in the window:
(defun sv:bradd (mode v / var cur rows)
  (if v
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
               sv:ksel (list sv:kidx)
         )
         (sv:boxdrop '("kvr" "kvl"))
         (strcat var " protected with its current value (" (sv:cut (Remote>>Dyl:SysVarText cur) 30) "): change it in the protected variables.")
        )
        (T
         (sv:store (setq rows (sv:addrow (sv:rows) var (Remote>>Dyl:SysVarText cur))))
         (setq sv:idx (vl-position var (mapcar 'car rows))
               sv:sel (list sv:idx)
         )
         (sv:boxdrop '("var" "val"))
         (strcat var " added to the profile with its current value (" (sv:cut (Remote>>Dyl:SysVarText cur) 30) "): change it in the profile.")
        )
      )
    )
    ""
  )
)

;;  Open the AutoCAD documentation of the variable v (help.autodesk.com, in the release
;;  and language of this AutoCAD). Returns a message when it could not, nil else:
(defun sv:brdoc (v / pth pos yr shl msg)
  (if v
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
        (setq msg "Unable to open the documentation (no web browser?).")
      )
      (if (not (vl-catch-all-error-p shl)) (vlax-release-object shl))
      msg
    )
  )
)

;;  The list window (Res\Dyl-SysVarsList.xaml), once the main one is closed. mode: 'profile
;;  when opened from the profile, 'keep from the protected variables: Add adds the variable
;;  selected to it and AutoCAD Help opens its page (the window is shown again, its search
;;  and the variable picked kept); a double-click closes it and returns the variable, to
;;  put in the box of that list (see sv:browsefill). nil otherwise:
(defun sv:browse (mode / all lines res sta msg flt idx v ret)
  (setq all   (sv:catalog)
        lines (mapcar 'sv:brline all)
        idx   0
        flt   ""
        sta   T
  )
  (while sta
    (setq v   (nth idx all)
          res (Dyl:WinShow
                "Dyl-SysVarsList.xaml"
                (append
                  (list (cons "win/title"
                              (if (= mode 'keep)
                                "DynALisp - System Variables: add to the protected variables"
                                (strcat "DynALisp - System Variables: add to the profile " (car (nth sv:pst sv:sets)))
                              )
                        )
                        (cons "flt" flt)
                        (cons "lst/list" lines)
                        (cons "lst" (if all (itoa idx) "-1"))
                        (cons "inf" (if v (sv:brinfo v) ""))
                        (cons "dsc" (if v (sv:brdesc v) ""))
                        (cons "msg"
                              (cond
                                (msg)
                                ((not all) "No list: Express\\sysvdlg.dat not found in this AutoCAD (install the Express Tools).")
                                ("")
                              )
                        )
                  )
                  (Dyl:WinOff '("flt" "add" "doc") (not all))
                )
              )
          sta (if res (car res))
          msg nil
    )
    (if (member sta '(2 3 4))
      (setq idx (Dyl:WinIdx res "lst")
            flt (cond ((Dyl:WinGet res "flt")) (""))
            v   (nth idx all)
      )
    )
    (cond
      ((= 2 sta) (setq msg (sv:bradd mode v)))
      ((= 4 sta) (setq msg (sv:brdoc v)))
      ((= 3 sta) (setq ret (car v) sta nil))
      ((setq sta nil))
    )
  )
  ret
)

;;  List... of the profile ('profile) or of the protected variables ('keep): the list
;;  window, then the variable double-clicked put in the box of that list (the row of the
;;  profile selected when it has the variable), ready to Add:
(defun sv:browsefill (mode / var i keys)
  (setq var  (sv:browse mode)
        keys (if (= mode 'keep) '("kvr" "kvl") '("var" "val"))
  )
  (cond
    ((not var))
    ((setq i (vl-position var (mapcar 'car (if (= mode 'keep) sv:keep (sv:rows)))))
     (if (= mode 'keep)
       (setq sv:kidx i sv:ksel (list i))
       (setq sv:idx i sv:sel (list i))
     )
     (sv:boxdrop keys)
     (setq sv:msg (strcat var (if (= mode 'keep) " is already protected" " is already in the profile") ": change its value, then Add."))
    )
    ;;  A new variable: its current value proposed as preferred value:
    (T
     (sv:boxput (car keys) var)
     (sv:boxput (cadr keys) (if (getvar var) (Remote>>Dyl:SysVarText (getvar var)) ""))
     (setq sv:msg (strcat var ": its current value is proposed, change it if needed, then Add."))
    )
  )
)

;;-------------------------=={ Profiles }==------------------------;;

;;  Why the profile name nam (trimmed) is not valid, nil when it is. skip: index of the
;;  profile being renamed (its own name is allowed):
(defun sv:nameerr (nam skip / n)
  (setq n -1)
  (cond
    ((= "" nam) "The profile name cannot be empty.")
    ((vl-some '(lambda (c) (vl-string-search c nam)) '("\\" "/" ":" "*" "?" "\"" "<" ">" "|"))
     "A profile name cannot contain \\ / : * ? \" < > |"
    )
    ((vl-some '(lambda (s) (and (/= skip (setq n (1+ n))) (= (strcase nam) (strcase (car s))))) sv:sets)
     "Another profile already has this name."
    )
  )
)

;;  Ask a profile name (Res\Dyl-Name.xaml; ttl: title of the window, nam: the name proposed,
;;  skip: see sv:nameerr). A name refused shows the window again with why. Returns the name,
;;  nil on Cancel:
(defun sv:dlgname (ttl nam skip / res err ret)
  (while
    (and (setq res (Dyl:WinShow "Dyl-Name.xaml"
                                (list (cons "win/title" (strcat "DynALisp - " ttl))
                                      (cons "lbl" "Profile name")
                                      (cons "nam" nam)
                                      (cons "error" (cond (err) ("")))
                                )
                   )
         )
         (= 1 (car res))
         (setq nam (vl-string-trim " \t." (cond ((Dyl:WinGet res "nam")) (""))))
         (setq err (sv:nameerr nam skip))
    )
  )
  (if (and res (= 1 (car res)) (not err)) nam)
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
            sv:sel  nil
      )
      (sv:boxdrop '("var" "val"))
    )
  )
)

;;  Delete the profile shown (the last one cannot be):
(defun sv:delete ()
  (if (cdr sv:sets)
    (progn
      (setq sv:sets (Remote>>Dyl:ListRemove sv:sets sv:pst)
            sv:pst  (min sv:pst (1- (length sv:sets)))
            sv:idx  0
            sv:sel  nil
      )
      (sv:boxdrop '("var" "val"))
    )
  )
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

(defun c:Dyl-SysVars (/ sv:sets sv:pst sv:old sv:idx sv:sel sv:keep sv:kidx sv:ksel sv:box sv:msg res sta err)
  (setq sv:keep (Remote>>Dyl:SysVarKeep)
        sv:kidx 0
        sv:old  (Remote>>Dyl:SysVarProfiles)
        sv:sets (cond ((mapcar '(lambda (n) (cons n (Remote>>Dyl:SysVarRead n))) sv:old)) ((list (list "Default"))))
        sv:pst  (cond ((sv:nameidx (Remote>>Dyl:SysVarProfile))) (0))
        sv:idx  0
        sta     2
  )
  ;;  The window is shown again after each button but OK and Cancel (see its file):
  (while (and sta (< 1 sta))
    (setq res (Dyl:WinShow "Dyl-SysVars.xaml" (sv:vals))
          sta (if res (car res))
    )
    (if (and sta (< 1 sta))
      (progn
        (sv:get res)
        (cond
          ;;  Another profile picked: its first row shown:
          ((= 2 sta) (setq sv:idx 0 sv:sel nil) (sv:boxdrop '("var" "val")))
          ((= 3 sta) (sv:profile 'new))
          ((= 4 sta) (sv:profile 'copy))
          ((= 5 sta) (sv:profile 'rename))
          ((= 6 sta) (sv:delete))
          ((= 7 sta) (sv:add))
          ((= 8 sta) (sv:usecur "var" "val"))
          ;; The list of every system variable, adding to the profile or to the protected ones:
          ((= 9 sta) (sv:browsefill 'profile))
          ((= 10 sta) (sv:remove))
          ((= 11 sta) (sv:reset))
          ((= 12 sta) (sv:keepadd))
          ((= 13 sta) (sv:usecur "kvr" "kvl"))
          ((= 14 sta) (sv:browsefill 'keep))
          ((= 15 sta) (sv:keepremove))
        )
      )
    )
  )
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
