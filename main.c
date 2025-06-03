#include <stdio.h>
#include <stdlib.h>
#include "basic.h"
#include <stdint.h>

int data_out = 0;
int flags    = 0;

void store_matrix(int id, int matrix[5][5]) {
    for (int i = 4; i >= 0; i--) {
        for (int j = 4; j >= 0; j--) {
            mpu_store(id, i, j, matrix[i][j]);
        }
    }
}

void load_matrix(int matrix[5][5]) {
    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            mpu_load(i, j);
            matrix[i][j] = data_out;
        }
    }
}

void print_matrix(int matrix[5][5]) {
    for(int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            printf("%d ", (signed char)matrix[i][j]);
        }
        printf("\n");
    }
}

int main() {
    init_mpu();
    mpu_reset();

    int matrix_c[5][5];

    // Matriz Identidade
    int identity_matrix[5][5] = {
        {1, 0, 0, 0, 0},
        {0, 1, 0, 0, 0},
        {0, 0, 1, 0, 0},
        {0, 0, 0, 1, 0},
        {0, 0, 0, 0, 1}
    };

    // Matriz Unitária (todos os elementos são 1)
    int unitary_matrix[5][5] = {
        {1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1},
        {1, 1, 1, 1, 1}
    };

    // Matriz Nula (todos os elementos são 0)
    int null_matrix[5][5] = {
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0},
        {0, 0, 0, 0, 0}
    };

    // Matriz Randômica 1 (valores gerados por mim)
    int matrix_a[5][5] = {
        {10, -50, 120, -10, 35},
        {-80, 25, 60, -120, 78},
        {5, -15, 90, -30, 42},
        {110, -5, -70, 88, -22},
        {-99, 1, 127, -128, 0}
    };

    // Matriz Randômica 2 (valores gerados por mim)
    int matrix_b[5][5] = {
        {22, -12, 87, -45, 11},
        {-77, 33, -99, 66, -111},
        {4, 8, -10, 12, -16},
        {55, -2, 77, -8, 99},
        {-33, 44, -55, 66, 77}
    };

    // Matriz para Teste de Overflow (valores máximos e mínimos de int)
    // int vai de -128 a 127
    int overflow_test_matrix[5][5] = {
        {INT8_MAX, INT8_MIN,       100, -100,         0},
        {     126,     -127,        50,  -50,        70},
        {INT8_MAX, INT8_MAX, INT8_MIN, INT8_MIN, INT8_MAX},
        {       1,        0,         -1,    127,      -128},
        {INT8_MIN, INT8_MAX,       127,   -128,         0}
    };

    printf("\nmatriz A:\n");
    print_matrix(matrix_a);
    printf("\nmatriz B:\n");
    print_matrix(matrix_b);

    store_matrix(0, matrix_a);
    store_matrix(1, matrix_b);

    printf("\noperação de soma\n");
    mpu_add();
    //printf("operação de subtração\n");
    //mpu_sub();
    //printf("operação de multiplicação\n");
    //mpu_mul();
    //printf("operação de multiplicação por escalar\n");
    //mpu_scl(10);

    for (int i = 0; i < 5; i++) {
        for (int j = 0; j < 5; j++) {
            mpu_load(i, j);
            matrix_c[i][j] = data_out;
        }
    }

    printf("\nmatriz resultante:\n");
    print_matrix(matrix_c);
    finish_mpu();
    return 0;
}
