
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
  command iomodifiers bgmodifier NEWLINE {
    printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE { 
    printf("   Yacc: Empty Line\n");
    //Shell::_currentCommand.execute(); 
  }
  | error NEWLINE { yyerrok; }
  ;

command: simple_command
        | command GUARD simple_command {
          //printf("   Yacc: Command pipeline\n");
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
    //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand->insertArgument( $1 );\
  }
  ;

command_word:
  WORD {
    //printf("   Yacc: insert command \"%s\"\n", $1->c_str());
    Command::_currentSimpleCommand = new SimpleCommand();
    Command::_currentSimpleCommand->insertArgument( $1 );
  }
  ;

iomodifiers:
  iomodifier_in iomodifier_out iomodifier_err
  | iomodifier_in iomodifier_err iomodifier_out
  | iomodifier_out iomodifier_in iomodifier_err
  | iomodifier_out iomodifier_err iomodifier_in
  | iomodifier_err iomodifier_in iomodifier_out
  | iomodifier_err iomodifier_out iomodifier_in
  ;

iomodifier_in:
  LESS WORD {
    //printf("   Yacc: insert input \"%s\"\n", $2->c_str());
    Shell::_currentCommand._inFile = $2;
  }
  | /*can be empty*/
  ;

iomodifier_out:
  GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
  }
  | GCONT WORD {
    //printf("   Yacc: insert background output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
  }
  | GGREAT WORD {
    //printf("   Yacc: insert append output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._appendO = true;
  }
  | GGCONT WORD {
    //printf("   Yacc: insert append background output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._appendO = true;
    Shell::_currentCommand._appendE = true;
  }
  | /*can be empty*/
  ;

iomodifier_err:
  GREAT2 WORD {
    //printf("   Yacc: insert error output \"%s\"\n", $2->c_str());
    Shell::_currentCommand._errFile = $2;
  }
  | /*can be empty*/
;

bgmodifier:
  CONT {
    //printf("   Yacc: The command will be ran in the background\n");
    Shell::_currentCommand._background = true;
  }
  | /*can be empty*/
  ;

%%

void
yyerror(const char * s)
{
  fprintf(stderr,"%s", s);
  Shell::prompt();
  yyparse();
}

#if 0
main()
{
  yyparse();
}
#endif
