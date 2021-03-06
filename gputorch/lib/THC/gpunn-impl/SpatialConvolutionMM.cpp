#include "amp_math.h"
#include "THBlas.h"
#include "THCBlas.h"
#include "THCGeneral.h"

#define NUMTHREADS 256 
// Kernel for fast unfold+copy
// (borrowed from Caffe: https://github.com/BVLC/caffe/blob/master/src/caffe/layers/conv_layer.cu)

void im2col(Concurrency::array_view<float,1> &avData_im, long imOffset,
            int channels, int height, int width, int ksize_h,
            int ksize_w, int pad_h, int pad_w, int stride_h, int stride_w,
            Concurrency::array_view<float,1> &avData_col, long colOffset)
{
  int height_col = (height + 2 * pad_h - ksize_h) / stride_h + 1;
  int width_col = (width + 2 * pad_w - ksize_w) / stride_w + 1;
  int n = channels * height_col * width_col;

  unsigned grdSz = (n + (NUMTHREADS - 1)) & ~(NUMTHREADS - 1);
  Concurrency::extent<2> grdExt(grdSz, ksize_h);
  Concurrency::tiled_extent<NUMTHREADS, 1> t_ext(grdExt);

  Concurrency::parallel_for_each(t_ext, [=] (Concurrency::tiled_index<NUMTHREADS, 1> tidx) restrict(amp)
  {
    long dataCol = colOffset;
    long dataIm = imOffset;
    int i = tidx.global[0];
    int p = tidx.global[1];

    if(i < n && p < ksize_h)
    {
      int w_out = i % width_col;
      i /= width_col;
      int h_out = i % height_col;
      int channel_in = i / height_col;
      int channel_out = channel_in * ksize_h * ksize_w;
      int h_in = h_out * stride_h - pad_h;
      int w_in = w_out * stride_w - pad_w;
      dataCol += (channel_out * height_col + h_out) * width_col + w_out;
      dataIm += (channel_in * height + h_in) * width + w_in ;

      dataCol += height_col * width_col * ksize_w * p;
      for (int j = 0; j < ksize_w; ++j)
      {
        int h = h_in + p;
        int w = w_in + j;
        avData_col[dataCol] = (h >= 0 && w >= 0 && h < height && w < width) ? avData_im[ dataIm + p * width + j] : 0;
        dataCol += height_col * width_col;
      }
    }
  });
}

void col2im_kernel(int n, Concurrency::array_view<float,1> &avData_col, long colOffset,
                   int height, int width, int channels,
                   int patch_h, int patch_w, int pad_h, int pad_w, int stride_h,
                   int stride_w, int height_col, int width_col,
                   Concurrency::array_view<float,1> &avData_im, long imOffset,
                   int inp_stride, int elt)
{
  unsigned grdSz = (n + NUMTHREADS) -(n % NUMTHREADS);
  Concurrency::extent<1> grdExt(grdSz);
  Concurrency::tiled_extent<NUMTHREADS> t_ext(grdExt);

  Concurrency::parallel_for_each(t_ext, [=] (Concurrency::tiled_index<NUMTHREADS> tidx) restrict(amp)
  {
    for (int i = tidx.global[0]; i < (n); i += t_ext[0])
    {
      float val = 0.0;
      int w = i % width + pad_w;
      int h = (i / width) % height + pad_h;
      int c = i / (width * height);
      // compute the start and end of the output
      int w_col_start = (w < patch_w) ? 0 : (w - patch_w) / stride_w + 1;
      int w_col_end = Concurrency::fast_math::fmin(w / stride_w + 1, width_col);
      int h_col_start = (h < patch_h) ? 0 : (h - patch_h) / stride_h + 1;
      int h_col_end = Concurrency::fast_math::fmin(h / stride_h + 1, height_col);
      // equivalent implementation
      int offset = (c * patch_h * patch_w + h * patch_w + w) * height_col * width_col;
      int coeff_h_col = (1 - stride_h * patch_w * height_col) * width_col;
      int coeff_w_col = (1 - stride_w * height_col * width_col);
      for (int h_col = h_col_start; h_col < h_col_end; ++h_col) 
      {
        for (int w_col = w_col_start; w_col < w_col_end; ++w_col) 
        {
          val += avData_col[colOffset + offset + h_col * coeff_h_col + w_col * coeff_w_col];
        }
      }
      avData_im[imOffset + i + elt * inp_stride] = val;
    }
  });
}

