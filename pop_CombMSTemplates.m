%pop_CombMSTemplates() interactively averages microstate across EEGs
%
% This is not a simple averaging, but a permute and average loop that
% optimizes the order of microstate classes in the individual datasets for
% maximal communality before averaging!
%
% Usage: >> [EEGOUT,com] = pop_CombMSTemplates(AllEEG, CURRENTSET, DoMeans, ShowWhenDone, MeanSetName, TemplateName)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "CURRENTSET" 
%   -> Index of selected EEGs. If more than one EEG is selected, the analysis
%      will be limited to those, if not, the user is asked.
%
%   "DoMeans"
%   -> True if you want to grand-average microstate maps already averaged
%   over datasets, false otherwise. Default is false (no GUI based choice).
%
%   "Show maps when done" / ShowWhenDone
%   -> Show maps when done
%
%   "Name of mean" / MeanSetName
%   -> Name of the new dataset returned by EEGOUT
%
%   Added by Delara 10/12/22
%   "Sort maps by published template when done" / TemplateName
%   -> Sort maps according to the specified published template when done
%
% Output:
%
%   "EEGOUT" 
%   -> EEG structure with the EEG containing the new cluster centers
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

function [AllEEG, EEGOUT,com] = pop_CombMSTemplates(AllEEG, CURRENTSET, DoMeans, ShowWhenDone, MeanSetName, IgnorePolarity, TemplateName)

    %% Set default values for outputs and input parameters
    com = '';
    EEGOUT = [];
    global MSTEMPLATE;
    
    if nargin < 3;  DoMeans = false;            end
    if nargin < 4;  ShowWhenDone = false;       end
    if nargin < 5;  MeanSetName = 'GrandMean';  end
    if nargin < 6;  IgnorePolarity = true;      end
    if nargin < 7;  TemplateName    = [];       end

    SortMaps = ~isempty(TemplateName);

    %% Validate TemplateName
    TemplateNames = {MSTEMPLATE.setname};
    TemplateIndex = 1;
    if SortMaps
        if (~any(matches(TemplateNames, TemplateName)))
            errorMessage = sprintf('The specified template %s could not be found in the microstates/Templates' + ...
            'folder. Please add the template to the folder before sorting.', TemplateName);
            errordlg2([errorMessage],'Identify microstate classes');
            return;
        else
            TemplateIndex = find(matches(TemplateNames, TemplateName));
        end
    end
    
    %% Select sets to combine
    if numel(CURRENTSET) == 1 
        nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
        HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG),'UniformOutput',true);
        if DoMeans == true
            nonempty(~HasChildren) = [];
        else
            nonempty(HasChildren) = [];
        end
        AvailableSets = {AllEEG(nonempty).setname};
            
        [res,~,~,structout] = inputgui('title','Average microstate maps across recordings',...
        'geometry', {1 1 1 1 1 1 1 1 1}, 'geomvert', [1 1 4 1 1 1 1 1 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for averaging'} ...
            { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
            { 'Style', 'listbox', 'string', AvailableSets, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
            { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
            { 'Style', 'edit', 'string', MeanSetName,'tag','MeanName' } ...
            { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            { 'Style', 'checkbox', 'string', 'Sort maps by published template when done', 'tag', 'Sort_Maps', 'Value', SortMaps } ...
            { 'Style', 'popupmenu', 'string', TemplateNames,'tag','TemplateIndex','Value', TemplateIndex} ...
            { 'Style', 'checkbox', 'string' 'Show maps when done' 'tag' 'Show_Maps'    ,'Value', ShowWhenDone }});
     
        if isempty(res); return; end
        
        SelectedSets = nonempty(structout.SelectSets);
        MeanSetName = structout.MeanName;
        IgnorePolarity = structout.Ignore_Polarity;
        SortMaps = structout.Sort_Maps;
        ShowWhenDone = structout.Show_Maps;

        if SortMaps
            TemplateIndex = structout.TemplateIndex;
            TemplateName = TemplateNames(TemplateIndex);
        end
    else
        if nargin < 5 || isempty(TemplateName)
            [res,~,~,structout] = inputgui('title','Average microstate maps across recordings',...
                'geometry', {1 1 1 1 1 1}, 'geomvert', [1 1 1 1 1 1], 'uilist', { ...
                { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
                { 'Style', 'edit', 'string', MeanSetName,'tag','MeanName' } ...
                { 'Style', 'checkbox', 'string', 'No polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
                { 'Style', 'checkbox', 'string', 'Sort maps by published template when done', 'tag', 'Sort_Maps', 'Value', SortMaps } ...
                { 'Style', 'popupmenu', 'string', TemplateNames,'tag','TemplateIndex','Value', TemplateIndex} ...
                { 'Style', 'checkbox', 'string' 'Show maps when done' 'tag' 'Show_Maps','Value', ShowWhenDone }});
        
            if isempty(res); return; end
    
            MeanSetName = structout.MeanName;
            IgnorePolarity = structout.Ignore_Polarity;
            SortMaps = structout.Sort_Maps;
            ShowWhenDone = structout.Show_Maps;

            if SortMaps
                TemplateIndex = structout.TemplateIndex;
                TemplateName = TemplateNames(TemplateIndex);
            end
        end    
        SelectedSets = CURRENTSET;
    end

    if numel(SelectedSets) < 2
        errordlg2('You must select at least two sets of microstate maps','Combine microstate maps');
        return;
    end

    if ~isfield(AllEEG(SelectedSets(1)),'msinfo')
        errordlg2(sprintf('Microstate info not found in dataset %',AllEEG(SelectedSets(1)).setname), 'Combine microstate maps');
        return;
    end

    %% Get all channel locations and verify that parameters are identical across sets
    MinClasses     = AllEEG(SelectedSets(1)).msinfo.ClustPar.MinClasses;
    MaxClasses     = AllEEG(SelectedSets(1)).msinfo.ClustPar.MaxClasses;
    tempIPolarity  = AllEEG(SelectedSets(1)).msinfo.ClustPar.IgnorePolarity;
    GFPPeaks       = AllEEG(SelectedSets(1)).msinfo.ClustPar.GFPPeaks;
    
     if ~isfield(AllEEG(SelectedSets(1)).msinfo.ClustPar,'UseEMD')
        UseEMD = false;
     else
         UseEMD = AllEEG(SelectedSets(1)).msinfo.ClustPar.UseEMD;
     end
    
    allchans  = { };
    children  = cell(length(SelectedSets),1);
    keepindex = 0;

    for index = 1:length(SelectedSets)
        if ~isfield(AllEEG(SelectedSets(index)),'msinfo')
            errordlg2(sprintf('Microstate info not found in dataset %',AllEEG(SelectedSets(index)).setname), 'Combine microstate maps'); 
            return;
        end
    
        if  MinClasses     ~= AllEEG(SelectedSets(index)).msinfo.ClustPar.MinClasses || ...
            MaxClasses     ~= AllEEG(SelectedSets(index)).msinfo.ClustPar.MaxClasses || ...
            tempIPolarity  ~= AllEEG(SelectedSets(index)).msinfo.ClustPar.IgnorePolarity || ...
            GFPPeaks       ~= AllEEG(SelectedSets(index)).msinfo.ClustPar.GFPPeaks
            errordlg2('Microstate parameters differ between datasets','Combine microstate maps');
            return;
        end
    
        children(index) = {AllEEG(SelectedSets(index)).setname};
        tmpchanlocs = AllEEG(SelectedSets(index)).chanlocs;
        tmpchans = { tmpchanlocs.labels };
        allchans = unique_bc([ allchans {tmpchanlocs.labels}]);

        if length(allchans) == length(tmpchans)
            keepindex = index;
        end
    end
    if keepindex
        tmpchanlocs = AllEEG(SelectedSets(keepindex)).chanlocs; 
    %    allchans = { tmpchanlocs.labels }; 
    end

    msinfo.children = children;
    msinfo.ClustPar = AllEEG(SelectedSets(1)).msinfo.ClustPar;
   
    %% Create combined maps
    for n = MinClasses:MaxClasses
        MapsToSort = nan(numel(SelectedSets),n,numel(tmpchanlocs));
        % Here we go to the common set of channels
        for index = 1:length(SelectedSets)
            LocalToGlobal = MakeResampleMatrices(AllEEG(SelectedSets(index)).chanlocs,tmpchanlocs);
            MapsToSort(index,:,:) = AllEEG(SelectedSets(index)).msinfo.MSMaps(n).Maps * LocalToGlobal';
        end
        % We sort out the stuff
        [BestMeanMap,~,ExpVar] = PermutedMeanMaps(MapsToSort,~IgnorePolarity,tmpchanlocs,[],UseEMD); % debugging only
        msinfo.MSMaps(n).Maps = BestMeanMap;
        msinfo.MSMaps(n).ExpVar = ExpVar;
        msinfo.MSMaps(n).ColorMap = lines(n);
        % Delara 10/14/22: add map labels
        for j = 1:n
            msinfo.MSMaps(n).Labels{j} = sprintf('%s_%i.%i', MeanSetName, n,j);
        end
        msinfo.MSMaps(n).SortMode = 'none';
        msinfo.MSMaps(n).SortedBy = 'none';
        msinfo.MSMaps(n).SpatialCorrelation = [];
    end
    
    EEGOUT = eeg_emptyset();
    EEGOUT.chanlocs = tmpchanlocs;
    EEGOUT.data = zeros(numel(EEGOUT.chanlocs),MaxClasses,MaxClasses);
    EEGOUT.msinfo = msinfo;
    
    for n = MinClasses:MaxClasses
        EEGOUT.data(:,1:n,n) = msinfo.MSMaps(n).Maps';
    end
    
    EEGOUT.setname     = MeanSetName;
    EEGOUT.nbchan      = size(EEGOUT.data,1);
    EEGOUT.trials      = size(EEGOUT.data,3);
    EEGOUT.pnts        = size(EEGOUT.data,2);
    EEGOUT.srate       = 1;
    EEGOUT.xmin        = 1;
    EEGOUT.times       = 1:EEGOUT.pnts;
    EEGOUT.xmax        = EEGOUT.times(end);


    %% Sorting
    ChosenTemplate = MSTEMPLATE(TemplateIndex);
    for n = MinClasses:MaxClasses

        % find the number of template classes to use
        HasTemplates = ~cellfun(@isempty,{ChosenTemplate.msinfo.MSMaps.Maps});
        TemplateClassesToUse = find(HasTemplates == true);

        % compare number of channels in mean set and template set -
        % convert whichever set has more channels to the channel
        % locations of the other
        MapsToSort = zeros(1, n, min(EEGOUT.nbchan, ChosenTemplate.nbchan));
        [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(EEGOUT.chanlocs,ChosenTemplate.chanlocs);
        if EEGOUT.nbchan > ChosenTemplate.nbchan
            MapsToSort(1,:,:) = EEGOUT.msinfo.MSMaps(n).Maps * LocalToGlobal';
            TemplateMaps = ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).Maps;
        else
            MapsToSort(1,:,:) = EEGOUT.msinfo.MSMaps(n).Maps;
            TemplateMaps = ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).Maps * GlobalToLocal';
        end

        % Sort
        [~,SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MapsToSort,TemplateMaps,~IgnorePolarity);
        EEGOUT.msinfo.MSMaps(n).Maps = EEGOUT.msinfo.MSMaps(n).Maps(SortOrder(SortOrder <= n),:);
        EEGOUT.msinfo.MSMaps(n).Maps = EEGOUT.msinfo.MSMaps(n).Maps .* repmat(polarity',1,numel(EEGOUT.chanlocs));

        % Update map labels and colors
        [Labels,Colors] = UpdateMicrostateLabels(EEGOUT.msinfo.MSMaps(n).Labels,ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).Labels,SortOrder,EEGOUT.msinfo.MSMaps(n).ColorMap,ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).ColorMap);
        EEGOUT.msinfo.MSMaps(n).Labels = Labels;
        EEGOUT.msinfo.MSMaps(n).ColorMap = Colors;

        % Delara 8/17/22 change
        EEGOUT.msinfo.MSMaps(n).SortMode = 'template based';
        EEGOUT.msinfo.MSMaps(n).SortedBy = [ChosenTemplate.setname];
        EEGOUT.msinfo.MSMaps(n).SpatialCorrelation = SpatialCorrelation;
        EEGOUT.saved = 'no';
    end

    if ShowWhenDone == true
        pop_ShowIndMSMaps(EEGOUT, nan, 0, AllEEG);
    end

    %% Command string generation
    com = sprintf('[ALLEEG, EEG, com] = pop_CombMSTemplates(%s, %s, %i, %i, ''%s'', %i, ''%s'');',inputname(1),mat2str(SelectedSets),DoMeans,ShowWhenDone,MeanSetName,IgnorePolarity,string(TemplateName));
    
end

function Answer = DoesItHaveChildren(in)
    Answer = false;
    if ~isfield(in,'msinfo')
        return;
    end
    
    if ~isfield(in.msinfo,'children')
        return
    else
        Answer = true;
    end
end

% Performs element-wise computation of abs(spatial correlation) or 
% spatial correlation between matrices A and B
function corr = elementCorr(A,B, IgnorePolarity)
    % average reference
    A = A - mean(A, 1);
    B = B - mean(B, 1);

    % get correlation
    A = A./sqrt(sum(A.^2, 1));
    B = B./sqrt(sum(B.^2, 1));           
    if (IgnorePolarity) 
        corr = abs(sum(A.*B, 1));
    else 
        corr = sum(A.*B, 1);
    end
end

