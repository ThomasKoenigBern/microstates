% pop_SortMSTemplates() Reorder microstate maps based on a mean template,
% published template, or manual indexing.
%
% Usage: 
%   >> [EEG, CURRENTSET, com] = pop_SortMSTemplates(ALLEEG, 
%       SelectedSets, 'key1', value1, 'key2', value2, ...)
%
% To sort maps by a template set, specify either the index of a mean set,
% name of a mean set, or name of a published set as the "TemplateSet"
% parameter.
%
% Ex: mean set index
%   >> [EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, 1:5, 'TemplateSet',
%       6, 'IgnorePolarity', 1, 'Classes', 4:7)
%
% Ex: mean set name
%   >> [EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, 1:5, 'TemplateSet',
%   'GrandMean', 'IgnorePolarity', 1, 'Classes', 4:7)
%
% Ex: published set name
%   >> [EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, 6, 'TemplateSet', 
%       'Koenig2002', 'IgnorePolarity', 1, 'Classes', 3:6)
%   >> [EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, 6, 'TemplateSet',
%       'Custo2017', 'IgnorePolarity', 1, 'Classes', 7)
%
% To sort maps or relabel maps manually, specify "TemplateSet" as "manual."
% Include "IgnorePolarity", "Classes", "SortOrder", and "NewLabels" for 
% reordering to occur without the GUI, or leave them out to bring up the 
% interactive GUI. Only one dataset can be passed in for manual sorting at 
% a time.
%
% Ex: manual sort without GUI
%   >> [EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, 1, 'TemplateSet',
%       'manual', 'IgnorePolarity', 1, 'Classes', 4, 'SortOrder', [-4 2 3 -1],
%       'NewLabels', {'A', 'B', 'C', 'D'})
%
% Ex: manual sort with GUI
%   >> [EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, 1, 'TemplateSet',
%       'manual')
%
% Graphical interface:
%
%   "Choose sets for sorting"
%   -> Select sets to sort
%   -> Command line equivalent: "SelectedSets"
%
%   "Name of template map to sort by"
%   -> Choose the "Manual or template sort in interactive explorer" option
%   if you would like to use the interactive explorer to sort and view the
%   template maps of one set. This option can also be used to manually
%   reorder and relabel microstate maps. Otherwise, choose a mean template
%   name or published template name to reorder maps based on the map order
%   of the specified template. Note: the interactive explorer option may
%   only be used for one set.
%   -> Command line equivalent: "TemplateSet"
%
%   "No polarity"
%   -> Consider maps with inverted polarity the same class (standard for
%   resting state EEG)
%   -> Command line equivalent: "IgnorePolarity"
%
% Batch template sorting graphical interface:
%
%   "Select classes to sort"
%   -> Select which cluster solutions to reorder
%   -> Command line equivalent: "Classes"
%
%   "Use selected solution to reorder all other solutions"
%   -> If one cluster solution is selected for sorting, this box can be
%   checked to sort the remaining cluster solutions by the selected
%   solution.
%   -> Command line equivalent: "SortAll"
%
%  Interactive sorting graphical interface:
%
%  "Select solution(s) to sort"
%   -> Select which cluster solution(s) to reorder. Multiple solutions can
%   be selected if using template sorting. Only one solution can be
%   selected if performing manual sorting or sorting all solutions by one
%   selected solution.
%   -> Command line equivalent: "Classes"
%
%   "Choose sorting procedure"
%   -> Select which type of sorting to perform: manual sorting based on map
%   indices, template sorting based on a mean set or published set, or
%   sorting all cluster solutions by one selected solution (or a
%   combination). 
%
%   "Select template" (only used for template sorting)
%   -> Select the mean template name or published template name to use for
%   sorting.
%   -> Command line equivalent: "TemplateSet"
%
%   "Sort Order" (only used for manual sorting)
%   -> Enter new indices of microstate maps. Use a negative index to
%   flip the polarity of the indexed map.
%   -> Command line equivalent: "SortOrder"
%
%   "New Labels" (only used for manual sorting)
%   -> Enter new labels for microstate maps
%   -> Command line equivalent: "NewLabels"
%
%   "Ignore polarity"
%   -> Consider maps with inverted polarity the same class (standard for
%   resting state EEG)
%   -> Command line equivalent: "IgnorePolarity"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Array of set indices of ALLEEG to sort. If not provided, a GUI
%   will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "TemplateSet"
%   -> Integer, string, or character vector specifying the template set to
%   sort by. Can be either the index of a mean set in ALLEEG, the name of a
%   mean set in ALLEEG, the name of a published template set in the
%   microstates/Templates folder, or "manual" for manual sorting. If not
%   provided, a GUI will appear to select a template set.
%
%   "IgnorePolarity"
%   -> 1 = Consider maps with inverted polarities the same class, 0 =
%   consider maps with inverted polarites different classes. If not
%   provided, a GUI will appear to select this option.
%
%   "Classes"
%   -> Array of class numbers indicating which cluster solutions to sort.
%   If TemplateSet is "manual", only one class number can be provided. If
%   not provided, a GUI will appear to select the cluster solution(s) to
%   sort.
%
%   "SortAll"
%   -> 1 = Sort all other solutions by the selected solution to sort, 0 =
%   only sort the selected solution(s). Ignored if there is more than one
%   solution selected to sort (e.g. "Classes" has more than one element)
%
%   "SortOrder" (only used for manual sorting)
%   -> Array of microstate map indices to use for manual reordering. Use a
%   negative index to flip the polarity of the indexed map. Ignored if
%   "TemplateSet" is not "manual"
%
%   "NewLabels" (only used for manual sorting)
%   -> String array or cell array of character vectors of new microstate
%   map labels. Ignored if "TemplateSet" is not "manual"
%
% Outputs:
%
%   "EEG" 
%   -> EEG structure array containing sorted datasets
%
%   "CURRENTSET"
%   -> Indices of the sorted datasets
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
function [AllEEG, EEGout, CurrentSet, com] = pop_SortMSTemplates(AllEEG, varargin)
    
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
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector'}));
    addParameter(p, 'SortOrder', [],  @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector'}));
    addParameter(p, 'NewLabels', [], @(x) validateattributes(x, {'char', 'string', 'cell'}, {'vector'}));
    addParameter(p, 'SortAll', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    IgnorePolarity = p.Results.IgnorePolarity;
    TemplateSet = p.Results.TemplateSet;
    Classes = p.Results.Classes;    
    SortOrder = p.Results.SortOrder;
    NewLabels = p.Results.NewLabels;
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
    isPublishedSet = arrayfun(@(x) matches(AllEEG(x).setname, {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(and(and(and(~isEmpty, ~HasDyn), HasMS), ~isPublishedSet));
    
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
                    {{ 'Style', 'text', 'string', 'Choose sets for sorting'}} ...
                    {{ 'Style', 'text', 'string', 'Use ctrlshift for multiple selection'}} ...
                    {{ 'Style', 'text', 'string', 'If using the interactive explorer, only one set can be chosen' 'FontWeight', 'bold'}} ...
                    {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom  = [guiGeom  1 1 1 1];
        guiGeomV = [guiGeomV  1 1 1 4];
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
        % If the template set is a number, make sure it is one of the
        % mean sets in ALLEEG
        if isnumeric(TemplateSet)
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
        % the mean setnames, published template setnames, or "manual"
        else
            if strcmpi(TemplateSet, 'manual')
                manualSort = true;
            elseif matches(TemplateSet, publishedSetnames)
                usingPublished = true;
                TemplateIndex = sortOrder(matches(publishedSetnames, TemplateSet));
                TemplateName = TemplateSet;
            elseif matches(TemplateSet, meanSetnames)
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
            else
                errorMessage = sprintf(['The specified template set "%s" could not be found in the ALLEEG ' ...
                    'mean sets or in the microstates/Templates folder.'], TemplateSet);
                errordlg2([errorMessage], 'Sort microstate maps error');
                return;
            end
        end

    % Otherwise, add template set selection gui elements
    else        
        if numel(SelectedSets) > 1
            combinedSetnames = [meanSetnames publishedDisplayNames];
        else
            % Check if there is already a interactive explorer open for the
            % selected set
            if ~isempty(findobj('Name', ['Microstate maps of ' AllEEG(SelectedSets).setname]))
                combinedSetnames = [meanSetnames publishedDisplayNames];
            else
                combinedSetnames = ['Manual or template sort in interactive explorer' meanSetnames publishedDisplayNames];
            end
        end
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Name of template set to sort by', 'fontweight', 'bold'}} ...
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
             'title','Edit & sort template maps');

        if isempty(res); return; end
        
        if isfield(outstruct, 'SelectedSets')
            SelectedSets = AvailableSets(outstruct.SelectedSets);
        end

        if isfield(outstruct, 'TemplateIndex')
            if contains('Manual or template sort in interactive explorer', combinedSetnames)
                if outstruct.TemplateIndex == 1
                    manualSort = true;
                elseif outstruct.TemplateIndex <= numel(meanSetnames)+1
                    TemplateIndex = outstruct.TemplateIndex-1;
                    TemplateSet = meanSets(TemplateIndex);
                    TemplateName = meanSetnames{TemplateIndex};
                else
                    TemplateIndex = outstruct.TemplateIndex - numel(meanSetnames) - 1;
                    TemplateSet = publishedSetnames{TemplateIndex};
                    TemplateIndex = sortOrder(TemplateIndex);
                    usingPublished = true;
                end
            else
                if outstruct.TemplateIndex <= numel(meanSetnames)
                    TemplateIndex = outstruct.TemplateIndex;
                    TemplateSet = meanSets(TemplateIndex);
                    TemplateName = meanSetnames{TemplateIndex};
                else
                    TemplateIndex = outstruct.TemplateIndex - numel(meanSetnames);
                    TemplateSet = publishedSetnames{TemplateIndex};
                    TemplateIndex = sortOrder(TemplateIndex);
                    usingPublished = true;
                end
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

    %% Handle manual/interactive sort case
    if manualSort
        % Check that only one set was selected
        if numel(SelectedSets) > 1
            errordlg2('Only one dataset can be chosen for manual sorting.', 'Sort microstate maps error');
            return;
        end

        % If all parameters are provided, perform manual sorting without GUI
        % and return
        if ~isempty(Classes) && ~isempty(SortOrder) && ~isempty(NewLabels)
            ClassRange = AllEEG(SelectedSets).msinfo.ClustPar.MinClasses:AllEEG(SelectedSets).msinfo.ClustPar.MaxClasses;
            [SortedMaps, com] = ManualSort(AllEEG(SelectedSets).msinfo.MSMaps, SortOrder, NewLabels, Classes, ClassRange);
            if isempty(SortedMaps); return; end

            % Sort all if selected
            IgnorePolarity = AllEEG(SelectedSets).msinfo.ClustPar.IgnorePolarity;
            if SortAll                
                SortedMaps = SortAllSolutions(SortedMaps, ClassRange, Classes, IgnorePolarity);
            end

            AllEEG(SelectedSets).msinfo.MSMaps = SortedMaps;
            EEGout = AllEEG(SelectedSets);
            CurrentSet = SelectedSets;
        
            NewLabelsTxt = sprintf('''%s'', ', string(NewLabels));
            NewLabelsTxt = ['{' NewLabelsTxt(1:end-2) '}'];
            if SortAll
                com = sprintf(['[ALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, %i, ''IgnorePolarity'', %i, ''TemplateSet'', ''manual'', ''Classes'', %i, ''SortOrder'', ' ...
                    '%s, ''NewLabels'', %s, ''SortAll'', %i);'], SelectedSets, IgnorePolarity, Classes, mat2str(SortOrder), NewLabelsTxt, SortAll);
            else
                com = sprintf(['[ALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, %i, ''TemplateSet'', ''manual'', ''Classes'', %i, ''SortOrder'', ' ...
                    '%s, ''NewLabels'', %s);'], SelectedSets, Classes, mat2str(SortOrder), NewLabelsTxt);
            end

            return;
        else
            [AllEEG, EEGout, CurrentSet, com] = InteractiveSort(AllEEG, SelectedSets);
            return;
        end
    end

    if usingPublished
        ChosenTemplate = MSTEMPLATE(TemplateIndex);
    else
        ChosenTemplate = AllEEG(meanSets(TemplateIndex));
    end

    %% Prompt user to select class range and option to sort all if necessary
    AllMinClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, SelectedSets);
    AllMaxClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, SelectedSets);
    MinClasses = min(AllMinClasses);
    MaxClasses = max(AllMaxClasses);
    if contains('Classes', p.UsingDefaults)
        classRange = MinClasses:MaxClasses;
        classChoices = sprintf('%i Classes|', classRange);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1], 'geomvert', [1 1 4 1], 'uilist', ...
            { {'Style', 'text', 'string', 'Select classes to sort'} ...
              {'Style', 'text', 'string' 'Use ctrlshift for multiple selection'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 2, 'Value', 1:numel(classRange), 'Tag', 'Classes', 'Callback', @solutionChanged}, ...
              {'Style', 'checkbox', 'string', 'Use selected solution to reorder all other solutions', 'Value', SortAll, 'Tag', 'SortAll', 'Enable', 'off'}}, ...
              'title', 'Sort microstate maps');
        
        if isempty(res); return; end

        Classes = classRange(outstruct.Classes);
        SortAll = outstruct.SortAll;
    else
        if any(Classes < MinClasses) || any(Classes > MaxClasses)
            invalidClasses = Classes(or((Classes < MinClasses), (Classes > MaxClasses)));
            invalidClassesTxt = sprintf('%i, ', invalidClasses);
            invalidClassesTxt = invalidClassesTxt(1:end-2);
            errorMessage = sprintf(['The following specified cluster solutions to sort are invalid: %s' ...
                '. Valid class numbers are in the range %i-%i.'], invalidClassesTxt, MinClasses, MaxClasses);
            errordlg2(errorMessage, 'Sort microstate maps error');
            return;
        end
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
    TemplateMinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
    TemplateMaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;    
    for index = 1:length(SelectedSets)
        fprintf('Sorting dataset %i of %i\n', index, numel(SelectedSets));
        sIndex = SelectedSets(index);

        if ~any(ismember(Classes, AllEEG(sIndex).msinfo.ClustPar.MinClasses:AllEEG(sIndex).msinfo.ClustPar.MaxClasses))
            continue
        end

        for n = Classes            

            % skip class number if the current set does not contain the
            % current cluster solution
            if n > AllEEG(sIndex).msinfo.ClustPar.MaxClasses
                continue
            elseif n < AllEEG(sIndex).msinfo.ClustPar.MinClasses
                continue
            end

            if n >= 10
                warning('Automatic sorting is not supported for 10 classes or greater. Please use manual sorting instead. Skipping remaining cluster solutions...');
                break
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

            % If the template set has unassigned maps, remove them (only
            % base sorting on assigned maps)
            nAssignedLabels = sum(~arrayfun(@(x) all(ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).ColorMap(x,:) == [.75 .75 .75]), 1:TemplateClassesToUse));
            if nAssignedLabels < TemplateClassesToUse && nAssignedLabels > 0 
                TemplateMaps(nAssignedLabels+1:end,:) = [];
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
            if numel(AllEEG(sIndex).msinfo.MSMaps(n).ExpVar) > 1
                AllEEG(sIndex).msinfo.MSMaps(n).ExpVar = AllEEG(sIndex).msinfo.MSMaps(n).ExpVar(SortOrder(SortOrder <= n));
            end

            % Update shared variance order
            if isfield(AllEEG(sIndex).msinfo.MSMaps(n), 'SharedVar')
                AllEEG(sIndex).msinfo.MSMaps(n).SharedVar = AllEEG(sIndex).msinfo.MSMaps(n).SharedVar(SortOrder(SortOrder <= n));
            end

            if usingPublished
                AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'published template';
                AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.setname];
            else
                if strcmp(ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).SortMode, 'none')
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'mean map';
                    AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.setname];
                else
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = [ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).SortMode '->mean map'];
                    AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = [ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).SortedBy '->' ChosenTemplate.setname];
                end
            end
            
            AllEEG(sIndex).msinfo.MSMaps(n).SpatialCorrelation = SpatialCorrelation;
            AllEEG(sIndex).saved = 'no';            
        end

        if SortAll && numel(Classes) == 1
            disp(['Sorting unselected solutions by selected solution' newline]);
            % Sort unsorted solutions by the sorted solution
            AllClasses = AllEEG(sIndex).msinfo.ClustPar.MinClasses:AllEEG(sIndex).msinfo.ClustPar.MaxClasses;
            AllEEG(sIndex).msinfo.MSMaps = SortAllSolutions(AllEEG(sIndex).msinfo.MSMaps, AllClasses, Classes, IgnorePolarity);
        end

    end

    EEGout = AllEEG(SelectedSets);
    CurrentSet = SelectedSets;

    %% Command string generation
    if ischar(TemplateSet) || isstring(TemplateSet)
        com = sprintf('[ALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, %s, ''IgnorePolarity'', %i, ''TemplateSet'', ''%s'', ''Classes'', %s, ''SortAll'', %i);', mat2str(SelectedSets), IgnorePolarity, TemplateSet, mat2str(Classes), SortAll);
    elseif isnumeric(TemplateSet)
        com = sprintf('[ALLEEG, EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, %s, ''IgnorePolarity'', %i, ''TemplateSet'', %i, ''Classes'', %s, ''SortAll'', %i);', mat2str(SelectedSets), IgnorePolarity, TemplateSet, mat2str(Classes), SortAll);
    end        
end

function solutionChanged(obj, event)
    sortAll = findobj(obj.Parent, 'Tag', 'SortAll');
    if numel(obj.Value) > 1    
        sortAll.Enable = 'off';
    else
        sortAll.Enable = 'on';
    end
end

function [TemplateNames, DisplayNames, sortOrder] = getTemplateNames()
    global MSTEMPLATE;
    TemplateNames = {MSTEMPLATE.setname};
    minClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, 1:numel(MSTEMPLATE));
    maxClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MaxClasses, 1:numel(MSTEMPLATE));
    [minClasses, sortOrder] = sort(minClasses, 'ascend');
    maxClasses = maxClasses(sortOrder);
    classRangeTxt = string(minClasses);
    diffMaxClasses = maxClasses ~= minClasses;
    classRangeTxt(diffMaxClasses) = sprintf('%s - %s', classRangeTxt(diffMaxClasses), string(maxClasses(diffMaxClasses)));
    TemplateNames = TemplateNames(sortOrder);
    nSubjects = arrayfun(@(x) MSTEMPLATE(x).msinfo.MetaData.nSubjects, sortOrder);
    nSubjects = arrayfun(@(x) sprintf('n=%i', x), nSubjects, 'UniformOutput', false);
    DisplayNames = strcat(classRangeTxt, " maps - ", TemplateNames, " - ", nSubjects);
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

    % find non-empty children fields
    nonempty = arrayfun(@(x) ~isempty(AllEEG(x).msinfo.children), SetsToSearch(HasChildren));
    if ~any(nonempty)
        return;
    end
    HasChildren = HasChildren(nonempty);

    % search the children of all the mean sets for the child set name
    containsChild = any(arrayfun(@(x) matches(childSetName, AllEEG(x).msinfo.children), SetsToSearch(HasChildren)));

    % if the child cannot be found, search the children of the children
    if ~containsChild
        childSetIndices = unique(cell2mat(arrayfun(@(x) find(matches({AllEEG.setname}, AllEEG(x).msinfo.children)), SetsToSearch(HasChildren), 'UniformOutput', false)));
        containsChild = checkSetForChild(AllEEG, childSetIndices, childSetName);
    end

end