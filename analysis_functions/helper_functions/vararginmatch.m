function i = vararginmatch(v,str)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License
if iscell(v(1))
    for i = 1:numel(v)
        if strcmp(v{i},str)
            return
        end
    end
else
    if strcmp(v,str)
        i = 1;
    end
end
i = 0;            
