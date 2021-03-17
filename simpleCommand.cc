#include <cstdio>
#include <cstdlib>

#include <iostream>
#include <bits/stdc++.h>
#include "simpleCommand.hh"

SimpleCommand::SimpleCommand() {
  _arguments = std::vector<std::string *>();
}

SimpleCommand::~SimpleCommand() {
  // iterate over all the arguments and delete them
  for (auto & arg : _arguments) {
    delete arg;
  }
}

void SimpleCommand::insertArgument( std::string * argument ) {
  // simply add the argument to the vector
  _arguments.push_back(argument);
}

// Print out the simple command
void SimpleCommand::print() {
  for (auto & arg : _arguments) {
    std::cout << "\"" << *arg << "\" \t";
  }
  // effectively the same as printf("\n\n");
  std::cout << std::endl;
}

char ** SimpleCommand::toString() {
  char ** output = (char**)malloc(_arguments.size() + 1);
  //printf("argument size: %d\n", _arguments.size());
  // int i = 0;
  // for (auto & arg : _arguments) {
  //   //printf("arg length: %d\n", arg->length());
  //   //printf("%d %d %d", arg->c_str()[0], arg->c_str()[1], arg->c_str()[2]);
  //   output[i] = (char*)malloc(arg->length() + 1);
  //   strcpy(output[i], arg->c_str());
  //   output[i][arg->length()] = '\0';
  //   printf("%s | %s\n", arg->c_str(), *(output + i));
  //   i++;
  // }

  for (int i = 0; i < _arguments.size(); i++) {
    std::string * arg = _arguments[i];
    output[i] = (char*)malloc(arg->length() + 1);
    strcpy(output[i], arg->c_str());
    output[i][arg->length()] = '\0';
    //printf("%s | %s\n", arg->c_str(), output[i]);
  }
  //printf("i = %d\n", i);
  //printf("output[0] before null assignment: %s\n", output[0]);
  output[_arguments.size()] = NULL;
  //printf("output[0] after null assignment: %s\n", output[0]);
  //for (int i = 0; i <= _arguments.size(); i++) printf("output[%d]: %s\n", i, output[i]);
  return output;
}
