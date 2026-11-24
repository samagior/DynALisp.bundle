;; Manager - The windows that set up the drawing tools, as the tabs of one window
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

;;  The Manager: the preset windows of the drawing tools (Quick Draw, Assembly Presets, Quick
;;  Shape, Materials, Hatch Presets) as the tabs of one window, DynALisp - Manager. Each tab
;;  is the window of its tool as it is, run by its own Lisp (Remote>>Dyl:PresetDialog): the
;;  Manager shows the window of the tab picked with the tabs above it (*dyl:wintabs*, see
;;  the Windows region of dynalisp.mnl and Installer\Windows\Engine\Tabs.cs). Another tab
;;  picked closes the window with *dyl:wintabcode*: the tool saves what was edited in its
;;  tab, as Save (Remote>>Dyl:PresetWin), and the Manager shows the window of the tab picked,
;;  at the same place. Cancel or OK of a tab ends the Manager; Draw draws the preset of Quick
;;  Draw or Quick Shape, then shows the Manager again.
;;
;;  The window is modeless, so the user draws while it is open (Modeless of
;;  Installer\Windows\Engine\Tabs.cs): Remote>>Dyl:Manager shows it and ends. A button that
;;  needs the Lisp (a tab, Save, Draw, an open button) leaves it open, disabled, and runs
;;  (Remote>>Dyl:ManagerEvent key tab) at the command line, the command running cancelled
;;  first: the Lisp of the tab runs again as if it had just shown its window, and gets that
;;  button with the values of the window. The window it shows next replaces it in place.
;;
;;  A window opened from a tab (Materials from Quick Draw, Hatch Presets from Materials) is
;;  a sub-window of that tab, without tabs, and gives back to it what was picked.
;;
;;  The main commands of the tools open the Manager on their tab (c:Dyl-QuickDraw,
;;  c:Dyl-Materials...), c:Dyl-Manager (Apps\Draw\Dyl-Manager.lsp) on the tab shown last.
;;  The tabs listed are those of the Apps turned on in the Startup Suite, with the tab asked
;;  for; an App turned on is only autoloaded, so it is loaded the first time its tab is shown
;;  (Dyl:SuiteFileLoad).
;;
;;    (Remote>>Dyl:Manager key)   -> the Manager on the tab key ("QuickDraw", "Materials"...;
;;                                   nil: the tab shown last)

;;  The tabs, in their order: (key title window app dialog run):
;;    key     the tab, as the commands name it
;;    title   its title in the row of tabs
;;    window  the window file of its tool (Res), the window that gets the tabs
;;    app     the Apps file of the tool (PATH of StartupSuite.csv): the tab is listed while
;;            it is turned on, and it is loaded when dialog is not defined yet
;;    dialog  the function that shows the window of the tool (no argument), and returns what
;;            to draw (nil: nothing)
;;    run     the function that draws what dialog returned (nil: the tool draws nothing)
(setq *dyl:mgrtabs*
       '(("QuickDraw" "Quick Draw" "Dyl-QuickDraw.xaml" "Dynalisp\\Apps\\Draw\\Dyl-QuickDraw.lsp" Dyl:QuickDrawDialog Dyl:QuickDrawRun)
         ("Assemblies" "Assembly Presets" "Dyl-AssemblyPresets.xaml" "Dynalisp\\Apps\\Draw\\Dyl-QuickDraw.lsp" Dyl:QuickDrawAsmManager nil)
         ("QuickShape" "Quick Shape" "Dyl-QuickShape.xaml" "Dynalisp\\Apps\\Draw\\Dyl-QuickShape.lsp" Dyl:QuickShapeDialog Dyl:QuickShapeRun)
         ("Materials" "Materials" "Dyl-Materials.xaml" "Dynalisp\\Apps\\Draw\\Dyl-Materials.lsp" Remote>>Dyl:ManagerMaterials nil)
         ("HatchPresets" "Hatch Presets" "Dyl-HatchPresets.xaml" "Dynalisp\\Apps\\Draw\\Dyl-HatchPresets.lsp" Remote>>Dyl:ManagerHatchPresets nil)
        )
)

;;  The title of the window, and where it is kept (DynalispWindowPlaces, whatever its tab):
(setq *dyl:mgrtitle* "DynALisp - Manager"
      *dyl:mgrplace* "Dyl-Manager"
)

