;; Dyl-Revisions - Revisions of a project, kept in one place and given to its sheets
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

;;  Loaded at startup with the other Remote files, before the Apps. The window and the
;;  commands are in Apps\Output\Dyl-Revisions.lsp.
;;
;;  The revisions of a project are managed as in Revit: one list for the whole project,
;;  each sheet (a layout of a sheet drawing) showing the revisions it has in its title
;;  block, numbered per project or per sheet.
;;
;;  The project is the AutoCAD Architecture project (Project Navigator) of the drawing:
;;  the first folder holding a .apj file, from the folder of the drawing up. Its sheets are
;;  the drawings of its sheet folder (SheetLocation of the .apj, Sheets\ by default). The
;;  revisions are project data, shared by every user of the project: they are kept in the
;;  project, in its DynALisp folder (<project>\DynALisp), never in the DynALisp settings:
;;
;;    Revisions.csv         the revisions, in their sequence (the order of the rows):
;;                          Id;Numbering;Date;Description;IssuedTo;IssuedBy;Issued
;;    RevisionSettings.csv  the settings of the project: Setting;Value
;;                          (Numbering: Project or Sheet, Start: the first number, 1 or 0,
;;                          LastId: the highest id given)
;;    Sheets.csv            the sheets and their revisions: File;Layout;Revisions;Clouds
;;                          (File relative to the project, the ids divided by |)
;;
;;  The files are UTF-8 (when AutoCAD can write it) and divided by ";".
;;
;;  A revision is a list of strings (id numbering date description issuedto issuedby
;;  issued): id never reused ("1", "2"...), numbering "Numeric", "Alphabetic" or "None",
;;  issued "1" once issued (its values and its sheets are then locked) or "".
;;
;;  A sheet has a revision when it is given to it in the Revisions window (Revisions of
;;  Sheets.csv: the central list, also kept in the layout itself as a copy, see
;;  *rev:xrec*), or when a revision cloud of the revision is on the layout (Pst-RevisionCloud:
;;  a polyline with the XData of *rev:app*; Clouds of Sheets.csv is what the last update
;;  found).
;;
;;  Its number: per project, the place of the revision among the revisions of its
;;  numbering (1, 2, 3 / A, B, C); per sheet, its place among the revisions of the sheet
;;  of its numbering. A revision of numbering None has no number.
;;
;;  The title blocks: RevisionBlocks.csv (Modules\Dynalisp\Res, edited in the Revision
;;  Title Blocks window, Dyl:UserFile) gives for a block name (wildcards) the attributes of
;;  its revision rows, # standing for the number of the row (REV#_DATE: REV1_DATE...):
;;    Block;Rows;First;Number;Date;Description;IssuedTo;IssuedBy;Current;CurrentDate
;;  Rows: the number of revision rows of the block; First: Newest or Oldest, the revision
;;  of row 1 (the newest Rows revisions are shown); Current, CurrentDate: one attribute
;;  each, the number and date of the newest revision of the sheet. An attribute left
;;  empty, or that the block does not have, is skipped.
;;
;;  The update of a sheet drawing (Remote>>Dyl:RevSyncDoc) writes its title blocks and the
;;  tags of its clouds, only the values that changed: a drawing already up to date is not
;;  modified. The drawings closed are updated with ObjectDBX, without opening them
;;  (Remote>>Dyl:RevUpdateFiles); one open by another user (its .dwl) is skipped.
;;  ObjectDBX does not move the attributes that are not left-justified to their new text:
;;  their layout is marked (the flag of *rev:xrec*), and they are set again the next time
;;  the drawing is updated open.
;;
;;  Revisions (Dyl-Settings, Overrides, DynalispRevisionSync): every sheet of a project is
;;  updated when it opens (Remote>>Dyl:RevisionsWatch, a startup step).

;;-------------------------=={ Project }==------------------------;;

