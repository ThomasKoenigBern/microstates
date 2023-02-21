% UPDATE DOCUMENTATION TO REFLECT KEY, VALUE PARAMETERS
%
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
%   provide the name of the normative template as the "TemplateSet" input.
%   If the template set is an EEG structure, or an array of EEG structures,
%   these will be used. If a template set index is not provided or an empty
%   array is passed in, the user will be prompted to select a template set.
% 
%   "TemplateSet" (added by Delara 8/16/22)
%   -> Name of published template or mean map setname that should be used 
%   for sorting. Can also be used to specify the setname of the mean set 
%   used to sort. Will be used if TemplateSet is empty or -1. If 
%   "TemplateSet" is not empty or equal to -1, this will be ignored.
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
function [EEGout, CurrentSet, com] = pop_SortMSTemplates(AllEEG, varargin)
    
    %% Set defaults for outputs
    com = '';
    global MSTEMPLATE;
    global guiOpts;
    global EEG;
    global CURRENTSET;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_SortMSTemplates';
    p.FunctionName = funcName;
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'IgnorePolarity', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    addParameter(p, 'SortOrder', [],  @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector'}));
    addParameter(p, 'NewLabels', [], @(x) validateattributes(x, {'char', 'string', 'cell'}, {'vector'}));
    addParameter(p, 'ClassRange', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector'}));
    addParameter(p, 'SortAll', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    IgnorePolarity = p.Results.IgnorePolarity;
    TemplateSet = p.Results.TemplateSet;
    SortOrder = p.Results.SortOrder;
    NewLabels = p.Results.NewLabels;
    ClassRange = p.Results.ClassRange;
    SortAll = p.Results.SortAll;

    if isnumeric(p.Results.TemplateSet)
        validateattributes(p.Results.TemplateSet, {'numeric'}, {'integer', 'scalar', 'positive', '<=', numel(AllEEG)}, funcName, 'TemplateSet');
    else
        validateattributes(p.Results.TemplateSet, {'char', 'string'}, {'scalartext'});
    end

    if ~isempty(NewLabels)
        NewLabels = convertStringsToChars(NewLabels);
        invalidSets = ~cellfun(@(x) ischar(x) || isstring(x), NewLabels);
        if any(invalidSets)
            invalidSetsTxt = sprintf('%i, ', find(inValidSets));
            invalidSetsTxt(end) = [];
            errorMessage = ['The following elements of NewLabels are invalid: ' invalidSetsTxt ...
                '. Expected all elements to be strings or chars.'];
            errordlg2(errorMessage, 'Sort microstate maps error');
        end
    end

    %% SelectedSets validation
    % First make sure there are valid sets for sorting
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(and(and(~isEmpty, ~HasDyn), HasMS));
    
    if isempty(AvailableSets)
        errordlg2(['No valid sets for sorting found.'], 'Sort microstate maps error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        % Check for empty sets, dynamics sets, or any sets without
        % microstate maps
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, dynamics sets, or sets ' ...
                'without microstate maps.'];
            errordlg2(errorMessage, 'Sort microstate maps error');
            return;
        end
    % Otherwise, add set selection gui elements
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        if isempty(defaultSets);    defaultSets = 1;    end        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        guiElements = [guiElements, ....
                    {{ 'Style', 'text'    , 'string', 'Choose sets for sorting'}} ...
                    {{ 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1 1];
        guiGeomV = [guiGeomV  1 1 4];
    end

    %% TemplateSet validation
    % If the user has provided a template set number or name, check its
    % validity
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), AvailableSets);
    meanSets = AvailableSets(HasChildren);
    meanSetnames = {AllEEG(meanSets).setname};
    [publishedSetnames, publishedDisplayNames, sortOrder] = getTemplateNames();
    TemplateIndex = 1;
    usingPublished = false;
    manualSort = false;
    if ~isempty(TemplateSet)
        % First check if the user wants to sort manually
        if matches(TemplateSet, 'manual', IgnoreCase=true)
            manualSort = true;
        % Else If the template set is a number, make sure it is one of the
        % mean sets in ALLEEG
        elseif isnumeric(TemplateSet)
            if ~ismember(TemplateSet, meanSets)
                errorMessage = sprintf(['The specified template set number %i is not a valid mean set. ' ...
                    'Make sure you have not selected an individual set or a dynamics set.'], TemplateSet);
                errordlg2([errorMessage], 'Sort microstate maps error');
                return;
            else
                TemplateIndex = find(ismember(meanSets, TemplateSet));
                TemplateName = meanSetnames{TemplateIndex};
            end
        % Else if the template set is a string, make sure it matches one of
        % the mean setnames or published template setnames
        else
            if matches(TemplateSet, meanSetnames)
                % If there are multiple mean sets with the same name
                % provided, notify the suer
                if numel(find(matches(meanSetnames, TemplateSet))) > 1
                    errorMessage = sprintf(['There are multiple mean sets with the name "%s." ' ...
                        'Please specify the set number instead ot the set name.'], TemplateSet);
                    errordlg2([errorMessage], 'Sort microstate maps error');
                    return;
                else
                    TemplateIndex = find(matches(meanSetnames, TemplateSet));
                    TemplateName = TemplateSet;
                    TemplateSet = meanSets(TemplateIndex);
                end
            elseif matches(TemplateSet, publishedSetnames)
                usingPublished = true;
                TemplateIndex = sortOrder(matches(publishedSetnames, TemplateSet));
                TemplateName = TemplateSet;
            else
                errorMessage = sprintf(['The specified template set "%s" could not be found in the ALLEEG ' ...
                    'mean sets or in the microstates/Templates folder.'], TemplateSet);
                errordlg2([errorMessage], 'Sort microstate maps error');
                return;
            end
        end

    % Otherwise, add template set selection gui elements
    else
        combinedSetnames = ['Manual sort' meanSetnames publishedDisplayNames];
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Name of template map to sort by', 'fontweight', 'bold'}} ...
            {{ 'Style', 'popupmenu', 'string', combinedSetnames, 'tag', 'TemplateIndex', 'Value', TemplateIndex }}];
        guiGeom = [guiGeom 1 1];
        guiGeomV = [guiGeomV 1 1];
    end

    %% Add other gui elements
    if contains('IgnorePolarity', p.UsingDefaults) && ~manualSort
        guiElements = [guiElements ...
            {{ 'Style', 'checkbox', 'string', 'No polarity','tag','IgnorePolarity','Value', IgnorePolarity }}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    %% Prompt user to fill in remaining parameters if necessary
    if ~isempty(guiElements)
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Sort microstate maps');

        if isempty(res); return; end
        
        if isfield(outstruct, 'SelectedSets')
            SelectedSets = AvailableSets(outstruct.SelectedSets);
        end

        if isfield(outstruct, 'TemplateIndex')
            if outstruct.TemplateIndex == 1
                manualSort = true;
            elseif outstruct.TemplateIndex <= numel(meanSetnames)+1
                TemplateIndex = outstruct.TemplateIndex-1;
                TemplateSet = meanSets(TemplateIndex);
                TemplateName = meanSetnames{TemplateIndex};
            else
                TemplateIndex = sortOrder(outstruct.TemplateIndex - numel(meanSetnames) - 1);
                TemplateSet = publishedSetnames{TemplateIndex};
                usingPublished = true;
            end
        end

        if isfield(outstruct, 'IgnorePolarity')
            IgnorePolarity = outstruct.IgnorePolarity;
        end
    end

    if numel(SelectedSets) < 1
        errordlg2('You must select at least one set of microstate maps','Sort microstate maps error');
        return;
    end

    %% Handle manual sort case
    if manualSort
        % Check that only one set was selected
        if numel(SelectedSets) > 1
            errordlg2('Only one dataset can be chosen for manual sorting.', 'Sort microstate maps error');
            return;
        end

        [SortedMaps, com] = pop_ManualSort(AllEEG, SelectedSets, SortOrder, NewLabels, ClassRange, SortAll, IgnorePolarity);
        if isempty(SortedMaps);  return; end
        AllEEG(SelectedSets).msinfo.MSMaps = SortedMaps;
        EEGout = AllEEG(SelectedSets);
        CurrentSet = SelectedSets;
        return;
    end

    if usingPublished
        ChosenTemplate = MSTEMPLATE(TemplateIndex);
    else
        ChosenTemplate = AllEEG(meanSets(TemplateIndex));
    end

    %% Prompt user to select class range and option to sort all if necessary
    TemplateMinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
    TemplateMaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;
    AllMinClasses = [TemplateMinClasses, arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, SelectedSets)];
    AllMaxClasses = [TemplateMaxClasses, arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, SelectedSets)];
    MinClasses = min(AllMinClasses);
    MaxClasses = max(AllMaxClasses);
    if contains('ClassRange', p.UsingDefaults)
        classes = MinClasses:MaxClasses;
        classChoices = sprintf('%i Classes|', classes);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1], 'geomvert', [1 1 4 1], 'uilist', ...
            { {'Style', 'text', 'string', 'Select classes to sort'} ...
              {'Style', 'text', 'string' 'Use ctrlshift for multiple selection'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 2, 'Value', 1:numel(classes), 'Tag', 'ClassRange'}, ...
              {'Style', 'checkbox', 'string', 'Sort remaining solutions by selected solution(s)', 'Value', SortAll, 'Tag', 'SortAll'}}, ...
              'title', 'Sort microstate maps');
        
        if isempty(res); return; end

        ClassRange = classes(outstruct.ClassRange);
        SortAll = outstruct.SortAll;
    end

    %% Verify compatibility between selected sets to sort and template set
    % If one of the selected sets is the same as the template set, remove
    % it from SelectedSets
    if matches(ChosenTemplate.setname, {AllEEG(SelectedSets).setname})
        SelectedSets(matches({AllEEG(SelectedSets).setname}, ChosenTemplate.setname)) = [];
    end

    % If the template set chosen is a mean set, make sure it is a parent
    % set of all the selected sets
    if ~usingPublished
        warningSetnames = {};
        for index = 1:length(SelectedSets)
            sIndex = SelectedSets(index);
            containsChild = checkSetForChild(AllEEG, meanSets(TemplateIndex), AllEEG(sIndex).setname);
            if ~containsChild
                warningSetnames = [warningSetnames, AllEEG(sIndex).setname];
            end
        end

        if ~isempty(warningSetnames) && guiOpts.showSortWarning
            txt = sprintf('%s, ', warningSetnames{:});
            txt = txt(1:end-2);
            warningMessage = sprintf(['Template set "%s" is not the parent set of ' ...
                'the following sets: %s. Are you sure you would like to proceed?'], ...
                TemplateName, txt);
            [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Sort microstate maps warning');
            if boxChecked;  guiOpts.showSortWarning = false;    end
            if ~yesPressed; return;                             end
        end
    end

    %% Sorting
    for index = 1:length(SelectedSets)
        fprintf('Sorting dataset %i of %i\n', index, numel(SelectedSets));
        sIndex = SelectedSets(index);

        for n = ClassRange

            % skip class number if the current set does not contain the
            % current cluster solution
            if n > numel(AllEEG(sIndex).msinfo.MSMaps)
                continue
            elseif isempty(AllEEG(sIndex).msinfo.MSMaps(n).Maps)
                continue
            end

            % find the number of template classes to use
            if n < TemplateMinClasses
                TemplateClassesToUse = TemplateMinClasses;
            elseif n > TemplateMaxClasses
                TemplateClassesToUse = TemplateMaxClasses;
            else
                TemplateClassesToUse = n;
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
            [Labels,Colors] = UpdateMicrostateLabels(AllEEG(sIndex).msinfo.MSMaps(n).Labels,ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).Labels,SortOrder,ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).ColorMap);
            AllEEG(sIndex).msinfo.MSMaps(n).Labels = Labels;
            AllEEG(sIndex).msinfo.MSMaps(n).ColorMap = Colors;

            % Update individual explained variance order
            AllEEG(sIndex).msinfo.MSMaps(n).ExpVar = AllEEG(sIndex).msinfo.MSMaps(n).ExpVar(SortOrder(SortOrder <= n));

            if usingPublished
                AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'published template';
                AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.setname];
            else
                if strcmp(ChosenTemplate.msinfo.MSMaps(n).SortMode, 'none')
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'mean map';
                    AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.setname];
                else
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = [ChosenTemplate.msinfo.MSMaps(n).SortMode '->mean map'];
                    AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.msinfo.MSMaps(n).SortedBy '->' ChosenTemplate.setname];
                end
            end
            
            AllEEG(sIndex).msinfo.MSMaps(n).SpatialCorrelation = SpatialCorrelation;
            AllEEG(sIndex).saved = 'no';            
        end

        if SortAll
            disp(['Sorting unselected solutions by largest selected solution' newline]);
            % Sort unsorted solutions by largest sorted solution
            AllClasses = AllEEG(sIndex).msinfo.ClustPar.MinClasses:AllEEG(sIndex).msinfo.ClustPar.MaxClasses;
            unsortedClasses = ~ismember(AllClasses, ClassRange);
            largestSortedClass = max(ClassRange);
            AllEEG(sIndex).msinfo.MSMaps = sortAllSolutions(AllEEG(sIndex).msinfo.MSMaps, AllClasses(unsortedClasses), largestSortedClass, IgnorePolarity);
        end

    end

    EEGout = AllEEG(SelectedSets);
    CurrentSet = SelectedSets;

    %% Command string generation
    if ischar(TemplateSet) || isstring(TemplateSet)
        com = sprintf('[EEG, CURRENTSET, com] = pop_SortMSTemplates(%s, %s, ''IgnorePolarity'', %i, ''TemplateSet'', ''%s'', ''SortAll'', %i);', inputname(1), mat2str(SelectedSets), IgnorePolarity, TemplateSet, SortAll);
    elseif isnumeric(TemplateSet)
        com = sprintf('[EEG, CURRENTSET, com] = pop_SortMSTemplates(%s, %s, ''IgnorePolarity'', %i, ''TemplateSet'', %i, ''SortAll'', %i);', inputname(1), mat2str(SelectedSets), IgnorePolarity, TemplateSet, SortAll);
    end        
