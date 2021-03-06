#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xmlrpc-c/base.h>
#include <xmlrpc-c/server.h>
#include <xmlrpc-c/server_cgi.h>
#include "oraccnet.h"

static xmlrpc_value *
debug_method(xmlrpc_env *const envP,
	     xmlrpc_value *const paramArrayP, 
	     void *serverInfo,
	     void *callInfo
	     )
{
  const char *addr = getenv("REMOTE_ADDR");
  xmlrpc_value *s, *s_ret;
  struct call_info *cip;

  fprintf(stderr, "oracc-xmlrpc: debug: REMOTE_ADDR=%s\n", addr);
  xmlrpc_array_read_item(envP, paramArrayP, 0, &s);
  sesh_init(envP, s, 1);

#if 1
  cip = callinfo_unpack(envP, s);
  file_save(cip, "@@ORACC@@/varoracc");
#else
  /* Simple methods can manipulate the RPC struct directly and just ship it back */
  xmlrpc_struct_set_value(envP, s, "clientIP", xmlrpc_string_new(envP, addr));
#endif

  cip->files = NULL;
  cip->methodargs = NULL;
  cip->clientIP = strdup(addr);
  s_ret = callinfo_pack(envP, cip);
  
  return s_ret;
}

struct xmlrpc_method_info3 debug_server_info =
{
  "debug",
  debug_method,
  NULL,
  0,
  "s:",
  "return the value of call_info structure with clientIP added to it from the environment",
};
