all: build

# Alvo para construir o executável
build: 
	as basic.s -o basic.o
	gcc --std=c99 basic.o basic.h main.c -o main

# Alvo para executar o programa
run: build
	./main 

# Regra para limpar arquivos gerados
clean:
	rm *.o ./main


