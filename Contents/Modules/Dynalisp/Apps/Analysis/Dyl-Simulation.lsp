;; Simulation - Simulate the heat (and later the vapour) through a 2D detail of the drawing
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

;;  A 2D detail is simulated inside a simulation zone (a closed curve of the drawing), between
;;  climate zones (closed curves of a climate: Interior, Exterior...) that cover the air on
;;  each side of it. Each region of the detail is a hatch or a closed curve that carries its
;;  material (see the material of an object, Remote\Dyl-Materials.lsp). The zones carry the
;;  DynALisp data of the objects too (application DYNALISP, Remote>>Dyl:MaterialTagPut):
;;    a simulation zone  Role=SimulationZone, Grid=Coarse|Medium|Fine (the size of its cells)
;;    a climate zone     Role=Climate, Climate=<id> (cl-Interior: a row of Climates.csv)
;;  The climates are a data file (Res\Climates.csv, its user copy), shared by every drawing:
;;  changing Interior changes every detail. The plugin DynALisp.Simulation.dll
;;  (Installer\Simulation) reads the detail of a zone in the drawing, builds its grid and
;;  shows it over the drawing with its problems (Dyl:SimulationRead, Dyl:SimulationClear);
;;  this file gives it the materials, the climates and the units.

;;-------------------------=={ Commands }==------------------------;;

;; Simulation
;; Opens a window to pick the simulation zone of a 2D detail, edit the climates, place the climate zones and check the detail before it is simulated.

(defun c:Dyl-Simulation ()
  (Dyl:SimulationDialog)
  (princ)
)

;; Simulation Zone
;; Draws the simulation zone of a 2D detail (a rectangle) or makes a closed polyline picked into one.

(defun c:Pst-SimulationZone (/ e)
  (if (setq e (Dyl:SimZoneNew)) (setq *sim:zone* e))
  (princ)
)

;; Simulation Climate
;; Draws a climate zone (Interior, Exterior...) over the air on one side of a 2D detail, or makes a closed polyline picked into one.

(defun c:Pst-SimulationClimate (/ rows i)
  (setq rows (Dyl:SimClimates))
  (if (setq i (Dyl:SimClimateAsk rows)) (Dyl:SimClimateNew (nth i rows)))
  (princ)
)

;; Simulation Check
;; Reads the detail of a simulation zone and shows its grid and its problems over the drawing: hatches without a material, materials without data, holes.

(defun c:Pst-SimulationCheck (/ z)
  (if (setq z (Dyl:SimZonePick T))
    (progn (setq *sim:zone* z) (Dyl:SimCheck z))
  )
  (princ)
)

;; Simulation Clear
;; Clears what the simulation shows over the drawing.

(defun c:Pst-SimulationClear ()
  (if Dyl:SimulationClear (Dyl:SimulationClear))
  (princ)
)

;;-------------------------=={ Climates }==------------------------;;

