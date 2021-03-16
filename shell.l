
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include <unistd.h>
#include "y.tab.hh"

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

void swtchBfr(char * input) {
  YY_BUFFER_STATE ybs = yy_scan_string(input);
  yy_switch_to_buffer(ybs);
}

void source(char * file) {
  FILE * fp;
  if (!(fp = fopen(file, "r"))) {
    perror("IO");
    return;
  }
  
  YY_BUFFER_STATE ybs = yy_create_buffer(fp, YY_BUF_SIZE);
  yypush_buffer_state(ybs);
}

std::string * removeE(char * s) {
  std::string* str = new std::string();
  for(int i = 0; i < strlen(s); i++) {
    if ((i > 0 && s[i - 1] == '\\') || (s[i] != '\"' && s[i] != '\\')) {
      str->push_back(s[i]);
      printf("%c", s[i]);
    }
  }
  return str;
}

int subshell (char ** input) {
  printf("subshell function call: %s\n", input[0]);
  char buf[8192];
  int p[2];
  if ( pipe(p) == -1) {
    perror( "shell: pipe");
    exit( 2 );
  }
  int pid = fork();
  if ( pid == -1 ) {
    perror( "shell: fork");
    exit( 2 );
  }

  if (pid == 0) {
    dup2(p[0], 1);
    close(p[0]);
    execvp("/proc/self/exe", input);
  } else {
    read(p[1], buf, 8191);
    close(p[0]);
    close(p[1]);
    printf("%s", buf);
  }
}


%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

((([^ \t\n]*[^\\ \t\n])|"")\"(([^\n]*[^\\\n])|"")\"[^ \t\n]*)+ {
  yylval.cpp_string = removeE(yytext);
  return WORD;
}

"""$(".*")""" {
  char ** temp = (char**) malloc(2);
  *(temp + 1) = 0;
  *temp = (char *)malloc(strlen(yytext) - 2);
  memcpy(*temp, yytext + 2, strlen(yytext) - 3);
  temp[0][strlen(yytext) - 2] = '\0';
  subshell(temp);
  free(*temp);
  free(temp);
}

"""`".*"`""" {
  char ** temp = (char**) malloc(2);
  *(temp + 1) = 0;
  *temp = (char *)malloc(strlen(yytext) - 1);
  memcpy(*temp, yytext + 1, strlen(yytext) - 2);
  temp[0][strlen(yytext) - 1] = '\0';
  subshell(temp);
  free(*temp);
  free(temp);
}

[ \t] {
  /* Discard spaces and tabs */
}

"""|" {
  return GUARD;
}

"""2>" {
  return GREAT2;
}

""">>&" {
  return GGCONT;
}

""">&" {
  return GCONT;
}

"""<&" {
  return LCONT;
}

""">>" {
  return GGREAT;
}

""">" {
  return GREAT;
}

"""<" {
  return LESS;
}

"""&" {
  return CONT;
}

[^ \t\n]+  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = removeE(yytext);
  return WORD;
}

<<EOF>> {
  yypop_buffer_state();
  YY_FLUSH_BUFFER;
  if ( !YY_CURRENT_BUFFER ) {
    yyterminate();
  }
  return NEWLINE;
}

%%
