;; CommandIndex - Builds a CSV index of the commands of a LISP library
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

;;; ==========================================================================
;;; CommandIndex.lsp
;;;
;;; Scans a LISP library folder and builds an index of every AutoCAD command
;;; (DEFUN C:xxx / DEFUN-Q C:xxx) it contains, then exports it to a CSV file.
;;;
;;; Expected folder structure (3 levels):
;;;   <Root>\                       - level 0 : root folder (*.lsp scanned)
;;;   <Root>\<Module>\              - level 1 : modules     (*.lsp scanned)
;;;   <Root>\<Module>\<Group>\      - level 2 : groups      (*.lsp scanned)
;;;   Deeper subfolders are ignored.
;;;
;;; Output (written to <Root>\CommandIndex.csv) :
;;;   Command ; File ; Module ; Group ; Line ; Duplicate ; Full path
;;;
;;; Parser notes:
;;;   - Line comments (;) and block comments (;| ... |;) are ignored.
;;;   - Text inside strings ("...") is ignored, including multi-line strings.
;;;   - "(defun" and "c:name" may be separated by spaces, tabs or line breaks.
;;;   - Commands are reported in upper case (AutoCAD commands are
;;;     case-insensitive).
;;;   - CommandIndex.lsp itself is skipped, so CMDINDEX is never listed.
;;;
;;; Core file of the bundle: kept in the Resources folder next to
;;; dynalisp.mnl, which loads it at startup (Dyl:load) and on Dyl-Reload.
;;; It is not in a module Apps folder, so it is not listed in the
;;; StartupSuite either.
;;;
;;; Command:
;;;   CMDINDEX   - select the root folder and generate the CSV index
;;; ==========================================================================

(vl-load-com)


;;; ==========================================================================
;;; SECTION 1 - SETTINGS
;;; Global constants. Change these values to adapt the output.
;;; ==========================================================================

(setq *cmdx:output-name* "CommandIndex.csv")   ; CSV file name (in root)
(setq *cmdx:self-name* "CommandIndex.lsp")     ; this file, never indexed
(setq *cmdx:delimiter* ";")                  ; ";" suits French Excel
(setq *cmdx:fh* nil)                  ; currently open file handle
(setq *cmdx:file-count* 0)                    ; number of .lsp files read