void col2im(Concurrency::array_view<float,1> &avData_col, long colOffset,
            int channels, int height, int width,
            int patch_h, int patch_w, int pad_h, int pad_w,
            int stride_h, int stride_w,
            Concurrency::array_view<float,1> &avData_im, long imOffset,
            int inp_stride, int elt)
{
  int height_col = (height + 2 * pad_h - patch_h) / stride_h + 1;
  int width_col = (width + 2 * pad_w - patch_w) / stride_w + 1;
  int num_kernels = channels * height * width;
  // To avoid involving atomic operations, we will launch one kernel per
  // bottom dimension, and then in the kernel add up the top dimensions.
   col2im_kernel(num_kernels, avData_col, colOffset, height, width, channels, patch_h, patch_w,
                 pad_h, pad_w, stride_h, stride_w, height_col, width_col, avData_im, imOffset, inp_stride, elt);
}

static int gpunn_SpatialConvolutionMM_updateOutput(lua_State *L)
{
  // Input
  THGPUTensor *input = (THGPUTensor*)luaT_checkudata(L, 2, "torch.GPUTensor");

  // Params:
  int dW = luaT_getfieldcheckint(L, 1, "dW");
  int dH = luaT_getfieldcheckint(L, 1, "dH");
  int kW = luaT_getfieldcheckint(L, 1, "kW");
  int kH = luaT_getfieldcheckint(L, 1, "kH");
  int nInputPlane = luaT_getfieldcheckint(L, 1, "nInputPlane");
  int nOutputPlane = luaT_getfieldcheckint(L, 1, "nOutputPlane");
  int padding = luaT_getfieldcheckint(L, 1, "padding");

  THGPUTensor *weight = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "weight", "torch.GPUTensor");
  THGPUTensor *bias = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "bias", "torch.GPUTensor");
  THGPUTensor *columns = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "finput", "torch.GPUTensor");
  THGPUTensor *ones = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "fgradInput", "torch.GPUTensor");
  THGPUTensor *output = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "output", "torch.GPUTensor");

  luaL_argcheck(L, input->nDimension == 3 || input->nDimension == 4, 2, "3D or 4D (batch mode) tensor is expected");

  int batch = 1;
  if (input->nDimension == 3)
  {
    luaL_argcheck(L, input->size[0] == nInputPlane, 2, "input channels and nInputPlane dont match");
    // Force batch
    batch = 0;
    THGPUTensor_resize4d(input, 1, input->size[0], input->size[1], input->size[2]);
  }
  else
  {
    luaL_argcheck(L, input->size[1] == nInputPlane, 2, "input channels and nInputPlane dont match");
  }

  long inputWidth   = input->size[3];
  long inputHeight  = input->size[2];
  long outputWidth  = (inputWidth + 2 * padding - kW) / dW + 1;
  long outputHeight = (inputHeight + 2 * padding - kH) / dH + 1;

  // Batch size + input planes
  long batchSize = input->size[0];

  // Resize output
  THGPUTensor_resize4d(output, batchSize, nOutputPlane, outputHeight, outputWidth);

  // Resize temporary columns
  THGPUTensor_resize2d(columns, nInputPlane*kW*kH, outputHeight*outputWidth);

  // Define a buffer of ones, for bias accumulation
  // Note: this buffer can be shared with other modules, it only ever gets increased,
  // and always contains ones.
  if (ones->nDimension != 2 || ones->size[0]*ones->size[1] < outputHeight*outputWidth)
  {
    // Resize plane and fill with ones...
    THGPUTensor_resize2d(ones, outputHeight, outputWidth);
    THGPUTensor_fill(ones, 1);
  }

  // Helpers
  auto avData_col = columns->get_array_view();
  auto avData_im = input->get_array_view();
  auto avData_ones = ones->get_array_view();
  auto avData_bias = bias->get_array_view();
  auto avData_output = output->get_array_view();
  auto avData_weight = weight->get_array_view();

  long m_ = nOutputPlane;
  long n_ = outputHeight * outputWidth;
  long k_ = 1;
  long m = weight->size[0];
  long n = columns->size[1];
  long k = weight->size[1];

  // For each elt in batch, do:
  for (int elt = 0; elt < batchSize; elt ++)
  {
    // Matrix mulitply per output:
    avData_ones.discard_data();
    avData_bias.discard_data();
    avData_output.discard_data();
    // Do Bias first:
    // M,N,K are dims of matrix A and B
    // Do GEMM (note: this is a bit confusing because gemm assumes column-major matrices)
    THGPUBlas_gemm('t', 'n', n_, m_, k_, 1,
                       avData_ones, ones->storageOffset, k_,
                       avData_bias, bias->storageOffset, k_, 0,
                       avData_output, output->storageOffset + output->stride[0] * elt, n_);

    avData_im.discard_data();
    avData_col.discard_data();

    // Extract columns:
    im2col(avData_im, input->storageOffset + input->stride[0] * elt,
           nInputPlane, inputHeight, inputWidth, kH, kW, padding,
           padding, dH, dW, avData_col, columns->storageOffset);
    
    avData_col.discard_data();
    avData_weight.discard_data();
    avData_output.discard_data();

    // M,N,K are dims of matrix A and B
    // Do GEMM (note: this is a bit confusing because gemm assumes column-major matrices)
    THGPUBlas_gemm('n', 'n', n, m, k, 1,
                       avData_col, columns->storageOffset, n,
                       avData_weight, weight->storageOffset, k, 1,
                       avData_output, output->storageOffset + output->stride[0] * elt, n);
  }
  // Resize output
  if (batch == 0)
  {
    THGPUTensor_resize3d(output, nOutputPlane, outputHeight, outputWidth);
    THGPUTensor_resize3d(input, nInputPlane, inputHeight, inputWidth);
  }
  return 1;
}

