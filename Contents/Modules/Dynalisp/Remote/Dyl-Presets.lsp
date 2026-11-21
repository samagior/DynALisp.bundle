;; Dyl-Presets - Preset engine shared by the preset tools (Quick Draw...)
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

;;  Loaded at startup with the other Remote files. A preset tool (e.g. Quick Draw,
;;  Apps\Draw\Dyl-QuickDraw.lsp) keeps its presets in a CSV file of the Dynalisp Res
;;  folder and edits them in the preset dialog made here.
;;
;;  A preset is a list of strings (id group name ...): the first three columns are the
;;  same for every tool, the next ones are the values of the tool. id is the id of a
;;  default preset (defined by the App, e.g. "qd-Demo"), or a custom id "cu-<Name>"
;;  (e.g. cu-ModularBrick) given the first time a custom preset is read or saved:
;;  renaming the preset keeps its id. The command of a default preset is <base><Id>
;;  (e.g. qd-Brick -> Pst-QuickDrawBrick, defined in the App). Each custom preset has a command <cmd><Name>
;;  (e.g. Pst-QuickDrawCustomModularBrick), a dynamic child of the main command of the
;;  tool (see Dyl:DynList in dynalisp.mnl): defined when the main command is turned on,
;;  listed under it in Dyl-Suite and run by the aliases given to it there.
;;
;;  A tool adds its spec to *dyl:presetspecs* from a Remote file, so the commands of its
;;  custom presets exist before its App is loaded (see Remote\Dyl-QuickDrawPresets.lsp):
;;
;;    ("QuickDraw"                                      ; key of the tool
;;     (file . "QuickDraw.csv")                         ; presets file, in the Dynalisp Res folder
;;     (header "Id" "Group" "Name" ...)                 ; columns of the presets file
;;     (default . "QD-*")                               ; wcmatch of the default ids (upper case)
;;     (base . "Pst-QuickDraw")                         ; command prefix of the default presets
;;     (cmd . "Pst-QuickDrawCustom")                    ; command prefix of the custom presets
;;     (title . "Quick Draw")                           ; name of the tool
;;     (path . "Dynalisp\\Apps\\Draw\\Dyl-QuickDraw.lsp") ; App, relative to the Modules folder
;;     (info . 3)                                       ; column shown in a custom command description
;;     (desc . "draws an outline and fills it with its hatch.")
;;     (get . Dyl:QuickDrawGet)                         ; App function: id -> preset
;;     (run . Dyl:QuickDrawRun)                         ; App function: draws a preset
;;    )


;;-------------------------=={ Presets }==------------------------;;

;;  Value of the property prop of the spec of the tool key:
(defun Remote>>Dyl:PresetProp (key prop)
  (cdr (assoc prop (cdr (assoc key *dyl:presetspecs*))))
)

