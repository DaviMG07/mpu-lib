#include <stdio.h>
#include <stdlib.h>
#include "basic.h"

int data_out = 0;
int flags    = 0;

int main() {
    init_mpu();
    mpu_reset();

    int matrix_unitary[5][5];
    int matrix_null[5][5] = {{0}};

    for (int i = 4; i >= 0; i--) {
        for (int j = 4; j >= 0; j--) {
            mpu_store(1, i, j, matrix_unitary[i][j]);
        }
    }

    for(int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            mpu_load(i, j);
            matrix_null[i][j] = data_out;
        }
    }

    for(int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            printf("%d ", (signed char)matrix_null[i][j]);
        }
        printf("\n");
    }
    finish_mpu();
    return 0;
}
