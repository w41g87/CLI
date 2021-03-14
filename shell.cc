#include <cstdio>
#include <unistd.h>
#include "shell.hh"
#include <signal.h>

int yyparse(void);

void Shell::prompt() {
  if ( isatty(0) ) {
    printf("λ> ");
    fflush(stdout);
  }
}

void Shell::termination(int signum) {
  Command::clear();
  Shell::prompt();
}

int main() {
  
  struct sigaction sa;
  sa.sa_handler = disp;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = 0;

  if(sigaction(SIGINT, &sa, NULL)){
      perror("sigaction");
      exit(2);
  }
  
  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
