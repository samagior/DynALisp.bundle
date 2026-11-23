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
;;  Modules\Dynalisp\Remote\Dyl-Revisions.lsp (read it first). This file has the windows (Res\Dyl-Revisions.xaml,
;;  Res\Dyl-RevisionTitleBlocks.xaml):
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

;;-------------------------=={ Windows }==------------------------;;

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

;;  A title block as the window gave it back, made right: the block and the tags in capitals,
;;  the rows a whole number, Row 1 Oldest or Newest:
(defun Dyl:RevBlocksFix (b / i)
  (setq i -1)
  (mapcar '(lambda (v)
             (setq i (1+ i)
                   v (vl-string-trim " " (cond (v) ("")))
             )
             (cond
               ((= 1 i) (itoa (atoi v)))
               ((= 2 i) (if (= "Oldest" v) "Oldest" "Newest"))
               ((strcase v))
             )
           )
          (list (nth 0 b) (nth 1 b) (nth 2 b) (nth 3 b) (nth 4 b) (nth 5 b) (nth 6 b) (nth 7 b) (nth 8 b) (nth 9 b))
  )
)

;;  Why the title blocks cannot be saved, nil when they can (the window checks them first):
(defun Dyl:RevBlocksCheck (/ v)
  (cond
    ((vl-some '(lambda (b) (= "" (car b))) tb:lst) "A title block needs a block name (wildcards * and ? can be used).")
    ((vl-some '(lambda (b) (not (and (setq v (distof (cadr b) 2)) (<= 0 v 50) (= v (fix v))))) tb:lst)
     "Rows: a whole number from 0 to 50."
    )
  )
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

;;  The Revision Title Blocks window (Res\Dyl-RevisionTitleBlocks.xaml): the title blocks
;;  are edited in the window (a list of rows); Pick... (3) closes it, the title block picked is
;;  guessed and the window shown again. OK saves RevisionBlocks.csv (the user copy). Returns T
;;  when saved:
(defun Dyl:RevBlocksDialog (/ tb:lst tb:sel res sta err)
  (setq tb:lst (Dyl:RevBlocksStr)
        tb:sel (if tb:lst '(0))
        sta    3
  )
  ;;  3: Pick..., then this window again; 5: shown again with why it cannot be saved:
  (while (member sta '(3 5))
    (setq res (Dyl:WinShow "Dyl-RevisionTitleBlocks.xaml"
                           (list (cons "tbl/rows" tb:lst)
                                 (cons "tbl.sel" (Dyl:RevSelStr tb:sel))
                                 (list "tbl/new" (list "*TITLE*" "5" "Oldest" "" "" "" "" "" "" ""))
                                 (list "fst/list" "Newest revision" "Oldest revision")
                                 (list "fst/vals" "Newest" "Oldest")
                                 (cons "error" (cond (err) ("")))
                           )
              )
          sta (if res (car res))
          err nil
    )
    (if res
      (setq tb:lst (mapcar 'Dyl:RevBlocksFix (cdr (assoc "tbl/rows" (cdr res))))
            tb:sel (Dyl:RevSelOf (Dyl:WinGet res "tbl.sel"))
      )
    )
    (cond
      ((= 3 sta) (Dyl:RevBlocksPick))
      ((and (= 1 sta) (setq err (Dyl:RevBlocksCheck))) (setq sta 5))
    )
  )
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

;;  The number shown of a revision: per project, or how it counts per sheet:
(defun Dyl:RevNumberOf (r nums)
  (cond
    ((= "None" (nth 1 r)) "-")
    ((/= "Sheet" (cdr (assoc "Numbering" rv:sets))) (cdr (assoc (car r) nums)))
    ((= "Numeric" (nth 1 r)) (strcat (cdr (assoc "Start" rv:sets)) "..."))
    ("A...")
  )
)

;;  Row of the revisions list: its columns (id numbering date description issuedto
;;  issuedby issued), then its sequence and its number, shown:
(defun Dyl:RevRow (r i nums)
  (append r (list (itoa (1+ i)) (Dyl:RevNumberOf r nums)))
)

;;  How many sheets, and with the revision id:
(defun Dyl:RevSheetsCount (id i)
  (strcat (itoa (length rv:shts))
          " sheet(s)"
          (if id
            (strcat ", "
                    (itoa (length (vl-remove-if-not '(lambda (s) (or (member id (caddr s)) (member id (cadddr s)))) rv:shts)))
                    " with revision "
                    (itoa (1+ i))
            )
            ""
          )
  )
)

;;  The values of the window (Res\Dyl-Revisions.xaml): the revisions (rows edited in the
;;  window), the project, and the sheets for each revision picked (sht/by, shh/by, scn/by:
;;  the window shows those of the first revision selected):
(defun Dyl:RevWinVals (/ nums i shown)
  (setq nums  (Dyl:RevAllNumbers)
        i     -1
        rv:sel  (vl-remove-if-not '(lambda (n) (nth n rv:revs)) rv:sel)
        rv:ssel (vl-remove-if-not '(lambda (n) (nth n rv:shts)) rv:ssel)
        shown (if rv:sel (car (nth (car rv:sel) rv:revs)))
  )
  (append
    (list (cons "prj"
                (strcat "Project: "
                        (nth 2 rv:prj)
                        (if (/= "" (nth 3 rv:prj)) (strcat " (" (nth 3 rv:prj) ")") "")
                        "   "
                        (car rv:prj)
                )
          )
          (cons "rev/rows" (mapcar '(lambda (r) (Dyl:RevRow r (setq i (1+ i)) nums)) rv:revs))
          (cons "rev.sel" (Dyl:RevSelStr rv:sel))
          (list "rev/new" (list "" "Numeric" (Dyl:RevToday) "" "" "" "" "" ""))
          (cons "num/list" *rev:numberings*)
          (cons "sht/list" (mapcar '(lambda (s) (Dyl:RevSheetLine s shown nums)) rv:shts))
          (cons "sht" (Dyl:RevSelStr rv:ssel))
          (cons "shh" (if rv:sel (strcat "Rev. " (itoa (1+ (car rv:sel)))) ""))
          (cons "scn" (Dyl:RevSheetsCount shown (car rv:sel)))
          (cons "tbs" (Dyl:RevBlocksSummary))
          (cons "error" (cond (rv:msg) ("")))
    )
    (if rv:revs
      (list (cons "sht/by" (mapcar '(lambda (r) (mapcar '(lambda (s) (Dyl:RevSheetLine s (car r) nums)) rv:shts)) rv:revs))
            (progn (setq i -1) (cons "shh/by" (mapcar '(lambda (r) (list (strcat "Rev. " (itoa (1+ (setq i (1+ i))))))) rv:revs)))
            (progn (setq i -1) (cons "scn/by" (mapcar '(lambda (r) (list (Dyl:RevSheetsCount (car r) (setq i (1+ i))))) rv:revs)))
      )
    )
    (Dyl:WinList "pnm" '("Per project" "Per sheet") (if (= "Sheet" (cdr (assoc "Numbering" rv:sets))) 1 0))
    (Dyl:WinList "pst" '("1" "0") (if (= "0" (cdr (assoc "Start" rv:sets))) 1 0))
  )
)

;;  The revisions as the window gave them back (res): their columns, trimmed, the numbering
;;  one of *rev:numberings*, Issued "1" or "":
(defun Dyl:RevWinRevs (res)
  (mapcar '(lambda (r)
             (list (nth 0 r)
                   (if (member (nth 1 r) *rev:numberings*) (nth 1 r) "Numeric")
                   (vl-string-trim " " (nth 2 r))
                   (vl-string-trim " " (nth 3 r))
                   (vl-string-trim " " (nth 4 r))
                   (vl-string-trim " " (nth 5 r))
                   (if (= "1" (nth 6 r)) "1" "")
             )
           )
          (cdr (assoc "rev/rows" (cdr res)))
  )
)

;;  Keep what the window gave back: the revisions selected, the sheets selected and the
;;  numbering of the project (the revisions themselves: see Dyl:RevWinRevs):
(defun Dyl:RevWinGet (res)
  (setq rv:sel  (Dyl:RevSelOf (Dyl:WinGet res "rev.sel"))
        rv:ssel (Dyl:RevSelOf (Dyl:WinGet res "sht"))
        rv:sets (subst (cons "Numbering" (if (= 1 (Dyl:WinIdx res "pnm")) "Sheet" "Project")) (assoc "Numbering" rv:sets) rv:sets)
        rv:sets (subst (cons "Start" (if (= 1 (Dyl:WinIdx res "pst")) "0" "1")) (assoc "Start" rv:sets) rv:sets)
        rv:msg  nil
  )
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
)

;;  Delete: the revisions selected, from the sheets too, after a confirmation. Their clouds
;;  stay in the drawings, without a revision. Never an issued one, nor one before an issued
;;  revision that would be numbered otherwise. Returns why it was not done:
(defun Dyl:RevDelete (/ ids n)
  (setq ids (mapcar 'car (Dyl:RevSelRevs))
        n   (length (vl-remove-if-not '(lambda (s) (vl-some '(lambda (i) (member i (cadddr s))) ids)) rv:shts))
  )
  (cond
    ((not ids) "Select the revisions to delete.")
    ((vl-some 'Dyl:RevIssued-p (Dyl:RevSelRevs)) "An issued revision cannot be deleted: clear Issued first.")
    ((not (Dyl:RevKeepsIssued-p (Dyl:RevWithoutSel)))
     "An issued revision after it would be numbered otherwise: it cannot be deleted."
    )
    ((Dyl:Ask (list (strcat "Delete " (itoa (length ids)) " revision(s) from the project?")
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
     nil
    )
  )
)

;;  Move up (d -1) / Move down (d 1) the revision selected: one at a time, never an issued
;;  one nor past an issued revision (its number would change). Returns why it was not done:
(defun Dyl:RevMove (d / i r o)
  (setq i (car rv:sel)
        r (if i (nth i rv:revs))
        o (if i (nth (+ i d) rv:revs))
  )
  (cond
    ((or (not r) (cdr rv:sel)) "Select one revision to move.")
    ((Dyl:RevIssued-p r) "An issued revision cannot move: clear Issued first.")
    ((or (not o) (> 0 (+ i d))) nil)
    ((Dyl:RevIssued-p o) "A revision never moves past an issued one: its number would change.")
    (T
     (setq rv:revs (Remote>>Dyl:ListInsert (Remote>>Dyl:ListRemove rv:revs i) (+ i d) r)
           rv:sel  (list (+ i d))
     )
     nil
    )
  )
)

;;  Add Revision (add T) / Remove Revision (add nil): the revisions selected given to the
;;  sheets selected, or taken from them (the ids of a sheet kept in their sequence). Returns
;;  why it was not done, or what was not:
(defun Dyl:RevSheetsPut (add / ids i keep)
  (setq ids (mapcar 'car (Dyl:RevSelRevs))
        i   -1
  )
  (cond
    ((not (and ids rv:ssel)) "Select the revisions and the sheets.")
    ((vl-some 'Dyl:RevIssued-p (Dyl:RevSelRevs)) "An issued revision is not given to sheets nor taken from them: clear Issued first.")
    (T
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
     (if keep "Some sheets keep the revision through their clouds: erase the clouds to remove it.")
    )
  )
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

;;  The window (Res\Dyl-Revisions.xaml) edits the revisions itself; what changes their
;;  numbers closes it with its number and it is shown again (see the window file). OK (1)
;;  saves them and updates the sheets they change, Update All Sheets (2) every sheet:

;; Revisions
;; Opens the revisions of the project, as in Revit: their numbering, dates and descriptions, and the sheets that have them.

(defun c:Dyl-Revisions (/ rv:prj rv:revs rv:revs0 rv:sets rv:sets0 rv:shts rv:shts0 rv:sel rv:ssel rv:stamp rv:tbchg rv:msg res sta done revs files)
  (cond
    ((not (setq rv:prj (Remote>>Dyl:RevProjectOf)))
     (princ "\nThis drawing is not in a project: open a drawing of a Project Navigator project (its folder or a folder under it has the .apj file).")
    )
    (T
     (setq rv:revs  (Remote>>Dyl:RevRead rv:prj)
           rv:revs0 rv:revs
           rv:sets  (Remote>>Dyl:RevSettings rv:prj)
           rv:sets0 rv:sets
           rv:shts  (Dyl:RevSheetsOf rv:prj)
           rv:shts0 rv:shts
           rv:stamp (Dyl:RevStamps rv:prj)
           rv:sel   (if rv:revs (list (1- (length rv:revs))))
           sta      T
     )
     (while sta
       (setq res (Dyl:WinShow "Dyl-Revisions.xaml" (Dyl:RevWinVals))
             sta (if res (car res) 0)
       )
       (if (< 0 sta)
         (progn
           (setq revs (Dyl:RevWinRevs res))
           (Dyl:RevWinGet res)
           ;;  A numbering that would number an issued revision after them otherwise is
           ;;  refused: the revisions keep their numberings:
           (if (and (= 5 sta) (not (Dyl:RevKeepsIssued-p revs)))
             (setq revs   (mapcar '(lambda (r / o) (if (setq o (assoc (car r) rv:revs)) (Remote>>Dyl:ListSubst r 1 (nth 1 o)) r)) revs)
                   rv:msg "An issued revision after it would be numbered otherwise: its numbering cannot change."
             )
           )
           (setq rv:revs revs)
           (cond
             ((member sta '(1 2)) (if (not (setq rv:msg (Dyl:RevCheck))) (setq done sta sta nil)))
             ((= 4 sta) (if (Dyl:RevBlocksDialog) (setq rv:tbchg T)))
             ((= 6 sta) (Dyl:RevNew))
             ((= 7 sta) (setq rv:msg (Dyl:RevDelete)))
             ((= 8 sta) (setq rv:msg (Dyl:RevMove -1)))
             ((= 9 sta) (setq rv:msg (Dyl:RevMove 1)))
             ((= 10 sta) (setq rv:msg (Dyl:RevSheetsPut T)))
             ((= 11 sta) (setq rv:msg (Dyl:RevSheetsPut nil)))
           )
         )
         (setq sta nil)
       )
     )
     (cond
       ((not done) (princ "\nRevisions unchanged."))
       ((not (Dyl:RevSave)) (alert "Error: the revisions could not be saved in the DynALisp folder of the project (is a file open in Excel?)."))
       ((setq files (if (= 2 done) (Remote>>Dyl:RevSheetFiles rv:prj) (Dyl:RevToUpdate)))
        (princ "\nRevisions saved.")
        (Dyl:RevReport (Remote>>Dyl:RevUpdateFiles rv:prj files))
       )
       ((princ "\nRevisions saved: no sheet to update."))
     )
    )
  )
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
