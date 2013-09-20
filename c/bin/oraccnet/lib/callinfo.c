#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <xmlrpc-c/base.h>
#include "oraccnet.h"

static void unpack(xmlrpc_env *envP, xmlrpc_value *s, const char *mem, char **valp);

struct call_info *
callinfo_new(void)
{
  return calloc(1, sizeof(struct call_info));
}

#define nonull(ptr)  (ptr?ptr:"")


/* Pack the information from any client method into a generic xmlrpc
   struct to send to the server */
xmlrpc_value *
callinfo_pack(xmlrpc_env *envP, struct call_info *cip)
{
  xmlrpc_value *s = xmlrpc_struct_new(envP);
  xmlrpc_value *methargs = xmlrpc_array_new(envP);
  xmlrpc_value *files = xmlrpc_array_new(envP);
  int i;

  xmlrpc_struct_set_value(envP, s, "clientIP", xmlrpc_string_new(envP, nonull(cip->clientIP)));
  xmlrpc_struct_set_value(envP, s, "serverURL", xmlrpc_string_new(envP, nonull(cip->serverURL)));
  xmlrpc_struct_set_value(envP, s, "session", xmlrpc_string_new(envP, nonull(cip->session)));
  xmlrpc_struct_set_value(envP, s, "method", xmlrpc_string_new(envP, nonull(cip->method)));
  xmlrpc_struct_set_value(envP, s, "user", xmlrpc_string_new(envP, nonull(cip->user)));
  xmlrpc_struct_set_value(envP, s, "password", xmlrpc_string_new(envP, nonull(cip->password)));
  xmlrpc_struct_set_value(envP, s, "project", xmlrpc_string_new(envP, nonull(cip->project)));
  xmlrpc_struct_set_value(envP, s, "version", xmlrpc_string_new(envP, nonull(cip->version)));

  trace();

  if (cip->methodargs)
    {
      for (i = 0; cip->methodargs[i]; ++i)
	{
	  if (!strncmp(cip->methodargs[i], "file:", 5))
	    {
	      char *file_what, *file_name;
	      
	      file_what = strdup(&cip->methodargs[i][5]);
	      file_name = strchr(file_what, '=');
	      if (file_name)
		{
		  xmlrpc_value * fstruct;
		  *file_name++ = '\0';
		  fstruct = file_pack(envP, file_what, file_name);
		  xmlrpc_array_append_item(envP, files, fstruct);
		}
	      else
		{
		  fprintf(stderr, "oracc-client: bad -Mfile arg, expected -Mfile:WHAT=NAME\n");
		  exit(1);
		}
	    }
	  else
	    xmlrpc_array_append_item(envP, methargs, xmlrpc_string_new(envP, cip->methodargs[i]));
	}
    }

  trace();

  xmlrpc_struct_set_value(envP, s, "method-args", methargs);
  xmlrpc_struct_set_value(envP, s, "method-data", files);

  trace();

  return s;
}

/* Unpack caller's information on the server, 
   or server's information returned to the client */
struct call_info *
callinfo_unpack(xmlrpc_env *envP, xmlrpc_value *s)
{
  struct call_info *cip = callinfo_new();
  xmlrpc_value *methargs, *files;
  int i;

  unpack(envP, s, "clientIP", (char **)&cip->clientIP);
  unpack(envP, s, "serverURL", &cip->serverURL);
  unpack(envP, s, "session", &cip->session);
  unpack(envP, s, "method", &cip->method);
  unpack(envP, s, "user", &cip->user);
  unpack(envP, s, "password", &cip->password);
  unpack(envP, s, "project", &cip->project);
  unpack(envP, s, "version", &cip->version);
  xmlrpc_struct_find_value(envP, s, "method-args", &methargs);
  if (methargs)
    {
      cip->nargs = xmlrpc_array_size(envP, methargs);
      cip->methodargs = malloc((cip->nargs +1) * sizeof(char *));
      for (i = 0; i < cip->nargs; ++i)
	{
	  xmlrpc_value *v;
	  xmlrpc_array_read_item(envP, methargs, i, &v);
	  xmlrpc_read_string(envP, v, (const char **const)(&cip->methodargs[i]));
	}
      cip->methodargs[cip->nargs] = NULL;
    }
  
  xmlrpc_struct_find_value(envP, s, "method-data", &files);
  if (files)
    {
      for (i = 0; i < xmlrpc_array_size(envP, files); ++i)
	{
	  struct file_data *this_file;
	  xmlrpc_value * fstruct;
	  xmlrpc_array_read_item(envP, files, i, &fstruct);
	  this_file = file_unpack(envP, fstruct);
	  if (cip->files == NULL)
	    {
	      cip->files = this_file;
	      cip->files_last = cip->files->next;
	    }
	  else
	    {
	      cip->files_last->next = this_file;
	      cip->files_last = cip->files->next;
	    }
	}
    }

  return cip;
}

static void
unpack(xmlrpc_env *envP, xmlrpc_value *s, const char *mem, char **valp)
{
  xmlrpc_value *val;

  xmlrpc_struct_find_value(envP, s, mem, &val);
  if (val)
    xmlrpc_read_string(envP, val, (const char **const)valp);
}
