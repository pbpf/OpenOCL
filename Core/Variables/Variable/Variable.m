% Copyright 2019 Jonas Koenemann, Moritz Diehl, University of Freiburg
% Redistribution is permitted under the 3-Clause BSD License terms. Please
% ensure the above copyright notice is visible in any derived work.
%
classdef Variable < handle
    % VARIABLE Default implementation of arithemtic operations for
    % variables
    % This class can be derived from to implement new arithemtics for 
    % variables e.g. casadi variables, or symbolic variables.
    
  properties (Constant)
      MAX_DISP_LENGTH = 200
      DISP_FLOAT_PREC = 6;
   end
  
  properties
    val
    positions
    type
  end
  
  methods (Static)
    
    %%% factory methods
    function var = create(type,value)
      if isnumeric(value)
        var = Variable.createNumeric(type,value);
      elseif isa(value,'casadi.MX') || isa(value,'casadi.SX')
        var = CasadiVariable.createFromValue(type,value);
      else
        oclError('Not implemented for this type of variable.')
      end
    end
    
    function var = createFromVar(type,pos,var)
      if isa(var, 'CasadiVariable')
        var = CasadiVariable(type,pos,var.mx,var.val);
      elseif isa(var,'SymVariable')
        var = SymVariable(type,pos,var.val);
      else
        var = Variable(type,pos,var.val);
      end
    end

    function obj = Matrix(value)
      % obj = createMatrixLike(input,value)
      t = OclMatrix(size(value));
      obj = Variable.create(t,value);
    end
    
    function var = createNumeric(type,value)
        [N,M,K] = type.size();
        v = OclValue(zeros(1,N,M,K));
        p = reshape(1:N*M*K,N,M,K);
        var = Variable(type,p,v);
        var.set(value);
    end
    
    function v = createFromHandleOne(fh, a, varargin)
      a = Variable.getValue(a);
      v = Variable.Matrix( fh(a, varargin{:}) );
    end
    
    function v = createFromHandleTwo(fh, a, b, varargin)
      a = Variable.getValue(a);
      b = Variable.getValue(b);
      if isnumeric(a) && ((isa(b,'casadi.SX')||isa(b,'casadi.MX')))
        a = casadi.DM(a);  
      end
      v = Variable.Matrix(fh(a,b,varargin{:}));
    end
    %%% end factory methods   
    function value = getValue(value)
      if isa(value,'Variable')
        value = value.value;
      end
    end
    
    function value = getValueAsColumn(value)
      value = Variable.getValue(value);
      value = value(:);
    end
  end % methods(static)
  
  methods
    function self = Variable(type,positions,val)
      narginchk(3,3);
      assert(isa(type,'OclStructure'));
      assert(isnumeric(positions));
      assert(isa(val,'OclValue'));
      self.type = type;
      self.positions = positions;
      self.val = val;
    end
    
    function r = str(self,valueStr)
      if nargin==1
        value = self.value;
        if isnumeric(value)
          valueStr = mat2str(self.value,Variable.DISP_FLOAT_PREC);
        else
          % cell array
          cell2str = cellfun(@(v)[mat2str(v),','],value, 'UniformOutput',false);
          str_joined = strjoin(cell2str);
          valueStr = ['{', str_joined(1:end-1), '}'];
        end
      end
      
      dotsStr = '';
      if numel(valueStr) >= Variable.MAX_DISP_LENGTH 
        valueStr = valueStr(1:Variable.MAX_DISP_LENGTH);
        dotsStr = '...';
      end
      
      childrenString = '  Children: None\n';
      if ~isempty(fieldnames(self.type.children))
        cArray = cell(1, length(fieldnames(self.type.children)));
        names = fieldnames(self.type.children);
        for i=1:length(names)-1
          cArray{i} = [names{i}, ', '];
        end
        cArray{end} = names{end};
        childrenString = ['  Children: ', cArray{:}, '\n'];
      end
      
      r = sprintf([ ...
                   class(self), ':\n' ....
                   '  Size: ', mat2str(self.size()), '\n' ....
                   '  Type: ', class(self.type), '\n' ...
                   childrenString, ...
                   '  Value: ', valueStr, dotsStr, '\n' ...
                   ]);
    end
    
    function disp(self)
      disp(self.str());
    end
    
    
    function c = children(self)
      % returns names of children
      c = fieldnames(self.type.children);
    end

    function varargout = subsref(self,s)
      % v(1)
      % v.x
      % v.value
      % v.set(4)
      % v.dot(w)
      % ...
      
      if numel(s) == 1 && strcmp(s.type,'()')
        % v(1)
        [varargout{1}] = self.slice(s.subs{:});
      elseif numel(s) > 1 && strcmp(s(1).type,'()')
        % v(1).something().a
        v = self.slice(s(1).subs{:});
        [varargout{1:nargout}] = subsref(v,s(2:end));
      elseif numel(s) > 0 && strcmp(s(1).type,'.')
        % v.something or v.something()
        id = s(1).subs;
        if isfield(self.type.children,id) && numel(s) == 1
          % v.x
          [varargout{1}] = self.get(id);
        elseif isfield(self.type.children,id)
          % v.x.get(3).set(2).value || v.x.y.get(1)
          v = self.get(id);
          [varargout{1:nargout}] = subsref(v,s(2:end));
        else
          % v.slice(1) || v.get(id)
          [varargout{1:nargout}] = builtin('subsref',self,s);
        end
      else
        oclError('Not supported.');
      end
    end % subsref
    
    function self = subsasgn(self,s,v)
      % v = 1
      % v(1) = 1
      % v.get(1) = 1
      % v.value(1) = 1
      % v* = Variable
      if numel(s)==1 && strcmp(s(1).type,'.') && ~isfield(self.type.children,s(1).subs)
        self = builtin('subsasgn',self,s,v);
      else
        v = Variable.getValue(v);
        subVar = subsref(self,s);
        subVar.set(v);
      end
    end
    
    % TODO: test	
    function n = numArgumentsFromSubscript(~,~,~)	
      n=1;
    end	

    %%% delegate methods to OclValue
    function set(self,val,varargin)
      % set(value)
      % set(value,slice1,slice2,slice3)
      self.val.set(self.type,self.positions,val,varargin{:})
    end
    function v = value(self)
      v = self.val.value(self.type,self.positions);
    end
    %%%    
    
    function s = size(self)
      s = size(self.positions);      
    end

    function ind = end(self,k,n)
       szd = size(self.positions);
       if k < n
          ind = szd(k);
       else
          ind = prod(szd(k:end));
       end
    end

    function r = get(self,id)
      % r = get(id)
      [t,p] = self.type.get(id,self.positions);
      r = Variable.createFromVar(t,p,self);
    end
    
    function r = slice(self,varargin)
      % r = get(dim1,dim2,dim3)
      p = self.positions(varargin{:});
      r = Variable.createFromVar(self.type,p,self);
    end

    function toJSON(self,path,name,varargin)
      % toJSON(self,path,name,opt)
      if nargin==1
        path = fullfile(getenv('OPENOCL_WORK'),[datestr(now,'yyyymmddHHMM'),'var.json']);
      end
      if nargin<=2
        name = 'var';
      end
      s = self.toStruct();
      savejson(name,s,path);
      disp(['json saved to ', path]);
    end
   
    function r = toStruct(self)
      r = self.type.toStruct(self.value);
    end
    
    function y = linspace(d1,d2,n)
      n1 = n-1;
      y = d1 + (0:n1).*(d2 - d1)/n1;
    end
    
    %%% operators
    % single argument
    function v = uplus(self)
      v = Variable.createFromHandleOne(@(self,varargin)uplus(self),self);
    end
    function v = uminus(self)
      v = Variable.createFromHandleOne(@(self,varargin)uminus(self),self);
    end
   
    function v = ctranspose(self)
      oclWarning(['Complex transpose is not defined. Using matrix transpose ', ...
                  'instead. Use the .'' operator instead on the '' operator!']);
      v = self.transpose();
    end
    function v = transpose(self)
      v = Variable.createFromHandleOne(@(self,varargin)transpose(self),self);
    end
    
    function v = reshape(self,varargin)
      v = Variable.createFromHandleOne(@(self,varargin)reshape(self,varargin{:}),self,varargin{:});
    end
    
    function v = triu(self)
      v = Variable.createFromHandleOne(@(self,varargin)triu(self),self);
    end
    
    function v = repmat(self,varargin)
      v = Variable.createFromHandleOne(@(self,varargin)repmat(self,varargin{:}),self,varargin{:});
    end
    
    function v = sum(self)
      v = Variable.createFromHandleOne(@(self,varargin)sum(self),self);
    end
    
    function v = norm(self,varargin)
      v = Variable.createFromHandleOne(@(self,varargin)norm(self,varargin{:}),self,varargin{:});
    end
    
    function v = inv(self)
      v = Variable.createFromHandleOne(@(self,varargin)inv(self),self);
    end
    
    function v = det(self)
      v = Variable.createFromHandleOne(@(self,varargin)det(self),self);
    end
    
    function v = trace(self)
      v = Variable.createFromHandleOne(@(self,varargin)trace(self),self);
    end
    
    function v = diag(self)
      v = Variable.createFromHandleOne(@(self,varargin)diag(self),self);
    end
    
    function v = abs(self)
      v = Variable.createFromHandleOne(@(self,varargin)abs(self),self);
    end

    function v = sqrt(self)
      v = Variable.createFromHandleOne(@(self,varargin)sqrt(self),self);
    end
    
    function v = sin(self)
      v = Variable.createFromHandleOne(@(self,varargin)sin(self),self);
    end
    
    function v = cos(self)
      v = Variable.createFromHandleOne(@(self,varargin)cos(self),self);
    end
    
    function v = tan(self)
      v = Variable.createFromHandleOne(@(self,varargin)tan(self),self);
    end
    
    function v = atan(self)
      v = Variable.createFromHandleOne(@(self,varargin)atan(self),self);
    end
    
    function v = asin(self)
      v = Variable.createFromHandleOne(@(self,varargin)asin(self),self);
    end
    
    function v = acos(self)
      v = Variable.createFromHandleOne(@(self,varargin)acos(self),self);
    end
    
    function v = tanh(self)
      v = Variable.createFromHandleOne(@(self,varargin)tanh(self),self);
    end
    
    function v = cosh(self)
      v = Variable.createFromHandleOne(@(self,varargin)cosh(self),self);
    end
    
    function v = sinh(self)
      v = Variable.createFromHandleOne(@(self,varargin)sinh(self),self);
    end
    
    function v = atanh(self)
      v = Variable.createFromHandleOne(@(self,varargin)atanh(self),self);
    end
    
    function v = asinh(self)
      v = Variable.createFromHandleOne(@(self,varargin)asinh(self),self);
    end
    
    function v = acosh(self)
      v = Variable.createFromHandleOne(@(self,varargin)acosh(self),self);
    end
    
    function v = exp(self)
      v = Variable.createFromHandleOne(@(self,varargin)exp(self),self);
    end
    
    function v = log(self)
      v = Variable.createFromHandleOne(@(self,varargin)log(self),self);
    end
    
    % two arguments
    function v = mtimes(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)mtimes(a,b),a,b);
    end
    
    function v = mpower(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)mpower(a,b),a,b);
    end
    
    function v = mldivide(a,b)
      a = Variable.getValue(a);
      b = Variable.getValue(b);
      if (numel(a) > 1) && (numel(b) > 1)
        v = Variable.Matrix(solve(a,b));
      else
        v = Variable.Matrix(mldivide(a,b));
      end
    end
    
    function v = mrdivide(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)mrdivide(a,b),a,b);
    end
    
    function v = cross(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)cross(a,b),a,b);
    end
    
    function v = dot(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)dot(a,b),a,b);
    end
    
    function v = polyval(p,a)
      v = Variable.createFromHandleTwo(@(p,a,varargin)polyval(p,a),p,a);
    end
    
    function v = jacobian(ex,arg)
      v = Variable.createFromHandleTwo(@(ex,arg,varargin)jacobian(ex,arg),ex,arg);
    end
    
    function v = plus(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)plus(a,b),a,b);
    end
    
    function v = minus(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)minus(a,b),a,b);
    end
    
    function v = times(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)times(a,b),a,b);
    end
    
    function v = power(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)power(a,b),a,b);
    end
    
    function v = rdivide(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)rdivide(a,b),a,b);
    end
    
    function v = ldivide(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)ldivide(a,b),a,b);
    end
    
    function v = atan2(a,b)
      v = Variable.createFromHandleTwo(@(a,b,varargin)atan2(a,b),a,b);
    end
    
    % three arguments
    function r = jtimes(ex,arg,v)
      ex = Variable.getValue(ex);
      arg = Variable.getValue(arg);
      v = Variable.getValue(v);
      r = Variable.Matrix(jtimes(ex,arg,v));
    end
    
    % lists
    function v = horzcat(varargin)
      N = numel(varargin);
      outValues = cell(1,N);
      for k=1:numel(varargin)
        outValues{k} = Variable.getValue(varargin{k});
      end    
      v = Variable.Matrix(horzcat(outValues{:}));
    end
    
    function v = vertcat(varargin)
      N = numel(varargin);
      outValues = cell(1,N);
      for k=1:numel(varargin)
        outValues{k} = Variable.getValue(varargin{k});
      end
      v = Variable.Matrix(vertcat(outValues{:}));
    end
    
    %%% element wise operations
    function n = properties(self)
      % DO NOT CHANGE THIS FUNCTION!
      % It is automatically renamed for Octave as properties is not 
      % allowed as a function name.
      %
      % Tab completion in Matlab for custom variables
      n = [fieldnames(self);fieldnames(self.type.children)];	
    end
  end
end

