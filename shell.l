
/*
 *
 * CS-252 
 * shell.l: lexical analyzer for shell
 * You have to extend it.
 *
 */

%{

#include <cstring>
#include "y.tab.hh"

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}


void source(char * file) {
  printf("Source called\n");
  YY_BUFFER_STATE ybs = yy_create_buffer(fopen(file, "r"), YY_BUF_SIZE);
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
}

%%
