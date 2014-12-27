#include "common.h"

struct hardtanhupdateOutput_functor
{
  float operator()(const float& input) const restrict(amp,cpu)
  {
    if (input < -1)
      return -1;
    else if (input <= 1)
      return input;
    else
      return 1;
  }
};

static int gpunn_HardTanh_updateOutput(lua_State *L)
{
  THGPUTensor *input = (THGPUTensor*)luaT_checkudata(L, 2, "torch.GPUTensor");
  THGPUTensor *output = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "output", "torch.GPUTensor");
  input = THGPUTensor_newContiguous(input);

  THGPUTensor_resizeAs(output, input);

  DECLARE_BOLT_DEVICE_VECTOR_2(input, input_data, output, output_data);
  bolt::amp::transform(input_data.begin(), input_data.end(), output_data.begin(), hardtanhupdateOutput_functor());

  THGPUTensor_free(input);
  return 1;
}

struct hardtanhupdateGradInput_functor
{
  float operator()(const float& input, const float& gradOutput) const restrict(amp,cpu)
  {
    if (input < -1 || input > 1)
      return 0;
    else
      return gradOutput;
  }
};

static int gpunn_HardTanh_updateGradInput(lua_State *L)
{
  THGPUTensor *input = (THGPUTensor*)luaT_checkudata(L, 2, "torch.GPUTensor");
  THGPUTensor *gradOutput = (THGPUTensor*)luaT_checkudata(L, 3, "torch.GPUTensor");
  THGPUTensor *gradInput = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "gradInput", "torch.GPUTensor");

  input = THGPUTensor_newContiguous(input);
  gradOutput = THGPUTensor_newContiguous(gradOutput);

  THGPUTensor_resizeAs(gradInput, input);

   DECLARE_BOLT_DEVICE_VECTOR_3(input, input_data, gradInput, gradInput_data, gradOutput, gradOutput_data);
  bolt::amp::transform(input_data.begin(), input_data.end(), gradOutput_data.begin(),gradInput_data.begin(), hardtanhupdateGradInput_functor());


  THGPUTensor_free(gradOutput);
  THGPUTensor_free(input);
  return 1;
}

static const struct luaL_Reg gpunn_HardTanh__ [] = {
  {"HardTanh_updateOutput", gpunn_HardTanh_updateOutput},
  {"HardTanh_updateGradInput", gpunn_HardTanh_updateGradInput},
  {NULL, NULL}
};

static void gpunn_HardTanh_init(lua_State *L)
{
  luaT_pushmetatable(L, "torch.GPUTensor");
  luaT_registeratname(L, gpunn_HardTanh__, "nn");
  lua_pop(L,1);
}
