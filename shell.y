
/*
 * CS-252
 * shell.y: parser for shell
 *
 * This parser compiles the following grammar:
 *
 *	cmd [arg]* [> filename]
 *
 * you must extend it to understand the complete shell grammar
 *
 */

%code requires 
{
#include <string>

#if __cplusplus > 199711L
#define register      // Deprecated in C++11 so remove the keyword
#endif
}

%union
{
  char        *string_val;
  // Example of using a c++ type in yacc
  std::string *cpp_string;
}

%token <cpp_string> WORD
%token NOTOKEN GREAT NEWLINE
%token GREAT2 GGCONT GCONT LCONT GGREAT CONT LESS GUARD

%{
//#define yylex yylex
#include <cstdio>
#include "shell.hh"

void yyerror(const char * s);
int yylex();

%}

%%

goal:
  commands
  ;

commands:
  command iomodifier_opt NEWLINE {
    printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE 
  | error NEWLINE { yyerrok; }
  ;

command: simple_command {
        | command GUARD {
          printf("   Yacc: Command pipeline\n");
        }
       ;

simple_command:	
  command_and_args 
  ;

command_and_args:
  command_word argument_list {
    Shell::_currentCommand.
    insertSimpleCommand( Command::_currentSimpleCommand );
  }
  ;

argument_list:
  argument_list argument
  | /* can be empty */
  ;

argument:
  WORD {
    printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand->insertArgument( $1 );\
  }
  ;

command_word:
  WORD {
    printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifier_opt:
  GREAT WORD {
    printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
  }
  | LESS WORD {
    printf("   Yacc: insert input \"%s\"\n", $2->c_str());
    Shell::_currentCommand._inFile = $2;
  }
  | GREAT2 WORD {
    printf("   Yacc: insert error output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._errFile = $2;
  }
  | GCONT WORD {
    printf("   Yacc: insert background output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._background = true;
  }
  | GGREAT WORD {
    printf("   Yacc: insert append output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
  }
  | GGCONT WORD {
    printf("   Yacc: insert append background output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._background = true;
  }
  | CONT {
    printf("   The command will be ran in the background");
    Shell::_currentCommand._background = true;
  }
  | /* can be empty */ 
  ;

%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
}

#if 0
main()
{
  yyparse();
}
#endif
