#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "symbol_table.h"

Method* head_method = NULL;

void init_symbol_table() {
    head_method = NULL;
}

void semantic_error(const char* msg) {
    extern int line_num;
    fprintf(stderr, "Semantic Error at line %d: %s\n", line_num, msg);
    exit(1);
}

Method* insert_method(char* name) {
    if (lookup_method(name)) {
        char buf[100];
        sprintf(buf, "Method '%s' already declared (no overloading allowed)", name);
        semantic_error(buf);
    }
    Method* m = (Method*)malloc(sizeof(Method));
    m->name = strdup(name);
    m->params = NULL;
    m->locals = NULL;
    m->param_count = 0;
    m->local_count = 0;
    m->next = head_method;
    head_method = m;
    return m;
}

Method* lookup_method(char* name) {
    Method* curr = head_method;
    while (curr) {
        if (strcmp(curr->name, name) == 0) return curr;
        curr = curr->next;
    }
    return NULL;
}

void add_param(Method* method, char* name) {
    Variable* p = (Variable*)malloc(sizeof(Variable));
    p->name = strdup(name);
    // Initial offset, will be fixed in fix_param_offsets
    p->offset = method->param_count; 
    p->next = method->params;
    method->params = p;
    method->param_count++;
}

void fix_param_offsets(Method* method) {
    Variable* v = method->params;
    int i = 0;
    // Parameters are pushed left-to-right?
    // In ACTUALS: ARGS EXPR { STA 0,6; INC6 1 }
    // ARGS: ARGS EXPR ',' { STA 0,6; INC6 1 }
    // So if call is f(a, b, c):
    // a is at X
    // b is at X+1
    // c is at X+2
    // SP is X+3
    // Entry: ST5 0,6 (X+3), STJ 1,6 (X+4), FP = X+3, SP = X+5
    // So c is at FP-1, b is at FP-2, a is at FP-3.
    // The list method->params has them in reverse order (c, b, a).
    while (v) {
        v->offset = -(i + 1);
        v = v->next;
        i++;
    }
}

void add_variable(Method* method, char* name) {
    // Check if it already exists in params or locals
    Variable* v = method->params;
    while(v) { if(strcmp(v->name, name) == 0) semantic_error("Variable already exists as param"); v=v->next; }
    v = method->locals;
    while(v) { if(strcmp(v->name, name) == 0) semantic_error("Variable already exists as local"); v=v->next; }

    Variable* lv = (Variable*)malloc(sizeof(Variable));
    lv->name = strdup(name);
    // Locals are at positive offsets relative to FP
    // SP+0: Saved FP, SP+1: Return Address, SP+2+: Locals
    lv->offset = 2 + method->local_count;
    lv->next = method->locals;
    method->locals = lv;
    method->local_count++;
}

int get_variable_offset(Method* method, char* name) {
    Variable* v = method->params;
    while (v) {
        if (strcmp(v->name, name) == 0) return v->offset;
        v = v->next;
    }
    v = method->locals;
    while (v) {
        if (strcmp(v->name, name) == 0) return v->offset;
        v = v->next;
    }
    char buf[100];
    sprintf(buf, "Variable '%s' not found", name);
    semantic_error(buf);
    return 0;
}

void check_method_exists(char* name) {
    if (!lookup_method(name)) {
        char buf[100];
        sprintf(buf, "Method '%s' not declared", name);
        semantic_error(buf);
    }
}

void check_method_call(char* name, int arg_count) {
    Method* m = lookup_method(name);
    if (!m) {
        char buf[100];
        sprintf(buf, "Method '%s' not declared", name);
        semantic_error(buf);
    }
    if (m->param_count != arg_count) {
        char buf[100];
        sprintf(buf, "Method '%s' expects %d arguments, but %d were provided", 
                name, m->param_count, arg_count);
        semantic_error(buf);
    }
}

void check_variable_exists(Method* method, char* name) {
    get_variable_offset(method, name);
}
