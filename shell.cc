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
  if (_currentCommand._pid != 0) kill(_currentCommand._pid, SIGINT);
  else{
    printf("\n");
    _currentCommand.clear();
    Shell::prompt();
  }
}

void Shell::elimination(int signum) {
  int e;
  if ((e = waitpid(0, NULL, 0)) != -1) printf("%d exited\n", e);
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

  Command::_currentSimpleCommand = new SimpleCommand();
  Command::_currentSimpleCommand->insertArgument( "source" );
  Command::_currentSimpleCommand->insertArgument( ".shellrc" );
  Shell::_currentCommand._simpleCommands.insertSimpleCommand( Command::_currentSimpleCommand );
  Command::execute();

  Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
