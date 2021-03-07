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
    std::cout << "\"" << arg << "\" \t";
  }
  // effectively the same as printf("\n\n");
  std::cout << std::endl;
}

char ** SimpleCommand::toString() {
  char ** output = (char**)malloc(_arguments.size());
  int i = 0;
  for (auto & arg : _arguments) {
    *(output + i) = (char*)malloc(arg->length() + 1);
    strcpy(*(output + i), arg->c_str());
  }
  return output;
}