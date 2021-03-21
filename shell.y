
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
#include <string>
#include <string.h>
#include <dirent.h>
#include <regex.h>
#include "shell.hh"

char * tilExp(const char *);

char ** dirExp(const char *);

void yyerror(const char * s);
int yylex();

extern "C" void * recallocarray(void *, size_t, size_t, size_t);

%}

%%

goal:
  commandline
  | goal commandline
  ;


commandline:
  commands iomodifiers bgmodifier NEWLINE {
    //printf("   Yacc: Execute command\n");
    Shell::_currentCommand.execute();
  }
  | NEWLINE { 
    //printf("   Yacc: Empty Line\n");
    Shell::_currentCommand.execute(); 
  }
  | error NEWLINE { yyerrok; }
  ;

commands: simple_command
        | commands GUARD simple_command {
          //printf("   Yacc: Command pipeline\n");
        }
       ;

simple_command:	
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
    if ($1->find('?') != std::string::npos || $1->find('*') != std::string::npos) {
      char ** exp = dirExp($1->c_str());
      delete $1;
      // iterate through the array and put everything into arguement
      int i;
      while(exp[i]) {
        Command::_currentSimpleCommand->insertArgument( new std::string(exp[i]) );
        free(exp[i]);
        i++;
      }
      free(exp);
    } else if ($1->c_str()[0] == '~') {
      if ($1->find('/') != std::string::npos) {
        char * home = tilExp($1->substr(0, $1->find('/')).c_str());
        std::string * newArg = new std::string();
        newArg->append(home);
        free(home);
        newArg->append($1->substr($1->find('/')));
        delete $1;
        Command::_currentSimpleCommand->insertArgument( newArg );
      } else {
        char * home = tilExp($1->substr(1).c_str());
        delete $1;
        Command::_currentSimpleCommand->insertArgument( new std::string(home) );
        free(home);
      }
    } else {
      Command::_currentSimpleCommand->insertArgument( $1 );
    }
    //printf("   Yacc: insert argument \"%s\"\n", $1->c_str());
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
    if (Shell::_currentCommand._outFile) {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
      return;
    }
    Shell::_currentCommand._outFile = $2;
  }
  | GCONT WORD {
    //printf("   Yacc: insert background output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile || Shell::_currentCommand._errFile) {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
      return;
    }
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
  fprintf(stderr,"%s\n", s);
  Shell::prompt();
  yyparse();
}

char * w2r (char * input) {
  std::string reg = std::string();
  reg.push_back('^');
  switch(*input) {
    case '*':
      reg.append("([^\\. ][^ ]*|\"\")");
      break;
    case '?':
      reg.append("[^\\. ]");
      break;
    case '+':
      reg.append("\\+");
      break;
    case '[':
      reg.append("\\[");
      break;
    case ']':
      reg.append("\\]");
      break;
    case '(':
      reg.append("\\(");
      break;
    case ')':
      reg.append("\\)");
      break;
    case '.':
      reg.append("\\.");
      break;
    default:
      reg.push_back(*input);
  }

  for (int i = 1; i < strlen(input); i++) {
    switch(input[i]) {
      case '*':
        reg.append("[^\\. ]?[^ ]*");
        break;
      case '?':
        reg.append("[^\\. ]");
        break;
      case '+':
        reg.append("\\+");
        break;
      case '[':
        reg.append("\\[");
        break;
      case ']':
        reg.append("\\]");
        break;
      case '(':
        reg.append("\\(");
        break;
      case ')':
        reg.append("\\)");
        break;
      case '.':
        reg.append("\\.");
        break;
      default:
        reg.push_back(input[i]);
    }
  }
  reg.push_back('$');

  char * output = (char *)calloc(strlen(reg.c_str()) + 1, sizeof(char));
  strcpy(output, reg.c_str());
  return(output);
}

