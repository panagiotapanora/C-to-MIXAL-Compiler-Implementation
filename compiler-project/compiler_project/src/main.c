#include <stdio.h>
#include <stdlib.h>
#include "symbol_table.h"

extern int yyparse(void);
extern FILE *yyin;
extern Method* head_method;

int main(int argc, char **argv) {
    if (argc > 1) {
        if (!(yyin = fopen(argv[1], "r"))) {
            perror(argv[1]);
            return 1;
        }
    } else {
        fprintf(stderr, "Usage: %s <input_file>\n", argv[0]);
        return 1;
    }
    
    init_symbol_table();
    
    if (yyparse() == 0) {
        // Check if main method exists
        if (!lookup_method("main")) {
            fprintf(stderr, "Semantic Error: 'main' method not found.\n");
            return 1;
        }
        printf("\nCompilation successful\n");
    } else {
        return 1;
    }
    
    return 0;
}
