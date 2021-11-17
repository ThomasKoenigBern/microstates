%pop_MS_Silhouette(AllEEG,MeanSet, IgnorePolarity)
%
% Usage: >> com = pop_MS_Silhouette(AllEEG,MeanSet, IgnorePolarity)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%   
%   "MeanSet" 
%   -> The mean microstate set to explore. All individual microstate maps
%      that contributed to the chosen mean will be included in the analysis
%
%   "IgnorePolarity"
%   -> Ignore the polarity of the maps to be sorted   
%
% Output:
%
%   "com"
%   -> Command necessary to replicate the computation
%
% =========================================================================
%              Understanding the idea of the resulting figure
%              ----------------------------------------------
%
% The graph lets you choose a particular number of microstate classes. It
% then displays things as follows:
%
% - On the right side, the silhouette values for each microstate class 
%   and subject are shown. Relatively large and mainly consistently 
%   positive silhouette values is what you expect from a cluster that can
%   be meaningfully identified across subjects.
%
% - The lowest graph on the right side shows the mean silhouettte values
%   for each subject. 
%
% - On the right side, the individual microstate maps of all clusters are 
%   shown in a 3D multidimensional scaling graph. The colors of the dots 
%   correspond to the background color of the microstate classes. When you
%   click on one of the bargraphs, the corresponding dots are enlarged.
%
% To visualize the individual maps that correspond to a silhouette value,
% click on a bargraph.
% 
% A good number of microstate classes is one where all clusters can be
% reaonably well identified across a reaonably large majority of
% individuals.
%
% =========================================================================
% Author: Thomas Koenig, University of Bern, Switzerland, 2017
%
% Copyright (C) 2016 Thomas Koenig, University of Bern, Switzerland, 2017
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
function com = pop_MS_Silhouette(AllEEG,MeanSet, IgnorePolarity)

    com = '';

    if nargin < 2 
        MeanSet = [];
    end

    if nargin < 3  IgnorePolarity = true;            end %#ok<*SEPEX>
    
    nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
    HasChildren = cellfun(@(x) isfield(x,'children'), {AllEEG.msinfo});
    nonemptyGroup  = nonempty(HasChildren);

    if numel(MeanSet) < 1 
        AvailableSets = {AllEEG(nonemptyGroup).setname};
  
        res = inputgui( 'geometry', {1 1 1}, 'geomvert', [1 4 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for sorting'} ...
            { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets'} ...
            { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            });
     
        if isempty(res)
            return; 
        end
        IgnorePolarity = res{2};
        SelectedMean = nonemptyGroup(res{1});

    else
        if nargin < 3
            res = inputgui( 'geometry', {1}, 'geomvert', 1, 'uilist', { ...
                { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
                });
        
            if isempty(res); return; end
            IgnorePolarity = res{1};
        end    
        SelectedMean = MeanSet;
    end

    if numel(SelectedMean) ~= 1
        errordlg2('You must select exactly one set of microstate maps','Sort microstate classes');
        return
    end
      
    eegout = AllEEG(SelectedMean);
    
    ChildIndex = FindTheWholeFamily(eegout,AllEEG);

    SilhouetteExplorer(eegout, AllEEG(ChildIndex));    
    txt = sprintf('%i ',SelectedMean);
    txt(end) = [];
    
        
    com = sprintf('com = pop_MS_Silhouette(%s, [%s], %i);', inputname(1),txt,IgnorePolarity); 
    end


    function ChildIndex = FindTheWholeFamily(TheMeanEEG,AllEEGs)
        
    AvailableDataNames = {AllEEGs.setname};
    
        ChildIndex = [];
        for i = 1:numel(TheMeanEEG.msinfo.children)
            idx = find(strcmp(TheMeanEEG.msinfo.children{i},AvailableDataNames));
        
            if isempty(idx)
                errordlg2(sprintf('Dataset %s not found',TheMeanEEG.msinfo.children{i}),'Silhouette explorer');
            end
    
            if numel(idx) > 1
                errordlg2(sprintf('Dataset %s repeatedly found',TheMeanEEG.msinfo.children{i}),'Silhouette explorer');
            end
            if ~isfield(AllEEGs(idx).msinfo,'children')
                ChildIndex = [ChildIndex idx]; %#ok<AGROW>
            else
                ChildIndex = [ChildIndex FindTheWholeFamily(AllEEGs(idx),AllEEGs)]; %#ok<AGROW>
            end
        end

    
    end
        
    