;;  Default presets file of the tool key:
(defun Remote>>Dyl:PresetDefault (key)
  (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\" (Remote>>Dyl:PresetProp key 'file))
)

;;  Presets file of the tool key to read: the user copy when there is one, else the default
;;  (see Dyl:UserFile in dynalisp.mnl):
(defun Remote>>Dyl:PresetFile (key)
  (Dyl:UserFile (Remote>>Dyl:PresetDefault key))
)

;;  Presets file of the tool key to write: the user copy:
(defun Remote>>Dyl:PresetFileW (key)
  (Dyl:UserFileW (Remote>>Dyl:PresetDefault key))
)

;;  Rows of the presets file of the tool key (as many columns as its header):
(defun Remote>>Dyl:PresetCsv (key)
  (Remote>>Dyl:CsvRead (Remote>>Dyl:PresetFile key) (length (Remote>>Dyl:PresetProp key 'header)))
)

;;  Name -> its letters and digits in CamelCase ("Modular brick 2" -> "ModularBrick2"):
(defun Remote>>Dyl:PresetCamel (nam / up out)
  (setq up  T
        out ""
  )
  (foreach c (vl-string->list nam)
    (if (or (< 47 c 58) (< 64 c 91) (< 96 c 123))
      (setq out (strcat out (chr (if (and up (< 96 c 123)) (- c 32) c)))
            up  nil
      )
      (setq up T)
    )
  )
  out
)

;;  Give the presets of lst without id ("") a custom id made from their name,
;;  unique in lst (cu-Test, cu-Test2...):
(defun Remote>>Dyl:PresetIds (lst / ids base id i)
  (setq ids (mapcar '(lambda (r) (strcase (car r))) lst))
  (mapcar
    '(lambda (r)
       (if (= "" (car r))
         (progn
           (setq base (strcat "cu-" (cond ((/= "" (setq id (Remote>>Dyl:PresetCamel (nth 2 r)))) id) ("Preset")))
                 id   base
                 i    1
           )
           (while (member (strcase id) ids) (setq id (strcat base (itoa (setq i (1+ i))))))
           (setq ids (cons (strcase id) ids))
           (cons id (cdr r))
         )
         r
       )
     )
    lst
  )
)

;;  Clean the rows read from the presets file of the tool key. defs are the default
;;  presets of the App (nil when the App is not loaded: the default ids are then told
;;  apart by their prefix). Any other id that is not a custom id (cu-...), or a repeated
;;  custom id, is cleared; rows without name or column 3 and repeated default ids are
;;  dropped; then the presets without id get one:
(defun Remote>>Dyl:PresetClean (key rows defs / lst)
  (foreach row rows
    (cond
      ((if defs
         (assoc (car row) defs)
         (wcmatch (strcase (car row)) (Remote>>Dyl:PresetProp key 'default))
       )
      )
      ((and (wcmatch (strcase (car row)) "CU-?*") (not (assoc (car row) lst))))
      ((setq row (cons "" (cdr row))))
    )
    (if
      (and (/= "" (nth 2 row))
           (/= "" (nth 3 row))
           (or (= "" (car row)) (not (assoc (car row) lst)))
      )
      (setq lst (cons row lst))
    )
  )
  (Remote>>Dyl:PresetIds (reverse lst))
)

;;  Read the presets of the tool key with the default presets defs of its App. Each row
;;  goes through the App function fix (values in upper case...), then the rows are
;;  cleaned (see above) and the default presets missing from the file are added with
;;  their default values:
(defun Remote>>Dyl:PresetRead (key defs fix / lst)
  (setq lst (Remote>>Dyl:PresetClean key (mapcar fix (Remote>>Dyl:PresetCsv key)) defs))
  (foreach x defs
    (if (not (assoc (car x) lst)) (setq lst (append lst (list x))))
  )
  lst
)

;;  Write the presets file of the tool key, the new custom presets getting their id
;;  first. Returns T on success (nil if the file is open in Excel):
(defun Remote>>Dyl:PresetWrite (key lst)
  (Remote>>LM:writecsv (cons (Remote>>Dyl:PresetProp key 'header) (Remote>>Dyl:PresetIds lst))
                       (Remote>>Dyl:PresetFileW key)
  )
)

;;  Preset id of the tool key, with the values edited by the user (defs and fix: see
;;  Remote>>Dyl:PresetRead):
(defun Remote>>Dyl:PresetGet (key defs fix id)
  (cond
    ((assoc id (Remote>>Dyl:PresetRead key defs fix)))
    ((assoc id defs))
  )
)

;;-------------------------=={ Custom preset commands }==------------------------;;

;;  Command of a custom preset id of the tool key: "cu-Test" -> "Pst-QuickDrawCustomTest"
(defun Remote>>Dyl:PresetCmd (key id)
  (strcat (Remote>>Dyl:PresetProp key 'cmd) (substr id 4))
)

;;  Command of the preset id of the tool key, default or custom (nil for a custom preset
;;  without id yet, or a tool without commands): "qd-Brick" -> "Pst-QuickDrawBrick",
;;  "cu-Test" -> "Pst-QuickDrawCustomTest"
(defun Remote>>Dyl:PresetCommand (key id)
  (cond
    ((or (= "" id) (not (Remote>>Dyl:PresetProp key 'cmd))) nil)
    ((wcmatch (strcase id) "CU-*") (Remote>>Dyl:PresetCmd key id))
    ((strcat (Remote>>Dyl:PresetProp key 'base) (substr id 4)))
  )
)

;;  The custom presets of every tool (with commands) as dynamic children of its main command:
;;  ((COMMAND NAME DESCRIPTION PATH BODY) ...), see Dyl:DynList in dynalisp.mnl.
(defun Remote>>Dyl:PresetChildren (/ key res)
  (foreach spec *dyl:presetspecs*
    (setq key (car spec))
    (foreach r (if (Remote>>Dyl:PresetProp key 'cmd) (Remote>>Dyl:PresetClean key (Remote>>Dyl:PresetCsv key) nil))
      (if (wcmatch (strcase (car r)) "CU-*")
        (setq res (cons (list (strcase (Remote>>Dyl:PresetCmd key (car r)))
                              (strcat (Remote>>Dyl:PresetProp key 'title) " " (nth 2 r))
                              (strcat "Custom preset ("
                                      (nth 1 r)
                                      ", "
                                      (strcase (nth (Remote>>Dyl:PresetProp key 'info) r))
                                      "): "
                                      (Remote>>Dyl:PresetProp key 'desc)
                              )
                              (Remote>>Dyl:PresetProp key 'path)
                              (list 'Remote>>Dyl:PresetCustomRun key (car r))
                        )
                        res
                  )
        )
      )
    )
  )
  (reverse res)
)

;;  Run the custom preset id of the tool key, loading its App first if needed:
(defun Remote>>Dyl:PresetCustomRun (key id / path run rec)
  (setq path (Remote>>Dyl:PresetProp key 'path)
        run  (Remote>>Dyl:PresetProp key 'run)
  )
  (if (not (eval run)) (load (strcat *dyl:module "\\" path) nil))
  (cond
    ((not (eval run)) (princ (strcat "\n--> Unable to load " (vl-filename-base path) ".lsp")))
    ((and (setq rec (apply (Remote>>Dyl:PresetProp key 'get) (list id))) (= id (car rec)))
     (apply run (list rec))
    )
    ((princ (strcat "\nThis custom preset no longer exists: see " (vl-filename-base path) ".")))
  )
  (princ)
)

;;  Register the provider of the custom preset commands (once):
(if (not (member 'Remote>>Dyl:PresetChildren *dyl:dynproviders*))
  (setq *dyl:dynproviders* (cons 'Remote>>Dyl:PresetChildren *dyl:dynproviders*))
)

;;-------------------------=={ Dialog }==------------------------;;

;;  Remote>>Dyl:PresetDialog shows the presets of a tool. The App gives its part of the
;;  dialog as an association list dlg:
;;
;;    (defs   . <default presets>)
;;    (fix    . <function: row -> row, see Remote>>Dyl:PresetRead>)
;;    (tiles  . (("pat" . 3) ...))  ; tiles of the App and index of their value in a preset
;;    (upper  "pat" ...)            ; tiles whose value is saved in upper case
;;    (params "<DCL line>" ...)     ; tiles of the App, in the Parameters column
;;    (new    . <preset>)           ; values of a new preset (id and group are replaced)
;;    (items  . <function: key -> values of a popup tile, nil for the other tiles>)
;;    (check  . <function: key value -> error message, nil when valid>)
;;    (init   . <function: fill the popups and set the actions of the App tiles>)
;;    (state  . <function: preset -> enable / disable the App tiles>)
;;    (warn . 5)      ; OK asks first when more than 5 presets were changed (Materials)
;;    (noun . "materials") ; what the presets are called in the messages ("presets")
;;    (skip   . <function: preset -> keys of the App tiles not stored, e.g. greyed out tiles
;;               that only show values stored elsewhere; optional>)
;;    (status . <function: code preset, called when the dialog is closed with a code >= 3;
;;               returns save to save the presets and close the dialog (no reopen)>)
;;    (prefix . <function: preset -> text put in the new alias box, e.g. "QD-">)
;;    (select . <id of the preset selected when the dialog opens (default: the last one)>)
;;    (groups . T)                  ; Group is a popup of the groups (Remote\Dyl-Groups.lsp), with
;;                                  ; its open button to the Preset Groups window (no groups:
;;                                  ; Group is an edit box)
;;    (material . 3)                ; index of a material id in a preset (see Materials below)
;;    (window . "Dyl-QuickDraw.xaml") ; shown in this WPF window (a .xaml of the Res folder of
;;                                  ; the Dynalisp module), not in a DCL dialog: see Window below
;;
;;  An App button closes the dialog with a code from 3 to 8 (after Remote>>Dyl:PresetDlgCommit):
;;  status is called (e.g. to show another dialog, not nested in this one), then this
;;  dialog is shown again with the presets being edited. Code 9 is the Edit materials button.
;;
;;  Materials: with (material . i), the Parameters column starts with a Material popup (the
;;  materials of Remote\Dyl-Materials.lsp, the deleted ones marked missing), a summary of the
;;  material and an Edit materials... button. It opens the Materials dialog on the material
;;  of the preset, and the material selected there on OK is given to the preset.
;;
;;  A tool without cmd in its spec (e.g. Materials, Remote\Dyl-Materials.lsp) has no
;;  commands: no aliases, and OK (save) instead of Draw / Save. Its dialog returns the
;;  preset selected on OK, so the tool that opened it can pick it.
;;
;;  Several presets can be selected in the list (Ctrl / Shift click) and edited at once (see
;;  CONVENTIONS.md, Windows): the fields show the preset shown (pst:idx), a value changed is
;;  given to every preset selected (pst:sel, see Remote>>Dyl:PresetDlgPut); the name, Copy
;;  and the aliases are for one preset only; Delete and Reset Selected act on all of them;
;;  Draw draws the preset shown.
;;
;;  The functions below run inside Remote>>Dyl:PresetDialog and use its local variables:
;;  pst:key (tool), pst:dlg (part of the App), pst:lst (presets being edited), pst:lst0 (the
;;  presets as read, see Remote>>Dyl:PresetDlgChanged), pst:idx (index of the preset shown),
;;  pst:sel (indexes of the presets selected, pst:idx included: several with (multi . T)), pst:dcl (dialog id), pst:grps (groups of the Group popup),
;;  pst:mats and pst:matids (materials, ids of the Hatch preset popup: the materials of the
;;  group of the preset shown), and the variables of the
;;  aliases panel (see Aliases below).

;;  Call the function prop of the App part of the dialog (nil when it has none):
(defun Remote>>Dyl:PresetDlgCall (prop args / f)
  (if (setq f (cdr (assoc prop pst:dlg))) (apply f args))
)

;;  Groups of the Group popup ((groups . T) of the App, nil for an edit box): the groups (see
;;  Remote>>Dyl:Groups, Remote\Dyl-Groups.lsp), then the other groups used by a preset (they
;;  stay selectable, e.g. a group typed in the presets file, or removed from the groups):
(defun Remote>>Dyl:PresetDlgGrps (/ g)
  (if (assoc 'groups pst:dlg)
    (progn
      (setq g (Remote>>Dyl:Groups))
      (foreach r pst:lst
        (if (not (member (nth 1 r) g)) (setq g (append g (list (nth 1 r)))))
      )
      g
    )
  )
)

;;  The presets of each group, ((group . n) ...), for the Preset Groups window:
(defun Remote>>Dyl:PresetDlgGroupCounts (/ res x g)
  (foreach r pst:lst
    (setq g (strcase (cond ((nth 1 r)) (""))))
    (if (setq x (assoc g res))
      (setq res (subst (cons (car x) (1+ (cdr x))) x res))
      (setq res (cons (cons g 1) res))
    )
  )
  res
)

;;  The groups renamed in the Preset Groups window since the dialog was shown (*grp:renames*,
;;  after its first pst:gren renames) are renamed in the presets being edited and in those
;;  as read (pst:lst0: the files were saved with them), so a preset saved after keeps them:
(defun Remote>>Dyl:PresetDlgGroupsSync (/ new)
  (setq new (Remote>>Dyl:GroupsDrop *grp:renames* pst:gren))
  (foreach pairs new
    (setq pst:lst  (mapcar '(lambda (r) (cons (car r) (cons (Remote>>Dyl:GroupRenamed (nth 1 r) pairs) (cddr r)))) pst:lst)
          pst:lst0 (mapcar '(lambda (r) (cons (car r) (cons (Remote>>Dyl:GroupRenamed (nth 1 r) pairs) (cddr r)))) pst:lst0)
          pst:shw  (if (/= "" pst:shw) (Remote>>Dyl:GroupRenamed pst:shw pairs) pst:shw)
    )
  )
  (setq pst:gren (length *grp:renames*))
)

;;  Popup tiles -> list of their values (nil for the other tiles): the Group popup (pst:grps,
;;  see Remote>>Dyl:PresetDialog), then the popups of the App:
(defun Remote>>Dyl:PresetDlgItems (key)
  (cond
    ((and (= "grp" key) pst:grps) pst:grps)
    ((= "mat" key) pst:matids)
    ((Remote>>Dyl:PresetDlgCall 'items (list key)))
  )
)

;;  Index of the material in a preset (nil: the tool has no material):
(defun Remote>>Dyl:PresetDlgMat ()
  (cdr (assoc 'material pst:dlg))
)

;;  Edit tiles of the dialog and index of their value in a preset. The material comes last:
;;  when it no longer exists, the other values are stored before it is refused:
(defun Remote>>Dyl:PresetDlgTiles ()
  (append '(("nam" . 2) ("grp" . 1))
          (cdr (assoc 'tiles pst:dlg))
          (if (Remote>>Dyl:PresetDlgMat) (list (cons "mat" (Remote>>Dyl:PresetDlgMat))))
  )
)

;;  The Hatch preset popup (mat) lists the materials of the group of the preset shown (its
;;  Group, the same groups as the materials, see Remote>>Dyl:Groups), by name: pst:matids. The
;;  material of the preset shown stays listed when it is in another group, or no longer
;;  exists (marked missing), and every material is listed when its group has none.

;;  Read the materials (each time the dialog is shown: they may have been edited), draw the
;;  open button of the Hatch Presets window and set its action:
(defun Remote>>Dyl:PresetDlgMatInit ()
  (setq pst:mats (Remote>>Dyl:MaterialRead))
  (Dyl:MoreTile "edm" T)
  (action_tile
    "edm"
    "(if (or (Remote>>Dyl:PresetDlgCommit) (not (assoc (nth (Remote>>Dyl:PresetDlgMat) (nth pst:idx pst:lst)) pst:mats))) (done_dialog 9))"
  )
)

;;  The materials of the group grp, sorted by name (nil: none):
(defun Remote>>Dyl:PresetDlgMatsOf (grp)
  (vl-sort (vl-remove-if-not '(lambda (m) (= (strcase grp) (strcase (nth 1 m)))) pst:mats)
           '(lambda (a b) (< (strcase (nth 2 a)) (strcase (nth 2 b))))
  )
)

;;  Fill the Hatch preset popup for the preset shown: the materials of its group, then its
;;  material when it is not one of them (shown "group - name", or marked missing). A group
;;  without material: every material, sorted by group and name, shown "group - name":
(defun Remote>>Dyl:PresetDlgMatFill (/ r cur in m)
  (setq r   (nth pst:idx pst:lst)
        cur (nth (Remote>>Dyl:PresetDlgMat) r)
        in  (Remote>>Dyl:PresetDlgMatsOf (nth 1 r))
  )
  (setq pst:matids
         (if in
           (Remote>>Dyl:MaterialPopup "mat"
                                      (if (and (setq m (assoc cur pst:mats)) (not (member m in))) (append in (list m)) in)
                                      (list cur)
                                      (nth 1 r)
           )
           (Remote>>Dyl:MaterialPopup "mat"
                                      (vl-sort pst:mats
                                               '(lambda (a b)
                                                  (< (strcase (strcat (nth 1 a) "\t" (nth 2 a)))
                                                     (strcase (strcat (nth 1 b) "\t" (nth 2 b)))
                                                  )
                                                )
                                      )
                                      (list cur)
                                      nil
           )
         )
  )
)

;;  The Group of the presets selected changed (Remote>>Dyl:PresetDlgField): the Hatch preset
;;  popup lists the materials of the new group. When the material of the preset shown is not
;;  one of them, the first one is given to the presets selected (then another one of the group
;;  can be picked):
(defun Remote>>Dyl:PresetDlgMatGroup (/ r i)
  (setq r (nth pst:idx pst:lst))
  (Remote>>Dyl:PresetDlgMatFill)
  (if (and (Remote>>Dyl:PresetDlgMatsOf (nth 1 r))
           (not (member (assoc (nth (Remote>>Dyl:PresetDlgMat) r) pst:mats) (Remote>>Dyl:PresetDlgMatsOf (nth 1 r))))
      )
    (progn
      (set_tile "mat" "0")
      (Remote>>Dyl:PresetDlgField "mat" "0")
    )
    (set_tile "mat" (itoa (cond ((vl-position (nth (Remote>>Dyl:PresetDlgMat) r) pst:matids)) (0))))
  )
)

;;  Default presets of the tool:
(defun Remote>>Dyl:PresetDlgDefs ()
  (cdr (assoc 'defs pst:dlg))
)

;;  What the presets are called in the messages ((noun . "materials") of the App):
(defun Remote>>Dyl:PresetDlgNoun ()
  (cond ((cdr (assoc 'noun pst:dlg))) ("presets"))
)

;;  Indexes of the presets selected, the one shown (pst:idx) included:
(defun Remote>>Dyl:PresetDlgSel ()
  (if (member pst:idx pst:sel) pst:sel (list pst:idx))
)

;;  Give the value val to the column i of every preset selected (pst:one T, see
;;  Remote>>Dyl:PresetDlgCommit: to the preset shown only):
(defun Remote>>Dyl:PresetDlgPut (i val)
  (foreach j (if pst:one (list pst:idx) (Remote>>Dyl:PresetDlgSel))
    (setq pst:lst (Remote>>Dyl:ListSubst pst:lst j (Remote>>Dyl:ListSubst (nth j pst:lst) i val)))
  )
)

;;  Number of presets changed since the dialog opened: edited (or added), and deleted:
(defun Remote>>Dyl:PresetDlgChanged ()
  (+ (length (vl-remove-if '(lambda (r) (member r pst:lst0)) pst:lst))
     (length (vl-remove-if '(lambda (r) (assoc (car r) pst:lst)) pst:lst0))
  )
)

;;  OK / Draw / Save: T, after asking when more presets were changed than (warn . n) of the
;;  App allows:
(defun Remote>>Dyl:PresetDlgWarnOk (/ w n)
  (setq w (cdr (assoc 'warn pst:dlg))
        n (Remote>>Dyl:PresetDlgChanged)
  )
  (or (not w)
      (<= n w)
      (Remote>>Dyl:PresetDlgAsk
        (strcat (itoa n) " " (Remote>>Dyl:PresetDlgNoun) " were changed (edited, added or deleted). Save the changes?")
      )
  )
)

;;  Sorts of the list (see *pst:sorts*):
(defun Remote>>Dyl:PresetDlgSorts ()
  *pst:sorts*
)

;;  T when the presets of the tool are commands (aliases, Draw button):
(defun Remote>>Dyl:PresetDlgCmds-p ()
  (if (Remote>>Dyl:PresetProp pst:key 'cmd) t)
)

;;  Docs page of the tool (Open Docs button, see Dyl:DocsTile) (nil: none found): (doc . "Draw\\Dyl-HatchPresets.htm") of
;;  its spec, relative to the Docs folder of the Dynalisp module, else the page named after
;;  its App (path . "Dynalisp\\Apps\\Draw\\Dyl-QuickDraw.lsp" -> Docs\Draw\Dyl-QuickDraw.htm):
(defun Remote>>Dyl:PresetDlgDocFile (/ doc app)
  (setq doc (Remote>>Dyl:PresetProp pst:key 'doc)
        app (Remote>>Dyl:PresetProp pst:key 'path)
  )
  ;;  The path found (not the T of an and), on the website or on this computer
  ;;  (Dyl:DocsFind of dynalisp.mnl: the setup does not install the Docs folders):
  (cond
    ((and doc (setq doc (Dyl:DocsFind (strcat *dyl:dyl "\\Docs\\" doc)))) doc)
    ((and app
          (setq app (Dyl:DocsFind (strcat *dyl:dyl "\\Docs\\"
                                      (vl-filename-base (vl-filename-directory app)) "\\" (vl-filename-base app) ".htm"
                              )
                    )
          )
     )
     app
    )
  )
)

;;  Write the dialog definition to a temporary DCL file and return its path:
(defun Remote>>Dyl:PresetDlgDcl (/ title cmds nost tabs wid path file)
  ;;  Columns of the list: group, name, and the aliases of a tool whose presets are commands
  ;;  (no Status column: the status of the preset shown is in the Parameters heading, see
  ;;  Remote>>Dyl:PresetDlgState). Without aliases: group and name only, the name about 30
  ;;  wide, a narrow list (nost):
  (setq title (Remote>>Dyl:PresetProp pst:key 'title)
        cmds  (Remote>>Dyl:PresetDlgCmds-p)
        nost  (not cmds)
        tabs  (if cmds "12 38" "12")
        wid   (if cmds "62" "44")
        path  (vl-filename-mktemp "pst" nil ".dcl")
        file  (open path "w")
  )
  (foreach line
    (append
      (list (strcat "dyl_pst : dialog { label = \"DynALisp - " title "\";")
            "  : row {"
            "    : column {"
            ;;  Filter and sort of the list (see Remote>>Dyl:PresetDlgView), kept narrow: the
            ;;  list is as wide as the widest line of this column. A narrow list (no aliases):
            ;;  the sort on a row of its own:
            "      : row {"
            "        : edit_box { key = \"flt\"; label = \"Filter:\"; edit_width = 16; edit_limit = 64; }"
            (if nost "" "        : popup_list { key = \"srt\"; label = \"Sort by:\"; edit_width = 12; }")
            (if nost "        : text { key = \"pcn\"; width = 14; }" "        : text { key = \"pcn\"; width = 12; }")
            "      }"
            (if nost "      : row { : popup_list { key = \"srt\"; label = \"Sort by:\"; edit_width = 16; } }" "")
            ;;  Show: the presets of one group; Set default: the group the window opens on:
            "      : row { : popup_list { key = \"shg\"; label = \"Show:\"; edit_width = 16; }"
            "              : button { key = \"shd\"; label = \"Set default\"; fixed_width = true; } }"
            ;;  Column titles: a one-line list box with the same tabs, so they line up with the list:
            (strcat "      : list_box { label = \"" (if cmds "Presets (double-click to draw):" "Presets:") "\";")
            (strcat "                   key = \"hdr\"; width = " wid "; height = 2; fixed_height = true; tabs = \"" tabs "\";")
            "                   is_tab_stop = false; }"
            ;;  Height of the list: (height . n) of the App (a tall Parameters column), else 16:
            (strcat "      : list_box { key = \"lst\"; width = " wid "; height = "
                    (itoa (cond ((cdr (assoc 'height pst:dlg))) (16)))
                    "; tabs = \""
                    tabs
                    "\";"
            )
            (strcat "                   allow_accept = " (if cmds "true" "false") ";"
                    " multiple_select = true;"
                    " }"
            )
            "      : row {"
            "        : button { key = \"new\"; label = \"New\"; }"
            "        : button { key = \"cpy\"; label = \"Copy\"; }"
            "        : button { key = \"del\"; label = \"Delete\"; }"
            "      }"
      )
      (if cmds
        (list "      : boxed_column { label = \"Aliases of the preset command\";"
              "        : list_box { key = \"als\"; height = 4; }"
              "        : row {"
              "          : edit_box { key = \"aln\"; edit_width = 18; edit_limit = 64; }"
              "          : button { key = \"aad\"; label = \"Add\"; }"
              "          : button { key = \"aren\"; label = \"Rename\"; }"
              "          : button { key = \"adel\"; label = \"Remove\"; }"
              "        }"
              "        : text { key = \"ams\"; width = 50; }"
              "      }"
        )
      )
      (list "    }"
            ;;  Its heading gives the status of the selected preset, Parameters (modified) or
            ;;  Parameters (custom) (see Remote>>Dyl:PresetDlgState; the longest one here, so
            ;;  its label has the room):
            "    : boxed_column { key = \"prm\"; label = \"Parameters (modified)\";"
            "      : edit_box { key = \"nam\"; label = \"Name:\"; edit_width = 28; edit_limit = 64; }"
            (if (assoc 'groups pst:dlg)
              ;;  Built as the Hatch preset row below (a label, then the popup, fixed, at the
              ;;  right of the row), so both popups have the same width:
              ;;  The open button of the Preset Groups window just left of it (one string: the
              ;;  then branch of the if):
              (strcat "      : row { : text { label = \"Group:\"; }"
                      " : image_button { key = \"gre\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
                      " : popup_list { key = \"grp\"; edit_width = 28; fixed_width = true; } }"
              )
              "      : edit_box { key = \"grp\"; label = \"Group:\"; edit_width = 28; edit_limit = 64; }"
            )
            "      spacer;"
      )
      (if (Remote>>Dyl:PresetDlgMat)
        ;;  The open button of the Hatch Presets window just left of the popup it edits (see
        ;;  CONVENTIONS.md, Windows), the popup at the right of the row as the boxes above:
        (list "      : row { : text { key = \"matl\"; label = \"Hatch preset:\"; }"
              "              : image_button { key = \"edm\"; height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
              "              : popup_list { key = \"mat\"; edit_width = 28; fixed_width = true; } }"
              "      : text { key = \"mts\"; width = 50; }"
              "      spacer;"
        )
      )
      (cdr (assoc 'params pst:dlg))
      ;;  The command of the preset, for a tool whose presets are commands:
      (if (Remote>>Dyl:PresetDlgCmds-p)
        (list "      spacer;"
              "      : text { key = \"src\"; width = 50; }"
        )
      )
      (list "    }"
            "  }"
            ;;  Bottom row: the reset buttons on the left (as small as their label), the
            ;;  spacer stretching between, OK / Cancel and Open Docs on the right:
            "  : row {"
            "    : button { key = \"rst\"; label = \"Reset Selected\"; fixed_width = true; }"
            "    : button { key = \"all\"; label = \"Reset All\"; fixed_width = true; }"
            "    : spacer { width = 1; }"
      )
      (if cmds
        (list "    : button { key = \"accept\"; label = \"Draw\"; is_default = true; width = 12; fixed_width = true; }"
              "    : button { key = \"sav\"; label = \"Save\"; width = 12; fixed_width = true; }"
        )
        (list "    : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 12; fixed_width = true; }")
      )
      (list "    : button { key = \"cancel\"; label = \"Cancel\"; is_cancel = true; width = 12; fixed_width = true; }"
            "    : button { key = \"docs\"; label = \"Open Docs\"; width = 12; fixed_width = true; }"
            "  }"
            "  errtile;"
            "}"
            (strcat "dyl_pst_ask : dialog { label = \"DynALisp - " title "\";")
            "  : text { key = \"msg\"; width = 64; }"
            "  ok_cancel;"
            "}"
      )
    )
    (write-line line file)
  )
  (close file)
  path
)

;;  T when another preset than the one at index skip is already named nam:
(defun Remote>>Dyl:PresetTaken-p (nam skip / n)
  (setq n -1)
  (vl-some
    '(lambda (r) (and (/= skip (setq n (1+ n))) (= (strcase nam) (strcase (nth 2 r)))))
    pst:lst
  )
)

;;  Return nam, followed by " (2)", " (3)"... when it is already taken:
(defun Remote>>Dyl:PresetUnique (nam skip / i new)
  (setq i   1
        new nam
  )
  (while (Remote>>Dyl:PresetTaken-p new skip)
    (setq new (strcat nam " (" (itoa (setq i (1+ i))) ")"))
  )
  new
)

;;  Rename the presets whose name is now used twice. keep is the index of the preset that
;;  keeps its name (nil: only the custom presets are renamed):
(defun Remote>>Dyl:PresetDlgRename (keep / i)
  (setq i -1)
  (foreach r pst:lst
    (setq i (1+ i))
    (if
      (and (/= i keep)
           (or keep (not (assoc (car r) (Remote>>Dyl:PresetDlgDefs))))
           (Remote>>Dyl:PresetTaken-p (nth 2 r) i)
      )
      (setq pst:lst (Remote>>Dyl:ListSubst pst:lst
                                            i
                                            (Remote>>Dyl:ListSubst r 2 (Remote>>Dyl:PresetUnique (nth 2 r) i))
                    )
      )
    )
  )
)

;;  Ask a yes / no question in a sub-dialog, returns T on OK:
(defun Remote>>Dyl:PresetDlgAsk (msg)
  (if (new_dialog "dyl_pst_ask" pst:dcl)
    (progn
      (set_tile "msg" msg)
      (= 1 (start_dialog))
    )
  )
)

;;  List line of a preset r: group, name, and its aliases (tools with commands):
(defun Remote>>Dyl:PresetDlgLine (r / c)
  (setq c (Remote>>Dyl:PresetCommand pst:key (car r)))
  (strcat (nth 1 r)
          "\t"
          (nth 2 r)
          (cond
            ((not (Remote>>Dyl:PresetDlgCmds-p)) "")
            ((not c) "\t")
            ((strcat "\t" (cond ((Remote>>LM:lst->str (Dyl:AliasesOf (strcase c) pst:als) ", ")) (""))))
          )
  )
)

;;-------------------------=={ Sort and filter }==------------------------;;

;;  The list shows pst:view: the indexes in pst:lst of the presets listed, in their order.
;;  pst:flt: the filter text (the presets whose group, name, aliases or third value,
;;  e.g. the pattern of a material, have it, any case; "": every preset), pst:srt: the sort
;;  (an item of *pst:sorts*, "Name" by default). The selected preset (pst:idx) is always
;;  listed, so the fields shown are those of a line of the list.
(setq *pst:sorts* '("Name" "Group"))

;;  Sort key of the preset at index i (see pst:srt), in upper case:
(defun Remote>>Dyl:PresetDlgKey (i / r)
  (setq r (nth i pst:lst))
  (strcase
    (cond
      ((= "Group" pst:srt) (strcat (nth 1 r) "\t" (nth 2 r)))
      ((nth 2 r))
    )
  )
)

;;  T when the preset at index a is listed before the one at index b (same key: file order):
(defun Remote>>Dyl:PresetDlgBefore (a b / ka kb)
  (setq ka (Remote>>Dyl:PresetDlgKey a)
        kb (Remote>>Dyl:PresetDlgKey b)
  )
  (if (= ka kb) (< a b) (< ka kb))
)

;;  T when the preset r has the filter text f (upper case, "": every preset):
(defun Remote>>Dyl:PresetDlgMatch-p (r f)
  (or (= "" f)
      (vl-string-search f (strcase (strcat (Remote>>Dyl:PresetDlgLine r) "\t" (if (= 'STR (type (nth 3 r))) (nth 3 r) ""))))
  )
)

;;  Indexes of the presets to list: those of the Show group (pst:shw, "": all) and of the
;;  filter, and the selected one when pin is T, in the order of the sort:
(defun Remote>>Dyl:PresetDlgView (pin / f i lst)
  (setq f (strcase (vl-string-trim " " (cond (pst:flt) (""))))
        i -1
  )
  (foreach r pst:lst
    (setq i (1+ i))
    (if (or (and pin (= i pst:idx)) (and (Remote>>Dyl:PresetDlgInShow-p r) (Remote>>Dyl:PresetDlgMatch-p r f)))
      (setq lst (cons i lst))
    )
  )
  (setq lst (reverse lst))
  (vl-sort lst 'Remote>>Dyl:PresetDlgBefore)
)

;;  Lines of the list of the presets selected, "0 3 5" ("": not listed):
(defun Remote>>Dyl:PresetDlgPos (/ l)
  (setq l (vl-remove nil (mapcar '(lambda (i) (vl-position i pst:view)) (Remote>>Dyl:PresetDlgSel))))
  (if l (Remote>>LM:lst->str (mapcar 'itoa (vl-sort l '<)) " ") "")
)

;;  Filter typed: the presets of the filter listed, the selected one kept when it has the
;;  text, else the first one that has it:
(defun Remote>>Dyl:PresetDlgFilter (val / m)
  (if (Remote>>Dyl:PresetDlgCommit)
    (progn
      (setq pst:flt val
            m       (Remote>>Dyl:PresetDlgView nil)
      )
      (if (and m (not (member pst:idx m))) (setq pst:idx (car m)))
      (setq pst:sel (list pst:idx))
      (Remote>>Dyl:PresetDlgShow)
    )
    (set_tile "flt" (cond (pst:flt) ("")))
  )
)

;;  Show: the list shows the presets of one group (pst:shw, "": All). Set default saves the
;;  group shown for the tool (the DynalispPresetShow<tool> user setting, all drawings): the
;;  window opens on it.

;;  Name of the user setting of the default Show group of the tool:
(defun Remote>>Dyl:PresetDlgShowEnv ()
  (strcat "DynalispPresetShow" pst:key)
)

;;  T when the preset r is in the Show group:
(defun Remote>>Dyl:PresetDlgInShow-p (r)
  (or (= "" pst:shw) (= (strcase pst:shw) (strcase (nth 1 r))))
)

;;  Groups of the Show popup: All, then the groups of the presets (in the order of the Group
;;  popup of the tool, else sorted), and the group shown when no preset is in it any more:
(defun Remote>>Dyl:PresetDlgShowGroups (/ used lst)
  (foreach r pst:lst
    (if (not (member (nth 1 r) used)) (setq used (cons (nth 1 r) used)))
  )
  (setq lst (if pst:grps
              (vl-remove-if-not '(lambda (g) (member g used)) pst:grps)
              (acad_strlsort used)
            )
  )
  (if (and (/= "" pst:shw) (not (member pst:shw lst))) (setq lst (append lst (list pst:shw))))
  (cons "All" lst)
)

;;  Fill the Show popup (again only when its groups changed, see pst:shwlst) and show the
;;  group of pst:shw:
(defun Remote>>Dyl:PresetDlgShowFill (/ lst)
  (setq lst (Remote>>Dyl:PresetDlgShowGroups))
  (if (not (equal lst pst:shwlst))
    (progn
      (start_list "shg")
      (foreach g lst (add_list g))
      (end_list)
      (setq pst:shwlst lst)
    )
  )
  (set_tile "shg" (itoa (cond ((if (/= "" pst:shw) (vl-position pst:shw lst))) (0))))
)

;;  A group picked in Show: its presets listed, the selected one kept when it is in it, else
;;  the first one of the group:
(defun Remote>>Dyl:PresetDlgShowPick (val / g m)
  (if (Remote>>Dyl:PresetDlgCommit)
    (progn
      (setq g       (nth (atoi val) pst:shwlst)
            pst:shw (if (or (not g) (= "0" val)) "" g)
            m       (Remote>>Dyl:PresetDlgView nil)
      )
      (if (and m (not (member pst:idx m))) (setq pst:idx (car m)))
      (setq pst:sel (list pst:idx))
      (Remote>>Dyl:PresetDlgShow)
    )
    (Remote>>Dyl:PresetDlgShowFill)
  )
)

;;  Set default: the group shown is the one the window opens on (All: every preset):
(defun Remote>>Dyl:PresetDlgShowDefault ()
  (setenv (Remote>>Dyl:PresetDlgShowEnv) pst:shw)
  (set_tile "error"
            (strcat (Remote>>Dyl:PresetProp pst:key 'title)
                    " now opens on "
                    (if (= "" pst:shw) "every group." (strcat "the group " pst:shw "."))
            )
  )
)

;;  Sort picked, kept for the tool for the session:
(defun Remote>>Dyl:PresetDlgSort (val)
  (setq pst:srt            (cond ((nth (atoi val) (Remote>>Dyl:PresetDlgSorts))) ("Name"))
        *dyl:presetsort* (cons (cons pst:key pst:srt) (vl-remove (assoc pst:key *dyl:presetsort*) *dyl:presetsort*))
  )
  (Remote>>Dyl:PresetDlgList)
)

;;  Fill the list with the presets of the filter, in the order of the sort. A list refilled
;;  scrolls back to its top and setting its selection scrolls to it, so the list does not move
;;  when a preset is picked: only the lines that changed are replaced (pst:lines, the lines
;;  shown; the whole list only when the number of lines changed), and the selection is set
;;  only when it is not the one shown:
(defun Remote>>Dyl:PresetDlgList (/ n lines pos i)
  (setq pst:view (Remote>>Dyl:PresetDlgView T)
        lines    (mapcar '(lambda (i) (Remote>>Dyl:PresetDlgLine (nth i pst:lst))) pst:view)
        pos      (Remote>>Dyl:PresetDlgPos)
  )
  (cond
    ((equal lines pst:lines))
    ((= (length lines) (length pst:lines))
     (setq i 0)
     (mapcar '(lambda (new old)
                (if (/= new old)
                  (progn
                    (start_list "lst" 1 i)
                    (add_list new)
                    (end_list)
                  )
                )
                (setq i (1+ i))
              )
             lines
             pst:lines
     )
    )
    (T
     (start_list "lst")
     (foreach l lines (add_list l))
     (end_list)
     ;;  A list refilled has no selection:
     (set_tile "lst" "")
    )
  )
  (setq pst:lines lines)
  (if (/= pos (get_tile "lst")) (set_tile "lst" pos))
  (Remote>>Dyl:PresetDlgShowFill)
  (setq n (length (Remote>>Dyl:PresetDlgView nil)))
  (set_tile "pcn"
            (cond
              ((and (= "" pst:shw) (= "" (vl-string-trim " " (cond (pst:flt) (""))))) (strcat (itoa (length pst:lst)) " " (Remote>>Dyl:PresetDlgNoun)))
              ((= 0 n) "No match")
              ((strcat (itoa n) " of " (itoa (length pst:lst))))
            )
  )
)

;;  Refresh the list, the preset status and the state of the buttons:
(defun Remote>>Dyl:PresetDlgState (/ r d sel)
  (setq r   (nth pst:idx pst:lst)
        d   (assoc (car r) (Remote>>Dyl:PresetDlgDefs))
        sel (mapcar '(lambda (j) (nth j pst:lst)) (Remote>>Dyl:PresetDlgSel))
  )
  (Remote>>Dyl:PresetDlgList)
  ;;  The status in the heading of the Parameters column (nothing for a default preset as
  ;;  shipped; several selected: their number), the command of the preset under it:
  (set_tile "prm"
            (cond
              ((cdr sel) (strcat "Parameters (" (itoa (length sel)) " selected)"))
              ((not d) "Parameters (custom)")
              ((not (equal r d)) "Parameters (modified)")
              ("Parameters")
            )
  )
  (if (Remote>>Dyl:PresetDlgCmds-p)
    (set_tile "src"
              (if (= "" (car r))
                "Gets its command once saved or given an alias."
                (strcat "Command: " (strcase (Remote>>Dyl:PresetCommand pst:key (car r))))
              )
    )
  )
  ;;  Reset Selected: a modified default preset selected; Delete: custom presets only. The
  ;;  name (unique) and Copy for one preset only:
  (mode_tile "rst"
             (if (vl-some '(lambda (x / y) (and (setq y (assoc (car x) (Remote>>Dyl:PresetDlgDefs))) (not (equal x y)))) sel)
               0
               1
             )
  )
  (mode_tile "del" (if (vl-some '(lambda (x) (assoc (car x) (Remote>>Dyl:PresetDlgDefs))) sel) 1 0))
  (mode_tile "nam" (if (cdr sel) 1 0))
  (mode_tile "cpy" (if (cdr sel) 1 0))
  ;;  The summary of the hatch preset under the popup:
  (if (Remote>>Dyl:PresetDlgMat)
    (set_tile "mts"
              (cond
                ((setq d (assoc (nth (Remote>>Dyl:PresetDlgMat) r) pst:mats)) (Remote>>Dyl:MaterialSummary d))
                ("")
              )
    )
  )
  (Remote>>Dyl:PresetDlgCall 'state (list r))
)

;;  Show the values of the selected preset:
(defun Remote>>Dyl:PresetDlgShow (/ r items)
  (setq r (nth pst:idx pst:lst))
  ;;  The materials of its group in the Hatch preset popup:
  (if (Remote>>Dyl:PresetDlgMat) (Remote>>Dyl:PresetDlgMatFill))
  (foreach x (Remote>>Dyl:PresetDlgTiles)
    (set_tile (car x)
              (if (setq items (Remote>>Dyl:PresetDlgItems (car x)))
                (itoa (cond ((vl-position (nth (cdr x) r) items)) (0)))
                (nth (cdr x) r)
              )
    )
  )
  (set_tile "error" "")
  (Remote>>Dyl:PresetDlgState)
  (if (Remote>>Dyl:PresetDlgCmds-p) (Remote>>Dyl:PresetDlgAliases))
)

;;  Validate the value of a tile and store it in the selected preset, returns T when valid:
(defun Remote>>Dyl:PresetDlgField (key val / items msg old)
  (setq old (nth 1 (nth pst:idx pst:lst)))
  ;;  The popups return the index of the value in their list:
  (if (setq items (Remote>>Dyl:PresetDlgItems key))
    (setq val (cond ((nth (atoi val) items)) ("")))
  )
  (setq val (vl-string-trim " \t" val))
  (if (member key (cdr (assoc 'upper pst:dlg))) (setq val (strcase val)))
  (setq msg (cond
              ((and (= "" val) (= "nam" key)) "The name cannot be empty.")
              ((and (= "" val) (= "grp" key)) "The group cannot be empty.")
              ((and (= "nam" key) (Remote>>Dyl:PresetTaken-p val pst:idx))
               (strcat "Another preset is already named \"" val "\".")
              )
              ((and (= "mat" key) (not (assoc val pst:mats))) "This hatch preset no longer exists: pick another one.")
              ((Remote>>Dyl:PresetDlgCall 'check (list key val)))
            )
  )
  (if msg
    (progn
      (set_tile "error" msg)
      (mode_tile key 2)
      nil
    )
    (progn
      ;;  To every preset selected (the preset shown only for the name, and while committing):
      (if (= "nam" key)
        (setq pst:lst (Remote>>Dyl:ListSubst pst:lst pst:idx (Remote>>Dyl:ListSubst (nth pst:idx pst:lst) 2 val)))
        (Remote>>Dyl:PresetDlgPut (cdr (assoc key (Remote>>Dyl:PresetDlgTiles))) val)
      )
      (if (not items) (set_tile key val))
      (set_tile "error" "")
      ;;  Another group: the Hatch preset popup lists its materials (not while committing:
      ;;  the group was stored by its action, the Hatch preset popup shows the preset's):
      (if (and (= "grp" key) (Remote>>Dyl:PresetDlgMat) (not pst:one) (/= (strcase old) (strcase val)))
        (Remote>>Dyl:PresetDlgMatGroup)
      )
      t
    )
  )
)

;;  Store every tile in the preset shown, returns T when they are all valid. The tiles the
;;  App skips (greyed out, showing values that are not the preset's) are not stored. Only in
;;  the preset shown (pst:one): a value changed was given to every preset selected by the
;;  action of its tile:
(defun Remote>>Dyl:PresetDlgCommit (/ ok skip pst:one)
  (setq pst:one t
        ok   t
        skip (Remote>>Dyl:PresetDlgCall 'skip (list (nth pst:idx pst:lst)))
  )
  (foreach x (Remote>>Dyl:PresetDlgTiles)
    (if (and ok (not (member (car x) skip))) (setq ok (Remote>>Dyl:PresetDlgField (car x) (get_tile (car x)))))
  )
  ok
)

;;  Select other presets (the current one must be valid first): lines val of the list picked
;;  ("3", or "0 3 5"), the presets they show (see pst:view). The preset
;;  shown stays when it is still selected, else the first one selected:
(defun Remote>>Dyl:PresetDlgPick (val / l)
  (setq l (vl-remove nil (mapcar '(lambda (n) (nth n pst:view)) (read (strcat "(" (cond (val) ("")) ")")))))
  (if (and l (Remote>>Dyl:PresetDlgCommit))
    (progn
      (setq pst:sel l
            pst:idx (if (member pst:idx l) pst:idx (car l))
      )
      (Remote>>Dyl:PresetDlgShow)
    )
    (set_tile "lst" (Remote>>Dyl:PresetDlgPos))
  )
)

;;  Add a custom preset after the selected one and select its name:
(defun Remote>>Dyl:PresetDlgAdd (rec)
  (if (Remote>>Dyl:PresetDlgCommit)
    (progn
      (setq pst:idx (1+ pst:idx)
            pst:lst (Remote>>Dyl:ListInsert pst:lst
                                             pst:idx
                                             (Remote>>Dyl:ListSubst rec 2 (Remote>>Dyl:PresetUnique (nth 2 rec) nil))
                    )
            pst:sel (list pst:idx)
      )
      (Remote>>Dyl:PresetDlgShow)
      (mode_tile "nam" 2)
      (mode_tile "nam" 3)
    )
  )
)

;;  New: custom preset in the group of the selected preset:
(defun Remote>>Dyl:PresetDlgNew ()
  (Remote>>Dyl:PresetDlgAdd
    (cons "" (Remote>>Dyl:ListSubst (cdr (cdr (assoc 'new pst:dlg))) 0 (nth 1 (nth pst:idx pst:lst))))
  )
)

;;  Copy: custom preset with the values of the selected preset:
(defun Remote>>Dyl:PresetDlgCopy (/ r)
  (setq r (nth pst:idx pst:lst))
  (Remote>>Dyl:PresetDlgAdd (cons "" (Remote>>Dyl:ListSubst (cdr r) 1 (strcat (nth 2 r) " copy"))))
)

;;  Delete the custom presets selected, with the aliases of their command:
(defun Remote>>Dyl:PresetDlgDelete (/ sel i c)
  (setq sel (Remote>>Dyl:PresetDlgSel))
  (if
    (Remote>>Dyl:PresetDlgAsk
      (if (cdr sel)
        (strcat "Delete the " (itoa (length sel)) " custom " (Remote>>Dyl:PresetDlgNoun) " selected"
                (if (Remote>>Dyl:PresetDlgCmds-p) " and their aliases" "")
                "?"
        )
        (strcat "Delete the custom preset \""
                (nth 2 (nth pst:idx pst:lst))
                "\""
                (if pst:alst " and its aliases" "")
                "?"
        )
      )
    )
    (progn
      (foreach j sel
        (if (setq c (Remote>>Dyl:PresetCommand pst:key (car (nth j pst:lst))))
          (setq c       (strcase c)
                pst:als (vl-remove-if '(lambda (p) (= c (cdr p))) pst:als)
          )
        )
      )
      (setq i       -1
            pst:lst (vl-remove-if '(lambda (r) (member (setq i (1+ i)) sel)) pst:lst)
            pst:idx (min (apply 'min sel) (1- (length pst:lst)))
            pst:sel (list pst:idx)
      )
      (Remote>>Dyl:PresetDlgShow)
    )
  )
)

;;  Reset the default presets selected to their default values (the custom ones selected
;;  are left as they are):
(defun Remote>>Dyl:PresetDlgReset (/ d)
  (foreach j (Remote>>Dyl:PresetDlgSel)
    (if (setq d (assoc (car (nth j pst:lst)) (Remote>>Dyl:PresetDlgDefs)))
      (progn
        (setq pst:lst (Remote>>Dyl:ListSubst pst:lst j d))
        (Remote>>Dyl:PresetDlgRename j)
      )
    )
  )
  (Remote>>Dyl:PresetDlgShow)
)

;;  Reset every default preset to its default values (custom presets are kept):
(defun Remote>>Dyl:PresetDlgRestore ()
  (if
    (Remote>>Dyl:PresetDlgAsk
      "Reset every default preset to its default values? Custom presets are kept."
    )
    (progn
      (setq pst:lst (mapcar '(lambda (r) (cond ((assoc (car r) (Remote>>Dyl:PresetDlgDefs))) (r))) pst:lst))
      (Remote>>Dyl:PresetDlgRename nil)
      (Remote>>Dyl:PresetDlgShow)
    )
  )
)

;;-------------------------=={ Aliases }==------------------------;;

;;  Aliases panel: the aliases of the command of the selected preset (Resources\Aliases.csv,
;;  see Dyl:AliasRead in dynalisp.mnl). Add creates the alias typed, Rename gives the alias
;;  picked the name typed, Remove deletes the alias picked. They are saved with the presets
;;  (Draw / Save), Cancel discards them. Local variables of Remote>>Dyl:PresetDialog:
;;  pst:als (every alias: ((ALIAS . COMMAND) ...)), pst:acmd (command of the selected preset,
;;  upper case, nil for a custom preset without id yet), pst:alst (aliases of pst:acmd).

;;  Fill the panel for the selected preset:
(defun Remote>>Dyl:PresetDlgAliases (/ r)
  (setq r        (nth pst:idx pst:lst)
        pst:acmd (Remote>>Dyl:PresetCommand pst:key (car r))
        pst:acmd (if pst:acmd (strcase pst:acmd))
        pst:alst (if pst:acmd (Dyl:AliasesOf pst:acmd pst:als))
  )
  (start_list "als")
  (foreach a pst:alst (add_list a))
  (end_list)
  (mode_tile "aren" 1)
  (mode_tile "adel" 1)
  (set_tile "aln" (cond ((Remote>>Dyl:PresetDlgCall 'prefix (list r))) ("")))
  ;;  For one preset only (greyed out while several are selected):
  (foreach k '("als" "aln" "aad") (mode_tile k (if (cdr (Remote>>Dyl:PresetDlgSel)) 1 0)))
  (set_tile "ams"
            (cond
              ((cdr (Remote>>Dyl:PresetDlgSel)) "Several presets selected: pick one to edit its aliases.")
              ((not pst:acmd) "New preset: adding an alias gives it its command.")
              ((not pst:alst) "No alias yet: type one and click Add.")
              ("Pick an alias to rename or remove it.")
            )
  )
)

;;  An alias was picked: put it in the edit box for a rename:
(defun Remote>>Dyl:PresetDlgAliasPick (val)
  (if (and val (/= "" val) (nth (atoi val) pst:alst))
    (progn
      (set_tile "aln" (nth (atoi val) pst:alst))
      (mode_tile "aren" 0)
      (mode_tile "adel" 0)
      (set_tile "ams" "")
    )
  )
)

;;  Alias picked in the panel list (nil if none):
(defun Remote>>Dyl:PresetDlgAliasSel (/ v)
  (if (/= "" (setq v (get_tile "als"))) (nth (atoi v) pst:alst))
)

;;  Error message for the alias name a (nil when valid). old is the alias being renamed
;;  (nil for a new one):
(defun Remote>>Dyl:PresetDlgAliasCheck (a old / x)
  (cond
    ((= "" a) "Type an alias name.")
    ((not (Dyl:AliasName-p a)) "Use letters, digits, - and _ only.")
    ((= a old) "The name did not change.")
    ((= a pst:acmd) "This is the name of the command itself.")
    ((setq x (assoc a pst:als)) (strcat a " is already an alias of " (cdr x) "."))
    ((and (eval (read (strcat "C:" a))) (not (member a *dyl:aliasdefs*))) (strcat a " is already a command."))
    ((getcname a) (strcat a " is an AutoCAD command: the alias would never run."))
  )
)

;;  Apply a change of the aliases (new pst:als) and show msg:
(defun Remote>>Dyl:PresetDlgAliasDone (new msg)
  (setq pst:als new)
  (Remote>>Dyl:PresetDlgList)
  (Remote>>Dyl:PresetDlgAliases)
  (set_tile "ams" msg)
)

;;  Add, Rename and Remove buttons. A custom preset without id gets its id (and command)
;;  from its name when it is given its first alias:
(defun Remote>>Dyl:PresetDlgAliasAdd (/ a err)
  (setq a (Dyl:SuiteCmd (get_tile "aln")))
  (cond
    ((setq err (Remote>>Dyl:PresetDlgAliasCheck a nil)) (set_tile "ams" err))
    ((and (not pst:acmd) (not (Remote>>Dyl:PresetDlgCommit))))
    (t
     (if (not pst:acmd)
       (progn
         (setq pst:lst (Remote>>Dyl:PresetIds pst:lst))
         (Remote>>Dyl:PresetDlgState)
         (Remote>>Dyl:PresetDlgAliases)
       )
     )
     (Remote>>Dyl:PresetDlgAliasDone (append pst:als (list (cons a pst:acmd))) (strcat a " added."))
    )
  )
)
(defun Remote>>Dyl:PresetDlgAliasRename (/ old a err)
  (setq old (Remote>>Dyl:PresetDlgAliasSel)
        a   (Dyl:SuiteCmd (get_tile "aln"))
  )
  (cond
    ((not old) (set_tile "ams" "Pick the alias to rename."))
    ((setq err (Remote>>Dyl:PresetDlgAliasCheck a old)) (set_tile "ams" err))
    ((Remote>>Dyl:PresetDlgAliasDone
       (subst (cons a pst:acmd) (cons old pst:acmd) pst:als)
       (strcat old " renamed " a ".")
     )
    )
  )
)
(defun Remote>>Dyl:PresetDlgAliasRemove (/ old)
  (if (setq old (Remote>>Dyl:PresetDlgAliasSel))
    (Remote>>Dyl:PresetDlgAliasDone (vl-remove (cons old pst:acmd) pst:als) (strcat old " removed."))
    (set_tile "ams" "Pick the alias to remove.")
  )
)

;;  The DCL dialog: shown again after a code >= 3 (an App button: its status function runs,
;;  then the dialog is shown again with the presets being edited, dialogs are not nested).
;;  Returns the status it was closed with (1 Draw / OK, 2 Save, 0 Cancel, nil: not shown):
(defun Remote>>Dyl:PresetDlgLoop (/ dcl:pth dcl:sta pst:dcl)
  (setq dcl:pth (Remote>>Dyl:PresetDlgDcl)
        pst:dcl (load_dialog dcl:pth)
        dcl:sta 3
  )
  (while (and dcl:sta (<= 3 dcl:sta))
    (setq dcl:sta nil)
    ;;  The groups renamed since the dialog was shown (here or in a window opened from it),
    ;;  then the groups of the Group popup:
    (Remote>>Dyl:PresetDlgGroupsSync)
    (setq pst:grps (Remote>>Dyl:PresetDlgGrps))
    (if (and (>= pst:dcl 0) (new_dialog "dyl_pst" pst:dcl))
      (progn
        ;;  A new dialog: its list is empty (see Remote>>Dyl:PresetDlgList):
        (setq pst:lines  nil
              pst:shwlst nil
        )
        (if (Remote>>Dyl:PresetDlgMat) (Remote>>Dyl:PresetDlgMatInit))
        (Remote>>Dyl:PresetDlgCall 'init nil)
        (if pst:grps
          (progn
            (start_list "grp")
            (foreach g pst:grps (add_list g))
            (end_list)
            ;;  The Preset Groups window (code 8):
            (Dyl:MoreTile "gre" T)
            (action_tile "gre" "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog 8))")
          )
        )
        (start_list "hdr")
        (add_list (if (Remote>>Dyl:PresetDlgCmds-p) "Group\tName\tAliases" "Group\tName"))
        (end_list)
        (action_tile "hdr" "(set_tile \"hdr\" \"\")")
        ;;  Filter and sort, as they were when the dialog is shown again:
        (start_list "srt")
        (foreach s (Remote>>Dyl:PresetDlgSorts) (add_list s))
        (end_list)
        (set_tile "srt" (itoa (cond ((vl-position pst:srt (Remote>>Dyl:PresetDlgSorts))) (0))))
        (set_tile "flt" pst:flt)
        (action_tile "flt" "(Remote>>Dyl:PresetDlgFilter $value)")
        (action_tile "srt" "(Remote>>Dyl:PresetDlgSort $value)")
        (action_tile "shg" "(Remote>>Dyl:PresetDlgShowPick $value)")
        (action_tile "shd" "(Remote>>Dyl:PresetDlgShowDefault)")
        (Remote>>Dyl:PresetDlgShow)
        (foreach x (Remote>>Dyl:PresetDlgTiles)
          (action_tile (car x) "(if (Remote>>Dyl:PresetDlgField $key $value) (Remote>>Dyl:PresetDlgState))")
        )
        (action_tile "lst" "(Remote>>Dyl:PresetDlgPick $value)")
        (action_tile "new" "(Remote>>Dyl:PresetDlgNew)")
        (action_tile "cpy" "(Remote>>Dyl:PresetDlgCopy)")
        (action_tile "del" "(Remote>>Dyl:PresetDlgDelete)")
        (action_tile "rst" "(Remote>>Dyl:PresetDlgReset)")
        (action_tile "all" "(Remote>>Dyl:PresetDlgRestore)")
        (Dyl:DocsTile (Remote>>Dyl:PresetDlgDocFile))
        (action_tile "als" "(Remote>>Dyl:PresetDlgAliasPick $value)")
        (action_tile "aad" "(Remote>>Dyl:PresetDlgAliasAdd)")
        (action_tile "aren" "(Remote>>Dyl:PresetDlgAliasRename)")
        (action_tile "adel" "(Remote>>Dyl:PresetDlgAliasRemove)")
        ;;  OK / Draw / Save: the values valid, and asked first when more presets were changed
        ;;  than (warn . n) allows:
        (action_tile "accept"
                     (if (Remote>>Dyl:PresetDlgCmds-p)
                       "(if (and (Remote>>Dyl:PresetDlgCommit) (Remote>>Dyl:PresetDlgWarnOk)) (done_dialog 1))"
                       "(if (and (Remote>>Dyl:PresetDlgCommit) (Remote>>Dyl:PresetDlgWarnOk)) (done_dialog 2))"
                     )
        )
        (action_tile "sav" "(if (and (Remote>>Dyl:PresetDlgCommit) (Remote>>Dyl:PresetDlgWarnOk)) (done_dialog 2))")
        (setq dcl:sta (start_dialog))
      )
      (alert (strcat "\nError: " (Remote>>Dyl:PresetProp pst:key 'title) " dialog could not be loaded"))
    )
    (if (and dcl:sta (<= 3 dcl:sta)) (setq dcl:sta (Remote>>Dyl:PresetDlgCode dcl:sta)))
  )
  (if (>= pst:dcl 0) (unload_dialog pst:dcl))
  (vl-file-delete dcl:pth)
  dcl:sta
)

;;  A code >= 3 the dialog (or the window) was closed with: the Preset Groups window (8),
;;  the Hatch Presets window (9), else the status function of the App. Returns the code
;;  (the dialog is shown again), 2 when the status function asks to save and close:
(defun Remote>>Dyl:PresetDlgCode (sta / mat)
  (cond
    ;;  The Preset Groups window: its renames are given to the presets being edited when
    ;;  the dialog is shown again (see Remote>>Dyl:PresetDlgGroupsSync):
    ((= 8 sta) (Remote>>Dyl:GroupsDialog (Remote>>Dyl:PresetDlgGroupCounts)) sta)
    ;;  Edit materials: the material selected on OK is given to the presets selected (see
    ;;  Remote>>Dyl:PresetDlgPut):
    ((= 9 sta)
     (if (setq mat (Remote>>Dyl:MaterialDialog (nth (Remote>>Dyl:PresetDlgMat) (nth pst:idx pst:lst))))
       (Remote>>Dyl:PresetDlgPut (Remote>>Dyl:PresetDlgMat) (car mat))
     )
     sta
    )
    ((= 'save (Remote>>Dyl:PresetDlgCall 'status (list sta (nth pst:idx pst:lst)))) 2)
    (sta)
  )
)

;;-------------------------=={ Window }==------------------------;;

;;  A tool with (window . "Dyl-QuickDraw.xaml") in the App part of its dialog is shown in
;;  that WPF window (DynALisp.Windows.dll, Installer\Windows\Engine\Presets.cs), not in the
;;  DCL dialog above. The window does it all itself, with the same rules (the list, its
;;  filter, sort and Show group, the presets selected, New, Copy, Delete, the resets, the
;;  aliases): the Lisp gives it the presets, gets them back as edited when it closes, and
;;  saves them (Draw, Save) as the dialog does. A code >= 3 (an open button) runs as in the
;;  dialog (see Remote>>Dyl:PresetDlgCode), then the window is shown again on the presets
;;  being edited. The App part gives, besides the properties of the dialog it uses (defs,
;;  fix, tiles, upper, new, check, status, groups, material):
;;
;;    (window . "Dyl-QuickDraw.xaml")   ; the window file, in the Res folder of the Dynalisp module
;;    (wtiles . "hbr:28:inv,mai:41")    ; other controls of the window and their column (inv: a
;;                                      ; checkbox showing the inverse of its column), added
;;                                      ; to tiles (see pst/tiles in Presets.cs)
;;    (extra . <function: preset -> the columns added after the columns of the file, for
;;              the window only: a summary, a preview (read, never saved)>)
;;    (spec 45 . "mas")                 ; the column of a preview of its own (an assembly), and
;;                                      ; the rule of the window when it is used (else the
;;                                      ; preview is the hatch of the material)
;;    (mspec . <function: material -> its preview, see Installer\Windows\Engine\Hatch.cs>)
;;    (wprefix . "4|Polyline=PL-|*=QD-") ; the text of a new alias, by the value of a column
;;    (wprep . <function: called before the window is shown, nil>)
;;    (wvals . <function: -> the values of the window the App gives (its lists...)>)
;;
;;  The values given are those of Presets.cs (pst/rows...). Before the presets are saved,
;;  the values of every preset changed are checked again by the check function of the App,
;;  and the new aliases by AutoCAD (an AutoCAD command): the first one not valid opens the
;;  window again on its preset, with its message.

;;  The columns of a preset in the file:
(defun Remote>>Dyl:PresetWinCols ()
  (length (Remote>>Dyl:PresetProp pst:key 'header))
)

;;  A preset for the window: its columns, then those of the App (extra):
(defun Remote>>Dyl:PresetWinRow (r)
  (append r (Remote>>Dyl:PresetDlgCall 'extra (list r)))
)

;;  A preset got back: its first n columns (the columns of the file):
(defun Remote>>Dyl:PresetWinCut (r n / res)
  (repeat n
    (setq res (cons (cond ((car r)) ("")) res)
          r   (cdr r)
    )
  )
  (reverse res)
)

;;  The controls of the values and their column: "nam:2,grp:1,mth:4,out:17:up,...":
(defun Remote>>Dyl:PresetWinTiles (/ up)
  (setq up (cdr (assoc 'upper pst:dlg)))
  (Remote>>LM:lst->str
    (append
      (mapcar '(lambda (x) (strcat (car x) ":" (itoa (cdr x)) (if (member (car x) up) ":up" "")))
              (Remote>>Dyl:PresetDlgTiles)
      )
      (if (cdr (assoc 'wtiles pst:dlg)) (list (cdr (assoc 'wtiles pst:dlg))))
    )
    ","
  )
)

;;  The names an alias cannot take: ((NAME what-has-it) ...), the Lisp commands defined
;;  (not the aliases of DynALisp: they are aliases) and the aliases of acad.pgp. The
;;  commands of AutoCAD are checked once the window is closed (see
;;  Remote>>Dyl:PresetWinCheck):
(defun Remote>>Dyl:PresetWinTaken (/ defs res v)
  (setq defs (mapcar 'strcase *dyl:aliasdefs*))
  (foreach a (atoms-family 1)
    (if (and (wcmatch (strcase a) "C:?*")
             (not (member (substr (strcase a) 3) defs))
             (not (vl-catch-all-error-p (setq v (vl-catch-all-apply 'eval (list (read a))))))
             v
        )
      (setq res (cons (list (substr (strcase a) 3) "a command") res))
    )
  )
  (foreach p (if Dyl:PgpAliases (Dyl:PgpAliases))
    (setq res (cons (list (car p) (strcat "an alias of acad.pgp (" (cdr p) ")")) res))
  )
  res
)

;;  The values of the window: the presets, the state of the list, the aliases, the hatch
;;  presets, the values of the App. err: a message to show (nil: none):
(defun Remote>>Dyl:PresetWinVals (err / spec)
  (setq spec (assoc 'spec pst:dlg))
  (append
    (list (cons "pst/rows" (mapcar 'Remote>>Dyl:PresetWinRow pst:lst))
          (cons "pst/defs" (mapcar 'Remote>>Dyl:PresetWinRow (Remote>>Dyl:PresetDlgDefs)))
          (list "pst/new" (Remote>>Dyl:PresetWinRow (cdr (assoc 'new pst:dlg))))
          (cons "pst/ncols" (itoa (Remote>>Dyl:PresetWinCols)))
          (cons "pst/tiles" (Remote>>Dyl:PresetWinTiles))
          (cons "pst.idx" (itoa pst:idx))
          (cons "pst.sel" (Remote>>LM:lst->str (mapcar 'itoa (Remote>>Dyl:PresetDlgSel)) " "))
          (cons "pst.shw" pst:shw)
          (cons "flt" (cond (pst:flt) ("")))
          (cons "pst/title" (Remote>>Dyl:PresetProp pst:key 'title))
          (cons "pst/noun" (Remote>>Dyl:PresetDlgNoun))
          (cons "error" (cond (err) ("")))
    )
    (Dyl:WinList "srt" (Remote>>Dyl:PresetDlgSorts) (cond ((vl-position pst:srt (Remote>>Dyl:PresetDlgSorts))) (0)))
    (if pst:grps (list (cons "grp/list" pst:grps)))
    (if (Remote>>Dyl:PresetDlgCmds-p)
      (list (cons "pst/cmds" "1")
            (cons "pst/base" (Remote>>Dyl:PresetProp pst:key 'base))
            (cons "pst/cmd" (Remote>>Dyl:PresetProp pst:key 'cmd))
            (cons "pst/als" (mapcar '(lambda (p) (list (car p) (cdr p))) pst:als))
            (cons "pst/taken" (Remote>>Dyl:PresetWinTaken))
            (cons "pst/prefix" (cond ((cdr (assoc 'wprefix pst:dlg))) ("")))
      )
    )
    (if (Remote>>Dyl:PresetDlgMat)
      (list (cons "pst/mat" (itoa (Remote>>Dyl:PresetDlgMat)))
            (cons "pst/mats"
                  (mapcar '(lambda (m)
                             (list (car m) (nth 1 m) (nth 2 m)
                                   (cond ((Remote>>Dyl:PresetDlgCall 'mspec (list m))) ("X?1"))
                                   (strcase (nth 3 m))
                             )
                           )
                          pst:mats
                  )
            )
      )
    )
    (if spec (list (cons "pst/spec" (itoa (cadr spec))) (cons "pst/specby" (cddr spec))))
    (Remote>>Dyl:PresetDlgCall 'wvals nil)
  )
)

;;  The presets got back from the window res (Dyl:WinShow): the presets edited, the presets
;;  selected, the aliases, the filter, the sort and the Show group (the view choices: also on
;;  Cancel), its default when Set default was clicked:
(defun Remote>>Dyl:PresetWinGet (res / rows n sel)
  (setq rows (cdr (assoc "pst/rows" (cdr res)))
        n    (Remote>>Dyl:PresetWinCols)
  )
  (if rows
    (setq pst:lst (mapcar '(lambda (r) (Remote>>Dyl:PresetWinCut r n)) rows)
          pst:als (mapcar '(lambda (p) (cons (car p) (cadr p))) (cdr (assoc "pst/als" (cdr res))))
          pst:idx (max 0 (min (atoi (cond ((Dyl:WinGet res "pst.idx")) ("0"))) (1- (length pst:lst))))
          sel     (vl-remove-if-not '(lambda (i) (and (= 'INT (type i)) (< -1 i (length pst:lst))))
                                    (read (strcat "(" (cond ((Dyl:WinGet res "pst.sel")) ("")) ")"))
                  )
          pst:sel (if (member pst:idx sel) sel (list pst:idx))
    )
  )
  (setq pst:flt          (cond ((Dyl:WinGet res "flt")) (""))
        pst:shw          (cond ((Dyl:WinGet res "pst.shw")) (pst:shw))
        pst:srt          (cond ((nth (Dyl:WinIdx res "srt") (Remote>>Dyl:PresetDlgSorts))) ("Name"))
        *dyl:presetsort* (cons (cons pst:key pst:srt) (vl-remove (assoc pst:key *dyl:presetsort*) *dyl:presetsort*))
  )
  (if (= "1" (Dyl:WinGet res "pst.shd")) (setenv (Remote>>Dyl:PresetDlgShowEnv) pst:shw))
)

;;  The presets got back checked again: every value of a preset changed (or added) since the
;;  window opened, by the check function of the App (as the dialog checks a value typed),
;;  and the aliases added, by AutoCAD (an alias with the name of an AutoCAD command never
;;  runs: it is removed). The message of the first one not valid, its preset shown (nil:
;;  all valid):
(defun Remote>>Dyl:PresetWinCheck (/ i msg)
  (setq i -1)
  (setq msg
         (vl-some
           '(lambda (r)
              (setq i (1+ i))
              (if (not (member r pst:lst0))
                (vl-some
                  '(lambda (x / m)
                     (if (setq m (Remote>>Dyl:PresetDlgCall 'check (list (car x) (nth (cdr x) r))))
                       (progn
                         (setq pst:idx i
                               pst:sel (list i)
                         )
                         (strcat (nth 2 r) ": " m)
                       )
                     )
                   )
                  (cdr (assoc 'tiles pst:dlg))
                )
              )
            )
           pst:lst
         )
  )
  (foreach p pst:als
    (if (and (not msg) (not (member p pst:als0)) (getcname (car p)))
      (setq msg     (strcat (car p) " is an AutoCAD command: the alias would never run.")
            pst:als (vl-remove p pst:als)
      )
    )
  )
  msg
)

;;  Show the window of the tool, again after each code >= 3 (see Remote>>Dyl:PresetDlgCode)
;;  and after a value not valid (see Remote>>Dyl:PresetWinCheck). Returns the status it was
;;  closed with (1 Draw, 2 Save, 0 Cancel, nil: not shown, see Dyl:WinShow):
(defun Remote>>Dyl:PresetWin (/ sta res err)
  (setq sta 3)
  (while (and sta (<= 3 sta))
    ;;  The groups renamed since the window was shown (here or in a window opened from it),
    ;;  the groups of the Group list, the hatch presets (they may have been edited):
    (Remote>>Dyl:PresetDlgGroupsSync)
    (setq pst:grps (Remote>>Dyl:PresetDlgGrps)
          pst:mats (if (Remote>>Dyl:PresetDlgMat) (Remote>>Dyl:MaterialRead))
    )
    (Remote>>Dyl:PresetDlgCall 'wprep nil)
    (setq res (Dyl:WinShow (cdr (assoc 'window pst:dlg)) (Remote>>Dyl:PresetWinVals err))
          err nil
          sta (car res)
    )
    (if res (Remote>>Dyl:PresetWinGet res))
    (cond
      ((not sta))
      ((= 0 sta))
      ;;  A value not valid: shown again with its message (the code asked for is dropped):
      ((setq err (Remote>>Dyl:PresetWinCheck)) (setq sta 99))
      ((<= 3 sta) (setq sta (Remote>>Dyl:PresetDlgCode sta)))
    )
  )
  sta
)

;;-------------------------=={ Dialog box }==------------------------;;

;;  Show the preset dialog of the tool pst:key with the App part pst:dlg (see above).
;;  Draw and Save (OK for a tool without commands) write the presets file and the aliases.
;;  Returns the preset to draw (the preset selected on OK for a tool without commands), or
;;  nil on Save / Cancel:
(defun Remote>>Dyl:PresetDialog (pst:key pst:dlg / dcl:sta pst:lst pst:lst0 pst:idx pst:sel pst:als0 pst:als
                                 pst:acmd pst:alst pst:grps pst:gren pst:mats pst:matids sel
                                 pst:view pst:flt pst:srt pst:lines pst:shw pst:shwlst
                                )
  ;;  The sort of the list of this tool, kept for the session (*dyl:presetsort*):
  (setq pst:srt (cdr (assoc pst:key *dyl:presetsort*))
        pst:srt (if (member pst:srt (Remote>>Dyl:PresetDlgSorts)) pst:srt "Name")
        pst:flt ""
  )
  (setq pst:lst  (Remote>>Dyl:PresetRead pst:key (Remote>>Dyl:PresetDlgDefs) (cdr (assoc 'fix pst:dlg)))
        sel      (cdr (assoc 'select pst:dlg))
        pst:idx  (min (cond
                        ((if sel (vl-position (assoc sel pst:lst) pst:lst)))
                        ((cdr (assoc pst:key *dyl:presetlast*)))
                        (0)
                      )
                      (1- (length pst:lst))
                 )
        pst:sel  (list pst:idx)
        pst:lst0 pst:lst
        pst:als0 (Dyl:AliasRead)
        pst:als  pst:als0
        pst:gren (length *grp:renames*)
  )
  ;;  Show: the default group of the tool when a preset is in it (else All); the preset shown
  ;;  is then one of the group, but the one the window was opened on:
  (setq pst:shw (cond ((getenv (Remote>>Dyl:PresetDlgShowEnv))) ("")))
  (if (not (vl-some '(lambda (r) (Remote>>Dyl:PresetDlgInShow-p r)) pst:lst)) (setq pst:shw ""))
  (if (and (not sel) (not (Remote>>Dyl:PresetDlgInShow-p (nth pst:idx pst:lst))))
    (setq pst:idx (car (Remote>>Dyl:PresetDlgView nil))
          pst:sel (list pst:idx)
    )
  )
  (if (cdr (assoc 'window pst:dlg))
    ;;  In its WPF window (see Window below):
    (setq dcl:sta (Remote>>Dyl:PresetWin))
    (setq dcl:sta (Remote>>Dyl:PresetDlgLoop))
  )
  (if (member dcl:sta '(1 2))
    (progn
      ;;  The dialog reopens on the last preset used during the session:
      (setq *dyl:presetlast* (cons (cons pst:key pst:idx)
                                   (vl-remove (assoc pst:key *dyl:presetlast*) *dyl:presetlast*)
                             )
            ;;  The new custom presets get their id now, so the preset returned has it:
            pst:lst          (Remote>>Dyl:PresetIds pst:lst)
      )
      (if (not (Remote>>Dyl:PresetWrite pst:key pst:lst))
        (alert (strcat "\nError: the presets could not be saved to\n"
                       (Remote>>Dyl:PresetFileW pst:key)
                       "\n(is it open in Excel?)"
               )
        )
        (progn
          (if (and (not (equal pst:als pst:als0)) (not (Dyl:AliasWrite pst:als)))
            (alert (strcat "\nError: the aliases could not be saved to\n" (Dyl:UserFileW *dyl:alias) "\n(is it open in Excel?)"))
          )
          ;;  The commands of the custom presets and the aliases follow the files saved:
          (if Dyl:DynApply (progn (Dyl:DynApply) (Dyl:AliasApply)))
        )
      )
      (if (or (= 1 dcl:sta) (not (Remote>>Dyl:PresetDlgCmds-p))) (nth pst:idx pst:lst))
    )
  )
)

(princ)
