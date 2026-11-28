# Project Files

The Project Files conventions of DynALisp, part of the [DynALisp Conventions](../CONVENTIONS.md): read before changing data kept with a project (the revisions). When a new convention of this topic is agreed, add it here, with the reason for it.

- Data that belongs to a **project** (its revisions, the revisions of its sheets) is kept in the project itself, in a `DynALisp` folder beside the `.apj` of its Project Navigator project (`<project>\DynALisp\Revisions.csv`), never in a `Dynalisp*` setting or the `User` folder. The project of a drawing is the first folder holding a `.apj`, from the folder of the drawing up (`Remote>>Dyl:RevProject`); its sheets are the drawings of its sheet folder (`SheetLocation` of the `.apj`).
- A choice the whole team must share (the numbering of the revisions, per project or per sheet) is a **setting of the project**, in a file of that folder (`RevisionSettings.csv`), edited in the window of the tool, not in the Settings window. What works the same in every project (the title blocks and their attributes, `RevisionBlocks.csv`) stays a data file of DynALisp (see [User Files](../CONVENTIONS.md#user-files)).
- The project files are CSV divided by `;`, in UTF-8 when AutoCAD can write it, and **read again just before they are written**, since another user may have changed them:
  - A file every drawing writes its rows to (`Sheets.csv`) is merged: only the rows of the drawings just updated are replaced (`Remote>>Dyl:RevSheetsMerge`).
  - A file edited in a window (`Revisions.csv`) is not saved when it changed since the window opened (its time, `Remote>>Dyl:RevStamp`): the window says so.
  - A file changed one row at a time (the tasks of the Start page, `Tasks.csv`) is opened alone (`FileShare.None`), read again and changed by the id of the row, then written back: a task added or checked by another user is kept.
- The **tasks** of a project or a sheet set pinned on the Start page are kept the same way, beside its `.apj` or its `.dst` (`<folder>\DynALisp\Tasks.csv`, `Id;Done;Task;Added;DoneOn`, `Installer\Windows\Tasks.cs`), never in `User\Start`: they are the project's, not the user's.
- The drawings of a project that are closed are changed with ObjectDBX, without opening them, and only the values that differ are written, so a drawing up to date is never modified. A drawing another user has open (its `.dwl`) is never changed: it is listed, and catches up the next time it is updated.
- What a drawing gets from the project is also kept in the drawing (the revisions of a layout in its XRecord), so a drawing copied or renamed keeps it; the project file wins when it has the drawing.

*Why: everyone who works on a project must see the same revisions, numbered the same way, wherever DynALisp is installed, and the data must move with the project, not with the computer. A project on a server is written by several users at once: a file read long before it is written would lose the work of the others.*
