import std.ascii : LetterCase;
import std.digest.md : toHexString, MD5;
import std.file : rename, remove, isFile, isDir, exists, dirEntries, SpanMode,
                  mkdirRecurse;
import std.path : extension, baseName, buildPath, dirName;
import std.process : wait, spawnProcess, environment;
import std.stdio : File, writeln, stdin, stdout, stderr;

void main(string[] args)
{
  version(unittest) return;

  if(args.length == 1) return printUsage();

  if(args[0] == "redo-ifchange")
    foreach(const ref arg; args[1..$]) redoIfChange(arg);
  else
    foreach(const ref arg; args[1..$]) redo(arg);
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
  if(upToDate(target)) return;

  immutable string redoPath = target.redoPath;

  if(redoPath == null)
  {
    writeln("No .do file found for target '" ~ target ~ "'");
    return;
  }

  immutable string tmpPath = target ~ "---redoing";
  auto tmp = File(tmpPath, "w");
  scope(failure) remove(tmpPath);
  scope(exit) tmp.close;

  auto pid = spawnProcess(
    [ "sh", redoPath, "-", target.baseName, tmpPath ],
    stdin,
    tmp,
    tmp,
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
 * Hashes a dependency for the REDO_TARGET env. variable.
 */

void redoIfChange(const string dep)
{
  auto target = environment.get("REDO_TARGET");

  if(target == null)
  {
    writeln("Missing REDO_TARGET environment variable.");
    return;
  }
  else if(!dep.exists)
  {
    return;
  }

  auto depsDir = buildPath(".redo", target);
  mkdirRecurse(depsDir);

  string hash = dep.genHash;
  auto f = File(buildPath(depsDir, dep), "w");
  scope(exit) f.close;

  f.write(hash);
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
  if(ext != null)
  {
    auto dir = path.dirName;
    ret = dir != "." ? buildPath(dir, "default" ~ ext ~ ".do") :
                       "default" ~ ext ~ ".do";
    if(ret.exists && ret.isFile) return ret;
  }

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
  auto depsDir = buildPath(".redo", target);
  if(!exists(depsDir)) return false;

  foreach(entry; dirEntries(depsDir, SpanMode.breadth))
  {
    auto dependency = entry.baseName;
    if(!exists(dependency)) return false;

    auto oldhash = getHash(entry);
    auto newhash = genHash(dependency);
    if(oldhash != newhash) return false;
  }

  return true;
}

unittest
{
  writeln("Running tests for `upToDate`");
  assert(upToDate("non-existent-target") == false);
  assert(upToDate("research") == false);
}

/**
 * Gets the hash for an entry in the `.redo` directory.
 */

string getHash(const string entry)
{
  auto file = new File(entry, "r");
  scope(exit) file.close;
  return file.readln[0..$];
}

/**
 * Generates an md5 hash for given file
 */

string genHash(const string filePath)
{
  auto file = new File(filePath, "r");
  scope(exit) file.close();

  MD5 hash;
  foreach(ubyte[] buffer; file.byChunk(4096))
    hash.put(buffer);
  ubyte[] result = hash.finish();

  return result.toHexString!(LetterCase.lower);
}
