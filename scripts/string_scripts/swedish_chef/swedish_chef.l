%{
/* chef.x - convert English on stdin to Mock Swedish on stdout
 *
 * The WC definition matches any word character, and the NW definition matches
 * any non-word character.  Two start conditions are maintained: INW (in word)
 * and NIW (not in word).  The first rule passes TeX commands without change.
 *
 * HISTORY
 *
 * Mar 7, 2014: Dave Goldman: Preserve "href" unchanged.
 *
 * Apr 23, 2013: Dave Goldman: Add "Done" -> "Börk Börk Börk!"
 *
 * Apr 26, 1993; John Hagerman: Added ! and ? to the Bork Bork Bork rule.
 *
 * Apr 15, 1992; John Hagerman: Created.
 */

static int i_seen = 0;
%}

WC		[A-Za-z']
NW		[^A-Za-z']

%start		INW NIW

%%

\\[^ \n]+	ECHO;

{NW}		{ BEGIN NIW; i_seen = 0; ECHO; }
[.!?]$		{ BEGIN NIW; i_seen = 0;
		  printf("%c\nBork Bork Bork!",yytext[0]); }

<NIW>"bork"/{NW} ECHO;
<NIW>"Bork"/{NW} ECHO;

"href"      { BEGIN INW; printf("href"); }
"Done"      { BEGIN INW; printf("Börk Börk Börk!"); }
"an"		{ BEGIN INW; printf("un"); }
"An"		{ BEGIN INW; printf("Un"); }
"au"		{ BEGIN INW; printf("oo"); }
"Au"		{ BEGIN INW; printf("Oo"); }
"a"/{WC}	{ BEGIN INW; printf("e"); }
"A"/{WC}	{ BEGIN INW; printf("E"); }
"en"/{NW}	{ BEGIN INW; printf("ee"); }
<INW>"ew"	{ BEGIN INW; printf("oo"); }
<INW>"e"/{NW}	{ BEGIN INW; printf("e-a"); }
<NIW>"e"	{ BEGIN INW; printf("i"); }
<NIW>"E"	{ BEGIN INW; printf("I"); }
<INW>"f"	{ BEGIN INW; printf("ff"); }
<INW>"ir"	{ BEGIN INW; printf("ur"); }
<INW>"i"	{ BEGIN INW; printf(i_seen++ ? "i" : "ee"); }
<INW>"ow"	{ BEGIN INW; printf("oo"); }
<NIW>"o"	{ BEGIN INW; printf("oo"); }
<NIW>"O"	{ BEGIN INW; printf("Oo"); }
<INW>"o"	{ BEGIN INW; printf("u"); }
"the"		{ BEGIN INW; printf("zee"); }
"The"		{ BEGIN INW; printf("Zee"); }
"th"/{NW}	{ BEGIN INW; printf("t"); }
<INW>"tion"	{ BEGIN INW; printf("shun"); }
<INW>"u"	{ BEGIN INW; printf("oo"); }
<INW>"U"	{ BEGIN INW; printf("Oo"); }
"v"		{ BEGIN INW; printf("f"); }
"V"		{ BEGIN INW; printf("F"); }
"w"		{ BEGIN INW; printf("v"); }
"W"		{ BEGIN INW; printf("V"); }

.		{ BEGIN INW; ECHO; }
