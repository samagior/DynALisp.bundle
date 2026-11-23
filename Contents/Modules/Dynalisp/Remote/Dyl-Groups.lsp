;; Groups - The groups of the presets and of the materials, and the Preset Groups window
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

;;  Two lists of groups, each one a file of one group per row (header "Group"; the user's
;;  copy under User, see Dyl:UserFile), its kind k:
;;
;;    nil         the groups of the presets (Res\Groups.csv): by the kind of drawing they are
;;                used in (Quick Draw, Quick Shape, the assemblies, the hatch presets)
;;    "Material"  the groups of the materials (Res\MaterialGroups.csv): by what they are made
;;                of (Masonry, Wood, Insulation...); the Group list of the Materials window,
;;                and the material Group list beside the Material list of a preset window
;;                and of a layer of an assembly
;;
;;  The Group popup of every preset window lists the groups of its kind ((groups . T) or
;;  (groups . "Material") of its dialog), edited in the Preset Groups window opened by the open
;;  button beside it (Remote>>Dyl:GroupsDialogOf). A group renamed there is renamed in the
;;  files of every preset tool of that kind ((groups . "Material") of its spec in
;;  *dyl:presetspecs*, see Remote>>Dyl:GroupsRenameOf). This file loads before
;;  Dyl-Materials.lsp and Dyl-Paths.lsp (the readers of the presets files use it).
;;
;;    (Remote>>Dyl:Groups)              -> the groups of the presets, in their order
;;    (Remote>>Dyl:GroupsOf k)          -> the groups of the kind k, in their order
;;    (Remote>>Dyl:GroupCase g)         -> g as written in the groups of the presets (any
;;                                         case), else g; Remote>>Dyl:GroupCaseOf: of kind k
;;    (Remote>>Dyl:GroupsDialogOf n k)  -> the Preset Groups window on the groups of kind k,
;;                                         n: presets using each group

;;  The groups of the presets when Groups.csv cannot be read: by the kind of drawing they are
;;  used in, the plans by their type:
(setq *grp:defaults* '("Floor" "Wall" "Ceiling" "Roof" "Finish" "Structural" "Site"
                       "Elevation" "Section" "Detail" "Annotation" "Phase" "Area" "Generic"
                      )
)

;;  The groups of the materials when MaterialGroups.csv cannot be read: by what they are made
;;  of, then the space of an assembly (Air: the air spaces, Void), the materials of the phases
;;  and the others:
(setq *grp:matdefaults* '("Concrete" "Masonry" "Metal" "Wood" "Board" "Insulation" "Finish"
                          "Roofing" "Site" "Air" "Phase" "Generic"
                         )
)

;;  The kinds of groups: (kind file defaults noun), noun what uses them in the Preset Groups
;;  window ("1 preset", "2 materials"):
(setq *grp:kinds* '((nil "Groups.csv" *grp:defaults* "preset")
                    ("Material" "MaterialGroups.csv" *grp:matdefaults* "material")
                   )
)

;;  The groups read, by kind (see Remote>>Dyl:GroupsOf), read again when DynALisp loads:
(setq *grp:cache* nil)

;;  The kind k of groups ((kind file defaults noun), the groups of the presets for any other k):
(defun Remote>>Dyl:GroupsKind (k)
  (cond ((if k (assoc k *grp:kinds*))) ((assoc nil *grp:kinds*)))
)

;;  The default groups file of the kind k (Res\Groups.csv or Res\MaterialGroups.csv under
;;  Contents):
(defun Remote>>Dyl:GroupsFileOf (k)
  (strcat (if *dyl:dylres *dyl:dylres(strcat *dyl:dyl "\\Res")) "\\" (cadr (Remote>>Dyl:GroupsKind k)))
)