static int gpunn_SpatialConvolutionMM_updateGradInput(lua_State *L)
{
  // Inputs
  THGPUTensor *input = (THGPUTensor *)luaT_checkudata(L, 2, "torch.GPUTensor");
  THGPUTensor *gradOutput = (THGPUTensor *)luaT_checkudata(L, 3, "torch.GPUTensor");

  // Params
  int dW = luaT_getfieldcheckint(L, 1, "dW");
  int dH = luaT_getfieldcheckint(L, 1, "dH");
  int kW = luaT_getfieldcheckint(L, 1, "kW");
  int kH = luaT_getfieldcheckint(L, 1, "kH");
  int nInputPlane = luaT_getfieldcheckint(L, 1, "nInputPlane");
  int nOutputPlane = luaT_getfieldcheckint(L, 1, "nOutputPlane");
  int padding = luaT_getfieldcheckint(L, 1, "padding");

  THGPUTensor *weight = (THGPUTensor *)luaT_getfieldcheckudata(L, 1, "weight", "torch.GPUTensor");
  THGPUTensor *gradColumns = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "finput", "torch.GPUTensor");
  THGPUTensor *gradInput = (THGPUTensor *)luaT_getfieldcheckudata(L, 1, "gradInput", "torch.GPUTensor");

  luaL_argcheck(L, input->nDimension == 3 || input->nDimension == 4, 2, "3D or 4D (batch mode) tensor is expected");

  int batch = 1;
  if (input->nDimension == 3)
  {
    // Force batch
    batch = 0;
    THGPUTensor_resize4d(input, 1, input->size[0], input->size[1], input->size[2]);
    THGPUTensor_resize4d(gradOutput, 1, gradOutput->size[0], gradOutput->size[1], gradOutput->size[2]);
  }

  long inputWidth   = input->size[3];
  long inputHeight  = input->size[2];
  long outputWidth  = (inputWidth + 2 * padding - kW) / dW + 1;
  long outputHeight = (inputHeight + 2 * padding - kH) / dH + 1;

  // Batch size + input planes
  long batchSize = input->size[0];

  // Resize output
  THGPUTensor_resize4d(gradInput, batchSize, nInputPlane, inputHeight, inputWidth);

  // Resize temporary columns
  THGPUTensor_resize2d(gradColumns, nInputPlane*kW*kH, outputHeight*outputWidth);

  auto avData_col = gradColumns->get_array_view();
  auto avData_im = gradInput->get_array_view();
  auto avData_gradOutput = gradOutput->get_array_view();
  auto avData_weight = weight->get_array_view();

  long m = weight->size[1];
  long n = gradColumns->size[1];
  long k = weight->size[0];

 // For each elt in batch, do:
  for (int elt = 0; elt < batchSize; elt ++)
  {
    // Matrix mulitply per sample:
    avData_gradOutput.discard_data();
    avData_weight.discard_data();
    avData_col.discard_data();
    // M,N,K are dims of matrix A and B
    // Do GEMM (note: this is a bit confusing because gemm assumes column-major matrices)
    THGPUBlas_gemm('n', 't', n, m, k, 1,
                       avData_gradOutput, gradOutput->storageOffset + gradOutput->stride[0] * elt, n,
                       avData_weight, weight->storageOffset, m, 0,
                       avData_col, gradColumns->storageOffset, n);

    avData_col.discard_data();
    avData_im.discard_data();

    // Unpack columns back into input:
    col2im(avData_col, gradColumns->storageOffset,  nInputPlane,
           inputHeight, inputWidth, kH, kW, padding, padding, dH, dW,
           avData_im, gradInput->storageOffset, gradInput->stride[0], elt);
  }

  // Resize output
  if (batch == 0)
  {
    THGPUTensor_resize3d(gradOutput, nOutputPlane, outputHeight, outputWidth);
    THGPUTensor_resize3d(input, nInputPlane, inputHeight, inputWidth);
    THGPUTensor_resize3d(gradInput, nInputPlane, inputHeight, inputWidth);
  }
  return 1;
}

