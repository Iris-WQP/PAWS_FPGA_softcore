#include <stdio.h>
#include <math.h>

#define N 4

void matvec(const float *A, const float *v, float *out) {
    for (int i = 0; i < N; ++i) {
        float s = 0.0f;
        for (int j = 0; j < N; ++j) s += A[i*N + j] * v[j];
        out[i] = s;
    }
}

float dot(const float *a, const float *b) {
    float s = 0.0f;
    for (int i = 0; i < N; ++i) s += a[i] * b[i];
    return s;
}

void cg_solve(const float *A, const float *b, float *x) {
    float r[N], p[N], Ap[N];
    for (int i = 0; i < N; ++i) x[i] = 0.0f;
    for (int i = 0; i < N; ++i) r[i] = b[i];
    for (int i = 0; i < N; ++i) p[i] = r[i];

    float rr_old = dot(r, r);
    const int max_iter = 64;
    const float tol = 1e-6f;

    for (int iter = 0; iter < max_iter; ++iter) {
        matvec(A, p, Ap);
        float pAp = dot(p, Ap);
        if (pAp == 0.0f) break;
        float alpha = rr_old / pAp;
        for (int i = 0; i < N; ++i) x[i] += alpha * p[i];
        for (int i = 0; i < N; ++i) r[i] -= alpha * Ap[i];
        float rr_new = dot(r, r);
        if (sqrtf(rr_new) < tol) break;
        float beta = rr_new / rr_old;
        for (int i = 0; i < N; ++i) p[i] = r[i] + beta * p[i];
        rr_old = rr_new;
    }
}

int main(void) {
    /* Symmetric positive-definite sample 4x4 matrix */
    float A[N*N] = {
        4.0f, 1.0f, 0.0f, 0.0f,
        1.0f, 3.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 2.0f, 1.0f,
        0.0f, 0.0f, 1.0f, 2.0f
    };
    float b[N] = {1.0f, 2.0f, 3.0f, 4.0f};
    float x[N];

    cg_solve(A, b, x);

    printf("Solution x:\n");
    for (int i = 0; i < N; ++i) printf("%0.8f\n", x[i]);
    return 0;
}
