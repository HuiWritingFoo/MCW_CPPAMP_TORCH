SET(src 
   THCGeneral.cpp THCStorage.cpp THCTensor.cpp THCTensorCopy.cpp THCTensorConv.cpp THCTensorMath.cpp THCTensorRandom.cpp)

INCLUDE_DIRECTORIES("/opt/clamp/include")
INCLUDE_DIRECTORIES("/opt/clamp/include/c++/v1")

# MCW CLAMP Specific. Version >= 0.3 is Must
#SET (OPENCL_INC "/usr/local/cuda/include")
SET (OPENCL_INC "/opt/AMDAPP/include/")
SET (PREFIX "/opt/clamp")
SET (CLANG_AMP "${PREFIX}/bin/clang++")
SET(CLAMP_CXXFLAGS "-std=c++amp -I/opt/AMDAPP/Bolt/include -I/opt/AMDAPP/include -I/home/neelakandan/Downloads/mcw_cppamp/cppamp-driver-ng/include -I/home/neelakandan/Downloads/mcw_cppamp/cppamp-driver-ng/libc++/libcxx/include")
SET(CLAMP_LDFLAGS  "-std=c++amp -fPIC -rdynamic /home/neelakandan/Downloads/Bolt-1.2-Linux-GCC-4.7.3/lib64/libclBolt.runtime.gcc.a -lOpenCL /home/neelakandan/Downloads/Bolt-1.2-Linux-GCC-4.7.3/lib64/libboost_thread.a -lboost_system /home/neelakandan/Downloads/Bolt-1.2-Linux-GCC-4.7.3/lib64/libboost_date_time.a /home/neelakandan/Downloads/Bolt-1.2-Linux-GCC-4.7.3/lib64/libboost_chrono.a -lpthread -L/home/neelakandan/Downloads/mcw_cppamp/build/build/lib -L/home/neelakandan/Downloads/mcw_cppamp/build/build/Release/lib -L/home/neelakandan/Downloads/mcw_cppamp/build/libc++/libcxx/lib -L/home/neelakandan/Downloads/mcw_cppamp/build/libc++/libcxxrt/lib -Wl,--rpath=/home/neelakandan/Downloads/mcw_cppamp/build/build/Release/lib:/home/neelakandan/Downloads/mcw_cppamp/build/libc++/libcxx/lib:/home/neelakandan/Downloads/mcw_cppamp/build/libc++/libcxxrt/lib -lOpenCL -lc++ -lcxxrt -ldl -Wl,--whole-archive -lmcwamp -Wl,--no-whole-archive ")
SET(CLAMP_SHAREDFLAGS "-shared -fPIC -Wl,-Bsymbolic")


SET_PROPERTY(SOURCE THCStorage.cpp APPEND_STRING PROPERTY COMPILE_FLAGS " ${CLAMP_CXXFLAGS}")
SET_PROPERTY(SOURCE THCTensor.cpp APPEND_STRING PROPERTY COMPILE_FLAGS " ${CLAMP_CXXFLAGS}")
SET_PROPERTY(SOURCE THCTensorMath.cpp APPEND_STRING PROPERTY COMPILE_FLAGS " ${CLAMP_CXXFLAGS}")
SET_PROPERTY(SOURCE THCTensorConv.cpp APPEND_STRING PROPERTY COMPILE_FLAGS " ${CLAMP_CXXFLAGS}")
SET_PROPERTY(SOURCE THCTensorCopy.cpp APPEND_STRING PROPERTY COMPILE_FLAGS " ${CLAMP_CXXFLAGS}")
SET_PROPERTY(SOURCE THCTensorRandom.cpp APPEND_STRING PROPERTY COMPILE_FLAGS " ${CLAMP_CXXFLAGS}")
SET_PROPERTY(SOURCE THCGeneral.cpp APPEND_STRING PROPERTY COMPILE_FLAGS " ${CLAMP_CXXFLAGS}")



#SET(src-cuda THC.cu)

#CUDA_ADD_LIBRARY(THC SHARED ${src} ${src-cuda})
ADD_LIBRARY(THC SHARED ${src})
TARGET_LINK_LIBRARIES(THC TH)

SET_PROPERTY(TARGET THC APPEND_STRING PROPERTY LINK_FLAGS " ${CLAMP_LDFLAGS} ${CLAMP_SHAREDFLAGS}")

INSTALL(TARGETS THC
          RUNTIME DESTINATION "${Torch_INSTALL_BIN_SUBDIR}"
          LIBRARY DESTINATION "${Torch_INSTALL_LIB_SUBDIR}"
          ARCHIVE DESTINATION "${Torch_INSTALL_LIB_SUBDIR}")

INSTALL(FILES
          THC.h
          THCGeneral.h
          THCGeneral.h
          THCStorage.h
          THCTensor.h
          THCTensorRandom.h
          THCTensorMath.h
          THCTensorConv.h
          DESTINATION "${Torch_INSTALL_INCLUDE_SUBDIR}/THC")