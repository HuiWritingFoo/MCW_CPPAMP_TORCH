#include "amp_math.h"
#include "THBlas.h"
#include "THCBlas.h"
#include "THCGeneral.h"
#include "common.h"

// Kernel for fast unfold+copy
// (borrowed from Caffe: https://github.com/BVLC/caffe/blob/master/src/caffe/layers/conv_layer.cu)

void im2col(Concurrency::array_view<float,1> &avData_im, long imOffset, int inOffset, int channels, int height, int width, int ksize_h,
            int ksize_w, int pad_h, int pad_w, int stride_h, int stride_w, Concurrency::array_view<float,1> &avData_col, long colOffset)
{
  int height_col = (height + 2 * pad_h - ksize_h) / stride_h + 1;
  int width_col = (width + 2 * pad_w - ksize_w) / stride_w + 1;
  int n = channels * height_col * width_col;
  
  unsigned grdSz = (n+255) & ~255;
  Concurrency::extent<2> grdExt(grdSz, ksize_h);
  Concurrency::tiled_extent<256, 1> t_ext(grdExt);
  Concurrency::parallel_for_each(t_ext, [=] (Concurrency::tiled_index<256, 1> tidx) restrict(amp)
  {
    float dataCol = colOffset;
    float dataIm = imOffset + inOffset;
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
      float dataCol_orig = dataCol;

      if(ksize_w == 11)
      {
        int h = h_in + p;
        int w = w_in;
        int xxx = dataIm + p * width;
        int STEP = 0;
        dataCol = dataCol_orig + height_col * width_col * ksize_w * p;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0; 
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;          
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0;
        avData_col[dataCol + height_col * width_col * STEP++] = (h >= 0 && w >= 0 && h < height && w++ < width) ? avData_im[ xxx++] : 0; 
      }
      else
      {
        dataCol = dataCol_orig + height_col * width_col * ksize_w * p;
        for (int j = 0; j < ksize_w; ++j)
        {
          int h = h_in + p;
          int w = w_in + j;
          avData_col[dataCol] = (h >= 0 && w >= 0 && h < height && w < width) ? avData_im[ dataIm + p * width + j] : 0;
          dataCol += height_col * width_col;
        }
      }
    }
  });
}

