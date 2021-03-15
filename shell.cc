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
  // _currentCommand.clear();
  printf("\n");
  // if ( isatty(0) ) {
  //   printf("current pid: %d\n", _currentCommand._pid);
  //   fflush(stdout);
  // }

  // Shell::prompt();
}

int main() {
  
  struct sigaction sa;
  sa.sa_handler = Shell::termination;
  sigemptyset(&sa.sa_mask);
  sa.sa_flags = SA_RESTART;

  if(sigaction(SIGINT, &sa, NULL)){
      perror("sigaction");
      exit(2);
  }
  
  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
