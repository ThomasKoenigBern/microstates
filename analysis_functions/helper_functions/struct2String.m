%struct2String() - Heloer function that converts a struct to a string
%
% Usage:
%   >> txt = struct2String(s)
%
% Where s is the struct to convert and txt is the result
%
% Copyright (C) 2016 Thomas Koenig, University of Bern, Switzerland, 2016
% thomas.koenig@puk.unibe.ch
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
%

function txt = struct2String(s)

    field = fieldnames(s);
    txt = 'struct(';
    
    for i = 1:numel(field)
        if i > 1
            txt = sprintf('%s,',txt);
        end
        if isnumeric(s.(field{i}))
            txt = sprintf('%s''%s'',%i',txt,field{i},s.(field{i}));
        elseif ischar(s.(field{i}))
            txt = sprintf('%s''%s'',%s',txt,field{i},s.(field{i}));
        elseif islogical(s.(field{i}))
            txt = sprintf('%s''%s'',%i',txt,field{i},s.(field{i}));
        end
    end
    txt = sprintf('%s)',txt);

end


            
            