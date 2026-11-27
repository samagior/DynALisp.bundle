;; Witness.lsp - the witness files of DynALisp.Core: what the Lisp gives from the test files
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

;;  The C# of DynALisp.Core (Installer\Core\Data) gives what the Lisp code it replaces gives.
;;  This file runs that Lisp code, in AutoCAD, on the test files of In (each folder a case: a
;;  Contents and a User folder of their own), and writes what it gives: the witness files the
;;  tests of the Core (Installer\Core\Tests\WitnessTests.cs) compare the C# with, cell for cell
;;  and byte for byte. Not part of DynALisp: run it once when the Lisp it covers changes.
;;
;;  In AutoCAD, with DynALisp loaded, run Pst-DiagnosticsWitness (DIAG-WITNESS, a child of
;;  Dyl-Diagnostics), or paste on the command line:
;;
;;    (load (strcat *dyl:repo "\\Installer\\Core\\Tests\\Witness\\Witness.lsp"))
;;
;;  It writes %TEMP%\DynALisp Witness <date>.zip and shows it in the Explorer: that zip, its
;;  files put in Installer\Core\Tests\Witness\Lisp, is the witness. Nothing of the drawing, the
;;  settings or the files of DynALisp is read or changed: each case is a copy of its folder in
;;  %TEMP%, the Lisp pointed at it for a moment (*dyl:contents, *dyl:user, *dyl:dylres,
;;  *dyl:res, *dyl:alias) and given back its own folders after, the reads kept dropped. The
;;  files are read by the Lisp itself (Dyl:Data, Dyl:DataHead, Dyl:AsmDefs, Dyl:AsmRead,
;;  Dyl:HatchDefs, Dyl:MatDefs, Dyl:MatBoth, Dyl:AsmPats, Dyl:AsmShows, Dyl:AsmWinMats,
;;  Dyl:AsmRows and Dyl:MatData of the Core hidden meanwhile), so the C# is compared with the
;;  Lisp, never with itself.
;;
;;  What is written, each line its cells divided by (chr 31), nil as (chr 30), a section by a
;;  line #name (UTF-8):
;;    Info.txt      the list separator of Windows, the code page, the version of AutoCAD
;;    Probes.txt    the functions of AutoLISP on the names of In\Probes.csv: the CamelCase of
;;                  the presets, strcase, <, acad_strlsort, vl-sort; distof on the texts of
;;                  wt:nums, rtos and Remote>>Dyl:MaterialNumP on the numbers of wt:reals
;;                  with each DIMZIN of wt:dimzins
;;    <case>\Witness.txt   for each preset tool: its file, header, rows, defaults, rows
;;                  cleaned, presets read and their commands; the groups and their case; the
;;                  aliases; the assemblies (defaults, read and fixed, in the units of
;;                  wt:factors and back); the hatch presets and the materials (defaults,
;;                  read and fixed); what the Quick Draw window shows of each assembly and
;;                  what the Assembly Presets window is given, its values and the
;;                  presets it gives back after each edit of wt:edits (in each drawing of
;;                  wt:setups); then whether each one was written
;;    <case>\User\  the files written (Remote>>Dyl:PresetWrite, Remote>>Dyl:GroupsWriteOf,
;;                  Dyl:AliasWrite), as they are on disk

;;  The tools, in the order they are read and written:
(setq wt:keys '("QuickShape" "QuickDrawAssembly" "QuickDraw" "Material" "HatchPreset"))

;;  A fix that leaves each row as it is (the fix of each tool comes with its tab):
(defun wt:id (r) r)
;;  The texts read as numbers (distof), the numbers written as texts (rtos) with each DIMZIN,
;;  and the units the assemblies are drawn in (the drawing units in a millimetre, see
;;  Dyl:QuickDrawAsmFactor):
(setq wt:nums    '("5" ".5" "5." "-1.5" "+2" "1,5" "" "a" " 5" "5 " "1e3" "1E-2" "1/2" "0" "-0"
                   "12.70" "007" "1.2.3" "--1" "e5" "5e" "1'" "15.9" "0.62598425" "1 1/2" "2'6\""
                  )
      wt:reals   (list 0.0 0.5 -0.5 1.0 2.5 10.0 0.125 2.675 1.005 15.9 0.62598425 -0.00001 123456.789
                       0.1 0.3 (* 15.9 (/ 0.001 0.0254)) (* 89.0 (/ 0.001 0.0254)) (/ 1.0 3.0) 1e-9
                       99.99999999 0.05 0.015 12.7 38.1 -0.004 0.0005 1e15
                 )
      wt:dimzins '(0 3 4 8 12)
      wt:factors (list (list "inch" (/ 0.001 0.0254)) (list "metre" (/ 0.001 1.0)))
)

;;  The value v of a number as the C# writes it (15 decimals, DIMZIN 0 set by the caller):
(defun wt:num (v) (if v (rtos v 2 15)))

