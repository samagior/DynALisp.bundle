;; GC-Sub - gileCAD remote subfunctions
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


;#region Subfunctions

;;----------------------------------------------------------------------;;
;#region String

;; Evalue si l'expression est une chaine non vide
;; expr : l'expression à évaluer
(defun Remote>>gc:strinp (expr) 
  (and (= 'STR (type expr)) 
       (/= expr "")
  )
)


;; Substitue toutes les occurences d'une chaine par une autre dans une chaine
;; new : la chaîne à substituer
;; old : la chaîne à remplacer
;; str : la chaîne à traiter
(defun Remote>>gc:StringSubstAll (new old str / pos) 
  (while (setq pos (vl-string-search old str)) 
    (setq str (vl-string-subst new old str pos))
  )
  str
)


;; Transforme un chaine avec séparateur en liste de chaines
;; str : la chaîne
;; sep : le séparateur
(defun Remote>>gc:str2lst (str sep / len lst) 
  (setq len (strlen sep))
  (while (setq pos (vl-string-search sep str)) 
    (setq lst (cons (substr str 1 pos) lst)
          str (substr str (+ len pos 1))
    )
  )
  (reverse (cons (substr str 1 pos) lst))
)


;; Concatène une liste de chaînes et un séparateur en une chaine
;; lst : la liste
;; sep : le séparateur
(defun Remote>>gc:lst2str (lst sep) 
  (apply 'strcat 
         (cons (car lst) 
               (mapcar (function (lambda (x) (strcat sep x))) (cdr lst))
         )
  )
)


;; Transforme une chaine en point 3d (saisie clavier avec grread)
;; str : la chaîne
(defun Remote>>gc:str2pt (str) 
  (setq str (mapcar 'read (Remote>>gc:str2lst str ",")))
  (if 
    (and (vl-every 'numberp str) 
         (< 1 (length str) 4)
    )
    (trans str 0 0)
  )
)


;; Ajoute autant de caratères que nécessaire au début de la chaîne
;; str : la chaîne
;; len : la longueur de chaîne
;; char : le caractère à ajouter
(defun Remote>>gc:StringPadLeft (str len char) 
  (if (< (strlen str) len) 
    (Remote>>gc:StringPadLeft (strcat char str) len char)
    str
  )
)


;; Ajoute autant de caratères que nécessaire à la fin de la chaîne
;; str : la chaîne
;; len : la longueur de chaîne
;; char : le caractère à ajouter
(defun Remote>>gc:StringPadRight (str len char) 
  (if (< (strlen str) len) 
    (Remote>>gc:StringPadRight (strcat str char) len char)
    str
  )
)


;; Retourne un liste de chaînes triés en tenant compte de la valeur
;; des chiffres placés au début
;; lst : la liste de chaînes à trier
(defun Remote>>gc:NumStrSort (lst / pref) 

  (defun pref (str / l1 l2) 
    (setq l1 (vl-string->list str))
    (while (< 47 (car l1) 58) 
      (setq l2 (cons (car l1) l2)
            l1 (cdr l1)
      )
    )
    (vl-list->string (reverse l2))
  )

  (vl-sort lst 
           '(lambda (x1 x2 / n1 n2) 
              (if 
                (and (/= (setq n1 (pref x1)) "") 
                     (/= (setq n2 (pref x2)) "")
                     (/= n1 n2)
                )
                (< (atoi n1) (atoi n2))
                (< x1 x2)
              )
            )
  )
)


;; Incrémente une chaine numéraire
;; str : la chaîne
(defun Remote>>gc:IncrNumStr (str / l) 
  (Remote>>gc:StringPadLeft "0" (strlen str) (itoa (1+ (atoi str))))
)


;; Incrémente le suffixe d'une chaîne de caractères de la valeur spécifiée.
;; Est pris en compte comme suffixe, l'ensemble des caractères [0-9] et/ou [A-Z] et/ou [a-z]
;; plus le séparateur (optionnel) depuis la fin du texte, en fonction de la valeur de 'alpha'
;; str : la chaîne
;; alpha : drapeau indiquant le type de chaîne à incrémenter somme des code binaires suivant :
;;         - 1 nombres entiers
;;         - 2 majuscules
;;         - 4 minuscules
;; sep : caractère devant être considéré comme séparateur (ou nil)
(defun Remote>>gc:IncSuff (str inc alpha sep / number upper lower lst crt pas ind val quo ret) 
  (defun number (x) (and (< 47 x 58) (= 1 (logand 1 alpha))))
  (defun upper (x) (and (< 64 x 91) (= 2 (logand 2 alpha))))
  (defun lower (x) (and (< 96 x 123) (= 4 (logand 4 alpha))))
  (setq lst (reverse (vl-string->list str))
        sep (if sep 
              (ascii sep)
              0
            )
  )
  (while 
    (and 
      (setq crt (car lst))
      (if (= sep crt) 
        (if 
          (or 
            (setq num (number (cadr lst)))
            (setq upr (upper (cadr lst)))
            (setq lwr (lower (cadr lst)))
          )
          (setq lst (cdr lst)
                crt (car lst)
                ret (cons sep ret)
          )
          T
        )
        (or 
          (setq num (number crt))
          (setq upr (upper crt))
          (setq lwr (lower crt))
          T
        )
      )
      (cond 
        (num
         (setq pas 10
               ind 48
         )
        )
        (upr
         (setq pas 26
               ind 65
         )
        )
        (lwr
         (setq pas 26
               ind 97
         )
        )
        ((< 0 quo)
         (setq crt (if (= 10 pas) 
                     ind
                     (1- ind)
                   )
               lst (cons (car lst) lst)
         )
        )
      )
    )
    (setq val (- crt ind)
          quo (/ (+ val inc) pas)
          ret (cons (+ ind (rem (+ val inc) pas)) ret)
    )
    (if (zerop quo) 
      (setq ret (append (reverse (cdr lst)) ret)
            lst nil
      )
      (if (cdr lst) 
        (setq lst (cdr lst)
              inc quo
        )
        (setq lst (list ind)
              inc (if (= 10 pas) 
                    quo
                    (1- quo)
                  )
        )
      )
    )
  )
  (if ret 
    (vl-list->string ret)
  )
)


;; Evalue si les caractères ouvrant et fermant sont appariée dans une chaine
;; op : le caractère ouvrant
;; cl : le caractère fermant
;; str : la chaîne
(defun Remote>>gc:Balanced (op cl str / n r) 
  (setq n   0
        r   T
        str (vl-string->list str)
  )
  (while (and r str) 
    (cond 
      ((= (car str) op) (setq n (1+ n)))
      ((= (car str) cl) (setq n (1- n)))
    )
    (setq r   (<= n 0)
          str (cdr str)
    )
  )
  r
)


;; Retourne la liste des positions d'un caractère ouvrant et de son équivalent fermant
;; op : le caractère ouvrant
;; cl : le caractère fermant
;; str : la chaîne
;; pos : index de départ de la recherche
(defun Remote>>gc:Apaired (op cl str pos / opened closed start tmp cnt) 
  (and 
    (setq opened (vl-string-search op str pos))
    (setq start  (1+ opened)
          closed T
          cnt    1
    )
    (while (and closed (< 0 cnt)) 
      (setq tmp    (vl-string-search op str start)
            closed (vl-string-search cl str start)
      )
      (if closed 
        (if (and tmp (< tmp closed)) 
          (setq cnt   (1+ cnt)
                start (1+ tmp)
          )
          (setq cnt   (1- cnt)
                start (1+ closed)
          )
        )
      )
    )
  )
  (if (= 0 cnt) 
    (list opened closed)
  )
)


;; Retourne la chaîne de caractère d'un attribut, texte ou mtexte
;; avec le(s) code(s) de champ(s)
;; ent : le nom d'entité du texte, mtexte ou attribut
(defun Remote>>gc:FieldCode (ent / foo elst xdict dict field str) 

  (defun foo (field str / pos fldID objID) 
    (setq pos 0)
    (if (setq pos (vl-string-search "\\_FldIdx " str pos)) 
      (while (setq pos (vl-string-search "\\_FldIdx " str pos)) 
        (setq fldId (entget (cdr (assoc 360 field)))
              field (vl-remove (assoc 360 field) field)
              str   (strcat 
                      (substr str 1 pos)
                      (if (setq objID (cdr (assoc 331 fldId))) 
                        (vl-string-subst 
                          (strcat "ObjId " (itoa (Remote>>gc:EnameToObjectId objID)))
                          "ObjIdx"
                          (cdr (assoc 2 fldId))
                        )
                        (foo fldId (cdr (assoc 2 fldId)))
                      )
                      (substr str (1+ (vl-string-search ">%" str pos)))
                    )
        )
      )
      str
    )
  )

  (setq elst (entget ent))
  (if 
    (and 
      (member (cdr (assoc 0 elst)) '("ATTRIB" "MTEXT" "TEXT"))
      (setq xdict (cdr (assoc 360 elst)))
      (setq dict (dictsearch xdict "ACAD_FIELD"))
      (setq field (dictsearch (cdr (assoc -1 dict)) "TEXT"))
    )
    (setq str (foo field (cdr (assoc 2 field))))
  )
)


;; Retourne l'ObjectID correspondant à un ename
;; ent : le nom d'entité
(defun Remote>>gc:EnameToObjectId (ename) 
  ((lambda (str) 
     (Remote>>gc:hex2dec 
       (substr (vl-string-right-trim ">" str) (+ 3 (vl-string-search ":" str)))
     )
   ) 
    (vl-princ-to-string ename)
  )
)


;; Crypte la chaine avec la méthode ROT13
;; s : la chaîne
(defun Remote>>gc:Rot13 (s) 
  (vl-list->string 
    (mapcar 
      (function 
        (lambda (x) 
          (cond 
            ((<= 65 x 90) (+ 65 (rem (- x 52) 26)))
            ((<= 97 x 122) (+ 97 (rem (- x 84) 26)))
            (x)
          )
        )
      )
      (vl-string->list s)
    )
  )
)


;; Crypte la chaine avec la méthode ROT47
;; s : la chaîne
(defun Remote>>gc:Rot47 (s) 
  (vl-list->string 
    (mapcar 
      (function 
        (lambda (x) 
          (if (<= 33 x 126) 
            (+ 33 (rem (+ x 14) 94))
            x
          )
        )
      )
      (vl-string->list s)
    )
  )
)


;; Convertit un nombre hexadécimal (chaine) en un entier
;; n : la chaîne figurant le nombre hexadécimal
(defun Remote>>gc:hex2dec (n / r s) 
  (setq r 0)
  (foreach s (vl-string->list (strcase n)) 
    (setq r (+ 
              (* r 16)
              (- s 
                 (if (<= s 57) 
                   48
                   55
                 )
              )
            )
    )
  )
)


;; Convertit un entier en un nombre hexadécimal (chaine)
;; n : l'entier
(defun Remote>>gc:int2hex (n / r i) 
  (setq r "")
  (while (> n 0) 
    (setq i (fix (rem n 16))
          n (/ (- n i) 16)
          r (strcat 
              (if (< i 10) 
                (itoa i)
                (chr (+ 55 i))
              )
              r
            )
    )
  )
)


;; Convertit un nombre hexadécimal (chaine) en un entier long (chaine)
;; n : la chaîne figurant le nombre hexadécimal
(defun Remote>>gc:hex2long (n / r s) 
  (setq r 0.)
  (rtos 
    (foreach s (vl-string->list (strcase n)) 
      (setq r (+ 
                (* r 16.)
                (- s 
                   (if (<= s 57) 
                     48.
                     55.
                   )
                )
              )
      )
    )
    2
    0
  )
)


;; Convertit un entier long (chaine) en un nombre hexadécimal (chaine)
;; n : la chaîne figurant l'entier long
(defun Remote>>gc:long2hex (n / r i) 
  (setq r ""
        n (atof n)
  )
  (while (> n 0) 
    (setq i (fix (rem n 16))
          n (/ (- n i) 16)
          r (strcat 
              (if (< i 10) 
                (itoa i)
                (chr (+ 55 i))
              )
              r
            )
    )
  )
)


;; Convertit un entier en caractères alphabétiques (majuscules)
;; num : un nombre entier
(defun Remote>>gc:num2alpha (num) 
  (if (< num 27) 
    (chr (+ 64 num))
    (if (zerop (rem num 26)) 
      (strcat (Remote>>gc:num2alpha (1- (/ num 26))) "Z")
      (strcat (Remote>>gc:num2alpha (/ num 26)) 
              (chr (+ 64 (rem num 26)))
      )
    )
  )
)


;; Convertit une chaine en entier (insensible à la casse)
;; str : la chaîne
(defun Remote>>gc:alpha2num (str) 
  (if (zerop (strlen str)) 
    0
    (+ 
      (* (- (ascii (strcase (substr str 1 1))) 64) 
         (expt 26 (1- (strlen str)))
      )
      (Remote>>gc:alpha2num (substr str 2))
    )
  )
)
;#endregion
;#region List

;; Lie des valeurs à des symboles et les passe en arguments dans une expression lambda
;; http://www.theswamp.org/index.php?topic=26792
;; bindings : liste de paires (symbole valeur)
;; body     : corps de l'expression lambda
;;
;; Exemple
;; (Remote>>gc:let '((a 3) (b 5)) '(* a b)) => 15
(defun Remote>>gc:let (bindings body) 
  (eval 
    (cons 
      (list 'lambda (mapcar 'car bindings) body)
      (mapcar 'cadr bindings)
    )
  )
)


;; Retourne la liste privée du dernier élément
;; l : une liste
(defun Remote>>gc:butLast (l) (reverse (cdr (reverse l))))


;; Retourne la liste de toutes les valeurs pour le code spécifié dans une liste d'association
;; key : la clé à rechercher dans la liste
;; alst : une liste d'association
(defun Remote>>gc:massoc (key alst) 
  (if (setq alst (member (assoc key alst) alst)) 
    (cons (cdar alst) (Remote>>gc:massoc key (cdr alst)))
  )
)


;; Retourne une liste de deux sous listes,
;; la première contenant les n premiers éléments, la seconde les éléments restants
;; n : le nombre d'éléments pour la première sous liste
;; l : une liste
(defun Remote>>gc:breakAt (n l / r) 
  (while (and l (< 0 n)) 
    (setq r (cons (car l) r)
          l (cdr l)
          n (1- n)
    )
  )
  (list (reverse r) l)
)


;; Retourne les n premiers éléments de la liste
;; n : le nombre d'éléments
;; l : une liste
(defun Remote>>gc:take (n l) 
  (if (and l (< 0 n)) 
    (cons (car l) (Remote>>gc:take (1- n) (cdr l)))
  )
)


;; Retourne la liste moins les n premiers éléments
;; n : le nombre d'éléments
;; l : une liste
(defun Remote>>gc:skip (n l) 
  (if (and l (< 0 n)) 
    (Remote>>gc:skip (1- n) (cdr l))
    l
  )
)


;; Divise une liste en sous-listes de la longueur spécifiée
;; n : le nombre d'éléments de chaque sous liste
;; l : une liste
(defun Remote>>gc:split (n l / s) 
  (if (and l (setq s (Remote>>gc:breakat n l))) 
    (cons (car s) (Remote>>gc:split n (cadr s)))
  )
)


;; Convertit une liste de coordonnées 2D en liste de points 2D
;; l : une liste
(defun Remote>>gc:split2 (l) 
  (if l 
    (cons (list (car l) (cadr l)) 
          (Remote>>gc:split2 (cddr l))
    )
  )
)


;; Convertit une liste de coordonnées 3D en liste de points
;; l : une liste
(defun Remote>>gc:split3 (l) 
  (if l 
    (cons (list (car l) (cadr l) (caddr l)) 
          (Remote>>gc:split3 (cdddr lst))
    )
  )
)


;; Retourne la sous liste de n éléments à partir de i
;; i : index du premier élément
;; n : nombre d'éléments
;; l : une liste
(defun Remote>>gc:sublist (i n l) 
  (Remote>>gc:take n (Remote>>gc:skip i l))
)


;; Retourne la liste des éléments communs à l1 et l2
;; l1 : une liste
;; l2 : une liste
(defun Remote>>gc:intersect (l1 l2) 
  (if l1 
    (if (member (car l1) l2) 
      (cons (car l1) (Remote>>gc:intersect (cdr l1) l2))
      (Remote>>gc:intersect (cdr l1) l2)
    )
  )
)


;; Retourne une liste contenant les éléments appartenant exclusivement à l1
;; l1 : une liste
;; l2 : une liste
(defun Remote>>gc:substract (l1 l2) 
  (if l1 
    (if (member (car l1) l2) 
      (Remote>>gc:substract (cdr l1) l2)
      (cons (car l1) (Remote>>gc:substract (cdr l1) l2))
    )
  )
)


;; Suprime tous les doublons d'une liste
;; l : une liste
(defun Remote>>gc:distinct (l) 
  (if l 
    (cons (car l) (Remote>>gc:distinct (vl-remove (car l) l)))
  )
)


;; Retourne la liste sans la première occurence de l'expression
;; ele : l'élément à supprimer
;; lst : la liste
(defun Remote>>gc:removeFirst (ele lst) 
  (if (equal ele (car lst)) 
    (cdr lst)
    (cons (car lst) (Remote>>gc:removeFirst ele (cdr lst)))
  )
)


;; Insère l'élément dans la liste à l'indice
;; ele : l'élément à insérer
;; ind : l'index auquel insérer l'élément
;; lst : la liste
(defun Remote>>gc:insertAt (ele ind lst) 
  (cond 
    ((null lst) (list ele))
    ((zerop ind) (cons ele lst))
    ((cons (car lst) (Remote>>gc:insertAt ele (1- ind) (cdr lst))))
  )
)


;; Insère les éléments dans la liste à partir l'indice
;; new : la liste d'éléments à insérer
;; ind : l'index auquel insérer l'élément
;; lst : la liste
(defun Remote>>gc:insertRange (new ind lst) 
  (cond 
    ((null lst) new)
    ((zerop ind) (append new lst))
    ((cons (car lst) (Remote>>gc:insertRange new (1- ind) (cdr lst))))
  )
)


;; Retourne la liste privée de l'élément à l'indice spécifié
;; ind : l'index de l'élément à supprimer
;; lst : la liste
(defun Remote>>gc:removeAt (ind lst) 
  (if (or (zerop ind) (null lst)) 
    (cdr lst)
    (cons (car lst) (Remote>>gc:removeAt (1- ind) (cdr lst)))
  )
)


;; Supprime le nombre d'éléments de la liste à partir de l'indice
;; ind : l'index à partir duquel supprimer les éléments
;; cnt : le nombre d'éléments à supprimer
;; lst : la liste
(defun Remote>>gc:removeRange (from cnt lst) 
  (cond 
    ((or (null lst) (zerop cnt)) lst)
    ((< 0 from) (cons (car lst) (Remote>>gc:removeRange (1- from) cnt (cdr lst))))
    ((Remote>>gc:removeRange from (1- cnt) (cdr lst)))
  )
)


;; Remplace l'élément à l'indice dans la liste
;; ele : l'élément à substituer
;; ind : l'index auquel substituer l'élément
;; lst : la liste
(defun Remote>>gc:SubstAt (ele ind lst) 
  (cond 
    ((null lst) nil)
    ((zerop ind) (cons ele (cdr lst)))
    ((cons (car lst) (Remote>>gc:substAt ele (1- ind) (cdr lst))))
  )
)


;; Remplace les éléments de la liste à partir de l'indice
;; new : la liste d'éléments à substituer
;; ind : l'index à partir duquel substituer les éléments
;; lst : la liste
(defun Remote>>gc:substRange (new ind lst) 
  (cond 
    ((or (null lst) (null new)) lst)
    ((zerop ind) (cons (car new) (Remote>>gc:substRange (cdr new) ind (cdr lst))))
    ((cons (car lst) (Remote>>gc:substRange new (1- ind) (cdr lst))))
  )
)


;; Retourne la liste tronquée à partir de la première occurrence
;; de l'expression (liste complémentaire de celle retournée par MEMBER)
;; expr : l'expression recherchée
;; lst : la liste
(defun Remote>>gc:trunc (expr lst) 
  (if 
    (and lst 
         (not (equal (car lst) expr))
    )
    (cons (car lst) (Remote>>gc:trunc expr (cdr lst)))
  )
)


;; Retourne la liste tronquée à partir de la première occurrence qui
;; retourne T à la fonction (complémentaire de celle retournée par VL-MEMBER-IF)
;; fun : la fonction prédicat
;; lst : la liste
(defun Remote>>gc:truncIf (fun lst) 
  (if 
    (and lst 
         (not ((eval fun) (car lst)))
    )
    (cons (car lst) (Remote>>gc:Trunctf fun (cdr lst)))
  )
)


;; Comme gc:Trunc avec une tolérance dans la comparaison
;; expr : l'expression recherchée
;; lst : la liste
;; fuzz : la tolérance
(defun Remote>>gc:truncFuzz (expr lst fuzz) 
  (if 
    (and lst 
         (not (equal (car lst) expr))
    )
    (cons (car lst) (Remote>>gc:truncFuzz expr (cdr lst) fuzz))
  )
)


;; Comme member avec une tolérance dans la comparaison
;; expr : l'expression recherchée
;; lst : la liste
;; fuzz : la tolérance
(defun Remote>>gc:memberFuzz (expr lst fuzz) 
  (while (and lst (not (equal (car lst) expr fuzz))) 
    (setq lst (cdr lst))
  )
  lst
)


;; Transforme un chaine avec séparateur en liste de chaines
;; str : la chaîne
;; sep : le séparateur
(defun Remote>>gc:str2lst (str sep / pos) 
  (if (setq pos (vl-string-search sep str)) 
    (cons (substr str 1 pos) (Remote>>gc:str2lst (substr str (+ (strlen sep) pos 1)) sep))
    (list str)
  )
)


;; Concatène une liste de chaînes et un séparateur en une chaine
;; lst : la liste
;; sep : le séparateur
(defun Remote>>gc:lst2str (lst sep) 
  (apply 'strcat 
         (cons (car lst) 
               (mapcar (function (lambda (x) (strcat sep x))) (cdr lst))
         )
  )
)


;; Retourne l'état final d'un accumulateur dont l'état initial est modifié
;; par l'application d'une fonction à chacun des éléments d'une liste
;; fun : la fonction à appliquer à chaque élément
;; acc : l'accumulateur
;; lst : la liste
(defun Remote>>gc:fold (fun acc lst) 
  (setq fun (eval fun))
  (foreach n lst (setq acc (fun acc n)))
)


;; Génère une liste à partir d'une fonction de calcul qui prend un état
;; et le modifie pour produire chaque élément suivant de la séquence
;; fun : la fonction de calculer à chaque élément
;; state : l'état initial
(defun Remote>>gc:unfold (fun state) 
  ((lambda (pair) 
     (if pair 
       (cons (car pair) (Remote>>gc:unfold fun (cdr pair)))
     )
   ) 
    ((eval fun) state)
  )
)


;; Retourne l'état final d'un accumulateur résultat de l'application
;; d'une fonction à chacun des éléments d'une liste
;; fun : la fonction à appliquer à chaque élément
;; lst : la liste
(defun Remote>>gc:reduce (fun lst) 
  (Remote>>gc:fold fun (car lst) (cdr lst))
)


;; Regroupe les éléments d'une liste selon la clé générée par la fonction spécifiée.
;; Retourne un liste de sous listes dont le premier élément est la clé.
;; fun : la fonction génératrice de clé
;; lst : la liste
(defun Remote>>gc:groupBy (fun lst / key sub res) 
  (setq fun (eval fun))
  (mapcar 
    '(lambda (l) (cons (car l) (reverse (cdr l))))
    (foreach l lst 
      (setq res (if (setq sub (assoc (setq key (fun l)) res)) 
                  (subst (vl-list* key l (cdr sub)) sub res)
                  (cons (list key l) res)
                )
      )
    )
  )
)

;#endregion
;#region MathGeom

;; Retourne la liste des codes binaires contenus dans un entier
;; n : un nombre entier
(defun Remote>>gc:binList (n / b l) 
  (while (/= 0 n) 
    (setq b (expt 2 (fix (/ (log n) (log 2))))
          n (- n b)
          l (cons b l)
    )
  )
)


;; Convertit un hexadécimal (string) en décimal (int)
;; s : une chaîne représentant un nombre hexadécimal
(defun Remote>>gc:hex2dec (s / f) 
  (defun f (l a / c) 
    (if (setq c (car l)) 
      (f 
        (cdr l)
        (+ 
          (cond 
            ((< 96 c 103) (- c 87))
            ((< 64 c 71) (- c 55))
            ((< 47 c 58) (- c 48))
          )
          (lsh a 4)
        )
      )
      a
    )
  )
  (f (vl-string->list s) 0)
)


;; Convertit un décimal (int) en hexadécimal (string)
;; n : un nombre entier
(defun Remote>>gc:dec2hex (n) 
  (cond 
    ((< 15 n)
     (strcat (Remote>>gc:dec2hex (lsh n -4)) (Remote>>gc:dec2hex (rem n 16)))
    )
    ((< n 10) (itoa n))
    (T (chr (+ n 55)))
  )
)


;; Arrondit à la valeur entière la plus proche
;; num : le nombre à arrondir
(defun Remote>>gc:round (num) 
  (if (minusp num) 
    (fix (- num 0.5))
    (fix (+ num 0.5))
  )
)


;; Arrondit à la valeur la plus proche en fonction de prec
;; prec : le nombre spécifiant la précision de l'arrondi
;; num : le nombre à arrondir
(defun Remote>>gc:roundTo (prec num) 
  (if (zerop (setq prec (abs prec))) 
    num
    (* prec (Remote>>gc:round (/ num prec)))
  )
)


;; Arrondit les nombres dans les points, listes de points, etc
;; lst : une liste de nombres et/ou de sous-listes de nombres
;; prec : le nombre spécifiant la précision de l'arrondi
(defun Remote>>gc:RoundRec (lst prec) 
  (if (listp lst) 
    (mapcar '(lambda (x) (Remote>>gc:RoundRec x prec)) lst)
    (Remote>>gc:roundTo lst prec)
  )
)


;; Arrondit à 0 les nombres compris entre -fuzz et fuzz
;; Fonctionne avec les nombres et les listes de nombres (même imbriquées)
;; num : le nombre à arrondir
;; fuzz : la tolérance
(defun Remote>>gc:FixZero (num fuzz) 
  (if (listp num) 
    (mapcar '(lambda (x) (Remote>>gc:FixZero x fuzz)) num)
    (if (equal num 0. fuzz) 
      0.
      num
    )
  )
)


;; Retourne le logarithme décimal du nombre
;; x : un nombre strictement positif
(defun Remote>>gc:Log10 (x) 
  (/ (log x) (log 10))
)


;; Retourne la tolérance utilisable pour comparaison en fonction
;; du nombre de chiffres significatifs de x
;; x : le nombre
(defun Remote>>gc:Fuzz (x) 
  (if (zerop x) 
    1e-15
    (expt 10.0 (fix (- (Remote>>gc:Log10 (abs x)) 15)))
  )
)


;; Evalue si deux nombres sont égaux en utilisant une tolérance calculée
;; en fonction du nombre de chiffres significatifs de x et y
;; x et y : les nombres à comparer
(defun Remote>>gc:EqualNumbers (x y) 
  (or (= x y) (equal x y (max (Remote>>gc:Fuzz x) (Remote>>gc:Fuzz y))))
)


;; Retourne un nombre "pseudo-aléatoire" entre 0 et 1
(defun Remote>>gc:random () 
  (or *seed* (setq *seed* (getvar "DATE")))
  (setq *seed* (rem (1+ (* 1664525 *seed*)) 4294967296.))
  (/ *seed* 4294967296.)
)


;; Retourne un nombre "pseudo-aléatoire" entre mini et maxi arrondi au pas spécifié
;; mini : le nombre minimum
;; maxi : le nombre maximum
;; step : le pas
(defun Remote>>gc:StepRandom (mini maxi step) 
  (+ mini (Remote>>gc:round (* (- maxi mini) (rng)) step))
)


;; Retourne une chaine qui est la représentation binaire de num
;; num : un nombre entier
(defun Remote>>gc:int2bin (num / n s) 
  (setq n 1
        s (itoa (rem num 2))
  )
  (while (< 0 (/ num (expt 2 n))) 
    (if (/= 0 (logand num (expt 2 n))) 
      (setq s (strcat "1" s))
      (setq s (strcat "0" s))
    )
    (setq n (1+ n))
  )
  s
)


;; Retourne l'entier auquel correspond la représentation binare bin
;; bin : chaîne uniquement composée de 0 et de 1
(defun b2d (bin / n s) 
  (setq n (strlen bin)
        s 0
  )
  (repeat n 
    (setq n (1- n))
    (if (= "1" (substr bin 1 1)) 
      (setq s (+ s (expt 2 n)))
    )
    (setq bin (substr bin 2))
  )
  s
)


;; Evalue si un nombre est premier
;; n : un nombre entier
(defun Remote>>gc:isPrime (n / f) 
  (defun f (i) 
    (or 
      (> (* i i) n)
      (and 
        (/= 0 (rem n i))
        (f (i + 2))
      )
    )
  )
  (or 
    (< n 4)
    (and 
      (/= 0 (rem n 2))
      (f 3)
    )
  )
)

;;------------------------------------------------;;
;;-------------------- POINTS --------------------;;
;;------------------------------------------------;;


;; Évalue si p est un point valide
;; p : l'expression à évaluer
(defun Remote>>gc:PointP (p) 
  (and 
    (listp p)
    (<= 2 (length p) 3)
    (vl-every 'numberp p)
  )
)


;; Evalue si deux points sont égaux en utilisant une tolérance calculée
;; en fonction du nombre de chiffres significatifs des coordonnées
;; p1 et p2 : les points à comparer
(defun Remote>>gc:EqualPoints (p1 p2) 
  (vl-every 'Remote>>gc:EqualNumbers p1 p2)
)


;; Retourne le milieu de p1 p2
;; p1 : un point
;; p2 : un point
(defun Remote>>gc:MidPoint (p1 p2) 
  (mapcar (function (lambda (x1 x2) (/ (+ x1 x2) 2.))) p1 p2)
)


;; Evalue si pt est entre p1 et p2
;; p1 : un point
;; p2 : un point
;; pt : le point à évaluer
(defun Remote>>gc:BetweenP (p1 p2 pt) 
  (or (equal p1 pt 1e-9) 
      (equal p2 pt 1e-9)
      (equal (Remote>>gc:GetUnitVector p1 pt) 
             (Remote>>gc:GetUnitVector pt p2)
             1e-9
      )
  )
)


;; Retourne la distance du point pt à la droite p1 p2
;; pt : le point extérieur à la droite
;; p1 : un point sur la droite
;; p2 : un point sur la droite
(defun Remote>>gc:DistanceTo (pt p1 p2) 
  ((lambda (v) 
     (/ 
       (distance '(0. 0. 0.) (Remote>>gc:CrossProduct (mapcar '- pt p1) v))
       (distance '(0. 0. 0.) v)
     )
   ) 
    (mapcar '- p2 p1)
  )
)


;; Retourne la liste des points qui divisent le segment p1 p2 en n segments égaux
;; p1 : le point à une extrémité du segment
;; p2 : le point à l'autre extrémité du segment
;; n  : le nombre de divisions
(defun Remote>>gc:DivSeg (p1 p2 n / v l) 
  (setq v (mapcar (function (lambda (x1 x2) (/ (- x2 x1) n))) p1 p2)
        l (cons p2 l)
  )
  (while (< 0 (setq n (1- n))) 
    (setq l (cons 
              (mapcar (function (lambda (x1 x2) (+ x1 (* x2 n)))) p1 v)
              l
            )
    )
  )
  (cons p1 l)
)


;; Retourne la liste des points formant l'envloppe convexe
;; pts : la liste des points
(defun Remote>>gc:ConvHull (pts / p0) 
  (setq pts (vl-sort pts 
                     '(lambda (p1 p2) 
                        (if (= (cadr p1) (cadr p2)) 
                          (< (car p1) (car p2))
                          (< (cadr p1) (cadr p2))
                        )
                      )
            )
        p0  (car pts)
        pts (vl-sort (cdr pts) 
                     '(lambda (p1 p2 / d1 d2 c1 c2) 
                        (setq d1 (distance p0 p1)
                              d2 (distance p0 p2)
                        )
                        (if 
                          (equal (setq c1 (/ (- (car p0) (car p1)) d1)) 
                                 (setq c2 (/ (- (car p0) (car p2)) d2))
                                 1e-9
                          )
                          (< d1 d2)
                          (< c1 c2)
                        )
                      )
            )
        acc (list (car pts) p0)
        pts (cdr pts)
  )
  (foreach p pts 
    (while (and (cdr acc) (Remote>>gc:clockwise (cadr acc) (car acc) p)) 
      (setq acc (cdr acc))
    )
    (setq acc (cons p acc))
  )
  (reverse acc)
)

;;------------------------------------------------;;
;;-------------------- ANGLES --------------------;;
;;------------------------------------------------;;


;; Évalue si un angle est égal à k*pi radians à 0.000000001 près.
;; a : la valeur de l'angle en radians
(defun Remote>>gc:EqualK*Pi (a) 
  (or 
    (equal (rem a pi) 0. 1e-009)
    (equal (abs (rem a pi)) pi 1e-009)
  )
)


;; Retourne la tangente de l'angle
;; a : la valeur de l'angle en radians
(defun Remote>>gc:Tan (a) (/ (sin a) (cos a)))


;; Retourne l'arc sinus du nombre
;; x : le sinus de l'angle
(defun Remote>>gc:asin (x) 
  (cond 
    ((equal x 1. 1e-9) (/ pi 2.))
    ((equal x -1. 1e-9) (/ pi -2.))
    ((< -1. x 1.)
     (atan x (sqrt (- 1 (* x x))))
    )
  )
)


;; Retourne l'arc cosinus du nombre
;; x : le cosinus de l'angle
(defun Remote>>gc:acos (x) 
  (cond 
    ((equal x 1. 1e-9) 0.)
    ((equal x -1. 1e-9) pi)
    ((< -1. x 1.)
     (atan (sqrt (- 1. (* x x))) x)
    )
  )
)


;; Retourne l'angle, à 2*k*pi près, compris entre 0 et 2*pi
;; a : la valeur de l'angle en radians
(defun Remote>>gc:Ang<2pi (a) 
  (if (and (<= 0. a) (< a (* 2. pi))) 
    a
    (Remote>>gc:Ang<2pi (rem (+ a (* 2. pi)) (* 2. pi)))
  )
)


;; Retourne le cosinus hyperbolique du nombre
;; x : un nombre
(defun Remote>>gc:cosh (x) 
  (/ (+ (exp x) (exp (- x))) 2.)
)			


;; Retourne le sinus hyperbolique du nombre
;; x : un nombre
(defun Remote>>gc:sinh (x) 
  (/ (- (exp x) (exp (- x))) 2.)
)


;; Retourne la tangente hyperbolique du nombre
;; x : un nombre
(defun Remote>>gc:tanh (x) 
  (/ (- (exp x) (exp (- x))) (+ (exp x) (exp (- x))))
)


;; Retourne l'argument sinus hyperbolique du nombre
;; x : un nombre
(defun Remote>>gc:asinh (x) 
  (log (+ x (sqrt (+ (* x x) 1.))))
)


;; Retourne l'argument cosinus hyperbolique du nombre
;; x : un nombre compris supérieur ou égal à 1.0
(defun Remote>>gc:acosh (x) 
  (if (<= 1. x) 
    (log (+ x (sqrt (- (* x x) 1.))))
  )
)


;; Retourne l'argument tangente hyperbolique du nombre
;; x : un nombre strictement compris entre -1.0 et 1.0
(defun Remote>>gc:atanh (x) 
  (if (< -1. x 1.) 
    (/ (log (/ (+ 1. x) (- 1. x))) 2.)
  )
)

;;-----------------------------------------------;;
;;------------------ TRIANGLES ------------------;;
;;-----------------------------------------------;;


;; Retourne le vecteur normal du plan défini par p1 p2 p3
;; p1, p2, p3 trois points 3d figurant un triangle dans l'espace
(defun Remote>>gc:Normal3Pts (p1 p2 p3) 
  (list 
    (- (* (- (cadr p2) (cadr p1)) (- (caddr p3) (caddr p1))) 
       (* (- (caddr p2) (caddr p1)) (- (cadr p3) (cadr p1)))
    )
    (- (* (- (caddr p2) (caddr p1)) (- (car p3) (car p1))) 
       (* (- (car p2) (car p1)) (- (caddr p3) (caddr p1)))
    )
    (- (* (- (car p2) (car p1)) (- (cadr p3) (cadr p1))) 
       (* (- (cadr p2) (cadr p1)) (- (car p3) (car p1)))
    )
  )
)


;; Evalue si les points p1 p2 et p3 tournent dans le sens horaire
;; p1, p2, p3 trois points 2d figurant un triangle dans le plan XY
(defun Remote>>gc:Clockwise (p1 p2 p3) 
  (< 
    (- (* (- (car p2) (car p1)) (- (cadr p3) (cadr p2))) 
       (* (- (cadr p2) (cadr p1)) (- (car p3) (car p2)))
    )
    1e-12
  )
)


;; Retourne l'angle défini par son sommet (p0) et deux points (p1 et p2)
;; L'angle retourné est toujours positif et inférieur à pi radians.
;; p0 : le point au sommet de l'angle
;; p1 : un point délimitant le secteur angulaire
;; p2 : un point délimitant le secteur angulaire
(defun Remote>>gc:Angle3Pts (p0 p1 p2) 
  ((lambda (v1 v2) 
     (Remote>>gc:acos 
       (/ 
         (Remote>>gc:DotProduct v1 v2)
         (* (Remote>>gc:VecLength v1) (Remote>>gc:VecLength v2))
       )
     )
   ) 
    (mapcar '- p1 p0)
    (mapcar '- p2 p0)
  )
)


;; Retourne le centre, le rayon et la normale du cercle inscrit dans le triangle p1 p2 p3
;; p1, p3, p3 : 3 points décrivant un triangle dans l'espace
(defun Remote>>gc:Inscribe (p1 p2 p3 / v1 v2 n c) 
  (setq v1 (Remote>>gc:GetNormal (mapcar '- p2 p1))
        v2 (Remote>>gc:GetNormal (mapcar '- p3 p1))
        n  (Remote>>gc:GetNormal (Remote>>gc:CrossProduct v1 v2))
  )
  (list 
    (setq c (inters 
              p1
              (mapcar '+ p1 v1 v2)
              p2
              (mapcar '+ p2 v1 (Remote>>gc:GetNormal (mapcar '- p2 p3)))
              nil
            )
    )
    (distance '(0. 0. 0.) (Remote>>gc:CrossProduct (mapcar '- c p1) v1))
    n
  )
)


;; Retourne le centre, le rayon et la normale du cercle circonscrit au le triangle p1 p2 p3
;; p1, p3, p3 : 3 points décrivant un triangle dans l'espace
(defun Remote>>gc:Circumscribe (p1 p2 p3 / v1 v2 n m1 m2 c) 
  (setq v1 (mapcar '- p2 p1)
        v2 (mapcar '- p3 p1)
        n  (Remote>>gc:CrossProduct v1 v2)
        m1 (Remote>>gc:MidPoint p1 p2)
        m2 (Remote>>gc:MidPoint p1 p3)
  )
  (list 
    (setq c (inters 
              m1
              (mapcar '+ m1 (Remote>>gc:CrossProduct v1 n))
              m2
              (mapcar '+ m2 (Remote>>gc:CrossProduct v2 n))
              nil
            )
    )
    (distance c p1)
    (Remote>>gc:GetNormal n)
  )
)


;; Retourne l'aire algébrique (signée) du triangle p1, p2, p3
;; p1, p3, p3 : 3 points 2d décrivant un triangle dans le plan XY
(defun Remote>>gc:AlgebraicArea (p1 p2 p3) 
  (/ 
    (- 
      (* (- (car p2) (car p1)) 
         (- (cadr p3) (cadr p1))
      )
      (* (- (car p3) (car p1)) 
         (- (cadr p2) (cadr p1))
      )
    )
    2.0
  )
)

;;------------------------------------------------;;
;;------------------- VECTEURS -------------------;;
;;------------------------------------------------;;


;; Retourne le vecteur de p1 à p2
;; p1, p2 : 2 points
(defun Remote>>gc:GetVector (p1 p2) (mapcar '- p2 p1))


;; retourne la norme (longueur) du vecteur
;; v : un vecteur
(defun Remote>>gc:VecLength (v) (distance '(0. 0. 0.) v))


;; Multiplie le vecteur par un scalaire
;; v : un vecteur
;; s : un nombre
(defun Remote>>gc:ScaleVector (v s) 
  (mapcar (function (lambda (x) (* x s))) v)
)


;; Retourne le produit scalaire de deux vecteurs
;; Arguments
;; v1, v2 : deux vecteurs
(defun Remote>>gc:DotProduct (v1 v2) (apply '+ (mapcar '* v1 v2)))


;; Retourne le produit vectoriel (vecteur) de deux vecteurs
;; Arguments
;; v1, v2 : deux vecteurs
(defun Remote>>gc:CrossProduct (v1 v2) 
  (list (- (* (cadr v1) (caddr v2)) (* (caddr v1) (cadr v2))) 
        (- (* (caddr v1) (car v2)) (* (car v1) (caddr v2)))
        (- (* (car v1) (cadr v2)) (* (cadr v1) (car v2)))
  )
)


;; Retourne le vecteur unitaire d'un vecteur
;; v : un vecteur
(defun Remote>>gc:GetNormal (v / l) 
  (if (/= 0. (setq l (Remote>>gc:VecLength v))) 
    (Remote>>gc:ScaleVector v (/ 1. l))
  )
)


;; Retourne le vecteur unitaire de sens p1 p2
;; p1, p2 : 2 points
(defun Remote>>gc:GetUnitVector (p1 p2) 
  ((lambda (d) 
     (if (not (zerop d)) 
       (mapcar (function (lambda (x1 x2) (/ (- x2 x1) d))) p1 p2)
     )
   ) 
    (distance p1 p2)
  )
)


;; Retourne le point après rotation sur l'axe défini par p1 p2
;; pt : le point devant subir la rotation
;; p1 : l'origine de l'axe de rotation
;; p2 : un point sur l'axe de rotation
;; ang : l'angle en radians
(defun Remote>>gc:Rotate3d (pt p1 p2 ang) 
  ((lambda (v) 
     (mapcar '+ 
             p1
             (trans 
               (Remote>>gc:mxv 
                 (list (list (cos ang) (- (sin ang)) 0.) 
                       (list (sin ang) (cos ang) 0.)
                       '(0. 0. 1.)
                 )
                 (trans (mapcar '- pt p1) 0 v)
               )
               v
               0
             )
     )
   ) 
    (Remote>>gc:GetVector p1 p2)
  )
)


;; Retourne le vecteur après rotation sur l'axe défini par le vecteur axis
;; vec : le vecteur devant subir la rotation
;; axis : l'axe de rotation (vecteur)
;; ang : l'angle en radians
(defun Remote>>gc:rotate (vec axis ang) 
  (trans 
    (Remote>>gc:mxv 
      (list (list (cos ang) (- (sin ang)) 0.) 
            (list (sin ang) (cos ang) 0.)
            '(0. 0. 1.)
      )
      (trans vec 0 axis)
    )
    axis
    0
  )
)


;; retourne le vecteur après un miroir suivant le plan dont axis est la normale
;; vec : le vecteur devant subir la rotation
;; axis : le vecteur normal du plan
(defun Remote>>gc:MirrorVector (vec axis) 
  ((lambda (v) 
     (trans (list (car v) (cadr v) (- (caddr v))) axis 0)
   ) 
    (trans vec 0 axis)
  )
)


;; Evalue si tous les points de la liste sont colinéiares
;; pts : une liste de points
(defun Remote>>gc:ColinearP (pts / p0) 
  (setq p0 (car pts))
  (vl-every 
    (function 
      (lambda (p1 p2) 
        (equal 
          (Remote>>gc:CrossProduct (Remote>>gc:GetVector p0 p1) (Remote>>gc:GetVector p0 p2))
          '(0. 0. 0.)
          1e-9
        )
      )
    )
    (cdr pts)
    (cddr pts)
  )
)


;; Evalue si les segments p1 p2 et p3 p4 sont parallèles
;; p1 : un point sur le premier segment
;; p2 : un autre point sur le premier segment
;; p3 : un point sur le second segment
;; p4 : un autre point sur le second segment
(defun Remote>>gc:Parallelp (p1 p2 p3 p4) 
  (equal '(0. 0. 0.) 
         (Remote>>gc:CrossProduct (Remote>>gc:GetVector p1 p2) (Remote>>gc:GetVector p3 p4))
         1e-9
  )
)


;; Evalue si les segments p1 p2 et p3 p4 sont perpendiculaires
;; p1 : un point sur le premier segment
;; p2 : un autre point sur le premier segment
;; p3 : un point sur le second segment
;; p4 : un autre point sur le second segment
(defun Remote>>gc:Penpendicularp (p1 p2 p3 p4) 
  (equal (Remote>>gc:DotProduct (Remote>>gc:GetVector p1 p2) (Remote>>gc:GetVector p3 p4)) 
         0
         1e-9
  )
)


;; Evalue si tous les points de la liste sont coplanaires
;; pts : une liste de points
(defun Remote>>gc:Coplanarp (pts / norm zlst) 
  (or 
    (null (cdddr pts))
    (and 
      (setq norm (Remote>>gc:Normal3Pts (car pts) (cadr pts) (caddr pts))
            zlst (mapcar (function (lambda (p) (caddr (trans p 0 norm)))) 
                         pts
                 )
      )
      (vl-every (function (lambda (z) (equal z (car zlst) 1e-9))) 
                (cdr zlst)
      )
    )
  )
)


;; Retourne l'élévation du point par rapport au plan
;; pt : le point dont on cherche l'élévation
;; norm : la normale du plan
;; org : un point sur le plan
(defun Remote>>gc:elevation (pt norm org) 
  (- (caddr (trans pt 0 norm)) (caddr (trans org 0 norm)))
)


;; Retourne la projection de pt sur la droite p1 p2
;; pt : le point à projeter
;; p1 : un point sur la droite
;; p2 : un point sur la droite
(defun Remote>>gc:ProjectOnLine (pt p1 p2) 
  ((lambda (u v) 
     (mapcar '+ p1 (Remote>>gc:ScaleVector u (Remote>>gc:DotProduct u v)))
   ) 
    (Remote>>gc:GetUnitVector p1 p2)
    (Remote>>gc:GetVector p1 pt)
  )
)


;; Retourne la projection de pt sur le plan
;; pt : le point à projeter
;; norm : la normale du plan
;; org : un point sur le plan
(defun Remote>>gc:ProjectOnPlane (pt norm org) 
  ((lambda (p o) 
     (trans (list (car p) (cadr p) (caddr o)) norm 0)
   ) 
    (trans pt 0 norm)
    (trans org 0 norm)
  )
)


;; Retourne le point d'intersection de la droite définie par p1 p2
;; avec le plan défini pas un point et sa normale
;; p1 : un point sur la droite
;; p2 : un autre point sur la droite
;; norm : la normale du plan de projection
;; org : un point sur le plan de projection
;; onSeg : si T, le point d'intersection doit être sur le segment p1, p2
;;         si nil, le segment est prolongé
(defun Remote>>gc:IntersLinePlane (p1 p2 norm org onSeg / scl) 
  (if 
    (and 
      (/= 0. (setq scl (Remote>>gc:DotProduct norm (Remote>>gc:GetVector p1 p2))))
      (or 
        (<= 0. 
            (setq scl (/ (Remote>>gc:DotProduct norm (Remote>>gc:GetVector p1 org)) scl))
            1.
        )
        (not onSeg)
      )
    )
    (mapcar '+ p1 (Remote>>gc:ScaleVector (Remote>>gc:GetVector p1 p2) scl))
  )
)


;; Retourne le point d'intersection de la perpendiculaire à la vue courante passant
;; par le point saisi par l'utilsateur et le plan défini par sa normale et un point.
;; nor : la normale du plan de projection
;; org : un point sur le plan de projection
;; msg : le message affiché pour la saisie du point
(defun Remote>>gc:GetPointAboutPlane (nor org msg / p1 p2 sc) 
  (if 
    (and (setq p1 (getpoint msg)) 
         (setq p1 (trans p1 1 0)
               p2 (trans p1 0 2)
               p2 (trans (list (car p2) (cadr p2) (1+ (caddr p2))) 2 0)
         )
         (/= 0 
             (setq sc (apply '+ (mapcar '* nor (Remote>>gc:GetVector p1 p2))))
         )
    )
    (mapcar 
      (function 
        (lambda (x1 x2) 
          (+ 
            (* (/ (apply '+ (mapcar '* nor (Remote>>gc:GetVector org p1))) sc) 
               (- x1 x2)
            )
            x1
          )
        )
      )
      p1
      p2
    )
  )
)


;; Retourne le vecteur de plus grande pente d'un plan dont n est la normale
;; n : la normale du plan
(defun Remote>>gc:GreatestSlope (n) 
  (Remote>>gc:GetNormal 
    (Remote>>gc:CrossProduct (list (- (cadr n)) (car n) 0.) n)
  )
)


;; Retourne l'expression en pourcentage de la pente d'un plan dont n est la normale
;; n : la normale du plan
(defun Remote>>gc:SlopePercent (n) 
  (if (= 0. (caddr n)) 
    1e99
    (abs 
      (/ 
        (* 100 (sqrt (+ (* (car n) (car n)) (* (cadr n) (cadr n)))))
        (caddr n)
      )
    )
  )
)

;;------------------------------------------------;;
;;------------------- MATRICES -------------------;;
;;------------------------------------------------;;

;; TRP
;; Transpose une matrice -Doug Wilson-
;; m : une matrice
(defun Remote>>gc:trp (m) (apply 'mapcar (cons 'list m)))

;; MXV
;; Applique une matrice de transformation à un vecteur -Vladimir Nesterovsky--
;; m : une matrice
;; v : un vecteur
(defun Remote>>gc:mxv (m v) 
  (mapcar (function (lambda (r) (apply '+ (mapcar '* r v)))) 
          m
  )
)

;; MXM
;; Multiplie (combine) deux matrices -Vladimir Nesterovsky-
;; m : une matrice
;; v : une matrice
(defun Remote>>gc:mxm (m q) 
  (mapcar (function (lambda (r) (Remote>>gc:mxv (Remote>>gc:trp q) r))) m)
)


;; Evalue si une matrice est carrée
;; m : une matrice
(defun Remote>>gc:SquareP (m) 
  (vl-every (function (lambda (v) (= (length v) (length m)))) 
            m
  )
)


;; Evalue si une matrice de transformation (3X3 ou 4X4) a un échelle uniforme
;; m : une matrice
(defun Remote>>gc:UniformP (m) 
  (and (or (= 3 (length m)) (setq m (mapcar 'butlast (butlast m)))) 
       (vl-every 
         (function 
           (lambda (v) 
             (equal (distance '(0. 0. 0.) (car m)) 
                    (distance '(0. 0. 0.) v)
                    1e-12
             )
           )
         )
         m
       )
  )
)


;; Evalue si une matrice est valide pour une utilisation avec vlax-tmatrix
;; m : une matrice
(defun Remote>>gc:TmatrixValid (m) 
  (and (= 4 (setq l (length m))) 
       (Remote>>gc:SquareP m)
       (Remote>>gc:UniformP m)
  )
)


;; Crée une matrice d'identité de dimension n
;; d : la dimension de la matrice
(defun Remote>>gc:Indentity (d / i n r m) 
  (setq i d)
  (while (<= 0 (setq i (1- i))) 
    (setq n d
          r nil
    )
    (while (<= 0 (setq n (1- n))) 
      (setq r (cons 
                (if (= i n) 
                  1.
                  0.
                )
                r
              )
      )
    )
    (setq m (cons r m))
  )
)


;; Évalue si la matrice est orthogonale
;; mat : une matrice
(defun Remote>>gc:IsOrtho (mat) 
  (equal (Remote>>gc:mxm (Remote>>gc:trp mat) mat) 
         (Remote>>gc:Indentity (length mat))
         1e-14
  )
)


;; Retourne la matrice de transformation (3X3) inverse
;; mat : une matrice 3x3
(defun Remote>>gc:Inv3x3 (mat / a b c d e f g h i det) 
  (mapcar 'set 
          '(a b c d e f g h i)
          (mapcar 'float (apply 'append mat))
  )
  (setq det (+ (* a e i) 
               (* b f g)
               (* c d h)
               (- (* c e g))
               (- (* b d i))
               (- (* a f h))
            )
  )
  (if (and (/= 0 det) (setq det (/ 1 det))) 
    (mapcar 
      '(lambda (v) 
         (mapcar '(lambda (x) (* x det)) v)
       )
      (list 
        (list (- (* e i) (* f h)) 
              (- (* c h) (* b i))
              (- (* b f) (* c e))
        )
        (list (- (* f g) (* d i)) 
              (- (* a i) (* c g))
              (- (* c d) (* a f))
        )
        (list (- (* d h) (* e g)) 
              (- (* b g) (* a h))
              (- (* a e) (* b d))
        )
      )
    )
  )
)


;; Applique la méthode de Gauss-Jordan à deux matrices
;; m1 : une matrice
;; m2 : une matrice
(defun Remote>>gc:GaussJordan (m1 m2 / len mat todo cnt row col piv new) 
  (setq len (length m1))
  (if (= len (length m2)) 
    (progn 
      (setq mat  (mapcar (function (lambda (x1 x2) (append x1 x2))) m1 m2)
            todo mat
            cnt  0
      )
      (while todo 
        (setq row (nth cnt mat)
              col (mapcar (function (lambda (x) (abs (car x)))) todo)
        )
        (repeat (vl-position (apply 'max col) col) 
          (setq mat (append (vl-remove row mat) (list row))
                row (nth cnt mat)
          )
        )
        (if (equal (setq piv (car row)) 0. 1e-14) 
          (setq mat  nil
                todo nil
          )
          (setq piv  (/ 1.0 piv)
                new  (mapcar (function (lambda (x) (* x piv))) row)
                mat  (mapcar 
                       (function 
                         (lambda (r / e) 
                           (setq e (car r))
                           (if (equal r row) 
                             (cdr new)
                             (cdr 
                               (mapcar 
                                 (function (lambda (x n) (- x (* n e))))
                                 r
                                 new
                               )
                             )
                           )
                         )
                       )
                       mat
                     )
                todo mat
                cnt  (1+ cnt)
          )
        )
        (and todo (repeat cnt (setq todo (cdr todo))))
      )
      mat
    )
  )
)


;; Inverse une matrice carrée (méthode Gauss-Jordan)
;; mat : une matrice
(defun Remote>>gc:Inverse (mat / col piv row res) 
  (setq mat (mapcar '(lambda (x1 x2) (append x1 x2)) 
                    mat
                    (Remote>>gc:Indentity (length mat))
            )
  )
  (while mat 
    (setq col (mapcar '(lambda (x) (abs (car x))) mat))
    (repeat (vl-position (apply 'max col) col) 
      (setq mat (append (cdr mat) (list (car mat))))
    )
    (if (equal (setq piv (caar mat)) 0. 1e-14) 
      (setq mat nil
            res nil
      )
      (setq piv (/ 1.0 piv)
            row (mapcar '(lambda (x) (* x piv)) (car mat))
            mat (mapcar 
                  '(lambda (r / e) 
                     (setq e (car r))
                     (cdr (mapcar '(lambda (x n) (- x (* n e))) r row))
                   )
                  (cdr mat)
                )
            res (cons 
                  (cdr row)
                  (mapcar 
                    '(lambda (r / e) 
                       (setq e (car r))
                       (cdr (mapcar '(lambda (x n) (- x (* n e))) r row))
                     )
                    res
                  )
                )
      )
    )
  )
  (reverse res)
)


;; Retourne le cofacteur associé à l'élément (i,j) d'une matrice (m)
;; i : index de rangée
;; j : index de colonne
;; m : une matrice
;;
;; Fonction requise
;; - Remote>>gc:RemoveAt (gc_List.lsp)
(defun Remote>>gc:Cofactor (i j m) 
  (* 
    (Remote>>gc:Determ 
      (Remote>>gc:RemoveAt 
        (1- i)
        (mapcar (function (lambda (x) (Remote>>gc:RemoveAt (1- j) x))) m)
      )
    )
    (expt -1 (+ i j))
  )
)


;; Retourne le déterminant d'une matrice carré
;; m : une matrice
(defun Remote>>gc:Determ (m) 
  (if (= 2 (length m)) 
    (- (* (caar m) (cadadr m)) (* (caadr m) (cadar m)))
    ((lambda (r n) 
       (apply '+ 
              (mapcar 
                (function 
                  (lambda (x) (* x (Remote>>gc:Cofactor 1 (setq n (1+ n)) m)))
                )
                r
              )
       )
     ) 
      (car m)
      0
    )
  )
)


;; Retourne la matrice adjointe d'une matrice
;; m : une matrice
(defun Remote>>gc:AdjMat (m / i) 
  (setq i 0)
  (Remote>>gc:trp 
    (mapcar 
      (function 
        (lambda (v / j) 
          (setq i (1+ i)
                j 0
          )
          (mapcar 
            (function (lambda (x) (Remote>>gc:Cofactor i (setq j (1+ j)) m)))
            v
          )
        )
      )
      m
    )
  )
)


;; Retourne la matrice inverse d'une matrice
;; m : une matrice
(defun Remote>>gc:InvMat (m / d) 
  (if (/= 0 (setq d (determ m))) 
    (mxs (adj-mat m) (/ 1.0 d))
  )
)


;; Applique la matrice de transformation (4x4) au point
;; pt : un point
;; mat : une matrice 4x4
(defun Remote>>gc:TransformBy (pt mat) 
  ((lambda (m d) 
     (mapcar '+ (Remote>>gc:mxv m pt) d)
   ) 
    (list 
      (list (caar mat) (cadar mat) (caddar mat))
      (list (caadr mat) (cadadr mat) (caddr (cadr mat)))
      (list (caaddr mat) (cadr (caddr mat)) (caddr (caddr mat)))
    )
    (list (cadddr (car mat)) 
          (cadddr (cadr mat))
          (cadddr (caddr mat))
    )
  )
)


;; Retourne la matrice de transformation (4x4) d'un système de coordonnées
;; vers un autre (mêmes types d'arguments que trans)
;; from : système de coordonnées de départ (entier, vecteur ou ename)
;; to : système de coordonnées de destination (entier, vecteur ou ename)
(defun Remote>>gc:TMatrixFromTo (from to) 
  (append 
    (mapcar 
      (function 
        (lambda (v o) 
          (append (trans v from to T) (list o))
        )
      )
      '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
      (trans '(0. 0. 0.) to from)
    )
    '((0. 0. 0. 1.))
  )
)


;; Retourne la matrice de transformation de la projection sur le plan
;; défini par origin et normal suivant la direction du vecteur projectDir
;; origin : un point sur le plan de projection
;; normal : la normale du plan de projection
;; projectDir : le vecteur décrivant la direction de projection
(defun Remote>>gc:ProjectionMatrix (origin normal projectDir / scl mat) 
  (if (/= (setq scl (Remote>>gc:DotProduct normal projectDir)) 0.) 
    (append 
      (mapcar 
        (function (lambda (v x) (append v (list x))))
        (setq mat (mapcar 
                    (function (lambda (v1 v2) (mapcar '- v1 v2)))
                    '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
                    (mapcar 
                      (function (lambda (s) (Remote>>gc:ScaleVector normal s)))
                      (Remote>>gc:ScaleVector projectDir (/ 1. scl))
                    )
                  )
        )
        (mapcar '- origin (Remote>>gc:mxv mat origin))
      )
      '((0. 0. 0. 1.))
    )
  )
)


;; Retourne un matrice (4x4) de mise à l'échelle
;; base : le point de base
;; scl : le facteur d'échelle
(defun Remote>>gc:ScaleMatrix (base scl) 
  (append 
    (mapcar 
      (function 
        (lambda (v1 v2) 
          (append (mapcar '(lambda (x) (* x scl)) v1) 
                  (list v2)
          )
        )
      )
      '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
      (mapcar '(lambda (x) (- x (* x scl))) base)
    )
    '((0. 0. 0. 1.))
  )
)


;; Retourne un matrice (4x4) de déplacement
;; dep : le vecteur décrivant le déplacement
(defun Remote>>gc:MoveMatrix (dep) 
  (append 
    (mapcar 
      (function 
        (lambda (v1 v2) 
          (append v1 (list v2))
        )
      )
      '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
      dep
    )
    '((0. 0. 0. 1.))
  )
)


;; Retourne un matrice (4x4) de rotation sur l'axe Z
;; base : le point de base
;; ang : l'angle en radians
(defun Remote>>gc:2dRotationMatrix (base ang / mat) 
  (append 
    (mapcar 
      (function 
        (lambda (v1 v2) 
          (append v1 (list v2))
        )
      )
      (setq mat (list (list (cos ang) (- (sin ang)) 0.) 
                      (list (sin ang) (cos ang) 0.)
                      '(0. 0. 1.)
                )
      )
      (mapcar '- base (Remote>>gc:mxv mat base))
    )
    '((0. 0. 0. 1.))
  )
)


;; Retourne un matrice (4x4) de rotation suivant un axe
;; org : origine de l'axe
;; axis : vecteur directeur de l'axe
;; ang : l'angle en radians

(defun Remote>>gc:3dRotationMatrix (org axis ang) 
  (Remote>>gc:mxm 
    (Remote>>gc:TMatrixFromTo 0 axis)
    (Remote>>gc:mxm 
      (Remote>>gc:2dRotationMatrix (trans org 0 axis) ang)
      (Remote>>gc:TMatrixFromTo axis 0)
    )
  )
)


;; Retourne un matrice (4x4) de rotation sur l'axe X
;; base : le point de base
;; ang : l'angle en radians
(defun Remote>>gc:XRotateMatrix (base ang / mat) 
  (append 
    (mapcar 
      (function 
        (lambda (v1 v2) 
          (append v1 (list v2))
        )
      )
      (setq mat (list '(1. 0. 0.) 
                      (list 0. (cos ang) (- (sin ang)))
                      (list 0. (sin ang) (cos ang))
                )
      )
      (mapcar '- base (Remote>>gc:mxv mat base))
    )
    '((0. 0. 0. 1.))
  )
)


;; Retourne un matrice (4x4) de rotation sur l'axe Y
;; base : le point de base
;; ang : l'angle en radians
(defun Remote>>gc:YRotateMatrix (base ang / mat) 
  (append 
    (mapcar 
      (function 
        (lambda (v1 v2) 
          (append v1 (list v2))
        )
      )
      (setq mat (list (list (cos ang) 0 (sin ang)) 
                      '(0. 1. 0.)
                      (list (- (sin ang)) 0 (cos ang))
                )
      )
      (mapcar '- base (Remote>>gc:mxv mat base))
    )
    '((0. 0. 0. 1.))
  )
)


;; Traduit les coordonnées d'un point du SCG dans le SC de l'espace
;; papier correspondant à la fenêtre spécifiée
;; (WCS2PCS pt vp) est équivalent à (trans (trans pt 0 2) 2 3) avec vp active
;; pt : un point
;; vp : la fenêtre (ename ou vla-object)
(defun Remote>>gc:WCS2PCS (pt vp / elst ang nor scl mat) 
  (vl-load-com)
  (and (= (type vp) 'VLA-OBJECT) 
       (setq vp (vlax-vla-object->ename vp))
  )
  (setq pt   (trans pt 0 0)
        elst (entget vp)
        ang  (cdr (assoc 51 elst))
        nor  (cdr (assoc 16 elst))
        scl  (/ (cdr (assoc 41 elst)) (cdr (assoc 45 elst)))
        mat  (Remote>>gc:mxm 
               (list (list (cos ang) (- (sin ang)) 0.) 
                     (list (sin ang) (cos ang) 0.)
                     '(0. 0. 1.)
               )
               (mapcar (function (lambda (v) (trans v nor 0 T))) 
                       '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
               )
             )
  )
  (mapcar '+ 
          (vxs (Remote>>gc:mxv mat (mapcar '- pt (cdr (assoc 17 elst)))) scl)
          (vxs (cdr (assoc 12 elst)) (- scl))
          (cdr (assoc 10 elst))
  )
)


;; Traduit les coordonnées d'un point de l'espace papier dans le
;; SCG correspondant à la fenêtre spécifiée
;; (PCS2WCS pt vp) est équivalent à (trans (trans pt 3 2) 2 0) avec vp active
;; pt : un point
;; vp : la fenêtre (ename ou vla-object)
(defun Remote>>gc:PCS2WCS (pt vp / ang nor scl mat) 
  (vl-load-com)
  (and (= (type vp) 'VLA-OBJECT) 
       (setq vp (vlax-vla-object->ename vp))
  )
  (setq pt   (trans pt 0 0)
        elst (entget vp)
        ang  (- (cdr (assoc 51 elst)))
        nor  (cdr (assoc 16 elst))
        scl  (/ (cdr (assoc 45 elst)) (cdr (assoc 41 elst)))
        mat  (Remote>>gc:mxm 
               (mapcar (function (lambda (v) (trans v 0 nor T))) 
                       '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
               )
               (list (list (cos ang) (- (sin ang)) 0.) 
                     (list (sin ang) (cos ang) 0.)
                     '(0. 0. 1.)
               )
             )
  )
  (mapcar '+ 
          (Remote>>gc:mxv 
            mat
            (mapcar '+ 
                    (vxs pt scl)
                    (vxs (cdr (assoc 10 elst)) (- scl))
                    (cdr (assoc 12 elst))
            )
          )
          (cdr (assoc 17 elst))
  )
)


;; Traduit les coordonnées du Système de Coordonnées Reference (bloc ou xref) vers le SCG :
;; pt : un point dans le RCS
;; mat : une matrice de transformation, retournée par (caddr (nentsel)) ou (caddr (nentselp))
(defun Remote>>gc:RCS2WCS (pt mat) 
  (setq pt (trans pt 0 0))
  (if (= 3 (length (car mat))) 
    (mapcar '+ (Remote>>gc:mxv (Remote>>gc:trp (Remote>>gc:butlast mat)) pt) (last mat))
    (mapcar '+ 
            (Remote>>gc:mxv (mapcar 'Remote>>gc:butlast (Remote>>gc:butlast mat)) pt)
            (Remote>>gc:butlast (mapcar 'last mat))
    )
  )
)


;; Traduit les coordonnées du SCG vers le Système de Coordonnées Reference (bloc ou xref) :
;; pt : un point dans le SCG
;; mat : une matrice de transformation, retournée par (caddr (nentsel)) ou (caddr (nentselp))
(defun Remote>>gc:WCS2RCS (pt mat) 
  (setq pt (trans pt 0 0))
  (if (= 3 (length (car mat))) 
    (setq mat (append (Remote>>gc:trp mat) (list '(0. 0. 0. 1.))))
  )
  (setq mat (inversematrix mat))
  (mapcar '+ (Remote>>gc:mxv mat pt) (Remote>>gc:butlast (mapcar 'last mat)))
)


;; Retourne la matrice de transformation d'une référence de bloc.
;; Matrice 4x4 telle que renvoyée par nentsel.
;; ename : lenom d'entité de la référence de bloc
(defun Remote>>gc:BlockTransform (ename / elst ang norm) 
  (setq elst (entget ename)
        ang  (cdr (assoc 50 elst))
        norm (cdr (assoc 210 elst))
  )
  (append 
    (mapcar 
      (function 
        (lambda (v1 v2) 
          (append v1 (list v2))
        )
      )
      (setq mat (Remote>>gc:mxm 
                  (mapcar (function (lambda (v) (trans v 0 norm T))) 
                          '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
                  )
                  (Remote>>gc:mxm 
                    (list (list (cos ang) (- (sin ang)) 0.) 
                          (list (sin ang) (cos ang) 0.)
                          '(0. 0. 1.)
                    )
                    (list (list (cdr (assoc 41 elst)) 0. 0.) 
                          (list 0. (cdr (assoc 42 elst)) 0.)
                          (list 0. 0. (cdr (assoc 43 elst)))
                    )
                  )
                )
      )
      (mapcar 
        '-
        (trans (cdr (assoc 10 elst)) norm 0)
        (Remote>>gc:mxv 
          mat
          (cdr (assoc 10 (tblsearch "BLOCK" (cdr (assoc 2 elst)))))
        )
      )
    )
    '((0. 0. 0. 1.))
  )
)


;; Retourne la matrice inverse de celle retournée par Remote>>gc:BlockTransform
;; ename : le nom d'entité
(defun Remote>>gc:BlockTransformInverse (ename / elst ang norm mat) 
  (setq elst (entget ename)
        ang  (- (cdr (assoc 50 elst)))
        norm (cdr (assoc 210 elst))
  )
  (append 
    (mapcar 
      (function 
        (lambda (v1 v2) 
          (append v1 (list v2))
        )
      )
      (setq mat (Remote>>gc:mxm 
                  (list (list (/ 1. (cdr (assoc 41 elst))) 0. 0.) 
                        (list 0. (/ 1. (cdr (assoc 42 elst))) 0.)
                        (list 0. 0. (/ 1. (cdr (assoc 43 elst))))
                  )
                  (Remote>>gc:mxm 
                    (list (list (cos ang) (- (sin ang)) 0.) 
                          (list (sin ang) (cos ang) 0.)
                          '(0. 0. 1.)
                    )
                    (mapcar (function (lambda (v) (trans v norm 0 T))) 
                            '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
                    )
                  )
                )
      )
      (mapcar 
        '-
        (cdr (assoc 10 (tblsearch "BLOCK" (cdr (assoc 2 elst)))))
        (Remote>>gc:mxv mat (trans (cdr (assoc 10 elst)) norm 0))
      )
    )
    '((0. 0. 0. 1.))
  )
)


;; Convertit les coordonnées d'un point entre le SCG ou le SCU  et le SCR -systéme de
;; coordonées d'une référence (xref ou bloc) quelque soit son niveau d'imbrication-
;; pt : le point à convertir
;; rlst : la liste des entités "parents" de la plus imbriqué à celle insérée dans
;;        l'espace courant -indentique à (last (nentsel)) ou (last (nentselp))
;; from to : comme avec trans : 0 pour le SCG, 1 pour le SCU courant, 2 pour le SCR
(defun Remote>>gc:TransNested (pt rlst from to) 
  (and (= 1 from) (setq pt (trans pt 1 0)))
  (and (= 2 to) (setq rlst (reverse rlst)))
  (and (or (= 2 from) (= 2 to)) 
       (while rlst 
         (setq geom (if (= 2 to) 
                      (Remote>>gc:RevRefGeom (car rlst))
                      (Remote>>gc:RefGeom (car rlst))
                    )
               rlst (cdr rlst)
               pt   (mapcar '+ (Remote>>gc:mxv (car geom) pt) (cadr geom))
         )
       )
  )
  (if (= 1 to) 
    (trans pt 0 1)
    pt
  )
)


;; Retourne une liste dont le premier élément est une matrice de transformation
;; (rotation, échelles, normale) de dimension 3X3 et le second le point
;; d'insertion de l'objet dans son "parent" (xref, bloc ou espace)
;; ename : le nom d'entité
(defun Remote>>gc:RefGeom (ename / elst ang norm mat) 
  (setq elst (entget ename)
        ang  (cdr (assoc 50 elst))
        norm (cdr (assoc 210 elst))
  )
  (list 
    (setq mat (Remote>>gc:mxm 
                (mapcar (function (lambda (v) (trans v 0 norm T))) 
                        '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
                )
                (Remote>>gc:mxm 
                  (list (list (cos ang) (- (sin ang)) 0.) 
                        (list (sin ang) (cos ang) 0.)
                        '(0. 0. 1.)
                  )
                  (list (list (cdr (assoc 41 elst)) 0. 0.) 
                        (list 0. (cdr (assoc 42 elst)) 0.)
                        (list 0. 0. (cdr (assoc 43 elst)))
                  )
                )
              )
    )
    (mapcar 
      '-
      (trans (cdr (assoc 10 elst)) norm 0)
      (Remote>>gc:mxv 
        mat
        (cdr (assoc 10 (tblsearch "BLOCK" (cdr (assoc 2 elst)))))
      )
    )
  )
)


;; Fonction inverse de RefGeom
;; ename : le nom d'entité
(defun Remote>>gc:RevRefGeom (ename / elst ang norm mat) 
  (setq elst (entget ename)
        ang  (- (cdr (assoc 50 elst)))
        norm (cdr (assoc 210 elst))
  )
  (list 
    (setq mat (Remote>>gc:mxm 
                (list (list (/ 1 (cdr (assoc 41 elst))) 0. 0.) 
                      (list 0. (/ 1 (cdr (assoc 42 elst))) 0.)
                      (list 0. 0. (/ 1 (cdr (assoc 43 elst))))
                )
                (Remote>>gc:mxm 
                  (list (list (cos ang) (- (sin ang)) 0.) 
                        (list (sin ang) (cos ang) 0.)
                        '(0. 0. 1.)
                  )
                  (mapcar (function (lambda (v) (trans v norm 0 T))) 
                          '((1. 0. 0.) (0. 1. 0.) (0. 0. 1.))
                  )
                )
              )
    )
    (mapcar '- 
            (cdr (assoc 10 (tblsearch "BLOCK" (cdr (assoc 2 elst)))))
            (Remote>>gc:mxv mat (trans (cdr (assoc 10 elst)) norm 0))
    )
  )
)


;; Retourne une matrice de transformation (4X4) identique à celle retournée par nentselp
;; lst : la liste des entités "parents" de la plus imbriqué à celle insérée dans
;;       l'espace courant -indentique à (last (nentsel)) ou (last (nentselp))
(defun Remote>>gc:GetTMatrix (lst / mat pt geom) 
  (setq mat (Remote>>gc:Indentity 3)
        pt  '(0. 0. 0.)
  )
  (while lst 
    (setq geom (Remote>>gc:refgeom (car lst))
          mat  (Remote>>gc:mxm (car geom) mat)
          pt   (mapcar '+ (Remote>>gc:mxv (car geom) pt) (cadr geom))
          lst  (cdr lst)
    )
  )
  (append 
    (mapcar '(lambda (v x) (append v (list x))) mat pt)
    (list '(0. 0. 0. 1.))
  )
)


;; Retourne les coordonnées SCU de l'emprise (bounding box) de l'entité
;; par rapport au SCU courant.
;; obj: une entité (ENAME ou VLA-OBJCET)
;; _OutputMinPtSym: un symbole quoté (output)
;; _OutputMaxPtSym: un symbole quoté (output)

(defun Remote>>gc:UcsBoundingBox (obj _OutputMinPtSym _OutputMaxPtSym) 
  (vl-load-com)
  (and (= (type obj) 'ENAME) 
       (setq obj (vlax-ename->vla-object obj))
  )
  (vla-TransformBy obj (vlax-tmatrix (Remote>>gc:TMatrixFromTo 1 0)))
  (vla-GetBoundingBox obj _OutputMinPtSym _OutputMaxPtSym)
  (vla-TransformBy obj (vlax-tmatrix (Remote>>gc:TMatrixFromTo 0 1)))
  (set _OutputMinPtSym 
       (vlax-safearray->list (eval _OutputMinPtSym))
  )
  (set _OutputMaxPtSym 
       (vlax-safearray->list (eval _OutputMaxPtSym))
  )
)


;; Retourne les coordonnées SCU de l'emprise (bounding box) des entités
;; contenues dans le jeu de sélection, par rapport au SCU courant.
;; ss: a selection set
;; _OutputMinPtSym: un symbole quoté (output)
;; _OutputMaxPtSym: un symbole quoté (output)

(defun Remote>>gc:SelSetUcsBBox (ss _OutputMinPtSym _OutputMaxPtSym / n l1 l2) 
  (repeat (setq n (sslength ss)) 
    (Remote>>gc:UcsBoundingBox 
      (ssname ss (setq n (1- n)))
      _OutputMinPtSym
      _OutputMaxPtSym
    )
    (setq l1 (cons (eval _OutputMinPtSym) l1)
          l2 (cons (eval _OutputMaxPtSym) l2)
    )
  )
  (set _OutputMinPtSym (apply 'mapcar (cons 'min l1)))
  (set _OutputMaxPtSym (apply 'mapcar (cons 'max l2)))
)
;#endregion
;#region Sortents

;; Retourne la table d'ordre de tracé du block record (bloc ou espace)
;; block : le block record
;; 
(defun Remote>>gc:GetSortentsTable (block / sort) 
  (cond 
    ((Remote>>gc:GetObject (vla-GetExtensionDictionary block) "ACAD_SORTENTS"))
    ((vla-AddObject (vla-GetExtensionDictionary block) "ACAD_SORTENTS" "AcDbSortentsTable"))
  )
)


;; Place les objets en avant (draworder)
;; blk : le block record auquel appartiennent les objets
;; olst : liste des objets à placer en avant (vla-objects)
(defun Remote>>gc:MoveToTop (blk olst) 
  (vlax-invoke (Remote>>gc:GetSortentsTable blk) 'MoveToTop olst)
)


;; Place les objets en arrière (draworder)
;; blk : le block record auquel appartiennent les objets
;; olst : liste des objets à placer en arrière (vla-objects)
(defun Remote>>gc:MoveToBottom (blk olst) 
  (vlax-invoke (Remote>>gc:GetSortentsTable blk) 'MoveToBottom olst)
)


;; Place les objets devant l'objet cible (draworder)
;; blk : le block record auquel appartiennent les objets
;; olst : liste des objets à placer devant (vla-objects)
;; targ : objet cible (vla-object)
(defun Remote>>gc:MoveAbove (blk olst targ) 
  (vlax-invoke (Remote>>gc:GetSortentsTable blk) 'MoveAbove olst targ)
)


;; Place les objets derrière l'objet cible (draworder)
;; blk : le block record auquel appartiennent les objets
;; olst : liste des objets à placer derrière (vla-objects)
;; targ : objet cible (vla-object)
(defun Remote>>gc:MoveBelow (blk olst targ) 
  (vlax-invoke (Remote>>gc:GetSortentsTable blk) 'MoveBelow olst targ)
)


;; Place les objets dans l'ordre de la liste
;; blk : le block record auquel appartiennent les objets
;; olst : liste des objets à trier (vla-objects)
(defun Remote>>gc:SetRelativeDrawOrder (blk olst) 
  (vlax-invoke (Remote>>gc:GetSortentsTable blk) 'SetRelativeDrawOrder olst)
)

;#endregion
;#region Regular Expressions Emulator
;; Retourne l'instance de VBScript.RegExp courante après avoir défini ses propriétés.
;; pattern    : Motif à rechercher.
;; ignoreCase : Si non nil, la recherche est faite sans tenir compte de la casse.
;; global     : Si non nil, recherche toutes les occurrences du modèle ;
;;              si nil, recherche uniquement la première occurrence.

(defun Remote>>gc:RegExpSet (pattern ignoreCase global / regex) 
  (setq regex (cond 
                ((vl-bb-ref '*regexp*))
                ((vl-bb-set '*regexp* (vlax-create-object "VBScript.RegExp")))
              )
  )
  (vlax-put regex 'Pattern pattern)
  (if ignoreCase 
    (vlax-put regex 'IgnoreCase acTrue)
    (vlax-put regex 'IgnoreCase acFalse)
  )
  (if global 
    (vlax-put regex 'Global acTrue)
    (vlax-put regex 'Global acFalse)
  )
  regex
)

;; Retourne T si une correspondance avec le motif a été trouvée dans la chaîne ; sinon, nil.
;; string     : Chaîne dans la quelle on recherche le motif.
;; pattern    : Motif à rechercher.
;; ignoreCase : Si non nil, la recherche est faite sans tenir compte de la casse.
;;
;; Exemples :
;; (Remote>>gc:RegexpTest "foo bar" "Ba" nil)  ; => nil
;; (Remote>>gc:RegexpTest "foo bar" "Ba" T)    ; => T
;; (Remote>>gc:RegExpTest "42C" "[0-9]+" nil)  ; => T

(defun Remote>>gc:RegExpTest (string pattern ignoreCase) 
  (= (vlax-invoke (Remote>>gc:RegExpSet pattern ignoreCase nil) 'Test string) -1)
)

;; Retourne la liste des correspondances avec le motif trouvées dans la chaine.
;; Chaque correspondance est renvoyée sous la forme d'une sous-liste contenant :
;; - la valeur de la correspondance,
;; - l'index du premier caractère (base 0)
;; - une liste des sous groupes.
;; string     : Chaîne dans la quelle on recherche le motif.
;; pattern    : Motif à rechercher.
;; ignoreCase : Si non nil, la recherche est faite sans tenir compte de la casse.
;; global     : Si non nil, recherche toutes les occurrences du modèle ;
;;              si nil, recherche uniquement la première occurrence.
;;
;; Exemples
;; (Remote>>gc:RegExpExecute "foo bar baz" "ba" nil nil)               ; => (("ba" 4 nil))
;; (Remote>>gc:RegexpExecute "12B 4bis" "([0-9]+)([A-Z]+)" T T)        ; => (("12B" 0 ("12" "B")) ("4bis" 4 ("4" "bis")))
;; (Remote>>gc:RegexpExecute "-12 25.4" "(-?\\d+(?:\\.\\d+)?)" nil T)  ; => (("-12" 0 ("-12")) ("25.4" 4 ("25.4")))

(defun Remote>>gc:RegExpExecute (string pattern ignoreCase global / sublst lst) 
  (vlax-for match (vlax-invoke (Remote>>gc:RegExpSet pattern ignoreCase global) 'Execute string) 
    (setq sublst nil)
    (vl-catch-all-apply 
      '(lambda () 
         (vlax-for submatch (vlax-get match 'SubMatches) 
           (if submatch 
             (setq sublst (cons submatch sublst))
           )
         )
       )
    )
    (setq lst (cons 
                (list (vlax-get match 'Value) 
                      (vlax-get match 'FirstIndex)
                      (reverse sublst)
                )
                lst
              )
    )
  )
  (reverse lst)
)

;; Retourne la chaîne après remplacement des correspondances avec le motif.
;; string     : Chaîne dans la quelle on recherche le motif.
;; pattern    : Motif à rechercher.
;; newStr     : Chaîne de remplacement.
;; ignoreCase : Si non nil, la recherche est faite sans tenir compte de la casse.
;; global     : Si non nil, recherche toutes les occurrences du modèle ;
;;              si nil, recherche uniquement la première occurrence.
;;
;; Exemples :
;; (Remote>>gc:RegExpReplace "foo bar baz" "a" "oo" nil T)                  ; => "foo boor booz"
;; (Remote>>gc:RegExpReplace "foo bar baz" "(\\w)\\w(\\w)" "$1_$2" nil T)   ; => "f_o b_r b_z"
;; (Remote>>gc:RegExpReplace "$ 3.25" "\\$ (\\d+(\\.\\d+)?)" "$1 €" nil T)  ; => "3.25 €"

(defun Remote>>gc:RegExpReplace (string pattern newStr ignoreCase global) 
  (vlax-invoke (Remote>>gc:RegExpSet pattern ignoreCase global) 'Replace string newStr)
)
;#endregion
;#region Dictionaries

;;
;; Stocke une liste de données dans un dictionnaire :
;; dict : le nom du dictionnaire (chaine) ou de l'object (ename)
;; key : la clé de l'entée du dictionnaire (chaine)
;; data : la liste de données (chaine, entier, réel, point)

(defun Remote>>gc:DictDataPut (name key data / dict lst xrec typ) 
  (if 
    (or 
      (and 
        (= (type name) 'STR)
        (snvalid name)
        (or 
          (and 
            (dictsearch (namedobjdict) name)
            (setq dict (cdr (assoc -1 (dictsearch (namedobjdict) name))))
          )
          (setq dict (dictadd 
                       (namedobjdict)
                       name
                       (entmakex '((0 . "DICTIONARY") (100 . "AcDbDictionary")))
                     )
          )
        )
      )
      (and 
        (or 
          (= (type name) 'ENAME)
          (and 
            (= (type name) 'VLA-OBJECT)
            (setq name (vlax-vla-object->ename name))
          )
        )
        (or 
          (setq dict (cdr 
                       (assoc 360 
                              (member '(102 . "{ACAD_XDICTIONARY") 
                                      (entget name)
                              )
                       )
                     )
          )
          (and 
            (setq dict (entmakex 
                         '((0 . "DICTIONARY") (100 . "AcDbDictionary"))
                       )
            )
            (entmod 
              (append (entget name) 
                      (list '(102 . "{ACAD_XDICTIONARY") 
                            (cons 360 dict)
                            '(102 . "}")
                      )
              )
            )
          )
        )
      )
    )
    (if (snvalid key) 
      (progn 
        (or (listp data) (setq data (list data)))
        (foreach d data 
          (setq typ (type d))
          (cond 
            ((= typ 'STR) (setq lst (cons (cons 1 d) lst)))
            ((= typ 'INT) (setq lst (cons (cons 70 d) lst)))
            ((= typ 'REAL) (setq lst (cons (cons 40 d) lst)))
            ((and (listp d) (<= 2 (length d) 3) (vl-every 'numberp d))
             (setq lst (cons (cons 10 d) lst))
            )
          )
        )
        (and (setq xrec (dictsearch dict key)) 
             (entdel (cdr (assoc -1 xrec)))
        )
        (if lst 
          (progn 
            (dictadd 
              dict
              key
              (entmakex 
                (append 
                  (list '(0 . "XRECORD") 
                        '(100 . "AcDbXrecord")
                  )
                  (reverse lst)
                )
              )
            )
            (reverse (mapcar 'cdr lst))
          )
        )
      )
      (princ (strcat "\nClé non valide: " key))
    )
    (princ "\nNom ou objet non valide.")
  )
)



;;
;; Liste les données des entrées d'un dictionnaire
;; Arguments :
;; dict : le nom du dictionnaire (chaine) ou de l'object (ename)

(defun Remote>>gc:DictDataList (name / dict elst lst) 
  (if 
    (or 
      (and 
        (= (type name) 'STR)
        (dictsearch (namedobjdict) name)
        (setq dict (dictsearch (namedobjdict) name))
      )
      (and 
        (or 
          (= (type name) 'ENAME)
          (and 
            (= (type name) 'VLA-OBJECT)
            (setq name (vlax-vla-object->ename name))
          )
        )
        (setq dict (entget 
                     (cdr 
                       (assoc 360 
                              (member '(102 . "{ACAD_XDICTIONARY") 
                                      (entget name)
                              )
                       )
                     )
                   )
        )
      )
    )
    (progn 
      (setq elst (vl-member-if 
                   (function (lambda (x) (= (car x) 3)))
                   dict
                 )
      )
      (while elst 
        (setq lst  (cons 
                     (cons (cdar elst) 
                           (mapcar 
                             'cdr
                             (cdr 
                               (vl-member-if 
                                 (function (lambda (x) (= (car x) 280)))
                                 (entget (cdadr elst))
                               )
                             )
                           )
                     )
                     lst
                   )
              elst (cddr elst)
        )
      )
      (reverse lst)
    )
  )
)



;;
;; Supprime une entée dans un dictionnaire
;; Arguments :
;; dict : le nom du dictionnaire (chaine) ou de l'object (ename)
;; key : la clé de l'entée du dictionnaire (chaine)

(defun Remote>>gc:DictDataDelete (name key / dict xrec) 
  (if 
    (or 
      (and 
        (= (type name) 'STR)
        (dictsearch (namedobjdict) name)
        (setq dict (cdr (assoc -1 (dictsearch (namedobjdict) name))))
      )
      (and 
        (or 
          (= (type name) 'ENAME)
          (and 
            (= (type name) 'VLA-OBJECT)
            (setq name (vlax-vla-object->ename name))
          )
        )
        (setq dict (cdr 
                     (assoc 360 
                            (member '(102 . "{ACAD_XDICTIONARY") 
                                    (entget name)
                            )
                     )
                   )
        )
      )
    )
    (if (setq xrec (dictsearch dict key)) 
      (entdel (cdr (assoc -1 xrec)))
    )
  )
)



;;
;; Retorune la liste de données de l'entrée du dictionnaire
;; Arguments :
;; dict : le nom du dictionnaire (chaine) ou de l'object (ename)
;; key : la clé de l'entée du dictionnaire (chaine)

(defun Remote>>gc:DictDataGet (name key / dict xrec) 
  (if 
    (or 
      (and 
        (= (type name) 'STR)
        (dictsearch (namedobjdict) name)
        (setq dict (cdr (assoc -1 (dictsearch (namedobjdict) name))))
      )
      (and 
        (or 
          (= (type name) 'ENAME)
          (and 
            (= (type name) 'VLA-OBJECT)
            (setq name (vlax-vla-object->ename name))
          )
        )
        (setq dict (cdr 
                     (assoc 360 
                            (member '(102 . "{ACAD_XDICTIONARY") 
                                    (entget name)
                            )
                     )
                   )
        )
      )
    )
    (if (setq xrec (dictsearch dict key)) 
      (mapcar 
        'cdr
        (cdr 
          (vl-member-if (function (lambda (x) (= (car x) 280))) xrec)
        )
      )
    )
  )
)


;; Retourne le dictionnaire d'extension de l'entité (ou nil) : ent (ENAME)

(defun Remote>>gc:GetExtDict (ent) 
  (cdadr (member '(102 . "{ACAD_XDICTIONARY") (entget ent)))
)


;; Retourne le dictionnaire d'extension de l'entité
;; Le dictionnaire est créé s'il n'existe pas : ent (ENAME)

(defun Remote>>gc:GetOrCreateExtDict (ent / dict) 
  (cond 
    ((cdadr (member '(102 . "{ACAD_XDICTIONARY") (entget ent))))
    ((setq dict (entmakex 
                  '((0 . "DICTIONARY") (100 . "AcDbDictionary"))
                )
     )
     (entmod 
       (vl-list* 
         (assoc -1 elst)
         (assoc 0 elst)
         (assoc 5 elst)
         (cons 102 "{ACAD_XDICTIONARY")
         (cons 360 dict)
         (cons 102 "}")
         (vl-remove-if (function (lambda (x) (member (car x) '(-1 0 5)))) elst)
       )
     )
     dict
    )
  )
)

;;;============================================================;;;


;; Retourne la liste des entrées du dictionnaire
;; sous forme de paires pointées (Nom . ENAME) : dict le dictionnaire (ENAME ou liste DXF)

(defun Remote>>gc:GetDictEntries (dict / result) 
  (and (= (type dict) 'ENAME) (setq dict (entget dict)))
  (while (setq dict (vl-member-if (function (lambda (x) (= (car x) 3))) (cdr dict))) 
    (setq result (cons (cons (cdar dict) (cdadr dict)) result))
  )
  (reverse result)
)


;; Retourne la liste DXF du dernier dictionnaire enfant de la liste (ou nil)
;; lst : la liste des noms des dictionnaires dans l'ordre de parenté

(defun Remote>>gc:NestedDictSearch (lst / dict) 
  (if (setq dict (dictsearch (namedobjdict) (car lst))) 
    (while 
      (and (setq lst (cdr lst)) 
           (setq dict (dictsearch (cdr (assoc -1 dict)) (car lst)))
      )
    )
  )
  dict
)


;; Retourne le ENAME du dictionnaire trouvé ou créé s'il n'exstait pas
;; dict : ENAME du dictionnaire parent
;; name : nom du dictionnaire à chercher ou créer

(defun Remote>>gc:GetOrCreateDict (dict name) 
  (if (snvalid name) 
    (cond 
      ((cdr (assoc -1 (dictsearch dict name))))
      ((dictadd dict 
                name
                (entmakex '((0 . "DICTIONARY") (100 . "AcDbDictionary")))
       )
      )
    )
  )
)


;; Retourne le ENAME du dernier dictionnaire enfant de la liste
;; S'ils n'existent pas déjà les dictionnaires sont créés
;; lst : la liste des noms des dictionnaires dans l'ordre de parenté

(defun Remote>>gc:GetOrCreateNestedDict (lst) 
  (setq dict (namedobjdict))
  (foreach n lst (setq dict (Remote>>gc:GetOrCreateDict dict n)))
  dict
)


;; Retourne le ENAME du dictionnaire supprimé (ou nil)
;; lst : la liste des noms des dictionnaires dans l'ordre de parenté
;; key : le nom du dictionnaire à supprimer

(defun Remote>>gc:NestedDictRemove (lst key / dict) 
  (if (setq dict (Remote>>gc:NestedDictSearch lst)) 
    (dictremove (cdr (assoc -1 dict)) key)
  )
)


;; Retourne la liste des données affectées au Xrecord (liste de paires pointées)
;; dict : ENAME du dictionnaire parent
;; key : nom du Xrecord

(defun Remote>>gc:GetXrecData (dict key / xrec) 
  (if 
    (and 
      (setq xrec (dictsearch dict key))
      (= (cdr (assoc 0 xrec)) "XRECORD")
    )
    (cdr (member (assoc 280 xrec) xrec))
  )
)


;; Retourne le ENAME du xrecord auquel sont affectées mes données
;; dict : ENAME du dictionnaire parent
;; key : nom du Xrecord
;; data : liste de paires pointées contenant les données

(defun Remote>>gc:SetXrecData (dict key data / xrec) 
  (if (snvalid key) 
    (progn 
      (and (setq xrec (dictsearch dict key)) 
           (entdel (cdr (assoc -1 xrec)))
      )
      (dictadd 
        dict
        key
        (entmakex 
          (append 
            (list '(0 . "XRECORD") 
                  '(100 . "AcDbXrecord")
            )
            data
          )
        )
      )
    )
  )
)


;; Retourne la liste des données affectées au Xrecord du dernier dictionnaire enfant
;; lst : la liste des noms des dictionnaires dans l'ordre de parenté
;; key : nom du Xrecord

(defun Remote>>gc:GetNestedXrecData (lst key / dict) 
  (if (setq dict (Remote>>gc:NestedDictSearch lst)) 
    (Remote>>gc:GetXrecData (cdr (assoc -1 dict)) key)
  )
)


;; Retourne le ENAME du xrecord auquel sont affectées les données
;; lst : la liste des noms des dictionnaires dans l'ordre de parenté
;; key : nom du Xrecord
;; val : liste de paires pointées

(defun Remote>>gc:SetNestedXrecData (lst key val / dict) 
  (if (setq dict (Remote>>gc:NestedDictSearch lst)) 
    (Remote>>gc:SetXrecData (cdr (assoc -1 dict)) key val)
  )
)


;#endregion
;#region Automation Helpers
;;--------------- VARIANTS & SAFEARRAYS ----------------;;


;; Convertit un variant ou un safearray en donnée LISP
;; var : variant ou safearray

(defun Remote>>gc:VariantToLispData (var) 
  (cond 
    ((= (type var) 'variant)
     (Remote>>gc:VariantToLispData (vlax-variant-value var))
    )
    ((= (type var) 'safearray)
     (if (< -1 (vlax-safearray-get-u-bound var 1)) 
       (mapcar 'gc:VariantToLispData (vlax-safearray->list var))
     )
    )
    (T var)
  )
)


;; Convertit un variant de coordonnées 2D en liste de points
;; LightweightPolyline dans le SCO
;; var : un variant (array de doubles) tel que retourné par vla-get-Coordinates

(defun Remote>>gc:2dVariantToPointList (var / foo) 
  (defun foo (lst) 
    (if lst 
      (cons (list (car lst) (cadr lst)) (foo (cddr lst)))
    )
  )
  (foo (vlax-safearray->list (vlax-variant-value var)))
)


;; Convertit un variant de coordonnées 3D en liste de points
;; Polyline dans le SCO (Z = 0)
;; 3DFace, 3DPolyline, Leader, MLine, PolyfaceMesh,
;; PolygonMesh, Solid, Trace dans le SCG
;; var : un variant (array de doubles) tel que retourné par vla-get-Coordinates

(defun Remote>>gc:3dVariantToPointList (var / foo) 
  (defun foo (lst) 
    (if lst 
      (cons (list (car lst) (cadr lst) (caddr lst)) (foo (cdddr lst)))
    )
  )
  (foo (vlax-safearray->list (vlax-variant-value var)))
)


;; Retourne une liste d'association (type liste DXF)
;; xtyp : variant (array d'entiers)
;; xval : variant (array de variants)

(defun Remote>>gc:VariantsToDxfList (xtyp xval) 
  (mapcar 'cons (Remote>>gc:VariantToLispData xtyp) (Remote>>gc:VariantToLispData xval))
)


;; Retourne la liste DXF des données étendues de l'objet
;; obj : (vla-object) l'objet auquel sont liées les données étendues
;; app : (string) le nom de l'application enregistrée ("" pour toutes les applications)

(defun Remote>>gc:GetXdata (obj app / xtyp xval) 
  (vla-GetXdata obj app 'xtyp 'xval)
  (Remote>>gc:VariantsToDxfList xtyp xval)
)


;; Retourne la liste DXF des données de l'objet XRECORD
;; xrec : (vla-object) l'objet XRECORD auquel sont liées les données

(defun Remote>>gc:GetXrecordData (xrec / xtyp xval) 
  (vla-GetXrecordData xrec 'xtyp 'xval)
  (Remote>>gc:VariantsToDxfList xtyp xval)
)

;;------------------------------------------------------;;

;; LISP -> variant


;; Retourne un variant de coordonnées 2d : une liste de points 2d

(defun Remote>>gc:2dPointListToVariant (lst) 
  (vlax-make-variant 
    (vlax-safearray-fill 
      (vlax-make-safearray 
        vlax-VbDouble
        (cons 0 (1- (* 2 (length lst))))
      )
      (apply 'append lst)
    )
  )
)


;; Retourne un variant de coordonnées 3d : une liste de points 3d

(defun Remote>>gc:3dPointListToVariant (lst) 
  (vlax-make-variant 
    (vlax-safearray-fill 
      (vlax-make-safearray 
        vlax-VbDouble
        (cons 0 (1- (* 3 (length lst))))
      )
      (apply 'append lst)
    )
  )
)


;; Retourne un variant (array d'objets)
;; lst : liste de vla-objet

(defun Remote>>gc:ObjectListToVariant (lst) 
  (vlax-make-variant 
    (vlax-safearray-fill 
      (vlax-make-safearray 
        vlax-vbObject
        (cons 0 (1- (length lst)))
      )
      lst
    )
  )
)


;; Définit 2 variables et affecte un variant à chacune
;; lst : une liste DXF
;; typeSymbol : un symbole quoté
;; valueSymbol : un symbole quoté

(defun Remote>>gc:DxfListToVariants (lst typeSymbol valueSymbol) 
  (set typeSymbol 
       (vlax-make-variant 
         (vlax-safearray-fill 
           (vlax-make-safearray 
             vlax-vbInteger
             (cons 0 (1- (length lst)))
           )
           (mapcar 'car lst)
         )
       )
  )
  (set valueSymbol 
       (vlax-make-variant 
         (vlax-safearray-fill 
           (vlax-make-safearray 
             vlax-vbVariant
             (cons 0 (1- (length lst)))
           )
           (mapcar 
             '(lambda (x) 
                (if (listp (setq x (cdr x))) 
                  (vlax-3d-point x)
                  (vlax-make-variant x)
                )
              )
             lst
           )
         )
       )
  )
)



;; Attribue des données étendues à un objet
;; obj : (vla-object) l'objet auquel sont liées les données
;; lst : (liste DXF) les données sous la forme :
;; '((1001 . "Nom_App") (1002 . "{") (1000 . "chaîne") (1070 . 1) (1002 . "}"))

(defun Remote>>gc:SetXdata (obj lst / xtyp xval) 
  (Remote>>gc:DxfListToVariants lst 'xtyp 'xval)
  (vla-SetXdata obj xtyp xval)
)


;; Attribue des données à un objet Xrecord
;; xrec : (vla-object) l'objet  Xrecord
;; lst : (liste DXF) les données sous la forme :
;; '((1 . "chaîne") (70 . 1) (10 1.0 2.0 0.0))

(defun Remote>>gc:SetXrecordData (xrec lst / xtyp xval) 
  (Remote>>gc:DxfListToVariants lst 'xtyp 'xval)
  (vla-SetXrecordData xrec xtyp xval)
)

;;-------------------- Safe methods --------------------;;

;; GetItem (gile)
;; Retourne le vla-object de l'item s'il est présent dans la collection (ou nil)
;; col : la collection (vla-object)
;; name : le nom de l'objet (string) ou son indice (entier)

(defun Remote>>gc:GetItem (col name / obj) 
  (vl-catch-all-apply 
    (function (lambda () (setq obj (vla-Item col name))))
  )
  obj
)


;; Retourne un objet (Custom Object) du dictionnaire d'après son nom (ou nil)
;; Arguments
;; dict : le dictionnaire (vla-object)
;; name : le nom de l'objet (string)

(defun Remote>>gc:GetObject (dict name / obj) 
  (vl-catch-all-apply 
    (function (lambda () (setq obj (vla-GetObject dict name))))
  )
  obj
)


;; Retourne un objet (vl-object) d'après son 'handle' (ou nil s'il est effacé)
;; Arguments
;; doc    : le document auquel appartient l'objet (vla-object)
;; handle : le 'handle' de l'objet (string)

(defun Remote>>gc:HandleToObject (doc handle / obj) 
  (vl-catch-all-apply 
    (function (lambda () (setq obj (vla-HandleToObject doc handle))))
  )
  obj
)

;;-------------------- TRUE COLORS ---------------------;;


;; Retourne un objet acCmColor (utilisable avec 'vla-put-TrueColor'
;; avec la couleur choisie dans la boite de dialogue standard
;; color         : une paire pointée correspondant à la couleur par défaut
;; allowbylayer  : si nil, DuBloc et DuCalque sont désactivés dans la boite de dialogue

(defun Remote>>gc:GetAcCmColor (color allowbylayer / accmcolor truecolor) 
  (if (setq color (acad_truecolordlg color allowbylayer)) 
    (progn 
      (setq accmcolor (vla-GetInterfaceObject 
                        *acad*
                        (strcat "AutoCAD.AcCmColor." (itoa (atoi (getvar 'acadver))))
                      )
      )
      (if (setq truecolor (cdr (assoc 420 color))) 
        (vla-SetRGB 
          accmcolor
          (lsh (fix truecolor) -16)
          (lsh (lsh (fix truecolor) 16) -24)
          (lsh (lsh (fix truecolor) 24) -24)
        )
        (vla-put-ColorIndex accmcolor (cdr (assoc 62 color)))
      )
    )
  )
  accmcolor
)


(defun Remote>>gc:TrueColorToList (accmcolor / ci cm tc bn) 
  (setq ci (vla-get-ColorIndex accmcolor)
        cm (vla-get-ColorMethod accmcolor)
  )
  (cond 
    ((= cm 192) '((62 . 256)))
    ((= cm 193) '((62 . 0)))
    ((= cm 195) (list (cons 62 ci)))
    (T
     (setq tc (+ (lsh (fix (vla-get-Red accmcolor)) 16) 
                 (lsh (fix (vla-get-Green accmcolor)) 8)
                 (fix (vla-get-Blue accmcolor))
              )
     )
     (if (= "" (setq bn (vla-get-BookName accmcolor))) 
       (list (cons 62 ci) 
             (cons 420 tc)
       )
       (list (cons 62 ci) 
             (cons 420 tc)
             (cons 430 (strcat bn "$" (vla-get-ColorName accmcolor)))
       )
     )
    )
  )
)

;;-------------------- OBJECT DBX ----------------------;;


;;; Accéder à un dessin fermé.
;;;
;;; Retourne :
;;; un objet IAxDbDocument si le document est trouve
;;; nil si le document n'a pu être trouvé ou s'il est ouvert.
;;;
;;; Argument :
;;; filename : le chemin complet du fichier
;;;
;;; Exemple d'utilisation :
;;; (if (setq doc (Remote>>gc:GetAxDbDoc filename))
;;;   (progn
;;;     ...
;;;     ...
;;;     (vlax-release-object doc)
;;;   )
;;; )

(defun Remote>>gc:GetAxDbDoc (filename / majVer progId axdbdoc) 
  (vl-load-com)
  (or *acad* (setq *acad* (vlax-get-acad-object)))
  (setq progId (if (< (setq majVer (substr (getvar 'acadver) 1 2)) "16") 
                 "ObjectDBX.AxDbDocument"
                 (strcat "ObjectDBX.AxDbDocument." majVer)
               )
  )
  (if 
    (vl-catch-all-error-p 
      (vl-catch-all-error-p 
        '(lambda () 
           (vla-Open 
             (setq axdbdoc (vla-GetInterfaceObject *acad* progId))
             filename
           )
         )
      )
    )
    (and axdbdoc (not (vlax-release-object axdbdoc)))
    axdbdoc
  )
)
;#endregion


;#endregion