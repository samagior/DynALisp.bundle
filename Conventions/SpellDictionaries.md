# Spell Dictionaries

The Spell Dictionaries conventions of DynALisp, part of the [DynALisp Conventions](../CONVENTIONS.md): read before changing a spell dictionary. When a new convention of this topic is agreed, add it here, with the reason for it.

- The custom dictionaries are `Res\Dictionaries\<code>.cus` (UTF-16 BE with BOM, CRLF, as AutoCAD writes them), each with its definitions file `<code>-def.csv` (UTF-8 with BOM, `;`), read by `Dyl-Dictionary`.
- Never re-set `DCTCUST` automatically to make AutoCAD read a changed dictionary: the user reloads it (restarts AutoCAD).
- Words added to a `.cus` go in both the default and its `User` copy (AutoCAD uses the copy and writes added words there); restart AutoCAD before using *Add to dictionary*, or AutoCAD writes its old list back.
- Every word of the `.cus` has a row in `-def.csv` (or is a form of one). Add only single real words or real hyphenated compounds (*pare-vapeur*) to the `.cus`, never phrases joined by hyphens; expressions of several words (*semelle filante*) go only in `-def.csv`, with the types `loc.n.m.`, `loc.n.f.`, `loc.adj.` or `loc.adv.`.

*Why: the spell checker checks each word separately, and the user controls when AutoCAD reloads the dictionary.*
