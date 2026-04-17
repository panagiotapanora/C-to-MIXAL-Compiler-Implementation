#ifndef CODEGEN_H
#define CODEGEN_H

void emit(const char* label, const char* op, const char* addr);
char* new_label();

#endif
