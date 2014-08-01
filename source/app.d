import std.process : getcwd;
import redo : redo, redoIfChange, printUsage;

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

