#include <wctype.h>
#include "atf.h"

#define a_acute 0x00e1
#define e_acute 0x00e9
#define i_acute 0x00ed
#define u_acute 0x00fa
#define A_acute 0x00c1
#define E_acute 0x00c9
#define I_acute 0x00cd
#define U_acute 0x00da
#define a_grave 0x00e0
#define e_grave 0x00e8
#define i_grave 0x00ec
#define u_grave 0x00f9
#define A_grave 0x00c0
#define E_grave 0x00c8
#define I_grave 0x00cc
#define U_grave 0x00d9
#define SUB_2   0x2082
#define SUB_3   0x2083

int accent_on_first_vowel = 1;
char vowel[128];

wchar_t
acute_of(wchar_t w)
{
  switch (w)
    {
    case 'a':
      return a_acute;
    case 'e':
      return e_acute;
    case 'i':
      return i_acute;
    case 'u':
      return u_acute;
    case 'A':
      return A_acute;
    case 'E':
      return E_acute;
    case 'I':
      return I_acute;
    case 'U':
      return U_acute;
    default:
      return w;
    }
}

wchar_t
grave_of(wchar_t w)
{
  switch (w)
    {
    case 'a':
      return a_grave;
    case 'e':
      return e_grave;
    case 'i':
      return i_grave;
    case 'u':
      return u_grave;
    case 'A':
      return A_grave;
    case 'E':
      return E_grave;
    case 'I':
      return I_grave;
    case 'U':
      return U_grave;
    default:
      return w;
    }
}

wchar_t
subdig_of(wchar_t w)
{
  switch (w)
    {
    case a_acute:
    case e_acute:
    case i_acute:
    case u_acute:
    case A_acute:
    case E_acute:
    case I_acute:
    case U_acute:
      return SUB_2;
    case a_grave:
    case e_grave:
    case i_grave:
    case u_grave:
    case A_grave:
    case E_grave:
    case I_grave:
    case U_grave:
      return SUB_3;
    }
  return w;
}

wchar_t
vowel_of(wchar_t w)
{
  switch (w)
    {
    case A_acute:
    case A_grave:
      return (wchar_t)'A';
    case E_acute:
    case E_grave:
      return (wchar_t)'E';
    case I_acute:
    case I_grave:
      return (wchar_t)'I';
    case U_acute:
    case U_grave:
      return (wchar_t)'U';
    case a_acute:
    case a_grave:
      return (wchar_t)'a';
    case e_acute:
    case e_grave:
      return (wchar_t)'e';
    case i_acute:
    case i_grave:
      return (wchar_t)'i';
    case u_acute:
    case u_grave:
      return (wchar_t)'u';
    }
  return w;
}

unsigned char *
accnum(const unsigned char *g)
{
  wchar_t *w;
  size_t len;
  int i;

  w = utf2wcs(g, &len);
  for (i = 0; i < len; ++i)
    {
      if (w[i] > 0x80)
	{
	  switch (w[i])
	    {
	    case a_acute:
	    case e_acute:
	    case i_acute:
	    case u_acute:
	    case A_acute:
	    case E_acute:
	    case I_acute:
	    case U_acute:
	    case a_grave:
	    case e_grave:
	    case i_grave:
	    case u_grave:
	    case A_grave:
	    case E_grave:
	    case I_grave:
	    case U_grave:
	      w[len++] = subdig_of(w[i]);
	      w[i] = vowel_of(w[i]);
	      w[len] = '\0';
	      return wcs2utf(w,len);
	    }
	}
    }
  return NULL;
}

unsigned char *
numacc(const unsigned char *g)
{
  wchar_t *w, accented, *vowptr;
  size_t len;
  
  if (!vowel['a'])
    vowel['a'] = vowel['A'] 
      = vowel['e'] = vowel['E'] 
      = vowel['i'] = vowel['I'] 
      = vowel['u'] = vowel['U'] = 1;

  w = utf2wcs(g, &len);
  if (accent_on_first_vowel)
    {
      vowptr = w;
      while (*vowptr && (*vowptr > 127 || !vowel[*vowptr]))
	++vowptr;
    }
  else
    {
      vowptr = w + len-1;
      while (vowptr > w && (*vowptr > 127 || !vowel[*vowptr]))
	--vowptr;
    }
  accented = (w[len-1] == SUB_2 ? acute_of(*vowptr) : grave_of(*vowptr));
  if (accented != *vowptr)
    {
      w[--len] = '\0';
      *vowptr = accented;
    }
  return wcs2utf(w,len);
}
