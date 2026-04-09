int global_multiplier = 5;
int global_result = 0;

int multiply(int a, int b) {
    return a * b;
}

int test_multiplication(int value) {
    global_result = multiply(value, global_multiplier);
    return global_result;
}

int get_global_multiplier() {
    return global_multiplier;
}

int get_global_result() {
    return global_result;
}