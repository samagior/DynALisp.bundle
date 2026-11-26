;; Dyl-EnvColor - Dynalisp display colors: backgrounds, crosshairs, theme
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
;;  run by dynalisp.mnl); off, the display preferences are left as they are.
;;
;;  Each display setting is a name, "" or missing: not set, the current value kept:
;;    - Model space (DynalispBackground): the model space background, DynALisp, DynALisp
;;      Neutral, Black, Default (blue-grey, the AutoCAD default) or White.
;;    - Layouts (DynalispLayoutBackground): the paper of the layouts and the background
;;      around it, DynALisp, DynALisp Neutral, Black or Default (white paper on light grey, the AutoCAD
;;      default).
;;    - Theme (DynalispColorTheme): the theme of AutoCAD (COLORTHEME), Dark or Light,
;;      which the DynALisp windows follow too.
;;    - Ribbon (DynalispRibbonColors): DynALisp or DynALisp Neutral, the ribbon of AutoCAD in the dark of the
;;      DynALisp windows while AutoCAD is in its dark theme, an experiment that Autodesk
;;      does not support: done by DynALisp.Ribbon.dll (Installer\Ribbon\Plugin\Skin.cs),
;;      which reads these settings itself and again when (Dyl:RibbonSkin) is called.
;;    - Palettes (DynalispPaletteColors): DynALisp or DynALisp Neutral, the same for the palettes of AutoCAD
;;      (Properties...), its status bar, file tabs and command line, by the same plugin
;;      ((Dyl:RibbonSkin "Palettes") says what it does with them).
;;  Each background comes with a crosshair color that stays readable on it. DynALisp is
;;  the dark of the DynALisp windows (Installer\Windows\Engine\Session.cs, Theme): the
;;  model space and the background around the paper a little darker than their title
;;  bar (#181B20), dark without being black, the paper in the color of their background
;;  (#252A32), the crosshairs in the color of their text (#E6EAF0). DynALisp Neutral is
;;  its variant in a neutral grey, darker: the model space and the background around the
;;  paper almost black (#121212), the paper a little lighter (#1E1E1E), the crosshairs
;;  light grey (#E6E6E6), the ribbon and the palettes in greys without hue. The colors
;;  are the display preferences (Options > Display > Colors), the background around the paper
;;  the "Paper background" setting of the profile, which Options does not show: user
;;  profile settings, so they apply to every drawing.
;;
;;  Use in an App:
;;    (Remote>>Dyl:Background 'model)          -> "DynALisp", "Black", "Default" or
;;                                                "White", nil for any other color
;;    (Remote>>Dyl:BackgroundSet 'layout "Default") -> sets the paper, its crosshair
;;                                                and the background around it
;;    (Remote>>Dyl:Theme)                      -> "Dark" or "Light"
;;    (Remote>>Dyl:ThemeSet "Dark")            -> sets COLORTHEME
;;    (Remote>>Dyl:DisplayApply)               -> applies the display settings, returns
;;                                                a status line

(vl-load-com)

;;  The backgrounds of each context: (CONTEXT (BACKGROUND-PROP CROSSHAIR-PROP)
;;  (NAME BACKGROUND CROSSHAIR [AROUND]) ...), colors as OLE values: R + G*256 + B*65536,
;;  AROUND the background around the paper of a layout ("Paper background").
(setq *ec:colors*
       '((model (graphicswinmodelbackgrndcolor modelcrosshaircolor)
                ("DynALisp" 2104088 15788774) ; RGB 24,27,32 / 230,234,240
                ("DynALisp Neutral" 1184274 15132390) ; RGB 18,18,18 / 230,230,230
                ("Black" 0 16777215)
                ("Default" 3155999 16777215) ; RGB 33,40,48
                ("White" 16777215 0)
         )
         (layout (graphicswinlayoutbackgrndcolor layoutcrosshaircolor)
                 ("DynALisp" 3287589 15788774 2104088) ; RGB 37,42,50 / 230,234,240 / 24,27,32
                 ("DynALisp Neutral" 1973790 15132390 1184274) ; RGB 30,30,30 / 230,230,230 / 18,18,18
                 ("Black" 0 16777215 3355443) ; around: RGB 51,51,51
                 ("Default" 16777215 0 12566463) ; around: RGB 191,191,191
         )
        )
)

;;  The themes of AutoCAD: (NAME . COLORTHEME)
(setq *ec:themes* '(("Dark" . 0) ("Light" . 1)))

;;  The display settings, in this order: (KEY CONTEXT), CONTEXT a context of
;;  *ec:colors*, theme, ribbon or palettes:
(setq *ec:prefs* '(("DynalispBackground" model)
                   ("DynalispLayoutBackground" layout)
                   ("DynalispColorTheme" theme)
                   ("DynalispRibbonColors" ribbon)
                   ("DynalispPaletteColors" palettes)
                  )
)

(defun ec:display () (vla-get-display (vla-get-preferences (vlax-get-acad-object))))

;;  The background around the paper of the layouts, an OLE color (nil: never set):
(defun ec:around (/ v)
  (if (and (setq v (getenv "Paper background")) (/= "" v)) (atoi v))
)

;;  Names of the choices of a context (model, layout, theme, ribbon or palettes):
(defun Remote>>Dyl:DisplayNames (ctx)
  (cond
    ((member ctx '(ribbon palettes)) '("DynALisp" "DynALisp Neutral"))
    ((mapcar 'car (if (= ctx 'theme) *ec:themes* (cddr (assoc ctx *ec:colors*)))))
  )
)

;;  The ribbon plugin told that the settings changed: what it does with the ribbon
;;  ("DynALisp", "off"...), nil when it is not loaded:
(defun ec:ribbon ()
  (if Dyl:RibbonSkin (Dyl:RibbonSkin))
)

;;  Name of the current background of a context (model or layout), nil when it is not
;;  one of *ec:colors*:
(defun Remote>>Dyl:Background (ctx / e c)
  (if
    (and (setq e (assoc ctx *ec:colors*))
         (not (vl-catch-all-error-p
                (setq c (vl-catch-all-apply
                          '(lambda ()
                             (vlax-variant-value
                               (vlax-variant-change-type (vlax-get-property (ec:display) (car (cadr e))) vlax-vblong)
                             )
                           )
                        )
                )
              )
         )
    )
    (car (vl-some '(lambda (b) (if (and (= c (cadr b)) (or (not (cadddr b)) (eq (cadddr b) (ec:around)))) b))
                  (cddr e)
         )
    )
  )
)

;;  Set the background of a context (model or layout), its crosshair color and the
;;  background around the paper of a layout (name of *ec:colors*):
(defun Remote>>Dyl:BackgroundSet (ctx name / e b)
  (if (and (setq e (assoc ctx *ec:colors*)) (setq b (assoc name (cddr e))))
    (progn
      (vlax-put-property (ec:display) (car (cadr e)) (cadr b))
      (vlax-put-property (ec:display) (cadr (cadr e)) (caddr b))
      (if (cadddr b) (setenv "Paper background" (itoa (cadddr b))))
      name
    )
  )
)

;;  Name of the current theme of AutoCAD (COLORTHEME), nil when it is unknown:
(defun Remote>>Dyl:Theme ()
  (car (vl-some '(lambda (e) (if (= (getvar "COLORTHEME") (cdr e)) e)) *ec:themes*))
)

;;  Set the theme of AutoCAD (name of *ec:themes*):
(defun Remote>>Dyl:ThemeSet (name / e)
  (if (setq e (assoc name *ec:themes*))
    (progn (setvar "COLORTHEME" (cdr e)) name)
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

;;  The display settings chosen, in the order of *ec:prefs*: (MODEL LAYOUT THEME RIBBON
;;  PALETTES), each a name, nil when it is not set:
(defun Remote>>Dyl:DisplayPref ()
  (mapcar '(lambda (p / name)
             (setq name (getenv (car p)))
             (if (member name (Remote>>Dyl:DisplayNames (cadr p))) name)
           )
          *ec:prefs*
  )
)

;;  Choose the display settings, a list in the order of *ec:prefs* (nil: not set, the
;;  current value kept):
(defun Remote>>Dyl:DisplayPrefSet (lst)
  (mapcar '(lambda (p name) (setenv (car p) (cond (name) ("")))) *ec:prefs* lst)
  (ec:ribbon)
)

;;  Apply the display settings chosen while they are on: each one set when it differs,
;;  the ribbon by its plugin. Returns a status line, nil when no display setting is
;;  chosen:
(defun Remote>>Dyl:DisplayApply (/ done rbn)
  (setq rbn (ec:ribbon))
  (if (Remote>>Dyl:DisplayOn-p)
    (progn
      (mapcar
        '(lambda (p name / ctx what)
           (setq ctx  (cadr p)
                 what (cdr (assoc ctx '((model . "model space ") (layout . "layouts ") (theme . "theme "))))
           )
           (cond
             ((not name))
             ((= ctx 'ribbon)
              (setq done (cons (strcat "ribbon " (cond (rbn) ("plugin not loaded"))) done))
             )
             ((= ctx 'palettes)
              (setq done (cons (strcat "palettes " (if Dyl:RibbonSkin (Dyl:RibbonSkin "Palettes") "plugin not loaded")) done))
             )
             ((= name (if (= ctx 'theme) (Remote>>Dyl:Theme) (Remote>>Dyl:Background ctx)))
              (setq done (cons (strcat what name) done))
             )
             ((if (= ctx 'theme) (Remote>>Dyl:ThemeSet name) (Remote>>Dyl:BackgroundSet ctx name))
              (setq done (cons (strcat what "set to " name) done))
             )
           )
         )
        *ec:prefs*
        (Remote>>Dyl:DisplayPref)
      )
      (if done
        (apply 'strcat (cons (car (reverse done)) (mapcar '(lambda (s) (strcat ", " s)) (cdr (reverse done)))))
      )
    )
    "off (see Dyl-Settings)"
  )
)

(princ)
