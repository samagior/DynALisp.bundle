;; Revisions - The revisions of a project, managed in one place as in Revit
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

;;  The revisions, the sheets, their files and the update of the drawings are in
;;  Modules\Dynalisp\Remote\Dyl-Revisions.lsp (read it first). This file has the windows:
;;
;;  - The Revisions window (Dyl-Revisions): the revisions of the project of the drawing,
;;    their parameters, the numbering of the project, and its sheets with the revisions
;;    each one has. OK saves them in the project and updates the sheets they change;
;;    Update All Sheets updates every sheet.
;;  - The Revision Title Blocks window (Pst-RevisionTitleBlocks, the open button of Title
;;    blocks): the attributes of the revision rows of each title block (RevisionBlocks.csv).
;;
;;  And the commands that draw a revision cloud with its tag (Pst-RevisionCloud) and update
;;  the drawing (Pst-RevisionsUpdate).

;;-------------------------=={ Dialogs }==------------------------;;

;;  Write the windows to a temporary DCL file, returns its path:
(defun Dyl:RevDcl (/ path file)
  (setq path (vl-filename-mktemp "rev" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("rev_more : image_button { height = 1; fixed_height = true; aspect_ratio = 1; fixed_width = true; color = -15; }"
      "rev_line : image { height = 0.8; fixed_height = true; color = -15; }"
      "rev_edit : edit_box { edit_width = 30; }"
      "rev_pop : popup_list { edit_width = 30; }"
      "rev_buttons : row { fixed_width = true; alignment = right;"
      "  : button { key = \"accept\"; label = \"OK\"; is_default = true; width = 12; fixed_width = true; }"
      "  : button { key = \"cancel\"; label = \"Cancel\"; is_cancel = true; width = 12; fixed_width = true; }"
      "  : button { key = \"docs\"; label = \"Open Docs\"; width = 12; fixed_width = true; }"
      "}"
      ;;  The Revisions window:
      "dyl_rev : dialog { label = \"DynALisp - Revisions\";"
      "  : text { key = \"prj\"; width = 124; }"
      "  : row {"
      "    : boxed_column { label = \"Revisions\";"
      "      : list_box { key = \"rhd\"; width = 74; height = 2; fixed_height = true; tabs = \"5 12 24 62\"; is_enabled = false; }"
      "      : list_box { key = \"rev\"; width = 74; height = 12; tabs = \"5 12 24 62\"; multiple_select = true; }"
      "      : row { fixed_width = true; alignment = left;"
      "        : button { key = \"new\"; label = \"New\"; width = 12; }"
      "        : button { key = \"del\"; label = \"Delete\"; width = 12; }"
      "        : button { key = \"up\"; label = \"Move Up\"; width = 12; }"
      "        : button { key = \"dn\"; label = \"Move Down\"; width = 12; }"
      "      }"
      "    }"
      "    : column {"
      "      : boxed_column { key = \"pbx\"; label = \"Parameters\";"
      "        : row { : rev_pop { key = \"num\"; label = \"Numbering:\"; } }"
      "        : row { : rev_edit { key = \"dat\"; label = \"Date:\"; } }"
      "        : row { : rev_edit { key = \"dsc\"; label = \"Description:\"; } }"
      "        : row { : rev_edit { key = \"ito\"; label = \"Issued to:\"; } }"
      "        : row { : rev_edit { key = \"iby\"; label = \"Issued by:\"; } }"
      "        : row { : toggle { key = \"iss\"; label = \"Issued\"; } }"
      "        : spacer { }"
      "      }"
      "      : boxed_column { label = \"Project\";"
      "        : row { : rev_pop { key = \"pnm\"; label = \"Numbering:\"; } }"
      "        : row { : rev_pop { key = \"pst\"; label = \"First number:\"; } }"
      "        : row {"
      "          : text { label = \"Title blocks:\"; }"
      "          : rev_more { key = \"tbm\"; }"
      "          : text { key = \"tbs\"; width = 28; fixed_width = true; }"
      "        }"
      "        : spacer { }"
      "      }"
      "    }"
      "  }"
      "  : boxed_column { key = \"sbx\"; label = \"Sheets\";"
      "    : list_box { key = \"shd\"; width = 124; height = 2; fixed_height = true; tabs = \"46 80 94\"; is_enabled = false; }"
      "    : list_box { key = \"sht\"; width = 124; height = 12; tabs = \"46 80 94\"; multiple_select = true; }"
      "    : row { fixed_width = true; alignment = left;"
      "      : button { key = \"add\"; label = \"Add Revision\"; width = 20; }"
      "      : button { key = \"rem\"; label = \"Remove Revision\"; width = 20; }"
      "      : button { key = \"all\"; label = \"Update All Sheets\"; width = 20; }"
      "    }"
      "  }"
      "  errtile;"
      "  rev_buttons;"
      "}"
      ;;  The Revision Title Blocks window:
      "dyl_revtb : dialog { label = \"DynALisp - Revision Title Blocks\";"
      "  : row {"
      "    : boxed_column { label = \"Title blocks\";"
      "      : list_box { key = \"thd\"; width = 46; height = 2; fixed_height = true; tabs = \"30 37\"; is_enabled = false; }"
      "      : list_box { key = \"tbl\"; width = 46; height = 17; tabs = \"30 37\"; multiple_select = true; }"
      "      : row { fixed_width = true; alignment = left;"
      "        : button { key = \"new\"; label = \"New\"; width = 12; }"
      "        : button { key = \"del\"; label = \"Delete\"; width = 12; }"
      "        : button { key = \"pck\"; label = \"Pick...\"; width = 12; }"
      "      }"
      "    }"
      "    : boxed_column { key = \"tbx\"; label = \"Parameters\";"
      "      : column { fixed_height = true;"
      "        : row { : rev_edit { key = \"nam\"; label = \"Block:\"; } }"
      "        : row { : rev_edit { key = \"rws\"; label = \"Rows:\"; } }"
      "        : row { : rev_pop { key = \"fst\"; label = \"Row 1:\"; } }"
      "      }"
      "      : spacer { }"
      "      : column { fixed_height = true;"
      "        : rev_line { key = \"ln1\"; }"
      "        : text { label = \"Row attributes:\"; }"
      "        : row { : rev_edit { key = \"a3\"; label = \"Number:\"; } }"
      "        : row { : rev_edit { key = \"a4\"; label = \"Date:\"; } }"
      "        : row { : rev_edit { key = \"a5\"; label = \"Description:\"; } }"
      "        : row { : rev_edit { key = \"a6\"; label = \"Issued to:\"; } }"
      "        : row { : rev_edit { key = \"a7\"; label = \"Issued by:\"; } }"
      "      }"
      "      : spacer { }"
      "      : column { fixed_height = true;"
      "        : rev_line { key = \"ln2\"; }"
      "        : text { label = \"Sheet attributes:\"; }"
      "        : row { : rev_edit { key = \"a8\"; label = \"Current revision:\"; } }"
      "        : row { : rev_edit { key = \"a9\"; label = \"Current date:\"; } }"
      "      }"
      "      : spacer { }"
      "    }"
      "  }"
      "  errtile;"
      "  rev_buttons;"
      "}"
     )
    (write-line line file)
  )
  (close file)
  path
)

;;  Fill a list or popup tile with the strings lst:
(defun Dyl:RevFillList (key lst)
  (start_list key)
  (foreach x lst (add_list x))
  (end_list)
)

;;  Indexes "0 3" <-> (0 3):
(defun Dyl:RevSelOf (str) (if (and str (/= "" str)) (read (strcat "(" str ")"))))
(defun Dyl:RevSelStr (sel) (cond ((Remote>>LM:lst->str (mapcar 'itoa sel) " ")) ("")))

;;  Today, the date of a new revision:
(defun Dyl:RevToday () (menucmd "M=$(edtime,$(getvar,date),YYYY-MO-DD)"))

;;-------------------------=={ Title Blocks window }==------------------------;;

;;  The functions below run inside Dyl:RevBlocksDialog and use its local variables: tb:lst
;;  (the title blocks being edited: lists of strings, block rows first number date
;;  description issuedto issuedby current currentdate), tb:sel (the indexes selected, the
;;  first one shown).

;;  The title blocks of RevisionBlocks.csv as lists of strings:
(defun Dyl:RevBlocksStr ()
  (mapcar '(lambda (b) (append (list (car b) (itoa (cadr b)) (caddr b)) (cdddr b))) (Remote>>Dyl:RevBlocks))
)

;;  Summary of the title blocks, beside their open button: "2 title blocks":
(defun Dyl:RevBlocksSummary (/ n)
  (setq n (length (Remote>>Dyl:RevBlocks)))
  (cond ((= 0 n) "None") ((= 1 n) "1 title block") ((strcat (itoa n) " title blocks")))
)

;;  Fill the list and show the title block shown:
(defun Dyl:RevBlocksFill ()
  (Dyl:RevFillList "tbl"
                   (mapcar '(lambda (b) (strcat (car b) "\t" (cadr b) "\t" (if (= "Oldest" (caddr b)) "Oldest" "Newest"))) tb:lst)
  )
  (set_tile "tbl" (Dyl:RevSelStr tb:sel))
  (Dyl:RevBlocksShow)
)

;;  The fields: the title block shown (the first one selected), greyed out when none is
;;  selected; the block name for one only:
(defun Dyl:RevBlocksShow (/ b on)
  (setq b  (if tb:sel (nth (car tb:sel) tb:lst))
        on (if b 0 1)
  )
  (set_tile "tbx" (if (cdr tb:sel) (strcat "Parameters (" (itoa (length tb:sel)) " selected)") "Parameters"))
  (set_tile "nam" (if b (car b) ""))
  (set_tile "rws" (if b (cadr b) ""))
  (set_tile "fst" (if (and b (= "Oldest" (caddr b))) "1" "0"))
  (foreach i '(3 4 5 6 7 8 9) (set_tile (strcat "a" (itoa i)) (if b (nth i b) "")))
  (foreach k '("rws" "fst" "a3" "a4" "a5" "a6" "a7" "a8" "a9") (mode_tile k on))
  (mode_tile "nam" (if (and b (not (cdr tb:sel))) 0 1))
  (mode_tile "del" on)
)

;;  A field changed: its value given to every title block selected (i: its column):
(defun Dyl:RevBlocksPut (i val)
  (setq val (strcase (vl-string-trim " " val)))
  (cond
    ((and (= 0 i) (= "" val)) (set_tile "error" "A title block needs a block name (wildcards * and ? can be used)."))
    ((and (= 1 i) (or (not (distof val 2)) (> 0 (atoi val)) (< 50 (atoi val)) (/= (atoi val) (distof val 2))))
     (set_tile "error" "Rows: a whole number from 0 to 50.")
    )
    (T
     (set_tile "error" "")
     (if (= 2 i) (setq val (if (= "1" val) "Oldest" "Newest")))
     (foreach s tb:sel (setq tb:lst (Remote>>Dyl:ListSubst tb:lst s (Remote>>Dyl:ListSubst (nth s tb:lst) i val))))
     (Dyl:RevBlocksFill)
    )
  )
)

;;  A new title block, selected:
(defun Dyl:RevBlocksNew ()
  (setq tb:lst (append tb:lst (list (list "*TITLE*" "5" "Oldest" "" "" "" "" "" "" "")))
        tb:sel (list (1- (length tb:lst)))
  )
  (Dyl:RevBlocksFill)
)

(defun Dyl:RevBlocksDelete (/ i)
  (setq i -1
        tb:lst (vl-remove-if '(lambda (b) (member (setq i (1+ i)) tb:sel)) tb:lst)
        tb:sel nil
  )
  (Dyl:RevBlocksFill)
)

;;  Words of a tag: its letters, cut at every other character (REV#_DATE: REV DATE):
(defun Dyl:RevWords (tag / w lst)
  (setq w "")
  (foreach c (vl-string->list (strcat tag " "))
    (if (or (<= 65 c 90) (<= 97 c 122) (< 127 c))
      (setq w (strcat w (chr c)))
      (if (/= "" w) (setq lst (cons (strcase w) lst) w ""))
    )
  )
  (reverse lst)
)

;;  Tag of a row with its first number made # (REV12_DATE: (REV#_DATE . 12)), nil when it
;;  has no number:
(defun Dyl:RevRowTag (tag / i j n)
  (setq i 1 n (strlen tag))
  (while (and (<= i n) (not (<= 48 (ascii (substr tag i 1)) 57))) (setq i (1+ i)))
  (if (<= i n)
    (progn
      (setq j i)
      (while (and (<= j n) (<= 48 (ascii (substr tag j 1)) 57)) (setq j (1+ j)))
      (cons (strcat (substr tag 1 (1- i)) "#" (substr tag j)) (atoi (substr tag i (- j i))))
    )
  )
)

;;  Column of the map a tag looks like (3 Number ... 9 CurrentDate), from its words
;;  (English and French), nil when none. row: a tag of a revision row:
(defun Dyl:RevGuess (tag row / w has)
  (setq w (Dyl:RevWords tag))
  (defun has (lst) (vl-some '(lambda (x) (member x w)) lst))
  (cond
    ((and row (has '("DATE"))) 4)
    ((and row (has '("DESC" "DESCRIPTION" "OBJET" "OBJ" "REMARQUE" "NATURE"))) 5)
    ((and row (has '("TO" "POUR" "DEST" "DESTINATAIRE" "EMISPOUR" "ISSUEDTO"))) 6)
    ((and row (has '("BY" "PAR" "DESS" "DRAWN" "INIT" "INITIALES" "AUTEUR"))) 7)
    ((and row (has '("NO" "NUM" "NUMBER" "REV" "REVISION" "R"))) 3)
    (row nil)
    ((and (has '("REV" "REVISION")) (has '("DATE"))) 9)
    ((and (has '("REV" "REVISION")) (not (cdr (vl-remove-if '(lambda (x) (member x '("NO" "NUM" "CUR" "CURRENT" "ACTUELLE"))) w))))
     8
    )
  )
)

;;  A title block of the block reference ent guessed from its attributes: its rows (the
;;  tags with a number that come for several numbers), what each one is from its words:
(defun Dyl:RevBlocksGuess (ent / obj tags rows cnt res g n)
  (setq obj  (vlax-ename->vla-object ent)
        tags (mapcar 'car (Remote>>Dyl:RevAtts obj))
        res  (list (Remote>>Dyl:RevBlockName obj) "0" "Oldest" "" "" "" "" "" "" "")
        n    0
  )
  ;;  Patterns of the numbered tags with their numbers ((pattern . number) ...):
  (foreach tg tags (if (setq g (Dyl:RevRowTag tg)) (setq cnt (cons g cnt))))
  ;;  The rows: the patterns that come for several numbers, the highest of their numbers:
  (foreach p cnt
    (if (and (< 1 (length (vl-remove-if-not '(lambda (x) (= (car x) (car p))) cnt))) (not (member (car p) rows)))
      (setq rows (cons (car p) rows))
    )
  )
  (foreach p cnt (if (member (car p) rows) (setq n (max n (cdr p)))))
  (foreach p (reverse rows)
    (if (and (setq g (Dyl:RevGuess p T)) (= "" (nth g res))) (setq res (Remote>>Dyl:ListSubst res g p)))
  )
  (foreach tg tags
    (if (and (not (Dyl:RevRowTag tg)) (setq g (Dyl:RevGuess tg nil)) (= "" (nth g res)))
      (setq res (Remote>>Dyl:ListSubst res g tg))
    )
  )
  (if rows (Remote>>Dyl:ListSubst res 1 (itoa n)) res)
)

;;  Pick... : a title block picked in the drawing, its block and attributes guessed, given
;;  to the title block shown (or a new one). Runs while the window is closed:
(defun Dyl:RevBlocksPick (/ e b)
  (while
    (and (setq e (entsel "\nSelect a title block with attributes <cancel>: "))
         (not (and (= "INSERT" (cdr (assoc 0 (entget (car e))))) (= 1 (cdr (assoc 66 (entget (car e)))))))
    )
    (princ "\nThat is not a block with attributes.")
  )
  (if e
    (progn
      (setq b (Dyl:RevBlocksGuess (car e)))
      (if tb:sel
        (setq tb:lst (Remote>>Dyl:ListSubst tb:lst (car tb:sel) b))
        (setq tb:lst (append tb:lst (list b)))
      )
      (setq tb:sel (list (if tb:sel (car tb:sel) (1- (length tb:lst)))))
      (princ (strcat "\nTitle block " (car b) ": " (cadr b) " revision rows found. Check the attributes guessed."))
    )
  )
)

;;  The Revision Title Blocks window. OK saves RevisionBlocks.csv (the user copy). Returns T
;;  when saved:
(defun Dyl:RevBlocksDialog (/ tb:lst tb:sel dcl id sta)
  (setq tb:lst (Dyl:RevBlocksStr)
        tb:sel (if tb:lst '(0))
        dcl    (Dyl:RevDcl)
        id     (load_dialog dcl)
        sta    3
  )
  ;;  Code 3: Pick..., then this window again:
  (while (= 3 sta)
    (setq sta nil)
    (if (and (<= 0 id) (new_dialog "dyl_revtb" id))
      (progn
        (Dyl:RevFillList "thd" '("Block\tRows\tRow 1"))
        (Dyl:RevFillList "fst" '("Newest revision" "Oldest revision"))
        (Dyl:LineTile "ln1")
        (Dyl:LineTile "ln2")
        (Dyl:RevBlocksFill)
        (action_tile "tbl" "(setq tb:sel (Dyl:RevSelOf $value)) (Dyl:RevBlocksShow)")
        (action_tile "nam" "(Dyl:RevBlocksPut 0 $value)")
        (action_tile "rws" "(Dyl:RevBlocksPut 1 $value)")
        (action_tile "fst" "(Dyl:RevBlocksPut 2 $value)")
        (foreach i '(3 4 5 6 7 8 9)
          (action_tile (strcat "a" (itoa i)) (strcat "(Dyl:RevBlocksPut " (itoa i) " $value)"))
        )
        (action_tile "new" "(Dyl:RevBlocksNew)")
        (action_tile "del" "(Dyl:RevBlocksDelete)")
        (action_tile "pck" "(done_dialog 3)")
        (action_tile "accept" "(done_dialog 1)")
        (Dyl:DocsTile "Output\\Dyl-Revisions.htm")
        (setq sta (start_dialog))
      )
      (alert "\nError: the Revision Title Blocks window could not be loaded")
    )
    (if (= 3 sta) (Dyl:RevBlocksPick))
  )
  (if (<= 0 id) (unload_dialog id))
  (vl-file-delete dcl)
  (cond
    ((/= 1 sta) nil)
    ((Remote>>Dyl:RevCsvWrite (Dyl:UserFileW (Remote>>Dyl:RevBlocksFile)) *rev:blkhdr* tb:lst)
     (princ "\nRevision title blocks saved.")
     T
    )
    ((alert (strcat "\nError: the title blocks could not be saved to\n" (Dyl:UserFileW (Remote>>Dyl:RevBlocksFile)) "\n(is it open in Excel?)")))
  )
)

;;-------------------------=={ Revisions window }==------------------------;;

;;  The functions below run inside c:Dyl-Revisions and use its local variables: rv:prj (the
;;  project), rv:revs (the revisions being edited, in their sequence), rv:sets (the settings of
;;  the project being edited), rv:shts (the sheets being edited, ((file layout hand clouds)
;;  ...)), rv:revs0, rv:sets0, rv:shts0 (as they were read), rv:sel (the indexes of the
;;  revisions selected, the first one shown), rv:ssel (the indexes of the sheets selected),
;;  rv:stamp (the times Revisions.csv and RevisionSettings.csv were written when they were
;;  read, Dyl:RevStamps), rv:tbchg (T once the title blocks were saved from this window).

;;  The revisions selected:
(defun Dyl:RevSelRevs () (mapcar '(lambda (i) (nth i rv:revs)) rv:sel))

;;  Issued:
(defun Dyl:RevIssued-p (r) (= "1" (nth 6 r)))

;;  Numbers of every revision, per project:
(defun Dyl:RevAllNumbers () (Remote>>Dyl:RevNumbers rv:revs (atoi (cdr (assoc "Start" rv:sets)))))

;;  T when every issued revision keeps its number with the revisions revs in place of
;;  rv:revs (a revision deleted, or numbered otherwise, before it). Compared per project: a
;;  number per sheet changes only when the number per project does:
(defun Dyl:RevKeepsIssued-p (revs / start old new)
  (setq start (atoi (cdr (assoc "Start" rv:sets)))
        old   (Remote>>Dyl:RevNumbers rv:revs start)
        new   (Remote>>Dyl:RevNumbers revs start)
  )
  (vl-every '(lambda (r) (or (not (Dyl:RevIssued-p r)) (equal (assoc (car r) old) (assoc (car r) new)))) rv:revs)
)

;;  The revisions without the ones selected:
(defun Dyl:RevWithoutSel (/ ids)
  (setq ids (mapcar 'car (Dyl:RevSelRevs)))
  (vl-remove-if '(lambda (r) (member (car r) ids)) rv:revs)
)

;;  Line of the revisions list: sequence, number (per project, or how it counts per sheet),
;;  date, description, issued:
(defun Dyl:RevLine (r i nums)
  (strcat (itoa (1+ i))
          "\t"
          (cond
            ((= "None" (nth 1 r)) "-")
            ((/= "Sheet" (cdr (assoc "Numbering" rv:sets))) (cdr (assoc (car r) nums)))
            ((= "Numeric" (nth 1 r)) (strcat (cdr (assoc "Start" rv:sets)) "..."))
            ("A...")
          )
          "\t"
          (nth 2 r)
          "\t"
          (nth 3 r)
          "\t"
          (if (Dyl:RevIssued-p r) "Issued" "")
  )
)

;;  Name of a sheet in the list: its file in the sheet folder, without .dwg:
(defun Dyl:RevSheetName (s / full sub nam)
  (setq full (Remote>>Dyl:RevFull rv:prj (car s))
        sub  (strcat (nth 4 rv:prj) "\\")
        nam  (if (= (strcase sub) (strcase (substr full 1 (strlen sub)))) (substr full (1+ (strlen sub))) (car s))
  )
  (if (wcmatch (strcase nam) "*.DWG") (substr nam 1 (- (strlen nam) 4)) nam)
)

;;  Line of the sheets list: sheet, layout, whether it has the revision shown (Yes: given to
;;  it, Cloud: by a cloud of the layout), and the numbers of its revisions:
(defun Dyl:RevSheetLine (s shown all / on nums)
  (setq on   (Remote>>Dyl:RevOn rv:revs (append (caddr s) (cadddr s)))
        nums (Remote>>Dyl:RevSheetNumbers rv:revs rv:sets (mapcar 'car on) all)
  )
  (strcat (Dyl:RevSheetName s)
          "\t"
          (cadr s)
          "\t"
          (cond
            ((not shown) "")
            ((and (member shown (caddr s)) (member shown (cadddr s))) "Yes, cloud")
            ((member shown (caddr s)) "Yes")
            ((member shown (cadddr s)) "Cloud")
            ("")
          )
          "\t"
          (cond
            ((Remote>>LM:lst->str
               (mapcar '(lambda (r / n) (if (= "" (setq n (cdr (assoc (car r) nums)))) "-" n)) on)
               ", "
             )
            )
            ("")
          )
  )
)

;;  Fill the revisions list (the ones of rv:sel selected) and the sheets list:
(defun Dyl:RevFill (/ nums i)
  (setq nums (Dyl:RevAllNumbers) i -1)
  (Dyl:RevFillList "rev" (mapcar '(lambda (r) (Dyl:RevLine r (setq i (1+ i)) nums)) rv:revs))
  (set_tile "rev" (Dyl:RevSelStr rv:sel))
  (Dyl:RevSheetsFill)
  (Dyl:RevShow)
)

;;  Fill the sheets list (the ones of rv:ssel selected), its column of the revision shown:
(defun Dyl:RevSheetsFill (/ shown all)
  (setq shown (if rv:sel (car (nth (car rv:sel) rv:revs)))
        all   (Dyl:RevAllNumbers)
  )
  (Dyl:RevFillList "shd" (list (strcat "Sheet\tLayout\t" (if rv:sel (strcat "Rev. " (itoa (1+ (car rv:sel)))) "") "\tRevisions")))
  (Dyl:RevFillList "sht" (mapcar '(lambda (s) (Dyl:RevSheetLine s shown all)) rv:shts))
  (set_tile "sht" (Dyl:RevSelStr rv:ssel))
  (set_tile "sbx"
            (strcat "Sheets ("
                    (itoa (length rv:shts))
                    (if shown
                      (strcat ", "
                              (itoa (length (vl-remove-if-not '(lambda (s) (or (member shown (caddr s)) (member shown (cadddr s)))) rv:shts)))
                              " with revision "
                              (itoa (1+ (car rv:sel)))
                      )
                      ""
                    )
                    ")"
            )
  )
)

;;  The fields: the revision shown (the first one selected), greyed out when none is
;;  selected or one of the selected is issued (Issued itself stays, to take it back); the
;;  buttons that need a selection:
(defun Dyl:RevShow (/ r sel lock one)
  (setq sel  (Dyl:RevSelRevs)
        r    (car sel)
        lock (or (not r) (vl-some 'Dyl:RevIssued-p sel))
        one  (and r (not (cdr sel)) (not (Dyl:RevIssued-p r)))
  )
  (set_tile "pbx" (if (cdr sel) (strcat "Parameters (" (itoa (length sel)) " selected)") "Parameters"))
  (set_tile "num" (itoa (if r (cond ((vl-position (nth 1 r) *rev:numberings*)) (0)) 0)))
  (set_tile "dat" (if r (nth 2 r) ""))
  (set_tile "dsc" (if r (nth 3 r) ""))
  (set_tile "ito" (if r (nth 4 r) ""))
  (set_tile "iby" (if r (nth 5 r) ""))
  (set_tile "iss" (if (and r (Dyl:RevIssued-p r)) "1" "0"))
  (foreach k '("num" "dat" "dsc" "ito" "iby") (mode_tile k (if lock 1 0)))
  ;;  Never deleted when an issued revision after it would be numbered otherwise:
  (mode_tile "del" (if (or lock (not (Dyl:RevKeepsIssued-p (Dyl:RevWithoutSel)))) 1 0))
  (mode_tile "iss" (if r 0 1))
  ;;  Moved one at a time, never past an issued revision (its number would change):
  (mode_tile "up" (if (and one (< 0 (car rv:sel)) (not (Dyl:RevIssued-p (nth (1- (car rv:sel)) rv:revs)))) 0 1))
  (mode_tile "dn"
             (if (and one
                      (< (car rv:sel) (1- (length rv:revs)))
                      (not (Dyl:RevIssued-p (nth (1+ (car rv:sel)) rv:revs)))
                 )
               0
               1
             )
  )
  (mode_tile "add" (if (and (not lock) rv:ssel) 0 1))
  (mode_tile "rem" (if (and (not lock) rv:ssel) 0 1))
)

;;  A field changed: its value given to every revision selected (i: its column). A
;;  numbering that would number an issued revision after them otherwise is refused:
(defun Dyl:RevPutField (i val / revs)
  (if (= 1 i) (setq val (nth (atoi val) *rev:numberings*)))
  (if (= 6 i) (setq val (if (= "1" val) "1" "")))
  (if (/= 1 i) (setq val (vl-string-trim " " val)))
  (setq revs rv:revs)
  (foreach s rv:sel (setq revs (Remote>>Dyl:ListSubst revs s (Remote>>Dyl:ListSubst (nth s revs) i val))))
  (if (and (= 1 i) (not (Dyl:RevKeepsIssued-p revs)))
    (progn
      (Dyl:RevShow)
      (set_tile "error" "An issued revision after it would be numbered otherwise: its numbering cannot change.")
    )
    (progn
      (setq rv:revs revs)
      (set_tile "error" "")
      (Dyl:RevFill)
    )
  )
)

;;  A project setting changed:
(defun Dyl:RevPutSetting (key val)
  (setq rv:sets (subst (cons key val) (assoc key rv:sets) rv:sets))
  (Dyl:RevFill)
)

;;  New: a revision after the last one, of the numbering of the last one, dated today. Its
;;  id is never one a revision had (LastId of the project): the clouds of a revision
;;  deleted never go to another one:
(defun Dyl:RevNew (/ id)
  (setq id (atoi (cdr (assoc "LastId" rv:sets))))
  (foreach r (append rv:revs0 rv:revs) (setq id (max id (atoi (car r)))))
  (setq rv:sets (subst (cons "LastId" (itoa (1+ id))) (assoc "LastId" rv:sets) rv:sets)
        rv:revs (append rv:revs
                        (list (list (itoa (1+ id)) (if rv:revs (nth 1 (last rv:revs)) "Numeric") (Dyl:RevToday) "" "" "" ""))
                )
        rv:sel  (list (1- (length rv:revs)))
  )
  (Dyl:RevFill)
  (mode_tile "dsc" 2)
)

;;  Delete: the revisions selected, from the sheets too, after a confirmation. Their clouds
;;  stay in the drawings, without a revision:
(defun Dyl:RevDelete (/ ids n)
  (setq ids (mapcar 'car (Dyl:RevSelRevs))
        n   (length (vl-remove-if-not '(lambda (s) (vl-some '(lambda (i) (member i (cadddr s))) ids)) rv:shts))
  )
  (if
    (Dyl:Ask (list (strcat "Delete " (itoa (length ids)) " revision(s) from the project?")
                   "They are removed from every sheet when the window is saved."
                   (if (< 0 n) (strcat (itoa n) " sheet(s) have clouds of them: erase those clouds.") "")
             )
             "Delete"
             "Cancel"
    )
    (setq rv:revs (vl-remove-if '(lambda (r) (member (car r) ids)) rv:revs)
          rv:shts (mapcar '(lambda (s) (Remote>>Dyl:ListSubst s 2 (vl-remove-if '(lambda (i) (member i ids)) (caddr s)))) rv:shts)
          rv:sel  nil
    )
  )
  (Dyl:RevFill)
)

;;  Move Up (d -1) / Move Down (d 1) the revision selected:
(defun Dyl:RevMove (d / i r)
  (setq i (car rv:sel)
        r (nth i rv:revs)
  )
  (setq rv:revs (Remote>>Dyl:ListInsert (Remote>>Dyl:ListRemove rv:revs i) (+ i d) r)
        rv:sel  (list (+ i d))
  )
  (Dyl:RevFill)
)

;;  Add Revision (add T) / Remove Revision (add nil): the revisions selected given to the
;;  sheets selected, or taken from them (the ids of a sheet kept in their sequence):
(defun Dyl:RevSheetsPut (add / ids i keep)
  (setq ids (mapcar 'car (Dyl:RevSelRevs))
        i   -1
  )
  (setq rv:shts
         (mapcar
           '(lambda (s / hand)
              (if (member (setq i (1+ i)) rv:ssel)
                (progn
                  (setq hand (if add
                               (mapcar 'car (Remote>>Dyl:RevOn rv:revs (append (caddr s) ids)))
                               (vl-remove-if '(lambda (x) (member x ids)) (caddr s))
                             )
                  )
                  (if (and (not add) (vl-some '(lambda (x) (member x (cadddr s))) ids)) (setq keep T))
                  (Remote>>Dyl:ListSubst s 2 hand)
                )
                s
              )
            )
           rv:shts
         )
  )
  (Dyl:RevFill)
  (if keep (set_tile "error" "Some sheets keep the revision through their clouds: erase the clouds to remove it."))
)

;;  The sheets of the project: Sheets.csv, its sheet drawings it does not have yet read
;;  first (without changing them), the drawings that no longer exist left out:
(defun Dyl:RevSheetsOf (prj / files shts rels new)
  (setq files (Remote>>Dyl:RevSheetFiles prj)
        shts  (Remote>>Dyl:RevSheets prj)
        rels  (mapcar '(lambda (s) (strcase (car s))) shts)
        new   (vl-remove-if '(lambda (f) (member (strcase (Remote>>Dyl:RevRel prj f)) rels)) files)
  )
  (if new
    (progn
      (princ (strcat "\nReading " (itoa (length new)) " new sheet drawing(s)..."))
      (Remote>>Dyl:RevReadFiles prj new)
      (setq shts (Remote>>Dyl:RevSheets prj))
    )
  )
  (setq files (mapcar 'strcase files))
  (vl-remove-if-not '(lambda (s) (member (strcase (Remote>>Dyl:RevFull prj (car s))) files)) shts)
)

;;  The times the revisions and the settings of the project were written (nil for a file
;;  not made yet), to tell when another user changed them:
(defun Dyl:RevStamps (prj)
  (mapcar '(lambda (f) (Remote>>Dyl:RevStamp (Remote>>Dyl:RevPath prj f))) '("Revisions.csv" "RevisionSettings.csv"))
)

;;  Check the revisions before saving: a sequence of dates and descriptions. Returns an
;;  error message, nil when they can be saved. The stamps are lists: compared with equal
;;  (= and /= tell two lists apart even when they hold the same values):
(defun Dyl:RevCheck ()
  (cond
    ((not (equal rv:stamp (Dyl:RevStamps rv:prj)))
     "Another user changed the revisions or the settings of the project since this window opened: Cancel, then open it again."
    )
    ((vl-some '(lambda (r) (= "" (nth 3 r))) rv:revs) "Every revision needs a description.")
  )
)

;;  Save the revisions, the settings and the revisions given to the sheets (only the sheets
;;  changed, in Sheets.csv read again). Returns T when saved:
(defun Dyl:RevSave (/ chg old new ok)
  (setq ok T)
  (if (not (equal rv:revs rv:revs0)) (setq ok (and ok (Remote>>Dyl:RevWrite rv:prj rv:revs))))
  (if (not (equal rv:sets rv:sets0)) (setq ok (and ok (Remote>>Dyl:RevSettingsWrite rv:prj rv:sets))))
  (foreach s rv:shts
    (if (not (equal (caddr s) (caddr (Remote>>Dyl:RevSheetRow rv:shts0 (car s) (cadr s))))) (setq chg (cons s chg)))
  )
  (if chg
    (progn
      (setq old (Remote>>Dyl:RevSheets rv:prj)
            new (mapcar '(lambda (o / c) (if (setq c (Remote>>Dyl:RevSheetRow chg (car o) (cadr o))) (Remote>>Dyl:ListSubst o 2 (caddr c)) o)) old)
      )
      (foreach c chg (if (not (Remote>>Dyl:RevSheetRow old (car c) (cadr c))) (setq new (cons c new))))
      (setq ok (and ok (Remote>>Dyl:RevSheetsWrite rv:prj new)))
    )
  )
  ok
)

;;  What the title block of the sheet s shows with the revisions revs and the settings
;;  sets: ((number date description issuedto issuedby) ...)
(defun Dyl:RevRender (revs sets s / on nums)
  (setq on   (Remote>>Dyl:RevOn revs (append (caddr s) (cadddr s)))
        nums (Remote>>Dyl:RevSheetNumbers revs sets (mapcar 'car on) nil)
  )
  (mapcar '(lambda (r) (list (cdr (assoc (car r) nums)) (nth 2 r) (nth 3 r) (nth 4 r) (nth 5 r))) on)
)

;;  The sheet drawings to update after a save (full paths): the sheets given or taken a
;;  revision, and the ones whose title block shows something else now (a revision changed,
;;  numbered otherwise...). Every sheet that has revisions when the title blocks were
;;  changed (rv:tbchg):
(defun Dyl:RevToUpdate (/ old lst f)
  (foreach s rv:shts
    (setq old (cond ((Remote>>Dyl:RevSheetRow rv:shts0 (car s) (cadr s))) (s)))
    (if
      (or (not (equal (caddr s) (caddr old)))
          (and rv:tbchg (or (caddr s) (cadddr s)))
          (not (equal (Dyl:RevRender rv:revs rv:sets s) (Dyl:RevRender rv:revs0 rv:sets0 old)))
      )
      (if (not (member (setq f (strcase (Remote>>Dyl:RevFull rv:prj (car s)))) lst)) (setq lst (cons f lst)))
    )
  )
  (reverse lst)
)

;;  Tell what an update did: the count of sheets updated, the ones that were not:
(defun Dyl:RevReport (res / up same)
  (setq up   (length (vl-remove-if-not '(lambda (r) (wcmatch (cadr r) "Updated*")) res))
        same (length (vl-remove-if-not '(lambda (r) (= "Up to date" (cadr r))) res))
  )
  (princ (strcat "\nRevisions: " (itoa up) " sheet drawing(s) updated, " (itoa same) " up to date."))
  (foreach r res
    (if (/= "Up to date" (cadr r))
      (princ (strcat "\n  " (vl-filename-base (car r)) ": " (cadr r)))
    )
  )
  (if (vl-some '(lambda (r) (wcmatch (cadr r) "Open by *")) res)
    (princ "\nThe drawings open by other users get their revisions when they are updated again (Revisions sync of Dyl-Settings: when they open).")
  )
)

;;  Show the Revisions window once. Returns its done_dialog code: 0 Cancel, 1 OK, 2 Update All
;;  Sheets, 4 the title blocks window (then this one again):
(defun Dyl:RevDlgRun (/ sta)
  (cond
    ((not (new_dialog "dyl_rev" rv:dcl)) (princ "\n--> Unable to show the Revisions window.") 0)
    (T
     (set_tile "prj"
               (strcat "Project: "
                       (nth 2 rv:prj)
                       (if (/= "" (nth 3 rv:prj)) (strcat " (" (nth 3 rv:prj) ")") "")
                       "   " (car rv:prj)
               )
     )
     (Dyl:RevFillList "rhd" '("Seq.\tNumber\tDate\tDescription\tIssued"))
     (Dyl:RevFillList "num" *rev:numberings*)
     (Dyl:RevFillList "pnm" '("Per project" "Per sheet"))
     (Dyl:RevFillList "pst" '("1" "0"))
     (set_tile "pnm" (if (= "Sheet" (cdr (assoc "Numbering" rv:sets))) "1" "0"))
     (set_tile "pst" (if (= "0" (cdr (assoc "Start" rv:sets))) "1" "0"))
     (set_tile "tbs" (Dyl:RevBlocksSummary))
     (Dyl:MoreTile "tbm" T)
     (Dyl:RevFill)
     (action_tile "rev" "(setq rv:sel (Dyl:RevSelOf $value)) (Dyl:RevSheetsFill) (Dyl:RevShow)")
     (action_tile "sht" "(setq rv:ssel (Dyl:RevSelOf $value)) (Dyl:RevShow)")
     (action_tile "num" "(Dyl:RevPutField 1 $value)")
     (action_tile "dat" "(Dyl:RevPutField 2 $value)")
     (action_tile "dsc" "(Dyl:RevPutField 3 $value)")
     (action_tile "ito" "(Dyl:RevPutField 4 $value)")
     (action_tile "iby" "(Dyl:RevPutField 5 $value)")
     (action_tile "iss" "(Dyl:RevPutField 6 $value)")
     (action_tile "pnm" "(Dyl:RevPutSetting \"Numbering\" (if (= \"1\" $value) \"Sheet\" \"Project\"))")
     (action_tile "pst" "(Dyl:RevPutSetting \"Start\" (if (= \"1\" $value) \"0\" \"1\"))")
     (action_tile "new" "(Dyl:RevNew)")
     (action_tile "del" "(Dyl:RevDelete)")
     (action_tile "up" "(Dyl:RevMove -1)")
     (action_tile "dn" "(Dyl:RevMove 1)")
     (action_tile "add" "(Dyl:RevSheetsPut T)")
     (action_tile "rem" "(Dyl:RevSheetsPut nil)")
     (action_tile "tbm" "(done_dialog 4)")
     (action_tile "all" "(if (setq rv:msg (Dyl:RevCheck)) (set_tile \"error\" rv:msg) (done_dialog 2))")
     (action_tile "accept" "(if (setq rv:msg (Dyl:RevCheck)) (set_tile \"error\" rv:msg) (done_dialog 1))")
     (action_tile "cancel" "(done_dialog 0)")
     (Dyl:DocsTile "Output\\Dyl-Revisions.htm")
     (start_dialog)
    )
  )
)

;;-------------------------=={ Revision clouds }==------------------------;;

;;  The tag block (*rev:tag*) of the drawing, made when missing: a triangle 8 mm wide around
;;  its insertion point (5/16" in an imperial drawing), its attribute in its middle:
(defun Dyl:RevTagDef (doc / blks blk s h pl att)
  (setq blks (vla-get-Blocks doc))
  (if (vl-catch-all-error-p (vl-catch-all-apply 'vla-Item (list blks *rev:tag*)))
    (progn
      (setq s   (if (= 1 (getvar "MEASUREMENT")) 1.0 (/ 1.0 25.4))
            h   (* 8.0 s (sqrt 3.0) 0.5)
            blk (vla-Add blks (vlax-3d-point '(0. 0. 0.)) *rev:tag*)
            pl  (vlax-invoke blk 'AddLightWeightPolyline (list (* -4. s) (/ h -3.) (* 4. s) (/ h -3.) 0. (/ h 1.5)))
      )
      (vla-put-Closed pl :vlax-true)
      (vla-put-Layer pl "0")
      (setq att (vla-AddAttribute blk (* 2.5 s) acAttributeModeNormal "Revision" (vlax-3d-point '(0. 0. 0.)) *rev:tagatt* ""))
      (vla-put-Layer att "0")
      (vla-put-Alignment att acAlignmentMiddleCenter)
      (vla-put-TextAlignmentPoint att (vlax-3d-point '(0. 0. 0.)))
    )
  )
)

;;  Give the XData of the revision id to an object (kind "Cloud" or "Tag"):
(defun Dyl:RevMark (ent id kind)
  (regapp *rev:app*)
  (entmod (append (entget ent) (list (list -3 (list *rev:app* (cons 1000 id) (cons 1000 kind))))))
)

;;  The revision of the clouds: the newest one not issued, or the one whose sequence is typed.
;;  Returns the revision, nil when the project has none open:
(defun Dyl:RevCloudOf (revs / open def i n)
  (setq i 0)
  (foreach r revs
    (setq i (1+ i))
    (if (not (Dyl:RevIssued-p r)) (setq open (cons (cons i r) open)))
  )
  (if open
    (progn
      (setq open (reverse open)
            def  (car (last open))
      )
      (foreach x open (princ (strcat "\n  " (itoa (car x)) "  " (nth 2 (cdr x)) "  " (nth 3 (cdr x)))))
      (while
        (and (setq n (progn (initget 6) (getint (strcat "\nRevision of the clouds (sequence) <" (itoa def) ">: "))))
             (not (assoc n open))
        )
        (princ "\nThat revision is issued or does not exist.")
      )
      (cdr (assoc (cond (n) (def)) open))
    )
  )
)

;;-------------------------=={ Commands }==------------------------;;

;; Revisions
;; Opens the revisions of the project, as in Revit: their numbering, dates and descriptions, and the sheets that have them.

(defun c:Dyl-Revisions (/ rv:prj rv:revs rv:revs0 rv:sets rv:sets0 rv:shts rv:shts0 rv:sel rv:ssel rv:stamp rv:tbchg rv:dcl rv:msg dcl:pth sta files)
  (cond
    ((not (setq rv:prj (Remote>>Dyl:RevProjectOf)))
     (princ "\nThis drawing is not in a project: open a drawing of a Project Navigator project (its folder or a folder under it has the .apj file).")
    )
    ((> 0 (setq rv:dcl (load_dialog (setq dcl:pth (Dyl:RevDcl))))) (princ "\n--> Unable to load the Revisions window."))
    (T
     (setq rv:revs  (Remote>>Dyl:RevRead rv:prj)
           rv:revs0 rv:revs
           rv:sets  (Remote>>Dyl:RevSettings rv:prj)
           rv:sets0 rv:sets
           rv:shts  (Dyl:RevSheetsOf rv:prj)
           rv:shts0 rv:shts
           rv:stamp (Dyl:RevStamps rv:prj)
           rv:sel   (if rv:revs (list (1- (length rv:revs))))
           sta      4
     )
     ;;  Code 4: the title blocks window, then this one again. Any error closes the window
     ;;  cleanly and is reported on the command line:
     (while (= 4 sta)
       (setq sta (vl-catch-all-apply 'Dyl:RevDlgRun nil))
       (if (vl-catch-all-error-p sta)
         (progn
           (term_dialog)
           (princ (strcat "\nRevisions window error: " (vl-catch-all-error-message sta)))
           (setq sta 0)
         )
       )
       (if (and (= 4 sta) (Dyl:RevBlocksDialog)) (setq rv:tbchg T))
     )
     (cond
       ((= 0 sta) (princ "\nRevisions unchanged."))
       ((not (Dyl:RevSave)) (alert "Error: the revisions could not be saved in the DynALisp folder of the project (is a file open in Excel?)."))
       ((setq files (if (= 2 sta) (Remote>>Dyl:RevSheetFiles rv:prj) (Dyl:RevToUpdate)))
        (princ "\nRevisions saved.")
        (Dyl:RevReport (Remote>>Dyl:RevUpdateFiles rv:prj files))
       )
       ((princ "\nRevisions saved: no sheet to update."))
     )
    )
  )
  (if (and rv:dcl (<= 0 rv:dcl)) (unload_dialog rv:dcl))
  (if dcl:pth (vl-file-delete dcl:pth))
  (princ)
)

;; Revision Cloud
;; Draws a revision cloud on the layout for a revision of the project, then its tag, and updates the title block.

(defun c:Pst-RevisionCloud (/ *error* prj revs rev doc lay old e0 e lst pt tag s r)
  ;;  Escape during REVCLOUD: the current layer back:
  (defun *error* (msg)
    (if old (setvar "CLAYER" old))
    (if (not (wcmatch (strcase msg t) "*break,*cancel*,*exit*")) (princ (strcat "\nError: " msg)))
    (princ)
  )
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (cond
    ((not (setq prj (Remote>>Dyl:RevProjectOf)))
     (princ "\nThis drawing is not in a project: revision clouds are drawn on the sheets of a Project Navigator project.")
    )
    ((or (= 1 (getvar "TILEMODE")) (/= 1 (getvar "CVPORT")))
     (princ "\nA revision cloud counts on the layout it is drawn on: go to the paper space of a layout first.")
    )
    ((not (setq rev (Dyl:RevCloudOf (setq revs (Remote>>Dyl:RevRead prj)))))
     (princ "\nNo revision open (not issued) in this project: add one in Dyl-Revisions first.")
    )
    (T
     (setq old (getvar "CLAYER")
           lay (if Remote>>Dyl:LayerKeyLayer (Remote>>Dyl:LayerKeyLayer "ANNREV"))
           e0  (entlast)
     )
     (if lay (setvar "CLAYER" lay))
     (princ (strcat "\nRevision clouds of " (nth 2 rev) " " (nth 3 rev) ":"))
     (command "_.REVCLOUD")
     (while (< 0 (getvar "CMDACTIVE")) (command pause))
     ;;  The polylines REVCLOUD made:
     (setq e (if e0 (entnext e0) (entnext)))
     (while e
       (if (= "LWPOLYLINE" (cdr (assoc 0 (entget e)))) (setq lst (cons e lst)))
       (setq e (entnext e))
     )
     (foreach x lst (Dyl:RevMark x (car rev) "Cloud"))
     (if (and lst (setq pt (getpoint "\nLocation of the revision tag <none>: ")))
       (progn
         (Dyl:RevTagDef doc)
         (setq tag (vla-InsertBlock (vla-get-Block (vla-get-ActiveLayout doc)) (vlax-3d-point (trans pt 1 0)) *rev:tag* 1. 1. 1. 0.))
         (if lay (vla-put-Layer tag lay))
         (Dyl:RevMark (vlax-vla-object->ename tag) (car rev) "Tag")
       )
     )
     (setvar "CLAYER" old)
     (cond
       ((not lst) (princ "\nNo revision cloud drawn."))
       ((progn
          (setq r (vl-catch-all-apply 'Remote>>Dyl:RevUpdateThis nil))
          (vl-catch-all-error-p r)
        )
        (princ (strcat "\n--> Revision cloud drawn, the title block not updated: " (vl-catch-all-error-message r)))
       )
       ((and r (wcmatch r "-->*")) (princ (strcat "\nRevision cloud drawn, the title block not updated: " r)))
       ((princ (strcat "\n" (itoa (length lst)) " revision cloud(s) drawn" (if r ", title block updated." "."))))
     )
    )
  )
  (princ)
)

;; Update Revisions
;; Updates the title blocks and revision tags of this sheet with the revisions of its project.

(defun c:Pst-RevisionsUpdate (/ prj r)
  (cond
    ((not (setq prj (Remote>>Dyl:RevProjectOf))) (princ "\nThis drawing is not in a project."))
    ((not (Remote>>Dyl:RevSheetThis prj))
     (princ (strcat "\nThis drawing is not a sheet of the project: the sheets are in " (nth 4 prj) "."))
    )
    ((vl-catch-all-error-p (setq r (vl-catch-all-apply 'Remote>>Dyl:RevUpdateThis nil)))
     (princ (strcat "\n--> Revisions not updated: " (vl-catch-all-error-message r)))
    )
    ((and r (wcmatch r "-->*")) (princ (strcat "\nRevisions not updated: " r)))
    (r (princ "\nRevisions: the title blocks and tags of this sheet are updated."))
    ((princ "\nRevisions: this sheet is up to date."))
  )
  (princ)
)

;; Revision Title Blocks
;; Opens the title blocks that show the revisions, and the attributes of their revision rows.

(defun c:Pst-RevisionTitleBlocks ()
  (Dyl:RevBlocksDialog)
  (princ)
)

(princ)
