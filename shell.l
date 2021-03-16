
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
#include "y.tab.hh"
#include "shell.hh"

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
  else for (i = i - 1; i >= 0; i--) myunputc(input[i]);
}

char * subshell (char ** input) {
  //printf("subshell function call: %s\n", input[0]);
  int size = 8;
  char* out = (char*)malloc(size);
  for (int i = 0; i < size; i++) out[i] = 0;
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
    printf("input: %s\n", input[0]);
    dup2(p[1], 1);
    close(p[0]);
    close(p[1]);
    execvp("/proc/self/exe", input);
    perror("child");
  }
  close(p[1]);
  waitpid(pid, 0, 0);

  int j, c;
  FILE* file = fdopen (p[0], "r");
  while ((c = fgetc (file)) != EOF) {
    if (j == size) {
      size *= 2;
      out = (char*)realloc(out, size);
      for (int i = size / 2; i < size; i++) out[i] = 0;
    }
    out[j++] = c;
  }
  fflush(file);
  fclose (file);
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

((([^ \t\n]*[^\\ \t\n])|"")\"(([^\n]*[^\\\n])|"")\"[^ \t\n]*)+ {
  yylval.cpp_string = removeE(yytext);
  return WORD;
}

"""$("(([^\n]*[^\\\n])|"")")" {
  char ** word = (char**) malloc(2);
  *(word + 1) = 0;
  *word = (char *)malloc(strlen(yytext) - 2);
  memcpy(*word, yytext + 2, strlen(yytext) - 3);
  word[0][strlen(yytext) - 3] = '\0';
  subshell(word);
  //free(*word);
  //free(word);
}

"""`"(([^\n]*[^\\\n])|"")"`" {
  char ** word = (char**) malloc(3);
  *(word + 2) = 0;
  *(word + 1) = (char *)malloc(strlen(yytext) - 1);
  memcpy(*(word + 1), yytext + 1, strlen(yytext) - 2);
  word[1][strlen(yytext) - 2] = '\0';
  word[0] = (char *)malloc(6);
  strcpy(*word, "shell\0");
  printf("yytext: %s\n", yytext);
  char * out = subshell(word);
  unputStr(out);
  //free(*word);
  //free(word);
  //free(out);
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
  //printf("lex scanned: %s\n", yytext);
  return WORD;
}

<<EOF>> {
  printf("EOF\n");
  YY_FLUSH_BUFFER;
  yypop_buffer_state();
  if ( !YY_CURRENT_BUFFER ) {
    Shell::_currentCommand.execute();
    yyterminate();
  }
  return NEWLINE;
}

%%
