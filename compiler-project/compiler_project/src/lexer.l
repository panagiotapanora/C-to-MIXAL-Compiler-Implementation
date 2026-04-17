%{
#include "parser.tab.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

int line_num = 1;
void yyerror(const char *s);
%}

%option noyywrap

digit   [0-9]
letter  [a-zA-Z]

%%

"int"       { return INT; }
"return"    { return RETURN; }
"if"        { return IF; }
"else"      { return ELSE; }
"while"     { return WHILE; }
"break"     { return BREAK; }
"true"      { return TRUE; }
"false"     { return FALSE; }

"<="        { return LE; }
">="        { return GE; }
"=="        { return EQ; }
"!="        { return NE; }
"<"         { return LT; }
">"         { return GT; }

{letter}({letter}|{digit}|_)* {
    yylval.str = strdup(yytext);
    return ID;
}

[1-9]{digit}*|0 {
    yylval.num = atoi(yytext);
    return NUM;
}

"+"         { return '+'; }
"-"         { return '-'; }
"*"         { return '*'; }
"/"         { return '/'; }
"="         { return '='; }
";"         { return ';'; }
","         { return ','; }
"("         { return '('; }
")"         { return ')'; }
"{"         { return '{'; }
"}"         { return '}'; }

"//".*      { /* skip comments */ }
[ \t\r]+    { /* skip whitespace */ }
\n          { line_num++; }

.           { 
                char msg[100];
                sprintf(msg, "Unknown character: %s", yytext);
                yyerror(msg); 
            }

%%