end

function MSMaps = sortAllSolutions(MSMaps, ClassRange, nClasses, IgnorePolarity)    
    for i=ClassRange

        [SortedMaps, SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps, MSMaps(nClasses).Maps, ~IgnorePolarity);
        MSMaps(i).Maps = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps), 2));

        [Labels, Colors] = UpdateMicrostateLabels(MSMaps(i).Labels, MSMaps(nClasses).Labels, SortOrder, MSMaps(nClasses).ColorMap);
        MSMaps(i).Labels = Labels(1:i);
        MSMaps(i).ColorMap = Colors(1:i, :);
        MSMaps(i).SortMode = [MSMaps(nClasses).SortMode 'alternate solution in set'];
        MSMaps(i).SortedBy = sprintf('%s->this set (%i classes)', MSMaps(nClasses).SortedBy, nClasses);
        MSMaps(i).SpatialCorrelation = SpatialCorrelation;
        MSMaps(i).ExpVar = MSMaps(i).ExpVar(SortOrder(SortOrder <= i));

        if i > nClasses+1
            [SortedMaps, SortOrder, ~, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps((nClasses+1):end,:), MSMaps(i-1).Maps((nClasses+1):end,:), ~IgnorePolarity);
            MSMaps(i).Maps((nClasses+1):end,:) = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps),2));
            MSMaps(i).Labels((nClasses+1):end) = arrayfun(@(x) sprintf('MS_%i.%i', i, nClasses+x), 1:(i-nClasses), 'UniformOutput', false);
            endExpVar = MSMaps(i).ExpVar((nClasses+1):end);
            MSMaps(i).ExpVar((nClasses+1):end) = endExpVar(SortOrder);
        end
    end
