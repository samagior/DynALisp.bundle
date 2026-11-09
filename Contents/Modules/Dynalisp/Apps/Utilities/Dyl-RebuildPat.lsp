;;; ==========================================================================
;;; Dyl-RebuildPat.lsp
;;;
;;; Rebuilds missing hatch pattern files (.pat) from the pattern data stored
;;; inside the hatches of the current drawing, and saves them in a folder of
;;; the support file search path so they can be reused and edited.
;;;
;;; How it works:
;;;   Every hatch keeps a copy of its pattern definition (DXF codes 53, 43,
;;;   44, 45, 46, 79, 49). Those values are already transformed by the hatch
;;;   scale, angle and origin. This routine reverses that transformation to
;;;   recover the original definition (scale 1.0, angle 0) and writes it in
;;;   the standard .pat format: one pattern per file, file name = pattern name.
;;;
;;; Scope:
;;;   - Selected hatches only, or (Enter at the prompt) every hatch in
;;;     model space, all layouts and all block definitions.
;;;   - External references (xrefs) and xref-dependent blocks are ignored.
;;;   - Solid fills, gradients and user-defined hatches are ignored
;;;     (they do not rely on a .pat file).
;;;   - A pattern is "missing" when no <name>.pat is found and the name is
;;;     absent from acad.pat and acadiso.pat. Missing patterns are always
;;;     rebuilt in the target folder.
;;;   - Existing patterns:
;;;       * Selection mode : the user chooses Replace, Rename or Cancel
;;;                          (Replace is not offered for a pattern stored
;;;                          inside acad.pat / acadiso.pat).
;;;       * Whole drawing  : left untouched, no prompt.
;;;
;;; Commands:
;;;   Dyl-RebuildPat - rebuilds the missing .pat files
;;;   RPAT           - alias of Dyl-RebuildPat
;;;   OPENPATS       - opens the pattern folder in Windows Explorer (child Pst-OpenPats)
;;;
;;; Target folder (found automatically, nothing hard coded):
;;;   1. A folder named "pats" already listed in the support file search
;;;      path (e.g. the one AutoCAD Architecture installs by default).
;;;   2. Otherwise <ROAMABLEROOTPREFIX>\Support\pats, which resolves to the
;;;      roaming folder of the running product, release and language
;;;      (AutoCAD, ACA, etc.). It is created if needed.
;;;
;;; Notes:
;;;   - The drawing itself is not modified.
;;;   - If the target folder is not in the support file search path, it is
;;;     added to the current profile.
;;; ==========================================================================

(vl-load-com)


;;; ==========================================================================
;;; SECTION 1 - CONFIGURATION
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; Global settings
;;;   rpat:*target-folder* : forced folder for the rebuilt .pat files.
;;;                          nil = automatic detection (see header).
;;;   rpat:*subfolder*     : name of the pattern folder to look for in the
;;;                          support path, or to create under Support.
;;;   rpat:*precision*     : number of decimals written for each value.
;;;   rpat:*fuzz*          : tolerance used to snap near-zero values to 0.
;;; --------------------------------------------------------------------------
(setq rpat:*target-folder* nil
      rpat:*subfolder*     "pats"
      rpat:*precision*     8
      rpat:*fuzz*          1e-9
)


;;; ==========================================================================
;;; SECTION 2 - GENERIC UTILITIES
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; rpat:split
;;;   Splits a string on a delimiter.
;;;   Arguments : str   - string to split
;;;               delim - delimiter string
;;;   Returns   : list of substrings
;;; --------------------------------------------------------------------------
(defun rpat:split (str delim / pos result) 
  (while (setq pos (vl-string-search delim str)) 
    (setq result (cons (substr str 1 pos) result)
          str    (substr str (+ pos 1 (strlen delim)))
    )
  )
  (reverse (cons str result))
)

;;; --------------------------------------------------------------------------
;;; rpat:join
;;;   Joins a list of strings with a delimiter.
;;;   Arguments : items - list of strings
;;;               delim - delimiter string
;;;   Returns   : single string
;;; --------------------------------------------------------------------------
(defun rpat:join (items delim / result) 
  (setq result (car items))
  (foreach item (cdr items) 
    (setq result (strcat result delim item))
  )
  result
)

