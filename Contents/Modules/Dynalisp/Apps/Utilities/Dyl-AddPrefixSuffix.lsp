;; AddPrefixSuffix - Adds a prefix or suffix to text objects
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

;;; ==============================================================
;;; AddPrefixSuffix.lsp
;;;
;;; Adds a user-chosen string to the beginning (prefix) or end
;;; (suffix) of the text content of all selected TEXT and MTEXT
;;; entities.
;;;
;;; COMMAND:  TXTPS
;;;
;;; USAGE:
;;;   1. Load this file (APPLOAD, or drag-and-drop onto the
;;;      AutoCAD window).
;;;   2. Type TXTPS at the command line.
;;;   3. Select the TEXT / MTEXT objects to modify (other object
;;;      types in the selection are ignored automatically).
;;;   4. Choose whether to add the string as a Prefix or Suffix.
;;;   5. Type the text to add.
;;;
;;; NOTES:
;;;   - Works on both single-line TEXT and multiline MTEXT.
;;;   - For MTEXT, the string is added to the raw TextString
;;;     (including any formatting codes it may already contain),
;;;     so existing formatting is preserved.
;;;   - Wrapped in a single UNDO group, so one U / CTRL+Z undoes
;;;     the whole operation.
;;; ==============================================================

;; Text Prefix Suffix
;; Adds a user string as a prefix or suffix to the selected Text and Mtext objects.

(defun c:Dyl-AddPrefixSuffix (/ ss n i ent obj choice addstr txt newtxt count doc) 

  (vl-load-com)

  ;; Prompt for selection, restricted to TEXT and MTEXT
  (prompt "\nSelect TEXT and/or MTEXT objects to edit...")
  (setq ss (ssget 
             '((-4 . "<OR")
               (0 . "TEXT")
               (0 . "MTEXT")
               (-4 . "OR>")
              )
           )
  )

  (cond 

    ((null ss)
     (princ "\nNo TEXT or MTEXT objects selected/found.")
    )

    (t
     ;; Ask Prefix or Suffix
     (initget "Prefix Suffix")
     (setq choice (getkword "\nAdd text as [Prefix/Suffix] <Suffix>: "))
     (if (null choice) (setq choice "Suffix"))

     ;; Ask for the string to insert
     (setq addstr (getstring T "\nEnter text to add: "))

     (cond 
       ((or (null addstr) (= addstr ""))
        (princ "\nNo text entered. Command cancelled.")
       )

       (t
        (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
        (vla-StartUndoMark doc)

        (setq n     (sslength ss)
              i     0
              count 0
        )

        (repeat n 
          (setq ent (ssname ss i))
          (setq obj (vlax-ename->vla-object ent))

          (if (vlax-property-available-p obj 'TextString) 
            (progn 
              (setq txt (vlax-get-property obj 'TextString))
              (setq newtxt (if (= choice "Prefix") 
                             (strcat addstr txt)
                             (strcat txt addstr)
                           )
              )
              (vlax-put-property obj 'TextString newtxt)
              (setq count (1+ count))
            )
          )
          (setq i (1+ i))
        )

        (vla-EndUndoMark doc)

        (princ (strcat "\n" (itoa count) " text object(s) updated."))
       )
     )
    )
  )

  (princ)
)

(princ "\nTXTPS command loaded. Type Dyl-AddPrefixSuffix to add a prefix/suffix to selected TEXT/MTEXT.")
(princ)