import std.file : rename, remove, isFile;
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
  if(isFile(path ~ ".do")) return path;

  auto ext = extension(path);
  string dft;

  if(ext != null && isFile(dft = "default" ~ ext ~ ".do")) return dft;

  return null;
}
