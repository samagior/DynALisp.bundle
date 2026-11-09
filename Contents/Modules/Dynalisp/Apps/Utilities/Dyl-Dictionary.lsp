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
;;  The window (Res\Dyl-Dictionary.dcl) opens the file of the language of the file
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

;;  str cut in lines of at most n characters, at the spaces:
(defun dic:wrap (str n / lst lin)
  (foreach w (Remote>>LM:str->lst str " ")
    (if (and lin (< n (+ (strlen lin) 1 (strlen w))))
      (setq lst (cons lin lst)
            lin w
      )
      (setq lin (if lin (strcat lin " " w) w))
    )
  )
  (reverse (if lin (cons lin lst) lst))
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

;;-------------------------=={ Dialog }==------------------------;;

;;  The functions below run inside c:Dyl-Dictionary and use its local variables:
;;  dic:dics (names of the definitions files), dic:idx (index of the file shown),
;;  dic:all (its words, see dic:read), dic:view (the words listed), dic:cats / dic:subs /
;;  dic:typs (items of the Category, Subcategory and Type popups, the first one: all),
;;  dic:cat / dic:sub / dic:typ (their index), dic:keys (folded words searched),
;;  dic:ind (T: also in the definitions), dic:cur (the word shown), dic:seel (its see
;;  also words).

(defun dic:popup (key lst idx)
  (start_list key)
  (mapcar 'add_list lst)
  (end_list)
  (set_tile key (itoa idx))
)

;;  Load the definitions file dic:idx, every filter cleared:
(defun dic:dlgload ()
  (setq dic:all  (if (nth dic:idx dic:dics) (dic:read (dic:path (nth dic:idx dic:dics))))
        dic:cats (cons "All categories" (dic:distinct '(lambda (e) (list (nth 3 e))) dic:all))
        dic:typs (cons "All types" (dic:distinct '(lambda (e) (dic:types (nth 2 e))) dic:all))
  )
  (dic:dlgclear)
)

;;  Clear the search and the filters:
(defun dic:dlgclear ()
  (setq dic:cat  0
        dic:typ  0
        dic:keys nil
  )
  (set_tile "src" "")
  (dic:popup "cat" dic:cats 0)
  (dic:popup "typ" dic:typs 0)
  (dic:dlgsubs)
)

;;  Subcategories of the category chosen (of every category when all are):
(defun dic:dlgsubs ()
  (setq dic:subs (cons "All subcategories"
                       (dic:distinct '(lambda (e) (if (or (= 0 dic:cat) (= (nth 3 e) (nth dic:cat dic:cats))) (list (nth 4 e))))
                                     dic:all
                       )
                 )
        dic:sub  0
  )
  (dic:popup "sub" dic:subs 0)
  (dic:dlglist)
)

;;  T when the word e passes the search and the filters:
(defun dic:match-p (e)
  (and (or (= 0 dic:cat) (= (nth 3 e) (nth dic:cat dic:cats)))
       (or (= 0 dic:sub) (= (nth 4 e) (nth dic:sub dic:subs)))
       (or (= 0 dic:typ) (member (nth dic:typ dic:typs) (dic:types (nth 2 e))))
       (vl-every '(lambda (k) (or (vl-string-search k (nth 8 e)) (and dic:ind (vl-string-search k (nth 9 e)))))
                 dic:keys
       )
  )
)

;;  Fill the list with the words that pass, the word shown kept selected when it is one:
(defun dic:dlglist (/ i)
  (setq dic:view (vl-remove-if-not 'dic:match-p dic:all))
  (start_list "lst")
  (foreach e dic:view (add_list (strcat (car e) "\t" (nth 2 e) "\t" (nth 3 e) "\t" (nth 4 e))))
  (end_list)
  (set_tile "cnt"
            (strcat (itoa (length dic:view))
                    " of "
                    (itoa (length dic:all))
                    " words"
                    (if dic:all "" " (no definitions file in Res\\Dictionaries)")
            )
  )
  (setq i (cond ((if dic:cur (vl-position dic:cur dic:view))) (0)))
  (if dic:view (set_tile "lst" (itoa i)))
  (dic:dlgshow (nth i dic:view))
)

;;  Show the word e (nil: none):
(defun dic:dlgshow (e / lns)
  (setq dic:cur  e
        dic:seel (if e (dic:split (nth 6 e)))
        lns      (if e (dic:wrap (nth 5 e) 108))
  )
  (set_tile "wrd" (if e (strcat (car e) (if (/= "" (nth 2 e)) (strcat "   (" (nth 2 e) ")") "")) ""))
  (set_tile "frm" (if (and e (/= "" (nth 1 e))) (strcat "Forms: " (nth 1 e)) ""))
  (mapcar '(lambda (k l) (set_tile k (cond (l) ("")))) '("d1" "d2" "d3") (list (car lns) (cadr lns) (caddr lns)))
  (set_tile "cls" (if e (strcat (nth 3 e) (if (/= "" (nth 4 e)) (strcat "  >  " (nth 4 e)) "")) ""))
  (dic:popup "see" (cond (dic:seel) ('("(none)"))) 0)
  (mode_tile "see" (if dic:seel 0 1))
  (mode_tile "jmp" (if dic:seel 0 1))
  (mode_tile "cpy" (if e 0 1))
  (set_tile "msg" "")
)

;;  Search the words typed:
(defun dic:dlgsearch (str)
  (setq dic:keys (mapcar 'dic:fold (vl-remove "" (Remote>>LM:str->lst (vl-string-trim " " str) " "))))
  (dic:dlglist)
)

;;  Go to the see also word picked (index i of dic:seel): the filters are cleared when it
;;  is not listed:
(defun dic:dlgjump (i / w e)
  (setq w (nth i dic:seel)
        e (vl-some '(lambda (x) (if (= w (car x)) x)) dic:all)
  )
  (cond
    ((not e) (set_tile "msg" (strcat w ": not in the list")))
    (T
     (if (not (member e dic:view)) (dic:dlgclear))
     (setq dic:cur e)
     (dic:dlglist)
    )
  )
)

;;  Copy the word shown to the clipboard:
(defun dic:dlgcopy ()
  (if dic:cur
    (set_tile "msg" (if (dic:clip (car dic:cur)) (strcat "Copied: " (car dic:cur)) "--> Unable to copy to the clipboard"))
  )
)

;;-------------------------=={ Command }==------------------------;;

;; Dictionary
;; Searches the words of the DynALisp dictionaries, their definitions and categories, in the language of the file preferences.

(defun c:Dyl-Dictionary (/ dcl:id sta dic:dics dic:idx dic:all dic:view dic:cats dic:subs dic:typs dic:cat dic:sub
                         dic:typ dic:keys dic:ind dic:cur dic:seel fle usr
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
        dcl:id   (load_dialog (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\Dyl-Dictionary.dcl"))
  )
  (cond
    ((> 0 dcl:id) (princ "\n--> Unable to load the dialog : Dyl-Dictionary.dcl"))
    ((not (new_dialog "dyl_dictionary" dcl:id)) (princ "\n--> Unable to show the dialog : Dyl-Dictionary.dcl"))
    (T
     (dic:popup "dic" (cond ((mapcar 'dic:code dic:dics)) ('("(none)"))) dic:idx)
     (start_list "hdr")
     (add_list "Word\tType\tCategory\tSubcategory")
     (end_list)
     (dic:dlgload)
     (action_tile "dic" "(setq dic:idx (atoi $value) dic:cur nil) (dic:dlgload)")
     ;;  Enter searches (not leaving the box: a click in the list would refresh it):
     (action_tile "src" "(if (= 1 $reason) (dic:dlgsearch $value))")
     (action_tile "go" "(dic:dlgsearch (get_tile \"src\"))")
     (action_tile "ind" "(setq dic:ind (= \"1\" $value)) (dic:dlglist)")
     (action_tile "cat" "(setq dic:cat (atoi $value)) (dic:dlgsubs)")
     (action_tile "sub" "(setq dic:sub (atoi $value)) (dic:dlglist)")
     (action_tile "typ" "(setq dic:typ (atoi $value)) (dic:dlglist)")
     (action_tile "clr" "(dic:dlgclear)")
     (action_tile "lst" "(dic:dlgshow (nth (atoi $value) dic:view)) (if (= 4 $reason) (dic:dlgcopy))")
     (action_tile "jmp" "(dic:dlgjump (atoi (get_tile \"see\")))")
     (action_tile "cpy" "(dic:dlgcopy)")
     (action_tile "edt" "(done_dialog 2)")
     (mode_tile "edt" (if dic:dics 0 1))
     (Dyl:DocsTile "Utilities\\Dyl-Dictionary.htm")
     (setq sta (start_dialog))
     ;;  Edit list: the user copy of the file (made from its default the first time),
     ;;  opened in Excel:
     (if (and (= 2 sta) (setq fle (nth dic:idx dic:dics)))
       (progn
         (setq usr (Dyl:UserFileW (strcat (dic:dir) "\\" fle)))
         (if (not (findfile usr)) (vl-file-copy (strcat (dic:dir) "\\" fle) usr))
         (dic:shell usr)
         (princ (strcat "\nEditing " usr " (save it as CSV UTF-8), then run Dyl-Dictionary again."))
       )
     )
    )
  )
  (if (<= 0 dcl:id) (unload_dialog dcl:id))
  (princ)
)

(princ)
