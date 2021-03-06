% Copyright 2019 Jonas Koenemann, Moritz Diehl, University of Freiburg
% Redistribution is permitted under the 3-Clause BSD License terms. Please
% ensure the above copyright notice is visible in any derived work.
%
classdef OclConstraint < handle
  %CONSTRAINT OclConstraint
  %   Create, store and access constraints with this class
  
  properties
    values
    lowerBounds
    upperBounds
    obj
  end
  
  methods
    
    function self = OclConstraint(obj)
      self.values = [];
      self.lowerBounds = [];
      self.upperBounds = [];
      self.obj = obj;
    end
    
    function setInitialCondition(self,varargin)
      oclDeprecation('Using of setInitialCondition is deprecated. Just use add instead.');
      self.add(varargin{:});
    end
    
    function addPathConstraint(self,varargin)
      oclDeprecation('Using of addPathConstraint is deprecated. Just use add instead.');
      self.add(varargin{:});
    end
    
    function addBoundaryCondition(self,varargin)
      oclDeprecation('Using of addBoundaryCondition is deprecated. Just use add instead.');
      self.add(varargin{:});
    end
    
    function add(self,varargin)
      % add(self,lhs,op,rhs)
      % add(self,lb,expr,ub)
      % add(self,val)
      
      if nargin==4
        if ischar(varargin{2})
          self.addWithOperator(varargin{1},varargin{2},varargin{3})
        else
          self.addWithBounds(varargin{1},varargin{2},varargin{3})
        end
        
      elseif nargin==2
        self.addWithOperator(varargin{1},'==',0);
      else
        error('Wrong number of arguments');
      end
      
    end
    
    function addWithBounds(self,lb,expr,ub)
      
      lb = Variable.getValueAsColumn(lb);
      expr = Variable.getValueAsColumn(expr);
      ub = Variable.getValueAsColumn(ub);
      
      self.lowerBounds  = [self.lowerBounds;lb];
      self.values       = [self.values;expr];
      self.upperBounds  = [self.upperBounds;ub];
    end
    
    function addWithOperator(self, lhs, op, rhs)
      
      lhs = Variable.getValueAsColumn(lhs);
      rhs = Variable.getValueAsColumn(rhs);
      
      % Create new constraint entry
      if strcmp(op,'==')
        expr = lhs-rhs;
        bound = zeros(size(expr));
        self.values = [self.values;expr];
        self.lowerBounds = [self.lowerBounds;bound];
        self.upperBounds = [self.upperBounds;bound];
        
      elseif strcmp(op,'<=')
        expr = lhs-rhs;
        lb = -inf*ones(size(expr));
        ub = zeros(size(expr));
        self.values = [self.values;expr];
        self.lowerBounds = [self.lowerBounds;lb];
        self.upperBounds = [self.upperBounds;ub];
      elseif strcmp(op,'>=')
        expr = rhs-lhs;
        lb = -inf*ones(size(expr));
        ub = zeros(size(expr));
        self.values = [self.values;expr];
        self.lowerBounds = [self.lowerBounds;lb];
        self.upperBounds = [self.upperBounds;ub];
      else
        error('Operator not supported.');
      end
    end
    
    function appendConstraint(self, constraint)
      self.values = [self.values;constraint.values];
      self.lowerBounds = [self.lowerBounds;constraint.lowerBounds];
      self.upperBounds = [self.upperBounds;constraint.upperBounds];
    end
    
  end
  
end