end

function [TemplateNames, DisplayNames, sortOrder] = getTemplateNames()
    global MSTEMPLATE;
    TemplateNames = {MSTEMPLATE.setname};
    nClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, 1:numel(MSTEMPLATE));
    [nClasses, sortOrder] = sort(nClasses, 'ascend');
    TemplateNames = TemplateNames(sortOrder);
    nSubjects = arrayfun(@(x) MSTEMPLATE(x).msinfo.MetaData.nSubjects, sortOrder);
    nSubjects = arrayfun(@(x) sprintf('n=%i', x), nSubjects, 'UniformOutput', false);
    DisplayNames = strcat(string(nClasses), " maps - ", TemplateNames, " - ", nSubjects);
end

function isEmpty = isEmptySet(in)
    isEmpty = all(cellfun(@(x) isempty(in.(x)), fieldnames(in)));
end

function hasDyn = isDynamicsSet(in)
    hasDyn = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if set is a dynamics set
    if ~isfield(in.msinfo, 'DynamicsInfo')
        return;
    else
        hasDyn = true;
    end
end

function hasMS = hasMicrostates(in)
    hasMS = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if msinfo is empty
    if isempty(in.msinfo)
        return;
    else
        hasMS = true;
    end
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
    
    % find which sets have children
    HasChildren = arrayfun(@(x) isfield(AllEEG(x).msinfo, 'children'), SetsToSearch);
    % if none of the sets to search have children, the child set could not
    % be found
    if ~any(HasChildren)
        return;
    end

    % search the children of all the mean sets for the child set name
    containsChild = any(arrayfun(@(x) matches(childSetName, AllEEG(x).msinfo.children), SetsToSearch(HasChildren)));

    % if the child cannot be found, search the children of the children
    if ~containsChild
        childSetIndices = unique(cell2mat(arrayfun(@(x) find(matches({AllEEG.setname}, AllEEG(x).msinfo.children)), SetsToSearch(HasChildren), 'UniformOutput', false)));
        containsChild = checkSetForChild(AllEEG, childSetIndices, childSetName);
    end

end