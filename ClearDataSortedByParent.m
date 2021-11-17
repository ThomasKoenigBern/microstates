%ClearDataSortedByParent() Attempts to clear previous sorting information
%
% Usage:
%   >> AllEEG = ClearDataSortedByParent(AllEEG, Children, ClassIndex)
%
% Inputs:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "Children"
%   -> Name of the datasets in the AllEEG structure that should have the
%      sorting information cleared. If the dataset is not found, a warning
%      is issued.
%
%   "ClassIndex"
%   -> Array of numbers of microstate cluster sizes to be cleared (default = all)
%
% Output:
%
%   "AllEEG" 
%   -> AllEEG structure with all the updated EEGs
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
%
function AllEEG = ClearDataSortedByParent(AllEEG, Children, ClassIndex)
    
    if isempty(Children)
        return;
    end
    
    for c = 1:numel(Children)
        ToBeCleared = find(strcmp(Children{c},{AllEEG.setname}));
        if isempty(ToBeCleared)
            fprintf(1,'Could not find %s for clearing sorting information\n',Children{c});
        end
    
        for i = 1:numel(ToBeCleared)
            sIdx = ToBeCleared(i);
            if nargin < 3
                ClassIndex = AllEEG(sIdx).msinfo.ClustPar.MinClasses:AllEEG(sIdx).msinfo.ClustPar.MaxClasses;
            end
            for n = 1:numel(ClassIndex)
                AllEEG(sIdx).msinfo.MSMaps(ClassIndex(n)).SortedBy = [];
                AllEEG(sIdx).msinfo.MSMaps(ClassIndex(n)).SortMode = 'none';
            end
            disp(['MS sorting info cleared from ' AllEEG(sIdx).setname]);
            
            AllEEG(sIdx).saved = 'no';
            
            if isfield(AllEEG(sIdx).msinfo,'children')
                AllEEG = ClearDataSortedByParent(AllEEG,AllEEG(sIdx).msinfo.children);
            end
        end    
    end
end