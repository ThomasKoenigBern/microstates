%pop_SortMSTemplates() Reorder microstate maps based on a mean template
%
% Usage: >> [EEGOUT,CurrentSet,com] = pop_SortMSTemplates(AllEEG, SelectedSets, DoMeans, TemplateSet, IgnorePolarity, NClasses)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "SelectedSets" 
%   -> Index of selected EEGs. If more than one EEG is selected, the analysis
%      will be limited to those, if not, the user is asked. If set indices
%      are not provided or an empty array is passed in, the user will be 
%      prompted to select them.
%
%   "DoMeans"
%   -> 0 to sort individual datasets
%   -> 1 to sort mean datasets
%   -> If DoMeans is not provided, it will by default by set to 0.
%
%   "TemplateSet"
%   -> Index of the AllEEG element with the dataset used as a template for sorting
%   If TemplateSet is -1, the user will be prompted for a normative
%   template. If you want to use a normative template in a script, either load the
%   dataset with the normative template first and than make this the
%   TemplateSet that you use for sorting, or set "TemplateSet" to -1 and 
%   provide the name of the normative template as the "TemplateName" input.
%   If the template set is an EEG structure, or an array of EEG structures,
%   these will be used. If a template set index is not provided or an empty
%   array is passed in, the user will be prompted to select a template set.
% 
%   "TemplateName" (added by Delara 8/16/22)
%   -> Name of published template (currently either Norms NI2002 or
%   Custo2017) or mean map setname that should be used for sorting. Can
%   also be used to specify the setname of the mean set used to sort. Will
%   be used if TemplateSet is empty or -1. If "TemplateSet" is not empty or
%   equal to -1, this will be ignored.
%
%   "IgnorePolarity"
%   -> Ignore the polarity of the maps to be sorted. Default = 1.  
%
%   "NClasses" (added by Delara 8/22/22)
%   -> optional argument specifying the cluster solution to sort (rather
%   than sorting all cluster solutions - default)
% Output:
%
%   "EEGOUT" 
%   -> EEG structure with all the sorted EEGs
%
%   "CurrentSet"
%   -> Index of the sorted EEGs
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
function [EEGOUT, CurrentSet, com] = pop_SortMSTemplates(AllEEG, SelectedSets, DoMeans, TemplateSet, TemplateName, IgnorePolarity, NClasses)

    global EEG;
    global CURRENTSET;
    global MSTEMPLATE;
    global showMessage;
    com = '';
    EEGOUT = EEG;
    CurrentSet = CURRENTSET;

    if nargin < 2;  SelectedSets = [];          end
    if nargin < 3;  DoMeans = false;            end
    if nargin < 4;  TemplateSet = [];           end
    if nargin < 5;  TemplateName = [];          end
    if nargin < 6;  IgnorePolarity = true;      end 
    if nargin < 7;  NClasses = [];              end
    
    nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG),'UniformOutput',true);
    nonemptyInd  = nonempty(~HasChildren);
    nonemptyMean = nonempty(HasChildren);

    % Validate SelectedSets
    if DoMeans 
        AvailableSets = nonemptyMean;
    else
        AvailableSets = nonemptyInd;
    end

    % Check if there are available sets to srot
    if isempty(AvailableSets)
        if DoMeans
            errordlg2(['No mean sets found. Use Tools -> Microstates ->' ...
                'Compute mean microstate maps across individuals to create ' ...
                'the mean maps before sorting.'], 'Sort microstate classes');
            return;
        else
            errordlg2(['No datasets with microstate maps found. Use Tools ->' ...
                ' Microstates -> Identify microstates to create maps before' ...
                ' sorting.'], 'Sort microstate classes');
            return;
        end
    end

    % Check if SelectedSets are included in AvailableSets
    if ~isempty(SelectedSets)
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSets = SelectedSets(~isValid);
            if (any(invalidSets > numel(AllEEG)))
                errordlg2(['Selected datasets exceed the total number of ' ...
                    'datasets loaded to EEGLAB.'], 'Sort microstate classes');
                return;
            elseif DoMeans
                errordlg2(['Individual datasets selected to sort. Choose ' ...
                    'mean datasets instead or use a "Sort individual ' ...
                    'microstate maps" menu option.'], 'Sort microstate classes');
                return;
            else
                errordlg2(['Mean datasets selected to sort. Choose individual ' ...
                    'datasets instead or use a "Sort mean microstate maps" ' ...
                    'menu option.'], 'Sort microstate classes');
                return;
            end
        end
    end

    % Validate TemplateSet    
    if isstruct(TemplateSet)
        TemplateNames = {TemplateSet.setname};
    else
        if TemplateSet == -1
            TemplateNames = {MSTEMPLATE.setname};
        else
            TemplateNames = {AllEEG(nonemptyMean).setname};
        end
    end

    % Check if there are template sets available
    if isempty(TemplateNames)
        if TemplateSet == -1
            errordlg2(['No published templates found. Add template sets to ' ...
                'the microstates/Templates folder before sorting.'], ['Sort ' ...
                'microstate classes']);
            return;
        else
            errordlg2(['No mean sets found. Use Tools -> Microstates -> ' ...
                'Compute mean microstate maps across individuals to create ' ...
                'the mean maps before sorting.'], 'Sort microstate classes');
            return;
        end
    end

    % Check if the provided template set/name is included in the available
    % template sets
    if ~isempty(TemplateSet) && TemplateSet ~= -1
        if ~ismember(TemplateSet, nonemptyMean)
            errorMessage = sprintf('Dataset %i is not a valid mean set.', ...
                TemplateSet);
            errordlg2([errorMessage], 'Sort microstate classes');
            return;
        else
            TemplateIndex = find(nonemptyMean == TemplateSet, 1);
        end
    elseif ~isempty(TemplateName)
        if (~any(matches(TemplateNames, TemplateName)))
            if TemplateSet == -1
                errorMessage = sprintf('The specified template %s could not be found in the microstates/Templates' + ...
                'folder. Please add the template to the folder before sorting.', TemplateName);
                errordlg2([errorMessage],'Sort microstate classes');
                return;
            else
                errorMessage = sprintf('The specified mean set %s could not be found.', TemplateName);
                errordlg2([errorMessage], 'Sort microstate classes');
                return;
            end
        else
            TemplateIndex = find(matches(TemplateNames, TemplateName));
        end
    else
        TemplateIndex = 1;
    end

    % Prompt user to select sets to sort and template sets if needed in pop-up windows
    if isempty(SelectedSets)
        AvailableSetnames = {AllEEG(AvailableSets).setname};

        res = inputgui('title','Sort microstate classes',...
        'geometry', {1 1 1 1 1 1}, 'geomvert', [1 1 4 1 1 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Choose sets for sorting'} ...
            { 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'} ...
            { 'Style', 'listbox', 'string', AvailableSetnames, 'tag','SelectSets' ,'Min', 0, 'Max',2} ...
            { 'Style', 'text', 'string', 'Name of template map', 'fontweight', 'bold'  } ...
            { 'Style', 'popupmenu', 'string', TemplateNames,'tag','MeanName','Value', TemplateIndex} ...
            { 'Style', 'checkbox', 'string', 'Ignore polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            });

        if isempty(res); return; end
        
        TemplateIndex = res{2};
        TemplateName = TemplateNames{TemplateIndex};
        
        IgnorePolarity = res{3};
        if DoMeans
            SelectedSets = nonemptyMean(res{1});
        else
            SelectedSets = nonemptyInd(res{1});
        end

    elseif TemplateIndex == 1
        res = inputgui('title','Sort microstate classes',...
        'geometry', {1 1 1}, 'geomvert', [1 1 1], 'uilist', { ...
            { 'Style', 'text', 'string', 'Name of template map', 'fontweight', 'bold'  } ...
            { 'Style', 'popupmenu', 'string', TemplateNames,'tag','MeanName' ,'Value', TemplateIndex } ...
            { 'Style', 'checkbox', 'string', 'Ignore polarity','tag','Ignore_Polarity' ,'Value', IgnorePolarity }  ...
            });
        
        if isempty(res); return; end
        TemplateIndex = res{1};
        TemplateName = TemplateNames{TemplateIndex};
        IgnorePolarity = res{2};

    else
        TemplateName = TemplateNames{TemplateIndex};
    end

    if numel(SelectedSets) < 1
        errordlg2('You must select at least one set of microstate maps','Sort microstate classes');
        return;
    end

    if isstruct(TemplateSet)
        ChosenTemplate = TemplateSet(TemplateIndex);
    else
        if TemplateSet == -1
            ChosenTemplate = MSTEMPLATE(TemplateIndex);
        else
            ChosenTemplate = AllEEG(1,nonemptyMean(TemplateIndex));
        end
    end

    % Verify compatibility between selected sets to sort and template set

    % option to sort only one specified cluster solution
    if ~isempty(NClasses)
        TemplateMinClasses = NClasses;
        TemplateMaxClasses = NClasses;
    else
        TemplateMinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
        TemplateMaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;
    end

    MinClasses = AllEEG(SelectedSets(1)).msinfo.ClustPar.MinClasses;
    MaxClasses = AllEEG(SelectedSets(1)).msinfo.ClustPar.MaxClasses;
    for index = 2:length(SelectedSets)
        sIndex = SelectedSets(index);
        MinClasses = max(MinClasses,AllEEG(sIndex).msinfo.ClustPar.MinClasses);
        MaxClasses = min(MaxClasses,AllEEG(sIndex).msinfo.ClustPar.MaxClasses);
    end

    % Check for overlap between selected sets and template set classes
    if ~any(ismember(MinClasses:MaxClasses, TemplateMinClasses:TemplateMaxClasses))
        warningMessage = sprintf('Not all selected sets to sort contain ' + ...
            'cluster solutions in the range %i to %i of the template set ' + ...
            '%s. No sorting will occur.', TemplateMinClasses, TemplateMaxClasses, ...
            TemplateName);
        warndlg2([warningMessage], 'Sort microstate classes');
        return;
    end

    % Check if template set is a parent set of all the selected sets
    if isempty(TemplateSet) || TemplateSet ~= -1
        warningSetnames = {};
        for index = 1:length(SelectedSets)
            sIndex = SelectedSets(index);
            minClasses = max(AllEEG(sIndex).msinfo.ClustPar.MinClasses, TemplateMinClasses);
            maxClasses = min(AllEEG(sIndex).msinfo.ClustPar.MaxClasses, TemplateMaxClasses);
    
            containsParent = checkSetForParent(AllEEG(sIndex), minClasses, maxClasses, TemplateName);
            if ~containsParent
                warningSetnames = [warningSetnames, AllEEG(sIndex).setname];
            end
        end

        if ~isempty(warningSetnames) && showMessage
            txt = sprintf('%s, ', warningSetnames{:});
            txt = txt(1:end-2);
            warningMessage = sprintf(['Template set %s is not the parent set of ' ...
                'the following sets: %s. Are you sure you would like to proceed?'], ...
                TemplateName, txt);
            res = inputgui('title', 'Sort microstate classes', ...
                'geometry', {1 [1 1] 1}, 'uilist', { ...
                { 'Style', 'text', 'string', warningMessage} ...
                { 'Style', 'radiobutton', 'string', 'Yes', 'Value', 0} ...
                { 'Style', 'radiobutton', 'string', 'No', 'Value', 0} ...
                { 'Style', 'checkbox', 'string', 'Do not show this message again', 'Value', 0} });
    
            if isempty(res); return; end 
            if (res{2}); return; end
            if (res{3})
                showMessage = 0;
            end

        end
    end

    % Sorting
    for n = MinClasses:MaxClasses
        MapsToSort = nan(numel(SelectedSets),n,numel(ChosenTemplate.chanlocs));
        % Here we go to the common set of channels
        for index = 1:length(SelectedSets)
            sIndex = SelectedSets(index);
            LocalToGlobal = MakeResampleMatrices(AllEEG(sIndex).chanlocs,ChosenTemplate.chanlocs);
           MapsToSort(index,:,:) = AllEEG(sIndex).msinfo.MSMaps(n).Maps * LocalToGlobal';
        end
        % We sort out the stuff
        [~,SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MapsToSort,ChosenTemplate.msinfo.MSMaps(n).Maps,~IgnorePolarity);

         for index = 1:length(SelectedSets)
            sIndex = SelectedSets(index);
            AllEEG(sIndex).msinfo.MSMaps(n).Maps = AllEEG(sIndex).msinfo.MSMaps(n).Maps(SortOrder(index,:),:);
            AllEEG(sIndex).msinfo.MSMaps(n).Maps = AllEEG(sIndex).msinfo.MSMaps(n).Maps .* repmat(polarity(index,:)',1,numel(AllEEG(sIndex).chanlocs));
            AllEEG(sIndex).msinfo.MSMaps(n).ColorMap = ChosenTemplate.msinfo.MSMaps(n).ColorMap;
%             AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'template based';
%             AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.msinfo.MSMaps(n).SortedBy '->' ChosenTemplate.setname];
            % Delara 8/17/22 change
            if (TemplateSet == -1)
                AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'template based';
            else
                if (DoMeans)
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'grand mean map based';
                else
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'mean map based';
                end
            end
            AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.setname];
            AllEEG(sIndex).msinfo.MSMaps(n).SpatialCorrelation = SpatialCorrelation(index,:);
            if isfield(ChosenTemplate.msinfo.MSMaps(n),'Labels')
                AllEEG(sIndex).msinfo.MSMaps(n).Labels = ChosenTemplate.msinfo.MSMaps(n).Labels;
            end
            AllEEG(sIndex).saved = 'no';
         end
    end
    SetsString = sprintf('%i ',SelectedSets);
    SetsString(end) = [];
    if isstruct(TemplateSet)
        TemplateSetString = inputname(4);
        if isempty(TemplateSetString)
            TemplateSetString = '[]';
        end
    else
        TemplateSetString = sprintf('%i ',TemplateSet);
        TemplateSetString(end) = [];
    end
    
    EEGOUT = AllEEG(SelectedSets);
    CurrentSet = SelectedSets;
    
    com = sprintf('[EEG CURRENTSET com] = pop_SortMSTemplates(%s, [%s], %i, %s, "%s", %i, 1);', inputname(1), SetsString, DoMeans, TemplateSetString, string(TemplateName), IgnorePolarity);
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

function containsParent = checkSetForParent(TheEEG, MinClasses, MaxClasses, TemplateName)

    parentSetNames = arrayfun(@getParentSetNames, MinClasses:MaxClasses, 'UniformOutput', false);
    containsParent = any(cellfun(@(x) matches(TemplateName, x), parentSetNames));

    function ParentSetNames = getParentSetNames(x)
    
        if ~isfield(TheEEG.msinfo.MSMaps(x), 'Parents')
            ParentSetNames = {};
        elseif ~isempty(TheEEG.msinfo.MSMaps(x).Parents)
            ParentSetNames = {TheEEG.msinfo.MSMaps(x).Parents.setname};
            nonEmptyInd = ~cellfun(@isempty, ParentSetNames);
            ParentSetNames = ParentSetNames(nonEmptyInd);
        else
            ParentSetNames = {};
        end
    
        if ~isfield(TheEEG.msinfo.MSMaps(x), 'Grandparents')
            GrandparentSetNames = {};
        elseif ~isempty(TheEEG.msinfo.MSMaps(x).Grandparents)
            GrandparentSetNames = {TheEEG.msinfo.MSMaps(x).Grandparents.setname};
            nonEmptyInd = ~cellfun(@isempty, GrandparentSetNames);
            GrandparentSetNames = GrandparentSetNames(nonEmptyInd);
        else
            GrandparentSetNames = {};
        end
    
        ParentSetNames = [ParentSetNames, GrandparentSetNames];
    end
end
