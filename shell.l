
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
#include <algorithm>

static  void yyunput (int c,char *buf_ptr  );

void myunputc(int c) {
  unput(c);
}

%}

%option noyywrap

%%

\n {
  return NEWLINE;
}

([([^ \t\n]*[^\\ \t\n])""]\".*[^\\]\")+ {
  yylval.cpp_string = new std::string(yytext);
  yylval.cpp_string->erase(std::remove(yylval.cpp_string->begin(), yylval.cpp_string->end(), '\"'), yylval.cpp_string->end());
  return WORD;
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

[^ \t\n][^ \t\n]*  {
  /* Assume that file names have only alpha chars */
  yylval.cpp_string = new std::string(yytext);
  return WORD;
}
