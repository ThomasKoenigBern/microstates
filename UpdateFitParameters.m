%UpdateFitParameters() Updates the parameters for the fitting 
%   
% Usage: function [pars, iscomplete] = UpdateFitParameters(inPars, DefPars, FieldNames)
%
% Returns a structure with the elements of inPars, and those elements of
% DefPars listed in FieldNames that do not exist in inPars (defaults) and a
% flag if all parameters are there
%
% Author: Thomas Koenig, University of Bern, Switzerland, 2016
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

function [pars, iscomplete] = UpdateFitParameters(inPars, DefPars, FieldNames)

    pars = inPars;

    for i = 1:numel(FieldNames)
        pars = UpdateField(pars,DefPars,FieldNames{i});
    end
    iscomplete = all(isfield(pars,FieldNames));
end

function inP = UpdateField(inP,DefP,FieldName)
    if isfield(inP,FieldName)
        return
    else
        if isfield(DefP,FieldName)
            inP.(FieldName) = DefP.(FieldName);
        end
    end
end