;;  A cell: nil as (chr 30), T as "T", a string as it is:
(defun wt:cell (x)
  (cond
    ((null x) (chr 30))
    ((= x T) "T")
    ((= 'STR (type x)) x)
    ((vl-princ-to-string x))
  )
)

;;  A row, its cells divided by (chr 31); nil as (chr 30):
(defun wt:line (lst / s)
  (if lst
    (progn
      (setq s (wt:cell (car lst)))
      (foreach x (cdr lst) (setq s (strcat s (chr 31) (wt:cell x))))
      s
    )
    (chr 30)
  )
)

(defun wt:put (s) (setq wt:out (cons s wt:out)))
(defun wt:sec (name) (wt:put (strcat "#" name)))
(defun wt:rows (name rows)
  (wt:sec name)
  (foreach r rows (wt:put (wt:line r)))
)

;;  The lines put written to the file f (UTF-8), then forgotten:
(defun wt:write (f / des)
  (if (setq des (open f "w" "utf8"))
    (progn
      (foreach l (reverse wt:out) (write-line l des))
      (close des)
    )
  )
  (setq wt:out nil)
)

;;  A path relative to the folder of the case (wt:root):
(defun wt:rel (p)
  (if (and p (= (strcase (strcat wt:root "\\")) (strcase (substr p 1 (1+ (strlen wt:root))))))
    (substr p (+ 2 (strlen wt:root)))
    p
  )
)

;;  The folder from copied to the folder to, its sub-folders too:
(defun wt:copy (from to)
  (Dyl:UserMkdir to)
  (foreach f (vl-directory-files from nil 1)
    (vl-file-copy (strcat from "\\" f) (strcat to "\\" f))
  )
  (foreach d (vl-directory-files from nil -1)
    (if (not (member d '("." "..")))
      (wt:copy (strcat from "\\" d) (strcat to "\\" d))
    )
  )
)

;;  Info.txt:
(defun wt:info (core)
  (wt:sec "info")
  (wt:put (wt:line (list "sep" (cond ((vl-registry-read "HKEY_CURRENT_USER\\Control Panel\\International" "sList")) (",")))))
  (wt:put (wt:line (list "codepage" (getvar "SYSCODEPAGE"))))
  (wt:put (wt:line (list "acadver" (getvar "ACADVER"))))
  (wt:put (wt:line (list "core" core)))
  (wt:write (strcat wt:outdir "\\Info.txt"))
)

;;  Probes.txt:
(defun wt:probes ()
  (wt:sec "camel")
  (foreach p wt:names (wt:put (wt:line (list p (Remote>>Dyl:PresetCamel p)))))
  (wt:sec "strcase")
  (foreach p wt:names (wt:put (wt:line (list p (strcase p) (strcase p T)))))
  (wt:sec "less")
  (foreach a wt:names
    (foreach b wt:names (wt:put (wt:line (list a b (< a b)))))
  )
  (wt:rows "strlsort" (list (acad_strlsort wt:names)))
  (wt:rows "sort" (list (vl-sort wt:names '<)))
  (setvar "DIMZIN" 0)
  (wt:sec "distof")
  (foreach s wt:nums (wt:put (wt:line (list s (wt:num (distof s 2))))))
  (wt:sec "rtos")
  (foreach dz wt:dimzins
    (setvar "DIMZIN" dz)
    (foreach n '(0 2 4 8)
      (foreach v wt:reals
        (wt:put (wt:line (list (itoa dz) (itoa n) (rtos v 2 n) (Remote>>Dyl:MaterialNumP v n))))
      )
    )
  )
  (setvar "DIMZIN" wt:dimzin)
  (wt:write (strcat wt:outdir "\\Probes.txt"))
)

;;  The tool key of the case: what is read, the presets read kept in wt:reads for the writes:
(defun wt:preset (key / fle defs read)
  (setq fle (Remote>>Dyl:PresetFile key))
  (wt:put (strcat "#" key " file" (chr 31) (wt:cell (wt:rel fle))))
  (wt:rows (strcat key " head") (list (Remote>>Dyl:CsvHead fle)))
  (wt:rows (strcat key " csv") (Remote>>Dyl:PresetCsv key))
  (setq wt:defcache nil
        defs        (Remote>>Dyl:MaterialDefsOf key 'wt:id 'wt:defcache nil)
  )
  (wt:rows (strcat key " defs") defs)
  (wt:rows (strcat key " clean") (Remote>>Dyl:PresetClean key (Remote>>Dyl:PresetCsv key) nil))
  (setq *pst:readcache* nil
        read            (Remote>>Dyl:PresetRead key defs 'wt:id)
  )
  (wt:rows (strcat key " read") read)
  (wt:sec (strcat key " commands"))
  (foreach r read (wt:put (wt:cell (Remote>>Dyl:PresetCommand key (car r)))))
  (setq wt:reads (cons (cons key read) wt:reads))
)

;;  The assemblies of the case (Apps\Draw\Dyl-QuickDraw.lsp): the defaults, the assemblies
;;  read and fixed, then their layers in the units of each drawing of wt:factors (8 decimals,
;;  with DIMZIN 0 and 8) and back in millimetres (4 decimals):
(defun wt:assemblies (/ defs read sc)
  (setq *qd:asmdefs*    nil
        *qd:asmcache*   nil
        *pst:readcache* nil
        *mt:defcache*   nil
        *hp:defcache*   nil
        defs            (Dyl:QuickDrawAsmDefs)
        read            (Remote>>Dyl:PresetRead "QuickDrawAssembly" defs 'Dyl:QuickDrawAsmFix)
  )
  (wt:rows "assemblies defs" defs)
  (wt:rows "assemblies read" read)
  (foreach dz '(0 8)
    (setvar "DIMZIN" dz)
    (foreach f wt:factors
      (setq sc (mapcar '(lambda (r) (Dyl:QuickDrawAsmScale r (cadr f) 8)) read))
      (wt:rows (strcat "assemblies " (car f) " " (itoa dz)) (mapcar '(lambda (r) (list (car r) (nth 3 r))) sc))
      (wt:rows (strcat "assemblies " (car f) " " (itoa dz) " back")
               (mapcar '(lambda (r) (list (car r) (nth 3 (Dyl:QuickDrawAsmScale r (/ 1.0 (cadr f)) 4)))) sc)
      )
    )
  )
  (setvar "DIMZIN" wt:dimzin)
  (setq *qd:asmdefs* nil *qd:asmcache* nil *pst:readcache* nil *mt:defcache* nil *hp:defcache* nil)
)

;;  The hatch presets and the materials of the case (Remote\Dyl-Materials.lsp): whether its
;;  materials file is one of DynALisp 1.1 (split by the Lisp alone, never here), then with
;;  DIMZIN 0 and 4 the defaults fixed and both read, fixed and cleaned:
(defun wt:materials (/ old b)
  (setq *pst:readcache* nil
        *mt:defcache*   nil
        *hp:defcache*   nil
        *mt:oldstamp*   nil
        old             (Remote>>Dyl:MaterialOld-p)
  )
  (wt:put (strcat "#materials old" (chr 31) (wt:cell old)))
  (foreach dz '(0 4)
    (setvar "DIMZIN" dz)
    (setq *pst:readcache* nil *mt:defcache* nil *hp:defcache* nil)
    (wt:rows (strcat "materials hatch defs " (itoa dz)) (Remote>>Dyl:HatchPresetDefs))
    (wt:rows (strcat "materials defs " (itoa dz)) (Remote>>Dyl:MaterialRowDefs))
    (if (not old)
      (progn
        (setq b (Remote>>Dyl:MaterialBoth))
        (wt:rows (strcat "materials hatch read " (itoa dz)) (car b))
        (wt:rows (strcat "materials read " (itoa dz)) (cadr b))
      )
    )
  )
  (setvar "DIMZIN" wt:dimzin)
  (setq *pst:readcache* nil *mt:defcache* nil *hp:defcache* nil *mt:oldstamp* nil)
)

;;  The drawings what the Quick Draw window shows is made for: (name MEASUREMENT INSUNITS
;;  LUNITS LUPREC DIMZIN), set for a moment:
(setq wt:setups '(("metric" 1 4 2 4 0) ("imperial" 0 1 2 3 8)))

;;  The units of the pattern p (upper case) in the witness, as Remote>>Dyl:MaterialPatUnits
;;  gives them, never those of the .pat files of this computer (its folders): Metric for a name
;;  with ISO or starting with AR-, none for a name starting with NO, else Imperial:
(defun wt:pat (p)
  (cond
    ((wcmatch p "*ISO*,AR-*") (cons "Metric" (strcat "C:\\Pat\\" p ".pat")))
    ((wcmatch p "NO*") nil)
    ((cons "Imperial" "C:\\Pat\\acad.pat"))
  )
)

;;  A text with its newlines as (chr 29), so it holds on one line:
(defun wt:nl (x) (if (= 'STR (type x)) (vl-string-translate "\n" (chr 29) x) x))

;;  What the Quick Draw window shows of each assembly of the case (Dyl:QuickDrawAsmShow), read
;;  as the window reads them (pst:mats, qd:mrows), in each drawing of wt:setups, at the drawing
;;  scale 1:50 (its value written first: the scale list of the drawing may not have it); not
;;  for a materials file of DynALisp 1.1 (split by the Lisp alone):
(defun wt:shows (/ saved pst:mats qd:mrows)
  (setq saved (mapcar 'getvar '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC" "CANNOSCALE")))
  (vl-catch-all-apply 'setvar '("CANNOSCALE" "1:50"))
  (setvar "DIMZIN" 0)
  (wt:put (strcat "#shows scale" (chr 31) (wt:cell (wt:num (getvar "CANNOSCALEVALUE")))))
  (setq *mt:oldstamp* nil)
  (if (Remote>>Dyl:MaterialOld-p)
    (wt:sec "shows lisp")
    (foreach s wt:setups
      (mapcar 'setvar '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC" "DIMZIN") (cdr s))
      (setq *pst:readcache* nil
            *mt:defcache*   nil
            *hp:defcache*   nil
            *qd:asmdefs*    nil
            *qd:asmcache*   nil
            *mt:patunits*   nil
            pst:mats        (Remote>>Dyl:MaterialRead)
            qd:mrows        (cadr (Remote>>Dyl:MaterialBoth))
      )
      (foreach h (car (Remote>>Dyl:MaterialBoth))
        (setq *mt:patunits* (cons (cons (strcat (strcase (nth 3 h)) "|" (itoa (getvar "MEASUREMENT"))) (wt:pat (strcase (nth 3 h))))
                                  *mt:patunits*
                            )
        )
      )
      (wt:rows (strcat "shows " (car s))
               (mapcar '(lambda (a) (mapcar 'wt:nl (cons (car a) (Dyl:QuickDrawAsmShow a)))) (Dyl:QuickDrawAsmReadAll))
      )
    )
  )
  (mapcar '(lambda (v x) (vl-catch-all-apply 'setvar (list v x))) '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC" "CANNOSCALE") saved)
  (setvar "DIMZIN" wt:dimzin)
  (setq *pst:readcache* nil *mt:defcache* nil *hp:defcache* nil *qd:asmdefs* nil *qd:asmcache* nil *mt:patunits* nil *mt:oldstamp* nil)
)

;;  The strings of lst, each once, in the order they come (nil and "" left out):
(defun wt:uniq (lst / res)
  (foreach x lst
    (if (and (= 'STR (type x)) (/= "" x) (not (member x res))) (setq res (cons x res)))
  )
  (reverse res)
)

;;  What the Assembly Presets window is given (Apps\Draw\Dyl-QuickDraw.lsp), opened from no
;;  Quick Draw preset on the assemblies read, in each drawing of wt:setups: the materials of
;;  the Material list (each with the id of its material row, "" for none), the groups of its
;;  Group list and the layer keys the assemblies use (Dyl:QuickDrawAsmWinMats, each key once),
;;  the data of each material (Remote>>Dyl:MaterialDataLists), the layer key of new lines and
;;  the row Add starts from (Dyl:QuickDrawAsmWinPrep, the layer keys of the case: its
;;  LayerKeys.csv, else the defaults), then the columns the window adds to each assembly
;;  (Dyl:QuickDrawAsmExtra, newlines as (chr 29)); not for a materials file of DynALisp 1.1
;;  (split by the Lisp alone):
(defun wt:asmwin (/ saved pst:lst qa:r qa:mats qa:grps qa:def qa:bk mt:keys got data *lk:file* *lk:readcache*)
  (setq saved     (mapcar 'getvar '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC"))
        *lk:file* (strcat *dyl:dylres "\\LayerKeys.csv")
  )
  (setq *mt:oldstamp* nil)
  (if (Remote>>Dyl:MaterialOld-p)
    (wt:sec "asmwin lisp")
    (foreach s wt:setups
      (mapcar 'setvar '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC" "DIMZIN") (cdr s))
      (setq *pst:readcache* nil
            *mt:defcache*   nil
            *hp:defcache*   nil
            *qd:asmdefs*    nil
            *qd:asmcache*   nil
            pst:lst         (Remote>>Dyl:PresetRead "QuickDrawAssembly" (Dyl:QuickDrawAsmDefs) 'Dyl:QuickDrawAsmFix)
            got             (Dyl:QuickDrawAsmWinMats pst:lst)
            data            (Remote>>Dyl:MaterialDataLists (mapcar 'car (car got)) nil)
      )
      (wt:rows (strcat "asmwin mats " (car s))
               (mapcar '(lambda (m) (list (car m) (cadr m) (if (caddr m) (car (caddr m)) "") (cadddr m))) (car got))
      )
      (wt:rows (strcat "asmwin groups " (car s)) (mapcar 'list (cadr got)))
      (wt:rows (strcat "asmwin keys " (car s)) (mapcar 'list (wt:uniq (caddr got))))
      (wt:rows (strcat "asmwin data " (car s)) (mapcar 'list (mapcar 'car (car got)) (car data) (cadr data)))
      (Dyl:QuickDrawAsmWinPrep)
      (wt:put (strcat "#asmwin bk " (car s) (chr 31) qa:bk))
      (wt:rows (strcat "asmwin def " (car s)) (list qa:def))
      (wt:rows (strcat "asmwin rows " (car s))
               (mapcar '(lambda (a) (mapcar 'wt:nl (cons (car a) (Dyl:QuickDrawAsmExtra a)))) pst:lst)
      )
    )
  )
  (mapcar '(lambda (v x) (vl-catch-all-apply 'setvar (list v x))) '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC") saved)
  (setvar "DIMZIN" wt:dimzin)
  (setq *pst:readcache* nil *mt:defcache* nil *hp:defcache* nil *qd:asmdefs* nil *qd:asmcache* nil *mt:oldstamp* nil)
)

;;  The units of the patterns of the hatch presets of the case, those of wt:pat (never those of
;;  the .pat files of this computer), for the drawing of MEASUREMENT set (*mt:patunits*, see
;;  Remote>>Dyl:MaterialPatUnits):
(defun wt:patsset ()
  (foreach h (car (Remote>>Dyl:MaterialBoth))
    (setq *mt:patunits* (cons (cons (strcat (strcase (nth 3 h)) "|" (itoa (getvar "MEASUREMENT"))) (wt:pat (strcase (nth 3 h))))
                              *mt:patunits*
                        )
    )
  )
)

;;  A value v of a window ((key . value) as the Lisp gives it to Dyl:WinShow), on one line: the
;;  key, then S and its text, L and its items (nil: none), R and the cells of each of its rows
;;  (a line each), or N and the number of its rows for the tables of the presets and of their
;;  defaults (pst/rows, pst/defs: their rows are those of the sections assemblies read and
;;  asmwin rows):
(defun wt:val (v / x)
  (setq x (cdr v))
  (cond
    ((= 'STR (type x)) (wt:put (wt:line (list (car v) "S" (wt:nl x)))))
    ((and (listp (car x)) x (member (car v) '("pst/rows" "pst/defs")))
     (wt:put (wt:line (list (car v) "N" (itoa (length x)))))
    )
    ((and x (listp (car x)))
     (foreach r x (wt:put (wt:line (cons (car v) (cons "R" (mapcar 'wt:nl r))))))
    )
    ((wt:put (wt:line (cons (car v) (cons "L" (mapcar 'wt:nl x))))))
  )
)

;;  A row r with the cells of pairs ((i . value) ...):
(defun wt:cells (r pairs)
  (foreach p pairs (setq r (Remote>>Dyl:ListSubst r (car p) (cdr p))))
  r
)

;;  A row r with the cells of pairs given to its first layer (its column 15, the layers as rows
;;  of the window, see Dyl:QuickDrawAsmDecode); nil without layers:
(defun wt:layer (r pairs / ls)
  (if (setq ls (Dyl:QuickDrawAsmDecode (cond ((nth 15 r)) (""))))
    (Remote>>Dyl:ListSubst r 15 (Dyl:QuickDrawAsmEncode (cons (wt:cells (car ls) pairs) (cdr ls))))
  )
)

;;  The edits made in the window to the first rows sent (rs, 3 at most): (name . function),
;;  the rows given back by the window, nil when the edit cannot be made on them. Each value of
;;  the window that wget and rowcheck read: the name and the texts trimmed, the ratings, the
;;  thicknesses, the materials, the framing, the band settings, the border and the hatch of a
;;  layer, its flags, the Border lines and the Dividing lines, no layers, a preset added,
;;  deleted, moved:
(setq wt:edits
  '(("same" lambda (rs) rs)
    ("name" lambda (rs) (cons (wt:cells (car rs) '((2 . "Edited name") (8 . "  A description  ") (13 . " Family ") (14 . " Short "))) (cdr rs)))
    ("ratings" lambda (rs) (cons (wt:cells (car rs) '((9 . "60") (10 . "45x"))) (cdr rs)))
    ("sound" lambda (rs) (cons (wt:cells (car rs) '((9 . "") (10 . "90") (11 . "50") (12 . "4.5"))) (cdr rs)))
    ("ratingsok" lambda (rs) (cons (wt:cells (car rs) '((9 . " 45 ") (10 . "120") (11 . "0") (12 . "55"))) (cdr rs)))
    ("thick" lambda (rs / r) (if (setq r (wt:layer (car rs) '((2 . "12.5")))) (cons r (cdr rs))))
    ("thickfine" lambda (rs / r) (if (setq r (wt:layer (car rs) '((2 . "0.62598425")))) (cons r (cdr rs))))
    ("thickbad" lambda (rs / r) (if (setq r (wt:layer (car rs) '((2 . "0")))) (cons r (cdr rs))))
    ("thicktext" lambda (rs / r) (if (setq r (wt:layer (car rs) '((2 . "abc")))) (cons r (cdr rs))))
    ("nomat" lambda (rs / r) (if (setq r (wt:layer (car rs) '((1 . "")))) (cons r (cdr rs))))
    ("framing" lambda (rs / r) (if (setq r (wt:layer (car rs) '((44 . "mt-Void") (45 . " 23,5 ")))) (cons r (cdr rs))))
    ("framingbad" lambda (rs / r) (if (setq r (wt:layer (car rs) '((44 . "mt-Void") (45 . "100")))) (cons r (cdr rs))))
    ("band" lambda (rs / r) (if (setq r (wt:layer (car rs) '((5 . "1") (8 . "abc")))) (cons r (cdr rs))))
    ("bandangle" lambda (rs / r) (if (setq r (wt:layer (car rs) '((5 . "1") (9 . "85")))) (cons r (cdr rs))))
    ("bandmiter" lambda (rs / r) (if (setq r (wt:layer (car rs) '((5 . "1") (11 . "0.5")))) (cons r (cdr rs))))
    ("bandfactor" lambda (rs / r) (if (setq r (wt:layer (car rs) '((5 . "1") (38 . "1") (39 . "0")))) (cons r (cdr rs))))
    ("bandoffset" lambda (rs / r) (if (setq r (wt:layer (car rs) '((5 . "1") (40 . "1") (41 . "x")))) (cons r (cdr rs))))
    ("bandok" lambda (rs / r)
     (if (setq r (wt:layer (car rs) '((5 . "1") (6 . "Edge") (8 . "2") (9 . "30") (11 . "2") (38 . "1") (39 . "1.5") (40 . "1") (41 . "2") (42 . "-1"))))
       (cons r (cdr rs))
     )
    )
    ("bandoff" lambda (rs / r) (if (setq r (wt:layer (car rs) '((5 . "0") (6 . "Edge")))) (cons r (cdr rs))))
    ("border" lambda (rs / r) (if (setq r (wt:layer (car rs) '((14 . "1") (15 . "")))) (cons r (cdr rs))))
    ("borderok" lambda (rs / r)
     (if (setq r (wt:layer (car rs) '((14 . "1") (15 . "hatch") (19 . "1") (20 . "dashed") (21 . "1") (22 . "2"))))
       (cons r (cdr rs))
     )
    )
    ("borderbad" lambda (rs / r) (if (setq r (wt:layer (car rs) '((14 . "1") (15 . "HATCH") (17 . "1") (18 . "300")))) (cons r (cdr rs))))
    ("borderoff" lambda (rs / r) (if (setq r (wt:layer (car rs) '((14 . "0") (15 . "OTHERKEY")))) (cons r (cdr rs))))
    ("hatchbad" lambda (rs / r) (if (setq r (wt:layer (car rs) '((27 . "1") (36 . "1") (37 . "95")))) (cons r (cdr rs))))
    ("hatchkey" lambda (rs / r)
     (if (setq r (wt:layer (car rs) '((27 . "1") (28 . "1") (29 . "1,2,3") (30 . "1") (31 . "dashed") (32 . "1") (33 . "2"))))
       (cons r (cdr rs))
     )
    )
    ("hatchoff" lambda (rs / r) (if (setq r (wt:layer (car rs) '((27 . "0")))) (cons r (cdr rs))))
    ("flags" lambda (rs / r) (if (setq r (wt:layer (car rs) '((16 . "1") (46 . "1") (47 . "1")))) (cons r (cdr rs))))
    ("lines" lambda (rs) (cons (wt:cells (car rs) '((16 . "1") (17 . ""))) (cdr rs)))
    ("linesok" lambda (rs) (cons (wt:cells (car rs) '((16 . "1") (17 . "hatch") (20 . "1") (21 . "dashed") (28 . "1") (29 . "a"))) (cdr rs)))
    ("linesbad" lambda (rs) (cons (wt:cells (car rs) '((28 . "1") (29 . "A") (30 . "1") (31 . "abc"))) (cdr rs)))
    ("linesoff" lambda (rs) (cons (wt:cells (car rs) '((16 . "0") (17 . "") (28 . "0") (29 . ""))) (cdr rs)))
    ("nolayers" lambda (rs) (cons (wt:cells (car rs) '((15 . ""))) (cdr rs)))
    ("new" lambda (rs / r)
     (setq r (wt:cells (Remote>>Dyl:PresetWinRow (cdr (assoc 'new pst:dlg))) '((2 . "Added"))))
     (append rs (list (cond ((wt:layer r '((1 . "mt-Void") (2 . "25")))) (r))))
    )
    ("newempty" lambda (rs) (append rs (list (Remote>>Dyl:PresetWinRow (cdr (assoc 'new pst:dlg))))))
    ("delete" lambda (rs) (if (cdr rs) (cons (car rs) (cddr rs))))
    ("move" lambda (rs) (if (cdr rs) (cons (cadr rs) (cons (car rs) (cddr rs)))))
   )
)

;;  The Assembly Presets window as the preset engine shows it (Remote>>Dyl:PresetDialog on the
;;  spec Dyl:QuickDrawAsmDlg of Apps\Draw\Dyl-QuickDraw.lsp): its values (Remote>>Dyl:PresetWinVals,
;;  each one by wt:val), opened from no Quick Draw preset (manager), from a preset whose border
;;  is on the key WALL and whose assembly is the second one read (quickdraw: its preset shown
;;  and its row Add starts from only), and from a preset whose key and assembly no longer exist
;;  (unknown, the same); then, from no preset, each edit of wt:edits on the first rows sent:
;;  the rows given back (in), the presets got from them (Remote>>Dyl:PresetWinBack, given
;;  their ids: out) and why they are not valid (Remote>>Dyl:PresetWinCheck: check, nil when
;;  they are). In each drawing of wt:setups, at the drawing scale 1:50; not for a materials file
;;  of DynALisp 1.1 (split by the Lisp alone):
(defun wt:asmtab (/ saved *lk:file* *lk:readcache* *pst:rowcache* *pst:winsent* rs n e in msg)
  (setq saved     (mapcar 'getvar '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC" "CANNOSCALE"))
        *lk:file* (strcat *dyl:dylres "\\LayerKeys.csv")
  )
  (vl-catch-all-apply 'setvar '("CANNOSCALE" "1:50"))
  (setvar "DIMZIN" 0)
  (wt:put (strcat "#asmtab scale" (chr 31) (wt:cell (wt:num (getvar "CANNOSCALEVALUE")))))
  (wt:rows "asmtab layerkeys" (mapcar '(lambda (k) (list (car k))) (Remote>>Dyl:LayerKeyRead)))
  (setq *mt:oldstamp* nil)
  (if (Remote>>Dyl:MaterialOld-p)
    (wt:sec "asmtab lisp")
    (foreach s wt:setups
      (mapcar 'setvar '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC" "DIMZIN") (cdr s))
      (setq *pst:readcache* nil
            *mt:defcache*   nil
            *hp:defcache*   nil
            *qd:asmdefs*    nil
            *qd:asmcache*   nil
            *mt:patunits*   nil
            *pst:rowcache*  nil
      )
      (wt:patsset)
      ;;  (a window that stops is said, with the step it stopped at, and the others go on:)
      (foreach v (list (list "manager" nil nil) (list "quickdraw" "WALL" 1) (list "unknown" "NOSUCHKEY" "as-NoSuchAssembly"))
        (setq wt:at nil)
        (if (vl-catch-all-error-p (setq e (vl-catch-all-apply 'wt:asmtabof (list (car s) (car v) (cadr v) (caddr v)))))
          (wt:put (wt:line (list (strcat "#asmtab stopped " (car s) " " (car v)) wt:at (vl-catch-all-error-message e))))
        )
      )
    )
  )
  (mapcar '(lambda (v x) (vl-catch-all-apply 'setvar (list v x))) '("MEASUREMENT" "INSUNITS" "LUNITS" "LUPREC" "CANNOSCALE") saved)
  (setvar "DIMZIN" wt:dimzin)
  (setq *pst:readcache* nil *mt:defcache* nil *hp:defcache* nil *qd:asmdefs* nil *qd:asmcache* nil *mt:patunits* nil *mt:oldstamp* nil)
)

;;  The window of wt:asmtab in the drawing setup, opened as name: from no preset (bdr nil),
;;  else from a Quick Draw preset whose border is on the key bdr and whose assembly is asm (its
;;  id, or the index of a preset read):
(defun wt:asmtabof (setup name bdr asm / pst:key pst:dlg pst:lst pst:lst0 pst:idx pst:sel pst:als0 pst:als pst:grps
                    pst:gren pst:mats pst:smats pst:mgr pst:flt pst:srt pst:shw pst:sent pst:sentof pst:prep qa:qd qa:r
                    qa:mats qa:grps qa:def qa:bk mt:keys vals sel rs n in msg r
                   )
  (setq wt:at   "read"
        pst:key "QuickDrawAssembly"
        pst:lst (Remote>>Dyl:PresetRead pst:key (Dyl:QuickDrawAsmDefs) 'Dyl:QuickDrawAsmFix)
        wt:at   "spec"
  )
  ;;  (nth on nil fails in AutoCAD: a case without assemblies)
  (if bdr
    (progn
      (setq r (list ""))
      (repeat 64 (setq r (cons "" r)))
      (setq r    (Remote>>Dyl:ListSubst r *qd:border* bdr)
            qa:r (Remote>>Dyl:ListSubst r *qd:layerscol* (if (numberp asm) (cond ((car (if pst:lst (nth asm pst:lst)))) ((car (car pst:lst))) ("")) asm))
      )
    )
  )
  (setq wt:at    "dlg"
        pst:dlg  (Dyl:QuickDrawAsmDlg qa:r)
        pst:srt  "Name"
        pst:flt  ""
        pst:shw  ""
        sel      (cdr (assoc 'select pst:dlg))
        pst:idx  (max 0 (min (cond ((if sel (vl-position (assoc sel pst:lst) pst:lst))) (0)) (1- (length pst:lst))))
        pst:sel  (list pst:idx)
        pst:lst0 pst:lst
        pst:gren (length *grp:renames*)
  )
  (setq wt:at "prep")
  (Remote>>Dyl:PresetWinPrep)
  (setq wt:at "vals"
        vals  (Remote>>Dyl:PresetWinVals nil)
  )
  (wt:sec (strcat "asmtab vals " setup " " name))
  (foreach v vals
    (if (or (= "manager" name) (member (car v) '("pst.idx" "pst.sel" "ll/new")))
      (progn (setq wt:at (strcat "val " (vl-princ-to-string (car v)))) (wt:val v))
    )
  )
  (setq wt:at "sent")
  (if (= "manager" name)
    (progn
      (setq rs         (Remote>>LM:sublst pst:sent 0 3)
            pst:sent   rs
            pst:sentof (Remote>>LM:sublst pst:sentof 0 3)
            pst:lst0   pst:sentof
            n          (Remote>>Dyl:PresetWinCols)
      )
      (foreach e wt:edits
        ;;  (without rows sent, only the rows added: a row edited would be nil, see
        ;;  WitnessTests.Edits)
        (if (and (or rs (member (car e) '("new" "newempty")))
                 (progn (setq wt:at (strcat "edit " (car e))) (setq in (apply (cdr e) (list rs))))
            )
          (progn
            (setq wt:at   (strcat "edit " (car e) " back")
                  pst:lst (Remote>>Dyl:PresetWinBack in n)
                  wt:at   (strcat "edit " (car e) " check")
                  msg     (Remote>>Dyl:PresetWinCheck)
                  wt:at   (strcat "edit " (car e) " written")
            )
            (wt:rows (strcat "asmtab edit " setup " " (car e) " in") (mapcar '(lambda (x) (mapcar 'wt:nl x)) in))
            (wt:rows (strcat "asmtab edit " setup " " (car e) " out")
                     (mapcar '(lambda (x) (mapcar 'wt:nl x)) (Remote>>Dyl:PresetIds pst:lst))
            )
            (wt:put (strcat "#asmtab edit " setup " " (car e) " check" (chr 31) (wt:cell msg)))
          )
        )
      )
    )
  )
)

;;  The groups of the case, and the case of the names of the probes in them:
(defun wt:groups ()
  (wt:rows "groups preset" (mapcar 'list (Remote>>Dyl:GroupsOf nil)))
  (wt:rows "groups material" (mapcar 'list (Remote>>Dyl:GroupsOf "Material")))
  (wt:rows "groups defaults preset" (mapcar 'list (Remote>>Dyl:GroupsDefaultsOf nil)))
  (wt:rows "groups defaults material" (mapcar 'list (Remote>>Dyl:GroupsDefaultsOf "Material")))
  (wt:sec "groups case")
  (foreach g (append '("wall" "SECTION" "concrete" "INSULATION") wt:names)
    (wt:put (wt:line (list g (Remote>>Dyl:GroupCaseOf g nil) (Remote>>Dyl:GroupCaseOf g "Material"))))
  )
)

;;  The aliases of the case, and those of each command:
(defun wt:aliases (/ cmds)
  (setq wt:als (Dyl:AliasRead))
  (wt:rows "aliases read" (mapcar '(lambda (p) (list (car p) (cdr p))) wt:als))
  (foreach p wt:als (if (not (member (cdr p) cmds)) (setq cmds (cons (cdr p) cmds))))
  (wt:sec "aliases of")
  (foreach c (reverse cmds) (wt:put (wt:line (cons c (Dyl:AliasesOf c wt:als)))))
)

;;  The case name: its folder copied to the work folder, the Lisp pointed at it, everything
;;  read, then written, in this order:
(defun wt:case (name / root)
  (setq root    (strcat wt:work "\\" name)
        wt:root root
        wt:out  nil
        wt:reads nil
  )
  (wt:copy (strcat wt:in "\\" name) root)
  (Dyl:UserMkdir (strcat root "\\Contents\\Modules\\Dynalisp\\Res"))
  (Dyl:UserMkdir (strcat root "\\Contents\\Resources"))
  (setq *dyl:contents   (strcat root "\\Contents")
        *dyl:user       (strcat root "\\User")
        *dyl:dylres     (strcat root "\\Contents\\Modules\\Dynalisp\\Res")
        *dyl:res        (strcat root "\\Contents\\Resources")
        *dyl:alias      (strcat root "\\Contents\\Resources\\Aliases.csv")
        *pst:readcache* nil
        *grp:cache*     nil
  )
  (wt:put (strcat "#case" (chr 31) name))
  (foreach key wt:keys (wt:preset key))
  (wt:groups)
  (wt:aliases)
  (wt:assemblies)
  (wt:materials)
  (wt:shows)
  (wt:asmwin)
  (wt:asmtab)
  (foreach key wt:keys
    (wt:put (strcat "#" key " write" (chr 31) (wt:cell (Remote>>Dyl:PresetWrite key (cdr (assoc key wt:reads))))))
  )
  (wt:put (strcat "#groups write" (chr 31) (wt:cell (Remote>>Dyl:GroupsWriteOf (Remote>>Dyl:GroupsOf nil) nil))))
  (wt:put (strcat "#groups material write" (chr 31) (wt:cell (Remote>>Dyl:GroupsWriteOf (Remote>>Dyl:GroupsOf "Material") "Material"))))
  (wt:put (strcat "#aliases write" (chr 31) (wt:cell (Dyl:AliasWrite wt:als))))
  (Dyl:UserMkdir (strcat wt:outdir "\\" name))
  (if (vl-file-directory-p (strcat root "\\User"))
    (wt:copy (strcat root "\\User") (strcat wt:outdir "\\" name "\\User"))
  )
  (wt:write (strcat wt:outdir "\\" name "\\Witness.txt"))
)

;;  Every case, and the probes:
(defun wt:all (core)
  (Dyl:UserMkdir wt:outdir)
  (setq wt:names (mapcar 'car (Remote>>Dyl:CsvReadLisp (strcat wt:in "\\Probes.csv") 1)))
  (wt:info core)
  (wt:probes)
  (foreach c (vl-sort (vl-remove-if '(lambda (d) (member d '("." ".."))) (vl-directory-files wt:in nil -1)) '<)
    (wt:case c)
  )
)

;;  The witness folder zipped beside it (PowerShell). Returns the zip, nil when not made:
(defun wt:zip (/ sh zip)
  (setq zip (strcat wt:outdir ".zip"))
  (if (setq sh (vlax-create-object "WScript.Shell"))
    (progn
      (vl-catch-all-apply
        'vlax-invoke-method
        (list sh 'Run
              (strcat "powershell -NoProfile -Command \"Compress-Archive -Path '" wt:outdir "\\*' -DestinationPath '" zip "' -Force\"")
              0
              :vlax-true
        )
      )
      (vlax-release-object sh)
    )
  )
  (if (findfile zip) zip)
)

(defun wt:run (/ saved err zip)
  (vl-load-com)
  (setq wt:in     (strcat *dyl:repo "\\Installer\\Core\\Tests\\Witness\\In")
        wt:outdir (strcat (getenv "TEMP") "\\DynALisp Witness " (menucmd "M=$(edtime,$(getvar,date),YYYYMODD-HHMMSS)"))
        wt:work   (strcat wt:outdir " work")
        saved     (list *dyl:contents *dyl:user *dyl:dylres *dyl:res *dyl:alias Dyl:Data Dyl:DataHead Dyl:AsmDefs Dyl:AsmRead
                        Dyl:HatchDefs Dyl:MatDefs Dyl:MatBoth Dyl:AsmPats Dyl:AsmShows Dyl:AsmWinMats
                        Dyl:AsmRows Dyl:MatData
                  )
        wt:dimzin (getvar "DIMZIN")
  )
  ;;  (the assemblies are read by Quick Draw, loaded before the folders are pointed at a case;
  ;;  never while it is turned off in the Startup Suite:)
  (if (and (not Dyl:QuickDrawAsmFix) (Dyl:SuiteFileOn-p (Remote>>Dyl:PresetProp "QuickDraw" 'path)))
    (Dyl:SuiteFileLoad (Remote>>Dyl:PresetProp "QuickDraw" 'path))
  )
  (cond
    ((not (vl-file-directory-p wt:in))
     (princ (strcat "\nWitness: no folder " wt:in " (only a git clone of DynALisp has it)."))
    )
    ((not Dyl:QuickDrawAsmFix)
     (princ "\nWitness: Quick Draw is turned off in the Startup Suite (Dyl-Suite): turn it on, the assemblies are read through it.")
    )
    (T
      (setq Dyl:Data      nil
            Dyl:DataHead  nil
            Dyl:AsmDefs   nil
            Dyl:AsmRead   nil
            Dyl:HatchDefs nil
            Dyl:MatDefs   nil
            Dyl:MatBoth   nil
            Dyl:AsmPats   nil
            Dyl:AsmShows  nil
            Dyl:AsmWinMats nil
            Dyl:AsmRows   nil
            Dyl:MatData   nil
            err           (vl-catch-all-apply 'wt:all (list (if (nth 5 saved) T)))
      )
      ;;  The folders and functions of DynALisp given back, the reads of the cases dropped:
      (setvar "DIMZIN" wt:dimzin)
      (setq *dyl:contents   (nth 0 saved)
            *dyl:user       (nth 1 saved)
            *dyl:dylres     (nth 2 saved)
            *dyl:res        (nth 3 saved)
            *dyl:alias      (nth 4 saved)
            Dyl:Data        (nth 5 saved)
            Dyl:DataHead    (nth 6 saved)
            Dyl:AsmDefs     (nth 7 saved)
            Dyl:AsmRead     (nth 8 saved)
            Dyl:HatchDefs   (nth 9 saved)
            Dyl:MatDefs     (nth 10 saved)
            Dyl:MatBoth     (nth 11 saved)
            Dyl:AsmPats     (nth 12 saved)
            Dyl:AsmShows    (nth 13 saved)
            Dyl:AsmWinMats  (nth 14 saved)
            Dyl:AsmRows     (nth 15 saved)
            Dyl:MatData     (nth 16 saved)
            *mt:patunits*   nil
            *pst:readcache* nil
            *grp:cache*     nil
            *mt:oldstamp*   nil
            *qd:asmdefs*    nil
            *qd:asmcache*   nil
            *mt:defcache*   nil
            *hp:defcache*   nil
            wt:reads        nil
            wt:als          nil
      )
      (cond
        ((vl-catch-all-error-p err)
         ;;  The lines of the case it stopped in, written all the same, so the section it
         ;;  stopped in is known:
         (if wt:out
           (progn
             (wt:put (wt:line (list "#stopped" (vl-catch-all-error-message err) wt:at)))
             (wt:write (strcat wt:outdir "\\Stopped " (vl-filename-base (cond (wt:root) ("case"))) ".txt"))
           )
         )
         (princ (strcat "\nWitness: stopped, " (vl-catch-all-error-message err) ". What was written is in " wt:outdir "."))
        )
        ((setq zip (wt:zip))
         (startapp "explorer" (strcat "/select,\"" zip "\""))
         (princ (strcat "\nWitness: written to " zip "."))
        )
        ((princ (strcat "\nWitness: written to " wt:outdir " (not zipped)."))
         (startapp "explorer" (strcat "\"" wt:outdir "\""))
        )
      )
    )
  )
  (princ)
)

(wt:run)
