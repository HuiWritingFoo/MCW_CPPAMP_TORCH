#define MINUS_LOG_THRESHOLD -18.42
#define SOFTMAX_THREADS 256

void gpunn_SoftMax_updateOutput_kernel(Concurrency::array_view<float,1> &avOutput, long outOffset,
                                       Concurrency::array_view<float,1>&avInp, long inpOffset,
                                       int nframe, int dim)
{
  Concurrency::extent<1> grdExt(nframe * SOFTMAX_THREADS);
  Concurrency::tiled_extent<SOFTMAX_THREADS> t_ext(grdExt);

  Concurrency::parallel_for_each(t_ext, [=] (Concurrency::tiled_index<SOFTMAX_THREADS> tidx) restrict(amp)
  {
    tile_static float buffer[SOFTMAX_THREADS+1];
    int k = tidx.tile[0];
    float *input_k = avInp.data() + inpOffset;
    input_k += k * dim;
    float *output_k = avOutput.data() + outOffset;
    output_k += k;

    int i_start = tidx.local[0];
    int i_end = dim;
    int i_step = t_ext.tile_dim0;

    // max?
    buffer[i_start] = -FLT_MAX;
    for (int i = i_start; i < i_end; i += i_step)
    {
      float z = input_k[i];
      if(buffer[i_start] < z)
        buffer[i_start] = z;
    }
    tidx.barrier.wait();

    // reduce
    if (i_start == 0)
    {
      float max_k = -FLT_MAX;
      for (int i = 0; i < i_step; i++)
      {
        if(max_k < buffer[i])
          max_k = buffer[i];
      }
      buffer[SOFTMAX_THREADS] = max_k;
    }
    tidx.barrier.wait();

    // sum?
    float max_k = buffer[SOFTMAX_THREADS];
    buffer[i_start] = 0;
    for (int i = i_start; i < i_end; i += i_step)
    {
      float z = Concurrency::fast_math::exp(input_k[i] - max_k);
      buffer[i_start] += z;
      output_k[i] = z;
    }
    tidx.barrier.wait();

    // reduce
    if (i_start == 0)
    {
      float sum_k = 0;
      for (int i = 0; i < i_step; i++)
        sum_k += buffer[i];

      buffer[SOFTMAX_THREADS] = sum_k;
    }
    tidx.barrier.wait();

    // softmax
    float sum_k = buffer[SOFTMAX_THREADS];
    for (int i = i_start; i < i_end; i += i_step)
      output_k[i] = output_k[i] / sum_k;

  });
}


void gpunn_SoftMax_updateGradInput_kernel(Concurrency::array_view<float, 1> &avGradInput, long gradInOffset,
                                          Concurrency::array_view<float,1> &avOutput, long outOffset,
                                          Concurrency::array_view<float,1> &avGradOutput, long gradOutOffset,
                                          int nframe, int dim)
{
  Concurrency::extent<1> grdExt(nframe * SOFTMAX_THREADS);
  Concurrency::tiled_extent<SOFTMAX_THREADS> t_ext(grdExt);

  Concurrency::parallel_for_each(t_ext, [=] (Concurrency::tiled_index<SOFTMAX_THREADS> tidx) restrict(amp) 
  {
    tile_static float buffer[SOFTMAX_THREADS];
    int k = tidx.tile[0];
    float *gradInput_k = avGradInput.data() + gradInOffset;
    gradInput_k += k * dim;
    float *output_k = avOutput.data() + outOffset;
    output_k += k * dim;
    float *gradOutput_k = avGradOutput.data() + gradOutOffset;
    gradOutput_k += k * dim;

    int i_start = tidx.local[0];
    int i_end = dim;
    int i_step = t_ext.tile_dim0;

    // sum?
    buffer[i_start] = 0;
    for (int i = i_start; i < i_end; i += i_step)
      buffer[i_start] += gradOutput_k[i] * output_k[i];

    tidx.barrier.wait();
    // reduce
    if (i_start == 0)
    {
      float sum_k = 0;
      for (int i = 0; i < i_step; i++)
        sum_k += buffer[i];

      buffer[0] = sum_k;
    }
    tidx.barrier.wait();

    float sum_k = buffer[0];
    for (int i = i_start; i < i_end; i += i_step)
      gradInput_k[i] = output_k[i] * (gradOutput_k[i] - sum_k);
  });
}

static int gpunn_SoftMax_updateOutput(lua_State *L)
{
  THGPUTensor *input = (THGPUTensor*)luaT_checkudata(L, 2, "torch.GPUTensor");
  THGPUTensor *output = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "output", "torch.GPUTensor");

  input = THGPUTensor_newContiguous(input);
  THGPUTensor_resizeAs(output, input);

  auto avInput = input->get_array_view();
  auto avOutput = output->get_array_view();

  if (input->nDimension == 1)
  {
    gpunn_SoftMax_updateOutput_kernel(avOutput, output->storageOffset,
                                      avInput, input->storageOffset,
                                      1, input->size[0]);
  }
  else if (input->nDimension == 2)
  {
    gpunn_SoftMax_updateOutput_kernel(avOutput, output->storageOffset,
                                      avInput, input->storageOffset,
                                      input->size[0], input->size[1]);
  }
  else
    THError("vector or matrix expected");

  THGPUTensor_free(input);
  return 1;
}

struct softmaxupdateGradInput_functor
{
  float value;

  softmaxupdateGradInput_functor(float value_) : value(value_) {}

  float operator()(const float& output, const float& gradOutput) const
  {
    return gradOutput - exp(output)*value;
  }
};

static int gpunn_SoftMax_updateGradInput(lua_State *L)
{
  THGPUTensor *gradOutput = (THGPUTensor*)luaT_checkudata(L, 3, "torch.GPUTensor");
  THGPUTensor *output = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "output", "torch.GPUTensor");
  THGPUTensor *gradInput = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "gradInput", "torch.GPUTensor");

  output = THGPUTensor_newContiguous(output);
  gradOutput = THGPUTensor_newContiguous(gradOutput);
  THGPUTensor_resizeAs(gradInput, output);

  auto avGradInput = gradInput->get_array_view();
  auto avOutput = output->get_array_view();
  auto avGradOutput = gradOutput->get_array_view();

  if (gradInput->nDimension == 1)
  {
    gpunn_SoftMax_updateGradInput_kernel(avGradInput, gradInput->storageOffset,
                                         avOutput, output->storageOffset,
                                         avGradOutput, gradOutput->storageOffset,
                                         1, gradInput->size[0]);
  }
  else if (gradInput->nDimension == 2)
  {
    gpunn_SoftMax_updateGradInput_kernel(avGradInput, gradInput->storageOffset,
                                         avOutput, output->storageOffset,
                                         avGradOutput, gradOutput->storageOffset,
                                         gradInput->size[0], gradInput->size[1]);
  }
  else
    THError("vector or matrix expected");

  THGPUTensor_free(gradOutput);
  THGPUTensor_free(output);
  return 1;
}

static const struct luaL_Reg gpunn_SoftMax__ [] = {
  {"SoftMax_updateOutput", gpunn_SoftMax_updateOutput},
  {"SoftMax_updateGradInput", gpunn_SoftMax_updateGradInput},
  {NULL, NULL}
};

static void gpunn_SoftMax_init(lua_State *L)
{
  luaT_pushmetatable(L, "torch.GPUTensor");
  luaT_registeratname(L, gpunn_SoftMax__, "nn");
  lua_pop(L,1);
}
