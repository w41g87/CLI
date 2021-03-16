/*
 * CS252: Shell project
 *
 * Template file.
 * You will need to add more code here to execute the command table.
 *
 * NOTE: You are responsible for fixing any bugs this code may have!
 *
 * DO NOT PUT THIS PROJECT IN A PUBLIC REPOSITORY LIKE GIT. IF YOU WANT 
 * TO MAKE IT PUBLICALLY AVAILABLE YOU NEED TO REMOVE ANY SKELETON CODE 
 * AND REWRITE YOUR PROJECT SO IT IMPLEMENTS FUNCTIONALITY DIFFERENT THAN
 * WHAT IS SPECIFIED IN THE HANDOUT. WE OFTEN REUSE PART OF THE PROJECTS FROM  
 * SEMESTER TO SEMESTER AND PUTTING YOUR CODE IN A PUBLIC REPOSITORY
 * MAY FACILITATE ACADEMIC DISHONESTY.
 */

#include <cstdio>
#include <cstdlib>
#include <wait.h>
#include <iostream>
#include <unistd.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <iostream>
#include <string.h>
#include <string>
#include <algorithm>
#include "command.hh"
#include "shell.hh"

using namespace std;

extern char ** environ;

void source(char * file);

Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
    _appendO = false;
    _appendE = false;
    _pid = 0;
}

void Command::insertSimpleCommand( SimpleCommand * simpleCommand ) {
    // add the simple command to the vector
    _simpleCommands.push_back(simpleCommand);
}

void Command::clear() {
    // deallocate all the simple commands in the command vector
    for (auto simpleCommand : _simpleCommands) {
        delete simpleCommand;
    }

    // remove all references to the simple commands we've deallocated
    // (basically just sets the size to 0)
    _simpleCommands.clear();

    if ( _outFile && _errFile != _outFile) {
        delete _outFile;
    }
    _outFile = NULL;

    if ( _inFile ) {
        delete _inFile;
    }
    _inFile = NULL;

    if ( _errFile ) {
        delete _errFile;
    }
    _errFile = NULL;

    _background = false;
    _appendO = false;
    _appendE = false;
    _pid = 0;
}

void Command::print() {
    printf("\n\n");
    printf("              COMMAND TABLE                \n");
    printf("\n");
    printf("  #   Simple Commands\n");
    printf("  --- ----------------------------------------------------------\n");

    int i = 0;
    // iterate over the simple commands and print them nicely
    for ( auto & simpleCommand : _simpleCommands ) {
        printf("  %-3d ", i++ );
        simpleCommand->print();
    }

    printf( "\n\n" );
    printf( "  Output       Input        Error        Background\n" );
    printf( "  ------------ ------------ ------------ ------------\n" );
    printf( "  %-12s %-12s %-12s %-12s\n",
            _outFile?_outFile->c_str():"default",
            _inFile?_inFile->c_str():"default",
            _errFile?_errFile->c_str():"default",
            _background?"YES":"NO");
    printf( "\n\n" );
}

