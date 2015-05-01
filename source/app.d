/**
 * Authors: Pedro Tacla Yamada
 * Date: August 1, 2014
 * License: Licensed under the GPLv3 license. See LICENSE for more information
 */
import std.file : getcwd;
import std.process : environment;

import redo : redo, redoPath, redoIfChange, printUsage;

int main(string[] args)
{
  import std.stdio;
  if(args.length == 1)
  {
    printUsage;
    return 1;
  }

  auto topDir = getcwd();

  if(args[0] == "redo-ifchange")
  {
    auto target = environment.get("REDO_TARGET");
    if(target == null)
    {
      writeln("Missing REDO_TARGET environment variable.");
      return 1;
    }

    redoIfChange(topDir, target, target.redoPath);

    foreach(const ref arg; args[1..$])
      redoIfChange(topDir, target, arg);
  }
  else
  {
    foreach(const ref arg; args[1..$])
      redo(topDir, arg);
  }

  return 0;
}

