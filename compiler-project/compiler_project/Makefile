CC = gcc
CFLAGS = -Wall -I./src
BISON = bison
FLEX = flex

TARGET = compiler

SRC_DIR = src
OBJ_DIR = build

$(TARGET): $(SRC_DIR)/parser.tab.c $(SRC_DIR)/lex.yy.c $(SRC_DIR)/symbol_table.c $(SRC_DIR)/codegen.c $(SRC_DIR)/main.c
	$(CC) $(CFLAGS) $^ -o $(TARGET)

$(SRC_DIR)/parser.tab.c $(SRC_DIR)/parser.tab.h: $(SRC_DIR)/parser.y
	$(BISON) -d -o $(SRC_DIR)/parser.tab.c $(SRC_DIR)/parser.y

$(SRC_DIR)/lex.yy.c: $(SRC_DIR)/lexer.l $(SRC_DIR)/parser.tab.h
	$(FLEX) -o $(SRC_DIR)/lex.yy.c $(SRC_DIR)/lexer.l

clean:
	rm -f $(TARGET) $(SRC_DIR)/*.tab.* $(SRC_DIR)/lex.yy.c
