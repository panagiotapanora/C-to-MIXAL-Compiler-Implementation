%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbol_table.h"
#include "codegen.h"

extern int yylex();
extern int line_num;
void yyerror(const char *s);

Method* current_method = NULL;
int in_loop = 0;
char* loop_end_labels[100];
char* loop_start_labels[100];

int header_emitted = 0;

void emit_header() {
    if (!header_emitted) {
        emit("", "ORIG", "3000");
        emit("STK", "EQU", "3500");
        emit("START", "ENT6", "STK"); // rI6 = SP
        emit("", "ENT5", "STK");      // rI5 = FP
        emit("", "JSR", "main");
        emit("", "HLT", "");
        header_emitted = 1;
    }
}

%}

%union {
    int num;
    char* str;
}

%token <str> ID
%token <num> NUM
%token INT RETURN IF ELSE WHILE BREAK TRUE FALSE
%token LE GE EQ NE LT GT

%type <str> RELOP ADDOP MULOP LOCATION METHOD
%type <num> ACTUALS ARGS

%left '+' '-'
%left '*' '/'
%left EQ NE LT GT LE GE
%right '='

%%

PROGRAM:
    { emit_header(); } METH_LIST
    | /* ε */
    ;

METH_LIST:
    METH METH_LIST
    | METH
    ;

METH:
    TYPE ID '(' {
        current_method = insert_method($2);
    } PARAMS ')' BODY {
        char label[100];
        sprintf(label, "END_%s", current_method->name);
        emit(label, "ENT6", "0,5"); // SP = FP
        emit("", "LD5", "0,6");    // Restore old FP
        emit("", "LDJ", "1,6");    // Restore return address (rJ)
        // Pop arguments
        if (current_method->param_count > 0) {
            char buf[20];
            sprintf(buf, "%d", current_method->param_count);
            emit("", "DEC6", buf);
        }
        emit("", "JMP", "0,J");    // Jump to return address in rJ
        current_method = NULL;
    }
    ;

PARAMS:
    FORMALS TYPE ID {
        add_param(current_method, $3);
    }
    | /* ε */
    ;

FORMALS:
    FORMALS TYPE ID ',' {
        add_param(current_method, $3);
    }
    | /* ε */
    ;

TYPE:
    INT
    ;

BODY:
    '{' {
        // Fix param offsets now that we know param_count
        fix_param_offsets(current_method);
        
        // Method entry: save old FP and return address
        emit(current_method->name, "ST5", "0,6"); // Save old FP at SP+0
        emit("", "STJ", "1,6");                 // Save Return Address at SP+1
        emit("", "ENT5", "0,6");                // FP = SP
        emit("", "INC6", "2");                  // SP = SP + 2
    } DECLS STMTS '}'
    ;

DECLS:
    DECL_LIST DECL
    | /* ε */
    ;

DECL_LIST:
    DECL_LIST DECL
    | /* ε */
    ;

DECL:
    TYPE ID VARS ';' {
        add_variable(current_method, $2);
        emit("", "INC6", "1");
    }
    | TYPE ID '=' EXPR {
        add_variable(current_method, $2);
        int offset = get_variable_offset(current_method, $2);
        char buf[20];
        sprintf(buf, "%d,5", offset);
        emit("", "STA", buf);
        emit("", "INC6", "1");
    } VARS ';'
    ;

VARS:
    ',' ID {
        add_variable(current_method, $2);
        emit("", "INC6", "1");
    } VARS
    | ',' ID '=' EXPR {
        add_variable(current_method, $2);
        int offset = get_variable_offset(current_method, $2);
        char buf[20];
        sprintf(buf, "%d,5", offset);
        emit("", "STA", buf);
        emit("", "INC6", "1");
    } VARS
    | /* ε */
    ;

STMTS:
    STMTS STMT
    | /* ε */
    ;

STMT:
    ASSIGN ';'
    | RETURN EXPR ';' {
        char label[100];
        sprintf(label, "END_%s", current_method->name);
        emit("", "JMP", label);
    }
    | IF '(' EXPR ')' {
        char* L1 = new_label();
        emit("", "CMPA", "=0=");
        emit("", "JE", L1);
        $<str>$ = L1;
    } STMT ELSE {
        char* L2 = new_label();
        emit("", "JMP", L2);
        emit($<str>5, "NOP", "");
        $<str>$ = L2;
    } STMT {
        emit($<str>8, "NOP", "");
    }
    | WHILE '(' {
        char* Lstart = new_label();
        char* Lend = new_label();
        emit(Lstart, "NOP", "");
        loop_start_labels[in_loop] = Lstart;
        loop_end_labels[in_loop] = Lend;
        in_loop++;
    } EXPR ')' {
        emit("", "CMPA", "=0=");
        emit("", "JE", loop_end_labels[in_loop-1]);
    } STMT {
        emit("", "JMP", loop_start_labels[in_loop-1]);
        emit(loop_end_labels[in_loop-1], "NOP", "");
        in_loop--;
    }
    | BREAK ';' {
        if (in_loop == 0) semantic_error("break outside loop");
        emit("", "JMP", loop_end_labels[in_loop-1]);
    }
    | BLOCK
    | ';'
    ;

