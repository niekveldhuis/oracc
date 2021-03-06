#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <xmlrpc-c/base.h>
#include <xmlrpc-c/client.h>
#include "oraccnet.h"

int trace;
#undef dieIfFaultOccurred

void 
dieIfFaultOccurred (xmlrpc_env * const envP)
{
  if (envP->fault_occurred)
    {
      fprintf(stderr, "ERROR: %s (%d)\n",
	      envP->fault_string, envP->fault_code);
      exit(1);
  }
}

void 
dieIfFaultOccurred3 (xmlrpc_env * const envP, const char *f, int i)
{
  if (envP->fault_occurred)
    {
      fprintf(stderr, "ERROR at %s:%d: %s (%d)\n",
	      f, i, envP->fault_string, envP->fault_code);
    exit(1);
  }
}
