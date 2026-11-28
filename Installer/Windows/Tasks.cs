// Tasks.cs - DynALisp.Windows: the tasks of a project, for the Start page
// Copyright (C) 2026  Samuel Martineau
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
// The tasks of each project or sheet set pinned on the Start page, with the bar of those done.
// They are the user's (CONVENTIONS.md, User Files): kept on this computer, in
// User\Start\Tasks\<name>-<key>.csv (the name of the .apj or .dst, the key a hash of its path),
// until the user keeps them with the project (Keep tasks with the project, the right-click
// menu of its card): then in the DynALisp folder beside its .apj or its .dst
// (<project>\DynALisp\Tasks.csv, Conventions\ProjectFiles.md), so everyone who works on it
// sees the same tasks; that file found, it is the one read. Moved either way, the tasks are
// added to those the other file has (by their id), and the file left deleted.
// A row a task, "Id;Done;Task;Added;DoneOn" (UTF-8, divided by ;, the ; of a task made a ,):
// the file is read again under a lock just before each change, and only the task changed is
// added, checked or deleted (by its id), never the whole list written over another user's.

using System;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Linq;
using System.Text;
using System.Threading;

namespace DynALisp.Windows
{
    static class ProjectTasksFile
    {
        static readonly Encoding Utf8 = new UTF8Encoding(false);
        const string Head = "Id;Done;Task;Added;DoneOn";

        internal sealed class Item
        {
            public string Id, Text, Added, DoneOn;
            public bool Done;
        }

        // The file kept with the project, the file of the user, the one used (the first while
        // it is there):
        internal static string SharedFile(string project) =>
            Path.Combine(Path.GetDirectoryName(project) ?? "", "DynALisp", "Tasks.csv");

        internal static string UserFile(string project)
        {
            string key;
            using (var sha = System.Security.Cryptography.SHA1.Create())
                key = BitConverter.ToString(sha.ComputeHash(Utf8.GetBytes(Path.GetFullPath(project).ToUpperInvariant()))).Replace("-", "").Substring(0, 8);
            string name = new string(Path.GetFileNameWithoutExtension(project).Select(c => Path.GetInvalidFileNameChars().Contains(c) ? '_' : c).ToArray());
            return Path.Combine(Activity.Folder, "Tasks", name + "-" + key + ".csv");
        }

        internal static bool Shared(string project)
        {
            try { return File.Exists(SharedFile(project)); } catch { return false; }
        }

        internal static string FileOf(string project) => Shared(project) ? SharedFile(project) : UserFile(project);

        // The tasks kept with the project (on) or by the user (off): added to the other file
        // (the tasks it has already kept), this one deleted. The folder of the project must be
        // writable to keep them there.
        internal static void Share(string project, bool on)
        {
            string from = on ? UserFile(project) : SharedFile(project), to = on ? SharedFile(project) : UserFile(project);
            var items = File.Exists(from) ? ReadFile(from) : new List<Item>();
            Change(to, had =>
            {
                foreach (var t in items)
                    if (!had.Any(h => h.Id == t.Id)) had.Add(t);
            });
            if (File.Exists(from)) File.Delete(from);
            // the DynALisp folder of the project left empty is removed:
            if (!on)
                try
                {
                    string dir = Path.GetDirectoryName(from);
                    if (Directory.Exists(dir) && !Directory.EnumerateFileSystemEntries(dir).Any()) Directory.Delete(dir);
                }
                catch { }
        }

        // The tasks of a project, in their order (none when it has no file yet):
        internal static List<Item> Read(string project) => ReadFile(FileOf(project));

        static List<Item> ReadFile(string file)
        {
            if (!File.Exists(file)) return new List<Item>();
            using (var fs = new FileStream(file, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            using (var sr = new StreamReader(fs, Utf8)) return Parse(sr.ReadToEnd());
        }

        static List<Item> Parse(string text)
        {
            var items = new List<Item>();
            foreach (var line in text.Split('\n'))
            {
                var f = line.TrimEnd('\r').Split(';');
                if (f.Length < 3 || f[0] == "Id" || f[0].Length == 0) continue;
                items.Add(new Item
                {
                    Id = f[0], Done = f[1] == "1", Text = f[2],
                    Added = f.Length > 3 ? f[3] : "", DoneOn = f.Length > 4 ? f[4] : "",
                });
            }
            return items;
        }

        static string Today() => DateTime.Today.ToString("yyyy-MM-dd", CultureInfo.InvariantCulture);

        internal static void Add(string project, string text) =>
            Change(FileOf(project), items => items.Add(new Item
            {
                Id = Guid.NewGuid().ToString("N").Substring(0, 12),
                Text = text.Replace(';', ',').Replace('\r', ' ').Replace('\n', ' ').Trim(),
                Added = Today(), DoneOn = "",
            }));

        internal static void Check(string project, string id, bool done) =>
            Change(FileOf(project), items =>
            {
                foreach (var t in items.Where(t => t.Id == id)) { t.Done = done; t.DoneOn = done ? Today() : ""; }
            });

        internal static void Remove(string project, string id) => Change(FileOf(project), items => items.RemoveAll(t => t.Id == id));

        // The file read again alone (another user may be changing it: tried again for 2 s),
        // changed, written back:
        static void Change(string file, Action<List<Item>> change)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(file));
            for (int i = 0; ; i++)
            {
                try
                {
                    using (var fs = new FileStream(file, FileMode.OpenOrCreate, FileAccess.ReadWrite, FileShare.None))
                    {
                        var items = Parse(new StreamReader(fs, Utf8, false, 4096, true).ReadToEnd());
                        change(items);
                        var sb = new StringBuilder(Head + "\r\n");
                        foreach (var t in items)
                            sb.Append(t.Id).Append(';').Append(t.Done ? "1" : "0").Append(';').Append(t.Text).Append(';')
                              .Append(t.Added).Append(';').Append(t.DoneOn).Append("\r\n");
                        var bytes = Utf8.GetBytes(sb.ToString());
                        fs.Position = 0;
                        fs.SetLength(0);
                        fs.Write(bytes, 0, bytes.Length);
                    }
                    return;
                }
                catch (IOException) when (i < 40) { Thread.Sleep(50); }
            }
        }
    }
}