BLOCK:
    '{' STMTS '}'
    ;

ASSIGN:
    LOCATION '=' EXPR {
        int offset = get_variable_offset(current_method, $1);
        char buf[20];
        sprintf(buf, "%d,5", offset);
        emit("", "STA", buf);
    }
    ;

LOCATION:
    ID { $$ = $1; }
    ;

METHOD:
    ID { $$ = $1; }
    ;

EXPR:
    ADD_EXPR RELOP {
        emit("", "STA", "0,6");
        emit("", "INC6", "1");
    } ADD_EXPR {
        emit("", "STA", "0,6");    // Push right operand (optional but safe)
        emit("", "LDA", "-1,6");   // Load left operand
        emit("", "CMPA", "0,6");   // Compare
        char* Ltrue = new_label();
        char* Lnext = new_label();
        emit("", $2, Ltrue);
        emit("", "LDA", "=0=");
        emit("", "JMP", Lnext);
        emit(Ltrue, "LDA", "=1=");
        emit(Lnext, "NOP", "");
        emit("", "DEC6", "1");     // Pop left operand
    }
    | ADD_EXPR
    ;

RELOP:
    LE { $$ = "JLE"; }
    | LT { $$ = "JL"; }
    | GT { $$ = "JG"; }
    | GE { $$ = "JGE"; }
    | EQ { $$ = "JE"; }
    | NE { $$ = "JNE"; }
    ;

ADD_EXPR:
    ADD_EXPR ADDOP {
        emit("", "STA", "0,6");
        emit("", "INC6", "1");
    } TERM {
        emit("", "STA", "0,6");   // Store right in SP+0
        emit("", "LDA", "-1,6");  // Load left from SP-1
        emit("", $2, "0,6");      // op with right
        emit("", "DEC6", "1");    // Pop
    }
    | TERM
    ;

ADDOP:
    '+' { $$ = "ADD"; }
    | '-' { $$ = "SUB"; }
    ;

TERM:
    TERM MULOP {
        emit("", "STA", "0,6");
        emit("", "INC6", "1");
    } FACTOR {
        emit("", "STA", "0,6");
        emit("", "LDA", "-1,6");
        if (strcmp($2, "MUL") == 0) {
            emit("", "MUL", "0,6");
            emit("", "STX", "0,6"); // Get low bits from rX? Actually MIX MUL stores in rAX
            emit("", "LDA", "0,6"); 
        } else {
            emit("", "ENTX", "0");
            emit("", "DIV", "0,6");
        }
        emit("", "DEC6", "1");
    }
    | FACTOR
    ;

MULOP:
    '*' { $$ = "MUL"; }
    | '/' { $$ = "DIV"; }
    ;

FACTOR:
    '(' EXPR ')'
    | '-' FACTOR {
        emit("", "STA", "0,6");
        emit("", "LDA", "=0=");
        emit("", "SUB", "0,6");
    }
    | LOCATION {
        int offset = get_variable_offset(current_method, $1);
        char buf[20];
        sprintf(buf, "%d,5", offset);
        emit("", "LDA", buf);
    }
    | NUM {
        char buf[20];
        sprintf(buf, "=%d=", $1);
        emit("", "LDA", buf);
    }
    | TRUE {
        emit("", "LDA", "=1=");
    }
    | FALSE {
        emit("", "LDA", "=0=");
    }
    | METHOD '(' ACTUALS ')' {
        check_method_call($1, $3);
        emit("", "JSR", $1);
    }
    ;

ACTUALS:
    ARGS EXPR {
        emit("", "STA", "0,6");
        emit("", "INC6", "1");
        $$ = $1 + 1;
    }
    | /* ε */ { $$ = 0; }
    ;

ARGS:
    ARGS EXPR ',' {
        emit("", "STA", "0,6");
        emit("", "INC6", "1");
        $$ = $1 + 1;
    }
    | /* ε */ { $$ = 0; }
    ;

%%

void yyerror(const char *s) {
    fprintf(stderr, "Syntax Error at line %d: %s\n", line_num, s);
    exit(1);
}