;;  Registered application of the XData of the clouds and tags: (1000 id) (1000 kind),
;;  kind "Cloud" or "Tag":
(setq *rev:app* "DYL_REV")
;;  XRecord of the extension dictionary of a layout: (1 . "ids") (70 . flag), the ids
;;  given to the sheet divided by |, flag 1 while attributes are to be set again (ObjectDBX):
(setq *rev:xrec* "DYL_REVISIONS")
;;  Block of the revision tags, its attribute:
(setq *rev:tag* "DYL-REVTAG")
(setq *rev:tagatt* "REV")
;;  Headers of the files:
(setq *rev:hdr* '("Id" "Numbering" "Date" "Description" "IssuedTo" "IssuedBy" "Issued"))
(setq *rev:shthdr* '("File" "Layout" "Revisions" "Clouds"))
(setq *rev:sethdr* '("Setting" "Value"))
(setq *rev:blkhdr* '("Block" "Rows" "First" "Number" "Date" "Description" "IssuedTo" "IssuedBy" "Current" "CurrentDate"))
(setq *rev:numberings* '("Numeric" "Alphabetic" "None"))
;;  Settings of a project and their defaults (LastId: the highest id given, never given
;;  again):
(setq *rev:setdefs* '(("Numbering" . "Project") ("Start" . "1") ("LastId" . "0")))

;;  RevisionBlocks.csv, the default (the user copy is read in its place, Dyl:UserFile):
(defun Remote>>Dyl:RevBlocksFile ()
  (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\RevisionBlocks.csv")
)

;;  Revisions sync on (Dyl-Settings): every sheet updated as it opens. Off on a new
;;  installation:
(defun Remote>>Dyl:RevSyncOn-p () (= "1" (getenv "DynalispRevisionSync")))
(defun Remote>>Dyl:RevSyncSet (on) (setenv "DynalispRevisionSync" (if on "1" "0")))

;;  Value of the attribute att of an XML line (<Project Name="..." ...>), nil when missing:
(defun Remote>>Dyl:RevXmlAtt (str att / pos end)
  (if (setq pos (vl-string-search (strcat " " att "=\"") str))
    (progn
      (setq pos (+ pos (strlen att) 3))
      (if (setq end (vl-string-search "\"" str pos)) (substr str (1+ pos) (- end pos)))
    )
  )
)

;;  Text of the element tag of an XML line (<SheetLocation>Sheets\</SheetLocation>):
(defun Remote>>Dyl:RevXmlText (str tag / pos end)
  (if (setq pos (vl-string-search (strcat "<" tag ">") str))
    (progn
      (setq pos (+ pos (strlen tag) 2))
      (if (setq end (vl-string-search "<" str pos)) (substr str (1+ pos) (- end pos)))
    )
  )
)

;;  Open a file as UTF-8 when this AutoCAD can (2021 and later), else as ANSI:
(defun Remote>>Dyl:RevOpen (fle mode / des)
  (if (vl-catch-all-error-p (setq des (vl-catch-all-apply 'open (list fle mode "utf8"))))
    (open fle mode)
    des
  )
)

;;  The project of the folder dir (the folder of a drawing): the first folder holding a
;;  .apj, from dir up. Returns (root apj name number sheets data), nil when none:
;;  root the folder of the .apj, sheets the folder of its sheets, data its DynALisp folder.
(defun Remote>>Dyl:RevProject (dir / apj prv n des str name num loc)
  (setq dir (vl-string-right-trim "\\/" (cond (dir) (""))) n 0)
  (while (and (not apj) (/= "" dir) (< n 40))
    (if (setq apj (car (vl-directory-files dir "*.apj" 1)))
      (setq apj (strcat dir "\\" apj))
      (setq prv dir
            dir (vl-string-right-trim "\\/" (cond ((vl-filename-directory dir)) ("")))
            ;;  Up to the drive (C:) or the share (\\server\share) of the path:
            dir (if (or (= dir prv)
                        (wcmatch dir "?:")
                        (and (wcmatch dir "\\\\*") (not (vl-string-search "\\" dir 2)))
                    )
                  ""
                  dir
                )
            n   (1+ n)
      )
    )
  )
  (if apj
    (progn
      (if (setq des (Remote>>Dyl:RevOpen apj "r"))
        (progn
          (while (setq str (read-line des))
            (if (and (not name) (vl-string-search "<Project " str))
              (setq name (Remote>>Dyl:RevXmlAtt str "Name")
                    num  (Remote>>Dyl:RevXmlAtt str "Number")
              )
            )
            (if (not loc) (setq loc (Remote>>Dyl:RevXmlText str "SheetLocation")))
          )
          (close des)
        )
      )
      (setq loc (vl-string-trim "\\/ " (cond (loc) ("Sheets"))))
      (list dir
            apj
            (cond (name) ((vl-filename-base apj)))
            (cond (num) (""))
            (if (wcmatch loc "?:*,\\\\*") loc (strcat dir "\\" loc))
            (strcat dir "\\DynALisp")
      )
    )
  )
)

;;  The project of the current drawing, nil when it is not saved in one:
(defun Remote>>Dyl:RevProjectOf ()
  (if (= 1 (getvar "DWGTITLED")) (Remote>>Dyl:RevProject (getvar "DWGPREFIX")))
)

;;  A file of the DynALisp folder of the project prj:
(defun Remote>>Dyl:RevPath (prj name) (strcat (nth 5 prj) "\\" name))

;;  Path of the drawing file relative to the project (as Sheets.csv keeps it), or the
;;  full path when it is not in the project:
(defun Remote>>Dyl:RevRel (prj file / root)
  (setq root (strcat (car prj) "\\"))
  (if (= (strcase root) (strcase (substr file 1 (strlen root))))
    (substr file (1+ (strlen root)))
    file
  )
)

;;  Full path of a file of Sheets.csv:
(defun Remote>>Dyl:RevFull (prj rel)
  (if (wcmatch rel "?:*,\\\\*") rel (strcat (car prj) "\\" rel))
)

;;  The sheet drawings of the project: every .dwg of its sheet folder and its sub-folders
;;  (full paths, sorted):
(defun Remote>>Dyl:RevSheetFiles (prj / walk lst)
  (defun walk (dir)
    (foreach f (vl-directory-files dir "*.dwg" 1) (setq lst (cons (strcat dir "\\" f) lst)))
    (foreach d (vl-directory-files dir nil -1)
      (if (not (member d '("." ".."))) (walk (strcat dir "\\" d)))
    )
  )
  (if (vl-file-directory-p (nth 4 prj)) (walk (nth 4 prj)))
  (vl-sort lst '(lambda (a b) (< (strcase a) (strcase b))))
)

;;-------------------------=={ Files }==------------------------;;

;;  Rows of a file of the project (or RevisionBlocks.csv), header excluded, each cut or
;;  padded to n cells. The separator is found in the header (";", tab or ","). nil when the
;;  file does not exist:
(defun Remote>>Dyl:RevCsvRead (fle n / des str sep idx row lst)
  (repeat n (setq idx (cons (setq n (1- n)) idx)))
  (if (and fle (findfile fle) (setq des (Remote>>Dyl:RevOpen fle "r")))
    (progn
      (if (setq str (read-line des))
        (setq sep (cond
                    ((vl-string-search ";" str) ";")
                    ((vl-string-search "\t" str) "\t")
                    (",")
                  )
        )
      )
      (while (setq str (read-line des))
        (if (/= "" (vl-string-trim " \t" str))
          (setq row (Remote>>LM:csv->lst str sep 0)
                lst (cons (mapcar '(lambda (i) (vl-string-trim " " (cond ((nth i row)) ("")))) idx) lst)
          )
        )
      )
      (close des)
    )
  )
  (reverse lst)
)

;;  Write the header hdr and the rows of a file, divided by ";" (its folder made when
;;  missing). Returns T once written, nil when it cannot be (open in Excel...):
(defun Remote>>Dyl:RevCsvWrite (fle hdr rows / des)
  (if (not (vl-file-directory-p (vl-filename-directory fle))) (vl-mkdir (vl-filename-directory fle)))
  (if (setq des (Remote>>Dyl:RevOpen fle "w"))
    (progn
      (foreach r (cons hdr rows) (write-line (Remote>>LM:lst->csv r ";") des))
      (close des)
      T
    )
  )
)

;;  Date and time a file was last written, to find out whether another user changed it
;;  (nil when it does not exist):
(defun Remote>>Dyl:RevStamp (fle) (if (findfile fle) (vl-file-systime fle)))

;;  ids text ("1|3") <-> list of ids ("1" "3"):
(defun Remote>>Dyl:RevIds (str) (vl-remove "" (Remote>>LM:str->lst (cond (str) ("")) "|")))
(defun Remote>>Dyl:RevIdsStr (ids) (cond ((Remote>>LM:lst->str ids "|")) ("")))

;;  The revisions of the project, in their sequence:
(defun Remote>>Dyl:RevRead (prj / lst)
  (foreach r (Remote>>Dyl:RevCsvRead (Remote>>Dyl:RevPath prj "Revisions.csv") (length *rev:hdr*))
    (if (/= "" (car r))
      (setq lst (cons (Remote>>Dyl:ListSubst r 1 (if (member (nth 1 r) *rev:numberings*) (nth 1 r) "Numeric")) lst))
    )
  )
  (reverse lst)
)

(defun Remote>>Dyl:RevWrite (prj lst)
  (Remote>>Dyl:RevCsvWrite (Remote>>Dyl:RevPath prj "Revisions.csv") *rev:hdr* lst)
)

;;  The settings of the project, every one of *rev:setdefs*: ((setting . value) ...)
(defun Remote>>Dyl:RevSettings (prj / rows)
  (setq rows (Remote>>Dyl:RevCsvRead (Remote>>Dyl:RevPath prj "RevisionSettings.csv") 2))
  (mapcar '(lambda (d / r)
             (setq r (assoc (car d) rows))
             (cons (car d) (if (and r (/= "" (cadr r))) (cadr r) (cdr d)))
           )
          *rev:setdefs*
  )
)

(defun Remote>>Dyl:RevSettingsWrite (prj sets)
  (Remote>>Dyl:RevCsvWrite (Remote>>Dyl:RevPath prj "RevisionSettings.csv")
                           *rev:sethdr*
                           (mapcar '(lambda (s) (list (car s) (cdr s))) sets)
  )
)

;;  The sheets of Sheets.csv: ((file layout hand clouds) ...), hand and clouds lists of ids:
(defun Remote>>Dyl:RevSheets (prj)
  (mapcar '(lambda (r) (list (car r) (cadr r) (Remote>>Dyl:RevIds (caddr r)) (Remote>>Dyl:RevIds (cadddr r))))
          (vl-remove-if '(lambda (r) (= "" (car r)))
                        (Remote>>Dyl:RevCsvRead (Remote>>Dyl:RevPath prj "Sheets.csv") (length *rev:shthdr*))
          )
  )
)

(defun Remote>>Dyl:RevSheetsWrite (prj lst)
  (Remote>>Dyl:RevCsvWrite
    (Remote>>Dyl:RevPath prj "Sheets.csv")
    *rev:shthdr*
    (mapcar '(lambda (s) (list (car s) (cadr s) (Remote>>Dyl:RevIdsStr (caddr s)) (Remote>>Dyl:RevIdsStr (cadddr s))))
            (vl-sort lst
                     '(lambda (a b)
                        (if (= (strcase (car a)) (strcase (car b)))
                          (< (strcase (cadr a)) (strcase (cadr b)))
                          (< (strcase (car a)) (strcase (car b)))
                        )
                      )
            )
    )
  )
)

;;  Same sheet (file and layout, any case):
(defun Remote>>Dyl:RevSame-p (a b)
  (and (= (strcase (car a)) (strcase (car b))) (= (strcase (cadr a)) (strcase (cadr b))))
)

;;  The row of the sheet (file layout) in the sheets lst, nil when none:
(defun Remote>>Dyl:RevSheetRow (lst file layout)
  (vl-some '(lambda (s) (if (Remote>>Dyl:RevSame-p s (list file layout)) s)) lst)
)

;;  Put the rows of the drawings files (relative paths) in Sheets.csv, read again just
;;  before (another user may have changed it): their former rows are replaced by rows.
;;  Written only when it changes:
(defun Remote>>Dyl:RevSheetsMerge (prj files rows / old new)
  (setq files (mapcar 'strcase files)
        old   (Remote>>Dyl:RevSheets prj)
        new   (append (vl-remove-if '(lambda (s) (member (strcase (car s)) files)) old) rows)
  )
  (if (or (/= (length old) (length new))
          (vl-some '(lambda (s / o) (not (and (setq o (Remote>>Dyl:RevSheetRow old (car s) (cadr s))) (equal o s)))) new)
      )
    (Remote>>Dyl:RevSheetsWrite prj new)
    T
  )
)

;;  The title blocks of RevisionBlocks.csv: (block rows first number date description
;;  issuedto issuedby current currentdate), rows an integer, the others in upper case:
(defun Remote>>Dyl:RevBlocks ()
  (mapcar '(lambda (r)
             (append (list (strcase (car r))
                           (max 0 (atoi (cadr r)))
                           (if (= "OLDEST" (strcase (caddr r))) "Oldest" "Newest")
                     )
                     (mapcar 'strcase (cdddr r))
             )
           )
          (vl-remove-if '(lambda (r) (= "" (car r)))
                        (Remote>>Dyl:RevCsvRead (Dyl:UserFile (Remote>>Dyl:RevBlocksFile)) (length *rev:blkhdr*))
          )
  )
)

(defun Remote>>Dyl:RevBlocksWrite (lst)
  (Remote>>Dyl:RevCsvWrite (Dyl:UserFileW (Remote>>Dyl:RevBlocksFile))
                           *rev:blkhdr*
                           (mapcar '(lambda (b) (append (list (car b) (itoa (cadr b)) (caddr b)) (cdddr b))) lst)
  )
)

;;-------------------------=={ Numbers }==------------------------;;

;;  n as letters: 1 A, 26 Z, 27 AA...
(defun Remote>>Dyl:RevAlpha (n / s)
  (setq s "")
  (while (> n 0)
    (setq n (1- n)
          s (strcat (chr (+ 65 (rem n 26))) s)
          n (/ n 26)
    )
  )
  s
)

;;  Numbers of the revisions revs (in their sequence), each counted among the revisions of
;;  revs of its numbering: ((id . number) ...), "" for numbering None. start: the first
;;  number of the Numeric ones (1 or 0):
(defun Remote>>Dyl:RevNumbers (revs start / cnt res k sch)
  (foreach r revs
    (setq sch (nth 1 r))
    (if (member sch '("Numeric" "Alphabetic"))
      (setq k   (1+ (cond ((cdr (assoc sch cnt))) (0)))
            cnt (cons (cons sch k) cnt)
            res (cons (cons (car r) (if (= "Numeric" sch) (itoa (+ k start -1)) (Remote>>Dyl:RevAlpha k))) res)
      )
      (setq res (cons (cons (car r) "") res))
    )
  )
  (reverse res)
)

;;  The revisions of revs that are in the list of ids, in their sequence:
(defun Remote>>Dyl:RevOn (revs ids)
  (vl-remove-if-not '(lambda (r) (member (car r) ids)) revs)
)

;;  The numbers of the revisions of a sheet (its ids), per project or per sheet as set in
;;  the project (sets); all: the numbers of every revision (per project), given to save
;;  computing them for each sheet:
(defun Remote>>Dyl:RevSheetNumbers (revs sets ids all / start)
  (setq start (atoi (cdr (assoc "Start" sets))))
  (if (= "Sheet" (cdr (assoc "Numbering" sets)))
    (Remote>>Dyl:RevNumbers (Remote>>Dyl:RevOn revs ids) start)
    (cond (all) ((Remote>>Dyl:RevNumbers revs start)))
  )
)

;;-------------------------=={ Drawings }==------------------------;;

;;  The values of the XData of *rev:app* of an object: ("id" "kind"), nil when none:
(defun Remote>>Dyl:RevXData (obj / typ val res)
  (if
    (and (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetXData (list obj *rev:app* 'typ 'val))))
         (= 'VARIANT (type val))
         (not (vl-catch-all-error-p
                (setq res (vl-catch-all-apply
                            '(lambda () (mapcar 'vlax-variant-value (vlax-safearray->list (vlax-variant-value val))))
                          )
                )
              )
         )
    )
    (cdr res)
  )
)

;;  The XRecord of a layout: (ids flag), nil when it has none:
(defun Remote>>Dyl:RevXrecGet (lay / dic xr typ val lst)
  (if
    (and (= :vlax-true (vla-get-HasExtensionDictionary lay))
         (setq dic (vla-GetExtensionDictionary lay))
         (not (vl-catch-all-error-p (setq xr (vl-catch-all-apply 'vla-Item (list dic *rev:xrec*)))))
         (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-GetXRecordData (list xr 'typ 'val))))
         (= 'VARIANT (type val))
         (not (vl-catch-all-error-p
                (setq lst (vl-catch-all-apply
                            '(lambda () (mapcar 'vlax-variant-value (vlax-safearray->list (vlax-variant-value val))))
                          )
                )
              )
         )
    )
    (list (Remote>>Dyl:RevIds (car lst)) (if (= 1 (cadr lst)) 1 0))
  )
)

;;  Write the XRecord of a layout: the ids given to it, flag 1 while attributes are to be
;;  set again:
(defun Remote>>Dyl:RevXrecPut (lay ids flag / dic xr)
  (setq dic (vla-GetExtensionDictionary lay))
  (if (vl-catch-all-error-p (setq xr (vl-catch-all-apply 'vla-Item (list dic *rev:xrec*))))
    (setq xr (vla-AddXRecord dic *rev:xrec*))
  )
  (vla-SetXRecordData
    xr
    (vlax-safearray-fill (vlax-make-safearray vlax-vbInteger '(0 . 1)) '(1 70))
    (vlax-safearray-fill (vlax-make-safearray vlax-vbVariant '(0 . 1))
                         (list (vlax-make-variant (Remote>>Dyl:RevIdsStr ids)) (vlax-make-variant flag vlax-vbInteger))
    )
  )
)

;;  Name of a block reference (its dynamic block for a dynamic one), upper case:
(defun Remote>>Dyl:RevBlockName (obj / nam)
  (if (vl-catch-all-error-p (setq nam (vl-catch-all-apply 'vla-get-EffectiveName (list obj))))
    (setq nam (vla-get-Name obj))
  )
  (strcase nam)
)

;;  The title block of RevisionBlocks.csv (maps) of a block name, nil when none:
(defun Remote>>Dyl:RevBlockMap (nam maps)
  ;;  The name itself first: a name picked (Dyl:RevBlocksGuess) is saved as it is, and one
  ;;  with a wildcard character (#, @, ., ~, [...) does not match itself in wcmatch:
  (vl-some '(lambda (m) (if (or (= (strcase nam) (strcase (car m))) (wcmatch nam (car m))) m)) maps)
)

;;  The objects of a layout that DynALisp writes: (clouds tags blocks), clouds the ids of
;;  its revision clouds, tags ((ref . id) ...) its revision tags, blocks ((ref . map) ...)
;;  its title blocks:
(defun Remote>>Dyl:RevScan (blk maps / typ xd m clouds tags blocks)
  (vlax-for o blk
    (setq typ (vla-get-ObjectName o))
    (cond
      ((not (member typ '("AcDbPolyline" "AcDbBlockReference"))))
      ((setq xd (Remote>>Dyl:RevXData o))
       (if (= "Tag" (cadr xd))
         (setq tags (cons (cons o (car xd)) tags))
         (if (not (member (car xd) clouds)) (setq clouds (cons (car xd) clouds)))
       )
      )
      ((and (= typ "AcDbBlockReference")
            (= :vlax-true (vla-get-HasAttributes o))
            (setq m (Remote>>Dyl:RevBlockMap (Remote>>Dyl:RevBlockName o) maps))
       )
       (setq blocks (cons (cons o m) blocks))
      )
    )
  )
  (list clouds tags blocks)
)

;;  The attributes of a block reference: ((TAG . attribute) ...):
(defun Remote>>Dyl:RevAtts (ref)
  (mapcar '(lambda (a) (cons (strcase (vla-get-TagString a)) a)) (vlax-invoke ref 'GetAttributes))
)

;;  Tag of a revision row: # replaced by the number of the row:
(defun Remote>>Dyl:RevTagOf (pat i / pos)
  (while (setq pos (vl-string-search "#" pat)) (setq pat (vl-string-subst (itoa i) "#" pat)))
  pat
)

;;  Set the text of an attribute when it differs. Returns 1 when set, 0 when it was the
;;  same, 101 for an attribute that is not left-justified set with ObjectDBX (dbx T): its
;;  layout is marked (see *rev:xrec*). The counts of a layout are added: 0 nothing set,
;;  100 or more a layout to mark:
(defun Remote>>Dyl:RevPut (att val dbx)
  (cond
    ((= val (vla-get-TextString att)) 0)
    ((vl-catch-all-error-p (vl-catch-all-apply 'vla-put-TextString (list att val))) 0)
    ((and dbx (/= acAlignmentLeft (vla-get-Alignment att))) 101)
    (1)
  )
)

;;  Fill a title block (ref) of the map m with the revisions of its sheet (on, in their
;;  sequence) and their numbers (nums: ((id . number) ...)). Returns its count of
;;  attributes set (see Remote>>Dyl:RevPut):
(defun Remote>>Dyl:RevFill (ref m on nums dbx / atts n lst i r cnt cur att val)
  (setq atts (Remote>>Dyl:RevAtts ref)
        n    (cadr m)
        lst  on
        cnt  0
        cur  (last on)
  )
  ;;  The newest n:
  (while (> (length lst) n) (setq lst (cdr lst)))
  (if (= "Newest" (caddr m)) (setq lst (reverse lst)))
  (setq i 0)
  (repeat n
    (setq r (nth i lst)
          i (1+ i)
    )
    ;;  Number Date Description IssuedTo IssuedBy (columns 3 to 7 of the map):
    (mapcar
      '(lambda (pat get)
         (if (and (/= "" pat) (setq att (cdr (assoc (Remote>>Dyl:RevTagOf pat i) atts))))
           (setq cnt (+ cnt (Remote>>Dyl:RevPut att (if r (apply get (list r)) "") dbx)))
         )
       )
      (list (nth 3 m) (nth 4 m) (nth 5 m) (nth 6 m) (nth 7 m))
      (list '(lambda (r) (cond ((cdr (assoc (car r) nums))) ("")))
            '(lambda (r) (nth 2 r))
            '(lambda (r) (nth 3 r))
            '(lambda (r) (nth 4 r))
            '(lambda (r) (nth 5 r))
      )
    )
  )
  ;;  Current revision and its date:
  (foreach x (list (cons (nth 8 m) (if cur (cond ((cdr (assoc (car cur) nums))) ("")) ""))
                   (cons (nth 9 m) (if cur (nth 2 cur) ""))
             )
    (if (and (/= "" (car x)) (setq att (cdr (assoc (car x) atts))))
      (setq cnt (+ cnt (Remote>>Dyl:RevPut att (cdr x) dbx)))
    )
  )
  cnt
)

;;  Set again the text of the attributes of the title blocks and tags (after an update
;;  with ObjectDBX, which did not move the ones not left-justified):
(defun Remote>>Dyl:RevRealign (scan)
  (foreach x (append (cadr scan) (caddr scan))
    (foreach a (vlax-invoke (car x) 'GetAttributes)
      (if (/= acAlignmentLeft (vla-get-Alignment a))
        (vl-catch-all-apply '(lambda () (vla-put-TextString a (vla-get-TextString a)) (vla-Update a)))
      )
    )
  )
)

;;  Update the sheets of a drawing (doc: the active document, another open one or an
;;  ObjectDBX one, dbx T) of the project prj: for each layout, the revisions given to it
;;  (from the sheets of Sheets.csv shts, else from its XRecord when Sheets.csv does not
;;  have it: a drawing renamed or copied keeps its revisions), its clouds, its title blocks
;;  and its tags. Only what differs is written.
;;  revs, sets, maps: the revisions, settings and title blocks, all: the numbers per project.
;;  Returns (count rows): count the number of values written, rows the rows of Sheets.csv
;;  of the drawing.
(defun Remote>>Dyl:RevSyncDoc (doc file prj revs sets maps shts all dbx / rel cnt rows nam row xr hand scan on nums flag c)
  (setq rel (Remote>>Dyl:RevRel prj file)
        cnt 0
  )
  (vlax-for lay (vla-get-Layouts doc)
    (if (= :vlax-false (vla-get-ModelType lay))
      (progn
        (setq nam  (vla-get-Name lay)
              row  (Remote>>Dyl:RevSheetRow shts rel nam)
              xr   (Remote>>Dyl:RevXrecGet lay)
              hand (cond (row (caddr row)) (xr (car xr)))
              scan (Remote>>Dyl:RevScan (vla-get-Block lay) maps)
              on   (Remote>>Dyl:RevOn revs (append hand (car scan)))
              nums (Remote>>Dyl:RevSheetNumbers revs sets (mapcar 'car on) all)
              flag 0
        )
        ;;  Attributes left by ObjectDBX, set again now that the drawing is open:
        (if (and xr (= 1 (cadr xr)) (not dbx)) (Remote>>Dyl:RevRealign scan))
        (foreach b (caddr scan)
          (setq c (Remote>>Dyl:RevFill (car b) (cdr b) on nums dbx))
          (if (<= 100 c) (setq flag 1))
          (setq cnt (+ cnt c))
        )
        (foreach tg (cadr scan)
          (foreach a (vlax-invoke (car tg) 'GetAttributes)
            (if (= *rev:tagatt* (strcase (vla-get-TagString a)))
              (progn
                (setq c (Remote>>Dyl:RevPut a (cond ((cdr (assoc (cdr tg) nums))) ("")) dbx))
                (if (<= 100 c) (setq flag 1))
                (setq cnt (+ cnt c))
              )
            )
          )
        )
        ;;  The flag kept while the drawing has not been updated open:
        (if (and xr (= 1 (cadr xr)) dbx) (setq flag 1))
        (if (or hand xr (= 1 flag))
          (if (not (equal (list hand flag) (cond (xr) ((list nil 0)))))
            (progn (Remote>>Dyl:RevXrecPut lay hand flag) (setq cnt (1+ cnt)))
          )
        )
        (setq rows (cons (list rel nam hand (reverse (car scan))) rows))
      )
    )
  )
  (list cnt (reverse rows))
)

;;  The drawing of the documents open in this AutoCAD whose path is file, nil when none:
(defun Remote>>Dyl:RevOpenDoc (file / doc)
  (vlax-for d (vla-get-Documents (vlax-get-acad-object))
    (if (= (strcase (vla-get-FullName d)) (strcase file)) (setq doc d))
  )
  doc
)

;;  User who has the drawing file open, from its lock file (.dwl), nil when none:
(defun Remote>>Dyl:RevLockedBy (file / dwl des str)
  (setq dwl (strcat (vl-filename-directory file) "\\" (vl-filename-base file) ".dwl"))
  (if (findfile dwl)
    (cond
      ((and (setq des (open dwl "r")) (setq str (read-line des)) (progn (close des) T) (/= "" str)) str)
      ((progn (if des (close des)) "another user"))
    )
  )
)

;;  Update the sheet drawings files (full paths) of the project prj. The active drawing and
;;  the other drawings open in this AutoCAD are updated (not saved), the closed ones with
;;  ObjectDBX (saved), a drawing open by another user skipped. Sheets.csv gets their rows.
;;  Returns ((file status) ...), status "Updated", "Up to date", "Updated, not saved",
;;  "Open by <user>" or "--> <error>":
(defun Remote>>Dyl:RevUpdateFiles (prj files / acad revs sets maps shts all dbx res rows done doc who r n)
  (setq acad (vlax-get-acad-object)
        revs (Remote>>Dyl:RevRead prj)
        sets (Remote>>Dyl:RevSettings prj)
        maps (Remote>>Dyl:RevBlocks)
        shts (Remote>>Dyl:RevSheets prj)
        all  (Remote>>Dyl:RevNumbers revs (atoi (cdr (assoc "Start" sets))))
        n    0
  )
  ;;  A progress bar for several drawings, when the Express Tools are there:
  (if (and (cdr files) acet-ui-progress-init) (acet-ui-progress-init "Updating the revisions of the sheets" (length files)))
  (foreach f files
    (setq n (1+ n))
    (if (and (cdr files) acet-ui-progress-safe) (acet-ui-progress-safe n))
    (cond
      ((setq doc (Remote>>Dyl:RevOpenDoc f))
       (setq r (vl-catch-all-apply 'Remote>>Dyl:RevSyncDoc (list doc f prj revs sets maps shts all nil)))
       (cond
         ;;  Another drawing open here cannot always be changed from this one:
         ((and (vl-catch-all-error-p r) (not (equal doc (vla-get-ActiveDocument acad))))
          (setq res (cons (list f "Open in this AutoCAD: run Pst-RevisionsUpdate in it") res))
         )
         ((vl-catch-all-error-p r) (setq res (cons (list f (strcat "--> " (vl-catch-all-error-message r))) res)))
         ((setq rows (append rows (cadr r))
                done (cons (Remote>>Dyl:RevRel prj f) done)
                res  (cons (list f (if (< 0 (car r)) "Updated, not saved" "Up to date")) res)
          )
         )
       )
      )
      ((setq who (Remote>>Dyl:RevLockedBy f)) (setq res (cons (list f (strcat "Open by " who)) res)))
      ((and (not dbx)
            (vl-catch-all-error-p
              (setq dbx (vl-catch-all-apply 'vla-GetInterfaceObject
                                            (list acad (strcat "ObjectDBX.AxDbDocument." (itoa (atoi (getvar "ACADVER")))))
                        )
              )
            )
            (not (setq dbx nil))
       )
       (setq res (cons (list f "--> ObjectDBX is not available") res))
      )
      ((vl-catch-all-error-p (setq r (vl-catch-all-apply 'vla-Open (list dbx f))))
       (setq res (cons (list f (strcat "--> " (vl-catch-all-error-message r))) res))
      )
      (T
       (setq r (vl-catch-all-apply 'Remote>>Dyl:RevSyncDoc (list dbx f prj revs sets maps shts all T)))
       (cond
         ((vl-catch-all-error-p r) (setq res (cons (list f (strcat "--> " (vl-catch-all-error-message r))) res)))
         ((progn
            (setq rows (append rows (cadr r))
                  done (cons (Remote>>Dyl:RevRel prj f) done)
            )
            (= 0 (car r))
          )
          (setq res (cons (list f "Up to date") res))
         )
         ((vl-catch-all-error-p (setq r (vl-catch-all-apply 'vla-SaveAs (list dbx f))))
          (setq res (cons (list f (strcat "--> Not saved: " (vl-catch-all-error-message r))) res))
         )
         ((setq res (cons (list f "Updated") res)))
       )
      )
    )
  )
  (if dbx (vlax-release-object dbx))
  (if (and (cdr files) acet-ui-progress-done) (acet-ui-progress-done))
  (if done (Remote>>Dyl:RevSheetsMerge prj done rows))
  (reverse res)
)

;;  The current drawing, when it is a sheet of its project prj (in its sheet folder),
;;  nil when not:
(defun Remote>>Dyl:RevSheetThis (prj / f dir)
  (setq f   (strcat (getvar "DWGPREFIX") (getvar "DWGNAME"))
        dir (strcat (strcase (nth 4 prj)) "\\")
  )
  (if (= dir (strcase (substr f 1 (strlen dir)))) f)
)

;;  The rows of Sheets.csv of a drawing (doc) read without changing it: its layouts, the
;;  revisions of their XRecords and their clouds:
(defun Remote>>Dyl:RevSheetRows (doc file prj / rel xr rows)
  (setq rel (Remote>>Dyl:RevRel prj file))
  (vlax-for lay (vla-get-Layouts doc)
    (if (= :vlax-false (vla-get-ModelType lay))
      (setq xr   (Remote>>Dyl:RevXrecGet lay)
            rows (cons (list rel (vla-get-Name lay) (car xr) (reverse (car (Remote>>Dyl:RevScan (vla-get-Block lay) nil)))) rows)
      )
    )
  )
  (reverse rows)
)

;;  Read the sheet drawings files (full paths) of the project prj into Sheets.csv, without
;;  changing them (the open ones as they are, the closed ones with ObjectDBX, read-only):
(defun Remote>>Dyl:RevReadFiles (prj files / acad dbx doc r rows done)
  (setq acad (vlax-get-acad-object))
  (foreach f files
    (if (and (not (setq doc (Remote>>Dyl:RevOpenDoc f))) (not dbx))
      (if (vl-catch-all-error-p
            (setq dbx (vl-catch-all-apply 'vla-GetInterfaceObject
                                          (list acad (strcat "ObjectDBX.AxDbDocument." (itoa (atoi (getvar "ACADVER")))))
                      )
            )
          )
        (setq dbx nil)
      )
    )
    (if (or doc (and dbx (not (vl-catch-all-error-p (vl-catch-all-apply 'vla-Open (list dbx f))))))
      (if (not (vl-catch-all-error-p (setq r (vl-catch-all-apply 'Remote>>Dyl:RevSheetRows (list (cond (doc) (dbx)) f prj)))))
        (setq rows (append rows r)
              done (cons (Remote>>Dyl:RevRel prj f) done)
        )
      )
    )
  )
  (if dbx (vlax-release-object dbx))
  (if done (Remote>>Dyl:RevSheetsMerge prj done rows))
)

;;  Update the current drawing when it is a sheet of a project. Returns a status: "...
;;  updated" or nil (nothing to do), an error with --> (see Dyl:StartupStep):
(defun Remote>>Dyl:RevUpdateThis (/ prj f r)
  (if (and (setq prj (Remote>>Dyl:RevProjectOf)) (setq f (Remote>>Dyl:RevSheetThis prj)))
    (progn
      (setq r (car (Remote>>Dyl:RevUpdateFiles prj (list f))))
      (cond
        ((wcmatch (cadr r) "-->*") (cadr r))
        ((= "Up to date" (cadr r)) nil)
        ("title blocks updated")
      )
    )
  )
)

;;  Startup step of every drawing opened while Revisions is on (Dyl-Settings): the sheets
;;  of a drawing of a project updated, only when its project has revisions. nil when
;;  off, not in a project, or up to date:
(defun Remote>>Dyl:RevisionsWatch (/ prj)
  (if (and (Remote>>Dyl:RevSyncOn-p)
           (setq prj (Remote>>Dyl:RevProjectOf))
           (findfile (Remote>>Dyl:RevPath prj "Revisions.csv"))
      )
    (Remote>>Dyl:RevUpdateThis)
  )
)

(princ)
