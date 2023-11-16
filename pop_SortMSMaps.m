% pop_SortMSMaps() Reorder microstate maps based on existing template
% maps or manual indexing.
%
% Usage: 
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 
%       SelectedSets, 'key1', value1, 'key2', value2, ...)
%
% SORTING BY TEMPLATE MAPS:
% To sort by an existing set of template maps, use the "TemplateSet"
% argument to specify either the index of a mean set, name of a mean set,
% name of a published set, or "own" to use a cluster solution from the same
% dataset(s) being sorted. 
% Use the "Classes" argument to specify which cluster solutions of the
% datasets should be sorted.
% Use the "TemplateClasses" argument to specify which solution from the 
% template set to use for sorting.
% Use "IgnorePolarity" argument to specify whether polarity should be 
% considered.
%
% If the "Classes" argument is specified as "all", all cluster solutions of 
% the chosen datasets will be sorted. If "Classes" is not provided, it is
% set to "all" by default.
%
% If the "TemplateClasses" argument is specified as "all", the cluster 
% solutions of the specified datasets to sort will be sorted by the equal 
% or closest cluster solutions of the chosen template set. 
% For example, if a grand mean dataset derived from a group of subject 
% level datasets with 4-7 cluster solutions is chosen for sorting, the 4 
% map solution of the grand mean set will be used to sort the 4 map 
% solutions of the subject level datasets, the 5 map solution will be used
% to sort the 5 map solutions of the subject level datasets, and so on. If 
% a cluster solution exists in a dataset to sort but does not exist in the
% template set, the next closest cluster solution will be used. 
% If "TemplateClasses" is not provided, it is set to "all" by default.
%
% This does NOT apply if "TemplateSet" is "own." In this case, a
% single cluster solution must be provided for "TemplateClasses".
%
% Ex: Sort subject level maps (1-20) by mean maps (21) using one-to-one  
% sorting for each cluster solution. 
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1:20, 
%       'TemplateSet', 21, 'IgnorePolarity', 1);
% (Equivalent to):
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1:20, 
%       'TemplateSet', 21, 'Classes', 'all', 'TemplateClasses', 'all', 
%       'IgnorePolarity', 1);
%
% Ex: Use the mean dataset name
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1:20, 
%   'TemplateSet', 'GrandMean', 'IgnorePolarity', 1);
%
% Ex: Use published set names
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1:20, 
%       'TemplateSet', 'Koenig2002', 'Classes', 4:6, 'IgnorePolarity', 1);
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1:20, 
%       'TemplateSet', 'Custo2017', 'Classes', 7, 'IgnorePolarity', 1);
%
% Ex: Sort all subject level cluster solutions by the 7 class solution
% of a grand mean dataset.
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1:20,
%   'TemplateSet', 'GrandMean', 'TemplateClasses', 7, 'IgnorePolarity', 1);
%
% Ex: Sort a subset of subject level cluster solutions by the 6 class
% solution of the published Koenig 2002 maps.
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1:20,
%   'TemplateSet', 'Koenig2002', 'Classes', 4:6, 'TemplateClasses', 6,
%   'IgnorePolarity', 1);
%
% If "TemplateSet" is "own", a single cluster solution must be provided for
% the "TemplateClasses" argument. In this case, the specified solution will
% be used to reorder the solutions provided in the "Classes" argument. 
% If "Classes" is "all", an additional parameter "Stepwise" can optionally 
% be set to true. This will reorder all solutions of the datasets to be
% sorted in a stepwise manner, rather than directly sorting the solutions
% by the solution specified in the "TemplateClasses" argument. Stepwise
% sorting will sort each cluster solution by the adjacent solution. 
% 
% For example, if the 7 class solution of a dataset with 4-7 solutions is 
% used to stepwise sort the 4-6 cluster solutions, the following will occur:
% 1. 7 class solution sorts the 6 class solution
% 2. 6 class solution sorts the 5 class solution
% 3. 5 class solution sorts the 4 class solution
%
% If the "TemplateClasses" solution is not the largest cluster solution,
% stepwise sorting will occur in both directions. For example, if the 6
% class solution of a dataset with 4-8 solutions is used for stepwise
% sorting, the following will occur:
% 1. Downward: 6 classes sorts 5 classes -> 5 classes sorts 4 classes
% 2. Upward: 6 classes sorts 7 classes -> 7 classes sorts 8 classes
%
% If "Stepwise" is not provided, it is set to false by default.
%
% Ex: Sort the 6 class solution of a dataset by the 7 class solution.
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1,
%   'TemplateSet', 'own', 'Classes', 6, 'TemplateClasses', 7);
%
% Ex: Use stepwise sorting to sort all solutions of a dataset by the 7
% class solution.
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1,
%   'TemplateSet', 'own', 'TemplateClasses', 7, 'Stepwise', 1);
%
% MANUAL SORTING:
% To sort or relabel maps manually, specify "TemplateSet" as "manual."
% Only one dataset can be passed in for manual sorting at a time.
% Use the "Classes" argument to specify which cluster solution to reorder.
% When manual sorting, this can only be one solution. 
% Use the "SortOrder" argument to pass in a vector of integers representing
% the new ordering, with negative integers indicating a flip in polarity. 
% Use the "NewLabels" argument to pass in the new labels for the maps. 
%
% If only "NewLabels" are provided without the "SortOrder" argument,
% template maps will be relabeled but not resorted. 
%
% Ex: Manual sort and relabel
%   >> [ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, 1, 
%       'TemplateSet', 'manual', 'Classes', 4, 'SortOrder', [-4 2 3 -1],
%       'NewLabels', {'A', 'B', 'C', 'D'});
%
% Graphical interface:
%
%   "Choose sets for sorting"
%   -> Select sets to sort
%   -> Command line equivalent: "SelectedSets"
%
%   "Name of template map to sort by"
%   -> Select the "Manual or template sort in interactive explorer" option
%   if you would like to use the interactive explorer to sort and view the
%   template maps of one set. This option can also be used to manually
%   reorder and relabel microstate maps. Otherwise, choose a mean template
%   name, published template name, or "own" to reorder maps based on the 
%   map order of the specified template. 
%   Note: the interactive explorer option may only be used for one set.
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
%   "Template solution to sort by"
%   -> Select the cluster solution of the template set to use for sorting.
%   Select "All" to perform one-to-one sorting for each cluster solution
%   (only applicable if own tempalte maps are not being used).
%
%   "Use stepwise sorting to reorder all solutions."
%   -> Only appears if own template maps are selected to use for sorting.
%   Check this box to sort all cluster solutions by the selected template
%   solution.
%   -> Command line equivalent: "Stepwise"
%
% Interactive sorting graphical interface:
%
%  "Select solution(s) to sort"
%   -> Select which cluster solution(s) to reorder. Multiple solutions can
%   be selected if using template sorting. Only one solution can be
%   selected if performing manual sorting.
%   -> Command line equivalent: "Classes"
%
%   "Choose sorting procedure"
%   -> Select which type of sorting to perform: manual sorting based on map
%   indices, template sorting based on a mean set or published set, or
%   stepwise sorting of all solutions based on a selected solution of the
%   same dataset.
%
%   "Select template" (only used for template sorting)
%   -> Select "own", the mean template name or published template name to 
%   use for sorting.
%   -> Command line equivalent: "TemplateSet"
%
%   "Select template solution" (only used for template sorting)
%   -> Select the cluster solution of the template set to use for sorting.
%   Select "All" to perform one-to-one sorting for each cluster solution
%   (only applicable if own template maps are not being used).
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
%   "Ignore polarity" (only used for template sorting)
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
%   -> Vector of set indices of ALLEEG to sort. If not provided, a GUI
%   will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "TemplateSet"
%   -> Integer, string, or character vector specifying the template set to
%   sort by. Can be either the index of a mean set in ALLEEG, the name of a
%   mean set in ALLEEG, the name of a published template set in the
%   microstates/Templates folder, "own" to use a dataset's own maps, or 
%   "manual" for manual sorting. If not provided, a GUI will appear 
%   to select a template set.
%
%   "Classes"
%   -> Vector of class numbers indicating which cluster solutions to sort.
%   If TemplateSet is "manual", only one class number can be provided. 
%   Default = "all" (sort all cluster solutions)
%
%   "TemplateClasses"
%   -> Scalar indicating cluster solution of the template set to use for 
%   sorting. Ignored if TemplateSet is "manual".
%   Default = "all" (use all template solutions to perform one-to-one
%   sorting between template set solutions and dataset solutions to sort)
%
%   "IgnorePolarity"
%   -> 1 = Consider maps with inverted polarities the same class, 0 =
%   consider maps with inverted polarites different classes. If not
%   provided, a GUI will appear to select this option. Ignored if
%   "TemplateSet" is "manual".
%
%   "Stepwise"
%   -> 1 = Use stepwise sorting to sort all solutions by the specified
%   "TemplateClasses" solution when sorting by own maps, 0 = sort all
%   solutions directly by the specified "TemplateClasses" solution. Ignored
%   if "TemplateSet" is not "own"
%   Default = 0 (no stepwise sorting)
%
%   "SortOrder" (only used for manual sorting)
%   -> Array of microstate map indices to use for manual reordering. Use a
%   negative index to flip the polarity of the indexed map. Ignored if
%   "TemplateSet" is not "manual".
%
%   "NewLabels" (only used for manual sorting)
%   -> String array or cell array of character vectors of new microstate
%   map labels. Ignored if "TemplateSet" is not "manual".
%
% Outputs:
%
%   "ALLEEG"
%   -> ALLEEG structure array containing sorted datasets. May also include
%   updated child datasets with cleared/updated sorting information.
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
% MICROSTATELAB: The EEGLAB toolbox for resting-state microstate analysis
% Version 1.0
%
% Authors:
% Thomas Koenig (thomas.koenig@upd.unibe.ch)
% Delara Aryan  (dearyan@chla.usc.edu)
% 
% Copyright (C) 2023 Thomas Koenig and Delara Aryan
%
% If you use this software, please cite as:
% "MICROSTATELAB: The EEGLAB toolbox for resting-state microstate 
% analysis by Thomas Koenig and Delara Aryan"
% In addition, please reference MICROSTATELAB within the Materials and
% Methods section as follows:
% "Analysis was performed using MICROSTATELAB by Thomas Koenig and Delara
% Aryan."
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
function [AllEEG, EEGout, CurrentSet, com] = pop_SortMSMaps(AllEEG, varargin)

    [~,nogui] = eegplugin_microstatelab;

    %% Set defaults for outputs
    com = '';
    global MSTEMPLATE;
    global EEG;
    global CURRENTSET;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_SortMSMaps';
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'IgnorePolarity', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    addParameter(p, 'Classes', 'all', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    addParameter(p, 'TemplateClasses', 'all', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));
    addParameter(p, 'SortOrder', [],  @(x) validateattributes(x, {'numeric'}, {'integer', 'vector'}));
    addParameter(p, 'NewLabels', [], @(x) validateattributes(x, {'char', 'string', 'cell'}, {'vector'}));
    addParameter(p, 'Stepwise', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    IgnorePolarity = p.Results.IgnorePolarity;
    TemplateSet = p.Results.TemplateSet;
    Classes = p.Results.Classes;    
    TemplateClasses = p.Results.TemplateClasses;
    SortOrder = p.Results.SortOrder;
    NewLabels = p.Results.NewLabels;
    Stepwise = p.Results.Stepwise;

    if isnumeric(TemplateSet)
        validateattributes(TemplateSet, {'numeric'}, {'integer', 'scalar', 'positive', '<=', numel(AllEEG)}, 'pop_SortMSMaps', 'TemplateSet');
    else
        validateattributes(TemplateSet, {'char', 'string'}, {'scalartext'});
    end

    if isnumeric(Classes)
        try
            validateattributes(Classes, {'numeric'}, {'integer', 'positive', 'vector'});
        catch
            error('Invalid value provided for Classes. Expected Classes to be a scalar or vector of integers or "all".');
        end
    else
        Classes = char(Classes);
        if ~strcmpi(Classes, 'all')
            error('Invalid value provided for Classes. Expected Classes to be a scalar or vector of integers or "all".');
        end
    end

    if isnumeric(TemplateClasses)
        try
            validateattributes(TemplateClasses, {'numeric'}, {'integer', 'positive', 'scalar'});
        catch
            error('Invalid value provided for TemplateClasses. Expected TemplateClasses to be a scalar integer or "all".');
        end
    else
        TemplateClasses = char(TemplateClasses);
        if ~strcmpi(TemplateClasses, 'all')
            error('Invalid value provided for TemplateClasses. Expected TemplateClasses to be a scalar integer or "all".');
        end
    end

    if ~isempty(NewLabels)
        NewLabels = convertStringsToChars(NewLabels);
        invalidLabels = ~cellfun(@(x) ischar(x) || isstring(x), NewLabels);
        if any(invalidLabels)
            invalidTxt = sprintf('%i, ', find(invalidLabels));
            invalidTxt = invalidTxt(1:end-2);
            error('The following elements of NewLabels are invalid: %s. Expected all elements to be strings or chars.', invalidTxt);
        end
    end

    %% SelectedSets validation
    % First make sure there are valid sets for sorting
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isPublished = arrayfun(@(x) isPublishedSet(AllEEG(x), {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasDyn & ~isPublished);
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), AvailableSets);
    AvailableIndSets = AvailableSets(~HasChildren);
    AvailableMeanSets = AvailableSets(HasChildren);
    
    if isempty(AvailableSets)
        errorMessage = ['No valid sets found for plotting. Use ' ...
            '"Tools->Identify microstate maps per dataset" to find and store microstate map data.'];
        if isempty(SelectedSets)
            errorDialog(errorMessage, 'Edit & sort microstate maps error');
            return;
        else
            error(errorMessage);
        end
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        % Check for empty sets, dynamics sets, or any sets without
        % microstate maps
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidTxt = invalidTxt(1:end-2);
            error(['The following sets are invalid: ' invalidTxt ...
                '. Make sure you have not selected empty sets, dynamics sets, or sets ' ...
                'without microstate maps.']);
        end
    % Otherwise, add set selection gui elements
    else        
        ud.AvailableSets = AvailableSets;
        ud.AvailableIndSets = AvailableIndSets;
        ud.AvailableMeanSets = AvailableMeanSets;
        ud.AvailableSetnames = {AllEEG(AvailableSets).setname};
        ud.AvailableIndSetnames = {AllEEG(AvailableIndSets).setname};
        ud.AvailableMeanSetnames = {AllEEG(AvailableMeanSets).setname};
        ud.CurrentSet = CurrentSet;

        defaultSets = find(ismember(AvailableSets, CurrentSet));
        ud.defaultSets = defaultSets;
        if isempty(defaultSets);    defaultSets = 1;    end

        setOptions = {'Individual datasets and mean sets', 'Only individual datasets', 'Only mean sets'};

        guiElements = [guiElements, ....
                    {{ 'Style', 'text', 'string', 'Choose sets for sorting', 'FontWeight', 'bold'}} ...
                    {{ 'Style', 'text', 'string', 'Use ctrl or shift for multiple selection'}} ...
                    {{ 'Style', 'text', 'string', 'If using the interactive explorer, only one set can be chosen'}} ...
                    {{ 'Style', 'text', 'string', 'Display options'}} ...
                    {{ 'Style', 'popupmenu', 'string', setOptions, 'Callback', @displayedSetsChanged, 'Tag', 'DisplayedSets'}} ...
                    {{ 'Style', 'text', 'string', ''}} ...
                    {{ 'Style', 'listbox' , 'string', ud.AvailableSetnames, 'Min', 0, 'Max', 1,'Value', defaultSets(1), 'tag','SelectedSets', 'UserData', ud}}];
        guiGeom  = [guiGeom  1 1 1 [4 6] 1 1];
        guiGeomV = [guiGeomV  1 1 1 1 1 4];
    end

    %% TemplateSet validation
    % If the user has provided a template set number or name, check its
    % validity
    meanSetnames = {AllEEG(AvailableMeanSets).setname};
    [publishedSetnames, publishedDisplayNames, sortOrder] = getTemplateNames();
    TemplateIndex = 1;
    usingPublished = false;
    if ~isempty(TemplateSet)        
        % If the template set is a number, make sure it is one of the
        % mean sets in ALLEEG
        if isnumeric(TemplateSet)
            if ~ismember(TemplateSet, AvailableMeanSets)
                error(['The specified template set number %i is not a valid mean set. ' ...
                    'Make sure you have not selected an individual set or a dynamics set.'], TemplateSet);
            else
                TemplateIndex = find(ismember(AvailableMeanSets, TemplateSet));
                TemplateName = meanSetnames{TemplateIndex};
            end
        % Else if the template set is a string, make sure it matches one of
        % the mean setnames, published template setnames, "manual", or
        % "own"
        else
            if matches(TemplateSet, publishedSetnames)
                usingPublished = true;
                TemplateIndex = sortOrder(matches(publishedSetnames, TemplateSet));
                TemplateName = TemplateSet;
            elseif matches(TemplateSet, meanSetnames)
                % If there are multiple mean sets with the same name
                % provided, notify the suer
                if numel(find(matches(meanSetnames, TemplateSet))) > 1
                    error(['There are multiple mean sets with the name "%s." ' ...
                        'Please specify the set number instead ot the set name.'], TemplateSet);
                else
                    TemplateIndex = find(matches(meanSetnames, TemplateSet));
                    TemplateName = TemplateSet;
                    TemplateSet = AvailableMeanSets(TemplateIndex);
                end            
            elseif ~matches(TemplateSet, {'manual', 'own', 'Manual', 'Own'})
                error(['The specified template set "%s" could not be found in the ALLEEG ' ...
                    'mean sets or in the microstates/Templates folder.'], TemplateSet);
            end
        end

    % Otherwise, add template set selection gui elements
    else        
        if numel(SelectedSets) > 1
            combinedSetnames = ['Own' meanSetnames publishedDisplayNames];
        else
            % Check if there is already a interactive explorer open for the
            % selected set
            if ~isempty(findobj('Name', ['Microstate maps of ' AllEEG(SelectedSets).setname]))
                combinedSetnames = ['Own' meanSetnames publishedDisplayNames];
            else
                combinedSetnames = ['Manual or template sort in interactive explorer' 'Own' meanSetnames publishedDisplayNames];
            end
        end
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', 'Name of template set to sort by', 'fontweight', 'bold'}} ...
            {{ 'Style', 'popupmenu', 'string', combinedSetnames, 'tag', 'TemplateIndex', 'Value', TemplateIndex, 'Callback', @templateChanged }}];
        guiGeom = [guiGeom 1 1];
        guiGeomV = [guiGeomV 1 1];
    end

    %% Add other gui elements
    if matches('IgnorePolarity', p.UsingDefaults) && ~strcmpi(TemplateSet, 'manual')
        guiElements = [guiElements ...
            {{ 'Style', 'checkbox', 'string', 'No polarity','tag','IgnorePolarity','Value', IgnorePolarity, 'Enable', 'off' }}];
        guiGeom = [guiGeom 1];
        guiGeomV = [guiGeomV 1];
    end

    %% Prompt user to fill in remaining parameters if necessary
    if ~isempty(guiElements)
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Edit & sort microstate maps');

        if isempty(res); return; end
        
        if isfield(outstruct, 'SelectedSets')
            if outstruct.DisplayedSets == 1
                SelectedSets = AvailableSets(outstruct.SelectedSets);
            elseif outstruct.DisplayedSets == 2
                SelectedSets = AvailableIndSets(outstruct.SelectedSets);
            else
                SelectedSets = AvailableMeanSets(outstruct.SelectedSets);
            end
        end

        if isfield(outstruct, 'TemplateIndex')
            if matches('Manual or template sort in interactive explorer', combinedSetnames)
                if outstruct.TemplateIndex == 1
                    TemplateSet = 'manual';
                elseif outstruct.TemplateIndex == 2
                    TemplateSet = 'own';
                elseif outstruct.TemplateIndex <= numel(meanSetnames)+2
                    TemplateIndex = outstruct.TemplateIndex-2;
                    TemplateSet = AvailableMeanSets(TemplateIndex);
                    TemplateName = meanSetnames{TemplateIndex};
                else
                    TemplateIndex = outstruct.TemplateIndex - numel(meanSetnames) - 2;
                    TemplateSet = publishedSetnames{TemplateIndex};
                    TemplateName = TemplateSet;
                    TemplateIndex = sortOrder(TemplateIndex);
                    usingPublished = true;
                end
            else
                if outstruct.TemplateIndex == 1
                    TemplateSet = 'own';                    
                elseif outstruct.TemplateIndex <= numel(meanSetnames)+1
                    TemplateIndex = outstruct.TemplateIndex-1;
                    TemplateSet = AvailableMeanSets(TemplateIndex);
                    TemplateName = meanSetnames{TemplateIndex};
                else
                    TemplateIndex = outstruct.TemplateIndex - numel(meanSetnames) - 1;
                    TemplateSet = publishedSetnames{TemplateIndex};
                    TemplateName = TemplateSet;
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
        errordlg2('You must select at least one dataset','Edit & sort microstate maps error');
        return;
    end

    %% Handle manual/interactive sort case
    if strcmpi(TemplateSet, 'manual')
        % Check that only one set was selected
        if numel(SelectedSets) > 1
            error('Only one dataset can be chosen for manual sorting.');
        end

        % If parameters are provided, perform manual sorting without the
        % GUI and return
        classRange = AllEEG(SelectedSets).msinfo.ClustPar.MinClasses:AllEEG(SelectedSets).msinfo.ClustPar.MaxClasses;
        if ~isempty(Classes) && ~isempty(NewLabels)            
            SortedMaps = ManualSort(AllEEG(SelectedSets).msinfo.MSMaps, SortOrder, NewLabels, Classes, classRange);
            if isempty(SortedMaps); return; end

            AllEEG(SelectedSets).msinfo.MSMaps = SortedMaps;
            EEGout = AllEEG(SelectedSets);
            CurrentSet = SelectedSets;
        
            NewLabelsTxt = sprintf('''%s'', ', string(NewLabels));
            NewLabelsTxt = ['{' NewLabelsTxt(1:end-2) '}'];
            if isempty(SortOrder)
                com = sprintf(['[ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, %i, ''TemplateSet'', ''manual'', ''Classes'', %i,' ...
                    ' ''NewLabels'', %s);'], SelectedSets, Classes, NewLabelsTxt);
            else
                com = sprintf(['[ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, %i, ''TemplateSet'', ''manual'', ''Classes'', %i,' ...
                    ' ''SortOrder'', %s, ''NewLabels'', %s);'], SelectedSets, Classes, mat2str(SortOrder), NewLabelsTxt);
            end

            return;
        else
            % Ask for range of classes to display in interactive window
            classChoices = arrayfun(@(x) {sprintf('%i Classes', x)}, classRange);
            [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
                { {'Style', 'text', 'String', 'Select cluster solutions to display in interactive explorer'} ...
                  {'Style', 'listbox', 'String', classChoices, 'Min', 0, 'Max', 2, 'Value', 1:numel(classRange), 'Tag', 'Classes'}}, ...
                'title','Edit & sort microstate maps');

            if isempty(res); return; end
            Classes = classRange(outstruct.Classes);

            [EEGout, CurrentSet, childIdx, childEEG, com] = InteractiveSort(AllEEG, SelectedSets, Classes);
            global ALLEEG;
            AllEEG = ALLEEG;            % refresh ALLEEG in case user modified datasets while explorer was open
            AllEEG = eeg_store(AllEEG, EEGout, CurrentSet);
            if ~isempty(childIdx)
                AllEEG = eeg_store(AllEEG, childEEG, childIdx);
            end
            return;
        end
    end

    if ~strcmpi(TemplateSet, 'own')
        if usingPublished
            ChosenTemplate = MSTEMPLATE(TemplateIndex);
        else
            ChosenTemplate = AllEEG(AvailableMeanSets(TemplateIndex));
        end
    end

    %% Verify compatibility between selected sets to sort and template set
    % If the template set chosen is a mean set, make sure it is a parent
    % set of all the selected sets
    if ~usingPublished && ~strcmpi(TemplateSet, 'own')
        warningSetnames = {};
        for i = 1:length(SelectedSets)          
            sIndex = SelectedSets(i);
            if matches(AllEEG(sIndex).setname, ChosenTemplate.setname)
                continue
            end
            containsChild = checkSetForChild(AllEEG, AvailableMeanSets(TemplateIndex), AllEEG(sIndex).setname);
            if ~containsChild
                warningSetnames = [warningSetnames, AllEEG(sIndex).setname];
            end
        end

        if ~isempty(warningSetnames)
            if matches('TemplateSet', p.UsingDefaults) && getpref('MICROSTATELAB', 'showSortWarning')
                warningMessage = sprintf(['Template set "%s" is not the parent set of ' ...
                    'the following sets. Are you sure you would like to proceed?'], TemplateName);
                [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Backfit microstate maps warning', warningSetnames);
                if boxChecked;  setpref('MICROSTATELAB', 'showSortWarning', 0); end
                if ~yesPressed; return;                                         end
            else
                warningSetsTxt = sprintf(['%s' newline], string(warningSetnames));
                warning(['Template set "%s" is not the parent set of the following sets: ' newline warningSetsTxt], TemplateName);
            end
        end
    end

    %% Classes validation
    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    AllMinClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, SelectedSets);
    AllMaxClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, SelectedSets);

    % Classes to sort
    MinClasses = min(AllMinClasses);
    MaxClasses = max(AllMaxClasses);
    classRange = MinClasses:MaxClasses;
    if (matches('Classes', p.UsingDefaults) && matches('TemplateSet', p.UsingDefaults)) ...
            || (strcmpi(TemplateSet, 'own') && matches('TemplateClasses', p.UsingDefaults))
        classChoices = arrayfun(@(x) {sprintf('%i Classes', x)}, classRange);
        if isnumeric(Classes)
            ud.prevSelection = find(ismember(classRange, Classes));
        else
            ud.prevSelection = 1:numel(classRange);
        end

        guiElements = [guiElements ...
            {{'Style', 'text', 'string', 'Select classes to sort', 'fontweight', 'bold'}} ...
            {{'Style', 'text', 'string' 'Use ctrl or shift for multiple selection'}} ...
            {{'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 2, 'Value', ud.prevSelection, 'Tag', 'Classes', 'UserData', ud}} ];
        guiGeom = [guiGeom 1 1 1];
        guiGeomV = [guiGeomV 1 1 4];        
    else
        if isnumeric(Classes) && (any(Classes < MinClasses) || any(Classes > MaxClasses))
            invalidClasses = Classes((Classes < MinClasses) | (Classes > MaxClasses));
            invalidClassesTxt = sprintf('%i, ', invalidClasses);
            invalidClassesTxt = invalidClassesTxt(1:end-2);
            error(['The following specified cluster solutions to sort are invalid: %s' ...
                '. Valid class numbers are in the range %i-%i.'], invalidClassesTxt, MinClasses, MaxClasses);
        end        
    end

    % Template classes
    if strcmpi(TemplateSet, 'own')
        TemplateMinClasses = max(AllMinClasses);
        TemplateMaxClasses = min(AllMaxClasses);
        if TemplateMaxClasses < TemplateMinClasses
            errorMessage = 'No overlap in microstate classes found between all selected sets for selecting a template solution.';
            if matches('TemplateSet', p.UsingDefaults)
                errordlg2(errorMessage, 'Edit & sort microstate maps error');
                return;
            else
                error(errorMessage);
            end            
        end
    else
        TemplateMinClasses = ChosenTemplate.msinfo.ClustPar.MinClasses;
        TemplateMaxClasses = ChosenTemplate.msinfo.ClustPar.MaxClasses;
    end

    templateClassRange = TemplateMinClasses:TemplateMaxClasses;
    if matches('TemplateClasses', p.UsingDefaults) && ...
            (matches('TemplateSet', p.UsingDefaults) || strcmpi(TemplateSet, 'own'))
        classChoices = arrayfun(@(x) {sprintf('%i Classes', x)}, templateClassRange);

        % Only show "All" option if there are multiple template solutions
        % and own template maps are not being used
        if ~strcmpi(TemplateSet, 'own') && (numel(templateClassRange) > 1)
            classChoices = ['All' classChoices];
            guiElements = [guiElements ...
                {{'Style', 'text', 'string', 'Select template solution to sort by', 'fontweight', 'bold'}} ...
                {{'Style', 'text', 'string' 'Select ''All'' to perform one-to-one sorting for each cluster solution.'}} ...
                {{'Style', 'popupmenu', 'string', classChoices, 'Tag', 'TemplateClasses'}} ];
            guiGeom = [guiGeom 1 1 1];
            guiGeomV = [guiGeomV 1 1 1];
        else
            guiElements = [guiElements ...
                {{'Style', 'text', 'string', 'Select template solution to sort by', 'fontweight', 'bold'}} ...
                {{'Style', 'popupmenu', 'string', classChoices, 'Tag', 'TemplateClasses'}} ];
            guiGeom = [guiGeom 1 1];
            guiGeomV = [guiGeomV 1 1];
        end
    else
        if isnumeric(TemplateClasses)
            if (TemplateClasses < TemplateMinClasses) || (TemplateClasses > TemplateMaxClasses)
                error('The specified template solution %i is invalid. Valid class numbers are in the range %i-%i.', ...
                    TemplateClasses, TemplateMinClasses, TemplateMaxClasses);
            end
        else
            % Make sure TemplateClasses is not "All" if sorting by own maps
            if strcmpi(TemplateSet, 'own')
                error(['A single cluster solution must be provided for ''TemplateClasses'' if sorting by own template maps. ' ...
                    '''all'' is only applicable for mean template sets or published template sets.']);
            end
        end
    end    

    % Stepwise sort checks
    if Stepwise
        % Override invalid Classes input if not all classes are selected
        if isnumeric(Classes) && ~all(ismember(classRange, Classes))
            warning(['Stepwise sorting reorders all cluster solutions of the selected datasets, ' ...
                'but ''Classes'' was set to %s. Overriding ''Classes'' to ''all''.'], mat2str(Classes));
            Classes = classRange;
        end

        % Show warning if template set is not 'own'
        if ~strcmpi(TemplateSet, 'own')
            warning(['Stepwise sorting is only applicable for sorting by a dataset''s own template maps. ' ...
                'Stepwise sorting will not be applied.']);
        end
    end

    %% Prompt user to select classes if necessary
    if ~isempty(guiElements)

        if nogui == true
            error("Parameters missing in function pop_SortMSMaps, check the help for pop_SortMSMaps for support");
        end
 
        % Add stepwise sorting option for sorting by own template if GUI is
        % being displayed
        if strcmpi(TemplateSet, 'own') && matches('Stepwise', p.UsingDefaults)
            guiElements = [guiElements ...
                {{ 'Style', 'checkbox', 'String', 'Use stepwise sorting to reorder all solutions by selected template solution', 'Value', 0, 'Tag', 'Stepwise', 'Callback', @stepwiseChanged}}];
            guiGeom = [guiGeom 1];
            guiGeomV = [guiGeomV 1];
        end
        
        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Edit & sort microstate maps');

        if isempty(res); return; end

        if isfield(outstruct, 'Classes')
            Classes = classRange(outstruct.Classes);            
        end

        if isfield(outstruct, 'TemplateClasses')
            if strcmpi(TemplateSet, 'own')
                TemplateClasses = templateClassRange(outstruct.TemplateClasses);
            else
                if outstruct.TemplateClasses == 1
                    TemplateClasses = 'all';
                else
                    TemplateClasses = templateClassRange(outstruct.TemplateClasses-1);
                end
            end
        end

        if isfield(outstruct, 'Stepwise')
            Stepwise = outstruct.Stepwise;
        end
    end

    %% Sorting    
    % Check that the template solution is sorted
    if numel(SelectedSets) == 1
        interactiveSort = ~isempty(findobj('Name', ['Microstate maps of ' AllEEG(SelectedSets).setname]));
    end

    if strcmpi(TemplateSet, 'own')
        SortModes = arrayfun(@(x) AllEEG(x).msinfo.MSMaps(TemplateClasses).SortMode, SelectedSets, 'UniformOutput', false);
        if matches('none', SortModes)
            if numel(SelectedSets) == 1
                errorMessage = sprintf('Selected template solution %i of dataset %s is unsorted. Please sort before using as a template solution', ...
                    TemplateClasses, AllEEG(SelectedSets).setname);
            else
                errorMessage = sprintf('Some %i class solutions of the selected datasets are unsorted. Please sort before using as a template solution.', ...
                    TemplateClasses);
            end
            if matches('TemplateSet', p.UsingDefaults) || interactiveSort
                errorDialog(errorMessage, 'Edit & sort microstate maps error');
                return;
            else
                error(errorMessage);
            end
        end

        % Check that the template solution and solution to sort are not the
        % same if sorting using own maps
        if all(Classes == TemplateClasses); return; end

    elseif ~usingPublished
        if strcmpi(TemplateClasses, 'all')
            tempClasses = Classes(Classes >= TemplateMinClasses & Classes <= TemplateMaxClasses);
            if any(Classes < TemplateMinClasses) && ~ismember(TemplateMinClasses, tempClasses)
                tempClasses = [TemplateMinClasses tempClasses];
            elseif any(Classes > TemplateMaxClasses) && ~ismember(TemplateMaxClasses, tempClasses)
                tempClasses = [tempClasses TemplateMaxClasses];
            end
            tempClasses = sort(tempClasses, 'ascend');
            SortMode = arrayfun(@(x) ChosenTemplate.msinfo.MSMaps(x).SortMode, tempClasses, 'UniformOutput', false);            
            if matches('none', SortMode)
                class = tempClasses(matches(SortMode, 'none'));
                classTxt = sprintf('%i, ', class);
                classTxt = classTxt(1:end-2);
                errorMessage = sprintf('The following cluster solutions of the template set %s are unsorted: %s. Please sort before using as template solutions.', TemplateName, classTxt);                    
                if matches('TemplateSet', p.UsingDefaults)
                    errorDialog(errorMessage, 'Edit & sort microstate maps error');
                    return;
                else
                    error(errorMessage);
                end
            end
        else
            SortMode = ChosenTemplate.msinfo.MSMaps(TemplateClasses).SortMode;
            if matches('none', SortMode)
                errorMessage = sprintf('Selected template solution %i of template set %s is unsorted. Please sort before using as a template solution.', TemplateClasses, TemplateName);
                if matches('TemplateSet', p.UsingDefaults) || interactiveSort
                    errorDialog(errorMessage, 'Edit & sort microstate maps error');
                    return;
                else
                    error(errorMessage);
                end
            end
        end            
    end

    if all(ismember(classRange, Classes))
        Classes = 'all';
    end

    if Stepwise
        for i=1:length(SelectedSets)
            fprintf('Sorting dataset %i of %i\n', i, numel(SelectedSets));
            sIndex = SelectedSets(i);

            MSMaps = StepwiseSort(AllEEG(sIndex).msinfo.MSMaps, AllEEG(sIndex).msinfo.ClustPar, AllEEG(sIndex).setname, TemplateClasses, IgnorePolarity);
            if isempty(MSMaps); continue;   end
            AllEEG(sIndex).msinfo.MSMaps = MSMaps;          
        end
    else        

        for i = 1:length(SelectedSets)
            fprintf('Sorting dataset %i of %i\n', i, numel(SelectedSets));
            sIndex = SelectedSets(i);

            if strcmpi(Classes, 'all')
                sortClasses = AllEEG(sIndex).msinfo.ClustPar.MinClasses:AllEEG(sIndex).msinfo.ClustPar.MaxClasses;
            else
                sortClasses = Classes;
            end
    
            for n = sortClasses            
    
                % skip class number if the current set does not contain the
                % current cluster solution
                if (n > AllEEG(sIndex).msinfo.ClustPar.MaxClasses) || (n < AllEEG(sIndex).msinfo.ClustPar.MinClasses)
                    continue;
                end            
    
                % find the number of template classes to use
                if ~strcmpi(TemplateClasses, 'all')
                    TemplateClassesToUse = TemplateClasses;
                else
                    if n < TemplateMinClasses
                        TemplateClassesToUse = TemplateMinClasses;
                    elseif n > TemplateMaxClasses
                        TemplateClassesToUse = TemplateMaxClasses;
                    else
                        TemplateClassesToUse = n;
                    end
                end

                % skip class number if own maps are being sorted by the
                % same solution
                if strcmpi(TemplateSet, 'own') && (n == TemplateClassesToUse)
                    continue;
                end
                % or if a mean set is being sorted by itself
                if ~strcmpi(TemplateSet, 'own') && ~usingPublished
                    if strcmp(TemplateName, AllEEG(sIndex).setname) && (n == TemplateClassesToUse)
                        continue;
                    end
                end
    
                if max(n, TemplateClassesToUse) >= 10 && (~license('test','optimization_toolbox') || isempty(which('intlinprog')))
                    warning(['Sorting using 10 or more classes requires the Optimization toolbox. ' ...
                        'Please install the toolbox using the Add-On Explorer. Skipping large cluster solutions...']);
                    break;
                end
    
                if ~strcmpi(TemplateSet, 'own')
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
                else
                    MapsToSort = zeros(1, n, AllEEG(sIndex).nbchan);
                    MapsToSort(1,:,:) = AllEEG(sIndex).msinfo.MSMaps(n).Maps;
                    ChosenTemplate = AllEEG(sIndex);
                    TemplateMaps = AllEEG(sIndex).msinfo.MSMaps(TemplateClassesToUse).Maps;
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
    
                if strcmpi(TemplateSet, 'own')
                    AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'own template maps';
                    AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = sprintf('%s->%s (%i classes)', ...
                        AllEEG(sIndex).msinfo.MSMaps(TemplateClassesToUse).SortedBy, AllEEG(sIndex).setname, TemplateClassesToUse);
                else
                    if usingPublished
                        AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'published template maps';
                        AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = sprintf('%s (%i classes)', ChosenTemplate.setname, TemplateClassesToUse);
                    else
                        if strcmp(TemplateName, AllEEG(sIndex).setname)
                            AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'own template maps';
                        else
                            AllEEG(sIndex).msinfo.MSMaps(n).SortMode = 'mean template maps';
                        end
                        AllEEG(sIndex).msinfo.MSMaps(n).SortedBy = sprintf('%s->%s (%i classes)', ...
                            ChosenTemplate.msinfo.MSMaps(TemplateClassesToUse).SortedBy, ChosenTemplate.setname, TemplateClassesToUse);
                    end
                end

                AllEEG(sIndex).msinfo.MSMaps(n).SpatialCorrelation = SpatialCorrelation;                        
            end

            AllEEG(sIndex).saved = 'no';
        end
    end

    EEGout = AllEEG(SelectedSets);
    CurrentSet = SelectedSets;

    %% Command string generation
    if isnumeric(TemplateSet)
        TemplateSet = int2str(TemplateSet);
    else
        TemplateSet = sprintf("'%s'", TemplateSet);
    end
    com = sprintf('[ALLEEG, EEG, CURRENTSET] = pop_SortMSMaps(ALLEEG, %s, ''TemplateSet'', %s', mat2str(SelectedSets), TemplateSet);    
    if ~strcmpi(Classes, 'all')
        com = [com sprintf(', ''Classes'', %s', mat2str(Classes))];
    end
    if ~strcmpi(TemplateClasses, 'all')
        com = [com sprintf(', ''TemplateClasses'', %s', mat2str(TemplateClasses))];
    end
    com = [com sprintf(', ''IgnorePolarity'', %i', IgnorePolarity)];
    if Stepwise
        com = [com ', ''Stepwise'', 1);'];
    else
        com = [com ');'];
    end
end

function displayedSetsChanged(obj, ~)
    setBox = findobj(obj.Parent, 'Tag', 'SelectedSets');
    if isempty(setBox); return; end
    ud = setBox.UserData;
    if obj.Value == 1
        setBox.String = ud.AvailableSetnames;
        defaultSets = find(ismember(ud.AvailableSets, ud.CurrentSet));        
    elseif obj.Value == 2
        setBox.String = ud.AvailableIndSetnames;
        defaultSets = find(ismember(ud.AvailableIndSets, ud.CurrentSet));
    else
        setBox.String = ud.AvailableMeanSetnames;
        defaultSets = find(ismember(ud.AvailableMeanSets, ud.CurrentSet));
    end
    
    if isempty(defaultSets);    defaultSets = 1;    end
    ud.defaultSets = defaultSets;
    templateSet = findobj(obj.Parent, 'Tag', 'TemplateIndex');
    if ~isempty(templateSet)
        if templateSet.Value == 1;  defaultSets = defaultSets(1);   end
    end
    setBox.Value = defaultSets;
    setBox.UserData = ud;
end

function templateChanged(obj, ~)
    setBox = findobj(obj.Parent, 'Tag', 'SelectedSets');    
    if ~isempty(setBox)
        ud = setBox.UserData;
        if obj.Value == 1
            setBox.Max = 1;
            setBox.Value = ud.defaultSets(1);
        else
            setBox.Max = 2;
            setBox.Value = ud.defaultSets;
        end
    end

    ignorePolarity = findobj(obj.Parent, 'Tag', 'IgnorePolarity');
    if ~isempty(ignorePolarity)
        if obj.Value == 1
            ignorePolarity.Enable = 'off';
        else
            ignorePolarity.Enable = 'on';
        end
    end
end

function stepwiseChanged(obj, ~)
    classBox = findobj(obj.Parent, 'Tag', 'Classes');
    if isempty(classBox);   return; end
    if obj.Value == 1
        classBox.UserData.prevSelection = classBox.Value;
        classBox.Value = 1:numel(classBox.String);
        classBox.Enable = 'inactive';
    else
        classBox.Value = classBox.UserData.prevSelection;
        classBox.Enable = 'on';
    end
end

function hasDyn = isDynamicsSet(in)
    hasDyn = false;
    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end    
    % check if set has FitPar
    if ~isfield(in.msinfo, 'FitPar')
        return;
    end
    % check if FitPar contains Rectify/Normalize parameters
    if ~isfield(in.msinfo.FitPar, 'Rectify')
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

function isPublished = isPublishedSet(in, templateNames)
    isPublished = false;
    if isempty(in.setname)
        return;
    end

    if matches(in.setname, templateNames)
        isPublished = true;
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
        setnames = {AllEEG.setname};
        isEmpty = cellfun(@isempty,setnames);
        if any(isEmpty)
            setnames(isEmpty) = {''};
        end
        childSetIndices = unique(cell2mat(arrayfun(@(x) find(matches(setnames, AllEEG(x).msinfo.children)), SetsToSearch(HasChildren), 'UniformOutput', false)));
        containsChild = checkSetForChild(AllEEG, childSetIndices, childSetName);
    end

end