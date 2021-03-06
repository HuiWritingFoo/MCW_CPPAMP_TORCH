local gpunntest = {}
local precision_forward = 1e-3
local precision_backward = 1e-2
local nloop = 1
local times = {}

local runtests = false
require 'nn'

if not gputorch then
  require 'gputorch'
  runtests=true
end

--e.g.: th -lgpunn -e "nn.testgpu{'copies'}"
--NW
function gpunntest.copies()
   -- test vector
   local t = torch.GPUTensor(100,10)

   -- simple copy
   t:normal()
   local t2 = t:clone()
   mytester:asserteq( t:add(-1,t2):abs():max(), 0, 'simple copy')

   -- transpose copy
   t:normal()
   local t3 = t:transpose(1,2)
   local t4 = t3:clone()
   mytester:asserteq( t3:add(-1,t4):abs():max(), 0, 'transpose copy')

   -- unfold copy
   t:normal()
   local t5 = t:unfold(2,5,1)
   local t6 = t5:clone()
   mytester:asserteq( t5:add(-1,t6):abs():max(), 0, 'transpose copy')

   -- host copy
   t = torch.FloatTensor(100,10)
   t:normal()
   local tc = t:gpu()
   tc = tc:transpose(1,2)
   local t2 = tc:float()
   mytester:asserteq(t:transpose(1,2):add(-1,t2):abs():max(), 0, 'host copy, plus transpoe')
end

function gpunntest.Tanh_forward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Tanh forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.Tanh()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Tanh():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.Tanh_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Tanh.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.Tanh()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.Abs_forward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Abs forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.Abs()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Abs():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.Abs_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Abs.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.Abs()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.Abs():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.Sigmoid_forward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Sigmoid forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.Sigmoid()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Sigmoid():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

--W
function gpunntest.Sigmoid_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Sigmoid.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.Sigmoid()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.Threshold_forward()
   local size = math.random(1,100)
   local thres = torch.uniform(-1,1)
   local val = torch.uniform(-1,1)

   local tm = {}
   local title = string.format('Threshold forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.Threshold(thres,val)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = sconv:gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.Threshold_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Threshold.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.Threshold()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.Sqrt_forward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Sqrt forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size):abs()
   local sconv = nn.Sqrt()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Sqrt():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.Sqrt_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Sqrt.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size):abs()
   local gradOutput = torch.randn(size)
   local sconv = nn.Sqrt()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

--W
function gpunntest.Square_forward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Square forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.Square()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Square():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.Square_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Square.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.Square()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.Max_forward()
   local size1 = math.random(1,1000)
   local size2 = math.random(2,100)

   local tm = {}
   local title = string.format('Max forward %dx%d', size1, size2)
   times[title] = tm

   local input = torch.randn(size1,size2)
   local sconv = nn.Max(2)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Max(2):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real
     --[[
        TODO: there is memory leak when 'resgpu:float()' call (At least 1 GPU memory allocation)
             type(resgpu) is torch.GPUTensor
      ]]--
   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')

   local error = gconv.indices:float() - sconv.indices
   mytester:assertlt(error:abs():max(), 1e-8, 'error on indices ')
end

function gpunntest.Max_backward()
   local size1 = math.random(1,1000)
   local size2 = math.random(2,100)

   local tm = {}
   local title = string.format('Max.backward %dx%d', size1, size2)
   times[title] = tm

   local input = torch.randn(size1,size2)
   local gradOutput = torch.randn(size1)
   local sconv = nn.Max(2)
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.Min_forward()
   local size1 = math.random(1,1000)
   local size2 = math.random(2,100)

   local tm = {}
   local title = string.format('Min forward %dx%d', size1, size2)
   times[title] = tm

   local input = torch.randn(size1,size2)
   local sconv = nn.Min(2)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Min(2):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')

   local error = gconv.indices:float() - sconv.indices
   mytester:assertlt(error:abs():max(), 1e-8, 'error on indices ')
end

