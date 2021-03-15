#ifndef shell_hh
#define shell_hh

#include "command.hh"

struct Shell {

  static void prompt();

  static void termination(int);

  static void elimination(int);

  static Command _currentCommand;
};

#endif
