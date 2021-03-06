
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
#include <math.h>
#include <unistd.h>
#include <sys/wait.h> 
#include <sys/types.h>
#include "shell.hh"

char * tilExp(const char *);

char ** dirExp(const char *, int);

std::string * envExp(std::string*);

void yyerror(const char * s);
int yylex();
void inplaceMerge(char**, size_t);

extern "C" void * recallocarray(void *, size_t, size_t, size_t);

%}

%%

goal:
  commandline
  | goal commandline
  ;


commandline:
  commands bgmodifier NEWLINE {
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
  command_word argument_list io {
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
    std::string * env = envExp($1);
    if (env->find('?') != std::string::npos || env->find('*') != std::string::npos) {
      char ** exp = dirExp(env->c_str(), 0);
      
      // iterate through the array and put everything into arguement
      int i = 0;
      while(exp[i++]);
      if (i == 1) {
        Command::_currentSimpleCommand->insertArgument( env );
      } else {
        delete env;
        //printf("i: %d\n", i);
        inplaceMerge(exp, i - 1);
        i = 0;
        while(exp[i]) {
          Command::_currentSimpleCommand->insertArgument( new std::string(exp[i]) );
          free(exp[i]);
          i++;
        }
      }
      free(exp);
    } else if (env->c_str()[0] == '~') {
      if (env->find('/') != std::string::npos) {
        char * home = tilExp(env->substr(0, env->find('/')).c_str());
        std::string * newArg = new std::string();
        newArg->append(home);
        free(home);
        newArg->append(env->substr(env->find('/')));
        delete env;
        Command::_currentSimpleCommand->insertArgument( newArg );
      } else {
        char * home = tilExp(env->substr(0).c_str());
        delete env;
        Command::_currentSimpleCommand->insertArgument( new std::string(home) );
        free(home);
      }
    } else {
      Command::_currentSimpleCommand->insertArgument( env );
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

io:
  io iomodifiers
  |
  ;

iomodifiers:
  LESS WORD {
    //printf("   Yacc: insert input \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._inFile) {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
    }
    Shell::_currentCommand._inFile = $2;
  }
  | GREAT WORD {
    //printf("   Yacc: insert output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile) {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
    }
    Shell::_currentCommand._outFile = $2;
  }
  | GCONT WORD {
    //printf("   Yacc: insert background output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile || Shell::_currentCommand._errFile) {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
  }
  | GGREAT WORD {
    //printf("   Yacc: insert append output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile) {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._appendO = true;
  }
  | GGCONT WORD {
    //printf("   Yacc: insert append background output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._outFile || Shell::_currentCommand._errFile) {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
    }
    Shell::_currentCommand._outFile = $2;
    Shell::_currentCommand._errFile = $2;
    Shell::_currentCommand._appendO = true;
    Shell::_currentCommand._appendE = true;
  }
  | GREAT2 WORD {
    //printf("   Yacc: insert error output \"%s\"\n", $2->c_str());
    if (Shell::_currentCommand._errFile) {
      printf("Ambiguous output redirect.\n");
      Shell::_currentCommand.clear();
    }
    Shell::_currentCommand._errFile = $2;
  }
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

// inplace Mergesort for string
void inplaceMerge(char ** ptr, size_t len) {
  // if only 1 string to sort, dont bother
  if (len < 2) return;

  // comparing between two strings
  if (len == 2) {
    int i = 0;
    // iterate until the first character mismatch
    while(ptr[0][i] == ptr[1][i]) i++;
    // if their place is reversed, switch back
    if (ptr[0][i] > ptr[1][i]) {
      char* temp = ptr[0];
      ptr[0] = ptr[1];
      ptr[1] = temp;
    }
    return;
  }

  // ptr1 and ptr2 point to the head of their respective sorted subarrays
  char ** ptr1 = ptr;
  char ** ptr2 = ptr + (len / 2);
  inplaceMerge(ptr1, len / 2);
  inplaceMerge(ptr2, (int)ceil((float)len / 2));
  // if ptr1 reaches ptr2 (array 1 is empty) or
  // ptr2 reaches the end (array 2 is empty)
  // the entire array is then sorted.
  while(ptr1 != ptr2 && ptr2 != ptr + len) {
    int i = 0;
    // since all entries are unique, we dont have to worry about SEGEV here
    while((*ptr1)[i] == (*ptr2)[i]) i++;
    // if the first element is smaller, simply increment
    if ((*ptr1)[i] < (*ptr2)[i]) ptr1++;
    // if the second is smaller, shift the array right and
    // insert it at the first pointer location
    else {
      char * temp = *ptr2;
      for (i = 0; i < ptr2 - ptr1; i++) *(ptr2 - i) = *(ptr2 - i - 1);
      *ptr1 = temp;
      ptr1++;
      ptr2++;
    }
  }
  return;
}

