% Copyright 2019 Jonas Koenemann, Moritz Diehl, University of Freiburg
% Redistribution is permitted under the 3-Clause BSD License terms. Please
% ensure the above copyright notice is visible in any derived work.
%
classdef CasadiVariable < Variable
  
  properties
    mx
  end
  
  methods (Static)
  
  
    function var = createFromValue(type,value)
      oclValue = OclValue(value);
      [N,M,K] = size(type);
      p = reshape(1:N*M*K,N,M,K);
      var = CasadiVariable(type,p,isa(value,'casadi.MX'),oclValue);
    end
    
    function var = create(type,mx)
      if isa(type,'OclTree')
        names = fieldnames(type.children);
        id = [names{:}];
      else
        id = class(type);
      end
      
      [N,M,K] = size(type);
      assert(K==1,'Not supported.');
      if N*M*K==0
        vv = [];
      elseif mx == true
        vv = casadi.MX.sym(id,N,M);
      else
        vv = casadi.SX.sym(id,N,M);
      end
      val = OclValue(vv);
      p = reshape(1:N*M*K,N,M,K);
      var = CasadiVariable(type,p,mx,val);
    end
    
    function obj = Matrix(size,mx)
      if nargin==1
        mx = false;
      end
      obj = CasadiVariable.create(OclMatrix(size),mx);
    end
  end
  
  methods
    
    function self = CasadiVariable(type,positions,mx,val)
      % CasadiVariable(type,positions,mx,val)
      narginchk(4,4);      
      self = self@Variable(type,positions,val);
      self.mx = mx;      
    end
    
    function r = disp(self)
      disp(self.str(self.value.str()));
    end
  end
end