;;; --------------------------------------------------------------------------
;;; rpat:num->str
;;;   Converts a real to a compact decimal string for the .pat file:
;;;   near-zero values become "0", trailing zeros are removed.
;;;   Requires DIMZIN = 0 (set by the main command).
;;;   Arguments : value - real number
;;;   Returns   : string
;;; --------------------------------------------------------------------------
(defun rpat:num->str (value / str) 
  (if (equal value 0.0 rpat:*fuzz*) (setq value 0.0))
  (setq str (rtos value 2 rpat:*precision*))
  (if (vl-string-search "." str) 
    (setq str (vl-string-right-trim "." (vl-string-right-trim "0" str)))
  )
  (if (= str "-0") (setq str "0"))
  str
)

;;; --------------------------------------------------------------------------
;;; rpat:deg->rad / rpat:rad->deg
;;;   Angle unit conversions.
;;; --------------------------------------------------------------------------
(defun rpat:deg->rad (deg) (* pi (/ deg 180.0)))
(defun rpat:rad->deg (rad) (* 180.0 (/ rad pi)))

;;; --------------------------------------------------------------------------
;;; rpat:normalize-angle
;;;   Brings an angle in degrees into the range [0, 360).
;;;   Arguments : deg - angle in degrees
;;;   Returns   : normalized angle in degrees
;;; --------------------------------------------------------------------------
(defun rpat:normalize-angle (deg) 
  (setq deg (rem deg 360.0))
  (if (< deg 0.0) (setq deg (+ deg 360.0)))
  (if (equal deg 360.0 1e-6) (setq deg 0.0))
  deg
)

