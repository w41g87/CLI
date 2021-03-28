#include <cstdio>
#include <unistd.h>
#include "shell.hh"
#include <signal.h>
#include <string.h>
#include <wait.h>

int yyparse(void);
void swtchBfr(char*);
void initBfr();
void flushBfr();
extern char ** history;
extern "C" void resetLine();

void Shell::prompt() {
  // prompt only when IO are console and excludes special occasions
  if ( isatty(0) && isatty(1) && Shell::isPrompt) {
    char * p = secure_getenv("PROMPT");
    if (p) printf("%s ", p);
    else printf("λ> ");
    fflush(stdout);
  }
}

// prompt function for read-line.c
extern "C" void prompt() {
  Shell::prompt();
}

// signal handler for ctrl-C
void Shell::termination(int signum) {
  // if a command is running, kill it
  if (_currentCommand._pid != 0) kill(_currentCommand._pid, SIGINT);
  // if not, clear the current command, reset input buffer
  // and start a new input line
  else {
    flushBfr();
    _currentCommand.clear();
    
    if ( isatty(0) && isatty(1) && Shell::isPrompt) {
      resetLine();
      printf("\n");
    }
    Shell::prompt();
  }
}

// signal handler for zombie elimination
void Shell::elimination(int signum) {
  int r;
  int e;
  while((e = wait(&r)) > 0) {
    if (isatty(0)) printf("%d exited\n", e);
    if (WEXITSTATUS(r) && secure_getenv("ON_ERROR")) puts(secure_getenv("ON_ERROR"));
  }
}

int main(int argc, char* argv[], char* envp[]) {

  // Extra functionality: allows commands to be passed as arguments
  // and execute without entering the shell
  if (argc > 1) {
    Shell::isPrompt = false;
    char * input = (char *) malloc(strlen(argv[1]) + 2);
    strcpy(input, argv[1]);
    // add newline to trigger command execution
    input[strlen(argv[1])] = '\n';
    // using input stirng as buffer for flex scanner
    swtchBfr(input);
    yyparse();
    free(input);
    exit(0);
  }

  // initialize history
  history = (char**) calloc(8, sizeof(char*));

  // store argv[0] for env exp
  Shell::argv = argv[0];

  // Signal handling for ctrl-c
  struct sigaction c, d;
  c.sa_handler = Shell::termination;
  sigemptyset(&c.sa_mask);
  c.sa_flags = SA_RESTART;

  if(sigaction(SIGINT, &c, NULL)){
      perror("sigaction");
      exit(2);
  }

  // Signal handling for child exiting
  d.sa_handler = Shell::elimination;
  sigemptyset(&d.sa_mask);
  c.sa_flags = SA_RESTART;

  if(sigaction(SIGCHLD, &d, NULL)){
      perror("sigaction");
      exit(2);
  }

  // init stdin buffer
  initBfr();
  // Extra functionality: first time execution runs .shellrc
  Shell::_currentCommand.execute();
  yyparse();
}

Command Shell::_currentCommand;
bool Shell::isPrompt = true;
int Shell::lstRtn = 0;
int Shell::lstPid = 0;
char * Shell::lstArg = NULL;
char * Shell::argv = NULL;
