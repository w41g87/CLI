#include <cstdio>
#include <unistd.h>
#include "shell.hh"
#include <signal.h>
#include <string.h>
#include <wait.h>

int yyparse(void);
void swtchBfr(char*);
void initBfr();

void Shell::prompt() {
  if ( isatty(0) && isatty(1) ) {
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

int main(int argc, char* argv[], char* envp[]) {
  
  // {
  //   int i = 0;
  //   printf("envp:\n");
  //   while (envp[i]) printf("%s\n", envp[i++]);
  //   printf("args:\n");
  //   for (i = 0; i < argc ; i++) printf("%s\n", argv[i]);
  // }

  if (strcmp(argv[0], "shell")) {
    char * input = (char *) malloc(strlen(argv[0]) + 2);
    strcpy(input, argv[0]);
    input[strlen(argv[0])] = '\n';
    printf("subshell: %s %s\n", argv[0], input);
    swtchBfr(input);
    yyparse();
    //free(input);
    exit(0);
  }

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
  initBfr();
  Command::_currentSimpleCommand->insertArgument( new std::string("source") );
  Command::_currentSimpleCommand->insertArgument( new std::string(".shellrc") );
  Shell::_currentCommand.insertSimpleCommand( Command::_currentSimpleCommand );
  Shell::_currentCommand.execute();
  //Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
