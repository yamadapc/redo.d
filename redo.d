import std.file : rename, remove, isFile, exists;
import std.path : extension;
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

void printUsage()
{
  writeln("Usage: redo files...");
}

void redo(const string target)
{
  immutable string tmpPath = target ~ "---redoing";
  auto tmp = File(tmpPath, "w");
  scope(failure) remove(tmpPath);
  scope(exit) tmp.close();

  auto pid = spawnProcess(
    ["sh", target ~ ".do", "-", "-", tmpPath, ">", tmpPath],
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

string redoPath(const string path)
{
  string ret;
  string ext;

  if(exists(ret = path ~ ".do") && isFile(ret))
    return ret;

  ext = extension(path);
  if(ext != null && exists(ret = "default" ~ ext ~ ".do") && isFile(ret))
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