void col2im_kernel(int n, Concurrency::array_view<float,1> &avData_col, long colOffset, int height, int width, int channels,
                   int patch_h, int patch_w, int pad_h, int pad_w, int stride_h,
                   int stride_w, int height_col, int width_col, Concurrency::array_view<float,1> &avData_im, long imOffset, int inp_stride, int elt)
{
  unsigned grdSz = (n + 256) -(n%256);
  Concurrency::extent<1> grdExt(grdSz);
  Concurrency::tiled_extent<256> t_ext(grdExt);
  Concurrency::parallel_for_each(t_ext, [=] (Concurrency::tiled_index<256> tidx) restrict(amp)
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

inline void col2im(Concurrency::array_view<float,1> &avData_col, long colOffset, int channels, int height, int width,
            int patch_h, int patch_w, int pad_h, int pad_w,
            int stride_h, int stride_w, Concurrency::array_view<float,1> &avData_im, long imOffset, int inp_stride, int elt)
{
  int height_col = (height + 2 * pad_h - patch_h) / stride_h + 1;
  int width_col = (width + 2 * pad_w - patch_w) / stride_w + 1;
  int num_kernels = channels * height * width;
  // To avoid involving atomic operations, we will launch one kernel per
  // bottom dimension, and then in the kernel add up the top dimensions.
   col2im_kernel(num_kernels, avData_col, colOffset, height, width, channels, patch_h, patch_w,
                 pad_h, pad_w, stride_h, stride_w, height_col, width_col, avData_im, imOffset, inp_stride, elt);
}

static int gpunn_SpatialConvolutionMM_updateOutput(lua_State *L) {
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
  if (input->nDimension == 3) {
    luaL_argcheck(L, input->size[0] == nInputPlane, 2, "input channels and nInputPlane dont match");
    // Force batch
    batch = 0;
    THGPUTensor_resize4d(input, 1, input->size[0], input->size[1], input->size[2]);
  } else {
    luaL_argcheck(L, input->size[1] == nInputPlane, 2, "input channels and nInputPlane dont match");
  }

  long inputWidth   = input->size[3];
  long inputHeight  = input->size[2];
  long outputWidth  = (inputWidth + 2*padding - kW) / dW + 1;
  long outputHeight = (inputHeight + 2*padding - kH) / dH + 1;


  // Batch size + input planes
  long batchSize = input->size[0];

  // Resize output
  THGPUTensor_resize4d(output, batchSize, nOutputPlane, outputHeight, outputWidth);

  // Resize temporary columns
  THGPUTensor_resize2d(columns, nInputPlane*kW*kH, outputHeight*outputWidth);

  // Define a buffer of ones, for bias accumulation
  // Note: this buffer can be shared with other modules, it only ever gets increased,
  // and always contains ones.
  if (ones->nDimension != 2 || ones->size[0]*ones->size[1] < outputHeight*outputWidth) {
    // Resize plane and fill with ones...
    THGPUTensor_resize2d(ones, outputHeight, outputWidth);
    THGPUTensor_fill(ones, 1);
  }

  // Helpers
  PREPARE_AV(columns, avData_col);
  PREPARE_AV(input, avData_im);
  long m_ = nOutputPlane;
  long n_ = outputHeight * outputWidth;
  long k_ = 1;
  long m = weight->size[0];
  long n = columns->size[1];
  long k = weight->size[1];

  PREPARE_AV(ones, avData_ones);
  PREPARE_AV(bias, avData_bias);
  PREPARE_AV(output, avData_output);
  PREPARE_AV(weight, avData_weight);
  Concurrency::array_view<float> *temp_buf = NULL;
  // For each elt in batch, do:
  for (int elt = 0; elt < batchSize; elt ++) {
    // Matrix mulitply per output:

    // Do Bias first:
    // M,N,K are dims of matrix A and B
    // (see http://docs.nvidia.com/gpu/cublas/#cublas-lt-t-gt-gemm)

    // Do GEMM (note: this is a bit confusing because gemm assumes column-major matrices)
    // Ugly codes but it is the way to deal with unnecessary copying from host
    avData_ones->discard_data();
    avData_bias->discard_data();
    avData_output->discard_data();
    THGPUBlas_gemm_opt(
        't', 'n',
        n_, m_, k_,
        1,
        *avData_ones, k_,
        *avData_bias, k_, 0,
        *avData_output, n_,
        NULL, NULL, NULL,
        ones->storageOffset, bias->storageOffset, output->storageOffset + output->stride[0] * elt, *temp_buf

    );
    // Extract columns:
    avData_im->discard_data();
    avData_col->discard_data();
    im2col(
        *avData_im, input->storageOffset, input->stride[0] * elt,
        nInputPlane, inputHeight, inputWidth, kH, kW, padding, padding, dH, dW,
        *avData_col, columns->storageOffset
    );
    // M,N,K are dims of matrix A and B
    // (see http://docs.nvidia.com/gpu/cublas/#cublas-lt-t-gt-gemm)

    // Do GEMM (note: this is a bit confusing because gemm assumes column-major matrices)
    avData_col->discard_data();
    avData_weight->discard_data();
    avData_output->discard_data();
    THGPUBlas_gemm_opt(
        'n', 'n',
        n, m, k,
        1,
        *avData_col, n,
        *avData_weight, k, 1,
        *avData_output, n,
        NULL, NULL, NULL,
        columns->storageOffset, weight->storageOffset, output->storageOffset + output->stride[0] * elt, *temp_buf
    );
  }

  // Resize output
  if (batch == 0) {
    THGPUTensor_resize3d(output, nOutputPlane, outputHeight, outputWidth);
    THGPUTensor_resize3d(input, nInputPlane, inputHeight, inputWidth);
  }
  // return output
  return 1;
}

static int gpunn_SpatialConvolutionMM_updateGradInput(lua_State *L) {
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
  if (input->nDimension == 3) {
    // Force batch
    batch = 0;
    THGPUTensor_resize4d(input, 1, input->size[0], input->size[1], input->size[2]);
    THGPUTensor_resize4d(gradOutput, 1, gradOutput->size[0], gradOutput->size[1], gradOutput->size[2]);
  }

  long inputWidth   = input->size[3];
  long inputHeight  = input->size[2];
  long outputWidth  = (inputWidth + 2*padding - kW) / dW + 1;
  long outputHeight = (inputHeight + 2*padding - kH) / dH + 1;

  // Batch size + input planes
  long batchSize = input->size[0];

  // Resize output
  THGPUTensor_resize4d(gradInput, batchSize, nInputPlane, inputHeight, inputWidth);

  // Resize temporary columns
  THGPUTensor_resize2d(gradColumns, nInputPlane*kW*kH, outputHeight*outputWidth);

  // Helpers
  PREPARE_AV(gradColumns, avData_col);
  PREPARE_AV(gradInput, avData_im);
  PREPARE_AV(gradOutput, avData_gradOutput);
  PREPARE_AV(weight, avData_weight);
  long colOffset = gradColumns->storageOffset;
  long imOffset = gradInput->storageOffset;
  long gradOutOffset = gradOutput->storageOffset;
  long weightOffset = weight->storageOffset;
  long m = weight->size[1];
  long n = gradColumns->size[1];
  long k = weight->size[0];

  Concurrency::array_view<float> *temp_buf = NULL;

 // For each elt in batch, do:
  for (int elt = 0; elt < batchSize; elt ++) {
    // Matrix mulitply per sample:

    // M,N,K are dims of matrix A and B
    // (see http://docs.nvidia.com/gpu/cublas/#cublas-lt-t-gt-gemm)

    // Do GEMM (note: this is a bit confusing because gemm assumes column-major matrices)
    // Ugly codes but it is the way to deal with unnecessary copying from host
    avData_gradOutput->discard_data();
    avData_weight->discard_data();
    avData_col->discard_data();
    THGPUBlas_gemm_opt(
        'n', 't',
        n, m, k,
        1,
        *avData_gradOutput, n,
        *avData_weight, m, 0,
        *avData_col, n,
        NULL, NULL, NULL,
        gradOutOffset + gradOutput->stride[0] * elt, weightOffset, colOffset, *temp_buf
    );

    // Unpack columns back into input:
    avData_col->discard_data();
    avData_im->discard_data();
    col2im(
        *avData_col, colOffset,
        nInputPlane, inputHeight, inputWidth, kH, kW, padding, padding, dH, dW,
        *avData_im, imOffset, gradInput->stride[0], elt
    );
  }

  // Resize output
  if (batch == 0) {
    THGPUTensor_resize3d(gradOutput, nOutputPlane, outputHeight, outputWidth);
    THGPUTensor_resize3d(input, nInputPlane, inputHeight, inputWidth);
    THGPUTensor_resize3d(gradInput, nInputPlane, inputHeight, inputWidth);
  }

  // Return gradInput
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
  if (input->nDimension == 3) {
    // Force batch
    batch = 0;
    THGPUTensor_resize4d(input, 1, input->size[0], input->size[1], input->size[2]);
    THGPUTensor_resize4d(gradOutput, 1, gradOutput->size[0], gradOutput->size[1], gradOutput->size[2]);
  }

  long inputWidth   = input->size[3];
  long inputHeight  = input->size[2];
  long outputWidth  = (inputWidth + 2*padding - kW) / dW + 1;
  long outputHeight = (inputHeight + 2*padding - kH) / dH + 1;

  // Batch size + input planes
  long batchSize = input->size[0];

  // Define a buffer of ones, for bias accumulation
  if (ones->nDimension != 2 || ones->size[0]*ones->size[1] < outputHeight*outputWidth) {
    // Resize plane and fill with ones...
    THGPUTensor_resize2d(ones, outputHeight, outputWidth);
    THGPUTensor_fill(ones, 1);
  }

  // Resize temporary columns
  THGPUTensor_resize2d(columns, nInputPlane*kW*kH, outputHeight*outputWidth);

  // Helpers
  long m = gradWeight->size[0];
  long n = gradWeight->size[1];
  long k = columns->size[1];
  long m_ = nOutputPlane;
  long k_ = outputHeight * outputWidth;

  // ones & gradBias are host pointer that will be used in kernels
  // Just sync from device to host here
  THGPUTensorMemcpyDeviceToHost(ones);
  THGPUTensorMemcpyDeviceToHost(gradBias);
  
  PREPARE_AV(columns, avData_col);
  PREPARE_AV(input, avData_im);
  PREPARE_AV(gradOutput, avData_gradOutput);
  PREPARE_AV(gradWeight, avData_gradWeight);
  PREPARE_AV(ones, avData_ones);
  PREPARE_AV(gradBias, avData_gradBias);
 
  long colOffset = columns->storageOffset;
  long imOffset = input->storageOffset;
  long gradOutOffset = gradOutput->storageOffset;
  long gradweiOffset = gradWeight->storageOffset;
  long onesOffset = ones->storageOffset;
  long gradBiasOffset = gradBias->storageOffset;
  

  // For each elt in batch, do:
  bool readNow=false;

  int lenX = k_;
  int lenY = m_;
  int len_X = (lenX + 255) & ~255;
  int numBlocks = len_X / 256;

  float* tempBuf = (float*)malloc(numBlocks*lenY*sizeof(float));
  Concurrency::extent<1> ext(numBlocks*lenY);
  Concurrency::array_view<float,1> temp_buf(ext, tempBuf);

  numBlocks = ((k + 255) & ~255)/256;
 
  Concurrency::array_view<float> *temp_buf1 = NULL;

  for (int elt = 0; elt < batchSize; elt ++) {
    // Extract columns:
    // Ugly codes but it is the way to deal with unnecessary copying from host
    avData_im->discard_data();
    avData_col->discard_data();
    im2col(
        *avData_im, imOffset, input->stride[0] * elt,
        nInputPlane, inputHeight, inputWidth, kH, kW, padding, padding, dH, dW,
        *avData_col, colOffset
    );

    // M,N,K are dims of matrix A and B
    // (see http://docs.nvidia.com/gpu/cublas/#cublas-lt-t-gt-gemm)

    // Do GEMM (note: this is a bit confusing because gemm assumes column-major matrices)
    avData_col->discard_data();
    avData_gradOutput->discard_data();
    avData_gradWeight->discard_data();
    THGPUBlas_gemm_opt(
        't', 'n',
        n, m, k,
        scale,
        *avData_col, k,
        *avData_gradOutput, k, 1,
        *avData_gradWeight, n,
        NULL, NULL, NULL,
        colOffset, gradOutOffset + gradOutput->stride[0] * elt, gradweiOffset, *temp_buf1
    );

    if(elt==batchSize-1)
      readNow = true;

    avData_ones->discard_data();
    avData_gradBias->discard_data();
    temp_buf.discard_data();

    THGPUBlas_gemv_opt(
        't',
        k_, m_,
        scale,
        *avData_gradOutput, gradOutOffset + gradOutput->stride[0] * elt,
        *avData_ones, onesOffset, 1,
        1,
        *avData_gradBias, gradBiasOffset, 1, temp_buf
    );
  }

  // Resize
  if (batch == 0) {
    THGPUTensor_resize3d(gradOutput, nOutputPlane, outputHeight, outputWidth);
    THGPUTensor_resize3d(input, nInputPlane, inputHeight, inputWidth);
  }
  // Return nothing
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
