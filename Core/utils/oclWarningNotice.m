% Copyright 2019 Jonas Koenemann, Moritz Diehl, University of Freiburg
% Redistribution is permitted under the 3-Clause BSD License terms. Please
% ensure the above copyright notice is visible in any derived work.
%
function oclWarningNotice()
  global oclHasWarnings
  if ~isempty(oclHasWarnings) && oclHasWarnings
    oclWarning(['There have been warnings in OpenOCL. Resolve all warnings ',...
                'before you proceed as they point to potential issues.']);
    oclHasWarnings = false;
  end