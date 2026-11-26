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
;;  In AutoCAD, with DynALisp loaded, paste on the command line:
;;
;;    (load (strcat *dyl:repo "\\Installer\\Core\\Tests\\Witness\\Witness.lsp"))
;;
;;  It writes %TEMP%\DynALisp Witness <date>.zip and shows it in the Explorer: that zip, its
;;  files put in Installer\Core\Tests\Witness\Lisp, is the witness. Nothing of the drawing, the
;;  settings or the files of DynALisp is read or changed: each case is a copy of its folder in
;;  %TEMP%, the Lisp pointed at it for a moment (*dyl:contents, *dyl:user, *dyl:dylres,
;;  *dyl:res, *dyl:alias) and given back its own folders after, the reads kept dropped. The
;;  files are read by the Lisp itself (Dyl:Data and Dyl:DataHead of the Core hidden meanwhile),
;;  so the C# is compared with the Lisp, never with itself.
;;
;;  What is written, each line its cells divided by (chr 31), nil as (chr 30), a section by a
;;  line #name (UTF-8):
;;    Info.txt      the list separator of Windows, the code page, the version of AutoCAD
;;    Probes.txt    the functions of AutoLISP on the names of In\Probes.csv: the CamelCase of
;;                  the presets, strcase, <, acad_strlsort, vl-sort
;;    <case>\Witness.txt   for each preset tool: its file, header, rows, defaults, rows
;;                  cleaned, presets read and their commands; the groups and their case; the
;;                  aliases; then whether each one was written
;;    <case>\User\  the files written (Remote>>Dyl:PresetWrite, Remote>>Dyl:GroupsWriteOf,
;;                  Dyl:AliasWrite), as they are on disk

;;  The tools, in the order they are read and written:
(setq wt:keys '("QuickShape" "QuickDrawAssembly" "QuickDraw" "Material" "HatchPreset"))

;;  A fix that leaves each row as it is (the fix of each tool comes with its tab):
(defun wt:id (r) r)

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
        saved     (list *dyl:contents *dyl:user *dyl:dylres *dyl:res *dyl:alias Dyl:Data Dyl:DataHead)
  )
  (if (not (vl-file-directory-p wt:in))
    (princ (strcat "\nWitness: no folder " wt:in "."))
    (progn
      (setq Dyl:Data     nil
            Dyl:DataHead nil
            err          (vl-catch-all-apply 'wt:all (list (if (nth 5 saved) T)))
      )
      ;;  The folders and functions of DynALisp given back, the reads of the cases dropped:
      (setq *dyl:contents   (nth 0 saved)
            *dyl:user       (nth 1 saved)
            *dyl:dylres     (nth 2 saved)
            *dyl:res        (nth 3 saved)
            *dyl:alias      (nth 4 saved)
            Dyl:Data        (nth 5 saved)
            Dyl:DataHead    (nth 6 saved)
            *pst:readcache* nil
            *grp:cache*     nil
            *mt:oldstamp*   nil
            wt:reads        nil
            wt:als          nil
      )
      (cond
        ((vl-catch-all-error-p err)
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
