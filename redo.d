import std.file : rename, remove, isFile, isDir, exists, dirEntries, SpanMode;
import std.path : extension, baseName, buildPath;
import std.process : wait, spawnProcess, environment;
import std.stdio : File, writeln, stdin, stdout, stderr;

void main(string[] args)
{
  version(unittest) return;

  if(args.length == 1) return printUsage();

  foreach(const ref arg; args[1..$])
  {
    redo(arg);
  }
}

/**
 * Print `redo` usage.
 */

void printUsage()
{
  writeln("Usage: redo files...");
}

/**
 * Redoes a target
 */

void redo(const string target)
{
  immutable string redoPath = target.redoPath;

  if(redoPath == null) {
    writeln("No .do file found for target '" ~ target ~ "'");
    return;
  }

  immutable string tmpPath = target ~ "---redoing";
  auto tmp = File(tmpPath, "w");
  scope(failure) remove(tmpPath);
  scope(exit) tmp.close;

  auto pid = spawnProcess(
    [
      "sh", redoPath, "-", target.extension.baseName, tmpPath,
      ">", tmpPath
    ],
    stdin,
    stdout,
    stderr,
    [
      "REDO_TARGET": target,
      "PATH": environment.get("PATH", "/bin") ~ ":."
    ]
  );
  auto exit = wait(pid);

  if(exit != 0)
  {
    writeln("Redo script exit with non-zero exit code: ", exit);
    remove(tmpPath);
  }
  else rename(tmpPath, target);
}

/**
 * Fetches the redo path for a given file.
 */

string redoPath(const string path)
{
  string ret;
  string ext;

  if(exists(ret = path ~ ".do") && ret.isFile)
    return ret;

  ext = path.extension;
  if(ext != null && exists(ret = "default" ~ ext ~ ".do") && ret.isFile)
    return ret;

  return null;
}

unittest
{
  writeln("Running tests for `redoPath`");
  assert(redoPath("redo") == "redo.do");
  assert(redoPath("something") == null);
  assert(redoPath("something.d") == "default.d.do");
}

/**
 * Returns whether a target is up-to-date according to its entry in the redo DB.
 */

bool upToDate(const string target)
{
  // If a target doesn't exist it's out-of-date by definition
  if(!exists(target)) return false;

  // For a directory, scan its contents and return false if any of its entries
  // isn't up-to-date.
  if(target.isDir)
  {
    auto entries = dirEntries(target, SpanMode.breadth);
    foreach(entry; dirEntries(target, SpanMode.breadth))
      if(!upToDate(buildPath(target, entry))) return false;
    return true;
  }

  // this isn't right; we look in the .redo dir
  // from this point out implementation will start to differ from the haskell
  // implementation, as we'll maybe use a small database engine, instead of
  // plain files (LevelDb, anyone?)
  auto f = File(target, "r");
  scope(exit) f.close;
  auto oldHash = f.readln;
  //auto newHash = ...

  return true;
}

unittest
{
  writeln("Running tests for `upToDate`");
  assert(upToDate("non-existent-target") == false);
  assert(upToDate("research") == false);
}
