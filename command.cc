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
#include "command.hh"
#include "shell.hh"


int yyparse(void);

Command::Command() {
    // Initialize a new vector of Simple Commands
    _simpleCommands = std::vector<SimpleCommand *>();

    _outFile = NULL;
    _inFile = NULL;
    _errFile = NULL;
    _background = false;
    _appendO = false;
    _appendE = false;
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

    if ( _outFile ) {
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

    int defaultin = dup( 0 );
	int defaultout = dup( 1 );
	int defaulterr = dup( 2 );
    int inF, outF, errF;

    // Print contents of Command data structure
    print();

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
    close(defaulterr);
    if (errF < 0) {
        perror( "shell: Failed to create the error output file.");
		exit( 2 );
    }

    if (_inFile) {
        inF = open(_inFile->c_str(), O_RDONLY);
        dup2(inF, 0);
        close(inF);
    } else dup2(defaultin, 0);
    close(defaultin);
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
    int fdpipe[2];
    int pid;
    if ( pipe(fdpipe) == -1) {
		perror( "shell: pipe");
		exit( 2 );
	}

    for ( auto & simpleCommand : _simpleCommands ) {
        if (++i > 1) dup2(fdpipe[0], 0);
        if (i == _simpleCommands.size()) {
            if (_outFile) {
                dup2(outF, 1);
                close(outF);
            }
            else dup2(defaultout, 1);
            close(defaultout);
        } else dup2(fdpipe[1], 1);


        pid = fork();
        if ( pid == -1 ) {
            perror( "shell: fork\n");
            exit( 2 );
        }

        if (pid == 0) {
            //Child
            
            // close file descriptors that are not needed
            close(fdpipe[0]);
            close(fdpipe[1]);
            
            close(outF);
            // You can use execvp() instead if the arguments are stored in an array
            execvp(simpleCommand->_arguments.front()->c_str(), simpleCommand::toString());

            // exec() is not suppose to return, something went wrong
            perror( "shell: exec cat");
            exit( 2 );
        }

    }

    if (!_background) waitpid( pid, 0, 0 );

    // Clear to prepare for next command
    clear();

    // Print new prompt
    Shell::prompt();
    yyparse();
}

SimpleCommand * Command::_currentSimpleCommand;
