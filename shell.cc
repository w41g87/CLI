#include <cstdio>

#include "shell.hh"

int yyparse(void);

void Shell::prompt() {
  printf("λ> ");
  fflush(stdout);
}

int main() {
  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