static int gpunn_SpatialConvolutionMM_accGradParameters(lua_State *L) {
  // Inputs
  THGPUTensor *input = (THGPUTensor *)luaT_checkudata(L, 2, "torch.GPUTensor");
  THGPUTensor *gradOutput = (THGPUTensor *)luaT_checkudata(L, 3, "torch.GPUTensor");

  // Params
  int dW = luaT_getfieldcheckint(L, 1, "dW");
  int dH = luaT_getfieldcheckint(L, 1, "dH");
  int kW = luaT_getfieldcheckint(L, 1, "kW");
  int kH = luaT_getfieldcheckint(L, 1, "kH");
  int nInputPlane = luaT_getfieldcheckint(L, 1, "nInputPlane");
  int nOutputPlane = luaT_getfieldcheckint(L, 1, "nOutputPlane");
  int padding = luaT_getfieldcheckint(L, 1, "padding");
  float scale = luaL_optnumber(L, 4, 1);

  THGPUTensor *gradWeight = (THGPUTensor *)luaT_getfieldcheckudata(L, 1, "gradWeight", "torch.GPUTensor");
  THGPUTensor *gradBias = (THGPUTensor *)luaT_getfieldcheckudata(L, 1, "gradBias", "torch.GPUTensor");
  THGPUTensor *columns = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "finput", "torch.GPUTensor");
  THGPUTensor *ones = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "fgradInput", "torch.GPUTensor");

  luaL_argcheck(L, input->nDimension == 3 || input->nDimension == 4, 2, "3D or 4D (batch mode) tensor is expected");

  int batch = 1;
  if (input->nDimension == 3)
  {
    // Force batch
    batch = 0;
    THGPUTensor_resize4d(input, 1, input->size[0], input->size[1], input->size[2]);
    THGPUTensor_resize4d(gradOutput, 1, gradOutput->size[0], gradOutput->size[1], gradOutput->size[2]);
  }

  long inputWidth   = input->size[3];
  long inputHeight  = input->size[2];
  long outputWidth  = (inputWidth + 2 * padding - kW) / dW + 1;
  long outputHeight = (inputHeight + 2 * padding - kH) / dH + 1;

  // Batch size + input planes
  long batchSize = input->size[0];

  // Define a buffer of ones, for bias accumulation
  if (ones->nDimension != 2 || ones->size[0]*ones->size[1] < outputHeight*outputWidth)
  {
    // Resize plane and fill with ones...
    THGPUTensor_resize2d(ones, outputHeight, outputWidth);
    THGPUTensor_fill(ones, 1);
  }

  // Resize temporary columns
  THGPUTensor_resize2d(columns, nInputPlane*kW*kH, outputHeight*outputWidth);

  long m = gradWeight->size[0];
  long n = gradWeight->size[1];
  long k = columns->size[1];
  long m_ = nOutputPlane;
  long k_ = outputHeight * outputWidth;

  auto avData_col = columns->get_array_view();
  auto avData_im = input->get_array_view();
  auto avData_gradOutput = gradOutput->get_array_view();
  auto avData_gradWeight = gradWeight->get_array_view();
  auto avData_ones = ones->get_array_view();
  auto avData_gradBias = gradBias->get_array_view();

  int lenX = k_;
  int lenY = m_;
  int len_X = (lenX + (NUMTHREADS - 1)) & ~(NUMTHREADS - 1);
  int numBlocks = len_X / NUMTHREADS;

  float* tempBuf = (float*)malloc(numBlocks * lenY * sizeof(float));
  Concurrency::extent<1> ext(numBlocks * lenY);
  Concurrency::array_view<float,1> temp_buf(ext, tempBuf);

  numBlocks = ((k + (NUMTHREADS - 1)) & ~(NUMTHREADS - 1)) / NUMTHREADS;

  // For each elt in batch, do:
  for (int elt = 0; elt < batchSize; elt ++)
  {
    avData_im.discard_data();
    avData_col.discard_data();

    // Extract columns:
    im2col(avData_im, input->storageOffset + input->stride[0] * elt,
          nInputPlane, inputHeight, inputWidth, kH, kW, padding, padding,
          dH, dW, avData_col, columns->storageOffset);

    avData_col.discard_data();
    avData_gradOutput.discard_data();
    avData_gradWeight.discard_data();

    // M,N,K are dims of matrix A and B
    // Do GEMM (note: this is a bit confusing because gemm assumes column-major matrices)
    THGPUBlas_gemm('t', 'n', n, m, k, scale,
                       avData_col, columns->storageOffset, k,
                       avData_gradOutput, gradOutput->storageOffset + gradOutput->stride[0] * elt, k, 1,
                       avData_gradWeight, gradWeight->storageOffset, n);

    avData_ones.discard_data();
    avData_gradBias.discard_data();
    temp_buf.discard_data();

    THGPUBlas_gemv('t', k_, m_, scale,
                       avData_gradOutput,
                       gradOutput->storageOffset + gradOutput->stride[0] * elt,
                       avData_ones, ones->storageOffset, 1, 1,
                       avData_gradBias, gradBias->storageOffset, 1, temp_buf);
  }

  // Resize
  if (batch == 0)
  {
    THGPUTensor_resize3d(gradOutput, nOutputPlane, outputHeight, outputWidth);
    THGPUTensor_resize3d(input, nInputPlane, inputHeight, inputWidth);
  }

  free(tempBuf);
  return 0;
}

static const struct luaL_Reg gpunn_SpatialConvolutionMM__ [] = {
  {"SpatialConvolutionMM_updateOutput", gpunn_SpatialConvolutionMM_updateOutput},
  {"SpatialConvolutionMM_updateGradInput", gpunn_SpatialConvolutionMM_updateGradInput},
  {"SpatialConvolutionMM_accGradParameters", gpunn_SpatialConvolutionMM_accGradParameters},
  {NULL, NULL}
};

static void gpunn_SpatialConvolutionMM_init(lua_State *L)
{
  luaT_pushmetatable(L, "torch.GPUTensor");
  luaT_registeratname(L, gpunn_SpatialConvolutionMM__, "nn");
  lua_pop(L,1);
}