function gpunntest.Min_backward()
   local size1 = math.random(1,1000)
   local size2 = math.random(2,100)

   local tm = {}
   local title = string.format('Min.backward %dx%d', size1, size2)
   times[title] = tm

   local input = torch.randn(size1,size2)
   local gradOutput = torch.randn(size1)
   local sconv = nn.Min(2)
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.Sum_forward()
   local size1 = math.random(1,1000)
   local size2 = math.random(2,100)

   local tm = {}
   local title = string.format('Sum forward %dx%d', size1, size2)
   times[title] = tm

   local input = torch.randn(size1,size2)
   local sconv = nn.Sum(2)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Sum(2):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.Sum_backward()
   local size1 = math.random(1,1000)
   local size2 = math.random(2,100)

   local tm = {}
   local title = string.format('Sum.backward %dx%d', size1, size2)
   times[title] = tm

   local input = torch.randn(size1,size2)
   local gradOutput = torch.randn(size1)
   local sconv = nn.Sum(2)
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.Mean_forward()
   local size1 = math.random(1,1000)
   local size2 = math.random(2,100)

   local tm = {}
   local title = string.format('Mean forward %dx%d', size1, size2)
   times[title] = tm

   local input = torch.randn(size1,size2)
   local sconv = nn.Mean(2)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Mean(2):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.Mean_backward()
   local size1 = math.random(1,1000)
   local size2 = math.random(2,100)

   local tm = {}
   local title = string.format('Mean.backward %dx%d', size1, size2)
   times[title] = tm

   local input = torch.randn(size1,size2)
   local gradOutput = torch.randn(size1)
   local sconv = nn.Mean(2)
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.SpatialConvolutionMM_forward_single()
   local from = math.random(1,32)
   local to = math.random(1,8) * 8
   local ki = math.random(3,15)
   local kj = math.random(3,15)
   local si = 1 -- not supported by CPU version yet
   local sj = si
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialConvolutionMM.forward %dx%dx%d o %dx%d -> %dx%dx%d [s: %dx%d]',
                               from, inj, ini, kj, ki, to, outj, outi, sj, si)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local sconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialConvolutionMM_forward_batch()
   local bs = math.random(1,4) * 2
   local from = math.random(1,32)
   local to = math.random(1,8) * 8
   local ki = math.random(3,15)
   local kj = math.random(3,15)
   local si = 1 -- not supported by CPU version yet
   local sj = si
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialConvolutionMM.forward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d [s: %dx%d]',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi, sj, si)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local sconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialConvolutionMM_backward_single()
   local from = math.random(1,32)
   local to = math.random(1,8) * 8
   local ki = math.random(3,15)
   local kj = math.random(3,15)
   local si = 1 -- not supported by CPU version yet
   local sj = si
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialConvolutionMM.backward %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local gradOutput = torch.randn(to,outj,outi)
   local sconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   local groundweight = sconv.gradWeight
   local groundbias = sconv.gradBias
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   local weightgpu = gconv.gradWeight
   local biasgpu = gconv.gradBias
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad
   local werror = weightgpu:float() - groundweight
   local berror = biasgpu:float() - groundbias

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
   mytester:assertlt(werror:abs():max(), precision_backward, 'error on weight (backward) ')
   mytester:assertlt(berror:abs():max(), precision_backward, 'error on bias (backward) ')
end

function gpunntest.SpatialConvolutionMM_backward_batch()
   local bs = math.random(1,4) * 4
   local from = math.random(1,32)
   local to = math.random(1,8) * 8
   local ki = math.random(3,15)
   local kj = math.random(3,15)
   local si = 1 -- not supported by CPU version yet
   local sj = si
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialConvolutionMM.backward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local gradOutput = torch.randn(bs,to,outj,outi)
   local sconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   local groundweight = sconv.gradWeight
   local groundbias = sconv.gradBias
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   local weightgpu = gconv.gradWeight
   local biasgpu = gconv.gradBias
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad
   local werror = weightgpu:float() - groundweight
   local berror = biasgpu:float() - groundbias

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
   mytester:assertlt(werror:abs():max(), precision_backward, 'error on weight (backward) ')
   mytester:assertlt(berror:abs():max(), precision_backward, 'error on bias (backward) ')
end

