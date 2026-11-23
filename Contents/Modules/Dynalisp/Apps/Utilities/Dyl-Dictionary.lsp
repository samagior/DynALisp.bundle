;; Dyl-Dictionary - Search the words of the DynALisp dictionaries and their definitions
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

;;  Next to each custom dictionary (Res\Dictionaries\<code>.cus, set by the file
;;  preferences, see Modules\Dynalisp\Remote\Dyl-FilePrefs.lsp), a definitions file
;;  <code>-def.csv (UTF-8, its user copy under User\ when there is one) gives each word:
;;    Word;Forms;Type;Category;Subcategory;Definition;See also
;;  Forms: its plural and feminine forms of the dictionary (comma separated), searched
;;  with the word. See also: related words of the file (comma separated).
;;  The window (Res\Dyl-Dictionary.xaml) opens the file of the language of the file
;;  preferences, searches it (accents and case ignored) and filters it by category,
;;  subcategory and type. This file has no accented letter: they are made with chr, so
;;  that it reads the same whatever the encoding AutoCAD loads it with.

(vl-load-com)

;;  Accented letters (code points) and the letters without accent they are searched as:
(setq *dic:acc* (apply 'strcat
                       (mapcar 'chr
                               '(224 226 228 225 227 233 232 234 235 237 236 238 239 243 242 244 246 245 250 249 251 252 255 231
                                 241 192 194 196 193 195 201 200 202 203 205 204 206 207 211 210 212 214 213 218 217 219 220 376
                                 199 209
                                )
                       )
                )
      *dic:asc* "aaaaaeeeeiiiiooooouuuuycnAAAAAEEEEIIIIOOOOOUUUUYCN"
      ;;  Ligatures, written as two letters:
      *dic:lig* (list (cons (chr 339) "oe") (cons (chr 338) "OE") (cons (chr 230) "ae") (cons (chr 198) "AE"))
)

;;-------------------------=={ Files }==------------------------;;

