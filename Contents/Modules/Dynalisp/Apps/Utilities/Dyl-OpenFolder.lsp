;; OpenFolder - Opens a Dynalisp or drawing folder in Windows Explorer
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
;;
;;-------------------------=={ End of Licence }==------------------------;;

;; Open Folder
;; Opens the repository, current drawing, template, sheet set or AutoCAD support folder in Windows Explorer.
;; The sheet set folder is the nearest folder containing a .dst file, searching
;; from the current drawing folder up through its parents. The support folder is the user
;; Support folder of AutoCAD (ROAMABLEROOTPREFIX + Support: acad.cuix, the partial CUIx
;; files AutoCAD saves there, the user's .pat and .lin files).

(defun Local>>Dyl:Explore (*dir)
  ;; *dir = [str] folder to open (quoted, trailing backslash removed for explorer)
  (if (and *dir (vl-file-directory-p *dir))
    (startapp "explorer" (strcat "\"" (vl-string-right-trim "\\" *dir) "\""))
    (princ (strcat "\nFolder not found: " (vl-princ-to-string *dir)))
  )
)

(defun Local>>Dyl:FindSheetSetDir (*dir / *par)
  ;; *dir = [str] folder to start the upward search from
  ;; Returns the first folder containing a .dst file, or nil
  (setq *dir (vl-string-right-trim "\\" *dir))
  (cond
    ((vl-directory-files *dir "*.dst" 1) *dir)
    ((and (setq *par (vl-filename-directory *dir))
          (/= (strcase *par) (strcase *dir))
     )
     (Local>>Dyl:FindSheetSetDir *par)
    )
  )
)

;; Open Folder
;; Opens the repository, current drawing, template, sheet set or AutoCAD support folder in Windows Explorer.

(defun c:Dyl-OpenFolder (/ *opt *dir)
  (initget
    "Repository CurrentDrawing Template SheetSet sUpport _R C T S U"
  )
  (setq *opt (getkword
               (strcat
                 "\nOpen folder: [Repository/CurrentDrawing/Template/SheetSet/sUpport] : "
               )
             )
  )
  (cond
    ((= "R" *opt) (Local>>Dyl:Explore *dyl:repo))
    ((= "C" *opt) (Local>>Dyl:Explore (getvar 'dwgprefix)))
    ((= "T" *opt) (Local>>Dyl:Explore *dyl:template))
    ((= "S" *opt)
     (if (setq *dir (Local>>Dyl:FindSheetSetDir (getvar 'dwgprefix)))
       (Local>>Dyl:Explore *dir)
       (princ "\nNo sheet set (.dst) found in the drawing folder or its parents.")
     )
    )
    ;;  The user Support folder of this AutoCAD (its version and language):
    ((= "U" *opt) (Local>>Dyl:Explore (strcat (getvar "ROAMABLEROOTPREFIX") "Support")))
    (T nil)
  )
  (princ)
)