void Command::execute() {
    // Don't do anything if there are no simple commands
    if ( _simpleCommands.size() == 0 ) {
        Shell::prompt();
        return;
    }
    // If exit is entered then exit shell

    int defaultin = dup( 0 );
	int defaultout = dup( 1 );
	int defaulterr = dup( 2 );
    int inF = 0;
    int outF = 0;
    int errF = 0;

    // Print contents of Command data structure
    //print();

    {    
        char * cmd = (char *) malloc(_simpleCommands.front()->_arguments.front()->length() + 1);
        int i = 0;
        *(cmd + _simpleCommands.front()->_arguments.front()->length()) = '\0';
        std::transform(_simpleCommands.front()->_arguments.front()->begin(), 
            _simpleCommands.front()->_arguments.front()->end(), 
            cmd, ::tolower);
        
        //printf("Lower case: %s\n", cmd);
        //printf("%s %d\n", cmd, strcmp(cmd, "exit"));
        if (!strcmp(cmd, "exit")) exit(0);
        
        if (!strcmp(cmd, "printenv")) {
            while(environ[i]) cout << environ[i++] << endl;
            clear();
            Shell::prompt();
            return;
        }

        char ** arg = _simpleCommands.front()->toString();
        while(arg[i++]);
        if (!strcmp(cmd, "setenv")) {
            if (i != 4) cout << "setenv: argument number mismatch." << endl;
            else if (setenv(arg[1], arg[2], 1) != 0) perror("setenv");
            clear();
            Shell::prompt();
            return;
        }
        if (!strcmp(cmd, "unsetenv")) {
            if (i != 3) cout << "unsetenv: argument number mismatch." << endl;
            else if (unsetenv(arg[1]) != 0) perror("unsetenv");
            clear();
            Shell::prompt();
            return;
        }
        if (!strcmp(cmd, "cd")) {
            printf("%d\n", i);
            if (i > 3) cout << "cd: too many arguments." << endl;
            else if (i == 2) chdir(getenv("HOME"));
            else if (chdir(arg[1]) != 0) perror("cd");
            clear();
            Shell::prompt();
            return;
        }
        if (!strcmp(cmd, "source")) {
            if (i != 3) cout << "source: argument number mismatch." << endl;
            else {
                clear();
                source(arg[1]);
            }
            clear();
            Shell::prompt();
            return;
        }
    }

    // Add execution here
    // For every simple command fork a new process
    // Setup i/o redirection
    // and call exec

    if (_errFile) {
        if (_appendE) errF = open(_errFile->c_str(), O_CREAT|O_WRONLY|O_APPEND, 0666);
        else errF = creat(_errFile->c_str(), 0666);
        dup2(errF, 2);
        close(errF);
    } else dup2(defaulterr, 2);
    if (errF < 0) {
        perror( "shell: Failed to create the error output file.");
		exit( 2 );
    }

    if (_inFile) {
        inF = open(_inFile->c_str(), O_RDONLY);
        dup2(inF, 0);
        close(inF);
    } else dup2(defaultin, 0);
    if (inF < 0) {
        perror( "shell: Failed to open the input file.");
		exit( 2 );
    }

    if (_outFile) {
        if (_appendO) outF = open(_outFile->c_str(), O_CREAT|O_WRONLY|O_APPEND, 0666);
        else outF = creat(_outFile->c_str(), 0666);
    } else
    if (outF < 0) {
        perror( "shell: Failed to create the output file.");
		exit( 2 );
    }

    unsigned int i = 0;

    int fdpipe[_simpleCommands.size()][2];

    for ( auto & simpleCommand : _simpleCommands ) {
        //printf("%d, %s", i, simpleCommand->_arguments.front()->c_str());

        if ( pipe(fdpipe[i]) == -1) {
            perror( "shell: pipe");
            exit( 2 );
        }

        if (++i > 1) {
            dup2(fdpipe[i - 2][0], 0);
            close(fdpipe[i - 2][0]);
        }
        if (i == _simpleCommands.size()) {
            if (_outFile) {
                dup2(outF, 1);
                close(outF);
            }
            else dup2(defaultout, 1);
        } else {
            dup2(fdpipe[i - 1][1], 1);
            close(fdpipe[i - 1][1]);
        }

        //printf("Forking...\n");
        _pid = fork();
        if ( _pid == -1 ) {
            perror( "shell: fork\n");
            exit( 2 );
        }

        if (_pid == 0) {
            //Child
            
            //close file descriptors that are not needed
            // close(fdpipe[0]);
            // close(fdpipe[1]);
            
            // printf("Params:\n");
            // for (unsigned int j = 0; j < simpleCommand->_arguments.size(); j++) {
            //    printf("%d: %s\n", j, *(simpleCommand->toString() + j));
            // }
            // You can use execvp() instead if the arguments are stored in an array
            execvp(simpleCommand->_arguments.front()->c_str(), simpleCommand->toString());

            // exec() is not suppose to return, something went wrong
            perror( "shell: Execution error");
            exit( 2 );
        }

    }
    //printf("pid: %d", _pid);
    if (!_background) waitpid( _pid, 0, 0 );
    //printf("terminated\n");
    dup2( defaultin , 0);
	dup2( defaultout , 1);
	dup2( defaulterr , 2);

	close( defaultin );
	close( defaultout );
	close( defaulterr );


    // Clear to prepare for next command
    clear();

    // Print new prompt
    Shell::prompt();
}

SimpleCommand * Command::_currentSimpleCommand;
