;; Dyl-RemoteSub - All available Dynalisp remote subfunctions
;; Copyright (C) 2023  Samuel Martineau
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


;#region Subfunctions

;;----------------------------------------------------------------------;;
;#region File and Directory


;;  Read every line of a file into a list of strings and print each line
;;  Arguments: *dir - directory path (with trailing separator), *fle - file name
;;  Result stored in global *lst

(defun Remote>>Dyl:fle->Lst (*dir *fle) 
  (setq *id (open (strcat *dir *fle) "r"))
  (setq *lst '())
  (while (setq *row (read-line *id)) 
    (setq *lst (cons *row *lst))
  )
  (setq *lst (reverse *lst))
  (foreach x *lst (princ (strcat "\n" x)))
  (close *id)
  (princ)
)


;;  Read every line of a CSV file, split it into fields and print the
;;  first 6 fields of each row as a list (list of lists)
;;  Arguments: *dir - directory path (with trailing separator), *fle - file name

(defun Remote>>Dyl:Lst->Lol (*dir *fle / *id *lst *row *col) 
  (setq *id (open (strcat *dir *fle) "r"))
  (while (setq *row (read-line *id)) 
    (progn 
      (setq *lst (Remote>>Dyl:Sep->Lst *row))
      (setq *col (list (nth 0 *lst) 
                       (nth 1 *lst)
                       (nth 2 *lst)
                       (nth 3 *lst)
                       (nth 4 *lst)
                       (nth 5 *lst)
                 )
      )
      (princ (strcat "\n" (vl-prin1-to-string *col)))
    )
  )
  (close *id)
  (princ)
)


;;  Split a delimited string into a list of individual strings
;;  Delimiters: ; : \ | / ,  (double quotes are stripped)
;;  Argument: *row - string to split
;;  Returns the list of strings

(defun Remote>>Dyl:Sep->Lst (*row / *chr *ctr *lst *wrd) 
  (setq *ctr 1)
  (setq *lst '())
  (setq *wrd "")
  (while (<= *ctr (strlen *row)) 
    (setq *chr (substr *row *ctr 1))
    (if (not (wcmatch *chr "\"")) 
      (if (not (wcmatch *chr ";,:,\\,|,/,`,")) 
        (setq *wrd (strcat *wrd *chr))
        (progn 
          (setq *lst (cons *wrd *lst))
          (setq *wrd "")
        )
      )
    )
    (setq *ctr (+ 1 *ctr))
  )
  (reverse (cons *wrd *lst))
)


;;  Join a list of strings into a single comma-separated string
;;  Requires global *lst to be set
;;  Result stored in global *str

(defun Remote>>Dyl:Lst->CmaStr () 
  (setq *ctr 0)
  (setq *str "")
  (while (< *ctr (length *lst)) 
    (setq *str (strcat *str (nth *ctr *lst) ","))
    (setq *ctr (+ 1 *ctr))
  )
  (if (> (strlen *str) 0) 
    (setq *str (substr *str 1 (1- (strlen *str))))
  )
  (princ)
)


;;  Copy a file as a .txt file in the same directory
;;  Requires globals *dir and *fle to be set

(defun Remote>>Dyl:FleCopyAsTxt () 
  (vl-file-copy 
    (strcat *dir "\\" *fle)
    (strcat *dir "\\" (vl-filename-base *fle) ".txt")
  )
  (princ (strcat "\nFile Duplicated as text: " *fle))
  (princ)
)


;;  Copy a file from one directory to another
;;  Requires globals *dir:in, *dir:out and *fle to be set

(defun Remote>>Dyl:FleCopyTo () 
  (vl-file-copy 
    (strcat *dir:in "\\" *fle)
    (strcat *dir:out "\\" *fle)
  )
  (princ (strcat "\nFile Copied to: " *dir:out))
  (princ)
)


;#endregion
;;----------------------------------------------------------------------;;
;#region Lists and CSV


;;  Return a copy of a list with the item at index i replaced by val:

(defun Remote>>Dyl:ListSubst (lst i val / n)
  (setq n -1)
  (mapcar '(lambda (x) (if (= i (setq n (1+ n))) val x)) lst)
)


;;  Return a copy of a list with val inserted at index i:

(defun Remote>>Dyl:ListInsert (lst i val)
  (if (and lst (< 0 i))
    (cons (car lst) (Remote>>Dyl:ListInsert (cdr lst) (1- i) val))
    (cons val lst)
  )
)


;;  Return a copy of a list without the item at index i:

(defun Remote>>Dyl:ListRemove (lst i / n)
  (setq n -1)
  (vl-remove-if '(lambda (x) (= i (setq n (1+ n)))) lst)
)


;;  The names of the header (the first line) of the CSV file fle, divided by its separator as
;;  in Remote>>Dyl:CsvRead, nil when it cannot be read:
(defun Remote>>Dyl:CsvHead (fle / des str)
  (if (and fle (setq des (open fle "r")))
    (progn
      (setq str (read-line des))
      (close des)
      (if str
        (mapcar '(lambda (x) (vl-string-trim " " x))
                (Remote>>LM:csv->lst (vl-string-left-trim (strcat (chr 239) (chr 187) (chr 191)) str)
                                     (cond ((vl-string-search ";" str) ";") ((vl-string-search "\t" str) "\t") (","))
                                     0
                )
        )
      )
    )
  )
)


;;  Read the rows of a CSV file, header row excluded. Each row is cut or padded to
;;  n cells trimmed of spaces. The separator (";", tab or ",") is detected from the
;;  header row, so the files written by Remote>>LM:writecsv are read back on any
;;  Windows list separator setting.
;;  Arguments: fle - full path of the CSV file, n - number of cells per row
;;  Returns nil when the file does not exist

(defun Remote>>Dyl:CsvRead (fle n / des str sep idx row lst)
  (repeat n (setq idx (cons (setq n (1- n)) idx)))
  (if (setq des (open fle "r"))
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
                lst (cons (mapcar '(lambda (i) (vl-string-trim " " (cond ((nth i row)) (""))))
                                  idx
                          )
                          lst
                    )
          )
        )
      )
      (close des)
    )
  )
  (reverse lst)
)


