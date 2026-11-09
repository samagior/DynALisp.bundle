;; SetFilePrefs - Dynalisp file preferences profile
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

;; Set File Preferences
;; Commands:
;;   DYL-SETFILEPREFS - The file preferences on the command line: the AEC library
;;                      classification, the drawing units and the language (of the
;;                      content and of the main dictionary) and whether the DynALisp
;;                      custom dictionary of the language is used, then the DynALisp
;;                      profile is turned on and set from them.
;; The same preferences are in Dyl-Settings, which lists this file with them instead of
;; with the other setup commands. The profile is made and checked in every drawing by
;; Modules\Dynalisp\Remote\Dyl-FilePrefs.lsp, its paths are in Res\FilePrefs.csv.


;; Set File Preferences
;; Prompts for the file preferences and sets the DynALisp profile from them.

(defun c:Dyl-SetFilePrefs (/ kws cur res)
  (foreach p *fp:prefs*
    (setq kws (mapcar 'car (caddr p))
          cur (Remote>>Dyl:PrefGet (car p))
    )
    (initget (Remote>>LM:lst->str kws " "))
    (if (setq res (getkword (strcat "\n" (cadr p) " [" (Remote>>LM:lst->str kws "/") "] <" cur ">: ")))
      (Remote>>Dyl:PrefSet (car p) res)
    )
  )
  (initget "Yes No")
  (if (setq res (getkword (strcat "\nUse the DynALisp custom dictionary of the language, when it has one [Yes/No] <"
                                  (if (Remote>>Dyl:PrefCustomOn-p) "Yes" "No")
                                  ">: "
                          )
                )
      )
    (Remote>>Dyl:PrefCustomSet (= "Yes" res))
  )
  (Remote>>Dyl:PrefProfileSet T)
  (princ (strcat "\n" (Remote>>Dyl:PrefApply T) "."))
  (princ)
)
