;; Dyl-Assistant.lsp - the Lisp side of the tools of the Assistant
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

;;  The tools of the Assistant (DynALisp.Assistant.dll, Installer\Assistant) that read or
;;  change what DynALisp knows: the materials, the assemblies and the presets, an action of
;;  DynALisp, a Lisp expression. The plugin calls (Remote>>Dyl:AssistantCall op args) with
;;  Application.Invoke, in the command context of AutoCAD (Installer\Assistant\Lisp.cs), never
;;  while a command runs; a change in one undo group of the plugin. It is defined in every
;;  drawing (a Remote file), so the active drawing always answers.
;;
;;  An answer is a list of pairs (("key" . value) ...), read by the plugin as a JSON object:
;;  a value is a string, a number, T, nil (null), a list of values, or such a list of pairs
;;  (an object); (("error" . message)) when the call failed, the message given to Claude.

;;  The call op (letters only: the function Remote>>Dyl:Assistant<op>) on its arguments args,
;;  its errors caught:
(defun Remote>>Dyl:AssistantCall (op args / f r)
  (setq f (if (and (= 'STR (type op)) (/= "" op) (not (wcmatch op "*[~A-Za-z]*")))
            (eval (read (strcat "Remote>>Dyl:Assistant" op)))
          )
  )
  (cond
    ((not f) (list (cons "error" (strcat "Unknown call of the Assistant: " (vl-princ-to-string op)))))
    ((vl-catch-all-error-p (setq r (vl-catch-all-apply f (list args))))
     (list (cons "error" (strcat "Lisp error: " (vl-catch-all-error-message r))))
    )
    (r)
    ((list (cons "done" T)))
  )
)
(vl-acad-defun 'Remote>>Dyl:AssistantCall)

;;---------------------------=={ Helpers }==-----------------------------;;

;;  The number of the text s ("" or not a number: nil), a decimal comma read as a point:
(defun Remote>>Dyl:AssistantNum (s)
  (if (= 'STR (type s)) (distof (vl-string-translate "," "." s) 2))
)

;;  The row of id among rows (its first column, any case), nil when none:
(defun Remote>>Dyl:AssistantFind (id rows / u)
  (if (= 'STR (type id))
    (progn
      (setq u (strcase id))
      (vl-some '(lambda (r) (if (= u (strcase (car r))) r)) rows)
    )
  )
)

;;  The column named col of the row of the presets of the tool key (its header):
(defun Remote>>Dyl:AssistantCol (key col row / i)
  (if (setq i (vl-position col (Remote>>Dyl:PresetProp key 'header))) (nth i row))
)

;;  The presets of the tool key as saved, with the default presets missing from its file
;;  (an older user copy), as written (no fix of an App): the rows with an id:
(defun Remote>>Dyl:AssistantRows (key / lst)
  (setq lst (Remote>>Dyl:PresetCsv key))
  (foreach x (Remote>>Dyl:CsvRead (Remote>>Dyl:PresetDefault key) (length (Remote>>Dyl:PresetProp key 'header)))
    (if (not (Remote>>Dyl:AssistantFind (car x) lst)) (setq lst (append lst (list x))))
  )
  (vl-remove-if '(lambda (r) (= "" (car r))) lst)
)

;;  Why the functions of Quick Draw are not defined, nil once they are: its Apps file loaded
;;  when it is turned on in the Startup Suite, never while it is off (the user turns it on):
(defun Remote>>Dyl:AssistantNeedQuickDraw (/ pth)
  (setq pth (Remote>>Dyl:PresetProp "QuickDraw" 'path))
  (cond
    ((and Dyl:QuickDrawAsmRead Dyl:QuickDrawGet Dyl:QuickDrawMat) nil)
    ((not (Dyl:SuiteFileOn-p pth))
     "Quick Draw is turned off in the Startup Suite (Dyl-Suite): its presets and assemblies are read through it. Ask the user to turn it on."
    )
    ((and (Dyl:SuiteFileLoad pth) Dyl:QuickDrawAsmRead Dyl:QuickDrawGet Dyl:QuickDrawMat) nil)
    ("Quick Draw could not be loaded (Dyl-QuickDraw.lsp).")
  )
)

;;--------------------------=={ Materials }==----------------------------;;

;;  The hatch preset id among the hatch presets hps, as "name (pattern)"; nil without one:
(defun Remote>>Dyl:AssistantHatch (id hps / h)
  (cond
    ((or (not id) (= "" id)) nil)
    ((setq h (Remote>>Dyl:AssistantFind id hps))
     (strcat (nth 2 h) (if (/= "" (nth 3 h)) (strcat " (" (nth 3 h) ")") " (no pattern)"))
    )
    ((strcat id " (missing hatch preset)"))
  )
)

;;  The material row m (Materials.csv: its data in SI) as an object, its hatch presets among hps:
(defun Remote>>Dyl:AssistantMaterial (m hps)
  (list (cons "id" (car m))
        (cons "group" (nth 1 m))
        (cons "name" (nth 2 m))
        (cons "cut" (Remote>>Dyl:AssistantHatch (nth 3 m) hps))
        (cons "surface" (Remote>>Dyl:AssistantHatch (if (= "" (nth 4 m)) (nth 3 m) (nth 4 m)) hps))
        (cons "conductivity" (Remote>>Dyl:AssistantNum (nth 5 m)))
        (cons "density" (Remote>>Dyl:AssistantNum (nth 6 m)))
        (cons "resistance" (Remote>>Dyl:AssistantNum (nth 7 m)))
  )
)

;;  The materials of the ids of args (nil: every material), their data in SI:
(defun Remote>>Dyl:AssistantMaterials (args / b m res)
  (setq b (Remote>>Dyl:MaterialBoth))
  (foreach id (cond (args) ((mapcar 'car (cadr b))))
    (setq res (cons (if (setq m (Remote>>Dyl:AssistantFind id (cadr b)))
                      (Remote>>Dyl:AssistantMaterial m (car b))
                      (list (cons "id" id) (cons "missing" T))
                    )
                    res
              )
    )
  )
  (list (cons "units" "SI: conductivity W/m.K, density kg/m3, resistance (fixed, for what the thickness does not give) m2.K/W; null: not known")
        (cons "materials" (reverse res))
  )
)

;;--------------------------=={ Assemblies }==---------------------------;;

;;  The assemblies of Quick Draw, without their layers:
(defun Remote>>Dyl:AssistantAssemblies (args / err)
  (if (setq err (Remote>>Dyl:AssistantNeedQuickDraw))
    (list (cons "error" err))
    (list (cons "assemblies"
                (mapcar '(lambda (a)
                           (list (cons "id" (car a))
                                 (cons "group" (nth 1 a))
                                 (cons "name" (nth 2 a))
                                 (cons "description" (nth 8 a))
                                 (cons "layers" (length (Remote>>Dyl:MaterialLayers (nth 3 a))))
                           )
                         )
                        (Dyl:QuickDrawAsmRead)
                )
          )
    )
  )
)

;;  A layer l of an assembly (see Remote>>Dyl:MaterialLayers), its materials among mats, u the
;;  metres of a drawing unit:
(defun Remote>>Dyl:AssistantLayer (l mats u / th m v fr)
  (setq th (cond ((Remote>>Dyl:AssistantNum (caddr l))) (0.0))
        m  (Remote>>Dyl:AssistantFind (cadr l) mats)
        v  (Remote>>Dyl:MaterialLayerValues l mats)
        fr (nth 8 l)
  )
  (list (cons "material" (cadr l))
        (cons "material_name" (if m (nth 2 m) "(missing material)"))
        (cons "thickness" th)
        (cons "thickness_mm" (* th u 1000.0))
        (cons "load_bearing" (= "1" (nth 6 l)))
        (cons "framing"
              (if fr
                (list (cons "material" (car fr))
                      (cons "material_name" (if (setq m (Remote>>Dyl:AssistantFind (car fr) mats)) (nth 2 m) "(missing material)"))
                      (cons "percent" (Remote>>Dyl:AssistantNum (cadr fr)))
                )
              )
        )
        (cons "variable_thickness" (= "1" (nth 9 l)))
        (cons "low_permeance" (= "1" (nth 10 l)))
        (cons "resistance" (car v))
        (cons "mass_per_area" (cadr v))
  )
)

;;  The assembly of id (the first of args) with its layers and its data, in the units of the
;;  drawing (see Remote>>Dyl:MaterialAssemblyData):
(defun Remote>>Dyl:AssistantAssembly (args / err a ls mats u d th)
  (cond
    ((setq err (Remote>>Dyl:AssistantNeedQuickDraw)) (list (cons "error" err)))
    ((not (and (= 'STR (type (car args))) (setq a (Dyl:QuickDrawAsmGet (car args)))))
     (list (cons "error" (strcat "No assembly " (vl-princ-to-string (car args)) ": list them with list_presets (kind assemblies).")))
    )
    (T
     (setq ls   (Remote>>Dyl:MaterialLayers (nth 3 a))
           mats (cadr (Remote>>Dyl:MaterialBoth))
           u    (Remote>>Dyl:MaterialUnitMetres)
           d    (Remote>>Dyl:MaterialAssemblyData ls mats (nth 6 a))
           th   (apply '+ (cons 0.0 (mapcar '(lambda (l) (cond ((Remote>>Dyl:AssistantNum (caddr l))) (0.0))) ls)))
     )
     (list (cons "id" (car a))
           (cons "group" (nth 1 a))
           (cons "name" (nth 2 a))
           (cons "description" (nth 8 a))
           (cons "exterior_side" (if (= "Last" (nth 6 a)) "the last layer" "the first layer"))
           (cons "fire_rating_min" (Remote>>Dyl:AssistantNum (nth 9 a)))
           (cons "fire_rating_non_load_bearing_min" (Remote>>Dyl:AssistantNum (nth 10 a)))
           (cons "stc" (Remote>>Dyl:AssistantNum (nth 11 a)))
           (cons "iic" (Remote>>Dyl:AssistantNum (nth 12 a)))
           (cons "units"
                 (strcat "thickness in drawing units (and mm); "
                         (if (Remote>>Dyl:MaterialImperial-p)
                           "resistance R in h.ft2.F/Btu, mass in lb/ft2"
                           "resistance RSI in m2.K/W, mass in kg/m2"
                         )
                         "; the air films are not counted"
                 )
           )
           (cons "thickness" th)
           (cons "thickness_mm" (* th u 1000.0))
           (cons "thermal_resistance" (car d))
           (cons "layers_without_resistance" (caddr d))
           (cons "mass_per_area" (cadr d))
           (cons "layers_without_mass" (cadddr d))
           (cons "continuous_layers_resistance" (nth 4 d))
           (cons "continuous_layers_without_resistance" (nth 5 d))
           (cons "low_permeance_ratio" (if (and (nth 6 d) (minusp (nth 6 d))) "unknown" (nth 6 d)))
           (cons "summary" (Remote>>Dyl:MaterialAssemblyText d))
           (cons "layers" (mapcar '(lambda (l) (Remote>>Dyl:AssistantLayer l mats u)) ls))
     )
    )
  )
)

;;---------------------------=={ Presets }==-----------------------------;;

;;  The presets of the kind of args: QuickDraw, QuickShape, Material, HatchPreset or LayerKey:
(defun Remote>>Dyl:AssistantPresets (args / k)
  (setq k (strcase (vl-princ-to-string (car args))))
  (cond
    ((= k "QUICKDRAW")
     (list (cons "presets"
                 (mapcar '(lambda (r)
                            (list (cons "id" (car r))
                                  (cons "group" (nth 1 r))
                                  (cons "name" (nth 2 r))
                                  (cons "material" (nth 3 r))
                                  (cons "method" (nth 4 r))
                                  (cons "view" (Remote>>Dyl:AssistantCol "QuickDraw" "View" r))
                                  (cons "assembly"
                                        (if (= "1" (Remote>>Dyl:AssistantCol "QuickDraw" "AssemblyOn" r))
                                          (Remote>>Dyl:AssistantCol "QuickDraw" "Assembly" r)
                                        )
                                  )
                            )
                          )
                         (Remote>>Dyl:AssistantRows "QuickDraw")
                 )
           )
     )
    )
    ((= k "QUICKSHAPE")
     (list (cons "presets"
                 (mapcar '(lambda (r)
                            (list (cons "id" (car r))
                                  (cons "group" (nth 1 r))
                                  (cons "name" (nth 2 r))
                                  (cons "material" (nth 3 r))
                                  (cons "shape" (nth 4 r))
                                  (cons "view" (Remote>>Dyl:AssistantCol "QuickShape" "View" r))
                            )
                          )
                         (Remote>>Dyl:AssistantRows "QuickShape")
                 )
           )
     )
    )
    ((= k "MATERIAL") (Remote>>Dyl:AssistantMaterials nil))
    ((= k "HATCHPRESET")
     (list (cons "hatch_presets"
                 (mapcar '(lambda (r)
                            (list (cons "id" (car r))
                                  (cons "group" (nth 1 r))
                                  (cons "name" (nth 2 r))
                                  (cons "pattern" (nth 3 r))
                                  (cons "scale" (Remote>>Dyl:AssistantNum (nth 4 r)))
                                  (cons "angle" (Remote>>Dyl:AssistantNum (nth 6 r)))
                                  (cons "type" (Remote>>Dyl:AssistantCol "HatchPreset" "Type" r))
                            )
                          )
                         (car (Remote>>Dyl:MaterialBoth))
                 )
           )
     )
    )
    ((= k "LAYERKEY")
     (list (cons "layer_keys"
                 (mapcar '(lambda (r)
                            (list (cons "key" (car r))
                                  (cons "layer" (nth 1 r))
                                  (cons "color" (nth 2 r))
                                  (cons "linetype" (nth 3 r))
                                  (cons "lineweight" (nth 4 r))
                                  (cons "plot" (= "1" (nth 5 r)))
                                  (cons "description" (nth 6 r))
                            )
                          )
                         (Remote>>Dyl:LayerKeyRead)
                 )
           )
     )
    )
    ((list (cons "error" (strcat "Unknown kind of presets: " k))))
  )
)

;;---------------------------=={ Actions }==-----------------------------;;

;;  Give the material id (the first of args; "": take it off) to the objects of the handles of
;;  args (the second), as Pst-MaterialAssign does: the hatches and closed curves only, the keys
;;  of the tool that drew them dropped:
(defun Remote>>Dyl:AssistantAssign (args / id m e done bad)
  (setq id (car args))
  (cond
    ((not (= 'STR (type id))) (list (cons "error" "material: give the id of a material (\"\" takes it off).")))
    ((and (/= "" id) (not (setq m (Remote>>Dyl:AssistantFind id (cadr (Remote>>Dyl:MaterialBoth))))))
     (list (cons "error" (strcat "No material " id ": list them with list_presets (kind materials).")))
    )
    (T
     (foreach h (cadr args)
       (if (and (= 'STR (type h))
                (setq e (handent h))
                (Remote>>Dyl:MaterialTaggable-p e)
                (Remote>>Dyl:MaterialTagPut e (list (cons "Material" (if m (car m) "")) '("Tool") '("Preset") '("Assembly") '("Layer") '("Role")))
           )
         (setq done (cons h done))
         (setq bad (cons h bad))
       )
     )
     (list (cons "material" (if m (car m) ""))
           (cons "changed" (reverse done))
           (cons "skipped" (reverse bad))
           (cons "note" (if bad "Skipped: not a hatch or a closed curve, or on a locked layer."))
     )
    )
  )
)

;;  Hatch the closed curves of the handles of args (the second) with the Quick Draw preset id
;;  (the first), as its method Select closed objects does: its material (the hatch preset of
;;  its view), its hatch and its border, the curves kept as its outlines:
(defun Remote>>Dyl:AssistantQuickDraw (args / err rec mat outs e mark made mt:tag mt:keepouts mt:legend mt:scale mt:origin)
  (cond
    ((setq err (Remote>>Dyl:AssistantNeedQuickDraw)) (list (cons "error" err)))
    ((not (and (= 'STR (type (car args))) (setq rec (Dyl:QuickDrawGet (car args)))))
     (list (cons "error" (strcat "No Quick Draw preset " (vl-princ-to-string (car args)) ": list them with list_presets (kind quick_draw).")))
    )
    ((not (setq mat (Remote>>Dyl:MaterialGetAs (nth 3 rec) (nth *qd:view* rec))))
     (list (cons "error" (strcat "The material of the preset " (nth 2 rec) " no longer exists (" (nth 3 rec) ").")))
    )
    (T
     (foreach h (cadr args)
       (if (and (= 'STR (type h)) (setq e (handent h)) (entget e) (Remote>>Dyl:MaterialClosed-p e))
         (setq outs (cons e outs))
       )
     )
     (if (not outs)
       (list (cons "error" "None of the objects is a closed polyline, circle, ellipse or spline: draw the outline first (create_entities, closed)."))
       (progn
         (setq mt:tag      (list (cons "Tool" "QuickDraw") (cons "Preset" (car rec)))
               mt:keepouts T
               mat         (Dyl:QuickDrawMat mat rec)
               mark        (entlast)
         )
         (Dyl:QuickDrawRecentAdd (car rec))
         (Remote>>Dyl:MaterialHatch mat (reverse outs))
         (while (setq mark (if mark (entnext mark) (entnext)))
           (if (not (member (cdr (assoc 0 (entget mark))) '("ATTRIB" "VERTEX" "SEQEND")))
             (setq made (cons (cdr (assoc 5 (entget mark))) made))
           )
         )
         (list (cons "preset" (car rec))
               (cons "name" (nth 2 rec))
               (cons "material" (car mat))
               (cons "outlines" (length outs))
               (cons "made" (reverse made))
         )
       )
     )
    )
  )
)

;;  Evaluate the AutoLISP code of args (the first), once the user turned on Allow Lisp in
;;  Dyl-Settings (DynalispAssistantLisp, off on a new installation) and allowed this call:
;;  its value, as read back by AutoLISP:
(defun Remote>>Dyl:AssistantLisp (args / r)
  (cond
    ((/= "1" (getenv "DynalispAssistantLisp"))
     (list (cons "error" "Allow Lisp is off in Dyl-Settings (Assistant): the Assistant does not run AutoLISP. Ask the user to turn it on."))
    )
    ((not (= 'STR (type (car args)))) (list (cons "error" "code: give the AutoLISP code.")))
    ((vl-catch-all-error-p (setq r (vl-catch-all-apply 'eval (list (read (strcat "(progn " (car args) "\n)"))))))
     (list (cons "error" (strcat "AutoLISP error: " (vl-catch-all-error-message r))))
    )
    ((list (cons "value" (vl-prin1-to-string r))))
  )
)

(princ)
