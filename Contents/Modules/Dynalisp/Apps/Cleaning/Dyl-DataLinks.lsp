;; DataLinks - Find and clean up the Excel data links of a drawing
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

;;  A data link (DATALINK object of the ACAD_DATALINK dictionary) connects tables
;;  to an Excel file. Links are left behind when their tables are erased or
;;  copied from another drawing, and links to a missing file slow down
;;  DATALINKUPDATE (and the DATALINKS step of the Prep Suite).
;;
;;  A link is "used" when a table of the drawing points to it, or when the link
;;  lists a table (or table content) that still exists as one of its users.
;;  Both checks are made so that a link is never reported unused by mistake.
;;  The tables themselves are never modified or deleted.
;;
;;  A link record is a list:
;;  (name ename status tables file connection)
;;  status: "OK", "Missing file" or "No source", tables: enames of the tables using it.

;;-------------------------=={ Functions }==------------------------;;

;;  Data links of the drawing: ((name ename) ...) sorted by name:
(defun Dyl:DataLinkList (/ dict name lst)
  (if (setq dict (dictsearch (namedobjdict) "ACAD_DATALINK"))
    (foreach x dict
      (cond
        ((= 3 (car x)) (setq name (cdr x)))
        ((and name (member (car x) '(350 360)))
         (setq lst  (cons (list name (cdr x)) lst)
               name nil
         )
        )
      )
    )
  )
  (vl-sort lst '(lambda (a b) (< (strcase (car a)) (strcase (car b)))))
)

;;  Source file of a link, from its connection string ("C:\...\Book.xlsx!Sheet1!A1:D9"):
(defun Dyl:DataLinkFile (ed / str pos)
  (if (and (setq str (cdr (assoc 302 ed))) (/= "" str))
    (substr str 1 (if (setq pos (vl-string-search "!" str)) pos (strlen str)))
  )
)

;;  Full path of a source file when it exists (a relative path is relative to the drawing):
(defun Dyl:DataLinkFound (fil)
  (cond
    ((findfile fil))
    ((not (wcmatch fil "?:*,\\\\*"))
     (findfile (strcat (getvar "DWGPREFIX") (if (wcmatch fil "`.\\*") (substr fil 3) fil)))
    )
  )
)

;;  Add val to the list of key in an association list ((key val ...) ...):
(defun Dyl:DataLinkAdd (key val lst / itm)
  (cond
    ((not (setq itm (assoc key lst))) (cons (list key val) lst))
    ((member val (cdr itm)) lst)
    ((subst (append itm (list val)) itm lst))
  )
)

;;  Data links (among ens) a table points to, directly or through its TABLECONTENT objects:
(defun Dyl:DataLinkPtrs (tbl ens / res)
  (foreach x (entget tbl)
    (if (= 'ENAME (type (cdr x)))
      (cond
        ((member (cdr x) ens) (setq res (cons (cdr x) res)))
        ((and (member (car x) '(340 360))
              (= "TABLECONTENT" (cdr (assoc 0 (entget (cdr x)))))
         )
         (foreach y (entget (cdr x))
           (if (and (= 'ENAME (type (cdr y))) (member (cdr y) ens))
             (setq res (cons (cdr y) res))
           )
         )
        )
      )
    )
  )
  res
)

;;  Tables a link lists as its users and that still exist (an erased table returns no data).
;;  A table content is reported as its table, or as itself when its owner is not a table:
(defun Dyl:DataLinkUsers (dl / ed own res)
  (foreach x (entget dl)
    (if (and (= 330 (car x)) (setq ed (entget (cdr x))))
      (cond
        ((= "ACAD_TABLE" (cdr (assoc 0 ed))) (setq res (cons (cdr x) res)))
        ((= "TABLECONTENT" (cdr (assoc 0 ed)))
         (setq own (cdr (assoc 330 ed))
               res (cons (if (and own (= "ACAD_TABLE" (cdr (assoc 0 (entget own))))) own (cdr x)) res)
         )
        )
      )
    )
  )
  res
)

;;  Every link of the drawing as a link record (see the top of this file):
(defun Dyl:DataLinkInfo (/ links ens use ss i tbl)
  (setq links (Dyl:DataLinkList)
        ens   (mapcar 'cadr links)
  )
  (if (and ens (setq ss (ssget "_X" '((0 . "ACAD_TABLE")))))
    (repeat (setq i (sslength ss))
      (setq tbl (ssname ss (setq i (1- i))))
      (foreach e (Dyl:DataLinkPtrs tbl ens) (setq use (Dyl:DataLinkAdd e tbl use)))
    )
  )
  (foreach e ens
    (foreach x (Dyl:DataLinkUsers e) (setq use (Dyl:DataLinkAdd e x use)))
  )
  (mapcar
    '(lambda (l / ed fil)
       (setq ed  (entget (cadr l))
             fil (Dyl:DataLinkFile ed)
       )
       (list (car l)
             (cadr l)
             (cond ((not fil) "No source") ((Dyl:DataLinkFound fil) "OK") ("Missing file"))
             (cdr (assoc (cadr l) use))
             (cond (fil) (""))
             (cond ((cdr (assoc 302 ed))) (""))
       )
     )
    links
  )
)

;;  Delete a data link, returns T when it is gone:
(defun Dyl:DataLinkDelete (name ent / dict)
  (if
    (vl-catch-all-error-p
      (vl-catch-all-apply '(lambda () (vla-delete (vlax-ename->vla-object ent))))
    )
    (progn
      (if (setq dict (cdr (assoc -1 (dictsearch (namedobjdict) "ACAD_DATALINK"))))
        (dictremove dict name)
      )
      (entdel ent)
    )
  )
  (not (entget ent))
)

;;  Delete the links of a list of link records inside one undo group, returns the number deleted:
(defun Dyl:DataLinkDeleteAll (lst / doc n)
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object))
        n   0
  )
  (vla-StartUndoMark doc)
  (foreach r lst (if (Dyl:DataLinkDelete (car r) (cadr r)) (setq n (1+ n))))
  (vla-EndUndoMark doc)
  n
)

;;  Layouts of a list of tables, e.g. "Model, Layout1":
(defun Dyl:DataLinkWhere (tbls / ed res)
  (foreach e tbls
    (setq ed (entget e)
          res (Dyl:DataLinkAdd 0
                               (cond
                                 ((cdr (assoc 410 ed)))
                                 ((= "ACAD_TABLE" (cdr (assoc 0 ed))) "a block definition")
                                 ("unknown")
                               )
                               res
              )
    )
  )
  (Remote>>LM:lst->str (cdar res) ", ")
)

;;-------------------------=={ Dialog }==------------------------;;

;;  Write the dialog definition to a temporary DCL file and return its path:
(defun Dyl:DataLinkDcl (/ path file)
  (setq path (vl-filename-mktemp "dl" nil ".dcl")
        file (open path "w")
  )
  (foreach line
    '("dyl_dl : dialog { label = \"DynALisp - Data Links\";"
      "  : list_box { label = \"Data links (name, status, tables, source file):\"; key = \"lst\";"
      "               width = 110; height = 16; multiple_select = true; tabs = \"32 46 54\"; }"
      "  : text { key = \"src\"; width = 110; }"
      "  : text { key = \"use\"; width = 110; }"
      "  : row {"
      "    : button { key = \"unu\"; label = \"Select unused\"; }"
      "    : button { key = \"mis\"; label = \"Select missing file\"; }"
      "    : button { key = \"del\"; label = \"Delete selected\"; }"
      "    : button { key = \"upd\"; label = \"Update tables\"; }"
      "    : button { key = \"mgr\"; label = \"Data Link Manager...\"; }"
      "    : button { key = \"cancel\"; label = \"Close\"; is_cancel = true; is_default = true; }"
      "    : button { key = \"docs\"; label = \"Open Docs\"; width = 12; fixed_width = true; }"
      "  }"
      "  errtile;"
      "}"
      "dyl_dl_ask : dialog { label = \"DynALisp - Data Links\";"
      "  : paragraph {"
      "    : text_part { key = \"msg\"; width = 80; }"
      "    : text_part { key = \"msg2\"; width = 80; }"
      "  }"
      "  ok_cancel;"
      "}"
     )
    (write-line line file)
  )
  (close file)
  path
)

;;  The functions below run inside c:Dyl-DataLinks and use its local variables:
;;  dl:dcl (dialog id), dl:lst (link records), dl:sel (names of the selected links),
;;  dl:upd (tables to update after the dialog closes).

;;  Ask a yes/no question in a nested dialog (msg2: second line or ""), returns T on OK:
(defun Dyl:DataLinkDlgAsk (msg msg2)
  (if (new_dialog "dyl_dl_ask" dl:dcl)
    (progn
      (set_tile "msg" msg)
      (set_tile "msg2" msg2)
      (= 1 (start_dialog))
    )
  )
)

;;  Fill the list, select the links of dl:sel and show their details:
(defun Dyl:DataLinkDlgShow ()
  (start_list "lst")
  (foreach r dl:lst
    (add_list (strcat (car r) "\t" (caddr r) "\t" (itoa (length (cadddr r))) "\t" (nth 4 r)))
  )
  (end_list)
  (Dyl:DataLinkDlgSetSel)
)

;;  Select the links of dl:sel in the list:
(defun Dyl:DataLinkDlgSetSel (/ names)
  (setq names (mapcar 'car dl:lst))
  (set_tile "lst"
            (cond
              ((Remote>>LM:lst->str
                 (mapcar 'itoa (vl-remove nil (mapcar '(lambda (n) (vl-position n names)) dl:sel)))
                 " "
               )
              )
              ("")
            )
  )
  (Dyl:DataLinkDlgDetails)
)

;;  Read the selection of the list into dl:sel:
(defun Dyl:DataLinkDlgPick (/ str)
  (setq str    (get_tile "lst")
        dl:sel (if (/= "" str)
                 (mapcar '(lambda (i) (car (nth i dl:lst))) (read (strcat "(" str ")")))
               )
  )
  (set_tile "error" "")
  (Dyl:DataLinkDlgDetails)
)

;;  Details of the selected links and state of the buttons:
(defun Dyl:DataLinkDlgDetails (/ sel r)
  (setq sel (vl-remove-if-not '(lambda (r) (member (car r) dl:sel)) dl:lst))
  (cond
    ((not sel)
     (set_tile "src" (strcat (itoa (length dl:lst)) " data link(s): "
                             (itoa (length (vl-remove-if 'cadddr dl:lst))) " unused, "
                             (itoa (length (vl-remove-if-not '(lambda (r) (= "Missing file" (caddr r))) dl:lst)))
                             " with a missing file."
                     )
     )
     (set_tile "use" "Select one or more links.")
    )
    ((= 1 (length sel))
     (setq r (car sel))
     (set_tile "src" (strcat "Source: " (if (= "" (nth 5 r)) "(none)" (nth 5 r))))
     (set_tile "use"
               (if (cadddr r)
                 (strcat "Used by " (itoa (length (cadddr r))) " table(s) in: " (Dyl:DataLinkWhere (cadddr r)))
                 "Not used by any table: it can be deleted safely."
               )
     )
    )
    (T
     (set_tile "src" (strcat (itoa (length sel)) " data links selected."))
     (set_tile "use" (strcat (itoa (length (vl-remove-if-not 'cadddr sel))) " of them used by tables."))
    )
  )
  (mode_tile "del" (if sel 0 1))
  (mode_tile "upd" (if (vl-some 'cadddr sel) 0 1))
)

;;  Select every link that matches a test (applied to a link record):
(defun Dyl:DataLinkDlgSelect (test msg)
  (setq dl:sel (mapcar 'car (vl-remove-if-not test dl:lst)))
  (Dyl:DataLinkDlgSetSel)
  (if (not dl:sel) (set_tile "error" msg))
)

;;  Delete the selected links, after a confirmation:
(defun Dyl:DataLinkDlgDelete (/ sel use n)
  (setq sel (vl-remove-if-not '(lambda (r) (member (car r) dl:sel)) dl:lst)
        use (vl-remove-if-not 'cadddr sel)
  )
  (if
    (and sel
         (Dyl:DataLinkDlgAsk
           (strcat "Delete " (itoa (length sel)) " data link(s)? This can be undone with U.")
           (if use
             (strcat (itoa (length use)) " of them are used by tables: the tables are kept, but no longer linked to Excel.")
             ""
           )
         )
    )
    (progn
      (setq n      (Dyl:DataLinkDeleteAll sel)
            dl:lst (Dyl:DataLinkInfo)
            dl:sel nil
      )
      (Dyl:DataLinkDlgShow)
      (set_tile "error"
                (strcat (itoa n) " data link(s) deleted"
                        (if (< n (length sel)) (strcat ", " (itoa (- (length sel) n)) " could not be deleted.") ".")
                )
      )
    )
  )
)

;;  Close the dialog to update the tables of the selected links (tables in a layout only,
;;  the ones a selection set can hold):
(defun Dyl:DataLinkDlgUpdate ()
  (setq dl:upd nil)
  (foreach r dl:lst
    (if (member (car r) dl:sel)
      (foreach e (cadddr r)
        (if (and (assoc 410 (entget e)) (not (member e dl:upd))) (setq dl:upd (cons e dl:upd)))
      )
    )
  )
  (if dl:upd
    (done_dialog 3)
    (set_tile "error" "The tables of these links are in block definitions: update them from the Data Link Manager.")
  )
)

;;  Body of c:Dyl-DataLinks (uses its local variables). Returns the done_dialog status:
;;  0 close, 2 open the Data Link Manager, 3 update the tables of dl:upd and reopen.
(defun Dyl:DataLinkDlgRun ()
  (cond
    ((not (new_dialog "dyl_dl" dl:dcl))
     (princ "\n--> Unable to show the Data Links dialog.")
     0
    )
    (T
     (setq dl:lst (Dyl:DataLinkInfo))
     (Dyl:DataLinkDlgShow)
     (action_tile "lst" "(Dyl:DataLinkDlgPick)")
     (action_tile "unu" "(Dyl:DataLinkDlgSelect '(lambda (r) (not (cadddr r))) \"Every data link is used by a table.\")")
     (action_tile "mis" "(Dyl:DataLinkDlgSelect '(lambda (r) (= \"Missing file\" (caddr r))) \"Every source file was found.\")")
     (action_tile "del" "(Dyl:DataLinkDlgDelete)")
     (action_tile "upd" "(Dyl:DataLinkDlgUpdate)")
     (action_tile "mgr" "(done_dialog 2)")
     (action_tile "cancel" "(done_dialog 0)")
     (Dyl:DocsTile "Cleaning\\Dyl-DataLinks.htm")
     (start_dialog)
    )
  )
)

;;-------------------------=={ Commands }==------------------------;;

;; Data Links
;; Lists the data links of the drawing with their status and tables, and deletes the unused or broken ones.

(defun c:Dyl-DataLinks (/ dcl:pth dl:dcl dl:lst dl:sel dl:upd sta ss)
  (cond
    ((not (Dyl:DataLinkList)) (princ "\nNo data links in this drawing."))
    ((> 0 (setq dl:dcl (load_dialog (setq dcl:pth (Dyl:DataLinkDcl)))))
     (princ "\n--> Unable to load the Data Links dialog.")
    )
    (T
     ;;  "Update tables" closes the dialog, runs DATALINKUPDATE, then reopens it:
     (while
       (progn
         ;;  Any error closes the dialog cleanly and is reported on the command line:
         (setq sta (vl-catch-all-apply 'Dyl:DataLinkDlgRun nil))
         (if (vl-catch-all-error-p sta)
           (progn
             (term_dialog)
             (princ (strcat "\nData Links dialog error: " (vl-catch-all-error-message sta)))
             (setq sta 0)
           )
         )
         (if (= 3 sta)
           (progn
             (setq ss (ssadd))
             (foreach e dl:upd (ssadd e ss))
             (princ (strcat "\nUpdating " (itoa (sslength ss)) " table(s) from their data links..."))
             ;;  MAJ:cmd-silent (dynalisp.mnl) never leaves the command waiting for input:
             (MAJ:cmd-silent (list "_.DATALINKUPDATE" "_U" ss ""))
           )
         )
         (= 3 sta)
       )
     )
     (if (= 2 sta)
       (vla-SendCommand (vla-get-ActiveDocument (vlax-get-acad-object)) "_.DATALINK ")
     )
    )
  )
  (if (and dl:dcl (<= 0 dl:dcl)) (unload_dialog dl:dcl))
  (if dcl:pth (vl-file-delete dcl:pth))
  (princ)
)

;; Purge Data Links
;; Deletes every data link that no table uses, and lists the used links whose Excel file is missing.

(defun c:Pst-DataLinkPurge (/ lst unu mis n)
  (setq lst (Dyl:DataLinkInfo)
        unu (vl-remove-if 'cadddr lst)
        mis (vl-remove-if-not '(lambda (r) (and (cadddr r) (= "Missing file" (caddr r)))) lst)
  )
  (cond
    ((not lst) (princ "\nNo data links in this drawing."))
    ((not unu) (princ (strcat "\nNo unused data link: all " (itoa (length lst)) " are used by tables.")))
    (T
     (princ (strcat "\nUnused data links: " (Remote>>LM:lst->str (mapcar 'car unu) ", ")))
     (initget "Yes No")
     (if (/= "No" (getkword (strcat "\nDelete " (itoa (length unu)) " unused data link(s)? [Yes/No] <Yes>: ")))
       (progn
         (setq n (Dyl:DataLinkDeleteAll unu))
         (princ (strcat "\n" (itoa n) " data link(s) deleted"
                        (if (< n (length unu)) (strcat ", " (itoa (- (length unu) n)) " could not be deleted.") ".")
                )
         )
       )
     )
    )
  )
  (if mis
    (princ (strcat "\nUsed data links with a missing Excel file: "
                   (Remote>>LM:lst->str (mapcar 'car mis) ", ")
                   "\nRun Dyl-DataLinks to review them."
           )
    )
  )
  (princ)
)

(princ)
