#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

typedef struct Variable {
    char* name;
    int offset;
    struct Variable* next;
} Variable;

typedef struct Method {
    char* name;
    Variable* params;
    Variable* locals;
    int param_count;
    int local_count;
    struct Method* next;
} Method;

void init_symbol_table();
Method* insert_method(char* name);
Method* lookup_method(char* name);
void add_param(Method* method, char* name);
void add_variable(Method* method, char* name);
void fix_param_offsets(Method* method);
int get_variable_offset(Method* method, char* name);
void check_method_exists(char* name);
void check_variable_exists(Method* method, char* name);
void check_method_call(char* name, int arg_count);
void semantic_error(const char* msg);

#endif