;;  The default groups file of the presets:
(defun Remote>>Dyl:GroupsFile ()
  (Remote>>Dyl:GroupsFileOf nil)
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

;;  The groups of the kind k (the user's copy of its file, else the default one), read again
;;  only when the file changed (*grp:cache*: ((kind (file date) . groups) ...)):
(defun Remote>>Dyl:GroupsOf (k / d f c)
  (setq d (Remote>>Dyl:GroupsKind k)
        f (Dyl:UserFile (Remote>>Dyl:GroupsFileOf (car d)))
        c (list f (if (findfile f) (vl-file-systime f)))
  )
  (if (not (equal c (cadr (assoc (car d) *grp:cache*))))
    (setq *grp:cache* (cons (cons (car d) (cons c (cond ((Remote>>Dyl:GroupsRead f)) ((eval (caddr d))))))
                            (vl-remove (assoc (car d) *grp:cache*) *grp:cache*)
                      )
    )
  )
  (cddr (assoc (car d) *grp:cache*))
)

;;  The groups of the presets:
(defun Remote>>Dyl:Groups ()
  (Remote>>Dyl:GroupsOf nil)
)

;;  The default groups of the kind k (its file as shipped, never its user copy):
(defun Remote>>Dyl:GroupsDefaultsOf (k)
  (cond ((Remote>>Dyl:GroupsRead (Remote>>Dyl:GroupsFileOf k))) ((eval (caddr (Remote>>Dyl:GroupsKind k)))))
)

;;  The group g as written in the groups of the kind k (any case: "section" -> "Section"),
;;  else g itself (a group typed in a presets file that is not one of them is kept):
(defun Remote>>Dyl:GroupCaseOf (g k)
  (cond
    ((vl-some '(lambda (x) (if (= (strcase x) (strcase g)) x)) (Remote>>Dyl:GroupsOf k)))
    (g)
  )
)

;;  The same, in the groups of the presets:
(defun Remote>>Dyl:GroupCase (g)
  (Remote>>Dyl:GroupCaseOf g nil)
)

;;  Save the groups lst of the kind k (the user's copy of its file). Returns T, nil when it
;;  cannot be written (open in Excel):
(defun Remote>>Dyl:GroupsWriteOf (lst k)
  (if (Remote>>LM:writecsv (cons '("Group") (mapcar 'list lst)) (Dyl:UserFileW (Remote>>Dyl:GroupsFileOf k)))
    (progn (setq *grp:cache* nil) t)
  )
)

;;  The group g once the renames pairs ((old . new) ...) are applied (any case):
(defun Remote>>Dyl:GroupRenamed (g pairs / p)
  (if (setq p (vl-some '(lambda (x) (if (= (strcase (car x)) (strcase g)) x)) pairs)) (cdr p) g)
)

;;  Rename the groups of the renames pairs ((old . new) ...) of the kind k in the files of
;;  every preset tool of that kind (*dyl:presetspecs*: its (groups . k), none for the groups
;;  of the presets: Quick Draw, Quick Shape, the hatch presets...; "Material": the
;;  materials), saved now: each file as it is on disk (the user's copy, else the default),
;;  its other values kept. Returns the tools whose file could not be written:
(defun Remote>>Dyl:GroupsRenameOf (pairs k / key rows new bad)
  (setq k (car (Remote>>Dyl:GroupsKind k)))
  ;;  A materials file of DynALisp 1.1 and older is split first (its user copy is not read as
  ;;  it is, see Remote>>Dyl:PresetFile, and would be written over):
  (if Remote>>Dyl:MaterialMigrate (Remote>>Dyl:MaterialMigrate))
  (foreach spec *dyl:presetspecs*
    (setq key  (car spec)
          rows (if (= k (car (Remote>>Dyl:GroupsKind (cdr (assoc 'groups (cdr spec)))))) (Remote>>Dyl:PresetCsv key))
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
;;  presets using each group (((GROUP . n) ...)), noun what they are ("preset", "material"):
(defun Remote>>Dyl:GroupsRow (g org used noun / n)
  (setq n (cdr (assoc (strcase org) used)))
  (list g (cond ((not n) "") ((= 1 n) (strcat "1 " noun)) ((strcat (itoa n) " " noun "s"))) org)
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

;;  The Preset Groups window on the groups of the kind k (titled Material Groups for the
;;  groups of the materials): add, rename, remove and order the groups. used: the number of
;;  presets in each group (((group . n) ...), any case, shown beside each group). OK saves the
;;  groups (Groups.csv or MaterialGroups.csv) and renames the groups renamed in the files of
;;  every preset tool of that kind (see Remote>>Dyl:GroupsRenameOf). Returns the renames
;;  ((old . new) ...) on OK (nil: none, or T), nil on Cancel; the caller renames them in the
;;  presets it is editing:
(defun Remote>>Dyl:GroupsDialogOf (used k / d org res rows lst pairs bad msg)
  (setq d    (Remote>>Dyl:GroupsKind k)
        k    (car d)
        used (mapcar '(lambda (x) (cons (strcase (car x)) (cdr x))) used)
        org  (Remote>>Dyl:GroupsOf k)
        rows (mapcar '(lambda (g) (Remote>>Dyl:GroupsRow g g used (cadddr d))) org)
  )
  ;;  Shown again on the rows edited while a name is not valid (checked here too, the window
  ;;  checks them first):
  (while
    (progn
      (setq res  (Dyl:WinShow
               "Dyl-PresetGroups.xaml"
               (append
                 (list (cons "gl/rows" rows)
                       ;;  Reset: the default groups, those of the file keep their presets:
                       (cons "gl/defs"
                             (mapcar '(lambda (g) (Remote>>Dyl:GroupsRow g (if (member g org) g "") used (cadddr d)))
                                     (Remote>>Dyl:GroupsDefaultsOf k)
                             )
                       )
                       (list "gl/new" (list "New group" "" ""))
                 )
                 ;;  The groups of the materials: the window is titled so (win/title, see
                 ;;  Installer\Windows\Engine\Session.cs):
                 (if k (list (cons "win/title" "DynALisp - Material Groups")))
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
        ((Remote>>Dyl:GroupsWriteOf lst k)
         (setq pairs (vl-remove-if '(lambda (x) (or (= "" (car x)) (= (car x) (cdr x))))
                                   (mapcar '(lambda (x) (cons (caddr x) (vl-string-trim " " (car x)))) rows)
                     )
         )
         ;;  The renames of the session, in their order, each one with its kind ((k pairs)):
         ;;  every preset window open renames those of its kind in the presets it is editing
         ;;  (see Remote>>Dyl:PresetDlgGroupsSync):
         (if pairs (setq *grp:renames* (append *grp:renames* (list (list k pairs)))))
         (if (setq bad (Remote>>Dyl:GroupsRenameOf pairs k))
           (alert (strcat "The groups could not be renamed in the presets of: "
                          (Remote>>LM:lst->str bad ", ")
                          " (is the file open in Excel?)."
                  )
           )
         )
         (cond (pairs) (T))
        )
        (T (alert (strcat "The groups could not be saved: is " (cadr d) " open in Excel?")) nil)
      )
    )
  )
)

;;  The Preset Groups window on the groups of the presets (see Remote>>Dyl:GroupsDialogOf):
(defun Remote>>Dyl:GroupsDialog (used)
  (Remote>>Dyl:GroupsDialogOf used nil)
)

;;  Rename the groups of the presets (see Remote>>Dyl:GroupsRenameOf):
(defun Remote>>Dyl:GroupsRename (pairs)
  (Remote>>Dyl:GroupsRenameOf pairs nil)
)
