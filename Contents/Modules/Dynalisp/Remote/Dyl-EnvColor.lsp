;; Dyl-EnvColor - Dynalisp display colors: interface, backgrounds, crosshairs
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
;;  The display settings of Dyl-Settings (Display in Overrides, its open button opening
;;  the display window). Display on (DynalispDisplayOn user setting, off by default),
;;  each drawing opened applies the display settings chosen (Remote>>Dyl:DisplayApply,
;;  run by dynalisp.mnl); off, the display preferences are left as they are. The theme
;;  of AutoCAD (COLORTHEME) is never set here: it is the one chosen in AutoCAD.
;;
;;  Each display setting is a name, "" or missing: not set:
;;    - Interface (DynalispInterface): the look of the whole interface, DynALisp Dark
;;      (the default, first in the list), Midnight, Blueprint, Forest, Ember or Plum
;;      (*ec:looks*). Its ribbon, palettes (Properties...), status bar,
;;      file tabs, command line and Start page, while AutoCAD is in its dark theme, by
;;      DynALisp.Ribbon.dll (Installer\Ribbon\Plugin\Skin.cs, an experiment that Autodesk
;;      does not support), which reads these settings itself and again when
;;      (Dyl:RibbonSkin) is called; and the model space background, the paper of the
;;      layouts and the background around it, set here. Not set: the colors of AutoCAD.
;;    - Model space (DynalispBackground): the model space background in place of the one
;;      of the interface, Black, Default (blue-grey, the AutoCAD default) or White, the
;;      rest of the interface left as it is. Not set: the one of the interface.
;;    - Layouts (DynalispLayoutBackground): the paper of the layouts in place of the one
;;      of the interface, White or Black, the background around it left to the
;;      interface. Not set: the one of the interface.
;;  Each background comes with a crosshair color that stays readable on it. DynALisp Dark
;;  is a neutral grey, without hue: the model space and the background around the paper
;;  almost black (#121212), the paper a little lighter (#1E1E1E), the crosshairs light
;;  grey (#E6E6E6), the ribbon, the palettes and the DynALisp windows in greys without
;;  hue. Midnight is the blue-grey of AutoCAD, darker (the dark windows of DynALisp,
;;  Installer\Windows\Engine\Session.cs, Theme): the model space and the background
;;  around the paper almost black in that blue (#14171B), the paper a little lighter
;;  (#1F232A), the crosshairs in the color of their text (#E6EAF0). Blueprint (the navy of
;;  old blueprints, #102A46), Forest (a fir green, #101E17), Ember (a warm charcoal,
;;  #1E1510) and Plum (an aubergine, #1D1221) are the same in their hue, the ribbon, the
;;  palettes and the windows tinted with it. The colors
;;  are the display preferences (Options > Display > Colors), the background around the
;;  paper the "Paper background" setting of the profile, which Options does not show:
;;  user profile settings, so they apply to every drawing.
;;
;;    - File tabs (DynalispFileTabColors): Project or Sheet set, a band of colour on the
;;      file tab of each drawing of a project (the first folder holding a .apj from the
;;      folder of the drawing up, as Remote>>Dyl:RevProject) or of a sheet set (a .dst, as
;;      Dyl-OpenFolder), the same colour for every drawing of a project: done by
;;      DynALisp.Ribbon.dll (Installer\Ribbon\Plugin\FileTabs.cs), an experiment too, which
;;      reads these settings itself and again when (Dyl:RibbonFileTabs) is called.
;;
;;  The former settings Ribbon and Palettes (DynalispRibbonColors, DynalispPaletteColors)
;;  are read as the Interface while it is not set, and Theme (DynalispColorTheme) is no
;;  longer applied. The former names of the looks (*ec:lookwas*: DynALisp Neutral, now
;;  DynALisp Dark, and DynALisp, now Midnight) are read as their new names, and written
;;  so at the next save of the settings; the plugins read both.
;;
;;  Use in an App:
;;    (Remote>>Dyl:DisplayWant 'model)         -> (NAME BACKGROUND CROSSHAIR [AROUND])
;;                                                wanted, nil when not set
;;    (Remote>>Dyl:DisplayHas 'model)          -> T when the current colors are those
;;    (Remote>>Dyl:DisplayApply)               -> applies the display settings, returns
;;                                                a status line

(vl-load-com)

;;  The looks of the interface: (NAME MODEL MODEL-CROSSHAIR PAPER PAPER-CROSSHAIR AROUND),
;;  colors as OLE values: R + G*256 + B*65536.
(setq *ec:looks*
       '(("DynALisp Dark" 1184274 15132390 1973790 15132390 1184274) ; RGB 18,18,18 / 230,230,230 / 30,30,30
         ("Midnight" 1775380 15788774 2761503 15788774 1775380) ; RGB 20,23,27 / 230,234,240 / 31,35,42
         ("Blueprint" 4598288 16248286 5978138 16248286 4598288) ; RGB 16,42,70 / 222,237,247 / 26,56,91
         ("Forest" 1515024 14543830 2239001 14543830 1515024) ; RGB 16,30,23 / 214,235,221 / 25,42,34
         ("Ember" 1053982 13689585 1646122 13689585 1053982) ; RGB 30,21,16 / 241,226,208 / 42,30,25
         ("Plum" 2167325 15784940 2955816 15784940 2167325) ; RGB 29,18,33 / 236,219,240 / 40,26,45
        )
)

;;  The former names of the looks, read as their new names: (FORMER . NAME).
(setq *ec:lookwas* '(("DynALisp Neutral" . "DynALisp Dark") ("DynALisp" . "Midnight")))

;;  The backgrounds that take the place of those of the interface: (CONTEXT
;;  (BACKGROUND-PROP CROSSHAIR-PROP) (NAME BACKGROUND CROSSHAIR) ...).
(setq *ec:colors*
       '((model (graphicswinmodelbackgrndcolor modelcrosshaircolor)
                ("Black" 0 16777215)
                ("Default" 3155999 16777215) ; RGB 33,40,48
                ("White" 16777215 0)
         )
         (layout (graphicswinlayoutbackgrndcolor layoutcrosshaircolor)
                 ("White" 16777215 0)
                 ("Black" 0 16777215)
         )
        )
)

;;  The display settings, in this order: (KEY CONTEXT), CONTEXT interface, model or
;;  layout:
(setq *ec:prefs* '(("DynalispInterface" interface)
                   ("DynalispBackground" model)
                   ("DynalispLayoutBackground" layout)
                   ("DynalispFileTabColors" tabs)
                  )
)

(defun ec:display () (vla-get-display (vla-get-preferences (vlax-get-acad-object))))

;;  The background around the paper of the layouts, an OLE color (nil: never set):
(defun ec:around (/ v)
  (if (and (setq v (getenv "Paper background")) (/= "" v)) (atoi v))
)

;;  A display preference as an OLE color, nil when it cannot be read:
(defun ec:get (prop / c)
  (if (not (vl-catch-all-error-p
             (setq c (vl-catch-all-apply
                       '(lambda () (vlax-variant-value (vlax-variant-change-type (vlax-get-property (ec:display) prop) vlax-vblong)))
                     )
             )
           )
      )
    c
  )
)

;;  Names of the choices of a context (interface, model, layout or tabs):
(defun Remote>>Dyl:DisplayNames (ctx)
  (cond
    ((= ctx 'tabs) '("Project" "Sheet set"))
    ((mapcar 'car (if (= ctx 'interface) *ec:looks* (cddr (assoc ctx *ec:colors*)))))
  )
)

;;  The ribbon plugin told that the settings changed: what it does with the ribbon
;;  ("DynALisp", "off"...), nil when it is not loaded:
(defun ec:ribbon ()
  (if Dyl:RibbonSkin (Dyl:RibbonSkin))
)

;;  What a context (model or layout) is set to while Display is on: (NAME BACKGROUND
;;  CROSSHAIR [AROUND]), the background chosen in place of the one of the interface, or
;;  the one of the interface; the background around the paper is the one of the
;;  interface. nil when neither is set:
(defun Remote>>Dyl:DisplayWant (ctx / pref own look)
  (setq pref (Remote>>Dyl:DisplayPref)
        own  (assoc (if (= ctx 'model) (cadr pref) (caddr pref)) (cddr (assoc ctx *ec:colors*)))
        look (assoc (car pref) *ec:looks*)
  )
  (cond
    ((= ctx 'model) (cond (own) (look (list (car look) (nth 1 look) (nth 2 look)))))
    ((or own look)
     (append (cond (own) ((list (car look) (nth 3 look) (nth 4 look)))) (if look (list (nth 5 look))))
    )
  )
)

;;  T when the colors of a context are those it is set to (or nothing is wanted):
(defun Remote>>Dyl:DisplayHas (ctx / w props)
  (setq w     (Remote>>Dyl:DisplayWant ctx)
        props (cadr (assoc ctx *ec:colors*))
  )
  (or (not w)
      (and (= (cadr w) (ec:get (car props)))
           (= (caddr w) (ec:get (cadr props)))
           (or (not (cadddr w)) (eq (cadddr w) (ec:around)))
      )
  )
)

;;  Set a context to what it is wanted to be (Remote>>Dyl:DisplayWant), its name:
(defun ec:set (ctx / w props)
  (if (setq w (Remote>>Dyl:DisplayWant ctx))
    (progn
      (setq props (cadr (assoc ctx *ec:colors*)))
      (vlax-put-property (ec:display) (car props) (cadr w))
      (vlax-put-property (ec:display) (cadr props) (caddr w))
      (if (cadddr w) (setenv "Paper background" (itoa (cadddr w))))
      (car w)
    )
  )
)

;;-------------------------=={ Display settings }==------------------------;;

;;  T when the display settings are applied (Display in Dyl-Settings, off by default):
(defun Remote>>Dyl:DisplayOn-p ()
  (= "1" (getenv "DynalispDisplayOn"))
)

;;  Turn the display settings on or off:
(defun Remote>>Dyl:DisplayOnSet (on)
  (setenv "DynalispDisplayOn" (if on "1" "0"))
  (ec:ribbon)
)

;;  The display settings chosen, in the order of *ec:prefs*: (INTERFACE MODEL LAYOUT TABS),
;;  each a name, nil when it is not set. The Interface not set is the former Palettes
;;  or Ribbon setting; a former name of a look is read as its new name (*ec:lookwas*):
(defun Remote>>Dyl:DisplayPref ()
  (mapcar '(lambda (p / name)
             (setq name (getenv (car p)))
             (if (and (= (cadr p) 'interface) (assoc name *ec:lookwas*))
               (setq name (cdr (assoc name *ec:lookwas*)))
             )
             (if (and (= (cadr p) 'interface) (member name '(nil "")))
               (setq name (cond ((vl-some '(lambda (k / v)
                                             (setq v (getenv k)
                                                   v (cond ((cdr (assoc v *ec:lookwas*))) (v))
                                             )
                                             (if (assoc v *ec:looks*) v)
                                           )
                                          '("DynalispPaletteColors" "DynalispRibbonColors")
                                 )
                                )
                                (name)
                          )
               )
             )
             (if (member name (Remote>>Dyl:DisplayNames (cadr p))) name)
           )
          *ec:prefs*
  )
)

;;  Choose the display settings, a list in the order of *ec:prefs* (nil: not set); the
;;  former Ribbon and Palettes settings are cleared, the Interface taking their place:
(defun Remote>>Dyl:DisplayPrefSet (lst)
  (mapcar '(lambda (p name) (setenv (car p) (cond (name) ("")))) *ec:prefs* lst)
  (foreach k '("DynalispPaletteColors" "DynalispRibbonColors" "DynalispColorTheme")
    (if (getenv k) (setenv k ""))
  )
  (ec:ribbon)
)

;;  Apply the display settings chosen while they are on: the model space and the layouts
;;  set when they differ, the interface by the ribbon plugin. Returns a status line, nil
;;  when no display setting is chosen:
(defun Remote>>Dyl:DisplayApply (/ done rbn)
  (setq rbn (ec:ribbon))
  (if (Remote>>Dyl:DisplayOn-p)
    (progn
      (if (car (Remote>>Dyl:DisplayPref))
        (setq done (list (strcat "interface "
                                 (if Dyl:RibbonSkin
                                   (strcat "ribbon " (cond (rbn) ("?")) ", palettes " (Dyl:RibbonSkin "Palettes"))
                                   "plugin not loaded"
                                 )
                         )
                   )
        )
      )
      (foreach c '((model . "model space ") (layout . "layouts "))
        (cond
          ((not (Remote>>Dyl:DisplayWant (car c))))
          ((Remote>>Dyl:DisplayHas (car c))
           (setq done (cons (strcat (cdr c) (car (Remote>>Dyl:DisplayWant (car c)))) done))
          )
          ((ec:set (car c))
           (setq done (cons (strcat (cdr c) "set to " (car (Remote>>Dyl:DisplayWant (car c)))) done))
          )
        )
      )
      (if (cadddr (Remote>>Dyl:DisplayPref))
        (setq done (cons (strcat "file tabs " (if Dyl:RibbonFileTabs (Dyl:RibbonFileTabs) "plugin not loaded")) done))
      )
      (if done
        (apply 'strcat (cons (car (reverse done)) (mapcar '(lambda (s) (strcat ", " s)) (cdr (reverse done)))))
      )
    )
    "off (see Dyl-Settings)"
  )
)

(princ)