char ** expandedPaths(const char * dirA, const char * arg) {
  //printf("dir address: %s\nrest: %s\n", dirA, arg);
  char ** output = (char **)calloc(8, sizeof(char*));
  int outputI = 0;
  int outputSize = 8;
  char * currentDir;
  char * rest = NULL;

  // terminating cases
  if (!strchr(arg, '/')) {
    currentDir = (char *)calloc(strlen(arg) + 1, sizeof(char));
    strcpy(currentDir, arg);
  } else {
    int len = strchr(arg, '/') - arg;
    currentDir = (char *)calloc(len + 1, sizeof(char));
    strncpy(currentDir, arg, len);
    rest = (char *)calloc(strlen(arg) - len, sizeof(char));
    strcpy(rest, arg + len + 1);
  }

  // regex conversion
  char * regExp = w2r(currentDir);
  //printf("regExp: %s\n", regExp);
  free(currentDir);
  currentDir = NULL;
  regex_t re;	
  int result = regcomp( &re, regExp,  REG_EXTENDED|REG_NOSUB);
  if( result != 0 ) {
    fprintf( stderr, "Bad regular expresion \"%s\"\n", regExp );
    exit( -1 );
  }

  // recursive calls
  DIR * dir = opendir(dirA);
  struct dirent * ent;
  while ((ent = readdir(dir)) != NULL) {
    regmatch_t match;
    char *name = ent->d_name;
    unsigned char type = ent->d_type;
    if (regexec( &re, name, 1, &match, 0) == 0 
      && strcmp(name, ".")
      && strcmp(name, "..")) {
      //printf("name: %s\n", name);
      if (rest == NULL) {
        //printf("strlen 1\n");
        output[outputI] = (char *)calloc(strlen(name) + 1, sizeof(char));
        strcpy(output[outputI], name);
        outputI++;
        if(outputI == outputSize) {
            outputSize *= 2;
            output = (char **)recallocarray(output, outputSize, sizeof(char *), outputSize / 2);
        }
      } else if (type == DT_DIR) {
        int i = 0;
        //printf("strlen 2\n");
        char * newDir = (char *)calloc(strlen(dirA) + strlen(name) + 2, sizeof(char));
        strcpy(newDir, dirA);
        //printf("strlen 3\n");
        strcpy(newDir + strlen(dirA), name);
        //printf("strlen 4\n");
        newDir[strlen(dirA) + strlen(name)] = '/';
        char ** recOut = expandedPaths(newDir, rest);
        while(recOut[i]) {
          //printf("strlen 5\n");
          output[outputI] = (char *)calloc(strlen(recOut[i]) + strlen(name) + 2, sizeof(char));
          strcpy(output[outputI], name);
          //printf("strlen 6\n");
          output[outputI][strlen(name)] = '/';
          //printf("strlen 7\n");
          strcpy(output[outputI] + strlen(name) + 1, recOut[i]);
          free(recOut[i]);

          i++;
          outputI++;
          if(outputI == outputSize) {
            outputSize *= 2;
            output = (char **)recallocarray(output, outputSize, sizeof(char *), outputSize / 2);
          }
        }
        free(recOut);
        free(newDir);
      } 
    }
  }

  free(rest);
  free(regExp);
  return output;
}

char * tilExp(const char * input) {
  char * dir;
  if(*input == '~') {
    char * home = getenv("HOME");
    dir = (char *)calloc(strlen(home) + 1, sizeof(char));
    strcpy(dir, home);
  } else {
    dir = (char *)calloc(strlen(input) + 6, sizeof(char));
    strcpy(dir, "/home/");
    strcpy(dir + 6, input);
  }
  return dir;
}

char ** dirExp(const char * input) {
  char ** exp;
  char ** output;
  int len = 0;
  if (*input == '/') {
    exp = expandedPaths("/", input + 1);
    while(exp[len]) len++;
    output = (char **)calloc(len + 1, sizeof(char *));
    for(int i = 0; i < len; i++) {
      output[i] = (char *)calloc(strlen(exp[i]) + 2, sizeof(char));
      output[i][0] = '/';
      strcpy(output[i] + 1, exp[i]);
      free(exp[i]);
    }
    free(exp);
    return output;
  } else if (*input == '~') {
    // isolate the username
    char * home = (char *)calloc(strchr(input, '/') - input + 1, sizeof(char));
    strncpy(home, input, strchr(input, '/') - input);
    // get tilda expansion
    char * dir = tilExp(home);
    free(home);
    // adding slash to the end
    dir = (char *)realloc(dir, strlen(dir) + 1);
    dir[strlen(dir) + 1] = 0;
    dir[strlen(dir)] = '/';
    // get the rest of the argument
    char * rest = (char *)calloc(strchr(input, '/') - input, sizeof(char));
    strcpy(rest, strchr(input, '/') + 1);
    exp = expandedPaths(dir, rest);
    free(rest);
    // append and return
    while(exp[len]) len++;
    output = (char **)calloc(len + 1, sizeof(char *));
    for(int i = 0; i < len; i++) {
      //printf("length: %d\n", len);
      output[i] = (char *)calloc(strlen(exp[i]) + strlen(dir) + 1, sizeof(char));
      strcpy(output[i], dir);
      strcpy(output[i] + strlen(dir), exp[i]);
      free(exp[i]);
    }
    free(exp);
    free(dir);
    return output;
  } else return expandedPaths(".", input);
}

#if 0
main()
{
  yyparse();
}
#endif