;;  Folder of the dictionaries (defaults under Contents):
(defun dic:dir ()
  (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\Dictionaries")
)

;;  Names of the definitions files (*-def.csv) of the folder and of its user copy, sorted:
(defun dic:files (/ dir usr lst)
  (setq dir (dic:dir)
        usr (Dyl:UserPath dir)
  )
  (foreach d (vl-remove nil (list dir (if (and usr (vl-file-directory-p usr)) usr)))
    (foreach f (vl-directory-files d "*-def.csv" 1)
      (if (not (member (strcase f) (mapcar 'strcase lst))) (setq lst (cons f lst)))
    )
  )
  (acad_strlsort lst)
)

;;  File to read of the definitions file name: its user copy when there is one:
(defun dic:path (name)
  (Dyl:UserFile (strcat (dic:dir) "\\" name))
)

;;  Code of a definitions file name ("fra-def.csv" -> "fra"):
(defun dic:code (name)
  (substr name 1 (- (strlen name) 8))
)

;;  Open the file to read it as UTF-8 (as ANSI when this AutoCAD cannot):
(defun dic:open (fle / des)
  (if (or (vl-catch-all-error-p (setq des (vl-catch-all-apply 'open (list fle "r" "utf8")))) (not des))
    (open fle "r")
    des
  )
)

;;-------------------------=={ Words }==------------------------;;

;;  str without accents nor ligatures, in upper case, to search it:
(defun dic:fold (str)
  (setq str (vl-string-translate *dic:acc* *dic:asc* str))
  (foreach p *dic:lig*
    (while (vl-string-search (car p) str) (setq str (vl-string-subst (cdr p) (car p) str)))
  )
  (strcase str)
)

;;  Words of a definitions file, sorted: ((word forms type category subcategory
;;  definition see-also WORD WORD+FORMS DEFINITION) ...), the last three folded to search
;;  them (see dic:fold):
(defun dic:read (fle / des str sep row lst)
  (if (setq des (dic:open fle))
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
          (progn
            (setq row (Remote>>LM:csv->lst str sep 0)
                  row (mapcar '(lambda (i) (vl-string-trim " " (cond ((nth i row)) ("")))) '(0 1 2 3 4 5 6))
            )
            (if (/= "" (car row))
              (setq lst (cons (append row
                                      (list (dic:fold (car row))
                                            (dic:fold (strcat (car row) ", " (cadr row)))
                                            (dic:fold (nth 5 row))
                                      )
                              )
                              lst
                        )
              )
            )
          )
        )
      )
      (close des)
    )
  )
  (vl-sort lst '(lambda (a b) (< (nth 7 a) (nth 7 b))))
)

;;  Items of a comma separated cell, trimmed, empty ones left out:
(defun dic:split (str)
  (vl-remove "" (mapcar '(lambda (s) (vl-string-trim " " s)) (Remote>>LM:str->lst str ",")))
)

;;  Types of a Type cell ("n.m./adj." -> ("n.m." "adj.")):
(defun dic:types (str)
  (vl-remove "" (mapcar '(lambda (s) (vl-string-trim " " s)) (Remote>>LM:str->lst str "/")))
)

;;  Distinct values of the function fn over the words lst, sorted:
(defun dic:distinct (fn lst / res)
  (foreach e lst
    (foreach v (apply fn (list e))
      (if (and (/= "" v) (not (member v res))) (setq res (cons v res)))
    )
  )
  (vl-sort res '(lambda (a b) (< (dic:fold a) (dic:fold b))))
)

;;  Copy str to the Windows clipboard, T when done:
(defun dic:clip (str / htm res)
  (if (setq htm (vlax-create-object "htmlfile"))
    (progn
      (setq res (vl-catch-all-apply
                  '(lambda ()
                     (vlax-invoke (vlax-get (vlax-get htm 'ParentWindow) 'ClipBoardData) 'SetData "Text" str)
                   )
                )
      )
      (vlax-release-object htm)
      (not (vl-catch-all-error-p res))
    )
  )
)

;;  Open the file path with its Windows association (Excel), Notepad when that fails:
(defun dic:shell (path / shl)
  (setq shl (vl-catch-all-apply 'vla-getinterfaceobject (list (vlax-get-acad-object) "Shell.Application")))
  (cond
    ((and (not (vl-catch-all-error-p shl))
          (not (vl-catch-all-error-p (vl-catch-all-apply 'vlax-invoke-method (list shl 'ShellExecute path "" "" "open" 1))))
     )
    )
    ((startapp "notepad" (strcat "\"" path "\"")))
  )
  (if (not (vl-catch-all-error-p shl)) (vlax-release-object shl))
)

;;-------------------------=={ Window }==------------------------;;

;;  The functions below run inside c:Dyl-Dictionary and use its local variables:
;;  dic:dics (names of the definitions files), dic:idx (index of the file shown),
;;  dic:all (its words, see dic:read), dic:view (the words listed: those of the category,
;;  subcategory and type picked; the window searches them itself), dic:cats / dic:subs /
;;  dic:typs (items of the Category, Subcategory and Type lists, the first one: all),
;;  dic:cat / dic:sub / dic:typ (their index), dic:src (the words typed in Words),
;;  dic:ind (T: also in the definitions), dic:cur (the word shown), dic:msg (the message
;;  under the definition).

;;  A cell without tab, to be a column of an item of the window:
(defun dic:cell (str) (vl-string-translate "\t" " " str))

;;  Load the definitions file dic:idx, every filter cleared:
(defun dic:winload ()
  (setq dic:all  (if (nth dic:idx dic:dics) (dic:read (dic:path (nth dic:idx dic:dics))))
        dic:cats (cons "All categories" (dic:distinct '(lambda (e) (list (nth 3 e))) dic:all))
        dic:typs (cons "All types" (dic:distinct '(lambda (e) (dic:types (nth 2 e))) dic:all))
        dic:cur  nil
  )
  (dic:winclear)
)

;;  Clear the search and the filters:
(defun dic:winclear ()
  (setq dic:cat 0
        dic:typ 0
        dic:src ""
  )
  (dic:winsubs)
)

;;  Subcategories of the category chosen (of every category when all are):
(defun dic:winsubs ()
  (setq dic:subs (cons "All subcategories"
                       (dic:distinct '(lambda (e) (if (or (= 0 dic:cat) (= (nth 3 e) (nth dic:cat dic:cats))) (list (nth 4 e))))
                                     dic:all
                       )
                 )
        dic:sub  0
  )
)

;;  T when the word e passes the filters (the search is made by the window):
(defun dic:match-p (e)
  (and (or (= 0 dic:cat) (= (nth 3 e) (nth dic:cat dic:cats)))
       (or (= 0 dic:sub) (= (nth 4 e) (nth dic:sub dic:subs)))
       (or (= 0 dic:typ) (member (nth dic:typ dic:typs) (dic:types (nth 2 e))))
  )
)

;;  The item of the word e: its word, type, category and subcategory shown, then the word
;;  and its forms (searched), the same with its definition (searched with Also in the
;;  definitions), and what the Definition box shows (its word and type, its forms, its
;;  definition, its class, its See also words):
(defun dic:item (e)
  (apply 'strcat
         (cdr (apply 'append
                     (mapcar '(lambda (s) (list "\t" (dic:cell s)))
                             (list (car e)
                                   (nth 2 e)
                                   (nth 3 e)
                                   (nth 4 e)
                                   (strcat (car e) ", " (nth 1 e))
                                   (strcat (car e) ", " (nth 1 e) " " (nth 5 e))
                                   (strcat (car e) (if (/= "" (nth 2 e)) (strcat "   (" (nth 2 e) ")") ""))
                                   (if (/= "" (nth 1 e)) (strcat "Forms: " (nth 1 e)) "")
                                   (nth 5 e)
                                   (strcat (nth 3 e) (if (/= "" (nth 4 e)) (strcat "  >  " (nth 4 e)) ""))
                                   (apply 'strcat (cdr (apply 'append (mapcar '(lambda (w) (list ", " w)) (dic:split (nth 6 e))))))
                             )
                     )
                )
         )
  )
)

;;  The values of the window: the lists, the words that pass the filters, the word shown
;;  (the first one when it no longer passes) and its definition:
(defun dic:winvals (/ i e see)
  (setq dic:view (vl-remove-if-not 'dic:match-p dic:all)
        i        (cond ((if dic:cur (vl-position dic:cur dic:view))) (0))
        e        (nth i dic:view)
        dic:cur  e
        see      (if e (dic:split (nth 6 e)))
  )
  (append (Dyl:WinList "dic" (cond ((mapcar 'dic:code dic:dics)) ('("(none)"))) dic:idx)
          (Dyl:WinList "cat" dic:cats dic:cat)
          (Dyl:WinList "sub" dic:subs dic:sub)
          (Dyl:WinList "typ" dic:typs dic:typ)
          (Dyl:WinList "lst" (mapcar 'dic:item dic:view) (if e i -1))
          (Dyl:WinList "see" see (if see 0 -1))
          (list (cons "src" dic:src)
                (Dyl:WinTog "ind" dic:ind)
                (cons "wrd" (if e (strcat (car e) (if (/= "" (nth 2 e)) (strcat "   (" (nth 2 e) ")") "")) ""))
                (cons "frm" (if (and e (/= "" (nth 1 e))) (strcat "Forms: " (nth 1 e)) ""))
                (cons "def" (if e (nth 5 e) ""))
                (cons "cls" (if e (strcat (nth 3 e) (if (/= "" (nth 4 e)) (strcat "  >  " (nth 4 e)) "")) ""))
                (cons "msg" (cond (dic:msg) ((not dic:all) "No definitions file in Res\\Dictionaries") ("")))
          )
          (Dyl:WinOff "edt" (not dic:dics))
  )
)

;;  Keep what the window got back: the search typed, Also in the definitions, the word
;;  picked (nil: none):
(defun dic:winget (res / i)
  (setq dic:src (cond ((Dyl:WinGet res "src")) (""))
        dic:ind (Dyl:WinOn-p res "ind")
        i       (atoi (cond ((Dyl:WinGet res "lst")) ("-1")))
        dic:cur (if (<= 0 i) (nth i dic:view))
        dic:msg nil
  )
)

;;  Go to the See also word picked (index i of the See also list of the word shown): the
;;  filters and the search are cleared when it does not pass them:
(defun dic:winjump (i / w e)
  (setq w (if dic:cur (nth i (dic:split (nth 6 dic:cur))))
        e (if w (vl-some '(lambda (x) (if (= w (car x)) x)) dic:all))
  )
  (cond
    ((not w))
    ((not e) (setq dic:msg (strcat w ": not in the list")))
    (T
     (if (or (not (dic:match-p e)) (/= "" dic:src)) (dic:winclear))
     (setq dic:cur e)
    )
  )
)

;;  Copy the word shown to the clipboard:
(defun dic:wincopy ()
  (if dic:cur
    (setq dic:msg (if (dic:clip (car dic:cur)) (strcat "Copied: " (car dic:cur)) "--> Unable to copy to the clipboard"))
  )
)

;;-------------------------=={ Command }==------------------------;;

;;  The window (Res\Dyl-Dictionary.xaml) closes with the number of what changed the words
;;  listed (2 Dictionary, 3 Category, 4 Subcategory, 5 Type, 9 Clear), of Go to (6) and of
;;  Copy word (7, a word double-clicked): it is shown again on the words of the new
;;  choice. Edit list... (8) opens the definitions file.

;; Dictionary
;; Searches the words of the DynALisp dictionaries, their definitions and categories, in the language of the file preferences.

(defun c:Dyl-Dictionary (/ res sta dic:dics dic:idx dic:all dic:view dic:cats dic:subs dic:typs dic:cat dic:sub dic:typ
                         dic:src dic:ind dic:cur dic:msg fle usr
                        )
  (setq dic:dics (dic:files)
        ;;  The file of the language of the file preferences, else the first one:
        dic:idx  (cond
                   ((if Remote>>Dyl:PrefDictionary
                      (vl-position (strcase (strcat (Remote>>Dyl:PrefDictionary (Remote>>Dyl:PrefGet "Language")) "-def.csv"))
                                   (mapcar 'strcase dic:dics)
                      )
                    )
                   )
                   (0)
                 )
  )
  (dic:winload)
  (while (and (setq res (Dyl:WinShow "Dyl-Dictionary.xaml" (dic:winvals)))
              (member (setq sta (car res)) '(2 3 4 5 6 7 9))
         )
    (dic:winget res)
    (cond
      ((= 2 sta)
       (setq dic:idx (Dyl:WinIdx res "dic"))
       (dic:winload)
      )
      ((= 3 sta)
       (setq dic:cat (Dyl:WinIdx res "cat"))
       (dic:winsubs)
      )
      ((= 4 sta) (setq dic:sub (Dyl:WinIdx res "sub")))
      ((= 5 sta) (setq dic:typ (Dyl:WinIdx res "typ")))
      ((= 6 sta) (dic:winjump (Dyl:WinIdx res "see")))
      ((= 7 sta) (dic:wincopy))
      ((= 9 sta) (dic:winclear))
    )
  )
  ;;  Edit list...: the user copy of the file (made from its default the first time),
  ;;  opened in Excel:
  (if (and (= 8 (car res)) (setq fle (nth dic:idx dic:dics)))
    (progn
      (setq usr (Dyl:UserFileW (strcat (dic:dir) "\\" fle)))
      (if (not (findfile usr)) (vl-file-copy (strcat (dic:dir) "\\" fle) usr))
      (dic:shell usr)
      (princ (strcat "\nEditing " usr " (save it as CSV UTF-8), then run Dyl-Dictionary again."))
    )
  )
  (princ)
)

(princ)
