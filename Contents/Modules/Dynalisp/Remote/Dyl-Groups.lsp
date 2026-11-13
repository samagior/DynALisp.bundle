;; Groups - The groups of the presets and hatch presets, and the Preset Groups window
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

;;  The Group popup of every preset window (Quick Draw, Quick Shape, Hatch Presets) lists the
;;  same groups: those of Res\Groups.csv (one group per row, header "Group"; the user's copy
;;  under User, see Dyl:UserFile), edited in the Preset Groups window opened by the open
;;  button beside each Group popup (Remote>>Dyl:GroupsDialog). A group renamed there is
;;  renamed in the files of every preset tool (see Remote>>Dyl:GroupsRename), so the groups of
;;  the presets and of their hatch presets stay the same. This file loads before
;;  Dyl-Materials.lsp and Dyl-Paths.lsp (the readers of the presets files use it).
;;
;;    (Remote>>Dyl:Groups)          -> the groups, in their order
;;    (Remote>>Dyl:GroupCase g)     -> g as written in the groups (any case), else g
;;    (Remote>>Dyl:GroupsDialog n)  -> the Preset Groups window, n: presets using each group

;;  The groups when Groups.csv cannot be read: by the kind of drawing they are used in, the
;;  plans by their type:
(setq *grp:defaults* '("Floor" "Wall" "Ceiling" "Roof" "Finish" "Structural" "Site"
                       "Elevation" "Section" "Detail" "Annotation" "Phase" "Area" "Generic"
                      )
)

;;  The default groups file (Res\Groups.csv under Contents):
(defun Remote>>Dyl:GroupsFile ()
  (strcat (if *dyl:dylres *dyl:dylres(strcat *dyl:dyl "\\Res")) "\\Groups.csv")
)

