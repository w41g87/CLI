#ifndef command_hh
#define command_hh

#include "simpleCommand.hh"

// Command Data Structure

struct Command {
  std::vector<SimpleCommand *> _simpleCommands;
  std::string * _outFile;
  std::string * _inFile;
  std::string * _errFile;
  bool _background;
  bool _appendO;
  bool _appendE;
  bool _init;
  int _pid;
  int _bgpid;

  Command();
  void insertSimpleCommand( SimpleCommand * simpleCommand );
  void embedDest(char**);
  void clear();
  void print();
  void execute();

  static SimpleCommand *_currentSimpleCommand;
};

#endif