// wildcard to regex
char * w2r (char * input) {
  std::string reg = std::string();
  reg.push_back('^');
  switch(*input) {
    case '*':
    // "non-blank character" my ass
      reg.append("([^\\.].*|\"\")");
      break;
    case '?':
      reg.append("[^\\.]");
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
        reg.append(".*");
        break;
      case '?':
        reg.append(".");
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

// environment variable expansion for specific input
char * mallocEnvExp(const char * input) {
  char * env;
  if (!strcmp(input, "$")) {
    pid_t pid = getpid();
    int lengthD = pid == 0 ? 1 : (int)floor(log10(abs(pid))) + 1;
    char * output = (char*)calloc(lengthD + 1, sizeof(char));
    sprintf(output, "%d", pid);
    return output;
  }
  if (!strcmp(input, "?")) {
    int lengthD = Shell::lstRtn == 0 ? 1 : (int)floor(log10(abs(Shell::lstRtn))) + 1;
    char * output = (char*)calloc(lengthD + 1, sizeof(char));
    sprintf(output, "%d", Shell::lstRtn);
    return output;
  }
  if (!strcmp(input, "!")) {
    int lengthD = Shell::lstPid == 0 ? 1 : (int)floor(log10(abs(Shell::lstPid))) + 1;
    char * output = (char*)calloc(lengthD + 1, sizeof(char));
    sprintf(output, "%d", Shell::lstPid);
    return output;
  }
  if (!strcmp(input, "_")) {
    if (Shell::lstArg != NULL) {
      char * output = (char*)calloc(strlen(Shell::lstArg) + 1, sizeof(char));
      strcpy(output, Shell::lstArg);
      return output;
    } else return (char*)calloc(1, sizeof(char));
  }
  if (!strcmp(input, "SHELL")) {
    return realpath(Shell::argv, NULL);
  }
  if ((env = getenv(input)) != NULL) {
    char * output = (char*)calloc(strlen(env) + 1, sizeof(char));
    strcpy(output, env);
    return output;
  } else return (char *)calloc(1, sizeof(char));
}

// environment variable expansion within arbitrary string
std::string * envExp(std::string* input) {
  int a = input->find('$');
  int b = input->find('{');
  int c = input->find('}');
  if ((a != std::string::npos) && (b == a + 1) && (c > b)) {
      char * exp = mallocEnvExp(input->substr(b + 1, c - b - 1).c_str());
      input->erase(a, c - a + 1);
      input->insert(a, exp);
      free(exp);
      return envExp(input);
  } else return input;
}

// takes a directory and wildcard arg and recursively expands all subdir
char ** expandedPaths(const char * dirA, const char * arg, int mode) {
  char ** output = (char **)calloc(8, sizeof(char*));
  int outputI = 0;
  int outputSize = 8;
  char * currentDir;
  char * rest = NULL;

  // extract the wildcard to expand in the current dir
  if (!strchr(arg, '/')) {
    // terminating case
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
  free(currentDir);
  currentDir = NULL;

  // regex init
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
    if (regexec( &re, name, 1, &match, 0) == 0) {
      if (rest == NULL) {
        // terminating case
        if (mode == 1 && type == DT_DIR) {
          output[outputI] = (char *)calloc(strlen(name) + 2, sizeof(char));
          strcpy(output[outputI], name);
          output[outputI][strlen(name)] = '/';
        } else {
          output[outputI] = (char *)calloc(strlen(name) + 1, sizeof(char));
          strcpy(output[outputI], name);
        }
        outputI++;
        // dynamically sized array
        if(outputI == outputSize) {
            outputSize *= 2;
            output = (char **)recallocarray(output, outputSize, sizeof(char *), outputSize / 2);
        }
      } else if (type == DT_DIR
        && strcmp(name, ".")
        && strcmp(name, "..")) {
        // recursive case
        int i = 0;
        // construct a new dir to recurse on
        char * newDir = (char *)calloc(strlen(dirA) + strlen(name) + 2, sizeof(char));
        strcpy(newDir, dirA);
        strcpy(newDir + strlen(dirA), name);
        newDir[strlen(dirA) + strlen(name)] = '/';
        // recursively acquire the expansion under new dir
        char ** recOut = expandedPaths(newDir, rest, mode);

        while(recOut[i]) {
          switch (mode) {
            case 0:
              // append output to new dir and return
              output[outputI] = (char *)calloc(strlen(recOut[i]) + strlen(name) + 2, sizeof(char));
              strcpy(output[outputI], name);
              output[outputI][strlen(name)] = '/';
              strcpy(output[outputI] + strlen(name) + 1, recOut[i]);
              break;
            case 1:
              // only return the leaf nodes
              output[outputI] = (char *)calloc(strlen(recOut[i]) + 1, sizeof(char));
              strcpy(output[outputI], recOut[i]);
          }
          free(recOut[i]);

          i++;
          outputI++;
          // dynamically sized array
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
  regfree(&re);
  closedir(dir);
  free(rest);
  free(regExp);
  return output;
}

// tilda expansion
char * tilExp(const char * input) {
  char * dir;
  if(!strcmp(input, "~")) {
    char * home = getenv("HOME");
    dir = (char *)calloc(strlen(home) + 1, sizeof(char));
    strcpy(dir, home);
  } else {
    dir = (char *)calloc(strlen(input) + 7, sizeof(char));
    strcpy(dir, "/homes/");
    strcpy(dir + 7, input + 1);
  }
  return dir;
}

// takes dir with wildcard and tilda and expands it
// mode: 0-full expansion 1-leaf expansion
char ** dirExp(const char * input, int mode) {
  char ** exp;
  char ** output;
  int len = 0;

  if (*input == '/') {
    // starting from root dir
    exp = expandedPaths("/", input + 1, mode);
    if (mode == 1) return exp;
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
    // expand home first

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

    // acquire expanded result
    exp = expandedPaths(dir, rest, mode);
    free(rest);
    
    if (mode == 1) {
      // only leaf nodes required
      free(dir);
      return exp;
    }
    // full expansion: append and return
    while(exp[len]) len++;
    output = (char **)calloc(len + 1, sizeof(char *));
    for(int i = 0; i < len; i++) {
      output[i] = (char *)calloc(strlen(exp[i]) + strlen(dir) + 1, sizeof(char));
      strcpy(output[i], dir);
      strcpy(output[i] + strlen(dir), exp[i]);
      free(exp[i]);
    }
    free(exp);
    free(dir);
    return output;
  } else return expandedPaths(".", input, mode);
}

// dir expansion for read-line.c
extern "C" char ** expPath(const char * input, int mode) {
  return dirExp(input, mode);
}

#if 0
main()
{
  yyparse();
}
#endif
