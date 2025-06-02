#ifndef BASIC_H
#define BASIC_H

typedef struct {
  int op_code;
  int id;
  int row;
  int col;
  int value;
} Instruction;

extern int     flags;
extern int     data_out;

void init_mpu();
void finish_mpu(); 

int format_instruction(Instruction* i);

void send_instruction(int wait_flags, int instruction);

void mpu_load(int row, int col);
void mpu_store(int id, int row, int col, int value);
void mpu_add();
void mpu_sub();
void mpu_mul();
void mpu_scl(int scalar);
void mpu_reset();

#endif
