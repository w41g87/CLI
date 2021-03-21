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

void Shell::prompt() {
  if ( isatty(0) && isatty(1) && Shell::isPrompt) {
    char * p = secure_getenv("PROMPT");
    if (p) printf("%s ", p);
    else printf("λ> ");
    fflush(stdout);
  }
}

void Shell::termination(int signum) {
  if (_currentCommand._pid != 0) kill(_currentCommand._pid, SIGINT);
  else{
    flushBfr();
    printf("\n");
    _currentCommand.clear();
    Shell::prompt();
  }
}

void Shell::elimination(int signum) {
  int r = 0;
  int e = waitpid(-1, &r, 0);
  if (e == -1) Shell::lstRtn = WEXITSTATUS(r);
  else {
    if (isatty(0)) printf("%d exited\n", e);
    Shell::lstPid = e;
  }
  if (WEXITSTATUS(r) && secure_getenv("ON_ERROR")) puts("ON_ERROR");
}

int main(int argc, char* argv[], char* envp[]) {
  
  // {
  //   int i = 0;
  //   printf("envp:\n");
  //   while (envp[i]) printf("%s\n", envp[i++]);
  //   printf("args:\n");
  //   for (i = 0; i < argc ; i++) printf("%s\n", argv[i]);
  // }

  if (argc > 1) {
    Shell::isPrompt = false;
    char * input = (char *) malloc(strlen(argv[1]) + 2);
    strcpy(input, argv[1]);
    input[strlen(argv[1])] = '\n';
    //printf("subshell: %s %s\n", argv[1], input);
    swtchBfr(input);
    yyparse();
    free(input);
    exit(0);
  }

  // initialize history
  history = (char**) calloc(8, sizeof(char*));

  // store argv[0];
  Shell::argv = argv[0];

  // Signal handling
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

  // init stdin buffer
  initBfr();
  Shell::_currentCommand.execute();
  //Shell::prompt();
  yyparse();
}

Command Shell::_currentCommand;
bool Shell::isPrompt = true;
int Shell::lstRtn = 0;
int Shell::lstPid = 0;
char * Shell::lstArg = NULL;
char * Shell::argv;