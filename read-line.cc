/*
 * CS252: Systems Programming
 * Purdue University
 * Example that shows how to read one line with simple editing
 * using raw terminal.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <unistd.h>
#include "shell.hh"

#define MAX_BUFFER_LINE 2048

extern void tty_raw_mode(void);

// Buffer where line is stored
int line_length;
int cursor;
char line_buffer[MAX_BUFFER_LINE];

void del() {
  line_length--;

  // modify line buffer
  int i = cursor;
  while(line_buffer[i]) line_buffer[i++] = line_buffer[i + 1];

  if (line_length != cursor) write(1, line_buffer + cursor, line_length - cursor);
  // Write a space to erase the last character read
  char ch = ' ';
  write(1,&ch,1);

  ch = 8;
  for (i = line_length; i >= cursor; i--) write(1,&ch,1);
}

void home() {
  char ch = 8;
  while(cursor > 0) {
    write(1,&ch,1);
    cursor--;
  }
}

void end() {
  write(1, line_buffer + cursor, line_length - cursor);
  cursor = line_length;
}

void erase() {
  // Erase old line
  // Print backspaces
  int i = 0;
  for (i =0; i < cursor; i++) {
    ch = 8;
    write(1,&ch,1);
  }

  // Print spaces on top
  for (i =0; i < line_length; i++) {
    ch = ' ';
    write(1,&ch,1);
  }

  // Print backspaces
  for (i =0; i < line_length; i++) {
    ch = 8;
    write(1,&ch,1);
  }	
}

// Simple history array
// This history does not change. 
// Yours have to be updated.
int historyL = 0;
int historyS = 8;
char ** history = (char**)calloc(8, sizeof(char*));

void read_line_print_usage()
{
  char * usage = "\n"
    " ctrl-?       Print usage\n"
    " Backspace    Deletes last character\n"
    " up arrow     See last command in the history\n";

  write(1, usage, strlen(usage));
}

/* 
 * Input a line with some basic editing.
 */
char * read_line() {

  // Set terminal in raw mode
  tty_raw_mode();

  // variable init
  line_length = 0;
  cursor = 0;
  int historyI = historyL;

  // create a copy of history
  char ** historyLocal = (char**)calloc(historyL + 2, sizeof(char*));
  for (int i = 0; i < historyL; i++) {
    historyLocal[i] = (char*)calloc(MAX_BUFFER_LINE, sizeof(char));
    strcpy(historyLocal[i], history[i]);
  }

  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char ch;
    read(0, &ch, 1);
    //printf("key: %d\n", ch);
    if (ch>=32 && ch < 127) {
      // It is a printable character. 

      // Do echo
      write(1,&ch,1);

      // If max number of character reached return.
      if (line_length==MAX_BUFFER_LINE-2) break; 

      // add char to buffer.
      line_buffer[cursor]=ch;
      line_length++;
      cursor++;
    }
    else if (ch==10) {
      // <Enter> was typed. Return line
      destroy(historyLocal);
      // Print newline
      write(1,&ch,1);
      history[historyL] = (char*)calloc(strlen(line_buffer) + 1, sizeof(char));
      strcpy(history[historyL], line_buffer);
      historyL++;
      if (historyL == historyS) {
        historyS *= 2;
        history = (char **)recallocarray(history, historyS, sizeof(char*));
      }
      break;
    }
    else if (ch == 31) {
      // ctrl-?
      read_line_print_usage();
      line_buffer[0]=0;
      break;
    }
    else if ((ch == 127 || ch == 8) && cursor > 0) {
      // <backspace> was typed. Remove previous character read.
      // Remove one character from buffer
      ch = 8;
      write(1,&ch,1);
      line_length--;
      cursor--;

      //printf("cursor: %d\n", cursor);
      // modify line buffer
      int i = cursor;
      while(line_buffer[i]) line_buffer[i++] = line_buffer[i + 1];

      if (line_length != cursor) write(1, line_buffer + cursor, line_length - cursor);
      // Write a space to erase the last character read
      ch = ' ';
      write(1,&ch,1);

      ch = 8;
      for (i = line_length; i >= cursor; i--) write(1,&ch,1);

      // Go back one character
      // ch = 8;
      // write(1,&ch,1);

    } else if (ch == 4 && cursor < line_length) del();
    else if (ch == 1) home();
    else if (ch == 5) end();
    else if (ch==27) {
      // Escape sequence. Read two chars more
      //
      // HINT: Use the program "keyboard-example" to
      // see the ascii code for the different chars typed.
      //
      char ch1; 
      char ch2;
      read(0, &ch1, 1);
      read(0, &ch2, 1);
      if (ch1==91) {
        if (ch2 == 65 && historyI > 0) {
          // Up arrow. Print next line in history.
          erase();
          
          // Save line to history
          strcpy(historyLocal[historyI], line_buffer);

          // Copy line from history
          historyI--;
          strcpy(line_buffer, historyLocal[historyI]);
          line_length = strlen(line_buffer);
          cursor = line_length;

          // echo line
          write(1, line_buffer, line_length);
        }
        if (ch2 == 66 && historyI < historyL) {
          // Save line to history
          strcpy(historyLocal[historyI], line_buffer);

          // Copy line from history
          historyI++;
          strcpy(line_buffer, historyLocal[historyI]);
          line_length = strlen(line_buffer);
          cursor = line_length;
        }
        if (ch2 == 68 && cursor > 0) {
          ch = 8;
          write(1,&ch,1);
          cursor--;
        }
        if (ch2 == 67 && cursor < line_length) {
          write(1, line_buffer + cursor, 1);
          cursor++;
        }
        if (ch2 == 72) home();
        if (ch2 == 70) end();
      }
      if (ch1 == 91 && ch2 == 51) {
        char ch3;
        read(0, &ch3, 1);
        if (ch3 == 126 && cursor < line_length) del();
      }
      
    }

  }

  // Add eol and null char at the end of string
  line_buffer[line_length]=10;
  line_length++;
  line_buffer[line_length]=0;

  return line_buffer;
}

