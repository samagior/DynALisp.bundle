;; LayerFilter - Initial layer filtering commands for visibility setup (work with AIA based layer names)
;; Copyright (C) 2023  Samuel Martineau
;; 
;; This program is free software: you can redistribute it and/or modify
;; it under the term  of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at y ur option) any later version.
;; 
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details 
;; 
;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>. 
;;
;;-------------------------=={ End of Licence }==------------------------;;

(defun Dyl-LayFilter (*shw *hid *sh2 *hi2 *scn *lck *msg) 

  ;;  Arguments:
  ;;  *shw = [lst] layer name patterns to turn ON and thaw (primary set)
  ;;  *hid = [lst] layer name patterns to turn OFF and freeze (primary set)
  ;;  *sh2 = [lst] layer name patterns to turn ON and thaw (secondary / stacked set)
  ;;  *hi2 = [lst] layer name patterns to turn OFF and freeze (secondary / stacked set)
  ;;  *scn = [lst] layer name patterns to apply 50% screen transparency (and optionally lock)
  ;;  *lck = [str] "Yes" to lock the screened layers, "No" otherwise
  ;;  *msg = [str] human-readable description of the filter state, shown in the prompt
  ;;
  ;;  Local variables:
  ;;  *erm = [str] error message string passed to the inner *error* handler
  ;;  *cme = [int] saved cmdecho system variable setting, restored on exit
  ;;  *xrl = [lst] xref block names that also exist as a layer in the drawing
  ;;  *blk = [obj] VLA block object iterated over the active document Blocks collection
  ;;  *nam = [str] name of the current xref block being examined
  ;;  *rst = [lst] xref layer patterns whose source dwg was NOT found in the Model views folder
  ;;  *dir = [str] path to the "Model views" subfolder of the current drawing directory
  ;;  *fll = [lst] list of .dwg filenames found in the Model views folder
  ;;  *inp = [lst] list of four lists (*shw *hid *sh2 *hi2) fed into the group-expansion foreach
  ;;  *ctr = [int] index of the current list within *inp (0=*shw 1=*hid 2=*sh2 3=*hi2)
  ;;  *out = [lst] accumulator collecting expanded lists; reversed at end to restore input order
  ;;  *lst = [lst] current list being expanded inside the foreach loop over *inp
  ;;  *ss  = [sel] user selection set (paper space only, used to pick viewports)
  ;;  *vps = [sel] viewport-only subset of *ss (paper space only)


  ;;---------------------------------------------------------------------------------------
  ;; Error handling function:
  (defun *error* (*erm) 
    (if (not *dyl-in-error) 
      (progn 
        (setq *dyl-in-error T)
        (*pop-error-mode*)
        (if *cme (setvar 'cmdecho *cme))
        (if *dyl-marked 
          (progn 
            (setq *dyl-marked nil)
            (vl-catch-all-apply '(lambda () (command "undo" "back")))
          )
        )
        (setq *dyl-in-error nil)
      )
    )
    (if (= *erm "Function cancelled") 
      (prompt "\nFunction cancelled.")
      (if (not (= *erm "quit / exit abort")) 
        (princ (strcat "\nError: " *erm))
      )
    )
    (princ)
  )
  (setq *cme          (getvar 'cmdecho)
        *dyl-marked   nil
        *dyl-in-error nil
  )
  (setvar 'cmdecho 0)
  (*push-error-using-command*)


  ;;---------------------------------------------------------------------------------------
  ;;  List of xref layer name to show when used in sheets with the sheet set manager
  ;;  (Xref are being asigned to a layer with the same name as the xref name)

  ;; starting variables:
  (setq *xrl '())

  ;;  Get all the active document block name and add them to the list if they are xref:
  (vlax-for *blk (vla-get-Blocks (vla-get-ActiveDocument (vlax-get-acad-object))) 
    (if (= (vla-get-IsXRef *blk) :vlax-true) 
      (progn 
        (setq *nam (vla-get-Name *blk))
        (if (= nil (member *nam *xrl)) 
          (setq *xrl (cons *nam *xrl))
        )
      )
    )
  )

  ;;  Check if the xref name if being used as a layer name also, if not remove it from the list:
  (foreach x *xrl 
    (if (not (tblsearch "LAYER" x)) 
      (setq *xrl (vl-remove x *xrl))
    )
  )

  ;;  Add the remaining xref name to the list of layer to show:
  (setq *shw (append *xrl *shw)
        *shw (append '("Defpoints" "0") *shw)
  )


  ;;---------------------------------------------------------------------------------------
  ;;  make all xref layer a screen of corrdination layer:
  ;;; (if (not (wcmatch *msg "*Xref*")) (setq *hi2 (append '("*|*Defpoints" "*|*0" "*|*Anno*") *hi2)))
  ;;  (if (and (not (member "*" *sh2)) (not (wcmatch *msg "*Xref*")))
  ;;    (setq *scn (append '("*|*") *scn))
  ;;  )

  ;;  get all dwg files from the current drawing folder:
  (setq *rst '())
  (setq *dir (getvar 'dwgprefix))
  (setq *dir (strcat *dir "\\Model views"))
  (setq *fll (vl-directory-files *dir "*.dwg" 1))
  (foreach x *xrl 
    (if (member x *fll) 
      (setq *scn (append (list (strcat x "|*")) *scn))
      (setq *rst (append (list (strcat x "|*")) *rst))
    )
  )




  ;;---------------------------------------------------------------------------------------
  ;;
  ;;  Convert all list to a list of list for the below foreach loop:
  (setq *inp (list *shw *hid *sh2 *hi2 *scn))

  ;;  Starting variable for the foreach loop:
  (setq *ctr 0
        *out '()
  )

  ;;  process each list form the input list of list in search for the corresponding layer groups
  ;;  if a group is found; replace the groupe name by a list of preset layer names:
  (foreach *lst *inp 
    (if (member "A-Flor" *lst) 
      (progn 
        (setq *lst (vl-remove "A-Flor" *lst))
        (setq *lst (append '("*A-Flor*" "*A-Wall*" "*A-Door*" "*A-Glaz*") *lst))
      )
    )
    (if (member "N-Architectural" *lst) 
      (progn 
        (setq *lst (vl-remove "N-Architectural" *lst))
        (setq *lst (append '("S-*" "P-*" "I-*" "L-*") *lst))
      )
    )
    (if (member "N-Structural" *lst) 
      (progn 
        (setq *lst (vl-remove "N-Structural" *lst))
        (setq *lst (append '("A-*" "P-*" "I-*" "L-*") *lst))
      )
    )
    (if (member "A-Scrn" *lst) 
      (progn 
        (setq *lst (vl-remove "A-Flor" *lst))
        (setq *lst (append '("L-*" "S-*" "*A-Door*" "*A-Door*") *lst))
      )
    )
    (if (member "Pattern" *lst) 
      (progn 
        (setq *lst (vl-remove "Pattern" *lst))
        (setq *lst (append '("*-Patt*" "*-Elev*-Mcut*") *lst))
      )
    )
    (if (member "Annotation" *lst) 
      (progn 
        (setq *lst (vl-remove "Annotation" *lst))
        (setq *lst (append 
                     '("*-Anno*" "*-Tags*" "*-Dims*" "*-Text*" "*-Note*" "*-Titl*" "*-Symb*" "*-Iden*" "*-Mark*" 
                       "*-Keyn*" "*-Exst*" "*-Grid*"
                      )
                     *lst
                   )
        )
      )
    )
    (if (member "Highlight" *lst) 
      (progn 
        (setq *lst (vl-remove "Highlight" *lst))
        (setq *lst (append 
                     '("*-Elev*-Main*" "*-Elev*-Otln*" "*-Elev*-Blin*" "*-Elev*-Sect*" "*-Elev*-Medm*" "*-Elev*-Wide*" 
                       "*-Elev*-X~~~*" "*-Elev*-XX~~*" "*-Elev*-XXX~*" "*-Elev*-XXXX*"
                      )
                     *lst
                   )
        )
      )
    )
    (if (member "Hidden" *lst) 
      (progn 
        (setq *lst (vl-remove "Hidden" *lst))
        (setq *lst (append '("*-Elev-*Hidd*" "*-Elev-*Bgrd*" "*-Elev-*Nplt*") *lst))
      )
    )
    (if (member "Standard" *lst) 
      (progn 
        (setq *lst (vl-remove "Hidden" *lst))
        (setq *lst (append '("*-Elev-*Line*" "*-Elev-*Hidd*" "*-Elev-*Bgrd*" "*-Elev-*Nplt*" "*-Elev-*Scrn*") *lst))
      )
    )
    (if (member "Fstk" *lst) 
      (progn 
        (setq *lst (vl-remove "Fstk" *lst))
        (if (or (= 0 *ctr) (= 2 *ctr)) 
          ;; item to show (with out asterix; selected phase only):
          (setq *lst (append '("*-0001" "*-0002" "*-0003" "*-0004" "*-0005" "*-0006" "*-0007" "*-0008" "*-0009") 
                             *lst
                     )
          )
          ;; item to Hide (with asterix; all phase):
          (setq *lst (append 
                       '("*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
                       *lst
                     )
          )
        )
      )
    )
    (if (member "Demo" *lst) 
      (progn 
        (setq *lst (vl-remove "Demo" *lst))
        (setq *lst (append '("*-D" "*-S" "*-T") *lst))
      )
    )
    (if (member "Neww" *lst) 
      (progn 
        (setq *lst (vl-remove "Neww" *lst))
        (setq *lst (append '("*-N" "*-M" "*-R") *lst))
      )
    )
    (if (member "Exst" *lst) 
      (progn 
        (setq *lst (vl-remove "Exst" *lst))
        (setq *lst (append '("*-@@??" "*-E" "*-X") *lst))
      )
    )
    (if (member "Futw" *lst) 
      (progn 
        (setq *lst (vl-remove "Futw" *lst))
        (setq *lst (append '("*-F") *lst))
      )
    )
    (if (member "Abnd" *lst) 
      (progn 
        (setq *lst (vl-remove "Abnd" *lst))
        (setq *lst (append '("*-A") *lst))
      )
    )
    (if (member "Ustk" *lst) 
      (progn 
        (setq *lst (vl-remove "Ustk" *lst))
        (setq *lst (append '("*-@@??" "*-@@??-?") *lst))
      )
    )

    ;; overwrite nil value as a list with "Empty" string:
    (if (= nil *lst) (setq *lst '("Empty")))

    ;; construct the output list of list:
    (setq *out (cons *lst *out))

    ;; counter increment used for the FullStack condition:
    (setq *ctr (1+ *ctr))
  )
  (setq *out (reverse *out))
  (setq *shw (nth 0 *out)
        *hid (nth 1 *out)
        *sh2 (nth 2 *out)
        *hi2 (nth 3 *out)
        *scn (nth 4 *out)
  )


  ;;---------------------------------------------------------------------------------------

  ;;TODO finish removing asterix from to show list
  ;; Add phasing to all the selected group:
  (if (wcmatch *msg "*Existing*") 
    (progn 
      (if (and (not (wcmatch *msg "*New*")) (not (wcmatch *msg "*Demo*"))) 
        (progn 
          (foreach x *shw 
            (setq *shw (cons (strcat x "-E") *shw)
                  *shw (cons (strcat x "-X") *shw)
            )
          )
          (foreach x *sh2 
            (setq *sh2 (cons (strcat x "-E") *sh2)
                  *sh2 (cons (strcat x "-X") *sh2)
            )
          )
        )
      )
      (if (wcmatch *msg "*New*") 
        (progn 
          (foreach x *shw 
            (setq *shw (cons (strcat x "-E") *shw)
                  *shw (cons (strcat x "-X") *shw)
                  *shw (cons (strcat x "-N") *shw)
                  *shw (cons (strcat x "-R") *shw)
                  *shw (cons (strcat x "-M") *shw)
            )
          )
          (foreach x *sh2 
            (setq *sh2 (cons (strcat x "-E") *sh2)
                  *sh2 (cons (strcat x "-X") *sh2)
                  *sh2 (cons (strcat x "-N") *sh2)
                  *sh2 (cons (strcat x "-R") *sh2)
                  *sh2 (cons (strcat x "-M") *sh2)
            )
          )
        )
      )
      (if (wcmatch *msg "*Demo*") 
        (progn 
          (foreach x *shw 
            (setq *shw (cons (strcat x "-E") *shw)
                  *shw (cons (strcat x "-X") *shw)
                  *shw (cons (strcat x "-D") *shw)
                  *shw (cons (strcat x "-S") *shw)
                  *shw (cons (strcat x "-T") *shw)
            )
          )
          (foreach x *sh2 
            (setq *sh2 (cons (strcat x "-E") *sh2)
                  *sh2 (cons (strcat x "-X") *sh2)
                  *sh2 (cons (strcat x "-D") *sh2)
                  *sh2 (cons (strcat x "-S") *sh2)
                  *sh2 (cons (strcat x "-T") *sh2)
            )
          )
        )
      )
    )
  )


  ;; Convert all the list into string to process in the layer command:
  (if (= 0 (length *shw)) 
    (setq *shw "Empty")
    (setq *shw (Local>>LM:lst->str *shw ","))
  )
  (if (= 0 (length *hid)) 
    (setq *hid "Empty")
    (setq *hid (Local>>LM:lst->str *hid ","))
  )
  (if (= 0 (length *sh2)) 
    (setq *sh2 "Empty")
    (setq *sh2 (Local>>LM:lst->str *sh2 ","))
  )
  (if (= 0 (length *hi2)) 
    (setq *hi2 "Empty")
    (setq *hi2 (Local>>LM:lst->str *hi2 ","))
  )
  (if (= 0 (length *scn)) 
    (setq *scn "Empty")
    (setq *scn (Local>>LM:lst->str *scn ","))
  )



  ;; main command
  (if (= 1 (getvar "tilemode")) 

    ;;  if in model space
    (progn 
      (command "undo" "mark")
      (setq *dyl-marked T)

      ;: Initial reset
      (command "-layer" "TR" "0" "*" "U" "*" "")

      ;; Startup state switch
      (if (= "Empty" *str) 
        (command "-layer" "Set" "0" "Off" "*" "No" "Freeze" "*" "")
      )
      (if (= "AllVisible" *str) 
        (command "-layer" "On" "*" "Thaw" "*" "")
      )

      ;: Layer visibility filter
      (command "-layer" "ON" *shw "T" *shw "OFF" *hid "F" *hid "ON" *sh2 "T" *sh2 "OFF" *hi2 "F" *hi2 "")

      ;: Layer utility
      (command "-layer" "TR" "50" *scn "")
      (if (= "Yes" *lck) (command "-layer" "LO" *scn ""))

      ;: clean exit
      (setq *dyl-marked nil)
      (princ (strcat "Layer filter set to: " *msg))
      (command "_.regen")
      (princ)
    )

    ;;  if in paper space:
    (progn 
      (prompt "\nSelect Viewport(s): ")
      (setq *ss (ssget))
      (if *ss 
        (progn 
          (setq *vps (ssget "P" '((0 . "VIEWPORT"))))
          (if (not *vps) 
            (prompt "\nNo viewports in selection. Please select viewport objects only.")
            (progn 
              (if (< (sslength *vps) (sslength *ss)) 
                (prompt "\nNote: Non-viewport objects were ignored.")
              )
              (command "undo" "mark")
              (setq *dyl-marked T)

              ;; Startup state switch (mirrors the model-space switch above):
              (if (= "Empty" *str) 
                (command "vplayer" "F" "*" "S" *vps "" "")
              )
              (if (= "AllVisible" *str) 
                (command "vplayer" "T" "*" "S" *vps "" "")
              )

              ;: Layer visibility filter (only send the operations whose list is non-empty;
              ;: feeding "Empty" straight to VPLAYER as a layer name can desync its prompts)
              (setq *vpa (list "vplayer"))
              (if (not (= *shw "Empty")) (setq *vpa (append *vpa (list "T" *shw "S" *vps ""))))
              (if (not (= *hid "Empty")) (setq *vpa (append *vpa (list "F" *hid "S" *vps ""))))
              (if (not (= *sh2 "Empty")) (setq *vpa (append *vpa (list "T" *sh2 "S" *vps ""))))
              (if (not (= *hi2 "Empty")) (setq *vpa (append *vpa (list "F" *hi2 "S" *vps ""))))
              (if (> (length *vpa) 1) (apply 'command (append *vpa (list ""))))

              ;: Layer utility
              (if (not (= *scn "Empty")) 
                (command "vplayer" "TR" "50" *scn "S" *vps "" "")
              )

              (setq *dyl-marked nil)
              (prompt (strcat "\nSelected Viewport(s) layer filter set to: " *msg))
              (princ)
            )
          )
        )
        (prompt "\nNo viewports selected.")
      )
    )
  )
  (*pop-error-mode*)
  (setvar 'cmdecho *cme)
  (princ)
)


  ;; List to String  -  Lee Mac
  ;; Concatenates each string in a supplied list, separated by a given delimiter
  ;; lst - [lst] List of strings to concatenate
  ;; del - [str] Delimiter string to separate each item
(defun Local>>LM:lst->str (lst del) 
  (if (cdr lst) 
    (strcat (car lst) del (Local>>LM:lst->str (cdr lst) del))
    (car lst)
  )
)


;;-------------------------=={ Commands }==------------------------;;

;;  The filter presets are the child commands Pst-* below, run by their aliases
;;  (SH-ALL, E1...) or picked in the Dyl-LayFilter dialog.

;; Layer Filters
;; Lists the layer filter presets with their aliases and applies the one picked.

(defun c:Dyl-LayFilter ()
  (Dyl:ChildPicker "Dyl-LayerFilter.lsp" "Layer Filters" "Double-click a filter (or OK) to apply it. In a layout, select the viewports next." '*lf:last*)
)

;#region Architectural

;; Architectural Floor Plan Filter
;; Sets the layer visibility to show only the architectural floor plan layers.

(defun c:Pst-ArchitecturalFloorPlanFilter (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("A-Flor")
        *hid '()
        *sh2 '()
        *hi2 '()
        *scn '()
        *lck "No"
        *msg "Architectural floor plan"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)


;#endregion

;#region Basic to Show

;; Show All Layers
;; Turns on and thaws every layer of the drawing, xrefs included.

(defun c:Pst-ShowAllLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '("*")
        *hid '()
        *sh2 '()
        *hi2 '()
        *scn '()
        *lck "No"
        *msg "Show All (Xref included)"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Show Non-Plotting Layers
;; Turns on and thaws the Defpoints, non-plotting and readme layers.

(defun c:Pst-ShowNonPlottingLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '("Defpoints" "*Nptl*" "*Rdme*")
        *hid '()
        *sh2 '()
        *hi2 '()
        *scn '()
        *lck "No"
        *msg "Show Non-Plotting Only"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Show New Work Layers
;; Turns on and thaws the new work phase layers.

(defun c:Pst-ShowNewWorkLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '("Neww")
        *hid '()
        *sh2 '()
        *hi2 '()
        *scn '()
        *lck "No"
        *msg "Show Existing to remain + New"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Show Demolition Layers
;; Turns on and thaws the existing to demolish phase layers.

(defun c:Pst-ShowDemolitionLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '("Demo")
        *hid '()
        *sh2 '()
        *hi2 '()
        *scn '()
        *lck "No"
        *msg "Show Existing to remain + Demo"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Show Existing Layers
;; Turns on and thaws the existing to remain phase layers.

(defun c:Pst-ShowExistingLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '("Exst")
        *hid '()
        *sh2 '()
        *hi2 '()
        *scn '()
        *lck "No"
        *msg "Show Existing to remain Only"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Show Key Plan Layers
;; Turns on and thaws the key plan layers.

(defun c:Pst-ShowKeyPlanLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '("*-Keyp*")
        *hid '()
        *sh2 '()
        *hi2 '()
        *scn '()
        *lck "No"
        *msg "Show Key Plan Only"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)
;#endregion


;#region Basic to Hide

;; Hide All Layers
;; Turns off and freezes every layer of the drawing, xrefs included.

(defun c:Pst-HideAllLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '("*")
        *scn '()
        *lck "No"
        *msg "Hide All (Xref included)"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Hide Annotation Layers
;; Turns off and freezes the annotation layers.

(defun c:Pst-HideAnnotationLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '("Annotation")
        *scn '()
        *lck "No"
        *msg "Hide All (Xref included)"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Hide Membrane Layers
;; Turns off and freezes the vapour, air and water membrane layers.

(defun c:Pst-HideMembraneLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '("*-Vapr*" "*-Air*" "*-Watr*")
        *scn '()
        *lck "No"
        *msg "Hide All (Xref included)"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Screen Existing Layers
;; Applies a 50 percent screening transparency to the existing layers.

(defun c:Pst-ScreenExistingLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '()
        *scn '("*-E")
        *lck "No"
        *msg "Existing layer screening applied"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Hide Non-Plotting Layers
;; Turns off and freezes the Defpoints, non-plotting and readme layers.

(defun c:Pst-HideNonPlottingLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '("Defpoints" "*Nptl*" "*Rdme*")
        *scn '()
        *lck "No"
        *msg "Hide Non-Plotting Layers Only"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Hide New Work Layers
;; Turns off and freezes the new work phase layers.

(defun c:Pst-HideNewWorkLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '("Neww")
        *scn '()
        *lck "No"
        *msg "Hide New Work Only"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Hide Demolition Layers
;; Turns off and freezes the existing to demolish phase layers.

(defun c:Pst-HideDemolitionLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '("Demo")
        *scn '()
        *lck "No"
        *msg "Hide Existing to demolish Only"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Hide Existing Layers
;; Turns off and freezes the existing to remain phase layers.

(defun c:Pst-HideExistingLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '("Exst")
        *scn '()
        *lck "No"
        *msg "Hide Existing to remain Only"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Hide Key Plan Layers
;; Turns off and freezes the key plan layers.

(defun c:Pst-HideKeyPlanLayers (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Curent"
        *shw '()
        *hid '()
        *sh2 '()
        *hi2 '("*-Keyp*")
        *scn '()
        *lck "No"
        *msg "Hide Key Plan Only"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)
;#endregion


;#region Stacked

;; Existing View Stack 0001
;; Shows the existing to remain layers of stack 0001 with the upper stacks screened.

(defun c:Pst-ExistingViewStack0001 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden")
        *sh2 '("Ustk" "*-0001*")
        *hi2 '("Demo" "Neww")
        *scn '("*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0001"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Existing View Stack 0002
;; Shows the existing to remain layers of stack 0002 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-ExistingViewStack0002 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*")
        *sh2 '("Ustk" "*-0002*")
        *hi2 '("Demo" "Neww")
        *scn '("*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0002"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Existing View Stack 0003
;; Shows the existing to remain layers of stack 0003 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-ExistingViewStack0003 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*")
        *sh2 '("Ustk" "*-0003*")
        *hi2 '("Demo" "Neww")
        *scn '("*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0003"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Existing View Stack 0004
;; Shows the existing to remain layers of stack 0004 with the lower stacks hidden and the upper stacks screened.

(Defun c:Pst-ExistingViewStack0004 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*")
        *sh2 '("Ustk" "*-0004*")
        *hi2 '("Demo" "Neww")
        *scn '("*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0004"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Existing View Stack 0005
;; Shows the existing to remain layers of stack 0005 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-ExistingViewStack0005 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*")
        *sh2 '("Ustk" "*-0005*")
        *hi2 '("Demo" "Neww")
        *scn '("*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0005"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Existing View Stack 0006
;; Shows the existing to remain layers of stack 0006 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-ExistingViewStack0006 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*")
        *sh2 '("Ustk" "*-0006*")
        *hi2 '("Demo" "Neww")
        *scn '("*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0006"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Existing View Stack 0007
;; Shows the existing to remain layers of stack 0007 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-ExistingViewStack0007 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*")
        *sh2 '("Ustk" "*-0007*")
        *hi2 '("Demo" "Neww")
        *scn '("*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0007"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Existing View Stack 0008
;; Shows the existing to remain layers of stack 0008 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-ExistingViewStack0008 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" 
               "*-0007*"
              )
        *sh2 '("Ustk" "*-0008*")
        *hi2 '("Demo" "Neww")
        *scn '("*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0008"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Existing View Stack 0009
;; Shows the existing to remain layers of stack 0009 with the lower stacks hidden.

(defun c:Pst-ExistingViewStack0009 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("*-@@??" "Exst")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" 
               "*-0007*" "*-0008*"
              )
        *sh2 '("Ustk" "*-0009*")
        *hi2 '("Demo" "Neww")
        *scn '()
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0009"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Architecture
;; Shows the existing and demolition layers with the new architectural group screened.

(defun c:Pst-DemolitionViewArchitecture (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden")
        *sh2 '("Ustk" "*-0001*")
        *hi2 '("Neww")
        *scn '("N-Architectural" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + Demo - Architecture"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)


;; Demolition View Stack 0001
;; Shows the existing and demolition layers of stack 0001 with the upper stacks screened.

(defun c:Pst-DemolitionViewStack0001 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden")
        *sh2 '("Ustk" "*-0001*")
        *hi2 '("Neww" "*-F")
        *scn '("*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0001"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Stack 0002
;; Shows the existing and demolition layers of stack 0002 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-DemolitionViewStack0002 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*")
        *sh2 '("Ustk" "*-0002*")
        *hi2 '("Neww")
        *scn '("*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0002"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Stack 0003
;; Shows the existing and demolition layers of stack 0003 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-DemolitionViewStack0003 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*")
        *sh2 '("Ustk" "*-0003*")
        *hi2 '("Neww")
        *scn '("*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0003"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Stack 0004
;; Shows the existing and demolition layers of stack 0004 with the lower stacks hidden and the upper stacks screened.

(Defun c:Pst-DemolitionViewStack0004 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*")
        *sh2 '("Ustk" "*-0004*")
        *hi2 '("Neww")
        *scn '("*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0004"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Stack 0005
;; Shows the existing and demolition layers of stack 0005 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-DemolitionViewStack0005 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*")
        *sh2 '("Ustk" "*-0005*")
        *hi2 '("Neww")
        *scn '("*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0005"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Stack 0006
;; Shows the existing and demolition layers of stack 0006 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-DemolitionViewStack0006 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*")
        *sh2 '("Ustk" "*-0006*")
        *hi2 '("Neww")
        *scn '("*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0006"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Stack 0007
;; Shows the existing and demolition layers of stack 0007 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-DemolitionViewStack0007 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*")
        *sh2 '("Ustk" "*-0007*")
        *hi2 '("Neww")
        *scn '("*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0007"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Stack 0008
;; Shows the existing and demolition layers of stack 0008 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-DemolitionViewStack0008 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" 
               "*-0007*"
              )
        *sh2 '("Ustk" "*-0008*")
        *hi2 '("Neww")
        *scn '("*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0008"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; Demolition View Stack 0009
;; Shows the existing and demolition layers of stack 0009 with the lower stacks hidden.

(defun c:Pst-DemolitionViewStack0009 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Demo" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" 
               "*-0007*" "*-0008*"
              )
        *sh2 '("Ustk" "*-0009*")
        *hi2 '("Neww")
        *scn '()
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0009"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Architecture
;; Shows the existing and new work layers with the new architectural group screened.

(defun c:Pst-NewWorkViewArchitecture (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden")
        *sh2 '("Ustk" "*-0001*")
        *hi2 '("Demo")
        *scn '("N-Architectural" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Architecture"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Structure
;; Shows the existing and new work layers with the new structural group screened.

(defun c:Pst-NewWorkViewStructure (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden")
        *sh2 '("Ustk" "*-0001*")
        *hi2 '("Demo")
        *scn '("N-Structural" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Architecture"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)



;; New Work View Stack 0001
;; Shows the existing and new work layers of stack 0001 with the upper stacks screened.

(defun c:Pst-NewWorkViewStack0001 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden")
        *sh2 '("Ustk" "*-0001*")
        *hi2 '("Demo" "*-F")
        *scn '("*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0001"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Stack 0002
;; Shows the existing and new work layers of stack 0002 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-NewWorkViewStack0002 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*")
        *sh2 '("Ustk" "*-0002*")
        *hi2 '("Demo")
        *scn '("*-0003*" "*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0002"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Stack 0003
;; Shows the existing and new work layers of stack 0003 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-NewWorkViewStack0003 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*")
        *sh2 '("Ustk" "*-0003*")
        *hi2 '("Demo")
        *scn '("*-0004*" "*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0003"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Stack 0004
;; Shows the existing and new work layers of stack 0004 with the lower stacks hidden and the upper stacks screened.

(Defun c:Pst-NewWorkViewStack0004 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*")
        *sh2 '("Ustk" "*-0004*")
        *hi2 '("Demo")
        *scn '("*-0005*" "*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Number 0004"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Stack 0005
;; Shows the existing and new work layers of stack 0005 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-NewWorkViewStack0005 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*")
        *sh2 '("Ustk" "*-0005*")
        *hi2 '("Demo")
        *scn '("*-0006*" "*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0005"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Stack 0006
;; Shows the existing and new work layers of stack 0006 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-NewWorkViewStack0006 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*")
        *sh2 '("Ustk" "*-0006*")
        *hi2 '("Demo")
        *scn '("*-0007*" "*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0006"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Stack 0007
;; Shows the existing and new work layers of stack 0007 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-NewWorkViewStack0007 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*")
        *sh2 '("Ustk" "*-0007*")
        *hi2 '("Demo")
        *scn '("*-0008*" "*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0007"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Stack 0008
;; Shows the existing and new work layers of stack 0008 with the lower stacks hidden and the upper stacks screened.

(defun c:Pst-NewWorkViewStack0008 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" 
               "*-0007*"
              )
        *sh2 '("Ustk" "*-0008*")
        *hi2 '("Demo")
        *scn '("*-0009*")
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0008"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)

;; New Work View Stack 0009
;; Shows the existing and new work layers of stack 0009 with the lower stacks hidden.

(defun c:Pst-NewWorkViewStack0009 (/ *shw *hid *sh2 *hi2 *scn *lck *msg) 
  (setq *str "Empty"
        *shw '("Ustk" "Exst" "Neww" "Fstk")
        *hid '("Annotation" "Pattern" "Highlight" "Hidden" "*-0001*" "*-0002*" "*-0003*" "*-0004*" "*-0005*" "*-0006*" 
               "*-0007*" "*-0008*"
              )
        *sh2 '("Ustk" "*-0009*")
        *hi2 '("Demo")
        *scn '()
        *lck "No"
        *msg "Existing to remain + New - Stack Number 0009"
  )
  (Dyl-LayFilter *shw *hid *sh2 *hi2 *scn *lck *msg)
)
;#endregion