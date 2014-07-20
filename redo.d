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

  auto pid = spawnProcess(
    ["sh", target ~ ".do", "-", "-", tmpPath, ">", tmpPath],
    stdin
  );
  auto exit = wait(pid);
  tmp.close();

  if(exit == 0)
  {
    rename(tmpPath, target);
  }
  else
  {
    writeln("Redo script exit with non-zero exit code: ", exit);
    remove(tmpPath);
  }
}

string redoPath(const string path)
{
  if(isFile(path ~ ".do"))
  {
    return path;
  }
  else
  {
    auto ext = extension(path);
    if(ext != null)
    {
      auto dft =  "default" ~ ext ~ ".do";
      if(isFile(dft))
      {
        return dft;
      }
    }
  }

  return null;
}
