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

    %% Set default values for outputs and input parameters
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

    %% Validate SelectedSets
    if DoMeans 
        AvailableSets = nonemptyMean;
    else
        AvailableSets = nonemptyInd;
    end

    % Check if there are available sets to sort
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
                errordlg2(['Selected dataset indices exceed the total number of ' ...
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

    %% Validate TemplateSet    
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
        TemplateIndex = [];
    end

    %% Prompt user to select sets to sort and template sets if needed in pop-up windows
    if isempty(SelectedSets)
        AvailableSetnames = {AllEEG(AvailableSets).setname};

        if isempty(TemplateIndex)
            TemplateIndex = 1;
        end

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

    elseif isempty(TemplateIndex)
        TemplateIndex = 1;

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

    %% Verify compatibility between selected sets to sort and template set

    % Check if template set is a parent set of all the selected sets (only
    % for mean sets)
    isPublishedTemplate = matches(TemplateName, {MSTEMPLATE.setname});    
    if ~isPublishedTemplate
        warningSetnames = {};
        for index = 1:length(SelectedSets)
            sIndex = SelectedSets(index);
            containsChild = checkSetForChild(AllEEG, nonemptyMean(TemplateIndex), AllEEG(sIndex).setname);
            if ~containsChild
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

    %% Sorting

    % Delara 9/29/22 edit: use widest rather than narrowest range of
    % classes (skip over classes that do not exist for certain sets in
    % later loop)
    if ~isempty(NClasses)
        MinClasses = NClasses;
        MaxClasses = NClasses;
    else
        MinClasses = AllEEG(SelectedSets(1)).msinfo.ClustPar.MinClasses;
        MaxClasses = AllEEG(SelectedSets(1)).msinfo.ClustPar.MaxClasses;
        for index = 2:length(SelectedSets)
            sIndex = SelectedSets(index);
            MinClasses = min(MinClasses,AllEEG(sIndex).msinfo.ClustPar.MinClasses);
            MaxClasses = max(MaxClasses,AllEEG(sIndex).msinfo.ClustPar.MaxClasses);
        end
    end

    % Delara 10/7/22 change: make outer loop go through selected sets,
    % inner loop go through classes
    for index = 1:length(SelectedSets)
        sIndex = SelectedSets(index);

        for n = MinClasses:MaxClasses

            % skip class number if the current set does not contain the
            % current cluster solution
            if n > numel(AllEEG(sIndex).msinfo.MSMaps)
                continue
            elseif isempty(AllEEG(sIndex).msinfo.MSMaps(n).Maps)
                continue
            end

            % find the number of template classes to use
            if TemplateSet == -1
                % published templates should only have 1 cluster solution
                HasTemplates = ~cellfun(@isempty,{ChosenTemplate.msinfo.MSMaps.Maps});
                TemplateClassesToUse = find(HasTemplates == true);
            else
                % for mean sets, use min cluster solution if class number
                % is less than min, max cluster solution if greater than
                % max, same number otherwise
                if n < ChosenTemplate.msinfo.ClustPar.MinClasses
                    TemplateClassesToUse = ChosenTemplate.msinfo.ClustPar.MinClasses;
                elseif n > ChosenTemplate.msinfo.ClustPar.MaxClasses
                    TemplateClassesToUse = ChosenTemplate.msinfo.ClustPar.MaxClasses;
                else
                    TemplateClassesToUse = n;
                end
            end

            % compare number of channels in selected set and template set -
            % convert whichever set has more channels to the channel
            % locations of the other
            MapsToSort = zeros(1, n, min(AllEEG(sIndex).nbchan, ChosenTemplate.nbchan));
            [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(AllEEG(sIndex).chanlocs,ChosenTemplate.chanlocs);
            if AllEEG(sIndex).nbchan > ChosenTemplate.nbchan
                MapsToSort(1,:,:) = AllEEG(sIndex).msinfo.MSMaps(n).Maps * LocalToGlobal';
                TemplateMaps = ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).Maps;
            else
                MapsToSort(1,:,:) = AllEEG(sIndex).msinfo.MSMaps(n).Maps;
                TemplateMaps = ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).Maps * GlobalToLocal';
            end

            % Sort
            [~,SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MapsToSort,TemplateMaps,~IgnorePolarity);
            AllEEG(sIndex).msinfo.MSMaps(n).Maps = AllEEG(sIndex).msinfo.MSMaps(n).Maps(SortOrder(SortOrder <= n),:);
            AllEEG(sIndex).msinfo.MSMaps(n).Maps = AllEEG(sIndex).msinfo.MSMaps(n).Maps .* repmat(polarity',1,numel(AllEEG(sIndex).chanlocs));

            % Update map labels and colors
            [Labels,Colors] = UpdateMicrostateLabels(AllEEG(sIndex).msinfo.MSMaps(n).Labels,ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).Labels,SortOrder,AllEEG(sIndex).msinfo.MSMaps(n).ColorMap,ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).ColorMap);
            AllEEG(sIndex).msinfo.MSMaps(n).Labels = Labels;
            AllEEG(sIndex).msinfo.MSMaps(n).ColorMap = Colors;

            % Delara 8/17/22 change
            if (TemplateSet == -1)
                AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'published template';
            else
                if (DoMeans)
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'grand mean map';
                else
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'mean map';
                end
            end
            AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.setname];
            AllEEG(sIndex).msinfo.MSMaps(n).SpatialCorrelation = SpatialCorrelation;
            AllEEG(sIndex).saved = 'no';
        end

    end

    %% Command string generation
    if isstruct(TemplateSet)
        TemplateSetString = inputname(4);
        if isempty(TemplateSetString)
            TemplateSetString = '[]';
        end
    else
        TemplateSetString = string(TemplateSet);
    end
    if isempty(NClasses)
        NClassesString = '[]';
    else
        NClassesString = string(NClasses);
    end
    
    EEGOUT = AllEEG(SelectedSets);
    CurrentSet = SelectedSets;
    
    com = sprintf('[EEG CURRENTSET com] = pop_SortMSTemplates(%s, %s, %i, %s, "%s", %i, %s);', inputname(1), mat2str(SelectedSets), DoMeans, TemplateSetString, string(TemplateName), IgnorePolarity, NClassesString);
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

function containsChild = checkSetForChild(AllEEG, SetsToSearch, childSetName)
    containsChild = false;
    if isempty(SetsToSearch)
        return;
    end
    
    meanSetInfos = [AllEEG(SetsToSearch).msinfo];
    HasChildren = arrayfun(@(x) isfield(x, 'children'), meanSetInfos);
    if ~any(HasChildren)
        return;
    end

    containsChild = any(cellfun(@(x) matches(childSetName, x), {meanSetInfos(HasChildren).children}));

    % if the child cannot be found, search the children of the children
    if ~containsChild
        childSetIndices = cell2mat(cellfun(@(x) find(matches({AllEEG.setname}, x)), {meanSetInfos.children}, 'UniformOutput', false));
        containsChild = checkSetForChild(AllEEG, childSetIndices, childSetName);
    end

end