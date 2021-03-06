% Copyright 2019 Jonas Koenemann, Moritz Diehl, University of Freiburg
% Redistribution is permitted under the 3-Clause BSD License terms. Please
% ensure the above copyright notice is visible in any derived work.
%

function testOclFunction
  
  fh = @(~,x,y,z)OclFunction_F1(x,y,z);
  fun = OclFunction([],fh,{[3,1],[6,1],[3,3]},2);
  
  x = [4,5,6]';
  y = 10;
  z = eye(3);
  [r1,r2] = fun.evaluate(x,y,z);
  assertEqual(r1,z*x)
  assertEqual(r2,ones(6,1)*y*2)
  
  
  cfun = CasadiFunction(fun);
  [r1,r2] = cfun.evaluate(x,y,z);
  assertEqual(r1,z*x)
  assertEqual(r2,ones(6,1)*y*2)
  
  
end

function [r1,r2] = OclFunction_F1(x,y,z)
  
  xs = OclMatrix([3,1]);
  ys = OclStructure();
  ys.add('x1',xs);
  ys.add('x2',xs);
  zs = OclMatrix([3,3]);
  
  xv = Variable.create(xs,x);
  yv = Variable.create(ys,y);
  zv = Variable.create(zs,z);
  
  r1 = zv*xv;
  r2 = yv * 2;
  
  r1 = r1.value;
  r2 = r2.value;
end

  