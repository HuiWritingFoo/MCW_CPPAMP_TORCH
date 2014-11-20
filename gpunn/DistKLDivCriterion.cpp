/*#include <thrust/fill.h>
#include <thrust/functional.h>
#include <thrust/reduce.h>
#include <thrust/inner_product.h>*/
#include <numeric>

struct kl_functor
{
  kl_functor() {}

  float operator()(const float& x, const float& y) const
  {
    return y > 0 ? y * (log(y) - x) : 0;
  }
};

static int cunn_DistKLDivCriterion_updateOutput(lua_State *L)
{
  THCudaTensor *input = (THCudaTensor*)luaT_checkudata(L, 2, "torch.CudaTensor");
  THCudaTensor *target = (THCudaTensor*)luaT_checkudata(L, 3, "torch.CudaTensor");
  int sizeAverage = luaT_getfieldcheckboolean(L, 1, "sizeAverage");

  float sum;

  long size = THCudaTensor_nElement(input);

  input = THCudaTensor_newContiguous(input);
  target = THCudaTensor_newContiguous(target);

  std::vector<float> input_data(THCudaTensor_data(input), THCudaTensor_data(input) + THCudaTensor_nElement(input));
  std::vector<float> target_data(THCudaTensor_data(target), THCudaTensor_data(target) + THCudaTensor_nElement(target));
  sum = std::inner_product(input_data.begin(), input_data.end(), target_data.begin(), (float) 0, std::plus<float>(), kl_functor());
  if (sizeAverage)
    sum /= size;

  THCudaTensor_free(input);
  THCudaTensor_free(target);

  lua_pushnumber(L, sum);
  lua_setfield(L, 1, "output");

  lua_pushnumber(L, sum);
  return 1;
}

struct kl_updateGradInput_functor
{
  const float norm;

  kl_updateGradInput_functor(float norm_) : norm(norm_) {}

  float operator()(const float& x, const float& y) const
  {
    return y > 0 ? norm * (-y) : 0;
  }
};

static int cunn_DistKLDivCriterion_updateGradInput(lua_State *L)
{
  THCudaTensor *input = (THCudaTensor*)luaT_checkudata(L, 2, "torch.CudaTensor");
  THCudaTensor *target = (THCudaTensor*)luaT_checkudata(L, 3, "torch.CudaTensor");
  int sizeAverage = luaT_getfieldcheckboolean(L, 1, "sizeAverage");
  THCudaTensor *gradInput = (THCudaTensor*)luaT_getfieldcheckudata(L, 1, "gradInput", "torch.CudaTensor");

  long size = THCudaTensor_nElement(input);
  float norm = (sizeAverage ? 2./size : 2.);

  input = THCudaTensor_newContiguous(input);
  target = THCudaTensor_newContiguous(target);

  THCudaTensor_resizeAs(gradInput, input);

  /*thrust::device_ptr<float> input_data(THCudaTensor_data(input));
  thrust::device_ptr<float> target_data(THCudaTensor_data(target));
  thrust::device_ptr<float> gradInput_data(THCudaTensor_data(gradInput));

  thrust::transform(input_data, input_data+size, target_data, gradInput_data, kl_updateGradInput_functor(norm));*/
  std::vector<float> input_data(THCudaTensor_data(input), THCudaTensor_data(input) + THCudaTensor_nElement(input));
  std::vector<float> target_data(THCudaTensor_data(target), THCudaTensor_data(target) + THCudaTensor_nElement(target));
  std::vector<float> gradInput_data(THCudaTensor_data(gradInput), THCudaTensor_data(gradInput) + THCudaTensor_nElement(gradInput));

  std::transform(input_data.begin(), input_data.end(), target_data.begin(), gradInput_data.begin(), kl_updateGradInput_functor(norm));

  std::copy(gradInput_data.begin(), gradInput_data.end(),gradInput->storage->data);
  THCudaTensor_free(input);
  THCudaTensor_free(target);
  return 1;
}

static const struct luaL_Reg cunn_DistKLDivCriterion__ [] = {
  {"DistKLDivCriterion_updateOutput", cunn_DistKLDivCriterion_updateOutput},
  {"DistKLDivCriterion_updateGradInput", cunn_DistKLDivCriterion_updateGradInput},
  {NULL, NULL}
};

static void cunn_DistKLDivCriterion_init(lua_State *L)
{
  luaT_pushmetatable(L, "torch.CudaTensor");
  luaT_registeratname(L, cunn_DistKLDivCriterion__, "nn");
  lua_pop(L,1);
}
