module redo;

import std.algorithm : startsWith, splitter, findSkip;
import std.array : array;
import std.ascii : LetterCase;
import std.digest.md : toHexString, MD5;
import std.file : rename, remove, isFile, isDir, exists, dirEntries, SpanMode,
                  mkdirRecurse, getSize;
import std.path : extension, baseName, buildPath, dirName, stripExtension;
import std.process : wait, spawnProcess, environment;
import std.regex : replaceFirst, regex;
import std.stdio : File, writeln, stdin, stdout, stderr;
import std.string : chompPrefix;

import leveldb : DB, Options;

/**
 * Print `redo` usage.
 */

void printUsage()
{
  writeln("Usage: redo files...");
}

/**
 * Creates a redo DB instance for the directory `topDir`
 */

DB createDb(const string topDir)
{
  auto opts = new Options;
  opts.create_if_missing = true;
  auto dbPath = buildPath(topDir, ".redo"); // TODO - resolve db path like git.
  return new DB(opts, dbPath);
}

/**
 * Gets the `value` stored in the `{topDir}/.redo` db (if it exists) key `key`.
 */

string getValue(const string topDir, const string key)
{
  auto db = createDb(topDir);
  scope(exit) db.close;
  string value;
  db.get(key, value);
  return value;
}

/**
 * Sets the `{topDIr}/redo` db's key `key` to `value`.
 */

void setValue(const string topDir, const string key, const string value)
{
  auto db = createDb(topDir);
  scope(exit) db.close;
  db.put(key, value);
}

/**
 * Redoes a target, if it's not up to date and has a .do script at `redoPath`.
 * If its do script fails, the function also updates it's entry to reflect this
 * failure and be considered out of date.
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

  scope(failure) setValue(topDir, target, "");
  runDo(target, redoPath);
}

/**
 * Redoes each of of a target's dependencies, updating their hash values in the
 * redo db.
 */

void redoIfChange(const string topDir, const string target, const string dep)
{
  auto redoPath = dep.redoPath;
  if(!(redoPath is null))
  {
    runDo(target, redoPath);
    return;
  }
  else if(!dep.exists || dep is null || dep.isDir)
  {
    return;
  }

  string hash = dep.hash;
  string head = getValue(topDir, target);

  // initialize the entry if it's not set
  if(head is null) setValue(topDir, target, dep);
  // append the current dependency if it isn't in the entry
  else if(!findSkip(head, dep)) setValue(topDir, target, head ~ ":" ~ dep);
  // update the dependency's hash value entry
  setValue(topDir, target ~ ":" ~ dep, hash);
}

/**
 * Runs a .do script at `script` path and updates the `target` if it's
 * ruccessful.
 */

void runDo(const string target, const string script)
{
  immutable string tmpPath = target ~ "---redoing";
  auto tmp = File(tmpPath, "w");
  scope(failure) tmpPath.remove;
  scope(exit) tmp.close;

  auto pid = spawnProcess(
    [ "sh", "-ex", script, target, target.baseName.stripExtension, tmpPath ],
    stdin,
    stdout,
    stderr,
    [
      "REDO_TARGET": target,
      "PATH": environment.get("PATH", "/bin")
    ]
  );
  auto exit = pid.wait;

  if(exit != 0)
  {
    writeln("Redo script exit with non-zero exit code; ", exit);
    if(tmpPath.exists) tmpPath.remove;
  }
  else if(tmpPath.exists && tmpPath.getSize != 0) rename(tmpPath, target);
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

/**
 * Returns whether a target is up to date according to its entry in the redo DB.
 */

bool upToDate(const string topDir, const string target)
{
  if(!target.exists) return false;

  auto entry = getValue(topDir, target);
  if(entry is null) return false;

  auto deps = splitter(entry, ":");
  if(deps.empty) return false;
  auto prefix = target ~ ":";

  foreach(dep; deps)
  {
    if(!dep.exists) return false;

    string oldhash = getValue(topDir, prefix ~ dep);
    string newhash = dep.hash;
    if(oldhash != newhash || (dep.redoPath && !upToDate(topDir, dep)))
      return false;
  }

  return true;
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
