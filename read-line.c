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
#include <termios.h>
#include <stdbool.h>

#define MAX_BUFFER_LINE 2048

extern struct termios tty_raw_mode(void);
void * destroy(char **);
void * recallocarray(void *, size_t, size_t, size_t);
char ** expPath(const char *, int);
void prompt();

// Buffer where line is stored
int line_length;
int cursor;
char line_buffer[MAX_BUFFER_LINE];

// Simple history array
// This history does not change. 
// Yours have to be updated.
int tabbed = false;
int historyI = 0;
int historyL = 0;
int historyS = 8;
char ** history;

void resetLine() {
  line_length = 0;
  cursor = 0;
  tabbed = false;
  memset(line_buffer, 0, MAX_BUFFER_LINE);
  historyI = historyL;
}

void del() {
  if (cursor >= line_length) return;

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
  if (cursor <= 0) return;

  char ch = 8;
  while(cursor > 0) {
    write(1,&ch,1);
    cursor--;
  }
}

void end() {
  if (cursor >= line_length) return;

  write(1, line_buffer + cursor, line_length - cursor);
  cursor = line_length;
}

void input(char ch) {
  char ws = ' ';
  char bs = 8;

  // add char to buffer.
  for (int i = line_length; i > cursor; i--) {
    write(1,&ws,1);
    line_buffer[i] = line_buffer[i - 1];
  }
  line_buffer[cursor]=ch;
  for (int i = line_length; i > cursor; i--) write(1,&bs,1);

  line_length++;
  write(1, line_buffer + cursor, line_length - cursor);
  cursor++;
  for (int i = line_length; i > cursor; i--) write(1,&bs,1);

}