;;  The tab shown last during the session:
(if (not *dyl:mgrlast*) (setq *dyl:mgrlast* "QuickDraw"))

;;  The tabs of the Manager opened on the tab key: those of the Apps turned on, and key:
(defun Remote>>Dyl:ManagerTabs (key)
  (vl-remove-if-not '(lambda (tab) (or (= key (car tab)) (Dyl:SuiteFileOn-p (nth 3 tab)))) *dyl:mgrtabs*)
)

;;  The window of the tool of tab (its App loaded first, once). Returns what to draw, nil
;;  when the window was closed otherwise, or could not be shown:
(defun Remote>>Dyl:ManagerShow (tab / f)
  (setq f (nth 4 tab))
  (if (not (eval f)) (Dyl:SuiteFileLoad (nth 3 tab)))
  (if (eval f)
    (apply f nil)
    (progn (princ (strcat "\n--> " (nth 1 tab) ": " (nth 3 tab) " could not be loaded.")) nil)
  )
)

;;  The Manager on the tab key (nil: the tab shown last), then the window of each tab picked
;;  until one is closed (OK, Cancel, Draw). What was drawn is drawn once it is closed.
;;  The window is modeless (see the top of this file): this call shows it and returns nil,
;;  and each button that needs the Lisp runs Remote>>Dyl:ManagerEvent, which runs it again
;;  on the tab of the window (*dyl:mgrevent*):
(defun Remote>>Dyl:Manager (key / *dyl:wintabs* *dyl:wintab* tabs i tab res r)
  (setq key  (cond (key) (*dyl:mgrlast*))
        tabs (Remote>>Dyl:ManagerTabs key)
        i    (cond ((vl-position (assoc (cond (*dyl:mgrevent*) (key)) tabs) tabs)) (0))
  )
  (while (and i (setq tab (nth i tabs)))
    (setq *dyl:mgrlast* (car tab)
          *dyl:wintabs* (list (nth 2 tab) (mapcar 'cadr tabs) i *dyl:mgrtitle* *dyl:mgrplace*
                              ;;  the event of its buttons: the Manager on the same tabs, this tab
                              (strcat "(Remote>>Dyl:ManagerEvent \"" key "\" \"" (car tab) "\")")
                        )
          *dyl:wintab*  nil
          res           (Remote>>Dyl:ManagerShow tab)
          ;;  another tab picked (see Dyl:WinShow), else the Manager is closed:
          i             *dyl:wintab*
    )
  )
  (cond
    ((not (and res tab (nth 5 tab))))
    ;;  Draw clicked in the modeless window: closed while drawing, then shown again on its tab
    ;;  (Escape ends the drawing, not the Manager):
    (*dyl:mgrevent*
     (if Dyl:WindowDone (Dyl:WindowDone))
     (if (and (vl-catch-all-error-p (setq r (vl-catch-all-apply (nth 5 tab) (list res))))
              (not (wcmatch (strcase (vl-catch-all-error-message r)) "*CANCEL*,*QUIT*,*EXIT*"))
         )
       (princ (strcat "\n--> " (nth 1 tab) ": " (vl-catch-all-error-message r)))
     )
     (setq *dyl:mgrevent* (car tab))
     (Remote>>Dyl:Manager key)
    )
    ((apply (nth 5 tab) (list res)))
  )
  res
)

;;  A button of the Manager that needs the Lisp, run at the command line (key: the tab the
;;  Manager was opened on, tab: the tab of the window): the tool of the tab runs again and
;;  gets the button from its window, as from a modal window. The window is closed when the
;;  Lisp did not show it again (OK, Cancel, an error):
(defun Remote>>Dyl:ManagerEvent (key tab / *dyl:mgrevent* r)
  (setq *dyl:mgrevent* tab
        r              (vl-catch-all-apply 'Remote>>Dyl:Manager (list key))
  )
  (if Dyl:WindowDone (Dyl:WindowDone))
  (if (vl-catch-all-error-p r)
    (princ (strcat "\n--> " *dyl:mgrtitle* ": " (vl-catch-all-error-message r)))
  )
  (princ)
)

;;  The tabs of the tools whose windows are in Remote (no App to load):
(defun Remote>>Dyl:ManagerMaterials () (Remote>>Dyl:MaterialDialog nil) nil)
(defun Remote>>Dyl:ManagerHatchPresets () (Remote>>Dyl:HatchPresetDialog nil) nil)

(princ)
