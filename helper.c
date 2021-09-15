#include <stdlib.h>
#include <string.h>

void * destroy(char** args) {
    int i = 0;
    while(args[i]) free(args[i++]);
    free(args);
    return NULL;
}

void * recallocarray(void * ptr, size_t nmemb, size_t size, size_t oldLen) {
  void * temp = calloc(nmemb, size);
  memcpy(temp, ptr, oldLen * size);
  free(ptr);
  return temp;
}
