;; Dyl-SettingsSync - Dynalisp settings reactor: a drawing made current follows the settings changed in another one
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

;;  Loaded at startup from the Reactor folder, after the Remote files, only while the
;;  DynALisp reactors are on (Dyl-Settings, see Dyl:ReactorsOn-p in dynalisp.mnl). Off, this
;;  file is not loaded: a setting changed in Dyl-Settings applies to the drawing it is
;;  changed in and to the drawings opened after, not to the other drawings already open.
;;
;;  Settings sync: other open drawings follow these settings (Settings sync in Dyl-Settings,
;;  DynalispSettingsSync user setting, off by default).
;;
;;  The settings are applied by Dyl:SetSync (Settings region of dynalisp.mnl): the drawing
;;  defaults (DS:synced) and the Command optimizer (MAJ:synced).

(vl-load-com)

;;  A drawing made current follows the settings changed in another drawing since it
;;  applied them: only a change is applied, so Dyl-RestoreCommands (this drawing only)
;;  and units changed by hand are kept until the setting changes again.
;;  Every open drawing has this reactor: only the one of the drawing made current acts
;;  (each one could send its command line to the drawing in front). The DynALisp reactors
;;  turned off in another drawing: every reactor of this drawing is removed (see
;;  Dyl:ReactorsStop in dynalisp.mnl). Settings sync turned off (Dyl:SettingsSyncOn-p),
;;  nothing is applied; turned on again, the drawing applies what changed meanwhile.
;;  Dyl:SetSync is defined later at startup:
(defun Reactor>>Dyl:SettingsOnDoc (rea args)
  (cond
    ((not (Dyl:ReactorsOn-p)) (Dyl:ReactorsStop))
    ((and Dyl:SetSync (Dyl:SettingsSyncOn-p) (Dyl:ThisDoc-p args)) (vl-catch-all-apply 'Dyl:SetSync))
  )
  (princ)
)

;;  Remove the reactor of this file in the drawing (run by Dyl:ReactorsStop):
(defun Reactor>>Dyl:SettingsStop ()
  (if *dyl:setreactor* (vl-catch-all-apply 'vlr-remove (list *dyl:setreactor*)))
  (setq *dyl:setreactor* nil)
)
(Dyl:ReactorsAdd 'Reactor>>Dyl:SettingsStop)

;;  Made again on each load (Dyl-Reload) so it always runs the functions of this file:
(if *dyl:setreactor* (vl-catch-all-apply 'vlr-remove (list *dyl:setreactor*)))
(setq *dyl:setreactor* (if (Dyl:ReactorsOn-p)
                         (vlr-docmanager-reactor "Dyl-Settings"
                                                 '((:vlr-documentBecameCurrent . Reactor>>Dyl:SettingsOnDoc))
                         )
                       )
)

(princ)