;;  List the names defined in the support files of a type: "pat" (hatch patterns)
;;  or "lin" (linetypes). Every *.<ext> file of the support path folders (ACAD
;;  environment variable + folder of acad.<ext>) is read; a definition line starts
;;  with "*NAME, description".
;;  Returns the names in upper case, sorted, without duplicates

(defun Remote>>Dyl:SupportDefs (ext / str pos dir dirs des nam lst)
  (setq str (strcat (cond ((getenv "ACAD")) ("")) ";"))
  (if (findfile (strcat "acad." ext))
    (setq str (strcat str (vl-filename-directory (findfile (strcat "acad." ext))) ";"))
  )
  (while (setq pos (vl-string-search ";" str))
    (setq dir (vl-string-right-trim "\\/ " (vl-string-left-trim " " (substr str 1 pos)))
          str (substr str (+ pos 2))
    )
    (if (and (/= "" dir) (not (member (strcase dir) dirs))) (setq dirs (cons (strcase dir) dirs)))
  )
  (foreach dir dirs
    (foreach fle (vl-directory-files dir (strcat "*." ext) 1)
      (if (setq des (open (strcat dir "\\" fle) "r"))
        (progn
          (while (setq str (read-line des))
            (if (= "*" (substr str 1 1))
              (progn
                (setq nam (strcase
                            (vl-string-trim " \t"
                                            (if (setq pos (vl-string-search "," str))
                                              (substr str 2 (1- pos))
                                              (substr str 2)
                                            )
                            )
                          )
                )
                (if (and (/= "" nam) (not (member nam lst))) (setq lst (cons nam lst)))
              )
            )
          )
          (close des)
        )
      )
    )
  )
  (acad_strlsort lst)
)


;#endregion


;#endregion