;;; --------------------------------------------------------------------------
;;; rpat:rotate-2d
;;;   Rotates a 2D vector around the origin.
;;;   Arguments : x, y - vector components
;;;               ang  - rotation angle in radians (counterclockwise)
;;;   Returns   : list (x' y')
;;; --------------------------------------------------------------------------
(defun rpat:rotate-2d (x y ang / c s) 
  (setq c (cos ang)
        s (sin ang)
  )
  (list (- (* x c) (* y s)) 
        (+ (* x s) (* y c))
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:next-group
;;;   Moves a cursor forward in an entity data list to the next pair having
;;;   the requested DXF code. The pair under the cursor is considered
;;;   already consumed, so repeated codes (e.g. 49) are read one by one.
;;;   Arguments : code   - DXF group code to find
;;;               cursor - current position (a tail of the entget list)
;;;   Returns   : new cursor (tail starting at the found pair) or nil
;;; --------------------------------------------------------------------------
(defun rpat:next-group (code cursor / tail) 
  (setq tail (cdr cursor))
  (member (assoc code tail) tail)
)

;;; --------------------------------------------------------------------------
;;; rpat:today
;;;   Returns the current date formatted as YYYY-MM-DD.
;;; --------------------------------------------------------------------------
(defun rpat:today () 
  (menucmd "M=$(edtime,$(getvar,date),YYYY-MO-DD)")
)


;;; ==========================================================================
;;; SECTION 3 - FILES AND SUPPORT PATH
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; rpat:get-support-paths
;;;   Returns the support file search path of the current profile as a
;;;   list of folders (empty entries removed).
;;; --------------------------------------------------------------------------
(defun rpat:get-support-paths () 
  (vl-remove "" 
             (mapcar '(lambda (p) (vl-string-trim " " p)) 
                     (rpat:split 
                       (vla-get-SupportPath 
                         (vla-get-Files (vla-get-Preferences (vlax-get-acad-object)))
                       )
                       ";"
                     )
             )
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:find-support-subfolder
;;;   Looks in the support path for an existing folder whose last name
;;;   matches the given subfolder name (e.g. "...\Support\pats").
;;;   Arguments : subfolder - folder name to look for
;;;   Returns   : first matching folder path, or nil
;;; --------------------------------------------------------------------------
(defun rpat:find-support-subfolder (subfolder / pattern) 
  (setq pattern (strcat "*\\" (strcase subfolder)))
  (vl-some 
    '(lambda (p / clean) 
       (setq clean (vl-string-right-trim "\\/" p))
       (if 
         (and (wcmatch (strcase clean) pattern) 
              (vl-file-directory-p clean)
         )
         clean
       )
     )
    (rpat:get-support-paths)
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:get-target-folder
;;;   Returns the folder where .pat files are written, always ending with a
;;;   backslash. Resolution order:
;;;     1. rpat:*target-folder*, if set (manual override)
;;;     2. an existing "pats" folder already in the support path
;;;        (AutoCAD Architecture default)
;;;     3. <ROAMABLEROOTPREFIX>\Support\pats (plain AutoCAD and others);
;;;        ROAMABLEROOTPREFIX already points to the roaming folder of the
;;;        running product, release and language
;;; --------------------------------------------------------------------------
(defun rpat:get-target-folder (/ folder) 
  (setq folder (cond 
                 (rpat:*target-folder*)
                 ((rpat:find-support-subfolder rpat:*subfolder*))
                 (T
                  (strcat (vl-string-right-trim "\\" (getvar "ROAMABLEROOTPREFIX")) 
                          "\\Support\\"
                          rpat:*subfolder*
                  )
                 )
               )
  )
  (strcat (vl-string-right-trim "\\/" folder) "\\")
)

;;; --------------------------------------------------------------------------
;;; rpat:ensure-folder
;;;   Creates the folder, including any missing parent folders.
;;;   Arguments : folder - folder path
;;;   Returns   : T if the folder exists after the call, nil otherwise
;;; --------------------------------------------------------------------------
(defun rpat:ensure-folder (folder / clean parent pos) 
  (setq clean (vl-string-right-trim "\\" folder))
  (if (not (vl-file-directory-p clean)) 
    (progn 
      ;; Create the parent first (recursive), then this folder
      (if (setq pos (vl-string-position (ascii "\\") clean nil T)) 
        (progn 
          (setq parent (substr clean 1 pos))
          (if (wcmatch parent "*?*") (rpat:ensure-folder parent))
        )
      )
      (vl-mkdir clean)
    )
  )
  (vl-file-directory-p clean)
)

;;; --------------------------------------------------------------------------
;;; rpat:ensure-in-support-path
;;;   Adds the folder to the support file search path of the current
;;;   profile if it is not already listed.
;;;   Arguments : folder - folder path
;;;   Returns   : T if the folder was added, nil if already present
;;; --------------------------------------------------------------------------
(defun rpat:ensure-in-support-path (folder / files paths clean) 
  (setq files (vla-get-Files (vla-get-Preferences (vlax-get-acad-object)))
        paths (vla-get-SupportPath files)
        clean (vl-string-right-trim "\\" folder)
  )
  (if 
    (vl-some 
      '(lambda (p) (= (strcase clean) (strcase (vl-string-right-trim "\\" p))))
      (rpat:split paths ";")
    )
    nil
    (progn 
      (vla-put-SupportPath files (strcat paths ";" clean))
      T
    )
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:pattern-in-file-p
;;;   Checks whether a multi-pattern file (e.g. acad.pat) contains a pattern
;;;   header "*NAME," for the given name.
;;;   Arguments : name - pattern name
;;;               file - pattern file name, searched in the support path
;;;   Returns   : T if found, nil otherwise
;;; --------------------------------------------------------------------------
(defun rpat:pattern-in-file-p (name file / path fh line pos header found) 
  (if 
    (and (setq path (findfile file)) 
         (setq fh (open path "r"))
    )
    (progn 
      (while (and (not found) (setq line (read-line fh))) 
        (setq line (strcase (vl-string-trim " \t" line)))
        (if (wcmatch line "`**") 
          (progn 
            (setq pos    (vl-string-search "," line)
                  header (vl-string-trim " \t" (if pos (substr line 1 pos) line))
            )
            (if (= header (strcat "*" (strcase name))) 
              (setq found T)
            )
          )
        )
      )
      (close fh)
    )
  )
  found
)

;;; --------------------------------------------------------------------------
;;; rpat:find-existing-pat
;;;   Looks for an existing definition of a pattern name.
;;;   Arguments : name   - pattern name
;;;               folder - target folder (checked even if not yet in the
;;;                        support path)
;;;   Returns   : ("FILE" path)    a standalone <name>.pat file exists
;;;               ("LIBRARY" path) the name is defined in acad.pat or
;;;                                acadiso.pat
;;;               nil              the pattern is missing
;;; --------------------------------------------------------------------------
(defun rpat:find-existing-pat (name folder / path) 
  (cond 
    ((setq path (findfile (strcat name ".pat")))
     (list "FILE" path)
    )
    ((setq path (findfile (strcat folder name ".pat")))
     (list "FILE" path)
    )
    ((rpat:pattern-in-file-p name "acad.pat")
     (list "LIBRARY" (findfile "acad.pat"))
    )
    ((rpat:pattern-in-file-p name "acadiso.pat")
     (list "LIBRARY" (findfile "acadiso.pat"))
    )
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:line->string
;;;   Formats one normalized definition line as a .pat line:
;;;   angle, x-origin, y-origin, delta-x, delta-y [, dash-1, dash-2, ...]
;;;   Arguments : def-line - list (angle x y dx dy (dashes...))
;;;   Returns   : string
;;; --------------------------------------------------------------------------
(defun rpat:line->string (def-line) 
  (rpat:join 
    (mapcar 'rpat:num->str 
            (append 
              (list (nth 0 def-line) 
                    (nth 1 def-line)
                    (nth 2 def-line)
                    (nth 3 def-line)
                    (nth 4 def-line)
              )
              (nth 5 def-line)
            )
    )
    ","
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:write-pat-file
;;;   Writes a single-pattern .pat file.
;;;   Arguments : path      - full file path
;;;               name      - pattern name (must match the file name)
;;;               def-lines - list of normalized definition lines
;;;   Returns   : T on success, nil if the file could not be opened
;;; --------------------------------------------------------------------------
(defun rpat:write-pat-file (path name def-lines / fh) 
  (if (setq fh (open path "w")) 
    (progn 
      ;; Comment block
      (write-line (strcat ";; " name ".pat") fh)
      (write-line 
        (strcat ";; Rebuilt by Dyl-RebuildPat.lsp from drawing " 
                (getvar "DWGNAME")
                " on "
                (rpat:today)
        )
        fh
      )
      (write-line ";;" fh)
      ;; Pattern header and definition lines
      (write-line (strcat "*" name ", Rebuilt from " (getvar "DWGNAME")) fh)
      (foreach def-line def-lines 
        (write-line (rpat:line->string def-line) fh)
      )
      ;; A .pat file must end with a line break after the last line
      (write-line "" fh)
      (close fh)
      T
    )
  )
)


;;; ==========================================================================
;;; SECTION 4 - HATCH DATA EXTRACTION
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; rpat:collect-hatches
;;;   Collects all hatch objects from model space, layouts and block
;;;   definitions, excluding xrefs and xref-dependent blocks.
;;;   Arguments : doc - active document (VLA object)
;;;   Returns   : list of hatch VLA objects
;;; --------------------------------------------------------------------------
(defun rpat:collect-hatches (doc / result) 
  (vlax-for blk (vla-get-Blocks doc) 
    (if 
      (and (= (vla-get-IsXref blk) :vlax-false) 
           (not (wcmatch (vla-get-Name blk) "*|*"))
      )
      (vlax-for obj blk 
        (if (= (vla-get-ObjectName obj) "AcDbHatch") 
          (setq result (cons obj result))
        )
      )
    )
  )
  (reverse result)
)

;;; --------------------------------------------------------------------------
;;; rpat:select-hatches
;;;   Asks the user to select hatches. Only HATCH entities can be picked
;;;   (other objects in a window or crossing are filtered out).
;;;   Returns   : list of hatch VLA objects, or nil if the user pressed
;;;               Enter without selecting anything
;;; --------------------------------------------------------------------------
(defun rpat:select-hatches (/ ss i result) 
  (princ "\nSelect hatches to rebuild <Enter = all hatches in drawing>: ")
  (if (setq ss (ssget '((0 . "HATCH")))) 
    (progn 
      (setq i (sslength ss))
      (while (> i 0) 
        (setq i      (1- i)
              result (cons (vlax-ename->vla-object (ssname ss i)) result)
        )
      )
    )
  )
  result
)

;;; --------------------------------------------------------------------------
;;; rpat:get-pattern-data
;;;   Returns the entity data of a hatch if it uses a pattern file
;;;   (predefined or custom, not solid, not gradient), nil otherwise.
;;;   Arguments : obj - hatch VLA object
;;;   Returns   : entget list or nil
;;; --------------------------------------------------------------------------
(defun rpat:get-pattern-data (obj / ed ptype nlines) 
  (setq ed     (entget (vlax-vla-object->ename obj))
        ptype  (cdr (assoc 76 ed))
        nlines (cdr (assoc 78 ed))
  )
  (if 
    (and (/= (cdr (assoc 70 ed)) 1)  ; not a solid fill
         (/= (cdr (assoc 450 ed)) 1) ; not a gradient
         (member ptype '(1 2)) ; predefined or custom
         nlines
         (> nlines 0)
    )
    ed
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:read-raw-lines
;;;   Reads the pattern definition lines stored in the hatch, as they are
;;;   (already scaled, rotated and moved to the hatch origin).
;;;   DXF codes read for each line:
;;;     53 line angle             43/44 base point   45/46 offset
;;;     79 number of dashes       49   dash lengths (repeated)
;;;   Important: angle codes 50-58 are written in degrees in a DXF file,
;;;   but entget returns them in RADIANS. Code 53 is therefore converted
;;;   to degrees here, so every later step works in degrees.
;;;   Arguments : ed - hatch entget list
;;;   Returns   : list of (angle-in-degrees bx by ox oy (dashes...))
;;; --------------------------------------------------------------------------
(defun rpat:read-raw-lines (ed / cursor ang bx by ox oy ndash dashes result) 
  (setq cursor (member (assoc 78 ed) ed))
  (repeat (cdar cursor) 
    (setq cursor (rpat:next-group 53 cursor)
          ang    (rpat:rad->deg (cdar cursor))
          cursor (rpat:next-group 43 cursor)
          bx     (cdar cursor)
          cursor (rpat:next-group 44 cursor)
          by     (cdar cursor)
          cursor (rpat:next-group 45 cursor)
          ox     (cdar cursor)
          cursor (rpat:next-group 46 cursor)
          oy     (cdar cursor)
          cursor (rpat:next-group 79 cursor)
          ndash  (cdar cursor)
          dashes nil
    )
    (repeat ndash 
      (setq cursor (rpat:next-group 49 cursor)
            dashes (cons (cdar cursor) dashes)
      )
    )
    (setq result (cons (list ang bx by ox oy (reverse dashes)) result))
  )
  (reverse result)
)

;;; --------------------------------------------------------------------------
;;; rpat:normalize-line
;;;   Reverses the hatch transformation on one raw line to get the original
;;;   .pat definition (scale 1.0, angle 0):
;;;     - angle    : line angle minus hatch angle
;;;     - base     : (base - hatch origin) rotated by -hatch angle, / scale
;;;     - offset   : rotated by -line angle (back into the line's own axes,
;;;                  as required by the .pat format), / scale
;;;     - dashes   : / scale
;;;   Arguments : raw     - raw line from rpat:read-raw-lines
;;;               pat-ang - hatch pattern angle (radians)
;;;               scale   - hatch pattern scale
;;;               origin  - hatch origin (x y)
;;;   Returns   : list (angle x y dx dy (dashes...))
;;; --------------------------------------------------------------------------
(defun rpat:normalize-line (raw pat-ang scale origin / line-ang base offset) 
  (setq line-ang (nth 0 raw)
        base     (rpat:rotate-2d 
                   (- (nth 1 raw) (car origin))
                   (- (nth 2 raw) (cadr origin))
                   (- pat-ang)
                 )
        offset   (rpat:rotate-2d 
                   (nth 3 raw)
                   (nth 4 raw)
                   (- (rpat:deg->rad line-ang))
                 )
  )
  (list (rpat:normalize-angle (- line-ang (rpat:rad->deg pat-ang))) 
        (/ (car base) scale)
        (/ (cadr base) scale)
        (/ (car offset) scale)
        (/ (cadr offset) scale)
        (mapcar '(lambda (d) (/ d scale)) (nth 5 raw))
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:build-definition
;;;   Builds the complete normalized pattern definition of a hatch.
;;;   Arguments : obj - hatch VLA object
;;;               ed  - hatch entget list
;;;   Returns   : list of normalized definition lines
;;; --------------------------------------------------------------------------
(defun rpat:build-definition (obj ed / pat-ang scale origin) 
  ;; Hatch transformation parameters
  (setq pat-ang (vla-get-PatternAngle obj)
        scale   (vla-get-PatternScale obj)
        origin  (vl-catch-all-apply 'vlax-get (list obj 'Origin))
  )
  (if (or (vl-catch-all-error-p origin) (not (listp origin))) 
    (setq origin '(0.0 0.0))
  )
  (if (equal scale 0.0 rpat:*fuzz*) 
    (setq scale 1.0)
  )
  ;; Raw lines -> normalized lines
  (mapcar '(lambda (raw) (rpat:normalize-line raw pat-ang scale origin)) 
          (rpat:read-raw-lines ed)
  )
)


;;; ==========================================================================
;;; SECTION 5 - REBUILD AND CONFLICT HANDLING
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; rpat:rebuild-to
;;;   Builds the pattern definition of a hatch and writes it to a file,
;;;   under the given pattern name (file is created or overwritten).
;;;   Arguments : obj      - hatch VLA object
;;;               ed       - hatch entget list
;;;               pat-name - pattern name written in the file header
;;;               path     - full path of the .pat file
;;;   Returns   : T on success, nil on failure
;;; --------------------------------------------------------------------------
(defun rpat:rebuild-to (obj ed pat-name path / def) 
  (setq def (vl-catch-all-apply 'rpat:build-definition (list obj ed)))
  (and def 
       (not (vl-catch-all-error-p def))
       (rpat:write-pat-file path pat-name def)
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:valid-name-p
;;;   Checks that a pattern name is not empty and contains no character
;;;   forbidden in a pattern name or a Windows file name.
;;;   Arguments : name - candidate name
;;;   Returns   : T if valid, nil otherwise
;;; --------------------------------------------------------------------------
(defun rpat:valid-name-p (name) 
  (and (/= name "") 
       (vl-every '(lambda (c) (not (vl-string-search c name))) 
                 '(" " "," ";" "*" "?" "<" ">" "|" "\"" "/" "\\" ":")
       )
  )
)

;;; --------------------------------------------------------------------------
;;; rpat:ask-action
;;;   Asks what to do with a pattern that already exists.
;;;   Replace is only offered for a standalone .pat file, never for a
;;;   pattern stored inside acad.pat / acadiso.pat.
;;;   Arguments : name     - pattern name
;;;               existing - result of rpat:find-existing-pat
;;;   Returns   : "Replace", "Rename" or "Cancel"
;;; --------------------------------------------------------------------------
(defun rpat:ask-action (name existing / answer) 
  (princ (strcat "\nPattern \"" name "\" already exists: " (cadr existing)))
  (if (= (car existing) "FILE") 
    (progn 
      (initget "Replace Rename Cancel")
      (setq answer (getkword "\n  [Replace/Rename/Cancel] <Cancel>: "))
    )
    (progn 
      (princ "\n  It is stored in a pattern library and cannot be replaced.")
      (initget "Rename Cancel")
      (setq answer (getkword "\n  [Rename/Cancel] <Cancel>: "))
    )
  )
  (if answer answer "Cancel")
)

;;; --------------------------------------------------------------------------
;;; rpat:ask-new-name
;;;   Asks for a new pattern name until it is valid and not already used.
;;;   Names are converted to uppercase (AutoCAD convention).
;;;   Arguments : folder - target folder
;;;   Returns   : new name, or nil if the user pressed Enter (cancel)
;;; --------------------------------------------------------------------------
(defun rpat:ask-new-name (folder / new-name result done) 
  (while (not done) 
    (setq new-name (strcase (vl-string-trim " " (getstring T "\n  New pattern name <Cancel>: "))))
    (cond 
      ((= new-name "")
       (setq done T)
      )
      ((not (rpat:valid-name-p new-name))
       (princ "\n  Invalid name: spaces and , ; * ? < > | \" / \\ : are not allowed.")
      )
      ((rpat:find-existing-pat new-name folder)
       (princ (strcat "\n  Pattern \"" new-name "\" already exists, choose another name."))
      )
      (T
       (setq result new-name
             done   T
       )
      )
    )
  )
  result
)


;;; ==========================================================================
;;; SECTION 6 - REPORTING
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; rpat:print-list
;;;   Prints a titled list of pattern names (nothing if the list is empty).
;;;   Arguments : title - section title
;;;               names - list of pattern names (in reverse order)
;;; --------------------------------------------------------------------------
(defun rpat:print-list (title names) 
  (if names 
    (progn 
      (princ (strcat "\n  " title " (" (itoa (length names)) "):"))
      (foreach name (reverse names) 
        (princ (strcat "\n    - " name))
      )
    )
  )
)


;;; ==========================================================================
;;; SECTION 7 - COMMANDS
;;; ==========================================================================

;;; --------------------------------------------------------------------------
;;; C:Dyl-RebuildPat
;;;   Main command. Asks for a hatch selection (Enter = whole drawing),
;;;   rebuilds each missing pattern once in the target folder, asks what to
;;;   do with existing patterns (selection mode only) and makes sure the
;;;   target folder is in the support file search path.
;;; --------------------------------------------------------------------------

;; Rebuild Patterns
;; Rebuilds the .pat files of the hatch patterns missing from the support path.

(defun c:Dyl-RebuildPat (/ *error* old-dimzin doc folder hatches scope selected-p seen ed name key existing-pat action 
                         new-name rebuilt replaced renamed available cancelled failed path-added
                        ) 

  ;; ------------------------------------------------------------------------
  ;; Error handler: restores system variables and reports real errors only
  ;; ------------------------------------------------------------------------
  (defun *error* (msg) 
    (if old-dimzin (setvar "DIMZIN" old-dimzin))
    (if (and msg (not (wcmatch (strcase msg) "*BREAK*,*CANCEL*,*QUIT*,*EXIT*"))) 
      (princ (strcat "\nError: " msg))
    )
    (princ)
  )

  ;; ------------------------------------------------------------------------
  ;; Initialization
  ;;   DIMZIN is forced to 0 so rtos keeps leading zeros (0.5, not .5).
  ;; ------------------------------------------------------------------------
  (setq old-dimzin (getvar "DIMZIN")
        doc        (vla-get-ActiveDocument (vlax-get-acad-object))
        folder     (rpat:get-target-folder)
  )
  (setvar "DIMZIN" 0)

  ;; ------------------------------------------------------------------------
  ;; Target folder validation
  ;; ------------------------------------------------------------------------
  (if (not (rpat:ensure-folder folder)) 
    (progn 
      (princ (strcat "\nDyl-RebuildPat: cannot access or create folder " folder))
      (exit)
    )
  )

  ;; ------------------------------------------------------------------------
  ;; Hatch scope: user selection, or every hatch if Enter is pressed
  ;; ------------------------------------------------------------------------
  (if (setq hatches (rpat:select-hatches)) 
    (setq scope      "selected hatch(es)"
          selected-p T
    )
    (setq hatches    (rpat:collect-hatches doc)
          scope      "whole drawing"
          selected-p nil
    )
  )

  ;; ------------------------------------------------------------------------
  ;; Main loop: each pattern name is handled only once
  ;; ------------------------------------------------------------------------
  (foreach obj hatches 
    (if (setq ed (rpat:get-pattern-data obj)) 
      (progn 
        (setq name (cdr (assoc 2 ed))
              key  (strcase name)
        )
        (if (not (member key seen)) 
          (progn 
            (setq seen         (cons key seen)
                  existing-pat (rpat:find-existing-pat name folder)
            )
            (cond 
              ;; Missing pattern: rebuild it in the target folder
              ((null existing-pat)
               (if (rpat:rebuild-to obj ed name (strcat folder name ".pat")) 
                 (setq rebuilt (cons name rebuilt))
                 (setq failed (cons name failed))
               )
              )

              ;; Whole drawing mode: existing patterns are left untouched
              ((not selected-p)
               (setq available (cons name available))
              )

              ;; Selection mode: ask Replace / Rename / Cancel
              (T
               (setq action (rpat:ask-action name existing-pat))
               (cond 
                 ;; Replace: overwrite the existing file where it is
                 ((= action "Replace")
                  (if (rpat:rebuild-to obj ed name (cadr existing-pat)) 
                    (setq replaced (cons name replaced))
                    (setq failed (cons name failed))
                  )
                 )

                 ;; Rename: write a new file under a new name
                 ((and (= action "Rename") 
                       (setq new-name (rpat:ask-new-name folder))
                  )
                  (if (rpat:rebuild-to obj ed new-name (strcat folder new-name ".pat")) 
                    (setq renamed (cons (strcat name " -> " new-name) renamed))
                    (setq failed (cons name failed))
                  )
                 )

                 ;; Cancel (or empty new name): skip this pattern
                 (T
                  (setq cancelled (cons name cancelled))
                 )
               )
              )
            )
          )
        )
      )
    )
  )

  ;; ------------------------------------------------------------------------
  ;; Support path: make the new files visible to the HATCH command
  ;; ------------------------------------------------------------------------
  (if (or rebuilt renamed) 
    (setq path-added (rpat:ensure-in-support-path folder))
  )

  ;; ------------------------------------------------------------------------
  ;; Report
  ;; ------------------------------------------------------------------------
  (princ 
    (strcat "\nDyl-RebuildPat: " 
            (itoa (length seen))
            " pattern(s) checked ("
            scope
            ")."
    )
  )
  (rpat:print-list "Rebuilt" rebuilt)
  (rpat:print-list "Replaced" replaced)
  (rpat:print-list "Renamed" renamed)
  (rpat:print-list "Already available (unchanged)" available)
  (rpat:print-list "Cancelled" cancelled)
  (rpat:print-list "Failed" failed)
  (if (or rebuilt renamed) 
    (princ (strcat "\n  Folder: " folder))
  )
  (if path-added 
    (princ "\n  Folder added to the support file search path.")
  )
  (if (null seen) 
    (princ "\n  No pattern hatch found.")
  )

  ;; ------------------------------------------------------------------------
  ;; Cleanup
  ;; ------------------------------------------------------------------------
  (setvar "DIMZIN" old-dimzin)
  (princ)
)

;;; --------------------------------------------------------------------------
;;; C:Pst-OpenPats
;;;   Opens the pattern folder used by Dyl-RebuildPat in Windows Explorer.
;;;   The folder is resolved with the same logic (override, existing "pats"
;;;   folder in the support path, or ROAMABLEROOTPREFIX\Support\pats) and
;;;   created if it does not exist yet.
;;; --------------------------------------------------------------------------

;; Open Patterns Folder
;; Opens the pattern folder used by Dyl-RebuildPat in Windows Explorer.

(defun c:Pst-OpenPats (/ folder shell opened) 

  ;; ------------------------------------------------------------------------
  ;; Resolve and validate the folder
  ;; ------------------------------------------------------------------------
  (setq folder (rpat:get-target-folder))
  (if (not (rpat:ensure-folder folder)) 
    (progn 
      (princ (strcat "\nOPENPATS: cannot access or create folder " folder))
      (exit)
    )
  )

  ;; ------------------------------------------------------------------------
  ;; Open in Explorer through Shell.Application (handles spaces in paths);
  ;; fall back on STARTAPP if the COM object is not available.
  ;; ------------------------------------------------------------------------
  (setq shell (vl-catch-all-apply 'vlax-create-object (list "Shell.Application")))
  (if (and shell (not (vl-catch-all-error-p shell))) 
    (progn 
      (setq opened (not 
                     (vl-catch-all-error-p 
                       (vl-catch-all-apply 'vlax-invoke (list shell 'Open folder))
                     )
                   )
      )
      (vlax-release-object shell)
    )
  )
  (if (not opened) 
    (startapp "explorer.exe" (strcat "\"" (vl-string-right-trim "\\" folder) "\""))
  )

  (princ (strcat "\nOPENPATS: " folder))
  (princ)
)

(princ "\nDyl-RebuildPat.lsp loaded. Commands: Dyl-RebuildPat (RPAT), OPENPATS.")
(princ)