void erase() {
  // Erase old line
  // Print backspaces
  char ch;
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


void read_line_print_usage()
{
  char * usage = "\n"
    " ctrl-?                Print usage\n"
    " ctrl-H / Backspace    Deletes last character\n"
    " ctrl-D / del          Deletes current character\n"
    " up arrow              See last command in the history\n"
    " down arrow            See next command in the history\n"
    " left arrow            Navigate backward\n"
    " right arrow           Navigate forward\n"
    " ctrl-A / Home         Jump to line beginning"
    " ctrl-E / End          Jump to line end";

  write(1, usage, strlen(usage));
}

/* 
 * Input a line with some basic editing.
 */
char * read_line() {

  // Set terminal in raw mode
  struct termios tty_old = tty_raw_mode();

  // variable init
  resetLine();

  // Extra functionality: creates a copy of history so that before 
  // each execution, all local modifications to the history is retained
  char ** historyLocal = (char**)calloc(historyL + 2, sizeof(char*));
  for (int i = 0; i < historyL; i++) {
    historyLocal[i] = (char*)calloc(MAX_BUFFER_LINE, sizeof(char));
    strcpy(historyLocal[i], history[i]);
  }
  historyLocal[historyL] = (char*)calloc(MAX_BUFFER_LINE, sizeof(char));

  // Read one line until enter is typed
  while (1) {

    // Read one character in raw mode.
    char ch;
    read(0, &ch, 1);
    //printf("key: %d\n", ch);
    if (ch>=32 && ch < 127) {
      // If max number of character reached return.
      if (line_length==MAX_BUFFER_LINE-2) break; 
      tabbed = false;
      input(ch);

    } else if (ch==10) {
      // <Enter> was typed. Return line
      destroy(historyLocal);
      // Print newline
      history[historyL] = (char*)calloc(strlen(line_buffer) + 1, sizeof(char));
      
      strcpy(history[historyL], line_buffer);
      historyL++;
      if (historyL == historyS) {
        historyS *= 2;
        history = (char **)recallocarray(history, historyS, sizeof(char*), historyS / 2);
      }
      write(1,&ch,1);
      break;
    }
    else if (ch == 31) {
      // ctrl-?
      read_line_print_usage();
      line_buffer[0]=0;
      break;
    }
    else if ((ch == 127 || ch == 8)) {
      tabbed = false;
      if (cursor <= 0) continue;
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

    } else if (ch == 4) {
      tabbed = false;
      del();
    } else if (ch == 1) {
      tabbed = false;
      home();
    } else if (ch == 5) {
      tabbed = false;
      end();
    } else if (ch == 9) {
      // tab
      bool hasPrint = false;
      char * slash;
      char * dir;
      char * lstArg;
      //char ch;
      char ** expanded;
      int chI = 0;
      int len = 0;

      // goto EOL
      end();

      // get the starting point of the last argument
      lstArg = strrchr(line_buffer, ' ') ? strrchr(line_buffer, ' ') + 1 : line_buffer;

      // get the starting point of the name to expand
      slash = strrchr(lstArg, '/') ? strrchr(lstArg, '/') + 1 : lstArg;

      // get how many letters has already been entered
      chI = strlen(slash);

      // construct a wildcard using the last argument
      dir = (char *)calloc(strlen(lstArg) + 2, sizeof(char));
      strcpy(dir, lstArg);
      dir[strlen(lstArg)] = '*';

      // get the expanded leaf nodes
      expanded = expPath(dir, 1);
      free(dir);
      
      // obtain array length
      while(expanded[len++]);
      
      // there is no choice, dont do anything
      if (--len == 0) {
        destroy(expanded);
        continue;
      }

      // there is only one choice, expand and go to the next argument
      if (len == 1) {
        while(expanded[0][chI]) input(expanded[0][chI++]);
        input(' ');
        destroy(expanded);
        tabbed = false;
        continue;
      }

      // more than one choice
      while (1) {
        int i;
        // check if they have mutual header characters
        for (i = 1; i < len; i++) if (expanded[i][chI] != expanded[0][chI]) break;
        
        if (i == len) {
          // if yes, then write the char and move to the next char
          hasPrint = true;
          tabbed = false;
          input(expanded[0][chI]);
        } else break;
        chI++;
      }

      if (!hasPrint) {
        // if nothing is being printed, then the expansion is finished
        if (tabbed) {
          // if user has pressd tab before, print all options
          printf("\n");
          printf("%s", expanded[0]);
          for (int i = 1; i < len; i++) {
            printf("\t%s", expanded[i]);
          }
          printf("\n");
          prompt();
          write(1, line_buffer, line_length);
        }
        // either way, reverse the truth value of tabbed
        tabbed = !tabbed;
      }
      
      destroy(expanded);
    }
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
        tabbed = false;
        if (ch2 == 65 && historyI > 0) {
          // Up arrow. Print last line in history.
          erase();


          //printf("line: %d\n", line_buffer[0]);
          // Save line to history
          //if (strchr(historyLocal[historyI], 10)) printf("Weird 10 char\n");
          strcpy(historyLocal[historyI], line_buffer);

          // Copy line from history
          historyI--;
          strcpy(line_buffer, historyLocal[historyI]);
          line_length = strlen(line_buffer);
          cursor = line_length;
          //printf ("line length: %d %d\n", line_length, line_buffer[line_length - 1]);
          // echo line
          write(1, line_buffer, line_length);
        }
        if (ch2 == 66 && historyI < historyL) {
          // Down arrow. Print next line in history.
          //printf("line: %d\n", historyLocal[historyI + 1][0]);
          erase();

          // Save line to history
          strcpy(historyLocal[historyI], line_buffer);

          // Copy line from history
          historyI++;
          if (*historyLocal[historyI] == 0) *line_buffer = 0;
          else strcpy(line_buffer, historyLocal[historyI]);
          line_length = strlen(line_buffer);
          cursor = line_length;
          //printf ("line length: %d %d\n", line_length, line_buffer[line_length - 1]);
          // echo line
          write(1, line_buffer, line_length);
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
  tcsetattr(0,TCSANOW,&tty_old);
  return line_buffer;
}

