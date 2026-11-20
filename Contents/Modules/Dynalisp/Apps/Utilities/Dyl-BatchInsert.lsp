;; Batch Insert - Inserts every drawing of a folder side by side as blocks
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

;; Batch Insert
;; Inserts every drawing of a folder side by side as blocks in the current drawing.

(defun c:Dyl-BatchInsert () 

  (Directory-Dia "Select a folder")

  (setq x 0)
  (foreach path (vl-directory-files "C:/Users/My folder/" "*.dwg") 

    (command "_.-insert" path "x,0,0" "" "" "")
    (setq x (+ x 100))
  )
)


(defun Directory-Dia (Message / sh folder folderobject result) 
  ;; By Tony Tanzillo
  ;; Modified by Tim Willey
  ;; 16 Will let you type in the path
  ;; 64 Will let you create a new folder

  (vl-load-com)
  (setq sh (vla-getInterfaceObject 
             (vlax-get-acad-object)
             "Shell.Application"
           )
  )


  (setq folder (vlax-invoke-method 
                 sh
                 'BrowseForFolder
                 (vla-get-HWND (vlax-get-Acad-Object))
                 Message
                 16 ; This is the bit number to change.
               )
  )
  (vlax-release-object sh)


  (if folder 
    (progn 
      (setq folderobject (vlax-get-property folder 'Self))
      (setq result (vlax-get-property FolderObject 'Path))
      (vlax-release-object folder)
      (vlax-release-object FolderObject)
      (if (/= (substr result (strlen result)) "\\") 
        (setq result (strcat result "\\"))
        result
      )
    )
  )
)
