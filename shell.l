
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
#include <sys/types.h> 
#include <sys/wait.h> 
#include <iostream>
#include "y.tab.hh"
#include "shell.hh"

using namespace std;

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

void initBfr() {
  yypush_buffer_state(yy_create_buffer(stdin, YY_BUF_SIZE));
}

void swtchBfr(char * input) {
  yy_switch_to_buffer(yy_scan_string(input));
}

void source(char * file) {
  FILE * fp;
  if (!(fp = fopen(file, "r"))) {
    perror("IO");
    return;
  }
  yypush_buffer_state(yy_create_buffer(fp, YY_BUF_SIZE));
}

std::string * removeE(char * s) {
  std::string* str = new std::string();
  for(int i = 0; i < strlen(s); i++) {
    if ((i > 0 && s[i - 1] == '\\') || (s[i] != '\"' && s[i] != '\\')) {
      str->push_back(s[i]);
      //printf("%c", s[i]);
    }
  }
  //str->push_back(0);
  return str;
}

void unputStr(char * input) {
  int i = 0;
  while(input[i] != '\0') {
    if (input[i] == '\n') input[i] = ' ';
    //printf("%c", input[i]);
    i++;
  }
  if (i == 0) printf("shell: subshell execution error\n");
  else {
    for (i = i - 1; i >= 0; i--) {
    //printf("%c", input[i]);
    myunputc(input[i]);
    }
  }
}

char * subshell (char ** input) {
  //printf("subshell function call: %s\n", input[0]);
  int size = 8;
  char* out = (char*)malloc(size);
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
    //printf("input: %s\n", input[0]);
    dup2(p[1], 1);
    close(p[0]);
    close(p[1]);
    execvp("/proc/self/exe", input);
    perror("child");
  }
  close(p[1]);
  waitpid(pid, 0, 0);

  int i, c;
  i = 0;
  FILE* file = fdopen (p[0], "r");
  while ((c = fgetc (file)) != EOF) {
    if (i == size - 1) {
      size *= 2;
      out = (char*)realloc(out, size);
    }
    out[i++] = c;
    //putchar(c);
  }
  out[i] = 0;

  //printf("size: %d\n", size);
  //printf("str: %s\n", out);
  
  fclose(file);
  close(p[0]);
  
  //printf("print ended\n");
  return out;
}


%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

((([^ \t\n]*[^\\ \t\n])|"")\"([^(\\\")]*[^\\]|"")\"[^ \t\n]*)+ {
  yylval.cpp_string = removeE(yytext);
  return WORD;
}

"""$("(([^\n]*[^\\\n])|"")")" {
  char ** word = (char**) malloc(3);
  word[2] = 0;
  word[1] = (char *)malloc(strlen(yytext) - 2);
  memcpy(word[1], yytext + 2, strlen(yytext) - 3);
  word[1][strlen(yytext) - 3] = '\0';
  word[0] = (char *)malloc(6);
  strcpy(*word, "shell\0");
  char * out = subshell(word);
  free(*word);
  free(word[1]);
  free(word);

  unputStr(out);
  free(out);
}

"""`"(([^\n]*[^\\\n])|"")"`" {
  char ** word = (char**) malloc(3);
  word[2] = 0;
  word[1] = (char *)malloc(strlen(yytext) - 1);
  memcpy(word[1], yytext + 1, strlen(yytext) - 2);
  word[1][strlen(yytext) - 2] = '\0';
  word[0] = (char *)malloc(6);
  strcpy(*word, "shell\0");
  //printf("yytext: %s\n", yytext);

  char * out = subshell(word);
  free(*word);
  free(word[1]);
  free(word);

  unputStr(out);
  free(out);
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
  yylval.cpp_string = new std::string(yytext);
  //removeE(yytext);
  //printf("lex scanned: %s\n", yytext);
  //cout << *yylval.cpp_string << endl;
  return WORD;
}

<<EOF>> {
  //printf("EOF\n");
  YY_FLUSH_BUFFER;
  yypop_buffer_state();
  if ( !YY_CURRENT_BUFFER ) {
    Shell::_currentCommand.execute();
    yyterminate();
  }
  return NEWLINE;
}

%%
