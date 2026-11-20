;; Dyl-LayerPhase - Dynalisp phases: active phase of the drawing and auto-phasing of new objects
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

;;  Loaded at startup with the other Remote files, before the Apps.
;;
;;  A phased layer ends with "-" and a phase code: A-Wall-Full-E (existing to remain),
;;  A-Wall-Full-N (new work)... The codes and their descriptions are read from
;;  Modules\Dynalisp\Res\AEC\Standard\Phase.csv (*ph:defaults* when it is missing).
;;
;;  Each drawing has an active phase, saved in the drawing (none by default):
;;    - while auto-phase is on, every layer key gives its layer in the active phase
;;      (MED -> A-Detl-Medm-E, see Remote>>Dyl:LayerKeyName);
;;    - Auto-phase moves the objects created by a command to the active phase: an object
;;      created on A-Wall-Full-E, or on the layer of a phased layer key, goes to
;;      A-Wall-Full-N. Objects on other layers are not changed. Auto-phase is a user
;;      setting (DynalispPhaseAuto, off by default, see Dyl-Settings): on or off in every
;;      drawing, a drawing already open follows a change when it is made current.
;;  A missing phase layer is created from its source layer (see Remote>>Dyl:PhaseMake).
;;  The active phase is shown in the status bar (MODEMACRO) when MODEMACRO is not used
;;  by something else.
;;
;;  The phases are set with the Dyl-LayerPhase dialog and its aliases (PH-E, PH-N...).
;;
;;  Use in an App:
;;    (Remote>>Dyl:PhaseGet)                       -> active phase code ("N"), nil if none
;;    (Remote>>Dyl:PhaseSet "N")                   -> sets the active phase (nil: no phase)
;;    (Remote>>Dyl:PhaseLayer "A-Wall-Full-E" "N") -> "A-Wall-Full-N", created if missing

(vl-load-com)

;;  Phases used when Phase.csv is missing: (code description)
(setq *ph:defaults* '(("E" "Existing To Remain")
                      ("D" "Existing To Demolish")
                      ("N" "New Work")
                      ("T" "Temporary Work")
                      ("M" "Item To Be Moved")
                      ("S" "Existing To Be Saved")
                      ("R" "Existing To Be Refurbished")
                      ("A" "Abandoned Work")
                      ("F" "Future Work")
                      ("X" "Not In Contract")
                      ("P" "Proposed Work")
                     )
      ;;  Layers never phased (wcmatch pattern, upper case):
      *ph:never*    "0,DEFPOINTS,*|*"
      ;;  Commands whose new objects are left on their layer: they edit or split existing
      ;;  objects, or bring objects in (replaced by the DynalispPhaseSkip environment variable):
      *ph:skip*     (strcat "U,UNDO,REDO,MREDO,OOPS,EXPLODE,XPLODE,BURST,BREAK,BREAKATPOINT,TRIM,EXTEND,"
                            "FILLET,CHAMFER,JOIN,PEDIT,SPLINEDIT,CONVERTPOLY,OVERKILL,-OVERKILL,HATCHEDIT,"
                            "-HATCHEDIT,REVCLOUD,PASTE*,COPYTOLAYER,-COPYTOLAYER,LAYMRG,-LAYMRG,XBIND,-XBIND,"
                            "BIND,REFEDIT,-REFEDIT,REFCLOSE,REFSET,BEDIT,BCLOSE,AUDIT,RECOVER,DXFIN,IMPORT,INSERTOBJ"
                    )
)

;;-------------------------=={ Phases }==------------------------;;

