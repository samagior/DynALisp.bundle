;; Dyl-Basics - the subfunctions of Lee Mac that the Dynalisp module uses
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

;;  The functions of Lee Mac (http://www.lee-mac.com, who keeps all the credit for them)
;;  that the Dynalisp module uses, copied as they are from Modules\LeeMac\Remote\LM-Sub.lsp:
;;  the lists and texts, the CSV files, a selection, a folder picked. The library modules
;;  (LeeMac, gileCAD) are loaded only once an App of another module needs them (Dyl:LibsLoad
;;  in dynalisp.mnl), so the Dynalisp module never relies on them. LM-Sub.lsp, loaded then,
;;  defines the same functions again, the same code. A function changed here is changed in
;;  LM-Sub.lsp too. Loads before Dyl-LayerPhase.lsp, which reads Phase.csv with them.

(defun Remote>>LM:lst->str (lst del) 
  (if (cdr lst) 
    (strcat (car lst) del (Remote>>LM:lst->str (cdr lst) del))
    (car lst)
  )
)

(defun Remote>>LM:str->lst (str del / len lst pos) 
  (setq len (1+ (strlen del)))
  (while (setq pos (vl-string-search del str)) 
    (setq lst (cons (substr str 1 pos) lst)
          str (substr str (+ pos len))
    )
  )
  (reverse (cons str lst))
)

(defun Remote>>LM:sublst (lst idx len / rtn) 
  (setq len (if len (min len (- (length lst) idx)) (- (length lst) idx))
        idx (+ idx len)
  )
  (repeat len (setq rtn (cons (nth (setq idx (1- idx)) lst) rtn)))
)

(defun Remote>>LM:csv->lst (str sep pos / s) 
  (cond 
    ((not (setq pos (vl-string-search sep str pos)))
     (if (wcmatch str "\"*\"") 
       (list (Remote>>LM:csv-replacequotes (substr str 2 (- (strlen str) 2))))
       (list str)
     )
    )
    ((or (wcmatch (setq s (substr str 1 pos)) "\"*[~\"]") 
         (and (wcmatch s "~*[~\"]*") (= 1 (logand 1 pos)))
     )
     (Remote>>LM:csv->lst str sep (+ pos 2))
    )
    ((wcmatch s "\"*\"")
     (cons 
       (Remote>>LM:csv-replacequotes (substr str 2 (- pos 2)))
       (Remote>>LM:csv->lst (substr str (+ pos 2)) sep 0)
     )
    )
    ((cons s (Remote>>LM:csv->lst (substr str (+ pos 2)) sep 0)))
  )
)

(defun Remote>>LM:csv-replacequotes (str / pos) 
  (setq pos 0)
  (while (setq pos (vl-string-search "\"\"" str pos)) 
    (setq str (vl-string-subst "\"" "\"\"" str pos)
          pos (1+ pos)
    )
  )
  str
)

(defun Remote>>LM:lst->csv (lst sep) 
  (if (cdr lst) 
    (strcat (Remote>>LM:csv-addquotes (car lst) sep) sep (Remote>>LM:lst->csv (cdr lst) sep))
    (Remote>>LM:csv-addquotes (car lst) sep)
  )
)

(defun Remote>>LM:csv-addquotes (str sep / pos) 
  (cond 
    ((wcmatch str (strcat "*[`" sep "\"]*"))
     (setq pos 0)
     (while (setq pos (vl-string-position 34 str pos)) 
       (setq str (vl-string-subst "\"\"" "\"" str pos)
             pos (+ pos 2)
       )
     )
     (strcat "\"" str "\"")
    )
    (str)
  )
)

(defun Remote>>LM:writecsv (lst csv / des sep) 
  (if (setq des (open csv "w")) 
    (progn 
      (setq sep (cond ((vl-registry-read "HKEY_CURRENT_USER\\Control Panel\\International" "sList")) (",")))
      (foreach row lst (write-line (Remote>>LM:lst->csv row sep) des))
      (close des)
      t
    )
  )
)

(defun Remote>>LM:ss->ent (ss / i l) 
  (if ss 
    (repeat (setq i (sslength ss)) 
      (setq l (cons (ssname ss (setq i (1- i))) l))
    )
  )
)

(defun Remote>>LM:browseforfolder (msg dir bit / err fld pth shl slf) 
  (setq err (vl-catch-all-apply 
              (function 
                (lambda (/ app hwd) 
                  (if 
                    (setq app (vlax-get-acad-object)
                          shl (vla-getinterfaceobject app "shell.application")
                          hwd (vl-catch-all-apply 'vla-get-hwnd (list app))
                          fld (vlax-invoke-method shl 
                                                  'browseforfolder
                                                  (if (vl-catch-all-error-p hwd) 0 hwd)
                                                  msg
                                                  bit
                                                  dir
                              )
                    )
                    (setq slf (vlax-get-property fld 'self)
                          pth (vlax-get-property slf 'path)
                          pth (vl-string-right-trim "\\" 
                                                    (vl-string-translate "/" "\\" pth)
                              )
                    )
                  )
                )
              )
            )
  )
  (if slf (vlax-release-object slf))
  (if fld (vlax-release-object fld))
  (if shl (vlax-release-object shl))
  (if (vl-catch-all-error-p err) 
    (prompt (vl-catch-all-error-message err))
    pth
  )
)

(princ)
