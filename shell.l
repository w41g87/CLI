
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
#include <sys/wait.h>
#include <sys/types.h> 
#include <iostream>
#include <limits.h>
#include <stdlib.h>
#include <math.h>
#include "y.tab.hh"
#include "shell.hh"

using namespace std;

///////////////////////// Start of Edit Mode Code /////////////////////////

extern "C" char * read_line();

int mygetc(FILE * f) {
  static char *p;
  char ch;

     if (!isatty(0)) {
  // stdin is not a tty. Call real getc
    return getc(f);
  }

  // stdin is a tty. Call our read_line.
  if (p==NULL || *p == 0) {
    char * s = read_line();
    p = s;
  }

  ch = *p;
  p++;

  return ch;
}

#undef getc
#define getc(f) mygetc(f)

///////////////////////// End of Edit Mode Code /////////////////////////

static  void yyunput (int c,char *buf_ptr  );
void * recallocarray(void *, size_t, size_t, size_t)

FILE * fp = NULL;

void myunputc(int c) {
  unput(c);
}
// initialize stdin input buffer
void initBfr() {
  yypush_buffer_state(yy_create_buffer(stdin, YY_BUF_SIZE));
}

// pop all buffers off buffer stack
void termBfr() {
  while ( YY_CURRENT_BUFFER ) {
    YY_FLUSH_BUFFER;
    yypop_buffer_state();
  }
}

// YY_FLUSH_BUFFER but could be called externally
void flushBfr() { YY_FLUSH_BUFFER; }

void swtchBfr(char * input) {
  yy_switch_to_buffer(yy_scan_string(input));
}

// source function
void source(char * file) {
  if (!(fp = fopen(file, "r"))) {
    perror("IO");
    return;
  }
  // create a new buffer and push it onto the stack
  yypush_buffer_state(yy_create_buffer(fp, YY_BUF_SIZE));
  return;
}

// remove escape
std::string * removeE(char * s) {
  std::string* str = new std::string();
  bool isEscaped = false;
  for(int i = 0; i < strlen(s); i++) {
    // if the current char is unescaped and is backslash
    // mark next char as escaped
    if (!isEscaped && s[i] == '\\') isEscaped = !isEscaped;
    // if there is an escaped character, or a character
    // that is neither quote or backslash, add it into the string
    else if (isEscaped || (s[i] != '\"' && s[i] != '\\')) {
      isEscaped = false;
      str->push_back(s[i]);
    }
  }
  return str;
}

// unput a 0-terminated string
void unputStr(char * input) {
  int i = 0;
  while(input[i] != '\0') {
    // replace newline with space
    if (input[i] == '\n') input[i] = ' ';
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

// subshell implementation
char * subshell (char ** input) {
  // initial output buffer size is 8
  int size = 8;
  char* out = (char*)malloc(size);
  // only one pipe is initialized to gather output from child
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
    // child, writes to pipe
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
  // parent reads from pipe
  FILE* file = fdopen (p[0], "r");
  while ((c = fgetc (file)) != EOF) {
    out[i++] = c;
    // dynamically resize buffer
    if (i == size) {
      size *= 2;
      out = (char*)recallocarray(out, size, sizeof(char), size / 2);
    }
  }
  
  fclose(file);
  close(p[0]);

  return out;
}


%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

((([^ \t\n]*[^\\ \t\n])|"")\"(\\.|[^"\\\n])*\"[^ \t\n]*)+ {
  yylval.cpp_string = removeE(yytext);
  return WORD;
}

"$("(\\.|[^\)\\])*")" {
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

"`"(\\.|[^`\\])*"`" {
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

"|" {
  return GUARD;
}

"2>" {
  return GREAT2;
}

">>&" {
  return GGCONT;
}

">&" {
  return GCONT;
}

"<&" {
  return LCONT;
}

">>" {
  return GGREAT;
}

">" {
  return GREAT;
}

"<" {
  return LESS;
}

"&" {
  return CONT;
}

(\\.|[^>&<\|\\ \t\n`\(\)])+  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = removeE(yytext);

  //printf("lex scanned: %s\n", yytext);
  //cout << *yylval.cpp_string << endl;
  return WORD;
}

<<EOF>> {
  //printf("EOF\n");
  YY_FLUSH_BUFFER;
  yypop_buffer_state();
  if (fp) fclose(fp);
  fp = NULL;
  if ( !YY_CURRENT_BUFFER ) {
    Shell::_currentCommand.execute();
    yyterminate();
  }
  return NEWLINE;
}

%%
