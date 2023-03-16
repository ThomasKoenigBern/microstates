%pop_RaguMSTemplates() transfers the microstate topographies to Ragu for topographic testing
%
% Usage:
%   >> com = pop_RaguMSTemplates(AllEEG, CURRENTSET, nClasses)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "CURRENTSET" 
%   -> Index of selected EEGs. If more than one EEG is selected, the analysis
%      will be limited to those, if not, the user is asked
%   -> nClasses: The number of microstate classes you want to have analyzed
%
% Output:
%
%   "com"
%   -> Command necessary to replicate the computation
%              %
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

function com = pop_RaguMSTemplates(AllEEG, SetToTest, nClasses)

    com = '';

    if numel(SetToTest) < 2
        nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
        HasChildren = cellfun(@(x) isfield(x,'children'), {AllEEG.msinfo});
        nonemptyInd  = nonempty(~HasChildren);
        AvailableSets = {AllEEG(nonemptyInd).setname};
        
        res = inputgui( 'geometry', {1 1 1}, 'geomvert', [1 1 4], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for export'} ...
            { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
            { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets' ,'Min', 0, 'Max',2}});
        
            if isempty(res); return; end
        
            SetToTest = nonemptyInd(res{1});
    end
    
    MinClasses = max(cellfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses,num2cell(SetToTest)));
    MaxClasses = min(cellfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses,num2cell(SetToTest)));

    PossibleNs = MinClasses:MaxClasses;
    choice = '';
    
     for i = 1:numel(PossibleNs)
        choice = [choice sprintf('%i Classes|',PossibleNs(i))];
     end
    
    if nargin < 3
        res = inputgui('title','Topographic tests using Ragu', 'geometry', {[1 1]}, 'geomvert', [3],  'uilist', { ...
            { 'Style', 'text', 'string', 'Number of classes', 'fontweight', 'bold'  } ...
            { 'style', 'listbox', 'string', choice}});
  
        if isempty(res)
            return
        else
            nClasses = PossibleNs(res{1});
        end
    end
    
    rd = SaveMSMapsForRagu(AllEEG(SetToTest),nClasses);
    Ragu(rd);

    txt = sprintf('%i ',SetToTest);
    txt(end) = [];

    com = sprintf('com = pop_RaguMSTemplates(%s, %i, [%s]);', inputname(1), nClasses, txt);
end

