#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <xmlrpc-c/base.h>
#include "oraccnet.h"

static char sesh_template[L_tmpnam];

static const char *sesh_path = NULL;

char *
sesh_file(const char *basename)
{
  char *tmp = malloc(strlen(sesh_path) + strlen(basename) + 2);
  (void)sprintf(tmp, "%s/%s", sesh_path, basename);
  return tmp;
}

/* calling this routine is optional for methods--a method which
   returns immediately and does not require tmp files can do without */
char *
sesh_init(xmlrpc_env * const envP, xmlrpc_value * const s, int with_tmpdir)
{
  fprintf(stderr, "in sesh_init\n");
  trace();
  if (with_tmpdir)
    {
      char *tmpdir;
      trace();
      fprintf(stderr, "sesh: sesh_template=%s\n", sesh_template);
      tmpdir = (char*)mkdtemp(sesh_template);
      fprintf(stderr, "sesh: sesh_template=%s; tmpdir=%s\n", sesh_template, tmpdir);
      if (tmpdir)
	{
	  char *basename = tmpdir+strlen(tmpdir);
	  while (basename > tmpdir && '/' != basename[-1])
	    --basename;
	  fprintf(stderr, "sesh: tmpdir=%s; basename=%s\n", tmpdir, basename);
	  basename = strdup(basename);
	  tmpdir = strdup(tmpdir);
	  /* basename = (char*)strrchr(tmpdir, '/'); */
	  sesh_path = tmpdir;
	  if (basename)
	    {
	      trace();
	      fprintf(stderr, "sesh: template=%s; tmpdir=%s; basename=%s\n", sesh_template, tmpdir, basename);
	      /* ++basename; */
	      xmlrpc_struct_set_value(envP, s, "session", xmlrpc_string_new(envP, basename));
	      dieIfFaultOccurred(envP);
	      xmlrpc_struct_set_value(envP, s, "#tmpdir", xmlrpc_string_new(envP, tmpdir));
	      dieIfFaultOccurred(envP);
	      return basename;
	    }
	  else
	    {
	      fprintf(stderr, "oracc-xmlrpc: no / in session name %s\n", tmpdir);
	      /* not good enough */
	      exit(1);
	    }
	}
      else
	{
	  fprintf(stderr, "oracc-xmlrpc: failed to create tmpdir from template %s\n", sesh_template);
	  perror("oracc-xmlrpc");
	  /* not good enough */
	  exit(1);
	}
    }
  return NULL;
}

char *
sesh_set_path(struct call_info *cip)
{
  if (cip->session)
    {
      char *sp = malloc(strlen(varoracc) + strlen(cip->session) + 2);
      (void)sprintf(sp, "%s/%s", varoracc, cip->session);
      sesh_path = sp;
      return sp;
    }
  return NULL;
}

void
sesh_set_template(const char *template)
{
  strcpy(sesh_template, template);
}
