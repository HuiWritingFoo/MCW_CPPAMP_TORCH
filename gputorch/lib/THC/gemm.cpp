#include "gemm.h"

void gemm_NoTransAB(Concurrency::array_view<float, 1> &A, Concurrency::array_view<float, 1> &B, Concurrency::array_view<float, 1> &C, int M, int N, int K, int lda, int ldb, int ldc, float alpha, float beta)
{
  Concurrency::extent<1> grdExt(N * 16);
  Concurrency::tiled_extent<16> t_ext(grdExt);
  Concurrency::parallel_for_each(t_ext, [=] (Concurrency::tiled_index<16> tidx) restrict(amp){
  float temp;
  for (int j = tidx.global[0]; j < N; j+=t_ext[0]) {
    if (beta == 0) {
      for (int i = 0; i < M; ++i) {
        C[i+j*ldc] = 0;
      }
    } else if (beta != 1) {
      for (int i = 0; i < M; ++i) {
        C[i+j*ldc] *= beta;
      }
    }
    for (int l = 0; l < K; ++l) {
      if (B[l+j*ldb] != 0) {
        temp = alpha * B[l+j*ldb];
        for (int i = 0; i < M; ++i) {
          C[i+j*ldc] += A[i+l*lda] * temp;
        }
      }
    }
  }
  });
}

void gemm_NoTransB(Concurrency::array_view<float, 1> &A, Concurrency::array_view<float, 1> &B, Concurrency::array_view<float, 1> &C, int M, int N, int K, int lda, int ldb, int ldc, float alpha, float beta)
{
  float temp;
  for (int j = 0; j < N; ++j) {
    for (int i = 0; i < M; ++i) {
      temp = 0;
      for (int l = 0; l < K; ++l) {
        temp += A[l+i*lda] * B[l+j*ldb];
      }
      if (beta == 0) {
        C[i+j*ldc] = alpha*temp;
      } else {
        C[i+j*ldc] = alpha*temp + beta*C[i+j*ldc];
      }
    }
  }
}

void gemm_NoTransA(Concurrency::array_view<float, 1> &A, Concurrency::array_view<float, 1> &B, Concurrency::array_view<float, 1> &C, int M, int N, int K, int lda, int ldb, int ldc, float alpha, float beta)
{
  float temp;
  for (int j = 0; j < N; ++j) {
    if (beta == 0) {
      for (int i = 0; i < M; ++i) {
        C[i+j*ldc] = 0;
      }
    } else if (beta != 1) {
      for (int i = 0; i < M; ++i) {
        C[i+j*ldc] *= beta;
      }
    }
    for (int l = 0; l < K; ++l) {
      if (B[j+l*ldb] != 0) {
        temp = alpha * B[j+l*ldb];
        for (int i = 0; i < M; ++i) {
          C[i+j*ldc] += A[i+l*lda] * temp;
        }
      }
    }
  }
}

void gemm_TransAB(Concurrency::array_view<float, 1> &A, Concurrency::array_view<float, 1> &B, Concurrency::array_view<float, 1> &C, int M, int N, int K, int lda, int ldb, int ldc, float alpha, float beta)
{
  float temp;
  for (int j = 0; j < N; ++j) {
    for (int i = 0; i < M; ++i) {
      temp = 0;
      for (int l = 0; l < K; ++l) {
        temp += A[l+i*lda] * B[j+l*ldb];
      }
      if (beta == 0) {
        C[i+j*ldc] = alpha*temp;
      } else {
        C[i+j*ldc] = alpha*temp + beta*C[i+j*ldc];
      }
    }
  }
}

int gemm_AMP(char TransA, char TransB, const int M, const int N, const int K, const float alpha,
  float* A, int lda, float* B, int ldb,
  const float beta, float* C,  int ldc)
{
  int num_rows_a, /*num_cols_a,*/ num_rows_b; // nrowa, ncola, nrowb

  // use longest possible type for intermediate value storage:
  float temp;
  // %%= if [:rational,:complex,:value].include?(dtype.type); "#{dtype.long_dtype.sizeof} temp1, temp2;"; end%%
  int i, j, l;

  if (TransA == 'n') 
    num_rows_a = M;
  else                        
    num_rows_a = K;

  if (TransB == 'n') 
     num_rows_b = K;
  else                        
     num_rows_b = N;

  if (M < 0) {
    fprintf(stderr, "GEMM: Expected M >= 0\n");
    return 0;
  } else if (N < 0) {
    fprintf(stderr, "GEMM: Expected N >= 0\n");
    return 0;
  } else if (K < 0) {
    fprintf(stderr, "GEMM: Expected K >= 0\n");
    return 0;
  } else if (lda < std::max(1, num_rows_a)) {
    fprintf(stderr, "GEMM: Expected lda >= max(1, num_rows_a), with num_rows_a = %d; got lda=%d\n", num_rows_a, lda);
    return 0;
  } else if (ldb < std::max(1, num_rows_b)) {
    fprintf(stderr, "GEMM: Expected ldb >= max(1, num_rows_b), with num_rows_b = %d; got ldb=%d\n", num_rows_b, ldb);
    return 0;
  } else if (ldc < std::max(1,M)) {
    fprintf(stderr, "GEMM: Expected ldc >= max(1,M) with M=%d; got ldc=%d\n", M, ldc);
    return 0;
  }

  // Quick return if possible
  if (!M || !N || (alpha == 0 || !K) && beta == 1) return 0;

  // For alpha = 0
  if (alpha == 0) {
    if (beta == 0) {
      for (j = 0; j < N; ++j)
        for (i = 0; i < M; ++i) {
          C[i+j*ldc] = 0;
        }
    } else {
      for (j = 0; j < N; ++j)
        for (i = 0; i < M; ++i) {
          C[i+j*ldc] *= beta;
        }
    }
    return 0;
  }
  Concurrency::array_view<float,1> A_mat(M * K, A);
  Concurrency::array_view<float,1> B_mat(K * N, B);
  Concurrency::array_view<float,1> C_mat(M * N, C);
  // Start the operations
  if (TransB == 'n') {
    if (TransA == 'n') {
      // C = alpha*A*B+beta*C

      gemm_NoTransAB(A_mat, B_mat, C_mat, M, N, K, lda, ldb, ldc, alpha, beta);
    } else {

      // C = alpha*A**T*B + beta*C

      gemm_NoTransB(A_mat, B_mat, C_mat, M, N, K, lda, ldb, ldc, alpha, beta);
    }

  } else if (TransA == 'n') {

    // C = alpha*A*B**T + beta*C

      gemm_NoTransA(A_mat, B_mat, C_mat, M, N, K, lda, ldb, ldc, alpha, beta);
  } else {

    // C = alpha*A**T*B**T + beta*C

      gemm_TransAB(A_mat, B_mat, C_mat, M, N, K, lda, ldb, ldc, alpha, beta);
  }

  return 0;
}