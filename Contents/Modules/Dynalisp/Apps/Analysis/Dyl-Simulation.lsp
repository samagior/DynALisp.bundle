;; Simulation - Simulate the heat and the vapour through a 2D detail of the drawing
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
;;  shows it over the drawing with its problems (Dyl:SimulationRead, Dyl:SimulationClear),
;;  solves the heat and the vapour through it and shows its temperatures (Dyl:SimulationRun),
;;  adds up the water of its months (Dyl:SimulationMonthly, the monthly balance), reads the
;;  temperature at a point (Dyl:SimulationProbe), and adds the result to the drawing on
;;  purpose (Dyl:SimulationKeep); this file gives it the materials, the climates and the
;;  units, says what it found, puts what is kept on its layer keys and writes the report.

;;-------------------------=={ Commands }==------------------------;;

;; Simulation
;; Opens a window to pick the simulation zone of a 2D detail, edit the climates, place the climate zones, check the detail and simulate the heat through it.

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

;; Simulation Play
;; Solves the heat and the vapour through the detail of a simulation zone and shows its temperatures over the drawing, the dew point, the coldest interior surface and where vapour condenses.

(defun c:Pst-SimulationPlay (/ z)
  (if (setq z (Dyl:SimZonePick T))
    (progn (setq *sim:zone* z) (Dyl:SimPlay z T))
  )
  (princ)
)

;; Simulation Monthly
;; Adds up month by month the water that condenses inside the detail of a simulation zone and dries out of it (the monthly balance of ISO 13788), from the climates of each month.

(defun c:Pst-SimulationMonthly (/ z)
  (if (setq z (Dyl:SimZonePick T))
    (progn (setq *sim:zone* z) (Dyl:SimMonthly z T))
  )
  (princ)
)

;; Simulation Probe
;; Gives the temperature, the relative humidity and the material at the points picked in the detail of the last simulation.

(defun c:Pst-SimulationProbe ()
  (Dyl:SimProbe)
  (princ)
)

;; Simulation Keep
;; Adds the result of the last simulation to the drawing, to print it: its isotherms, the dew point line and a hatch where vapour condenses, on their layer keys.

(defun c:Pst-SimulationKeep ()
  (Dyl:SimKeep)
  (princ)
)

;; Simulation Report
;; Writes a text report of the last simulation: the zone, the climates, the materials and their data, the results and the methods.

(defun c:Pst-SimulationReport ()
  (Dyl:SimReportWrite)
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
;;  condensation on a surface (RSI), then the temperature of each month (C, T01 January to T12
;;  December) and its relative humidity (%, RH01 to RH12), for the monthly balance; each value
;;  empty when not known (a climate without its months is the same all year):
(setq *sim:climhead* '("Id" "Name" "Temperature" "Humidity" "Rs" "RsCondensation"
                       "T01" "T02" "T03" "T04" "T05" "T06" "T07" "T08" "T09" "T10" "T11" "T12"
                       "RH01" "RH02" "RH03" "RH04" "RH05" "RH06" "RH07" "RH08" "RH09" "RH10" "RH11" "RH12"
                      )
)

