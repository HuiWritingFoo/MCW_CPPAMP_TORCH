#include "common.h"
#include "amp_math.h"

struct sigmoidupdateOutput_functor
{
  float operator()(const float& input) const restrict(amp,cpu)
  {
    return 1./(1.+ Concurrency::fast_math::exp(-input));
  }
};

static int gpunn_Sigmoid_updateOutput(lua_State *L)
{
  THGPUTensor *input = (THGPUTensor*)luaT_checkudata(L, 2, "torch.GPUTensor");
  THGPUTensor *output = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "output", "torch.GPUTensor");
  THGPUTensor* input_orig = input;
  input = THGPUTensor_newContiguous(input);

  THGPUTensor_resizeAs(output, input);

  DECLARE_BOLT_DEVICE_VECTOR_2(input, input_data, output, output_data);
  bolt::amp::transform(input_data.begin(), input_data.end(), output_data.begin(), sigmoidupdateOutput_functor());


  if (input_orig != input) {
    THGPUTensor_free(input);
    input = NULL;
  }
  return 1;
}

struct sigmoidupdateGradInput_functor
{
  float operator()(const float& output, const float& gradOutput) const restrict(amp,cpu)
  {
    return gradOutput * (1.-output) * output;
  }
};

static int gpunn_Sigmoid_updateGradInput(lua_State *L)
{
  THGPUTensor *output = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "output", "torch.GPUTensor");
  THGPUTensor *gradOutput = (THGPUTensor*)luaT_checkudata(L, 3, "torch.GPUTensor");
  THGPUTensor *gradInput = (THGPUTensor*)luaT_getfieldcheckudata(L, 1, "gradInput", "torch.GPUTensor");
  THGPUTensor *gradOutput_orig = gradOutput;
  gradOutput = THGPUTensor_newContiguous(gradOutput);

  THGPUTensor_resizeAs(gradInput, output);

   DECLARE_BOLT_DEVICE_VECTOR_3(output, output_data, gradInput, gradInput_data, gradOutput, gradOutput_data);
   bolt::amp::transform(output_data.begin(), output_data.end(), gradOutput_data.begin(),gradInput_data.begin(), sigmoidupdateGradInput_functor());

  if (gradOutput_orig != gradOutput) {
    THGPUTensor_free(gradOutput);
    gradOutput = NULL;
  }
  return 1;
}

static const struct luaL_Reg gpunn_Sigmoid__ [] = {
  {"Sigmoid_updateOutput", gpunn_Sigmoid_updateOutput},
  {"Sigmoid_updateGradInput", gpunn_Sigmoid_updateGradInput},
  {NULL, NULL}
};

static void gpunn_Sigmoid_init(lua_State *L)
{
  luaT_pushmetatable(L, "torch.GPUTensor");
  luaT_registeratname(L, gpunn_Sigmoid__, "nn");
  lua_pop(L,1);
}
