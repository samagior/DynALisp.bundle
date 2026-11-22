;; Groups - The groups of the presets and materials, and the Preset Groups window
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

;;  The Group popup of every preset window (Quick Draw, Quick Shape, Materials) lists the
;;  same groups: those of Res\Groups.csv (one group per row, header "Group"; the user's copy
;;  under User, see Dyl:UserFile), edited in the Preset Groups window opened by the open
;;  button beside each Group popup (Remote>>Dyl:GroupsDialog). A group renamed there is
;;  renamed in the files of every preset tool (see Remote>>Dyl:GroupsRename), so the groups of
;;  the presets and of their materials stay the same. This file loads before
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
;;  (*dyl:presetspecs*: Quick Draw, Quick Shape, the materials...), saved now: each file
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

;;  The Preset Groups window (Res\Dyl-PresetGroups.xaml, shown by DynALisp.Windows.dll): its
;;  groups are a list of rows edited in the window itself (Installer\Windows\Engine\Rows.cs),
;;  a row per group: (name presets original), its name, how many presets use it (shown only)
;;  and its name in the file ("" for a group added), so that the groups renamed are renamed in
;;  the presets on OK. The window checks the names (not empty, without ; , or ", one of each).

;;  The first n items of lst, lst without them:
(defun Remote>>Dyl:GroupsTake (lst n / res)
  (repeat (min n (length lst)) (setq res (cons (car lst) res) lst (cdr lst)))
  (reverse res)
)
(defun Remote>>Dyl:GroupsDrop (lst n)
  (repeat (min n (length lst)) (setq lst (cdr lst)))
  lst
)

;;  The row of the group g of the window, its name in the file org ("": added), used: the
;;  presets using each group (((GROUP . n) ...)):
(defun Remote>>Dyl:GroupsRow (g org used / n)
  (setq n (cdr (assoc (strcase org) used)))
  (list g (cond ((not n) "") ((= 1 n) "1 preset") ((strcat (itoa n) " presets"))) org)
)

;;  The problem of the names of groups lst (nil: none): a name with ; , or " (the
;;  separators of the CSV files), or given twice (any case):
(defun Remote>>Dyl:GroupsCheck (lst / bad seen)
  (foreach g lst
    (cond
      (bad)
      ((vl-some '(lambda (c) (vl-string-search c g)) '(";" "," "\""))
       (setq bad (strcat "The group " g " cannot hold ; , or \"."))
      )
      ((member (strcase g) seen) (setq bad (strcat "The group " g " is given twice.")))
      ((setq seen (cons (strcase g) seen)))
    )
  )
  bad
)

;;  The Preset Groups window: add, rename, remove and order the groups. used: the number of
;;  presets in each group (((group . n) ...), any case, shown beside each group). OK saves the
;;  groups (Groups.csv) and renames the groups renamed in the files of every preset tool (see
;;  Remote>>Dyl:GroupsRename). Returns the renames ((old . new) ...) on OK (nil: none, or T),
;;  nil on Cancel; the caller renames them in the presets it is editing:
(defun Remote>>Dyl:GroupsDialog (used / org res rows lst pairs bad msg)
  (setq used (mapcar '(lambda (x) (cons (strcase (car x)) (cdr x))) used)
        org  (Remote>>Dyl:Groups)
        rows (mapcar '(lambda (g) (Remote>>Dyl:GroupsRow g g used)) org)
  )
  ;;  Shown again on the rows edited while a name is not valid (checked here too, the window
  ;;  checks them first):
  (while
    (progn
      (setq res  (Dyl:WinShow
               "Dyl-PresetGroups.xaml"
               (list (cons "gl/rows" rows)
                     ;;  Reset: the default groups, those of the file keep their presets:
                     (cons "gl/defs"
                           (mapcar '(lambda (g) (Remote>>Dyl:GroupsRow g (if (member g org) g "") used))
                                   (Remote>>Dyl:GroupsDefaults)
                           )
                     )
                     (list "gl/new" (list "New group" "" ""))
               )
             )
      )
      (if (= 1 (car res))
        (progn
          (setq rows (vl-remove-if '(lambda (x) (= "" (vl-string-trim " " (car x)))) (cdr (assoc "gl/rows" (cdr res))))
                lst  (mapcar '(lambda (x) (vl-string-trim " " (car x))) rows)
                msg  (Remote>>Dyl:GroupsCheck lst)
          )
          (if msg (progn (alert msg) T))
        )
      )
    )
  )
  (if (= 1 (car res))
    (progn
      (cond
        ((not lst) (alert "Keep at least one group.") nil)
        ((Remote>>Dyl:GroupsWrite lst)
         (setq pairs (vl-remove-if '(lambda (x) (or (= "" (car x)) (= (car x) (cdr x))))
                                   (mapcar '(lambda (x) (cons (caddr x) (vl-string-trim " " (car x)))) rows)
                     )
         )
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
        (T (alert "The groups could not be saved: is Groups.csv open in Excel?") nil)
      )
    )
  )
)