;;  Phases of Phase.csv: ((code description) ...), *ph:defaults* when the file is missing
;;  (or at startup, while LM-Sub.lsp that parses the CSV lines is not loaded yet). The
;;  description is in the language of the AutoCAD installed (Dyl:LangAcad, as the ribbon),
;;  not the Language of Dyl-Settings (the docs), when the file has its column
;;  (Description.fr), the English one (Description, 6th column) otherwise. The file is read
;;  as UTF-8 for the accents; an AutoCAD that cannot (older than 2021) reads it in the code
;;  page of Windows and keeps the English descriptions:
(defun Remote>>Dyl:PhaseList (/ fle des utf str sep head col row lst)
  (setq fle (Dyl:UserFile (strcat (if *dyl:dylres *dyl:dylres (strcat *dyl:dyl "\\Res")) "\\AEC\\Standard\\Phase.csv")))
  (if (and Remote>>LM:csv->lst (findfile fle))
    (progn
      (setq utf (not (or (vl-catch-all-error-p (setq des (vl-catch-all-apply 'open (list fle "r" "utf8"))))
                         (not des)
                     )
                )
      )
      (if (not utf) (setq des (open fle "r")))
      (if des
        (progn
          (if (setq str (read-line des))
            (setq sep  (cond ((vl-string-search ";" str) ";") ((vl-string-search "\t" str) "\t") (","))
                  ;;  (a byte order mark can only be on the first name, Abbreviation, not used here)
                  head (mapcar '(lambda (h) (strcase (vl-string-trim " \t\"" h))) (Remote>>LM:csv->lst str sep 0))
                  ;;  The column of the language (nil in English, or without UTF-8):
                  col  (if (and utf Dyl:LangAcad (/= "en" (Dyl:LangAcad)))
                         (vl-position (strcat "DESCRIPTION." (strcase (Dyl:LangAcad))) head)
                       )
            )
          )
          (while (setq str (read-line des))
            (if (/= "" (vl-string-trim " \t" str))
              (progn
                (setq row (mapcar '(lambda (s) (vl-string-trim " " s)) (Remote>>LM:csv->lst str sep 0)))
                (if (and (= 1 (strlen (car row))) (snvalid (car row)) (not (assoc (strcase (car row)) lst)))
                  (setq lst (cons (list (strcase (car row))
                                        (cond ((and col (/= "" (cond ((nth col row)) ("")))) (nth col row))
                                              ((nth 5 row))
                                              ("")
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
    )
  )
  (cond ((reverse lst)) (*ph:defaults*))
)

;;  Description of a phase code ("" when it is not a phase):
(defun Remote>>Dyl:PhaseName (code)
  (cond ((cadr (assoc code (Remote>>Dyl:PhaseList)))) (""))
)

;;  Phase code of a layer name ("A-Wall-Full-E" -> "E"), nil when it is not phased.
;;  codes: the list of Remote>>Dyl:PhaseList
(defun Remote>>Dyl:PhaseOf (lay codes / c)
  (if (and (wcmatch lay "*?-?") (assoc (setq c (strcase (substr lay (strlen lay)))) codes)) c)
)

;;  Layer name without its phase ("A-Wall-Full-E" -> "A-Wall-Full"):
(defun Remote>>Dyl:PhaseBase (lay codes)
  (if (Remote>>Dyl:PhaseOf lay codes) (substr lay 1 (- (strlen lay) 2)) lay)
)

;;  Layer an object on lay goes to in phase code, nil when it stays on lay: a phased
;;  layer takes code in place of its own phase, the layer of a phased layer key gets it
;;  added. bases: layers of the layer keys (Remote>>Dyl:LayerKeyPhased)
(defun Remote>>Dyl:PhaseTarget (lay code codes bases / new)
  (setq new (cond
              ((wcmatch (strcase lay) *ph:never*) nil)
              ((Remote>>Dyl:PhaseOf lay codes) (strcat (Remote>>Dyl:PhaseBase lay codes) "-" code))
              ((member (strcase lay) bases) (strcat lay "-" code))
            )
  )
  (if (and new (/= (strcase new) (strcase lay))) new)
)

;;  Color of a layer moved from phase from to phase to (nil: not phased), same colors as
;;  Dyl-LayerTransfer: existing to demolish 2#, existing to remain 20# (# = last digit of
;;  the color), the other phases keep the color (its last digit when it comes from E or D):
(defun Remote>>Dyl:PhaseColor (aci from to / d)
  (setq d   (substr (itoa aci) (strlen (itoa aci)))
        aci (cond
              ((= "D" to) (atoi (strcat "2" d)))
              ((= "E" to) (atoi (strcat "20" d)))
              ((member from '("D" "E")) (atoi d))
              (aci)
            )
  )
  (if (<= 1 aci 255) aci 7)
)

;;  Create the layer new from the layer src (phase from -> phase to) when the drawing
;;  does not have it: color of Remote>>Dyl:PhaseColor (the color of its layer key when the
;;  key keeps its color in every phase, see Remote>>Dyl:LayerKeyKeepColor), linetype,
;;  lineweight, plot and description of src. Returns T when the layer exists:
(defun Remote>>Dyl:PhaseMake (src new from to / lays s n)
  (if (not (tblsearch "LAYER" new))
    (progn
      (setq lays (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object)))
            s    (vla-item lays src)
      )
      (if (not (vl-catch-all-error-p (setq n (vl-catch-all-apply 'vla-Add (list lays new)))))
        (progn
          (vla-put-Color n
                         (cond
                           ((and Remote>>Dyl:LayerKeyKeepColor
                                 (Remote>>Dyl:LayerKeyKeepColor (substr new 1 (max 1 (- (strlen new) (strlen to) 1))))
                            )
                           )
                           ((Remote>>Dyl:PhaseColor (abs (vla-get-Color s)) from to))
                         )
          )
          (vla-put-Linetype n (vla-get-Linetype s))
          (vla-put-Lineweight n (vla-get-Lineweight s))
          (vla-put-Plottable n (vla-get-Plottable s))
          (vla-put-Description n (vla-get-Description s))
          (princ (strcat "\nLayer created: " new " (phase " to ")"))
        )
      )
    )
  )
  (and (tblsearch "LAYER" new) t)
)

;;  Return the layer of lay in phase code, created from lay when missing (lay when it is
;;  not phased or code is nil):
(defun Remote>>Dyl:PhaseLayer (lay code / codes new)
  (setq codes (Remote>>Dyl:PhaseList))
  (if
    (and code
         (setq new (Remote>>Dyl:PhaseTarget lay code codes (Remote>>Dyl:LayerKeyPhased)))
         (Remote>>Dyl:PhaseMake lay new (Remote>>Dyl:PhaseOf lay codes) code)
    )
    new
    lay
  )
)

;;-------------------------=={ Active phase }==------------------------;;

;;  Active phase code of the drawing, nil when there is none:
(defun Remote>>Dyl:PhaseGet (/ p)
  (if (and (= 'STR (type (setq p (vlax-ldata-get "dyl-layer" "phase")))) (/= "" p)) p)
)

;;  T when auto-phase is on (user setting, off by default):
(defun Remote>>Dyl:PhaseAuto-p ()
  (= "1" (getenv "DynalispPhaseAuto"))
)

;;  T when auto-phase runs: on, and the DynALisp reactors on too (Dyl-Settings), since its
;;  reactors are in Modules\Dynalisp\Reactor\Dyl-LayerPhase.lsp:
(defun Remote>>Dyl:PhaseAutoOn-p ()
  (and (Remote>>Dyl:PhaseAuto-p) (Dyl:ReactorsOn-p))
)

;;  Set the active phase (nil: no phase). The current layer goes to the new phase when
;;  it is phased (A-Wall-Full-E -> A-Wall-Full-N):
(defun Remote>>Dyl:PhaseSet (code / lay)
  (vlax-ldata-put "dyl-layer" "phase" (cond (code) ("")))
  (if code
    (progn
      (setq lay (Remote>>Dyl:PhaseLayer (getvar "CLAYER") code))
      (if (/= (strcase lay) (strcase (getvar "CLAYER"))) (vl-catch-all-apply 'setvar (list "CLAYER" lay)))
      (princ (strcat "\nActive phase: " code " - " (Remote>>Dyl:PhaseName code)
                     " (current layer: " (getvar "CLAYER") ")"
                     (if (Remote>>Dyl:PhaseAutoOn-p) "" ", auto-phase off")
             )
      )
    )
    (princ "\nNo active phase: the layer keys give their layer without phase.")
  )
  (Remote>>Dyl:PhaseStatus)
)

;;  Turn auto-phase on or off (every drawing, from the next one made current):
(defun Remote>>Dyl:PhaseAutoSet (on)
  (setenv "DynalispPhaseAuto" (if on "1" "0"))
  (if Reactor>>Dyl:PhaseReactors (vl-catch-all-apply 'Reactor>>Dyl:PhaseReactors (list on)))
  (Remote>>Dyl:PhaseStatus)
  (princ (strcat "\nAuto-phase "
                 (if on "on" "off")
                 (if (and on (not (Dyl:ReactorsOn-p))) ", but the DynALisp reactors are off (see Dyl-Settings)" "")
                 "."
         )
  )
)

;;  Show the active phase in the status bar (MODEMACRO), only when MODEMACRO is empty or
;;  already shows the phase, and in the Auto-phase and Phase drop-downs of the ribbon
;;  (Dyl:RibbonPhase of Resources\DynALisp.Ribbon.dll, AutoCAD 2025 and later). Run on
;;  every change of the phase or of auto-phase, so that both always show the current state:
(defun Remote>>Dyl:PhaseStatus (/ mm code auto)
  (setq mm   (getvar "MODEMACRO")
        code (Remote>>Dyl:PhaseGet)
        auto (Remote>>Dyl:PhaseAutoOn-p)
  )
  (if (or (= "" mm) (wcmatch mm "Phase: *"))
    (vl-catch-all-apply 'setvar
                        (list "MODEMACRO"
                              (cond
                                (code (strcat "Phase: " code " - " (Remote>>Dyl:PhaseName code) (if auto " [Auto]" "")))
                                (auto "Phase: none [Auto]")
                                ("")
                              )
                        )
    )
  )
  (if Dyl:RibbonPhase
    (vl-catch-all-apply 'Dyl:RibbonPhase
                        (list code
                              (Remote>>Dyl:PhaseAuto-p)
                              (Dyl:ReactorsOn-p)
                              (apply 'append
                                     (mapcar '(lambda (p) (list (car p) (cond ((cadr p)) (""))))
                                             (Remote>>Dyl:PhaseList)
                                     )
                              )
                        )
    )
  )
  (princ)
)

;;  The auto-phase reactors are in Modules\Dynalisp\Reactor\Dyl-LayerPhase.lsp, loaded only
;;  while the DynALisp reactors are on (Dyl-Settings).

;;  Each drawing opened shows its phase (again once every Remote file is loaded, see
;;  Dyl:load: the ribbon then gets the phases of Phase.csv, read by Dyl-Sub.lsp):
(Remote>>Dyl:PhaseStatus)

(princ)
