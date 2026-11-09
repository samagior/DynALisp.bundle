;; Dyl-Paths - Dynalisp module Res paths and file preferences
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

;;  Loaded at startup with the other Remote files, before the Apps.
;;  Only this module points to its Res folder: *dyl:dyl (module root) is
;;  set by dynalisp.mnl.


;;  Dynalisp module Res paths:
(setq *dyl:dylres    (strcat *dyl:dyl "\\Res")
      *dyl:template  (strcat *dyl:dylres "\\Templates\\Model")
      *dyl:layerlist (strcat *dyl:dylres "\\Layer\\List")
      *dyl:plotstyle (strcat *dyl:dylres "\\Printers\\Plot Styles")
)


;;  Adds the module Plot Styles folder to the plot style search path
;;  (set on first launch and validated on each startup):
(defun Remote>>Dyl:PlotStylePath (/ pth)
  (setq pth (vla-get-PrinterStyleSheetPath *acad:fileprefs))
  (if
    (and (vl-file-directory-p *dyl:plotstyle)
         (not (vl-string-search (strcase *dyl:plotstyle) (strcase pth)))
    )
    (vla-put-PrinterStyleSheetPath *acad:fileprefs
                                   (vl-string-left-trim ";"
                                                        (strcat (vl-string-right-trim ";" pth)
                                                                ";"
                                                                *dyl:plotstyle
                                                        )
                                   )
    )
  )
)
(Remote>>Dyl:PlotStylePath)

(princ)
