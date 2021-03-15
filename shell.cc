#include <cstdio>
#include <unistd.h>
#include "shell.hh"
#include <signal.h>
#include <wait.h>

int yyparse(void);

void Shell::prompt() {
  if ( isatty(0) ) {
    printf("λ> ");
    fflush(stdout);
  }
}

void Shell::termination(int signum) {
  printf("\n");
  _currentCommand.clear();
  Shell::prompt();
}

void Shell::elimination(int signum) {
  int i;
  while((i = wait(NULL)) > 0) {
    print("%d exited", i);
  }
}

int main() {
  
  struct sigaction c, d;
  c.sa_handler = Shell::termination;
  sigemptyset(&c.sa_mask);
  c.sa_flags = SA_RESTART;

  if(sigaction(SIGINT, &c, NULL)){
      perror("sigaction");
      exit(2);
  }

  d.sa_handler = Shell::elimination;
  sigemptyset(&d.sa_mask);
  c.sa_flags = SA_RESTART;

  if(sigaction(SIGCHLD, &d, NULL)){
      perror("sigaction");
      exit(2);
  }
  
  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
