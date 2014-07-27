import std.algorithm : startsWith;
import std.ascii : LetterCase;
import std.digest.md : toHexString, MD5;
import std.file : rename, remove, isFile, isDir, exists, dirEntries, SpanMode,
                  mkdirRecurse, getSize;
import std.path : extension, baseName, buildPath, dirName, stripExtension;
import std.process : wait, spawnProcess, environment, getcwd;
import std.regex : replaceFirst, regex;
import std.stdio : File, writeln, stdin, stdout, stderr;
import std.string : chompPrefix;

import leveldb : DB, Slice, Options;

version(unittest) void main() {}
else
void main(string[] args)
{
  if(args.length == 1) return printUsage;

  auto topDir = getcwd();

  if(args[0] == "redo-ifchange")
  {
    foreach(const ref arg; args[1..$])
      redoIfChange(topDir, arg);
  }
  else
  {
    foreach(const ref arg; args[1..$])
      redo(topDir, arg);
  }
}

/**
 * Print `redo` usage.
 */

void printUsage()
{
  writeln("Usage: redo files...");
}

DB getDb(const string topDir)
{
  auto dbPath = buildPath(topDir, ".redo"); // TODO - resolve db path like git.

  auto opts = new Options;
  opts.create_if_missing = true;
  return new DB(opts, dbPath);
}

/**
 * Redoes a target
 */

void redo(const string topDir, const string target)
{
  if(upToDate(topDir, target)) return;

  immutable string redoPath = target.redoPath;

  if(redoPath == null)
  {
    writeln("No .do file found for target '" ~ target ~ "'");
    return;
  }

  immutable string tmpPath = target ~ "---redoing";
  auto tmp = File(tmpPath, "w");
  scope(failure) tmpPath.remove;
  scope(exit) tmp.close;

  auto pid = spawnProcess(
    [ "sh", "-x", redoPath, target, target.baseName.stripExtension, tmpPath ],
    stdin,
    stdout,
    stderr,
    [
      "REDO_TARGET": target,
      "PATH": environment.get("PATH", "/bin") ~ ":" ~ "."
    ]
  );
  auto exit = pid.wait;

  if(exit != 0)
  {
    writeln("Redo script exit with non-zero exit code; ", exit);
    tmpPath.remove;
  }
  else if(tmpPath.getSize == 0) tmpPath.remove;
  else rename(tmpPath, target);
}

/**
 * Hashes a dependency for the REDO_TARGET env. variable.
 */

void redoIfChange(const string topDir, const string dep)
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

  string hash = dep.hash;

  auto db = getDb(topDir);
  scope(exit) delete db;
  auto head = db.find(target, "");
  if(head == "") db.put(target, true);
  db.put(target ~ "_" ~ dep, hash);
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
  assert(redoPath("something.c") == "default.c.do");
}

/**
 * Returns whether a target is up-to-date according to its entry in the redo DB.
 */

bool upToDate(const string topDir, const string target)
{
  if(!target.exists) return false;

  auto db = getDb(topDir);
  scope(exit) delete db;
  auto it = db.iterator;
  scope(exit) delete it;
  it.seek(target);

  if(it.valid && it.value.as!bool)
  {
    it.next;
    if(!it.valid) return true; // this shouldn't ever execute.
  }
  else return false;

  auto prefix = target ~ "_";
  foreach(Slice key, Slice value; it)
  {
    auto skey = key.as!string;
    if(0 == startsWith(skey, prefix)) continue;

    auto dep = skey.chompPrefix(prefix);
    if(!dep.exists) return false;

    auto oldhash = value.as!string;
    auto newhash = dep.hash;
    if(oldhash != newhash || (dep.redoPath && !upToDate(topDir, dep)))
      return false;
  }

  return true;
}

unittest
{
  assert(upToDate(".", "non-existent-target") == false);
  assert(upToDate(".", "research") == false);
}

/**
 * Generates an md5 hash for given file
 */

string hash(const string filePath)
{
  auto file = new File(filePath, "r");
  scope(exit) file.close;

  MD5 hash;
  foreach(ubyte[] buffer; file.byChunk(4096))
    hash.put(buffer);
  ubyte[] result = hash.finish;

  return result.toHexString!(LetterCase.lower);
}
