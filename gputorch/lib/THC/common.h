#pragma once

#include "bolt/amp/functional.h"
#include "bolt/amp/fill.h"
#include "bolt/amp/device_vector.h"
#include "bolt/amp/transform.h"
#include "bolt/amp/transform_reduce.h"
#include "bolt/amp/reduce.h"
#include "bolt/amp/inner_product.h"
#include "bolt/amp/copy.h"

#ifdef DECLARE_BOLT_DEVICE_VECTOR
#undef DECLARE_BOLT_DEVICE_VECTOR
#endif
#define DECLARE_BOLT_DEVICE_VECTOR(host_a, dv_a) \
  Concurrency::array_view<float, 1> *pav_##host_a = static_cast<Concurrency::array_view<float, 1> *>(host_a->storage->allocatorContext);\
  bolt::amp::device_vector<float> dv_a(*pav_##host_a,THGPUTensor_nElement(host_a));

#ifdef DECLARE_BOLT_DEVICE_VECTOR_2
#undef DECLARE_BOLT_DEVICE_VECTOR_2
#endif
#define DECLARE_BOLT_DEVICE_VECTOR_2(host_1, dv_1, host_2, dv_2) \
  DECLARE_BOLT_DEVICE_VECTOR(host_1, dv_1); \
  DECLARE_BOLT_DEVICE_VECTOR(host_2, dv_2);

#ifdef DECLARE_BOLT_DEVICE_VECTOR_3
#undef DECLARE_BOLT_DEVICE_VECTOR_3
#endif
#define DECLARE_BOLT_DEVICE_VECTOR_3(host_1, dv_1, host_2, dv_2, host_3, dv_3) \
  DECLARE_BOLT_DEVICE_VECTOR(host_1, dv_1); \
  DECLARE_BOLT_DEVICE_VECTOR(host_2, dv_2); \
  DECLARE_BOLT_DEVICE_VECTOR(host_3, dv_3);