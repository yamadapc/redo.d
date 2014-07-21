import std.file : rename, remove, isFile, exists;
import std.path : extension;
import std.process : wait, spawnProcess;
import std.stdio : File, writeln, stdin, stdout;

void main(string[] args)
{
  foreach(const ref arg; args[0..$])
  {
    redo(arg);
  }
}

void redo(const string target)
{
  immutable string tmpPath = target ~ "---redoing";
  auto tmp = File(tmpPath, "w");
  scope(failure) remove(tmpPath);
  scope(exit) tmp.close();

  auto pid = spawnProcess(
    ["sh", target ~ ".do", "-", "-", tmpPath, ">", tmpPath],
    stdin
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
