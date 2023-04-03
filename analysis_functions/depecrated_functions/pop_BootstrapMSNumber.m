%pop_BootstrapMSNumber() Reorder microstate maps based on a mean template
%
% Usage: >> com = pop_BootstrapMSNumber(AllEEG,SetToSort, IgnorePolarity, LearningsetSize)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%   
%   "SetToSort" 
%   -> Index of selected EEGs. If more than one EEG is selected, the analysis
%      will be limited to those, if not, the user is asked.
%
%   "IgnorePolarity"
%   -> Ignore the polarity of the maps to be sorted   
%
%   "LearningsetSize"
%   -> Percent samples used for the learning set
% Output:
%
%   "com"
%   -> Command necessary to replicate the computation
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
function com = pop_BootstrapMSNumber(AllEEG,SetToSort, IgnorePolarity, LearningsetSize, Runs)

    com = '';
    
%    if numel(EEG) > 1
%        errordlg2('pop_findMSTemplates() currently supports only a single EEG as input');
%        return;
%    end
    if nargin < 2 
        SetToSort = [];
    end

    if nargin < 3  IgnorePolarity = true;            end %#ok<*SEPEX>
    if nargin < 4  LearningsetSize = 50;            end %#ok<*SEPEX>
    if nargin < 5  Runs = 10;            end %#ok<*SEPEX>
    
    nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
    HasChildren = cellfun(@(x) isfield(x,'children'), {AllEEG.msinfo});
    nonemptyInd  = nonempty(~HasChildren);
    
    if numel(SetToSort) < 3 
        AvailableSets = {AllEEG(nonemptyInd).setname};
  
        res = inputgui( 'geometry', {1 1 1 [1 1] [1 1] 1}, 'geomvert', [1 1 4 1 1 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for sorting'} ...
            { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
            { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
            { 'Style', 'text', 'string', 'Percent samples in learning set', 'fontweight', 'bold'  } ...
            { 'Style', 'edit', 'string', sprintf('%3.1f',LearningsetSize),'tag' 'LearningsetSize' } ... 
            { 'Style', 'text', 'string', 'Bootstrap samples', 'fontweight', 'bold'  } ...
            { 'Style', 'edit', 'string', sprintf('%i',Runs),'tag' 'Runs' } ... 
            { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            });
     
        if isempty(res)
            return; 
        end
        LearningsetSize = str2double(res{2});
        IgnorePolarity = res{4};
        Runs = floor(str2double(res{3}));
        SelectedSet = nonemptyInd(res{1});

    else
        if nargin < 5
            res = inputgui( 'geometry', {[1 1] [1 1] 1}, 'geomvert', [1 1 1], 'uilist', { ...
                { 'Style', 'text', 'string', 'Percent samples in learning set', 'fontweight', 'bold'  } ...
                { 'Style', 'edit', 'string', sprintf('%3.1f',LearningsetSize),'tag' 'LearningsetSize' } ... 
                { 'Style', 'text', 'string', 'Bootstrap samples', 'fontweight', 'bold'  } ...
                { 'Style', 'edit', 'string', sprintf('%i',Runs),'tag' 'Runs' } ... 
                { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
                });
        
            if isempty(res); return; end
            LearningsetSize = str2double(res{1});
            IgnorePolarity = res{3};
            Runs = floor(str2double(res{2}));
        end    
        SelectedSet = SetToSort;
    end

    if numel(SelectedSet) < 1
        errordlg2('You must select at least one set of microstate maps','Sort microstate classes');
        return
    end
    
    cutoff = ceil(numel(SelectedSet)) * LearningsetSize / 100;
    
    h = figure();
    clf
    
    
    for r = 1:Runs
        fprintf(1,'\r --- Run %i/%i ---',r,Runs);
        idx = randperm(numel(SelectedSet));
        LearningSet = SelectedSet(idx(1:cutoff));
        TestSet     = SelectedSet(idx((cutoff+1):end));
        eegout = pop_CombMSTemplates(AllEEG, LearningSet, 0, 0, [], IgnorePolarity);
        eegout.msinfo = rmfield(eegout.msinfo,'children');
        
        [~,SortedTestSet] = pop_SortMSTemplates(AllEEG,TestSet, false,eegout, IgnorePolarity);
        pidx = 1;
        for c = eegout.msinfo.ClustPar.MinClasses:eegout.msinfo.ClustPar.MaxClasses
            
            subplot(1,(eegout.msinfo.ClustPar.MaxClasses - eegout.msinfo.ClustPar.MinClasses+1),pidx);
            pidx = pidx + 1;
            Comm = cell2mat(cellfun(@(x) SortedTestSet(x).msinfo.MSMaps(c).Communality,num2cell(1:numel(TestSet)),'UniformOutput',false));
            Comm = reshape(Comm,c,numel(TestSet));
            Comm
            MeansToStore = [mean(Comm,2);mean(Comm(:))];
            if r == 1
                MeanComm{c} = MeansToStore;
            else
                MeanComm{c} = [MeanComm{c} MeansToStore];
            end

            plot([1 c],[MeanComm{c}(c+1,:) ;MeanComm{c}(c+1,:)],'-','Color',[0.5 0.5 0.5]);
            hold on
            GrandMeanComm(c) = mean(MeanComm{c}(c+1,:),2);
            plot([1 c],mean([GrandMeanComm(c) ;GrandMeanComm(c)],2),'-r');
            plot(1:c,MeanComm{c}(1:c,:),'.k');
            title({sprintf('%i classes',c);sprintf('%4.2f %%common',GrandMeanComm(c) * 100)});
            
            axis([0 c+1 0.7 1]);
            hold off
        end
        [~,idxmax] = max(GrandMeanComm);
        set(h,'Name',sprintf('Optimal communality with %i maps',idxmax),'NumberTitle','off');
        drawnow    
    end
    txt = sprintf('%i ',SelectedSet);
    txt(end) = [];
    
    fprintf(1,'\n\n*** You have optimal communality with %i maps ***\n\n',idxmax);
    
    com = sprintf('com = pop_BootstrapMSNumber(%s, [%s], %i, %i %i);', inputname(1),txt,IgnorePolarity, LearningsetSize, Runs); 
end