;;  The groups of the file f: its rows, without the empty and repeated ones (any case), nil
;;  when it has none:
(defun Remote>>Dyl:GroupsRead (f / lst)
  (foreach r (if (and f (findfile f)) (Remote>>Dyl:CsvRead f 1))
    (if (and (/= "" (car r)) (not (member (strcase (car r)) (mapcar 'strcase lst))))
      (setq lst (cons (car r) lst))
    )
  )
  (reverse lst)
)

;;  The groups (the user's copy of Groups.csv, else the default one), read again only when
;;  the file changed (*grp:cache*: (file date) . groups):
(defun Remote>>Dyl:Groups (/ f k)
  (setq f (Dyl:UserFile (Remote>>Dyl:GroupsFile))
        k (list f (if (findfile f) (vl-file-systime f)))
  )
  (if (not (equal k (car *grp:cache*)))
    (setq *grp:cache* (cons k (cond ((Remote>>Dyl:GroupsRead f)) (*grp:defaults*))))
  )
  (cdr *grp:cache*)
)

;;  The default groups (Res\Groups.csv as shipped, never its user copy):
(defun Remote>>Dyl:GroupsDefaults ()
  (cond ((Remote>>Dyl:GroupsRead (Remote>>Dyl:GroupsFile))) (*grp:defaults*))
)

;;  The group g as written in the groups (any case: "section" -> "Section"), else g itself
;;  (a group typed in a presets file that is not one of them is kept):
(defun Remote>>Dyl:GroupCase (g)
  (cond
    ((vl-some '(lambda (x) (if (= (strcase x) (strcase g)) x)) (Remote>>Dyl:Groups)))
    (g)
  )
)

;;  Save the groups lst (the user's copy of Groups.csv). Returns T, nil when it cannot be
;;  written (open in Excel):
(defun Remote>>Dyl:GroupsWrite (lst)
  (if (Remote>>LM:writecsv (cons '("Group") (mapcar 'list lst)) (Dyl:UserFileW (Remote>>Dyl:GroupsFile)))
    (progn (setq *grp:cache* nil) t)
  )
)

;;  The group g once the renames pairs ((old . new) ...) are applied (any case):
(defun Remote>>Dyl:GroupRenamed (g pairs / p)
  (if (setq p (vl-some '(lambda (x) (if (= (strcase (car x)) (strcase g)) x)) pairs)) (cdr p) g)
)

;;  Rename the groups of the renames pairs ((old . new) ...) in the files of every preset tool
;;  (*dyl:presetspecs*: Quick Draw, Quick Shape, the hatch presets...), saved now: each file
;;  as it is on disk (the user's copy, else the default), its other values kept. Returns the
;;  tools whose file could not be written:
(defun Remote>>Dyl:GroupsRename (pairs / key rows new bad)
  (foreach spec *dyl:presetspecs*
    (setq key  (car spec)
          rows (Remote>>Dyl:PresetCsv key)
          new  (mapcar '(lambda (r) (cons (car r) (cons (Remote>>Dyl:GroupRenamed (nth 1 r) pairs) (cddr r)))) rows)
    )
    (if (and (not (equal rows new))
             (not (Remote>>LM:writecsv (cons (Remote>>Dyl:PresetProp key 'header) new) (Remote>>Dyl:PresetFileW key)))
        )
      (setq bad (cons (Remote>>Dyl:PresetProp key 'title) bad))
    )
  )
  bad
)

;;-------------------------=={ Preset Groups window }==------------------------;;

;;  The functions below run inside Remote>>Dyl:GroupsDialog and use its local variables:
;;  gp:lst (the groups being edited), gp:map (((original . current) ...): the groups of the
;;  file and their name now, to rename them on OK), gp:used (((group . n) ...): the presets
;;  using each group, for the messages).

;;  Write the window to a temporary DCL file, returns its path:
(defun Remote>>Dyl:GroupsDcl (/ path file)
  (setq path (vl-filename-mktemp "grp" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("dyl_grp : dialog { label = \"DynALisp - Preset Groups\";"
      "  : row {"
      "    : list_box { key = \"gl\"; label = \"Groups (the order of the Group lists):\"; width = 30; height = 16; multiple_select = true; }"
      "    : column {"
      "      : edit_box { key = \"gn\"; label = \"Name:\"; edit_width = 20; edit_limit = 32; }"
      "      : button { key = \"ga\"; label = \"Add\"; }"
      "      : button { key = \"gr\"; label = \"Rename\"; }"
      "      : button { key = \"gd\"; label = \"Remove\"; }"
      "      : button { key = \"gu\"; label = \"Move up\"; }"
      "      : button { key = \"gw\"; label = \"Move down\"; }"
      "      : button { key = \"gz\"; label = \"Reset\"; }"
      "      : spacer { }"
      "    }"
      "  }"
      "  : text { key = \"gm\"; width = 64; }"
      "  : row {"
      "    : spacer { }"
      "    : button { label = \"OK\"; key = \"accept\"; is_default = true; width = 12; fixed_width = true; }"
      "    : button { label = \"Cancel\"; key = \"cancel\"; is_cancel = true; width = 12; fixed_width = true; }"
      "    : button { label = \"Open Docs\"; key = \"docs\"; width = 12; fixed_width = true; }"
      "  }"
      "}"
     )
    (write-line line file)
  )
  (close file)
  path
)

;;  Indexes of the groups selected in the list:
(defun Remote>>Dyl:GroupsDlgSel ()
  (read (strcat "(" (get_tile "gl") ")"))
)

;;  Fill the list with gp:lst, the groups sel (indexes) selected, msg shown under it; the
;;  buttons for one group (Rename, Move up, Move down) greyed out unless one is selected,
;;  Remove unless one or more are:
(defun Remote>>Dyl:GroupsDlgFill (sel msg)
  (start_list "gl")
  (foreach g gp:lst
    (add_list (strcat g (if (assoc (strcase g) gp:used) (strcat "  (" (itoa (cdr (assoc (strcase g) gp:used))) ")") "")))
  )
  (end_list)
  (set_tile "gl" (cond ((Remote>>LM:lst->str (mapcar 'itoa sel) " ")) ("")))
  (Remote>>Dyl:GroupsDlgPick msg)
)

;;  The selection changed: its group in the name box (one selected), the state of the buttons:
(defun Remote>>Dyl:GroupsDlgPick (msg / sel)
  (setq sel (Remote>>Dyl:GroupsDlgSel))
  (if (and sel (not (cdr sel))) (set_tile "gn" (nth (car sel) gp:lst)))
  (foreach k '("gr" "gu" "gw") (mode_tile k (if (and sel (not (cdr sel))) 0 1)))
  (mode_tile "gd" (if sel 0 1))
  (set_tile "gm" (cond (msg) ("")))
)

;;  Error message for the group name g (nil when valid), skip: the index of the group renamed:
(defun Remote>>Dyl:GroupsDlgCheck (g skip / i)
  (setq i -1)
  (cond
    ((= "" g) "Type a group name.")
    ((wcmatch g "*[;\",]*") "A group name cannot have ; , or \".")
    ((vl-some '(lambda (x) (setq i (1+ i)) (and (/= i skip) (= (strcase x) (strcase g)))) gp:lst)
     (strcat "There is already a group " g ".")
    )
  )
)

;;  Add: the name typed, after the group selected (else last):
(defun Remote>>Dyl:GroupsDlgAdd (/ g err sel i)
  (setq g   (vl-string-trim " " (get_tile "gn"))
        sel (Remote>>Dyl:GroupsDlgSel)
  )
  (if (setq err (Remote>>Dyl:GroupsDlgCheck g nil))
    (set_tile "gm" err)
    (progn
      (setq i      (if sel (1+ (apply 'max sel)) (length gp:lst))
            gp:lst (append (Remote>>Dyl:GroupsTake gp:lst i) (list g) (Remote>>Dyl:GroupsDrop gp:lst i))
      )
      (Remote>>Dyl:GroupsDlgFill (list i) (strcat g " added."))
    )
  )
)

;;  The first n items of lst, lst without them:
(defun Remote>>Dyl:GroupsTake (lst n / res)
  (repeat (min n (length lst)) (setq res (cons (car lst) res) lst (cdr lst)))
  (reverse res)
)
(defun Remote>>Dyl:GroupsDrop (lst n)
  (repeat (min n (length lst)) (setq lst (cdr lst)))
  lst
)

;;  Rename: the group selected gets the name typed (renamed in the presets on OK):
(defun Remote>>Dyl:GroupsDlgRename (/ sel old g err)
  (setq sel (car (Remote>>Dyl:GroupsDlgSel))
        old (nth sel gp:lst)
        g   (vl-string-trim " " (get_tile "gn"))
  )
  (cond
    ((= g old) (set_tile "gm" "The name did not change."))
    ((setq err (Remote>>Dyl:GroupsDlgCheck g sel)) (set_tile "gm" err))
    (T
     (setq gp:lst (Remote>>Dyl:ListSubst gp:lst sel g)
           gp:map (mapcar '(lambda (x) (if (= (cdr x) old) (cons (car x) g) x)) gp:map)
     )
     (Remote>>Dyl:GroupsDlgFill
       (list sel)
       (strcat old " renamed " g (if (assoc (strcase old) gp:used) " (in the presets too, on OK)." "."))
     )
    )
  )
)

;;  Remove: the groups selected (the presets in them keep their group, still listed in the
;;  Group lists of their window):
(defun Remote>>Dyl:GroupsDlgRemove (/ sel gone n)
  (setq sel    (Remote>>Dyl:GroupsDlgSel)
        gone   (mapcar '(lambda (i) (nth i gp:lst)) sel)
        gp:lst (vl-remove-if '(lambda (g) (member g gone)) gp:lst)
        gp:map (vl-remove-if '(lambda (x) (member (cdr x) gone)) gp:map)
        n      (apply '+ (mapcar '(lambda (g) (cond ((cdr (assoc (strcase g) gp:used))) (0))) gone))
  )
  (Remote>>Dyl:GroupsDlgFill
    nil
    (strcat (itoa (length gone))
            " group(s) removed."
            (if (< 0 n) (strcat " " (itoa n) " preset(s) keep their group.") "")
    )
  )
)

;;  Move up (d -1) / Move down (d 1) the group selected:
(defun Remote>>Dyl:GroupsDlgMove (d / i j g)
  (setq i (car (Remote>>Dyl:GroupsDlgSel))
        j (+ i d)
  )
  (if (and (<= 0 j) (< j (length gp:lst)))
    (progn
      (setq g      (nth i gp:lst)
            gp:lst (Remote>>Dyl:ListSubst (Remote>>Dyl:ListSubst gp:lst i (nth j gp:lst)) j g)
      )
      (Remote>>Dyl:GroupsDlgFill (list j) nil)
    )
  )
)

;;  Reset: the default groups (nothing renamed):
(defun Remote>>Dyl:GroupsDlgReset ()
  (setq gp:lst (Remote>>Dyl:GroupsDefaults)
        gp:map (vl-remove-if-not '(lambda (x) (member (car x) gp:lst)) (mapcar '(lambda (x) (cons (car x) (car x))) gp:map))
  )
  (Remote>>Dyl:GroupsDlgFill nil "The default groups (saved on OK).")
)

;;  The Preset Groups window: add, rename, remove and order the groups. used: the number of
;;  presets in each group (((group . n) ...), any case, shown beside each group). OK saves the
;;  groups (Groups.csv) and renames the groups renamed in the files of every preset tool (see
;;  Remote>>Dyl:GroupsRename). Returns the renames ((old . new) ...) on OK (nil: none, or T),
;;  nil on Cancel; the caller renames them in the presets it is editing:
(defun Remote>>Dyl:GroupsDialog (used / gp:lst gp:map gp:used dcl id sta pairs bad)
  (setq gp:lst  (Remote>>Dyl:Groups)
        gp:map  (mapcar '(lambda (g) (cons g g)) gp:lst)
        gp:used (mapcar '(lambda (x) (cons (strcase (car x)) (cdr x))) used)
        dcl     (Remote>>Dyl:GroupsDcl)
        id      (load_dialog dcl)
  )
  (if (and (<= 0 id) (new_dialog "dyl_grp" id))
    (progn
      (Remote>>Dyl:GroupsDlgFill nil nil)
      (Dyl:DocsTile "Draw\\Dyl-PresetGroups.htm")
      (action_tile "gl" "(Remote>>Dyl:GroupsDlgPick nil)")
      (action_tile "ga" "(Remote>>Dyl:GroupsDlgAdd)")
      (action_tile "gr" "(Remote>>Dyl:GroupsDlgRename)")
      (action_tile "gd" "(Remote>>Dyl:GroupsDlgRemove)")
      (action_tile "gu" "(Remote>>Dyl:GroupsDlgMove -1)")
      (action_tile "gw" "(Remote>>Dyl:GroupsDlgMove 1)")
      (action_tile "gz" "(Remote>>Dyl:GroupsDlgReset)")
      (action_tile "accept" "(if gp:lst (done_dialog 1) (set_tile \"gm\" \"Keep at least one group.\"))")
      (setq sta (start_dialog))
    )
    (alert "\nError: the Preset Groups window could not be loaded")
  )
  (if (<= 0 id) (unload_dialog id))
  (vl-file-delete dcl)
  (if (= 1 sta)
    (if (Remote>>Dyl:GroupsWrite gp:lst)
      (progn
        (setq pairs (vl-remove-if '(lambda (x) (= (car x) (cdr x))) gp:map))
        ;;  The renames of the session, in their order: every preset window open renames them
        ;;  in the presets it is editing (see Remote>>Dyl:PresetDlgGroupsSync):
        (if pairs (setq *grp:renames* (append *grp:renames* (list pairs))))
        (if (setq bad (Remote>>Dyl:GroupsRename pairs))
          (alert (strcat "The groups could not be renamed in the presets of: "
                         (Remote>>LM:lst->str bad ", ")
                         " (is the file open in Excel?)."
                 )
          )
        )
        (cond (pairs) (T))
      )
      (progn (alert "The groups could not be saved: is Groups.csv open in Excel?") nil)
    )
  )
)