;;  The columns of the values of a climate (2 to 29), and a row r padded to all of them:
(setq *sim:climcols* '(2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29))
(defun Dyl:SimPad (r)
  (while (< (length r) 30) (setq r (append r (list ""))))
  r
)

;;  The names of the months:
(setq *sim:months* '("January" "February" "March" "April" "May" "June" "July" "August" "September" "October" "November" "December"))

;;  The default climates, each value from a source (a value is never made up): the surface
;;  resistances of ISO 6946 (Rsi 0.13 for a horizontal heat flow, Rse 0.04) and ISO 13788
;;  (Rsi 0.25 to judge the condensation on an interior surface); the interior at 21 C and
;;  35 % (the indoor conditions behind Table 9.25.1.2. of the NBC: "a maximum indoor RH of
;;  35% throughout the heating season", 21 C on average, Chown and Mukhopadhyaya, NRCC-47656,
;;  2005); the exterior at -23 C, the January 2.5 % design temperature of Montreal (NBC 2020,
;;  Division B, Appendix C, Table C-2), to change for a project elsewhere:
;;  No month has a default: no source gives the monthly climate of the interior and the exterior
;;  of every project, so they are typed (the normals of the weather station nearest the site):
(setq *sim:climdefs* (mapcar 'Dyl:SimPad '(("cl-Interior" "Interior" "21" "35" "0.13" "0.25") ("cl-Exterior" "Exterior" "-23" "" "0.04" "0.04"))))

;;  The imperial factors of the values shown (a temperature in F is C x 1.8 + 32), by column:
(setq *sim:climdata* (append '((2 . T) (4 . 5.678263) (5 . 5.678263)) (mapcar '(lambda (c) (cons c T)) '(6 7 8 9 10 11 12 13 14 15 16 17))))

(defun Dyl:SimClimFile ()
  (strcat *dyl:dylres "\\Climates.csv")
)

;;  The climates (rows of *sim:climhead*), the defaults when the file has none:
(defun Dyl:SimClimates (/ f rows)
  (if (findfile (setq f (Dyl:UserFile (Dyl:SimClimFile))))
    (setq rows (vl-remove-if '(lambda (r) (= "" (car r))) (Remote>>Dyl:CsvRead f 30)))
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

;;  The row of the window of a climate r: id name, its values as shown (temperature humidity
;;  rs rscond, the temperatures of the months, their humidities: the columns 2 to 29), then the
;;  values of the file (30 to 57) and those shown (58 to 85), so a value shown and not changed
;;  is saved as it was, never rounded by opening the window:
(defun Dyl:SimClimRow (r imp / shown)
  (setq r     (Dyl:SimPad r)
        shown (mapcar '(lambda (c) (Dyl:SimShown (nth c r) c imp)) *sim:climcols*)
  )
  (append (list (car r) (cadr r)) shown (mapcar '(lambda (c) (nth c r)) *sim:climcols*) shown)
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
                     (if (= v (cond ((nth (+ c 56) w)) (""))) (cond ((nth (+ c 28) w)) ("")) (Dyl:SimStored v c imp))
                   )
                  *sim:climcols*
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
      ;;  The layer keys of what is kept of a run (Dyl:SimKeep), plotted: the isotherms and
      ;;  their labels, the dew point line and its label, the hatch of the condensation:
      *sim:keepkeys* '(("Isotherm" . "SIMISOTHERM") ("Label" . "SIMISOTHERM") ("Dew" . "SIMDEWPOINT")
                       ("Condensation" . "SIMCONDENSATION")
                      )
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

;;  The materials for the plugin: (known data table names), the ids of every material, of
;;  those that have a thermal conductivity or a fixed thermal resistance (columns 5 and 7),
;;  their texts "id|conductivity|resistance|permeability|permeance" (SI, columns 5, 7, 8 and 9)
;;  and ((id . name) ...) of every material:
(defun Dyl:SimMaterials (/ ms data)
  (setq ms   (cadr (Remote>>Dyl:MaterialBoth))
        data (vl-remove-if-not '(lambda (m) (or (Dyl:SimNum (nth 5 m)) (Dyl:SimNum (nth 7 m)))) ms)
  )
  (list (mapcar 'car ms)
        (mapcar 'car data)
        (mapcar '(lambda (m) (strcat (car m) "|" (Dyl:SimText (nth 5 m)) "|" (Dyl:SimText (nth 7 m))
                                     "|" (Dyl:SimText (nth 8 m)) "|" (Dyl:SimText (nth 9 m))
                             )
                 )
                data
        )
        (mapcar '(lambda (m) (cons (car m) (caddr m))) ms)
  )
)

;;  A value of a file as a number in text for the plugin ("" when empty):
(defun Dyl:SimText (v / x)
  (if (setq x (Dyl:SimNum v)) (rtos x 2 8) "")
)

;;  The climates for the plugin: "id|temperature|humidity|rs|rscondensation" (SI):
(defun Dyl:SimClimTexts (rows)
  (mapcar '(lambda (r) (strcat (car r) "|" (Dyl:SimText (nth 2 r)) "|" (Dyl:SimText (nth 3 r)) "|"
                               (Dyl:SimText (nth 4 r)) "|" (Dyl:SimText (nth 5 r))
                       )
           )
          rows
  )
)

;;  The months of the climates for the plugin: "id|t1|...|t12|rh1|...|rh12" (SI), for the
;;  climates with a month typed:
(defun Dyl:SimMonthTexts (rows / v)
  (vl-remove nil
    (mapcar '(lambda (r)
               (setq v (mapcar '(lambda (c) (Dyl:SimText (nth c r))) '(6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29)))
               (if (vl-remove "" v) (strcat (car r) "|" (Remote>>LM:lst->str v "|")))
             )
            rows
    )
  )
)

;;  The climates of the zone (their ids, item 13 of a check r) that have no temperature, by
;;  their names:
(defun Dyl:SimNoTemp (r rows / c res)
  (foreach id (nth 13 r)
    (if (and (setq c (assoc id rows)) (not (Dyl:SimNum (nth 2 c)))) (setq res (cons (cadr c) res)))
  )
  (reverse res)
)

;;  n things, their noun one or many:
(defun Dyl:SimCount (n one many)
  (strcat (itoa n) " " (if (= 1 n) one many))
)

;;  What the check of a zone found (the result of Dyl:SimulationRead, see Plugin.cs), a line per
;;  item, the problems first; and whether it found one: (text problems-p):
(defun Dyl:SimReport (r grid notemp / n bad lines)
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
      (foreach c notemp (setq bad (cons (strcat "Climate " c " without a temperature") bad)))
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
     (setq rep "The check needs DynALisp.Simulation.dll (not blocked by SECURELOAD).")
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
           rep  (car (Dyl:SimReport res grid (if (listp res) (Dyl:SimNoTemp res (Dyl:SimClimates)))))
     )
    )
  )
  (princ (strcat "\n" rep))
  (setq *sim:last* rep)
)

;;-------------------------=={ Play }==------------------------;;

;;  A temperature deg (C) as it is shown in the drawing ("-12.3 C", "9.9 F"):
(defun Dyl:SimDeg (deg imp)
  (if imp
    (strcat (Remote>>Dyl:MaterialNumP (+ 32.0 (* 1.8 deg)) 1) " F")
    (strcat (Remote>>Dyl:MaterialNumP deg 1) " C")
  )
)

;;  The value of the key k of a result (nil when not known):
(defun Dyl:SimGet (k res) (cdr (assoc k res)))

;;  The name of a climate id (its id when it is not a climate of the file):
(defun Dyl:SimClimName (id rows / r)
  (if (setq r (assoc id rows)) (cadr r) id)
)

;;  The names of the material ids lst, divided by commas:
(defun Dyl:SimNames (lst names)
  (Remote>>LM:lst->str (mapcar '(lambda (id) (cond ((cdr (assoc id names))) (id))) lst) ", ")
)

;;  What the vapour of a run res tells, a line (nil when it says nothing): where it condenses
;;  inside the detail and how much, per metre (imperial: per foot) of its depth, or why it was
;;  not computed:
(defun Dyl:SimVapour (res rows names imp / v)
  (cond
    ((Dyl:SimGet "Vapour" res)
     (strcat
       (if (< 0 (cond ((Dyl:SimGet "Condensing" res)) (0)))
         (strcat "Condensation inside the detail (in magenta): "
                 (Remote>>Dyl:MaterialSig (* (cond ((Dyl:SimGet "Rate" res)) (0.0)) (if imp 0.3048 1.0)))
                 (if imp " g/(ft.day)" " g/(m.day)")
                 (if (setq v (Dyl:SimGet "CondensingMaterials" res)) (strcat " in " (Dyl:SimNames v names)) "")
         )
         (strcat "No condensation inside the detail"
                 (if (setq v (Dyl:SimGet "MaxRh" res))
                   (strcat " (highest relative humidity " (Remote>>Dyl:MaterialNumP (min 100.0 v) 0) " %)")
                   ""
                 )
         )
       )
       (if (Dyl:SimGet "VapourNotConverged" res) "\nThe vapour did not settle: the condensation is approximate" "")
     )
    )
    ((setq v (Dyl:SimGet "NoHumidity" res))
     (strcat "No vapour inside the detail: no relative humidity for "
             (Remote>>LM:lst->str (mapcar '(lambda (id) (Dyl:SimClimName id rows)) v) ", ")
     )
    )
    ((setq v (Dyl:SimGet "NoVapour" res))
     (strcat "No vapour inside the detail: no vapour permeability for " (Dyl:SimNames v names))
    )
  )
)

;;  What a run found (res, see Plugin.cs), a line per value, in the units of the drawing:
(defun Dyl:SimResult (res rows names imp / v lines dew)
  (setq dew (Dyl:SimGet "Dew" res))
  (foreach x
    (list
      (if (setq v (Dyl:SimGet "Ti" res))
        (strcat (Dyl:SimClimName (Dyl:SimGet "Interior" res) rows) " " (Dyl:SimDeg v imp) ", "
                (Dyl:SimClimName (Dyl:SimGet "Exterior" res) rows) " " (Dyl:SimDeg (Dyl:SimGet "Te" res) imp)
        )
      )
      (if (setq v (Dyl:SimGet "Tsi" res))
        (strcat "Coldest interior surface " (Dyl:SimDeg v imp)
                (if (Dyl:SimGet "TsiMaterial" res)
                  (strcat " (" (cond ((cdr (assoc (Dyl:SimGet "TsiMaterial" res) names))) ((Dyl:SimGet "TsiMaterial" res))) ")")
                  ""
                )
        )
      )
      (if (setq v (Dyl:SimGet "fRsi" res)) (strcat "Temperature factor fRsi " (rtos v 2 3)))
      (if dew
        (strcat "Dew point of the interior air " (Dyl:SimDeg dew imp)
                (if (< 0 (cond ((Dyl:SimGet "BelowDew" res)) (0)))
                  ": condensation on the interior surface (in magenta)"
                  ": no condensation on the interior surface"
                )
        )
        "No humidity for the interior climate: no dew point"
      )
      (Dyl:SimVapour res rows names imp)
      (if (setq v (Dyl:SimGet "Rsi" res))
        (strcat "Effective " (if imp "R " "RSI ") (Remote>>Dyl:MaterialNumP (if imp (* v 5.678263) v) 2)
                " over the interior surface"
        )
      )
      (if (setq v (Dyl:SimGet "L2D" res))
        (strcat "Thermal coupling L2D "
                (if imp
                  (strcat (Remote>>Dyl:MaterialNumP (* v 0.577789) 4) " Btu/(h.ft.F)")
                  (strcat (Remote>>Dyl:MaterialNumP v 4) " W/(m.K)")
                )
        )
      )
      (if (< 0 (setq v (cond ((Dyl:SimGet "Isolated" res)) (0))))
        (strcat (itoa v) " cells of a material touch no climate: not solved (in grey)")
      )
    )
    (if x (setq lines (cons x lines)))
  )
  (Remote>>LM:lst->str (reverse lines) "\n")
)

;;  Solve the zone z and show its temperatures (the plugin); say what was found. With ask, the
;;  command line then offers to probe the detail, open the window or clear it. Returns the text
;;  of the report (kept for the window):
(defun Dyl:SimPlay (z ask / grid m rows imp res rep notemp)
  (setq imp (Remote>>Dyl:MaterialImperial-p))
  (cond
    ((not Dyl:SimulationRun)
     (setq rep "Play needs DynALisp.Simulation.dll (not blocked by SECURELOAD).")
    )
    (T
     (setq grid (Dyl:SimZoneGrid z)
           m    (Dyl:SimMaterials)
           rows (Dyl:SimClimates)
           res  (Dyl:SimulationRun
                  z
                  (/ (cadr (assoc grid *sim:grids*)) (Remote>>Dyl:MaterialUnitMetres))
                  (car m)
                  (caddr m)
                  (Dyl:SimClimTexts rows)
                  (if imp 1 0)
                  (Remote>>Dyl:MaterialUnitMetres)
                )
     )
     (cond
       ((or (not res) (= 'STR (type res))) (setq rep (car (Dyl:SimReport res grid nil))))
       ((not (cadr res))
        ;;  A problem: the check shown, nothing solved.
        (setq notemp (if (listp (car res)) (Dyl:SimNoTemp (car res) rows))
              rep    (strcat "Not solved:\n" (car (Dyl:SimReport (car res) grid notemp)))
        )
       )
       (T
        (setq rep         (Dyl:SimResult (cadr res) rows (cadddr m) imp)
              *sim:lastrun* (list z grid res rows m rep)
        )
       )
     )
    )
  )
  (princ (strcat "\n" rep))
  (setq *sim:last* rep)
  (if (and ask res (listp res) (cadr res)) (Dyl:SimAfter (Dyl:SimGet "Vapour" (cadr res))))
  rep
)

;;-------------------------=={ Monthly Balance }==------------------------;;

;;  A water w (g per metre of the depth of the detail) as it is shown (imperial: per foot):
(defun Dyl:SimWater (w imp)
  (strcat (Remote>>Dyl:MaterialSig (* w (if imp 0.3048 1.0))) (if imp " g/ft" " g/m"))
)

;;  What the monthly balance of a run res tells, a line per value (see Dyl:SimulationMonthly
;;  of Plugin.cs): the water, whether it dries out, a line per month, then the heat of the
;;  month shown:
(defun Dyl:SimMonthResult (res rows names imp / v lines len)
  (setq len (Dyl:SimGet "Length" res))
  (if (= 0 (cond ((Dyl:SimGet "Start" res)) (0)))
    (setq lines (list "No condensation inside the detail in any month (monthly balance of ISO 13788)"))
    (setq lines
      (list
        (strcat "Monthly balance of ISO 13788 from " (nth (1- (Dyl:SimGet "Start" res)) *sim:months*) ": "
                (if (< 0 (cond ((Dyl:SimGet "MaxMonth" res)) (0)))
                  (strcat "the most water " (Dyl:SimWater (Dyl:SimGet "MaxWater" res) imp)
                          (if (and len (< 0 len))
                            (strcat " ("
                                    (if imp
                                      (strcat (Remote>>Dyl:MaterialSig (* 0.204816 (/ (Dyl:SimGet "MaxWater" res) len 1000.0))) " lb/ft2")
                                      (strcat (Remote>>Dyl:MaterialSig (/ (Dyl:SimGet "MaxWater" res) len 1000.0)) " kg/m2")
                                    )
                                    " of interior surface)"
                            )
                            ""
                          )
                          " at the end of " (nth (1- (Dyl:SimGet "MaxMonth" res)) *sim:months*) " (in magenta)"
                          (if (setq v (Dyl:SimGet "WaterMaterials" res)) (strcat ", in " (Dyl:SimNames v names)) "")
                  )
                  "no water held at the end of a month"
                )
        )
        (if (= 1 (Dyl:SimGet "Dries" res))
          "All of it dries out by the end of the year: the detail passes"
          (strcat (Dyl:SimWater (Dyl:SimGet "Remaining" res) imp)
                  " still wet at the end of the year: the water builds up year after year"
          )
        )
      )
    )
  )
  (foreach m (Dyl:SimGet "Months" res)
    (setq lines (append lines
                        (list (strcat (substr (nth (1- (car m)) *sim:months*) 1 3) "  "
                                      (Dyl:SimDeg (caddr m) imp)
                                      "  condensed " (Dyl:SimWater (nth 4 m) imp)
                                      "  dried " (Dyl:SimWater (nth 5 m) imp)
                                      "  held " (Dyl:SimWater (nth 6 m) imp)
                              )
                        )
                )
    )
  )
  (if (Dyl:SimGet "VapourNotConverged" res)
    (setq lines (append lines (list "The vapour did not settle in a month: the balance is approximate")))
  )
  (Remote>>LM:lst->str
    (append lines
            (list (strcat "Shown: " (nth (1- (Dyl:SimGet "Shown" res)) *sim:months*)))
            (list (Dyl:SimResult (vl-remove-if '(lambda (x) (= "Vapour" (car x))) res) rows names imp))
    )
    "\n"
  )
)

;;  What the monthly balance needs that it did not have (a run res without Monthly):
(defun Dyl:SimMonthMissing (res rows names / v lines)
  (if (Dyl:SimGet "NoMonths" res)
    (setq lines (list "No climate of the zone has its months: type them with the open button of Months in the Simulation window"))
  )
  (if (setq v (Dyl:SimGet "PartMonths" res))
    (setq lines (cons (strcat "Months missing for " (Remote>>LM:lst->str (mapcar '(lambda (id) (Dyl:SimClimName id rows)) v) ", ")
                              ": type all twelve, or none (the same all year)"
                      )
                      lines
                )
    )
  )
  (if (setq v (Dyl:SimGet "NoHumidity" res))
    (setq lines (cons (strcat "No relative humidity for " (Remote>>LM:lst->str (mapcar '(lambda (id) (Dyl:SimClimName id rows)) v) ", ")) lines))
  )
  (if (setq v (Dyl:SimGet "NoVapour" res))
    (setq lines (cons (strcat "No vapour permeability for " (Dyl:SimNames v names)) lines))
  )
  (strcat "The monthly balance needs:\n" (Remote>>LM:lst->str (reverse lines) "\n"))
)

;;  The monthly balance of the zone z (the plugin): solve each month, show the month that holds
;;  the most water, say what was found. With ask, the command line then offers to probe the
;;  detail, keep it, report it... Returns the text of the report (kept for the window):
(defun Dyl:SimMonthly (z ask / grid m rows imp res rep notemp r)
  (setq imp (Remote>>Dyl:MaterialImperial-p))
  (cond
    ((not Dyl:SimulationMonthly)
     (setq rep "The monthly balance needs DynALisp.Simulation.dll (not blocked by SECURELOAD).")
    )
    (T
     (setq grid (Dyl:SimZoneGrid z)
           m    (Dyl:SimMaterials)
           rows (Dyl:SimClimates)
     )
     (princ "\nSolving twelve months...")
     (setq res (Dyl:SimulationMonthly
                 z
                 (/ (cadr (assoc grid *sim:grids*)) (Remote>>Dyl:MaterialUnitMetres))
                 (car m)
                 (caddr m)
                 (Dyl:SimClimTexts rows)
                 (Dyl:SimMonthTexts rows)
                 (if imp 1 0)
                 (Remote>>Dyl:MaterialUnitMetres)
               )
     )
     (cond
       ((or (not res) (= 'STR (type res))) (setq rep (car (Dyl:SimReport res grid nil))))
       ((not (setq r (cadr res)))
        (setq notemp (if (listp (car res)) (Dyl:SimNoTemp (car res) rows))
              rep    (strcat "Not solved:\n" (car (Dyl:SimReport (car res) grid notemp)))
        )
       )
       ((not (Dyl:SimGet "Monthly" r))
        (setq rep (Dyl:SimMonthMissing r rows (cadddr m))
              res nil
        )
       )
       (T
        (setq rep           (Dyl:SimMonthResult r rows (cadddr m) imp)
              *sim:lastrun* (list z grid res rows m rep)
        )
       )
     )
    )
  )
  (princ (strcat "\n" rep))
  (setq *sim:last* rep)
  (if (and ask res (listp res) (cadr res)) (Dyl:SimAfter T))
  rep
)

;;  After a run: probe the detail, show its humidity or its temperatures, open the window or
;;  clear what is shown, until Enter (Humidity only when its vapour was computed: vap):
(defun Dyl:SimAfter (vap / k)
  (while
    (progn
      (initget (if vap "Probe Humidity Temperature Keep Report Window Clear eXit" "Probe Keep Report Window Clear eXit"))
      (setq k (getkword (if vap
                          "\nSimulation [Probe/Humidity/Temperature/Keep/Report/Window/Clear/eXit] <eXit>: "
                          "\nSimulation [Probe/Keep/Report/Window/Clear/eXit] <eXit>: "
                        )
              )
      )
      (cond
        ((= k "Probe") (Dyl:SimProbe) T)
        ((= k "Keep") (Dyl:SimKeep) T)
        ((= k "Report") (Dyl:SimReportWrite) T)
        ((member k '("Humidity" "Temperature")) (if Dyl:SimulationView (Dyl:SimulationView k)) T)
        ((= k "Window") (Dyl:SimulationDialog) nil)
        ((= k "Clear") (if Dyl:SimulationClear (Dyl:SimulationClear)) nil)
      )
    )
  )
)

;;  The temperature, the material and, with the vapour, the relative humidity at the points
;;  picked, until Enter (the last run):
(defun Dyl:SimProbe (/ imp names rows p r)
  (setq imp   (Remote>>Dyl:MaterialImperial-p)
        names (cadddr (Dyl:SimMaterials))
        rows  (Dyl:SimClimates)
  )
  (cond
    ((not Dyl:SimulationProbe) (princ "\nThe probe needs DynALisp.Simulation.dll."))
    (T
     (while (setq p (getpoint "\nPoint to probe <done>: "))
       (setq r (Dyl:SimulationProbe (trans p 1 0)))
       (princ
         (cond
           ((not r) "\nOutside the last simulation (run Play first).")
           ((/= "" (caddr r)) (strcat "\nClimate " (Dyl:SimClimName (caddr r) rows)))
           ((not (car r)) (strcat "\nNo temperature here" (if (/= "" (cadr r)) " (a region that touches no climate)" " (a hole)")))
           ((strcat "\n" (Dyl:SimDeg (car r) imp)
                    (if (cadddr r) (strcat "  " (Remote>>Dyl:MaterialNumP (cadddr r) 0) " % RH") "")
                    (if (nth 5 r) "  condensation" "")
                    "  " (cond ((cdr (assoc (cadr r) names))) ((cadr r)))
            )
           )
         )
       )
     )
    )
  )
)

;;-------------------------=={ Keep And Report }==------------------------;;

;;  The interval of the isotherms kept, in the units shown (C, F in an imperial drawing), for
;;  the session:
(setq *sim:step* nil)

;;  Add the last run of the drawing to it (Dyl:SimulationKeep): the isotherms every interval
;;  asked, the dew point line and the hatch of the condensation, each on its layer key, the
;;  texts 2.5 mm high on paper and the hatch lines 3 mm apart at the drawing scale (CANNOSCALE),
;;  in one undo:
(defun Dyl:SimKeep (/ imp st m sc res n k)
  (setq imp (Remote>>Dyl:MaterialImperial-p)
        m   (Remote>>Dyl:MaterialUnitMetres)
        sc  (Remote>>Dyl:MaterialDrawScale)
  )
  (cond
    ((not Dyl:SimulationKeep) (princ "\nKeep needs DynALisp.Simulation.dll."))
    (T
     (initget 4)
     (setq st (getreal (strcat "\nIsotherms every how many degrees, 0 for none <"
                               (Remote>>Dyl:MaterialNum (cond (*sim:step*) ((if imp 10.0 5.0)))) (if imp " F" " C") ">: "
                       )
              )
           st (cond (st) (*sim:step*) ((if imp 10.0 5.0)))
     )
     (setq *sim:step* st)
     (vla-StartUndoMark (vla-get-ActiveDocument (vlax-get-acad-object)))
     (setq res (Dyl:SimulationKeep st (/ (* 0.0025 sc) m) (/ (* 0.003 sc) m)))
     (cond
       ((= 'STR (type res)) (princ (strcat "\n" res)))
       ((not res) (princ "\nNo simulation to keep: run Play first."))
       (T
        (foreach x res
          (setq k (cdr (assoc (car x) *sim:keepkeys*)))
          (foreach e (cdr x) (Remote>>Dyl:LayerKeyApply e k))
        )
        (setq n (length (cdr (assoc "Isotherm" res))))
        (princ (strcat "\nKept: " (Dyl:SimCount n "isotherm" "isotherms")
                       (if (assoc "Dew" res) ", the dew point line" "")
                       (if (assoc "Condensation" res) ", the hatch of the condensation" "")
                       "."
               )
        )
       )
     )
     (vla-EndUndoMark (vla-get-ActiveDocument (vlax-get-acad-object)))
    )
  )
)

;;  Open the file f in the program Windows opens it with:
(defun Dyl:SimOpen (f / sh)
  (if (setq sh (vlax-create-object "Shell.Application"))
    (progn
      (vl-catch-all-apply 'vlax-invoke-method (list sh 'ShellExecute f "" "" "open" 1))
      (vlax-release-object sh)
    )
  )
)

;;  A value v of a file with its unit u, or nil when it is empty:
(defun Dyl:SimWith (label v u / x)
  (if (setq x (Dyl:SimNum v)) (strcat label " " (Remote>>Dyl:MaterialSig x) " " u))
)

;;  The lines of the report of the last run (*sim:lastrun*: zone grid res rows materials text):
(defun Dyl:SimReportLines (run / z grid res chk rows m names mats imp lines c d)
  (setq z     (nth 0 run)
        grid  (nth 1 run)
        res   (nth 2 run)
        chk   (car res)
        rows  (nth 3 run)
        m     (nth 4 run)
        names (cadddr m)
        mats  (cadr (Remote>>Dyl:MaterialBoth))
        imp   (Remote>>Dyl:MaterialImperial-p)
  )
  (setq lines
    (list
      "DynALisp simulation report"
      (strcat "Date: " (menucmd "M=$(edtime,$(getvar,date),YYYY-MO-DD HH:MM)"))
      (strcat "Drawing: " (getvar "DWGPREFIX") (getvar "DWGNAME"))
      (strcat "Zone: " (if (and (= 'ENAME (type z)) (entget z)) (strcat (cdr (assoc 5 (entget z))) ", " (Dyl:SimZoneSize z)) "erased")
              ", grid " grid " (cells of " (Remote>>Dyl:MaterialNum (* 1000 (cadr (assoc grid *sim:grids*)))) " mm at most), "
              (itoa (nth 0 chk)) " cells (" (itoa (nth 1 chk)) " x " (itoa (nth 2 chk)) ")"
      )
      ""
      "Climates (SI):"
    )
  )
  (foreach id (nth 13 chk)
    (if (setq c (assoc id rows))
      (setq lines (append lines
                          (list (strcat "  " (cadr c) " (" (car c) "): "
                                        (Remote>>LM:lst->str
                                          (vl-remove nil
                                                     (list (Dyl:SimWith "temperature" (nth 2 c) "C")
                                                           (Dyl:SimWith "relative humidity" (nth 3 c) "%")
                                                           (Dyl:SimWith "surface resistance" (nth 4 c) "m2.K/W")
                                                           (Dyl:SimWith "condensation resistance" (nth 5 c) "m2.K/W")
                                                     )
                                          )
                                          ", "
                                        )
                                )
                          )
                          (if (vl-remove "" (mapcar '(lambda (i) (nth i c)) '(6 7 8 9 10 11 12 13 14 15 16 17)))
                            (list (strcat "    months (C / %): "
                                          (Remote>>LM:lst->str
                                            (mapcar '(lambda (i) (strcat (substr (nth (- i 6) *sim:months*) 1 3) " " (nth i c) " / " (nth (+ i 12) c)))
                                                    '(6 7 8 9 10 11 12 13 14 15 16 17)
                                            )
                                            ", "
                                          )
                                  )
                            )
                          )
                  )
      )
    )
  )
  (setq lines (append lines (list "" "Materials (SI):")))
  (foreach id (nth 12 chk)
    (setq d (assoc id mats))
    (setq lines (append lines
                        (list (strcat "  " (cond ((cdr (assoc id names))) (id)) " (" id "): "
                                      (cond
                                        ((not d) "no longer a material")
                                        ((Remote>>LM:lst->str
                                           (vl-remove nil
                                                      (list (Dyl:SimWith "conductivity" (nth 5 d) "W/(m.K)")
                                                            (Dyl:SimWith "resistance" (nth 7 d) "m2.K/W")
                                                            (Dyl:SimWith "vapour permeability" (nth 8 d) "ng/(Pa.s.m)")
                                                            (Dyl:SimWith "vapour permeance" (nth 9 d) "ng/(Pa.s.m2)")
                                                      )
                                           )
                                           ", "
                                         )
                                        )
                                      )
                              )
                        )
                )
    )
  )
  (append lines
          (list ""
                (strcat "Results" (if imp " (imperial units):" ":"))
          )
          (mapcar '(lambda (l) (strcat "  " l)) (Dyl:SimLines (nth 5 run)))
          (list ""
                "Methods:"
                "  Steady heat flow of ISO 10211: finite volumes on the grid, the edge of the zone outside a climate adiabatic."
                "  Surface resistances of ISO 6946 for the heat flow, L2D and the effective RSI; the condensation resistance"
                "  (ISO 13788) for the surface temperatures, fRsi and the dew point on the surfaces."
                "  Vapour inside the detail: the method of Glaser of ISO 13788 in two dimensions, by diffusion alone, at the"
                (if (Dyl:SimGet "Monthly" (cadr res))
                  "  temperatures of the heat flow, each month steady."
                  "  temperatures of the heat flow; a steady state of the conditions given, not a monthly balance."
                )
          )
          (if (Dyl:SimGet "Monthly" (cadr res))
            (list "  Monthly balance of ISO 13788 (clause 6.4): the water of each cell added up from the first month that"
                  "  condenses after one that does not, a cell that holds water held at the saturation pressure, so it dries"
                  "  by what it gives back; the detail passes when every cell is dry at the end of the twelve months. Months"
                  "  of 31, 28, 31... days; a climate without its months the same all year."
            )
          )
          (list
                "  A material without a conductivity is simulated by its fixed RSI, one without a vapour permeability by its"
                "  fixed permeance, across the smaller side of its region."
          )
  )
)

;;  The lines of a text divided by new lines:
(defun Dyl:SimLines (s / i res)
  (while (setq i (vl-string-search "\n" s))
    (setq res (cons (substr s 1 i) res)
          s   (substr s (+ i 2))
    )
  )
  (reverse (cons s res))
)

;;  Write the report of the last run to a text file picked (beside the drawing by default),
;;  then open it:
(defun Dyl:SimReportWrite (/ f h)
  (cond
    ((not *sim:lastrun*) (princ "\nNo simulation to report: run Play first."))
    ((setq f (getfiled "Simulation report"
                       (strcat (getvar "DWGPREFIX") (vl-filename-base (getvar "DWGNAME")) " - Simulation.txt")
                       "txt"
                       1
             )
     )
     (if (setq h (open f "w"))
       (progn
         (foreach l (Dyl:SimReportLines *sim:lastrun*) (write-line l h))
         (close h)
         (princ (strcat "\nReport written: " f))
         (Dyl:SimOpen f)
       )
       (princ (strcat "\nThe report could not be written: " f))
     )
    )
  )
)

;;-------------------------=={ Window }==------------------------;;

;;  The Simulation window (Res\Dyl-Simulation.xaml): the zone, its grid, the climates and the
;;  last check or run. Its buttons that act on the drawing close it with their number, and it is shown
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
                        (list "cl/new" (Dyl:SimClimRow (list "" "New climate") imp))
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
      ((member code '(1 5 7 8))
       (setq climates (Dyl:SimClimsOf rows imp))
       (if (not (Dyl:SimClimatesWrite climates))
         (alert "The climates could not be saved: is Climates.csv open in Excel?")
       )
       (setq go nil)
       (cond
         ((not z))
         ((= 5 code) (Dyl:SimCheck z))
         ((= 7 code) (Dyl:SimPlay z T))
         ((= 8 code) (Dyl:SimMonthly z T))
       )
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