;;; ==========================================================================
;;; SECTION 2 - STRING AND PATH UTILITIES
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; cmdx:path-join
;;;   Joins a folder path and a file or folder name with a single backslash.
;;;   Arguments : folder - parent folder path (with or without trailing "\")
;;;               name   - file or folder name
;;;   Returns   : full path string
;;; --------------------------------------------------------------------------
(defun cmdx:path-join (folder name) 
  (strcat (vl-string-right-trim "\\/" folder) "\\" name)
)

;;; --------------------------------------------------------------------------
;;; cmdx:string-replace-all
;;;   Replaces every occurrence of a substring (vl-string-subst only
;;;   replaces the first one).
;;;   Arguments : str - source string
;;;               old - substring to find
;;;               new - replacement substring
;;;   Returns   : the modified string
;;; --------------------------------------------------------------------------
(defun cmdx:string-replace-all (str old new / pos) 
  (setq pos 0)
  (while (setq pos (vl-string-search old str pos)) 
    (setq str (strcat (substr str 1 pos) 
                      new
                      (substr str (+ pos 1 (strlen old)))
              )
          pos (+ pos (strlen new))
    )
  )
  str
)

;;; --------------------------------------------------------------------------
;;; cmdx:csv-field
;;;   Formats a value as a quoted CSV field. Inner double quotes are doubled
;;;   so that delimiters or quotes in names never break the columns.
;;;   Arguments : value - string or integer
;;;   Returns   : quoted string, e.g.  "My ""file"".lsp"
;;; --------------------------------------------------------------------------
(defun cmdx:csv-field (value) 
  (if (numberp value) (setq value (itoa value)))
  (strcat "\"" (cmdx:string-replace-all value "\"" "\"\"") "\"")
)

;;; --------------------------------------------------------------------------
;;; cmdx:csv-line
;;;   Builds one CSV line from a list of values.
;;;   Arguments : values - list of strings / integers
;;;   Returns   : the delimited line (without line break)
;;; --------------------------------------------------------------------------
(defun cmdx:csv-line (values / line) 
  (setq line (cmdx:csv-field (car values)))
  (foreach v (cdr values) 
    (setq line (strcat line *cmdx:delimiter* (cmdx:csv-field v)))
  )
  line
)


;;; ==========================================================================
;;; SECTION 3 - FILE SYSTEM ACCESS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; cmdx:browse-folder
;;;   Opens the Windows "Browse for folder" dialog.
;;;   Arguments : title - text displayed in the dialog
;;;   Returns   : selected folder path, or nil if cancelled / not a real
;;;               file system folder
;;; --------------------------------------------------------------------------
(defun cmdx:browse-folder (title / shell folder self path) 
  (setq shell  (vla-GetInterfaceObject (vlax-get-acad-object) "Shell.Application")
        folder (vl-catch-all-apply 'vlax-invoke-method 
                                   (list shell 'BrowseForFolder 0 title 0)
               )
  )
  (if (and folder (not (vl-catch-all-error-p folder))) 
    (progn 
      (setq self (vlax-get-property folder 'Self)
            path (vlax-get-property self 'Path)
      )
      (vlax-release-object self)
      (vlax-release-object folder)
    )
  )
  (vlax-release-object shell)
  ;; Virtual folders (e.g. "This PC") return a GUID instead of a real path
  (if (and path (vl-file-directory-p path)) path)
)

;;; --------------------------------------------------------------------------
;;; cmdx:list-subfolders
;;;   Lists the immediate subfolders of a folder, sorted alphabetically.
;;;   Arguments : folder - folder path
;;;   Returns   : list of subfolder names (not full paths)
;;; --------------------------------------------------------------------------
(defun cmdx:list-subfolders (folder) 
  (acad_strlsort 
    (vl-remove-if '(lambda (d) (member d '("." ".."))) 
                  (vl-directory-files folder nil -1)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; cmdx:list-lsp-files
;;;   Lists the .lsp files directly inside a folder, sorted alphabetically.
;;;   CommandIndex.lsp itself is left out so CMDINDEX never lists itself.
;;;   Arguments : folder - folder path
;;;   Returns   : list of file names (not full paths)
;;; --------------------------------------------------------------------------
(defun cmdx:list-lsp-files (folder)
  (acad_strlsort
    (vl-remove-if '(lambda (f) (= (strcase f) (strcase *cmdx:self-name*)))
                  (vl-directory-files folder "*.lsp" 1)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; cmdx:close-handle
;;;   Closes the file currently open by this program, if any.
;;;   Called after normal use and by the error handler.
;;; --------------------------------------------------------------------------
(defun cmdx:close-handle () 
  (if *cmdx:fh* 
    (progn 
      (vl-catch-all-apply 'close (list *cmdx:fh*))
      (setq *cmdx:fh* nil)
    )
  )
)


;;; ==========================================================================
;;; SECTION 4 - LISP SOURCE PARSER
;;;
;;; A small character-level tokenizer reads each line and keeps track of
;;; strings and comments. Every "word" found outside strings and comments
;;; is passed to cmdx:flush-token, which detects the sequence:
;;;     "("  ->  DEFUN | DEFUN-Q  ->  C:<name>
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; cmdx:flush-token
;;;   Ends the token being accumulated and updates the detection state.
;;;   IMPORTANT : works on the parser state variables declared as locals in
;;;   cmdx:parse-file (token, line-no, prev-paren, expect-name, found).
;;;   AutoLISP dynamic scoping gives this function access to them.
;;; --------------------------------------------------------------------------
(defun cmdx:flush-token (/ word) 
  (if token 
    (progn 
      (setq word  (strcase (vl-list->string (reverse token)))
            token nil
      )
      (cond 
        ;; Previous token was DEFUN : is this one a C: command name?
        (expect-name
         (if (and (> (strlen word) 2) (= (substr word 1 2) "C:")) 
           (setq found (cons (list (substr word 3) line-no) found))
         )
         (setq expect-name nil)
        )
        ;; "(" followed by DEFUN or DEFUN-Q : the next token is the name
        ((and prev-paren (member word '("DEFUN" "DEFUN-Q")))
         (setq expect-name T)
        )
      )
      (setq prev-paren nil)
    )
  )
)

;;; --------------------------------------------------------------------------
;;; cmdx:parse-file
;;;   Reads a .lsp file and returns the commands it defines.
;;;   Arguments : path - full path of the .lsp file
;;;   Returns   : list of (COMMAND-NAME LINE-NUMBER), in file order,
;;;               or nil if the file has no command or cannot be opened
;;; --------------------------------------------------------------------------
(defun cmdx:parse-file (path / line chars ch nxt step in-string in-block escape token line-no prev-paren expect-name 
                        found
                       ) 

  ;; --- Initialize the parser state ---------------------------------------
  (setq line-no   0
        *cmdx:fh* (open path "r")
  )

  (if (null *cmdx:fh*) 
    (princ (strcat "\n  Warning: cannot open " path))
    (progn 

      ;; --- Read the file line by line --------------------------------------
      (while (setq line (read-line *cmdx:fh*)) 
        (setq line-no (1+ line-no)
              chars   (vl-string->list line)
              escape  nil
        )

        ;; --- Scan each character of the line -------------------------------
        (while chars 
          (setq ch   (car chars)
                nxt  (cadr chars)
                step 1
          )
          (cond 
            ;; Inside a block comment : wait for "|;"
            (in-block
             (if (and (= ch 124) (= nxt 59)) 
               (setq in-block nil
                     step     2
               )
             )
            )
            ;; Inside a string : handle escapes, wait for closing quote
            (in-string
             (cond 
               (escape (setq escape nil))
               ((= ch 92) (setq escape T)) ; backslash
               ((= ch 34) (setq in-string nil)) ; closing "
             )
            )
            ;; ";|" opens a block comment, ";" comments the rest of the line
            ((= ch 59)
             (cmdx:flush-token)
             (if (= nxt 124) 
               (setq in-block T
                     step     2
               )
               (setq step (length chars))
             )
            )
            ;; Opening double quote
            ((= ch 34)
             (cmdx:flush-token)
             (setq in-string   T
                   prev-paren  nil
                   expect-name nil
             )
            )
            ;; Opening parenthesis
            ((= ch 40)
             (cmdx:flush-token)
             (setq prev-paren  T
                   expect-name nil
             )
            )
            ;; Closing parenthesis
            ((= ch 41)
             (cmdx:flush-token)
             (setq prev-paren  nil
                   expect-name nil
             )
            )
            ;; Separators : space, tab, CR, quote, backquote, comma
            ((member ch '(32 9 13 39 96 44))
             (cmdx:flush-token)
            )
            ;; Any other character belongs to the current token
            (T (setq token (cons ch token)))
          )
          (repeat step (setq chars (cdr chars)))
        )

        ;; --- End of line also ends the current token -----------------------
        (if (not in-string) (cmdx:flush-token))
      )

      (cmdx:close-handle)
      (setq *cmdx:file-count* (1+ *cmdx:file-count*))
    )
  )
  (reverse found)
)


;;; ==========================================================================
;;; SECTION 5 - FOLDER SCANNING
;;;
;;; Record format used by the rest of the program:
;;;   (COMMAND FILE MODULE GROUP LINE FULL-PATH)
;;;    nth 0   nth 1 nth 2  nth 3 nth 4 nth 5
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; cmdx:scan-folder
;;;   Parses every .lsp file directly inside one folder.
;;;   Arguments : folder - folder path
;;;               module - module name to record ("" for the root)
;;;               group  - group name to record  ("" if not in a group)
;;;   Returns   : list of records
;;; --------------------------------------------------------------------------
(defun cmdx:scan-folder (folder module group / records full-path) 
  (foreach file (cmdx:list-lsp-files folder) 
    (setq full-path (cmdx:path-join folder file))
    (foreach cmd (cmdx:parse-file full-path) 
      (setq records (cons (list (car cmd) file module group (cadr cmd) full-path) 
                          records
                    )
      )
    )
  )
  (reverse records)
)

;;; --------------------------------------------------------------------------
;;; cmdx:scan-tree
;;;   Walks the 3-level structure : Root -> Modules -> Groups.
;;;   Arguments : root - root folder path
;;;   Returns   : list of records for the whole tree
;;; --------------------------------------------------------------------------
(defun cmdx:scan-tree (root / records module-path group-path) 

  ;; --- Level 0 : files in the root folder -------------------------------
  (setq records (cmdx:scan-folder root "" ""))

  ;; --- Level 1 : Modules ------------------------------------------------
  (foreach module (cmdx:list-subfolders root) 
    (setq module-path (cmdx:path-join root module))
    (princ (strcat "\n  Module: " module))
    (setq records (append records (cmdx:scan-folder module-path module "")))

    ;; --- Level 2 : Groups inside the module -----------------------------
    (foreach group (cmdx:list-subfolders module-path) 
      (setq group-path (cmdx:path-join module-path group))
      (setq records (append records (cmdx:scan-folder group-path module group)))
    )
  )
  records
)


;;; ==========================================================================
;;; SECTION 6 - POST-PROCESSING
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; cmdx:sort-records
;;;   Sorts records by Module, Group, File, then Command (case-insensitive).
;;;   Arguments : records - list of records
;;;   Returns   : sorted list
;;; --------------------------------------------------------------------------
(defun cmdx:sort-records (records) 
  (vl-sort records 
           '(lambda (a b) 
              (< (strcase (strcat (nth 2 a) "\t" (nth 3 a) "\t" (nth 1 a) "\t" (nth 0 a))) 
                 (strcase (strcat (nth 2 b) "\t" (nth 3 b) "\t" (nth 1 b) "\t" (nth 0 b)))
              )
            )
  )
)

;;; --------------------------------------------------------------------------
;;; cmdx:count-commands
;;;   Counts how many times each command name is defined. A command defined
;;;   more than once will silently override the other when loaded.
;;;   Arguments : records - list of records
;;;   Returns   : association list ((COMMAND . count) ...)
;;; --------------------------------------------------------------------------
(defun cmdx:count-commands (records / counts cell) 
  (foreach rec records 
    (if (setq cell (assoc (car rec) counts)) 
      (setq counts (subst (cons (car rec) (1+ (cdr cell))) cell counts))
      (setq counts (cons (cons (car rec) 1) counts))
    )
  )
  counts
)


;;; ==========================================================================
;;; SECTION 7 - CSV OUTPUT
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; cmdx:write-csv
;;;   Writes the command index to a CSV file.
;;;   Arguments : csv-path - output file path
;;;               records  - sorted list of records
;;;               counts   - result of cmdx:count-commands
;;;   Returns   : T on success, nil if the file cannot be written
;;;               (e.g. already open in Excel)
;;; --------------------------------------------------------------------------
(defun cmdx:write-csv (csv-path records counts / duplicate) 
  (setq *cmdx:fh* (open csv-path "w"))
  (if *cmdx:fh* 
    (progn 
      ;; --- Header ----------------------------------------------------------
      (write-line 
        (cmdx:csv-line '("Command" "File" "Module" "Group" "Line" "Duplicate" "Full path"))
        *cmdx:fh*
      )

      ;; --- One line per command --------------------------------------------
      (foreach rec records 
        (setq duplicate (if (> (cdr (assoc (car rec) counts)) 1) "Yes" ""))
        (write-line 
          (cmdx:csv-line 
            (list (nth 0 rec) 
                  (nth 1 rec)
                  (nth 2 rec)
                  (nth 3 rec)
                  (nth 4 rec)
                  duplicate
                  (nth 5 rec)
            )
          )
          *cmdx:fh*
        )
      )
      (cmdx:close-handle)
      T
    )
  )
)


;;; ==========================================================================
;;; SECTION 8 - MAIN COMMAND
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; C:CMDINDEX
;;;   1. Asks for the root folder
;;;   2. Scans Root / Modules / Groups for C: commands
;;;   3. Writes <Root>\CommandIndex.csv and prints a summary
;;; --------------------------------------------------------------------------

;; Command Index
;; Scans a root Lisp folder for C: commands and writes them to CommandIndex.csv with a summary.

(defun C:CMDINDEX (/ *error* root records counts csv-path dup-names) 

  ;; --- Local error handler : always release the open file ---------------
  (defun *error* (msg) 
    (cmdx:close-handle)
    (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*"))) 
      (princ (strcat "\nCMDINDEX error: " msg))
    )
    (princ)
  )

  ;; --- Step 1 : select the root folder -----------------------------------
  (setq root (cmdx:browse-folder "Select the root LISP folder"))

  (cond 
    ((null root)
     (princ "\nCMDINDEX: no valid folder selected.")
    )
    (T
     ;; --- Step 2 : scan the folder tree ---------------------------------
     (setq *cmdx:file-count* 0)
     (princ (strcat "\nScanning " root " ..."))
     (setq records (cmdx:sort-records (cmdx:scan-tree root)))

     (if (null records) 
       (princ 
         (strcat "\nCMDINDEX: no command found in " 
                 (itoa *cmdx:file-count*)
                 " file(s)."
         )
       )
       (progn 
         ;; --- Step 3 : detect duplicates and write the CSV --------------
         (setq counts   (cmdx:count-commands records)
               csv-path (cmdx:path-join root *cmdx:output-name*)
         )
         (foreach c counts 
           (if (> (cdr c) 1) (setq dup-names (cons (car c) dup-names)))
         )

         (if (cmdx:write-csv csv-path records counts) 
           (progn 
             ;; --- Step 4 : summary --------------------------------------
             (princ 
               (strcat "\nCMDINDEX: " 
                       (itoa (length records))
                       " command(s) found in "
                       (itoa *cmdx:file-count*)
                       " file(s)."
               )
             )
             (if dup-names 
               (princ 
                 (strcat "\n  Warning: " 
                         (itoa (length dup-names))
                         " command(s) defined more than once (see \"Duplicate\" column)."
                 )
               )
             )
             (princ (strcat "\n  Index written to: " csv-path))
           )
           (princ 
             (strcat "\nCMDINDEX: cannot write " 
                     csv-path
                     " (file open in another program?)"
             )
           )
         )
       )
     )
    )
  )
  (princ)
)


;;; Loaded silently by dynalisp.mnl, which prints the CMDINDEX hint itself.
(princ)
