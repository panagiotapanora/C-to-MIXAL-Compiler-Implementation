#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "codegen.h"

int label_count = 0;

void emit(const char* label, const char* op, const char* addr) {
    if (label && strlen(label) > 0) {
        printf("%-10s %-10s %-10s\n", label, op, addr);
    } else {
        printf("%-10s %-10s %-10s\n", "", op, addr);
    }
}

char* new_label() {
    char* label = (char*)malloc(10);
    sprintf(label, "L%d", label_count++);
    return label;
}
