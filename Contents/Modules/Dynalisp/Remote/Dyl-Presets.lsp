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
;;    (status . <function: code preset, called when the dialog is closed with a code >= 3;
;;               returns save to save the presets and close the dialog (no reopen)>)
;;    (prefix . <function: preset -> text put in the new alias box, e.g. "QD-">)
;;    (select . <id of the preset selected when the dialog opens (default: the last one)>)
;;    (groups "Floor" ...)          ; groups of the Group popup (no groups: Group is an edit box)
;;    (material . 3)                ; index of a material id in a preset (see Materials below)
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
;;  The functions below run inside Remote>>Dyl:PresetDialog and use its local variables:
;;  pst:key (tool), pst:dlg (part of the App), pst:lst (presets being edited), pst:idx
;;  (index of the selected preset), pst:dcl (dialog id), pst:grps (groups of the Group popup),
;;  pst:mats and pst:matids (materials, ids of the Material popup), and the variables of the
;;  aliases panel (see Aliases below).

;;  Call the function prop of the App part of the dialog (nil when it has none):
(defun Remote>>Dyl:PresetDlgCall (prop args / f)
  (if (setq f (cdr (assoc prop pst:dlg))) (apply f args))
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

;;  Fill the Material popup (each time the dialog is shown: the materials may have been
;;  edited) and set the action of the Edit materials button. It also works when the material
;;  of the preset no longer exists (only the material is then invalid), to pick or make another:
(defun Remote>>Dyl:PresetDlgMatInit ()
  (setq pst:mats   (Remote>>Dyl:MaterialRead)
        pst:matids (Remote>>Dyl:MaterialPopup "mat"
                                              pst:mats
                                              (mapcar '(lambda (r) (nth (Remote>>Dyl:PresetDlgMat) r)) pst:lst)
                   )
  )
  (action_tile
    "edm"
    "(if (or (Remote>>Dyl:PresetDlgCommit) (not (assoc (nth (Remote>>Dyl:PresetDlgMat) (nth pst:idx pst:lst)) pst:mats))) (done_dialog 9))"
  )
)

;;  Default presets of the tool:
(defun Remote>>Dyl:PresetDlgDefs ()
  (cdr (assoc 'defs pst:dlg))
)

;;  T when the presets of the tool are commands (aliases, Draw button):
(defun Remote>>Dyl:PresetDlgCmds-p ()
  (if (Remote>>Dyl:PresetProp pst:key 'cmd) t)
)

;;  Docs page of the tool (Open Docs button, see Dyl:DocsTile) (nil: none found): (doc . "Draw\\Dyl-Materials.htm") of
;;  its spec, relative to the Docs folder of the Dynalisp module, else the page named after
;;  its App (path . "Dynalisp\\Apps\\Draw\\Dyl-QuickDraw.lsp" -> Docs\Draw\Dyl-QuickDraw.htm):
(defun Remote>>Dyl:PresetDlgDocFile (/ doc app)
  (setq doc (Remote>>Dyl:PresetProp pst:key 'doc)
        app (Remote>>Dyl:PresetProp pst:key 'path)
  )
  ;;  The path found (not the T of an and):
  (cond
    ((and doc (findfile (strcat *dyl:dyl "\\Docs\\" doc))) (findfile (strcat *dyl:dyl "\\Docs\\" doc)))
    ((and app
          (setq app (findfile (strcat *dyl:dyl "\\Docs\\"
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
(defun Remote>>Dyl:PresetDlgDcl (/ title cmds tabs wid path file)
  ;;  Columns of the list: group, name, (aliases), status; the status, last, about 12 wide:
  (setq title (Remote>>Dyl:PresetProp pst:key 'title)
        cmds  (Remote>>Dyl:PresetDlgCmds-p)
        tabs  (if cmds "12 38 60" "12 46")
        wid   (if cmds "72" "58")
        path  (vl-filename-mktemp "pst" nil ".dcl")
        file  (open path "w")
  )
  (foreach line
    (append
      (list (strcat "dyl_pst : dialog { label = \"DynALisp - " title "\";")
            "  : row {"
            "    : column {"
            ;;  Filter and sort of the list (see Remote>>Dyl:PresetDlgView):
            "      : row {"
            ;;  Kept narrow: the list is as wide as the widest line of this column:
            "        : edit_box { key = \"flt\"; label = \"Filter:\"; edit_width = 16; edit_limit = 64; }"
            "        : popup_list { key = \"srt\"; label = \"Sort by:\"; edit_width = 12; }"
            "        : text { key = \"pcn\"; width = 12; }"
            "      }"
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
            (strcat "                   allow_accept = " (if cmds "true" "false") "; }")
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
            "    : boxed_column { label = \"Parameters\";"
            "      : edit_box { key = \"nam\"; label = \"Name:\"; edit_width = 28; edit_limit = 64; }"
            (if (assoc 'groups pst:dlg)
              "      : popup_list { key = \"grp\"; label = \"Group:\"; edit_width = 28; }"
              "      : edit_box { key = \"grp\"; label = \"Group:\"; edit_width = 28; edit_limit = 64; }"
            )
            "      spacer;"
      )
      (if (Remote>>Dyl:PresetDlgMat)
        (list "      : popup_list { key = \"mat\"; label = \"Material:\"; edit_width = 32; }"
              "      : text { key = \"mts\"; width = 50; }"
              "      : button { key = \"edm\"; label = \"Edit materials...\"; fixed_width = true; alignment = right; }"
              "      spacer;"
        )
      )
      (cdr (assoc 'params pst:dlg))
      (list "      spacer;"
            "      : text { key = \"src\"; width = 50; }"
            "    }"
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

;;  Fill the preset list: group, name, aliases (tools with commands) and status of each preset:
;;  Status of a preset r: "custom", "modified" (a default one changed) or "" (default):
(defun Remote>>Dyl:PresetDlgStatus (r / d)
  (setq d (assoc (car r) (Remote>>Dyl:PresetDlgDefs)))
  (cond
    ((not d) "custom")
    ((equal r d) "")
    ("modified")
  )
)

;;  List line of a preset r: group, name, aliases (tools with commands), status:
(defun Remote>>Dyl:PresetDlgLine (r / c)
  (setq c (Remote>>Dyl:PresetCommand pst:key (car r)))
  (strcat (nth 1 r)
          "\t"
          (nth 2 r)
          "\t"
          (cond
            ((not (Remote>>Dyl:PresetDlgCmds-p)) "")
            ((not c) "\t")
            ((strcat (cond ((Remote>>LM:lst->str (Dyl:AliasesOf (strcase c) pst:als) ", ")) ("")) "\t"))
          )
          (Remote>>Dyl:PresetDlgStatus r)
  )
)

;;-------------------------=={ Sort and filter }==------------------------;;

;;  The list shows pst:view: the indexes in pst:lst of the presets listed, in their order.
;;  pst:flt: the filter text (the presets whose group, name, aliases, status or third value,
;;  e.g. the pattern of a material, have it, any case; "": every preset), pst:srt: the sort
;;  (index in *pst:sorts*, 0: file order). The selected preset (pst:idx) is always listed,
;;  so the fields shown are those of a line of the list.
(setq *pst:sorts* '("File order" "Group" "Name" "Status"))

;;  Sort key of the preset at index i (see pst:srt), in upper case:
(defun Remote>>Dyl:PresetDlgKey (i / r)
  (setq r (nth i pst:lst))
  (strcase
    (cond
      ((= 1 pst:srt) (strcat (nth 1 r) "\t" (nth 2 r)))
      ((= 2 pst:srt) (nth 2 r))
      ;;  Status: custom, then modified, then the default presets:
      ((strcat (cdr (assoc (Remote>>Dyl:PresetDlgStatus r) '(("custom" . "1") ("modified" . "2") ("" . "3"))))
               "\t"
               (nth 1 r)
               "\t"
               (nth 2 r)
       )
      )
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

;;  Indexes of the presets to list: those of the filter, and the selected one when pin is T,
;;  in the order of the sort:
(defun Remote>>Dyl:PresetDlgView (pin / f i lst)
  (setq f (strcase (vl-string-trim " " (cond (pst:flt) (""))))
        i -1
  )
  (foreach r pst:lst
    (setq i (1+ i))
    (if (or (and pin (= i pst:idx)) (Remote>>Dyl:PresetDlgMatch-p r f)) (setq lst (cons i lst)))
  )
  (setq lst (reverse lst))
  (if (and pst:srt (/= 0 pst:srt)) (vl-sort lst 'Remote>>Dyl:PresetDlgBefore) lst)
)

;;  Line of the list of the selected preset ("": not listed):
(defun Remote>>Dyl:PresetDlgPos (/ p)
  (if (setq p (vl-position pst:idx pst:view)) (itoa p) "")
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
      (Remote>>Dyl:PresetDlgShow)
    )
    (set_tile "flt" (cond (pst:flt) ("")))
  )
)

;;  Sort picked, kept for the tool for the session:
(defun Remote>>Dyl:PresetDlgSort (val)
  (setq pst:srt            (atoi val)
        *dyl:presetsort* (cons (cons pst:key pst:srt) (vl-remove (assoc pst:key *dyl:presetsort*) *dyl:presetsort*))
  )
  (Remote>>Dyl:PresetDlgList)
)

;;  Fill the list with the presets of the filter, in the order of the sort:
(defun Remote>>Dyl:PresetDlgList (/ n)
  (setq pst:view (Remote>>Dyl:PresetDlgView T))
  (start_list "lst")
  (foreach i pst:view (add_list (Remote>>Dyl:PresetDlgLine (nth i pst:lst))))
  (end_list)
  (set_tile "lst" (Remote>>Dyl:PresetDlgPos))
  (setq n (length (Remote>>Dyl:PresetDlgView nil)))
  (set_tile "pcn"
            (cond
              ((= "" (vl-string-trim " " (cond (pst:flt) ("")))) (strcat (itoa (length pst:lst)) " presets"))
              ((= 0 n) "No preset matches")
              ((strcat (itoa n) " of " (itoa (length pst:lst))))
            )
  )
)

;;  Refresh the list, the preset status and the state of the buttons:
(defun Remote>>Dyl:PresetDlgState (/ r d)
  (setq r (nth pst:idx pst:lst)
        d (assoc (car r) (Remote>>Dyl:PresetDlgDefs))
  )
  (Remote>>Dyl:PresetDlgList)
  (set_tile "src"
            (cond
              ((not (Remote>>Dyl:PresetDlgCmds-p))
               (strcat (if d "Default" "Custom") " preset" (if (and d (not (equal r d))) " (modified)" ""))
              )
              ((= "" (car r)) "Custom preset - gets its command once saved or given an alias")
              ((strcat (if d "Default" "Custom")
                       " preset - command "
                       (strcase (Remote>>Dyl:PresetCommand pst:key (car r)))
                       (if (and d (not (equal r d))) " (modified)" "")
               )
              )
            )
  )
  (mode_tile "rst" (if (and d (not (equal r d))) 0 1))
  (mode_tile "del" (if d 1 0))
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
(defun Remote>>Dyl:PresetDlgField (key val / items msg)
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
              ((and (= "mat" key) (not (assoc val pst:mats))) "This material no longer exists: pick another one.")
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
      (setq pst:lst (Remote>>Dyl:ListSubst pst:lst
                                            pst:idx
                                            (Remote>>Dyl:ListSubst (nth pst:idx pst:lst)
                                                                   (cdr (assoc key (Remote>>Dyl:PresetDlgTiles)))
                                                                   val
                                            )
                    )
      )
      (if (not items) (set_tile key val))
      (set_tile "error" "")
      t
    )
  )
)

;;  Store every tile in the selected preset, returns T when they are all valid:
(defun Remote>>Dyl:PresetDlgCommit (/ ok)
  (setq ok t)
  (foreach x (Remote>>Dyl:PresetDlgTiles)
    (if ok (setq ok (Remote>>Dyl:PresetDlgField (car x) (get_tile (car x)))))
  )
  ok
)

;;  Select another preset (the current one must be valid first):
;;  Line val of the list picked: the preset it shows (see pst:view):
(defun Remote>>Dyl:PresetDlgPick (val / i)
  (if (and (Remote>>Dyl:PresetDlgCommit) (setq i (nth (atoi val) pst:view)))
    (progn
      (setq pst:idx i)
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

;;  Delete the selected custom preset, with the aliases of its command:
(defun Remote>>Dyl:PresetDlgDelete ()
  (if
    (Remote>>Dyl:PresetDlgAsk
      (strcat "Delete the custom preset \""
              (nth 2 (nth pst:idx pst:lst))
              "\""
              (if pst:alst " and its aliases" "")
              "?"
      )
    )
    (progn
      (if pst:acmd (setq pst:als (vl-remove-if '(lambda (p) (= pst:acmd (cdr p))) pst:als)))
      (setq pst:lst (Remote>>Dyl:ListRemove pst:lst pst:idx)
            pst:idx (min pst:idx (1- (length pst:lst)))
      )
      (Remote>>Dyl:PresetDlgShow)
    )
  )
)

;;  Reset the selected default preset to its default values:
(defun Remote>>Dyl:PresetDlgReset ()
  (setq pst:lst (Remote>>Dyl:ListSubst pst:lst
                                        pst:idx
                                        (assoc (car (nth pst:idx pst:lst)) (Remote>>Dyl:PresetDlgDefs))
                )
  )
  (Remote>>Dyl:PresetDlgRename pst:idx)
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
  (set_tile "ams"
            (cond
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

;;-------------------------=={ Dialog box }==------------------------;;

;;  Show the preset dialog of the tool pst:key with the App part pst:dlg (see above).
;;  Draw and Save (OK for a tool without commands) write the presets file and the aliases.
;;  Returns the preset to draw (the preset selected on OK for a tool without commands), or
;;  nil on Save / Cancel:
(defun Remote>>Dyl:PresetDialog (pst:key pst:dlg / dcl:pth dcl:sta pst:dcl pst:lst pst:idx pst:als0 pst:als
                                 pst:acmd pst:alst pst:grps pst:mats pst:matids sel mat
                                 pst:view pst:flt pst:srt
                                )
  ;;  The sort of the list of this tool, kept for the session (*dyl:presetsort*):
  (setq pst:srt (cond ((cdr (assoc pst:key *dyl:presetsort*))) (0))
        pst:flt ""
  )
  (setq dcl:pth  (Remote>>Dyl:PresetDlgDcl)
        pst:dcl  (load_dialog dcl:pth)
        pst:lst  (Remote>>Dyl:PresetRead pst:key (Remote>>Dyl:PresetDlgDefs) (cdr (assoc 'fix pst:dlg)))
        sel      (cdr (assoc 'select pst:dlg))
        pst:idx  (min (cond
                        ((if sel (vl-position (assoc sel pst:lst) pst:lst)))
                        ((cdr (assoc pst:key *dyl:presetlast*)))
                        (0)
                      )
                      (1- (length pst:lst))
                 )
        pst:als0 (Dyl:AliasRead)
        pst:als  pst:als0
        pst:grps (cdr (assoc 'groups pst:dlg))
        dcl:sta  3
  )
  ;;  Group popup: the groups of the App, then the other groups used by a preset (they stay
  ;;  selectable, e.g. a group typed in the presets file):
  (if pst:grps
    (foreach r pst:lst
      (if (not (member (nth 1 r) pst:grps)) (setq pst:grps (append pst:grps (list (nth 1 r)))))
    )
  )
  ;;  Code >= 3 = App button: its status function runs, then this dialog is shown again
  ;;  with the presets being edited (dialogs are not nested):
  (while (and dcl:sta (<= 3 dcl:sta))
    (setq dcl:sta nil)
    (if (and (>= pst:dcl 0) (new_dialog "dyl_pst" pst:dcl))
      (progn
        (if (Remote>>Dyl:PresetDlgMat) (Remote>>Dyl:PresetDlgMatInit))
        (Remote>>Dyl:PresetDlgCall 'init nil)
        (if pst:grps
          (progn
            (start_list "grp")
            (foreach g pst:grps (add_list g))
            (end_list)
          )
        )
        (start_list "hdr")
        (add_list (if (Remote>>Dyl:PresetDlgCmds-p) "Group\tName\tAliases\tStatus" "Group\tName\tStatus"))
        (end_list)
        (action_tile "hdr" "(set_tile \"hdr\" \"\")")
        ;;  Filter and sort, as they were when the dialog is shown again:
        (start_list "srt")
        (foreach s *pst:sorts* (add_list s))
        (end_list)
        (set_tile "srt" (itoa pst:srt))
        (set_tile "flt" pst:flt)
        (action_tile "flt" "(Remote>>Dyl:PresetDlgFilter $value)")
        (action_tile "srt" "(Remote>>Dyl:PresetDlgSort $value)")
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
        (action_tile "accept"
                     (if (Remote>>Dyl:PresetDlgCmds-p)
                       "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog 1))"
                       "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog 2))"
                     )
        )
        (action_tile "sav" "(if (Remote>>Dyl:PresetDlgCommit) (done_dialog 2))")
        (setq dcl:sta (start_dialog))
      )
      (alert (strcat "\nError: " (Remote>>Dyl:PresetProp pst:key 'title) " dialog could not be loaded"))
    )
    (cond
      ((not (and dcl:sta (<= 3 dcl:sta))))
      ;;  Edit materials: the material selected on OK is given to the preset:
      ((= 9 dcl:sta)
       (if (setq mat (Remote>>Dyl:MaterialDialog (nth (Remote>>Dyl:PresetDlgMat) (nth pst:idx pst:lst))))
         (setq pst:lst (Remote>>Dyl:ListSubst pst:lst
                                               pst:idx
                                               (Remote>>Dyl:ListSubst (nth pst:idx pst:lst)
                                                                      (Remote>>Dyl:PresetDlgMat)
                                                                      (car mat)
                                               )
                       )
         )
       )
      )
      ((= 'save (Remote>>Dyl:PresetDlgCall 'status (list dcl:sta (nth pst:idx pst:lst))))
       (setq dcl:sta 2)
      )
    )
  )
  (if (>= pst:dcl 0) (unload_dialog pst:dcl))
  (vl-file-delete dcl:pth)
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