;;  The climates file and its columns: id, name, temperature (C), relative humidity (%), the
;;  surface resistance of its faces (RSI, m2.K/W, for the heat) and the one used to judge the
;;  condensation on a surface (RSI), each value empty when not known:
(setq *sim:climhead* '("Id" "Name" "Temperature" "Humidity" "Rs" "RsCondensation"))

;;  The default climates: their surface resistances are those of ISO 6946 (Rsi 0.13 for a
;;  horizontal heat flow, Rse 0.04) and ISO 13788 (Rsi 0.25 to judge the condensation on an
;;  interior surface); their temperature and humidity are not given until a source is picked
;;  for them (a value is never made up):
(setq *sim:climdefs* '(("cl-Interior" "Interior" "" "" "0.13" "0.25") ("cl-Exterior" "Exterior" "" "" "0.04" "0.04")))

;;  The imperial factors of the values shown (a temperature in F is C x 1.8 + 32), by column:
(setq *sim:climdata* '((2 . T) (4 . 5.678263) (5 . 5.678263)))

(defun Dyl:SimClimFile ()
  (strcat *dyl:dylres "\\Climates.csv")
)

;;  The climates (rows of *sim:climhead*), the defaults when the file has none:
(defun Dyl:SimClimates (/ f rows)
  (if (findfile (setq f (Dyl:UserFile (Dyl:SimClimFile))))
    (setq rows (vl-remove-if '(lambda (r) (= "" (car r))) (Remote>>Dyl:CsvRead f 6)))
  )
  (cond (rows) (*sim:climdefs*))
)

;;  Save the climates rows; T when saved:
(defun Dyl:SimClimatesWrite (rows)
  (Remote>>LM:writecsv (cons *sim:climhead* rows) (Dyl:UserFileW (Dyl:SimClimFile)))
)

;;  A number of a text (a decimal comma read as a point), nil for an empty text:
(defun Dyl:SimNum (s)
  (if (and s (/= "" (setq s (vl-string-trim " " s)))) (distof (vl-string-translate "," "." s) 2))
)

;;  The value v of the column c of a climate (SI) as it is shown, and back (imp: imperial):
(defun Dyl:SimShown (v c imp / x f)
  (cond
    ((not (setq x (Dyl:SimNum v))) "")
    ((not (and imp (setq f (cdr (assoc c *sim:climdata*))))) (Remote>>Dyl:MaterialNumP x 4))
    ((= f T) (Remote>>Dyl:MaterialNumP (+ 32.0 (* 1.8 x)) 2))
    ((Remote>>Dyl:MaterialNumP (* x f) 4))
  )
)
(defun Dyl:SimStored (v c imp / x f)
  (cond
    ((not (setq x (Dyl:SimNum v))) "")
    ((not (and imp (setq f (cdr (assoc c *sim:climdata*))))) (Remote>>Dyl:MaterialNumP x 6))
    ((= f T) (Remote>>Dyl:MaterialNumP (/ (- x 32.0) 1.8) 6))
    ((Remote>>Dyl:MaterialNumP (/ x f) 6))
  )
)

;;  The row of the window of a climate r: id name temperature humidity rs rscond as shown, then
;;  the values of the file and those shown (the columns 2 to 5 each), so a value shown and not
;;  changed is saved as it was, never rounded by opening the window:
(defun Dyl:SimClimRow (r imp / shown)
  (setq shown (mapcar '(lambda (c) (Dyl:SimShown (nth c r) c imp)) '(2 3 4 5)))
  (append (list (car r) (cadr r)) shown (mapcar '(lambda (c) (nth c r)) '(2 3 4 5)) shown)
)

;;  The climate of a row of the window w (see Dyl:SimClimRow), its id made from its name when
;;  it is new (cl-<name without spaces>, unique among used):
(defun Dyl:SimClimOf (w imp used / id k base)
  (setq id (car w))
  (if (= "" id)
    (progn
      (setq base (strcat "cl-" (vl-string-translate " " "-" (vl-string-trim " " (cadr w))))
            id   base
            k    1
      )
      (while (member (strcase id) used) (setq id (strcat base (itoa (setq k (1+ k))))))
    )
  )
  (append (list id (vl-string-trim " " (cadr w)))
          (mapcar '(lambda (c / v)
                     (setq v (vl-string-trim " " (cond ((nth c w)) (""))))
                     (if (= v (cond ((nth (+ c 8) w)) (""))) (cond ((nth (+ c 4) w)) ("")) (Dyl:SimStored v c imp))
                   )
                  '(2 3 4 5)
          )
  )
)

;;  The climates of the rows of the window rows (see Dyl:SimClimOf):
(defun Dyl:SimClimsOf (rows imp / used res r)
  (setq used (mapcar 'strcase (vl-remove "" (mapcar 'car rows))))
  (foreach w rows
    (if (/= "" (vl-string-trim " " (cadr w)))
      (setq r    (Dyl:SimClimOf w imp used)
            used (cons (strcase (car r)) used)
            res  (cons r res)
      )
    )
  )
  (reverse res)
)

;;  The index of a climate of rows asked on the command line (nil: none):
(defun Dyl:SimClimateAsk (rows / i n)
  (setq i 0)
  (princ "\nClimates:")
  (foreach r rows (princ (strcat "  " (itoa (setq i (1+ i))) " " (cadr r))))
  (initget 6)
  (setq n (getint (strcat "\nClimate of the zone <1>: ")))
  (cond
    ((not n) 0)
    ((<= n (length rows)) (1- n))
    ((princ "\nNo such climate.") nil)
  )
)

;;-------------------------=={ Zones }==------------------------;;

;;  The layer keys of the zones (not plotted), and the sizes of the cells of each grid, in
;;  metres (the target size: the cells are this size or smaller, see Installer\Simulation):
(setq *sim:zonekey* "SIMZONE"
      *sim:climkey* "SIMCLIMATE"
      *sim:grids*   '(("Coarse" 0.010) ("Medium" 0.005) ("Fine" 0.002))
)

;;  The value of the role of the entity e ("" when it has none, upper case):
(defun Dyl:SimRole (e)
  (strcase (cond ((and e (entget e) (Remote>>Dyl:MaterialTag e "Role"))) ("")))
)

(defun Dyl:SimZone-p (e)
  (= "SIMULATIONZONE" (Dyl:SimRole e))
)

;;  The grid of the zone z ("Medium" when it has none or one not known):
(defun Dyl:SimZoneGrid (z / g)
  (setq g (Remote>>Dyl:MaterialTag z "Grid"))
  (cond ((and g (assoc g *sim:grids*)) g) ("Medium"))
)

;;  The simulation zones of the drawing (enames):
(defun Dyl:SimZones (/ ss i e res)
  (if (setq ss (ssget "_X" (list (list -3 (list *mt:app*)))))
    (progn
      (setq i 0)
      (repeat (sslength ss)
        (setq e (ssname ss i)
              i (1+ i)
        )
        (if (Dyl:SimZone-p e) (setq res (cons e res)))
      )
    )
  )
  res
)

;;  The zone to work on: the one of the session when it still exists, else the only one of the
;;  drawing, else nil:
(defun Dyl:SimZoneCurrent (/ zs)
  (cond
    ((and *sim:zone* (entget *sim:zone*) (Dyl:SimZone-p *sim:zone*)) *sim:zone*)
    ((= 1 (length (setq zs (Dyl:SimZones)))) (car zs))
  )
)

;;  A simulation zone picked (Enter: the current one when cur is T), nil when none:
(defun Dyl:SimZonePick (cur / z e)
  (setq z (if cur (Dyl:SimZoneCurrent)))
  (while
    (progn
      (setq e (entsel (if z "\nSelect a simulation zone <current>: " "\nSelect a simulation zone: ")))
      (cond
        ((not e) nil)
        ((Dyl:SimZone-p (car e)) (setq z (car e)) nil)
        ((princ "\nThis is not a simulation zone (Pst-SimulationZone makes one).")))
    )
  )
  z
)

;;  A closed outline asked on the command line: a rectangle by two corners, or a closed
;;  polyline picked (Pick). Returns (ename . drawn) (drawn: T when it was drawn), nil: none:
(defun Dyl:SimOutline (what / p q e res)
  (initget "Pick")
  (setq p (getpoint (strcat "\nFirst corner of the " what " or [Pick]: ")))
  (cond
    ((= p "Pick")
     (while
       (progn
         (setq e (entsel (strcat "\nSelect the closed polyline of the " what ": ")))
         (cond
           ((not e) nil)
           ((not (Remote>>Dyl:MaterialClosed-p (car e))) (princ "\nThis is not a closed polyline."))
           ;;  A region of the detail stays one (its material would be taken off):
           ((Remote>>Dyl:MaterialOf (car e)) (princ "\nThis outline is a region of a material: draw the zone around it."))
           ((setq res (cons (car e) nil)) nil))
       )
     )
    )
    ((and p (setq q (getcorner p "\nOther corner: ")))
     (setq p (trans p 1 0)
           q (trans q 1 0)
     )
     (if (setq e (entmakex (list '(0 . "LWPOLYLINE") '(100 . "AcDbEntity") '(100 . "AcDbPolyline")
                                 '(90 . 4) '(70 . 1) (cons 38 (caddr p))
                                 (list 10 (car p) (cadr p)) (list 10 (car q) (cadr p))
                                 (list 10 (car q) (cadr q)) (list 10 (car p) (cadr q))
                           )
                 )
         )
       (setq res (cons e T))
     )
    )
  )
  res
)

;;  A new simulation zone (see Dyl:SimOutline), on the layer of its layer key when it is
;;  drawn, its grid kept (Medium for a new one). Returns its ename, nil when none:
(defun Dyl:SimZoneNew (/ o)
  (if (setq o (Dyl:SimOutline "simulation zone"))
    (progn
      (if (cdr o) (Remote>>Dyl:LayerKeyApply (car o) *sim:zonekey*))
      (if (Remote>>Dyl:MaterialTagPut (car o) (list '("Material") '("Role" . "SimulationZone") (cons "Grid" (Dyl:SimZoneGrid (car o)))))
        (progn (princ "\nSimulation zone made.") (car o))
        (progn (princ "\nThe zone could not be written (a locked layer?).") nil)
      )
    )
  )
)

;;  A new climate zone of the climate row r (see Dyl:SimOutline), on the layer of its layer key
;;  when it is drawn, red for Interior and blue for Exterior:
(defun Dyl:SimClimateNew (r / o)
  (if (setq o (Dyl:SimOutline (strcat (cadr r) " climate zone")))
    (progn
      (if (cdr o)
        (progn
          (Remote>>Dyl:LayerKeyApply (car o) *sim:climkey*)
          (cond
            ((= "cl-Interior" (car r)) (vla-put-Color (vlax-ename->vla-object (car o)) 1))
            ((= "cl-Exterior" (car r)) (vla-put-Color (vlax-ename->vla-object (car o)) 5))
          )
        )
      )
      (if (Remote>>Dyl:MaterialTagPut (car o) (list '("Material") '("Grid") '("Role" . "Climate") (cons "Climate" (car r))))
        (progn (princ (strcat "\n" (cadr r) " climate zone made.")) (car o))
        (progn (princ "\nThe zone could not be written (a locked layer?).") nil)
      )
    )
  )
)

;;  The size of the zone z, in the units of the drawing ("600 x 400"):
(defun Dyl:SimZoneSize (z / mn mx)
  (vla-GetBoundingBox (vlax-ename->vla-object z) 'mn 'mx)
  (setq mn (vlax-safearray->list mn)
        mx (vlax-safearray->list mx)
  )
  (strcat (rtos (- (car mx) (car mn)) 2 (getvar "LUPREC")) " x " (rtos (- (cadr mx) (cadr mn)) 2 (getvar "LUPREC")))
)

;;-------------------------=={ Check }==------------------------;;

;;  The materials for the plugin: (known data), the ids of every material and of those that
;;  have a thermal conductivity or a fixed thermal resistance (columns 5 and 7):
(defun Dyl:SimMaterials (/ ms)
  (setq ms (cadr (Remote>>Dyl:MaterialBoth)))
  (list (mapcar 'car ms)
        (mapcar 'car (vl-remove-if-not '(lambda (m) (or (Dyl:SimNum (nth 5 m)) (Dyl:SimNum (nth 7 m)))) ms))
  )
)

;;  n things, their noun one or many:
(defun Dyl:SimCount (n one many)
  (strcat (itoa n) " " (if (= 1 n) one many))
)

;;  What the check of a zone found (the result of Dyl:SimulationRead, see Plugin.cs), a line per
;;  item, the problems first; and whether it found one: (text problems-p):
(defun Dyl:SimReport (r grid / n bad lines)
  (cond
    ((not r) (list "The zone could not be read." T))
    ((= 'STR (type r)) (list r T))
    (T
      (foreach x (list (list (nth 4 r) "hatch without a material" "hatches without a material")
                       (list (nth 5 r) "region of a material that no longer exists" "regions of materials that no longer exist")
                       (list (nth 6 r) "region of a material without thermal data" "regions of materials without thermal data")
                       (list (nth 7 r) "hole (no material, no climate)" "holes (no material, no climate)")
                       (list (nth 9 r) "climate zone of a climate that no longer exists" "climate zones of climates that no longer exist")
                 )
        (if (< 0 (car x)) (setq bad (cons (apply 'Dyl:SimCount x) bad)))
      )
      (if (= 0 (nth 10 r)) (setq bad (cons "No climate zone in the zone" bad)))
      (setq lines (append (reverse bad)
                          (list (strcat (Dyl:SimCount (nth 3 r) "region" "regions") " of "
                                        (Dyl:SimCount (length (nth 12 r)) "material" "materials")
                                )
                                (strcat (itoa (nth 0 r)) " cells (" (itoa (nth 1 r)) " x " (itoa (nth 2 r)) "), " grid " grid"
                                        (if (= 0 (nth 11 r)) ", too dense to be shown" "")
                                )
                          )
                          (if (< 0 (nth 8 r)) (list (strcat (itoa (nth 8 r)) " cells in two regions: the one in front is used")))
                          (if (not bad) (list "Ready: no problem found."))
                  )
      )
      (list (Remote>>LM:lst->str lines "\n") bad)
    )
  )
)

;;  Check the zone z: read its detail, show its grid and its problems over the drawing (the
;;  plugin), and say what was found. Returns the text of the report (kept for the window):
(defun Dyl:SimCheck (z / grid m res rep)
  (cond
    ((not Dyl:SimulationRead)
     (setq rep "The check needs DynALisp.Simulation.dll (AutoCAD 2015 or later, not blocked by SECURELOAD).")
    )
    (T
     (setq grid (Dyl:SimZoneGrid z)
           m    (Dyl:SimMaterials)
           res  (Dyl:SimulationRead
                  z
                  (/ (cadr (assoc grid *sim:grids*)) (Remote>>Dyl:MaterialUnitMetres))
                  (car m)
                  (cadr m)
                  (mapcar 'car (Dyl:SimClimates))
                )
           rep  (car (Dyl:SimReport res grid))
     )
    )
  )
  (princ (strcat "\n" rep))
  (setq *sim:last* rep)
)

;;-------------------------=={ Window }==------------------------;;

;;  The Simulation window (Res\Dyl-Simulation.xaml): the zone, its grid, the climates and the
;;  last check. Its buttons that act on the drawing close it with their number, and it is shown
;;  again on the values it gave back (the climates edited are kept until OK or Cancel):
(defun Dyl:SimulationDialog (/ imp rows z go res code sel names gi climates)
  (setq imp  (Remote>>Dyl:MaterialImperial-p)
        rows (mapcar '(lambda (r) (Dyl:SimClimRow r imp)) (Dyl:SimClimates))
        names (mapcar 'car *sim:grids*)
        go   T
  )
  (while go
    (setq z   (Dyl:SimZoneCurrent)
          gi  (if z (vl-position (Dyl:SimZoneGrid z) names) 1)
          res (Dyl:WinShow
                "Dyl-Simulation.xaml"
                (append
                  (list (cons "zsum" (if z (strcat "Zone of " (Dyl:SimZoneSize z) ", made of the hatches and closed outlines inside it.") "No zone picked: pick a closed polyline, or draw a new zone."))
                        (cons "res" (cond (*sim:last*) ("Not checked yet.")))
                        (cons "cl/rows" rows)
                        (cons "cl/defs" (mapcar '(lambda (r) (Dyl:SimClimRow r imp)) *sim:climdefs*))
                        (list "cl/new" (list "" "New climate" "" "" "" "" "" "" "" "" "" ""))
                        (cons "sim.imp" (if imp "1" "0"))
                        (cons "sim.zone" (if z "1" "0"))
                        (cons "sim.plugin" (if Dyl:SimulationRead "1" "0"))
                  )
                  (Dyl:WinList "grd" names gi)
                  (if sel (list (cons "cl.sel" sel)))
                )
              )
          code (car res)
    )
    (if (and res (/= 0 code))
      (progn
        (setq rows (cond ((Dyl:WinGet res "cl/rows")) (rows))
              sel  (Dyl:WinGet res "cl.sel")
        )
        (if (and z (/= (nth (Dyl:WinIdx res "grd") names) (Dyl:SimZoneGrid z)))
          (Remote>>Dyl:MaterialTagPut z (list (cons "Grid" (nth (Dyl:WinIdx res "grd") names))))
        )
      )
    )
    (cond
      ((or (not res) (= 0 code)) (setq go nil))
      ((member code '(1 5))
       (setq climates (Dyl:SimClimsOf rows imp))
       (if (not (Dyl:SimClimatesWrite climates))
         (alert "The climates could not be saved: is Climates.csv open in Excel?")
       )
       (setq go nil)
       (if (and (= 5 code) z) (Dyl:SimCheck z))
      )
      ((= 2 code) (if (setq z (Dyl:SimZonePick nil)) (setq *sim:zone* z *sim:last* nil)))
      ((= 3 code) (if (setq z (Dyl:SimZoneNew)) (setq *sim:zone* z *sim:last* nil)))
      ((= 4 code)
       ;;  The climates saved first, so the zone placed names a climate of the file:
       (setq climates (Dyl:SimClimsOf rows imp))
       (Dyl:SimClimatesWrite climates)
       (setq rows (mapcar '(lambda (r) (Dyl:SimClimRow r imp)) climates))
       (Dyl:SimClimateNew (nth (max 0 (min (1- (length climates)) (atoi (cond (sel) ("0"))))) climates))
      )
      ((= 6 code) (if Dyl:SimulationClear (Dyl:SimulationClear)))
    )
  )
)

(princ)
