;; Assistant - A conversation with Claude in a palette of AutoCAD, through Claude Code
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

;; Assistant
;; Shows the Assistant palette: a conversation with Claude, through Claude Code, the command
;; line of Anthropic, installed by the user and signed in with their own Claude account (no
;; API key). The palette is DynALisp.Assistant.dll (Installer\Assistant, AutoCAD 2016 and
;; later): (Dyl:AssistantShow docs prompt), docs the page its Open Docs button opens, prompt
;; the instructions added to those of Claude Code (Res\Assistant\Prompt.txt, or its User
;; copy). Claude reads the active drawing through the tools of the plugin, and changes it or
;; runs an AutoCAD command once the user allows it in the palette (one U undoes each change).

(defun c:Dyl-Assistant (/ page prompt)
  (cond
    ((not Dyl:AssistantShow)
     (princ "\n--> The Assistant needs DynALisp.Assistant.dll (AutoCAD 2016 or later, not blocked by SECURELOAD).")
    )
    (T
     (setq page   (Dyl:DocsPage "Utilities\\Dyl-Assistant.htm")
           prompt (findfile (Dyl:UserFile (strcat *dyl:dylres "\\Assistant\\Prompt.txt")))
     )
     (Dyl:AssistantShow (if page (Dyl:DocsTarget page)) prompt)
    )
  )
  (princ)
)