-- TODO: transpose is not working
--[[function gpunntest.SpatialConvolutionMM_BHWD_forward_batch()
   local bs = math.random(1,4) * 4
   local from = math.random(1,32)
   local to = math.random(1,8) * 8
   local ki = math.random(3,15)
   local kj = ki
   local si = 1 -- not supported by CPU version yet
   local sj = si
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialConvolutionMM.forward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d [s: %dx%d]',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi, sj, si)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local sconv = nn.SpatialConvolutionMM(from,to,ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real
   input = input:gpu():transpose(2,3):transpose(3,4):contiguous()
   local gconv = nn.SpatialConvolutionMM_BHWD(from,to,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real
   resgpu = resgpu:transpose(4,3):transpose(3,2):contiguous()

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end]]--

function gpunntest.SpatialConvolutionGPU_forward_batch()
   local bs = 32
   local from = 4 * math.random(1,4)
   local to = 32
   local ki = math.random(3,15)
   local kj = ki
   local si = math.random(1,2)
   local sj = si
   local outi = math.random(1,64)
   local outj = outi
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialConvolutionGPU.forward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d [s: %dx%d]',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi, sj, si)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local sconv = nn.SpatialConvolution(from,to,ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:resize(bs,from*ini*inj):t():contiguous():resize(from,ini,inj,bs):gpu()
   local gconv = nn.SpatialConvolutionGPU(from,to,ki,kj,si,sj):gpu()

   local weight = sconv.weight:clone()
   weight:resize(to, from*ki*kj)
   weight = weight:t():contiguous()
   weight:resize(from, kj, ki, to)
   gconv.weight:copy(weight)
   gconv.bias:copy(sconv.bias)

   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   resgpu = resgpu:resize(to*outi*outj,bs):t():contiguous():resize(bs,to,outi,outj):float()

   local error = resgpu - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialConvolutionGPU_backward_batch()
   local bs = 32
   local from = 4 * math.random(1,4)
   local to = 32
   local ki = math.random(5,11)
   local kj = ki
   local si = math.random(1,2)
   local sj = si
   local outi = math.random(4,12)
   local outj = outi
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialConvolution.backward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local gradOutput = torch.randn(bs,to,outj,outi)
   local sconv = nn.SpatialConvolution(from,to,ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   local groundweight = sconv.gradWeight
   local groundbias = sconv.gradBias
   tm.cpu = a:time().real

   input = input:resize(bs,from*ini*inj):t():contiguous():resize(from,ini,inj,bs):gpu()
   gradOutput = gradOutput:resize(bs,to*outi*outj):t():contiguous():resize(to,outi,outj,bs):gpu()
   local gconv = nn.SpatialConvolutionGPU(from,to,ki,kj,si,sj):gpu()

   local weight = sconv.weight:clone()
   weight:resize(to, from*ki*kj)
   weight = weight:t():contiguous()
   weight:resize(from, kj, ki, to)
   gconv.weight:copy(weight)
   gconv.bias:copy(sconv.bias)

   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   local weightgpu = gconv.gradWeight
   local biasgpu = gconv.gradBias
   gputorch.synchronize()
   tm.gpu = a:time().real

   resgpu = resgpu:resize(from*ini*inj,bs):t():contiguous():resize(bs,from,ini,inj)
   weightgpu = weightgpu:resize(from*ki*kj, to):t():contiguous():resize(to, from, ki, kj)

   local error = resgpu:float() - groundgrad
   local werror = weightgpu:float() - groundweight
   local berror = biasgpu:float() - groundbias

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
   mytester:assertlt(werror:abs():max(), precision_backward, 'error on weight (backward) ')
   mytester:assertlt(berror:abs():max(), precision_backward, 'error on bias (backward) ')
end


function gpunntest.SpatialSubSampling_forward()
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   local si = math.random(2,4)
   local sj = math.random(2,4)
   --[[
   -- original
   local outi = math.random(32,256)
   local outj = math.random(32,256)
   ]]--
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialSubSampling.forward %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local sconv = nn.SpatialSubSampling(from,ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialSubSampling(from,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialSubSampling_forward_batch()
   local bs = math.random(4,10)
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   local si = math.random(2,4)
   local sj = math.random(2,4)
   --[[
   -- original
   local outi = math.random(32,256)
   local outj = math.random(32,256)
   ]]--
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialSubSampling.forward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local sconv = nn.SpatialSubSampling(from,ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialSubSampling(from,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialSubSampling_backward()
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(2,4)
   local sj = math.random(2,4)
   ]]--
   
   -- TODO: need to implement atomicAdd for float
   local si = ki
   local sj = kj
   local outi = math.random(32,64)
   local outj = math.random(32,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialSubSampling.backward %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local gradOutput = torch.randn(to,outj,outi)
   local sconv = nn.SpatialSubSampling(from,ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   local groundweight = sconv.gradWeight
   local groundbias = sconv.gradBias
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialSubSampling(from,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   local weightgpu = gconv.gradWeight
   local biasgpu = gconv.gradBias
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad
   local werror = weightgpu:float() - groundweight
   local berror = biasgpu:float() - groundbias

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
   mytester:assertlt(werror:abs():max(), precision_backward, 'error on weight (backward) ')
   mytester:assertlt(berror:abs():max(), precision_backward, 'error on bias (backward) ')
end

function gpunntest.SpatialSubSampling_backward_batch()
   local bs = math.random(4,10)
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(2,4)
   local sj = math.random(2,4)
   ]]--
   -- TODO: Need to implement atomicAdd for float
   local si = ki
   local sj = kj
   local outi = math.random(32,64)
   local outj = math.random(32,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialSubSampling.backward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local gradOutput = torch.randn(bs,to,outj,outi)
   local sconv = nn.SpatialSubSampling(from,ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   local groundweight = sconv.gradWeight
   local groundbias = sconv.gradBias
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialSubSampling(from,ki,kj,si,sj):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   local weightgpu = gconv.gradWeight
   local biasgpu = gconv.gradBias
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad
   local werror = weightgpu:float() - groundweight
   local berror = biasgpu:float() - groundbias

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
   mytester:assertlt(werror:abs():max(), precision_backward, 'error on weight (backward) ')
   mytester:assertlt(berror:abs():max(), precision_backward, 'error on bias (backward) ')
end

function gpunntest.SpatialMaxPooling_forward()
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(1,4)
   local sj = math.random(1,4)
   ]]--
   -- TODO: need to implement atomicAdd for float
   local si = ki
   local sj = kj
 
   --[[
   -- original
   local outi = math.random(32,256)
   local outj = math.random(32,256)
   ]]--
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialMaxPooling.forward %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local sconv = nn.SpatialMaxPooling(ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialMaxPooling(ki,kj,si,sj):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
   local error_ind = gconv.indices:float() - sconv.indices
   mytester:asserteq(error_ind:max(), 0, 'error on indices (forward) ')
end

function gpunntest.SpatialMaxPooling_forward_batch()
   local bs = math.random(4,10)
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(2,4)
   local sj = math.random(2,4)
   --]]

   -- TODO: need to implement atomicAdd for float
   local si = ki
   local sj = kj
 
   --[[
   -- original
   local outi = math.random(32,256)
   local outj = math.random(32,256)
   --]]
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialMaxPooling.forward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local sconv = nn.SpatialMaxPooling(ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialMaxPooling(ki,kj,si,sj):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialMaxPooling_backward()
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(1,4)
   local sj = math.random(1,4)
   ]]--

   -- TODO: need to implement atomicAdd
   local si = ki
   local sj = kj
      
   local outi = math.random(32,64)
   local outj = math.random(32,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialMaxPooling.backward %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local gradOutput = torch.randn(to,outj,outi)
   local sconv = nn.SpatialMaxPooling(ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialMaxPooling(ki,kj,si,sj):gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.SpatialMaxPooling_backward_batch()
   local bs = math.random(4,10)
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   -- enforce testing non-atomic kernel (dW == kW) and (dH == kH)
   local si = ki
   local sj = kj
   local outi = math.random(32,64)
   local outj = math.random(32,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialMaxPooling.backward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local gradOutput = torch.randn(bs,to,outj,outi)
   local sconv = nn.SpatialMaxPooling(ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialMaxPooling(ki,kj,si,sj):gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

-- TOOD: need to implement atomicAdd for float
--[[function gpunntest.SpatialMaxPooling_backward_batch_atomic()
   local bs = math.random(4,10)
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   -- enforce that kW ~= dW or kH ~= dH (which trigers the atomic kernel)
   local si = ki + ((math.random(0,1) == 1) and -math.random(1,ki-1) or math.random(1,2))
   local sj = kj + ((math.random(0,1) == 1) and  -math.random(1,kj-1) or math.random(1,2))
   local outi = math.random(32,64)
   local outj = math.random(32,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialMaxPooling.backward %dx%dx%dx%d o %dx%d (%dx%d) -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, si, sj, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local gradOutput = torch.randn(bs,to,outj,outi)
   local sconv = nn.SpatialMaxPooling(ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialMaxPooling(ki,kj,si,sj):gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end]]--

function gpunntest.SpatialMaxPoolingGPU_forward_batch()
   local bs = 32
   local from = 16 * math.random(1,3)
   local to = from
   local ki = math.random(2,4)
   local kj = ki
   local si = ki
   local sj = kj
   local outi = math.random(16,32)
   local outj = outi
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialMaxPoolingGPU.forward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local sconv = nn.SpatialMaxPooling(ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:resize(bs,from*ini*inj):t():contiguous():resize(from,ini,inj,bs):gpu()
   local gconv = nn.SpatialMaxPoolingGPU(ki,kj,si,sj):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   resgpu = resgpu:resize(to*outi*outj,bs):t():contiguous():resize(bs,to,outi,outj):float()

   local error = resgpu - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialMaxPoolingGPU_backward_batch()
   local bs = 32
   local from = 16 * math.random(1,3)
   local to = from
   local ki = math.random(2,4)
   local kj = ki
   local si = ki
   local sj = kj
   local outi = math.random(16,32)
   local outj = outi
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialMaxPoolingGPU.backward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local gradOutput = torch.randn(bs,to,outj,outi)
   local sconv = nn.SpatialMaxPooling(ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:resize(bs,from*ini*inj):t():contiguous():resize(from,ini,inj,bs):gpu()
   gradOutput = gradOutput:resize(bs,to*outi*outj):t():contiguous():resize(to,outi,outj,bs):gpu()
   local gconv = nn.SpatialMaxPoolingGPU(ki,kj,si,sj):gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   resgpu = resgpu:resize(from*ini*inj,bs):t():contiguous():resize(bs,from,ini,inj)

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end


function gpunntest.SpatialAveragePooling_forward()
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(1,ki)
   local sj = math.random(1,kj)
   --]]
   -- TODO: need to implement atomicAdd for float
   local si = ki
   local sj = kj
   local outi = math.random(32,256)
   local outj = math.random(32,256)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialAveragePooling.forward %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local sconv = nn.SpatialAveragePooling(ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialAveragePooling(ki,kj,si,sj):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialAveragePooling_forward_batch()
   local bs = math.random(4,10)
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(1,ki)
   local sj = math.random(1,kj)
   --]]
   -- TODO: need to implement atomicAdd for float
   local si = ki
   local sj = kj
   local outi = math.random(32,256)
   local outj = math.random(32,256)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialAveragePooling.forward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local sconv = nn.SpatialAveragePooling(ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialAveragePooling(ki,kj,si,sj):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialAveragePooling_backward()
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(1,ki)
   local sj = math.random(1,kj)
   --]]
   -- TODO: need to implement atomicAdd for float
   local si = ki
   local sj = kj
   local outi = math.random(32,64)
   local outj = math.random(32,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialMaxPooling.backward %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local gradOutput = torch.randn(to,outj,outi)
   local sconv = nn.SpatialAveragePooling(ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialAveragePooling(ki,kj,si,sj):gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.SpatialAveragePooling_backward_batch()
   local bs = math.random(4,10)
   local from = math.random(1,64)
   local to = from
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   --[[
   -- original
   local si = math.random(1,ki)
   local sj = math.random(1,kj)
   --]]
   -- TODO: need to implement atomicAdd for float
   local si = ki
   local sj = kj
   local outi = math.random(32,64)
   local outj = math.random(32,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialAveragePooling.backward %dx%dx%dx%d o %dx%d -> %dx%dx%dx%d',
                               bs, from, inj, ini, kj, ki, bs, to, outj, outi)
   times[title] = tm

   local input = torch.randn(bs,from,inj,ini)
   local gradOutput = torch.randn(bs,to,outj,outi)
   local sconv = nn.SpatialAveragePooling(ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.SpatialAveragePooling(ki,kj,si,sj):gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.SpatialLPPooling_forward()
   local from = math.random(1,64)
   local to = from
   local pnorm = 2
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   local si = ki
   local sj = kj
   --[[
   -- original
   local outi = math.random(32,256)
   local outj = math.random(32,256)
   ]]--
   local outi = math.random(1,64)
   local outj = math.random(1,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialLPPooling.forward (P=2 only) %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local sconv = nn.SpatialLPPooling(from,pnorm,ki,kj,si,sj)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SpatialLPPooling(from,pnorm,ki,kj,si,sj):gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialLPPooling_backward()
   local from = math.random(1,64)
   local to = from
   local pnorm = 2
   local ki = math.random(2,4)
   local kj = math.random(2,4)
   local si = ki
   local sj = kj
   local outi = math.random(32,64)
   local outj = math.random(32,64)
   local ini = (outi-1)*si+ki
   local inj = (outj-1)*sj+kj

   local tm = {}
   local title = string.format('SpatialLPPooling.backward (P=2 only) %dx%dx%d o %dx%d -> %dx%dx%d',
                               from, inj, ini, kj, ki, to, outj, outi)
   times[title] = tm

   local input = torch.randn(from,inj,ini)
   local gradOutput = torch.randn(to,outj,outi)
   local sconv = nn.SpatialLPPooling(from,pnorm,ki,kj,si,sj)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.mse()
   for sizeAverage = 0, 1 do
      local size = math.random(3000,5000)
      local input = torch.randn(size,1,1)
      local target = torch.randn(size)
      local mod = nn.MSECriterion(sizeAverage == 1)

      local tm = {}
      local title = string.format('MSECriterion sizeAverage %d, %d ', sizeAverage, size)
      times[title] = tm

      local a = torch.Timer()
      local fout = mod:forward(input,target)
      local fgin = mod:backward(input,target):clone()
      tm.cpu = a:time().real

      local cinput = input:gpu()
      local ctarget = target:gpu()
      local cmod = nn.MSECriterion(sizeAverage == 1):gpu()
      a:reset()
      local cout = cmod:forward(cinput,ctarget)
      local cgin = cmod:backward(cinput,ctarget)
      gputorch.synchronize()
      tm.gpu = a:time().real

      local tm2 = {}
      local title = string.format('MSECriterion2 sizeAverage %d, %d ',sizeAverage, size)
      times[title] = tm2
      tm2.cpu = tm.cpu
      local cinput2 = input:gpu()
      local ctarget2 = target:gpu()
      local cmod2 = nn.MSECriterion(sizeAverage == 1):gpu()
      a:reset()
      local cout2 = cinput2.nn.MSECriterion_updateOutput2(cmod,cinput2,ctarget2)
      local cgin2 = cinput2.nn.MSECriterion_updateGradInput2(cmod,cinput2,ctarget2)
      gputorch.synchronize()
      tm2.gpu = a:time().real

      mytester:assertlt(math.abs(fout-cout), precision_forward, 'error  on output')
      local gerr = cgin:float() - fgin
      mytester:assertlt(gerr:abs():max(), precision_forward, 'error  on gradInput')

      mytester:assertlt(math.abs(fout-cout2), precision_forward, 'error on output - 2')
      local gerr2 = cgin2:float() - fgin
      mytester:assertlt(gerr2:abs():max(), precision_forward, 'error on gradInput -2')
   end
end

function gpunntest.distkldiv()
   for sizeAverage = 0, 1 do
      local size = math.random(3000,5000)
      local input = torch.randn(size,1,1)
      local target = torch.randn(size)
      local mod = nn.DistKLDivCriterion(sizeAverage == 1)

      local tm = {}
      local title = string.format('DistKLDivCriterion sizeAverage %d, %d ',sizeAverage,size)
      times[title] = tm

      local a = torch.Timer()
      local fout = mod:forward(input,target)
      local fgin = mod:backward(input,target):clone()
      tm.cpu = a:time().real

      local cinput = input:gpu()
      local ctarget = target:gpu()
      local cmod = nn.DistKLDivCriterion(sizeAverage == 1):gpu()
      a:reset()
      local cout = cmod:forward(cinput,ctarget)
      local cgin = cmod:backward(cinput,ctarget)
      gputorch.synchronize()
      tm.gpu = a:time().real

      mytester:assertlt(math.abs(fout-cout), precision_forward, 'error  on output')
      local gerr = cgin:float() - fgin
      mytester:assertlt(gerr:abs():max(), precision_backward, 'error  on gradInput')
   end
end

function gpunntest.SoftMax_forward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('SoftMax forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.SoftMax()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SoftMax():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SoftMax_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('SoftMax.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.SoftMax()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.LogSoftMax_forward()
   local size = math.random(1,256)

   local tm = {}
   local title = string.format('LogSoftMax forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.LogSoftMax()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.LogSoftMax():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward*10, 'error on state (forward) ')
end

function gpunntest.LogSoftMax_backward()
   local size = math.random(1,256)

   local tm = {}
   local title = string.format('LogSoftMax.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.LogSoftMax()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.LogSoftMax_forward_batch()
   local size = math.random(1,256)
   local bs = math.random(32,256)

   local tm = {}
   local title = string.format('LogSoftMax forward batch %d x %d -> %d x %d', bs, size, bs, size)
   times[title] = tm

   local input = torch.randn(bs, size)
   local sconv = nn.LogSoftMax()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.LogSoftMax():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward*10, 'error on state (forward) ')
end

function gpunntest.LogSoftMax_backward_batch()
   local size = math.random(1,256)
   local bs = math.random(32,256)

   local tm = {}
   local title = string.format('LogSoftMax.backward batch %d x %d -> %d x %d', bs, size, bs, size)
   times[title] = tm

   local input = torch.randn(bs, size)
   local gradOutput = torch.randn(bs, size)
   local sconv = nn.LogSoftMax()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

--[[function gpunntest.TemporalConvolution_forward()
   local from = math.random(1,64) -- inputFrameSize
   local to = math.random(1,64) -- outputFrameSize
   local ki = math.random(3,15) -- kernelWidth (kW)
   local si = math.random(1,2) -- stepSize (dW)
   local outi = math.random(1,256) -- nOutputFrame
   local ini = (outi-1)*si+ki -- nInputFrame

   local tm = {}
   local title = string.format('TemporalConvolution.forward %dx%d o %d -> %dx%d [s: %d]',
                               from, ini, ki, to, outi, si)
   times[title] = tm

   local input = torch.randn(ini,from)
   local sconv = nn.TemporalConvolution(from,to,ki,si)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.TemporalConvolution(from,to,ki,si):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.TemporalConvolution_forward_batch()
   local bs = math.random(4,16)
   local from = math.random(1,64)
   local to = math.random(1,64)
   local ki = math.random(3,15)
   local si = math.random(1,2)
   local outi = math.random(1,256)
   local ini = (outi-1)*si+ki

   local tm = {}
   local title = string.format('TemporalConvolution.forward %dx%dx%d o %d -> %dx%dx%d [s: %d]',
                               bs, from, ini, ki, bs, to, outi, si)
   times[title] = tm

   local input = torch.randn(bs,ini,from)
   local sconv = nn.TemporalConvolution(from,to,ki,si)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.TemporalConvolution(from,to,ki,si):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.TemporalConvolution_backward()
  local from = math.random(1,64)
   local to = math.random(1,64)
   local ki = math.random(3,15)
   local si = math.random(1,2)
   local outi = math.random(1,256)
   local ini = (outi-1)*si+ki

   local tm = {}
   local title = string.format('TemporalConvolution.backward %dx%d o %d -> %dx%d',
                               from, ini, ki, to, outi)

   times[title] = tm

   local input = torch.randn(ini,from)
   local gradOutput = torch.randn(outi,to)
   local sconv = nn.TemporalConvolution(from,to,ki,si)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   local groundweight = sconv.gradWeight
   local groundbias = sconv.gradBias
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.TemporalConvolution(from,to,ki,si):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   local weightgpu = gconv.gradWeight
   local biasgpu = gconv.gradBias
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad
   local werror = weightgpu:float() - groundweight
   local berror = biasgpu:float() - groundbias

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
   mytester:assertlt(werror:abs():max(), precision_backward, 'error on weight (backward) ')
   mytester:assertlt(berror:abs():max(), precision_backward, 'error on bias (backward) ')
end

function gpunntest.TemporalConvolution_backward_batch()
   local bs = math.random(4,16)
   local from = math.random(1,64)
   local to = math.random(1,64)
   local ki = math.random(3,15)
   local si = math.random(1,2)
   local outi = math.random(1,256)
   local ini = (outi-1)*si+ki

   local tm = {}
   local title = string.format('TemporalConvolution.backward %dx%dx%d o %d -> %dx%dx%d',
                               bs, from, ini, ki, bs, to, outi)
   times[title] = tm

   local input = torch.randn(bs,ini,from)
   local gradOutput = torch.randn(bs,outi,to)
   local sconv = nn.TemporalConvolution(from,to,ki,si)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   local groundweight = sconv.gradWeight
   local groundbias = sconv.gradBias
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = nn.TemporalConvolution(from,to,ki,si):gpu()
   gconv.weight = sconv.weight:gpu()
   gconv.bias = sconv.bias:gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   local weightgpu= gconv.gradWeight
   local biasgpu = gconv.gradBias
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad
   local werror = weightgpu:float() - groundweight
   local berror = biasgpu:float() - groundbias

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
   mytester:assertlt(werror:abs():max(), precision_backward, 'error on weight (backward) ')
   mytester:assertlt(berror:abs():max(), precision_backward, 'error on bias (backward) ')
end]]--

function gpunntest.Exp_forward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Exp forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.Exp()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.Exp():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.Exp_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('Exp.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.Exp()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end


function gpunntest.SoftPlus_forward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('SoftPlus forward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local sconv = nn.SoftPlus()
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = nn.SoftPlus():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SoftPlus_backward()
   local size = math.random(1,100)

   local tm = {}
   local title = string.format('SoftPlus.backward %d -> %d', size, size)
   times[title] = tm

   local input = torch.randn(size)
   local gradOutput = torch.randn(size)
   local sconv = nn.SoftPlus()
   sconv:forward(input)
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.SpatialUpSamplingNearest_forward()
   local f = torch.random(3, 15)
   local h = torch.random(3, 15)
   local w = torch.random(3, 15)
   local scale = torch.random(2,5)

   local tm = {}
   local title = string.format('SpatialUpSamplingNearest.forward %dx%dx%d -> %dx%dx%d',
                               f, h, w, f, h*scale, w*scale)
   times[title] = tm

   local input = torch.randn(f, h, w)
   local sconv = nn.SpatialUpSamplingNearest(scale)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = sconv:clone():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')
end

function gpunntest.SpatialUpSamplingNearest_forward_batch()
   local nbatch = torch.random(3, 15)
   local f = torch.random(3, 15)
   local h = torch.random(3, 15)
   local w = torch.random(3, 15)
   local scale = torch.random(2,5)

   local tm = {}
   local title = string.format('SpatialUpSamplingNearest.forward %dx%dx%dx%d -> %dx%dx%dx%d',
                               nbatch, f, h, w, nbatch, f, h*scale, w*scale)
   times[title] = tm

   local input = torch.randn(nbatch, f, h, w)
   local sconv = nn.SpatialUpSamplingNearest(scale)
   local groundtruth = sconv:forward(input)
   local a = torch.Timer()
   for i = 1,nloop do
      groundtruth = sconv:forward(input)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   local gconv = sconv:clone():gpu()
   local resgpu = gconv:forward(input)
   a:reset()
   for i = 1,nloop do
      resgpu = gconv:forward(input)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundtruth
   mytester:assertlt(error:abs():max(), precision_forward, 'error on state (forward) ')

end

function gpunntest.SpatialUpSamplingNearest_backward()
   local f = torch.random(3, 15)
   local h = torch.random(3, 15)
   local w = torch.random(3, 15)
   local scale = torch.random(2,5)

   local tm = {}
   local title = string.format('SpatialUpSamplingNearest.backward %dx%dx%d -> %dx%dx%d',
                               f, h, w, f, h*scale, w*scale)
   times[title] = tm

   local input = torch.randn(f, h, w)
   local gradOutput = torch.randn(f, h*scale, w*scale)
   local sconv = nn.SpatialUpSamplingNearest(scale)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.SpatialUpSamplingNearest_backward_batch()
   local nbatch = torch.random(3, 15)
   local f = torch.random(3, 15)
   local h = torch.random(3, 15)
   local w = torch.random(3, 15)
   local scale = torch.random(2,5)

   local tm = {}
   local title = string.format('SpatialUpSamplingNearest.backward %dx%dx%dx%d -> %dx%dx%dx%d',
                               nbatch, f, h, w, nbatch, f, h*scale, w*scale)
   times[title] = tm

   local input = torch.randn(nbatch, f, h, w)
   local gradOutput = torch.randn(nbatch, f, h*scale, w*scale)
   local sconv = nn.SpatialUpSamplingNearest(scale)
   sconv:forward(input)
   sconv:zeroGradParameters()
   local groundgrad = sconv:backward(input, gradOutput)
   local a = torch.Timer()
   for i = 1,nloop do
      sconv:zeroGradParameters()
      groundgrad = sconv:backward(input, gradOutput)
   end
   tm.cpu = a:time().real

   input = input:gpu()
   gradOutput = gradOutput:gpu()
   local gconv = sconv:clone():gpu()
   gconv:forward(input)
   gconv:zeroGradParameters()
   local resgpu = gconv:backward(input, gradOutput)
   a:reset()
   for i = 1,nloop do
      gconv:zeroGradParameters()
      resgpu = gconv:backward(input, gradOutput)
   end
   gputorch.synchronize()
   tm.gpu = a:time().real

   local error = resgpu:float() - groundgrad

   mytester:assertlt(error:abs():max(), precision_backward, 'error on state (backward) ')
end

function gpunntest.l1cost()
   local size = math.random(300,500)
   local input = torch.randn(size)
   local mod = nn.L1Cost()
   local tm = {}
   local title = string.format('L1Cost %d ',size)
   times[title] = tm
   local a = torch.Timer()
   local fout = mod:forward(input)
   local fgin = mod:backward(input):clone()
   tm.cpu = a:time().real
   local cinput = input:gpu()
   local cmod = nn.L1Cost():gpu()
   a:reset()
   local cout = cmod:forward(cinput)
   local cgin = cmod:backward(cinput)
   gputorch.synchronize()
   tm.gpu = a:time().real
   mytester:assertlt(math.abs(fout-cout), precision_forward, 'error on output')
   local gerr = cgin:float() - fgin
   mytester:assertlt(gerr:abs():max(), precision_forward, 'error on gradInput')
end

--[[function gpunntest.ClassNLLCriterionSingleTarget()
   local size = math.random(3000,5000)
   local input = torch.randn(size)
   local target = 1
   local mod = nn.ClassNLLCriterion()

   local tm = {}
   local title = string.format('ClassNLLCriterionSingleTarget %d ',size)
   times[title] = tm

   local a = torch.Timer()
   local fout = mod:forward(input, target)
   local fgin = mod:backward(input, target):clone()
   tm.cpu = a:time().real

   local cinput = input:gpu()
   local ctarget = torch.GPUTensor(1):fill(target)
   local cmod = nn.ClassNLLCriterion():gpu()
   a:reset()
   local cout = cmod:forward(cinput,ctarget)
   local cgin = cmod:backward(cinput,ctarget)
   gputorch.synchronize()
   tm.gpu = a:time().real

   mytester:assertlt(
       math.abs(fout-cout), precision_forward, 'error  on output')
   local gerr = cgin:float() - fgin
   mytester:assertlt(gerr:abs():max(), precision_forward, 'error  on gradInput')
end]]--

function gpunntest.ClassNLLCriterionMultipleTarget()
   local size = math.random(3000,5000)
   local input = torch.randn(size, size)
   local target = torch.randperm(size)
   local mod = nn.ClassNLLCriterion()

   local tm = {}
   local title = string.format('ClassNLLCriterionMultiTarget %d ',size)
   times[title] = tm

   local a = torch.Timer()
   local fout = mod:forward(input, target)
   local fgin = mod:backward(input, target):clone()
   tm.cpu = a:time().real

   local cinput = input:gpu()
   local ctarget = target:gpu()
   local cmod = nn.ClassNLLCriterion():gpu()
   a:reset()
   local cout = cmod:forward(cinput,ctarget)
   local cgin = cmod:backward(cinput,ctarget)
   gputorch.synchronize()
   tm.gpu = a:time().real

   mytester:assertlt(
       math.abs(fout-cout), precision_forward, 'error on output')

   local gerr = cgin:float() - fgin
   mytester:assertlt(gerr:abs():max(), precision_forward, 'error  on gradInput')
end

function nn.testgpu(tests)
   local oldtype = torch.getdefaulttensortype()
   torch.setdefaulttensortype('torch.FloatTensor')
   math.randomseed(os.time())
   mytester = torch.Tester()
   mytester:add(gpunntest)
   mytester:run(tests)
   torch.setdefaulttensortype(oldtype)
   print ''
   print ' ------------------------------------------------------------------------------------------------'
   print '|  Module                                                                          |  Speedup    |'
   print ' ------------------------------------------------------------------------------------------------'
   for module,tm in pairs(times) do
      local str = string.format('| %-80s | %4.2f        |', module, (tm.cpu / (tm.gpu or 1e6)))
      print(str)
   end
   print ' ------------------------------------------------------------------------------------------------'
end

if runtests then 
  require 'gpunn'
  nn.testgpu()
end
