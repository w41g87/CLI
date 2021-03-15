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
  int _pid;

  Command();
  void insertSimpleCommand( SimpleCommand * simpleCommand );

  void clear();
  void print();
  void execute();

  static SimpleCommand *_currentSimpleCommand;
};

struct YY_BUFFER_STATE {
  FILE * 	yy_input_file
  char * 	yy_ch_buf
  char * 	yy_buf_pos
  yy_size_t 	yy_buf_size
  int 	yy_n_chars
  int 	yy_is_our_buffer
  int 	yy_is_interactive
  int 	yy_at_bol
  int 	yy_fill_buffer
  int 	yy_buffer_status=
}

#endif
