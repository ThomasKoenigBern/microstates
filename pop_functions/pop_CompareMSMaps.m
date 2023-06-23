% pop_CompareMSMaps() - Interactively compare microstate topographies
% within or across datasets. Allows for comparison of microstate
% topographies across cluster solutions within one dataset, or comparison
% of one cluster solution across multiple datasets. Generates an
% interactive GUI for exploring how similar different microstate
% topographies are and viewing shared variances between topographies.
%
% Usage:
%   >> sharedVarTable = pop_CompareMSMaps(ALLEEG,
%       IndividualSets, MeanSets, PublishedSets,  'key1', value1, 'key2', 
%       value2, ...)
%
% To compare microstate topographies across cluster solutions within one
% dataset, pass in the index or name of one dataset within ALLEEG.
% Ex:
%   >> sharedVarTable = pop_CompareMSMaps(ALLEEG, 1, [], [])
%
% To compare microstate topographies of one cluster solution across
% multiple datasets, pass in the indices or names of datasets to compare,
% along with the number of classes to compare across sets.
% Ex:
%   >> sharedVarTable = pop_CompareMSMaps(ALLEEG, 1:5, 6, 'Koenig2002', 
%       'Classes', 4)
%
% To generate the shared variance matrix for all microstate topographies of
% the chosen sets to compare without displaying the GUI, use the "Filename"
% and "gui" parameters.
% Ex:
%   >> sharedVarTable = pop_CompareMSMaps(ALLEEG, 1, [], [],
%       'Filename', 'MICROSTATELAB/results/sharedvars.csv', 'gui', 0)
%
% Graphical interface:
%
%   "Individual sets"
%   -> Select individual sets for comparing microstate topographies. If
%   comparing within a dataset, only one dataset can be chosen between both
%   individual and mean sets.
%   -> Command line equivalent: "IndividualSets"
%
%   "Mean sets"
%   -> Select mean sets for comparing microstate topographies. If comparing
%   within a dataset, only one dataset can be chosen between both
%   individual and mean sets.
%   -> Command line equivalent: "MeanSets"
%
%   "Published sets"
%   -> Select published sets for comparing microstate topographies. Only
%   appears if comparing across datasets.
%   -> Command line equivalent: "PublishedSets"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "IndividualSets" (optional)
%   -> Vector of individual set indices of ALLEEG to compare. Use this
%   argument to specify any sets contained in ALLEEG that do not have child
%   sets (e.g. not averaged across other sets). If comparing within a
%   dataset, only one dataset can be chosen between both individual and
%   mean sets.
%
%   "MeanSets" (optional)
%   -> Vector of mean set indices or mean set names in ALLEEG to compare. If
%   specifying mean sets by name, use a string array or cell array of
%   character vectors. Use this argument to specify any sets contained in 
%   ALLEEG that have child sets (e.g. averaged across other sets). If 
%   comparing within a dataset, only one dataset can be chosen between both 
%   individual and mean sets.
%
%   "PublishedSets" (optional)
%   -> String array or cell array of character vectors of published set
%   names to compare. All setnames included in this argument should be the
%   names of templates contained in the microstates/Templates folder.
%   
% Key, Value inputs (optional):
%
%   "Classes"
%   -> Integer indicating which cluster solution to compare across
%   datasets. Only used if multiple datasets are passed in using the
%   "IndividualSets", "MeanSets", and "PublishedSets" arguments. If
%   multiple datasets are provided and "Classes" is not provided, a GUI
%   will appear to select the cluster solution to compare.
%
%   "Filename"
%   -> Full csv, xlsx, txt, or mat filename to save the shared variance
%   matrix between all microstate topographies from the selected set(s)
%   chosen. If provided, the function will automatically save the full 
%   shared variance matrix rather than providing the option to save in the 
%   interactive GUI. Useful for scripting purposes.
%
%   "gui"
%   -> 1 = show interactive GUI, 0 = do not show interactive GUI. Useful
%   for scripting purposes, e.g. if the function is being used to generate
%   and save a shared variance matrix and the GUI is not necessary.
%   -> Default = 1
%
% Outputs:
%
%   "sharedVarTable"
%   -> Table of shared variances between each pair of microstate maps
%   selected for comparison.
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
function [sharedVarTable, com] = pop_CompareMSMaps(AllEEG, varargin)
    
    sharedVarTable = [];
    com = '';
    global EEG;
    global CURRENTSET;
    global MSTEMPLATE;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    guiElements = {};

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_CompareMSMaps';
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'IndividualSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', '<=', numel(AllEEG)}));
    addOptional(p, 'MeanSets', [], @(x) validateattributes(x, {'char', 'string', 'cell', 'numeric'}, {}));
    addOptional(p, 'PublishedSets', [], @(x) validateattributes(x, {'char', 'string', 'cell', 'numeric'}, {}));
    addParameter(p, 'Classes', []);
    addParameter(p, 'Filename', '', @(x) validateattributes(x, {'char', 'string'}, {'scalartext'}));
    addParameter(p, 'gui', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));

    parse(p, AllEEG, varargin{:});

    IndividualSets = p.Results.IndividualSets;
    MeanSets = p.Results.MeanSets;
    PublishedSets = p.Results.PublishedSets;
    nClasses = p.Results.Classes;
    Filename = p.Results.Filename;
    showGUI = p.Results.gui;

    if ~isempty(IndividualSets)
        validateattributes(IndividualSets, {'numeric'}, {'vector'});
    end

    if ~isempty(MeanSets)
        if isnumeric(MeanSets)
            validateattributes(MeanSets, {'numeric'}, {'integer', 'vector', 'positive', '<=', numel(AllEEG)}, 'pop_CompareMSMaps', 'MeanSets');
        else
            MeanSets = convertStringsToChars(MeanSets);
            if isa(MeanSets, 'char')
                MeanSets = {MeanSets};
            end
            invalidSets = ~cellfun(@(x) ischar(x) || isstring(x), MeanSets);
            if any(invalidSets)
                invalidSetsTxt = sprintf('%i, ', find(invalidSets));
                invalidSetsTxt = invalidSetsTxt(1:end-2);
                error(['The following elements of MeanSets are invalid: ' invalidSetsTxt ...
                    '. Expected all elements to be strings or chars.']);
            end
        end
    end

    if ~isempty(PublishedSets)
        validateattributes(PublishedSets, {'char', 'string', 'cell'}, {'vector'});
        PublishedSets = convertStringsToChars(PublishedSets);
        if isa(PublishedSets, 'char')
            PublishedSets = {PublishedSets};
        end
        invalidSets = ~cellfun(@(x) ischar(x) || isstring(x), PublishedSets);
        if any(invalidSets)
            invalidSetsTxt = sprintf('%i, ', find(inValidSets));
            invalidSetsTxt(end) = [];
            error(['The following elements of PublishedSets are invalid: ' invalidSetsTxt ...
                '. Expected all elements to be strings or chars.']);
        end
    end

    %% Selected sets validation

    % Make sure there are sets available to compare
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isPublished = arrayfun(@(x) isPublishedSet(AllEEG(x), {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableIndSets = find(HasMS & ~HasChildren & ~HasDyn & ~isPublished);
    AvailableMeanSets = find(HasMS & HasChildren & ~HasDyn & ~isPublished);    
    AvailablePublishedSets = 1:numel(MSTEMPLATE);
    AvailableSets = [AvailableIndSets, AvailableMeanSets, AvailablePublishedSets];

    if isempty(AvailableSets)
        errorMessage = ['No valid sets found for comparing maps. Use ' ...
            '"Tools->Identify microstate maps per dataset" to find and store microstate map data.'];
        if all(matches({'IndividualSets','MeanSets','PublishedSets'}, p.UsingDefaults))
            errorDialog(errorMessage, 'Compare microstate maps error');
            return;
        else
            error(errorMessage);
        end
    end

    % Validate individual sets
    if ~isempty(IndividualSets)
        IndividualSets = unique(IndividualSets, 'stable');
        isValid = ismember(IndividualSets, AvailableIndSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', IndividualSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following individual sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, dynamics sets, ' ...
                'or sets without microstate maps.']);
        end
    end

    % Validate mean sets
    MeanSetnames = {AllEEG(AvailableMeanSets).setname};
    if ~isempty(MeanSets)
        MeanSets = unique(MeanSets, 'stable');
        if isnumeric(MeanSets)
            isValid = ismember(MeanSets, AvailableMeanSets);
            if any(~isValid)
                invalidSetsTxt = sprintf('%i, ', MeanSets(~isValid));
                invalidSetsTxt = invalidSetsTxt(1:end-2);
                error(['The following mean sets are invalid: ' invalidSetsTxt ...
                    '. Make sure you have not selected individual datasets, dynamics sets, ' ...
                    'or sets without microstate maps.']);
            end
        else
            isValid = ismember(MeanSets, MeanSetnames);
            if any(~isValid)
                invalidSetsTxt = sprintf('%s, ', string(MeanSets(~isValid)));
                invalidSetsTxt = invalidSetsTxt(1:end-2);
                error(['The following mean sets could not be found: ' invalidSetsTxt]);
            else
                % if MeanSets is a string array/cell array of char vectors,
                % convert to integers
                MeanSets = AvailableMeanSets(ismember(MeanSetnames, MeanSets));
            end
        end
    end

    % Validate PublishedSets
    [publishedSetnames, publishedDisplayNames, sortOrder] = getTemplateNames();
    if ~isempty(PublishedSets)
        PublishedSets = unique(PublishedSets, 'stable');
        isValid = ismember(PublishedSets, publishedSetnames);
        if any(~isValid)
            invalidSetsTxt = sprintf('%s, ', string(PublishedSets(~isValid)));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following published template sets could not be found in the Templates folder: ' invalidSetsTxt '.']);
        else
            % get template set integers
            PublishedSetIndices = sortOrder(ismember(publishedSetnames, PublishedSets));
        end
    else
        PublishedSetIndices = [];
    end

    %% User input
    SelectedSets = [IndividualSets(:); MeanSets(:)];
    if isempty(SelectedSets) && isempty(PublishedSetIndices)
        question = 'Which kind of comparison would you like to make?';
        options = {'Compare solutions within dataset', 'Compare maps across datasets'};
        title = 'Compare microstate maps';
        selection = questionDialog(question, title, options);
        if isempty(selection) || strcmp(selection, 'Cancel')
            return;
        else
            compWithin = strcmp(selection, 'Compare solutions within dataset');
        end        
        
        if compWithin
            setOptions = {'Individual datasets and mean sets', 'Individual datasets', 'Mean sets'};

            ud.IndSets = AvailableIndSets;
            ud.MeanSets = AvailableMeanSets;
            ud.AllSets = [AvailableIndSets AvailableMeanSets];
            ud.IndSetnames = {AllEEG(AvailableIndSets).setname};
            ud.MeanSetnames = {AllEEG(AvailableMeanSets).setname};
            ud.AllSetnames = [ud.IndSetnames ud.MeanSetnames];
            ud.CurrentSet = CurrentSet;
            ud.prevValue = 1;

            defaultSet = find(ismember(ud.AllSets, CurrentSet), 1);

            [res,~,~,outstruct] = inputgui('geometry', {1 [4 6] 1 1} , 'geomvert', [1 1 1 4], 'uilist', {...
                { 'Style', 'text', 'string', 'Pick an individual dataset or mean set for comparing cluster solutions.', 'Fontweight', 'bold'} ...
                { 'Style', 'text', 'string', 'Display options'} ...
                { 'Style', 'popupmenu', 'String', setOptions, 'Callback', @displayedSetsChanged, 'Tag', 'DisplayedSets'} ...
                { 'Style', 'text', 'String', ''} ...
                { 'Style', 'listbox', 'String', ud.AllSetnames, 'Value', defaultSet, 'Tag', 'SelectedSets', 'UserData', ud}}, ...
                'title', 'Compare microstate maps');

            if isempty(res); return; end            

            if outstruct.DisplayedSets == 1
                SelectedSets = AvailableSets(outstruct.SelectedSets);
            elseif outstruct.DisplayedSets == 2
                SelectedSets = AvailableIndSets(outstruct.SelectedSets);
            else
                SelectedSets = AvailableMeanSets(outstruct.SelectedSets);
            end
            
            if numel(SelectedSets) < 1
                errordlg2('You must select one set of microstate maps.', 'Compare microstate maps error');
                return;
            end

        else
            defaultIndSets = find(ismember(AvailableIndSets, CurrentSet)) + 1;
            defaultMeanSets = find(ismember(AvailableMeanSets, CurrentSet)) + 1;
            [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1 1 1 1 1], 'geomvert', [1 1 1 4 1 4 1 4], 'uilist', { ...
                { 'Style', 'text', 'String', 'Pick any number of sets for comparing maps.', 'Fontweight', 'bold'} ...
                { 'Style', 'text', 'String', 'Sets can be chosen from any category.'} ...
                { 'Style', 'text', 'string', 'Individual datasets'} ...
                { 'Style', 'listbox', 'String', ['None' {AllEEG(AvailableIndSets).setname}], 'Value', defaultIndSets, ...
                    'Min', 0, 'Max' 2, 'Tag', 'IndividualSets' } ...
                { 'Style', 'text', 'String', 'Mean sets'} ...
                { 'Style', 'listbox', 'String', ['None' {AllEEG(AvailableMeanSets).setname}], 'Value', defaultMeanSets, ...
                    'Min', 0, 'Max', 2, 'Tag', 'MeanSets'} ...
                { 'Style', 'text', 'String', 'Published sets'} ...
                { 'Style', 'listbox', 'String', ['None' publishedDisplayNames], 'Min', 0, 'Max', 2, 'Tag', 'PublishedSets'}}, ...
                'title', 'Compare microstate maps');
            
            if isempty(res); return; end      
            
            indSelected = ~all(outstruct.IndividualSets == 1);
            meanSelected = ~all(outstruct.MeanSets == 1);
            pubSelected = ~all(outstruct.PublishedSets == 1);
            if ~indSelected && ~meanSelected && ~pubSelected
                errordlg2('You must select at least one set of microstate maps.', 'Compare microstate maps error');
                return;
            end
            if indSelected
                SelectedSets = AvailableIndSets(outstruct.IndividualSets(outstruct.IndividualSets ~= 1) - 1);
            end
            if meanSelected
                SelectedSets = [SelectedSets AvailableMeanSets(outstruct.MeanSets(outstruct.MeanSets ~= 1) - 1)];                
            end
            if pubSelected
                PublishedSetIndices = sortOrder(outstruct.PublishedSets(outstruct.PublishedSets ~= 1) - 1);
            end
        end        
    elseif (numel(SelectedSets) + numel(PublishedSetIndices)) == 1
        compWithin = 1;
    else
        compWithin = 0;
    end

    SelectedEEG = [];
    if ~isempty(SelectedSets)
        SelectedEEG = eeg_store(SelectedEEG, AllEEG(SelectedSets), 1:numel(SelectedSets));
    end
    nonpublishedSets = 1:numel(SelectedEEG);
    if ~isempty(PublishedSetIndices)
        publishedSets = MSTEMPLATE(PublishedSetIndices);
        SelectedEEG = eeg_store(SelectedEEG, publishedSets, (numel(SelectedEEG)+1):(numel(SelectedEEG)+numel(publishedSets)));
    end

    %% If comparing within a dataset, check for consistent labels across solutions
    if compWithin
        showDlg = all(matches({'IndividualSets', 'MeanSets'}, p.UsingDefaults));
        MinClasses = SelectedEEG.msinfo.ClustPar.MinClasses;
        MaxClasses = SelectedEEG.msinfo.ClustPar.MaxClasses;
        classes = MinClasses:MaxClasses;

        % First check if any solutions remain unsorted
        SortModes = {SelectedEEG.msinfo.MSMaps(classes).SortMode};
        if any(strcmp(SortModes, 'none'))           
            classesTxt = sprintf('%i, ', classes(strcmp(SortModes, 'none')));
            classesTxt = classesTxt(1:end-2);
            errorMessage = ['The following cluster solutions remain unsorted: ' classesTxt '. Please sort all ' ...
                'cluster solutions before proceeding.'];
            if showDlg
                errorDialog(errorMessage, 'Compare microstate maps error');
                return;
            else
                error(errorMessage);
            end
        end

        % Check for unassigned labels
        Colors = {SelectedEEG.msinfo.MSMaps(classes).ColorMap};
        unlabeled = cellfun(@(x) any(arrayfun(@(y) all(x(y,:) == [.75 .75 .75]), 1:size(x,1))), Colors);
        if any(unlabeled)
            classesTxt = sprintf('%i, ', classes(unlabeled));
            classesTxt = classesTxt(1:end-2);
            errorMessage = ['The following cluster solutions contains maps without assigned labels: ' classesTxt ...
                '. For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'];
            if showDlg
                errorDialog(errorMessage, 'Compare microstate maps error');
                return;
            else
                error(errorMessage);
            end
        end

    %% If comparing across datasets, ask user for number of classes and check for consistent labels
    else
        showDlg = all(matches({'IndividualSets', 'MeanSets', 'PublishedSets'}, p.UsingDefaults));
        setnames = {SelectedEEG(nonpublishedSets).setname};
        isEmpty = cellfun(@isempty,setnames);
        if any(isEmpty)
            setnames(isEmpty) = {''};
        end

        % Check for overlap in cluster solutions
        AllMinClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MinClasses, 1:numel(SelectedEEG));
        AllMaxClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MaxClasses, 1:numel(SelectedEEG));
        MinClasses = max(AllMinClasses);
        MaxClasses = min(AllMaxClasses);
        if MaxClasses < MinClasses
            errorMessage = 'No overlap in cluster solutions found between all selected sets.';
            if showDlg
                errordlg2(errorMessage, 'Compare microstate maps error');
                return;
            else
                error(errorMessage);
            end
        end

        if matches('Classes', p.UsingDefaults)
            classes = MinClasses:MaxClasses;
            classChoices = sprintf('%i Classes|', classes);
            classChoices(end) = [];
    
            [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
                { {'Style', 'text', 'string', 'Select cluster solution to compare'} ...
                  {'Style', 'listbox', 'string', classChoices, 'Tag', 'nClasses'}}, ...
                  'title', 'Compare microstate maps');
            
            if isempty(res); return; end
    
            nClasses = classes(outstruct.nClasses);
        else
            if nClasses > MaxClasses || nClasses < MinClasses
                error(['Not all selected sets to compare contain a %i cluster solution. ' ...
                    'Valid class numbers are in the range %i-%i.'], nClasses, MinClasses, MaxClasses);
            end
        end

        % Check if any datasets remain unsorted
        SortModes = arrayfun(@(x) {SelectedEEG(x).msinfo.MSMaps(nClasses).SortMode}', nonpublishedSets);
        if matches('none', SortModes)          
            unsortedSets = setnames(strcmp(SortModes, 'none'));
            if showDlg                
                errorDialog(sprintf('The %i cluster solutions of the following sets remain unsorted. Please sort all sets before proceeding.', nClasses), ...
                    'Compare microstate maps error', unsortedSets);
                return;
            else
                unsortedSetsTxt = sprintf(['%s' newline], string(unsortedSets));
                error(['The %i cluster solutions of the following sets remain unsorted: ' newline unsortedSetsTxt ...
                    'Please sort all sets before proceeding.'], nClasses);
            end
        end

        % Check for unassigned labels
        Colors = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).ColorMap, nonpublishedSets, 'UniformOutput', false);
        unlabeled = cellfun(@(x) any(arrayfun(@(y) all(x(y,:) == [.75 .75 .75]), 1:size(x,1))), Colors);
        if any(unlabeled)
            unsortedSets = setnames(unlabeled);
            if showDlg
                errorDialog(sprintf(['The %i cluster solutions of the following sets contain maps without assigned labels. ' ...
                    'For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                    'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], nClasses), ...
                    'Compare microstate maps error', unsortedSets);
                return;
            else
                unsortedSetsTxt = sprintf(['%s' newline], string(unsortedSets));
                error(['The %i cluster solutions of the following sets contain maps without assigned labels: ' newline unsortedSetsTxt ...
                    'For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                    'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], nClasses);
            end
        end
    end

    %% Check for different channel numbers and create common set of channels
    if numel(SelectedEEG) > 1
        nChannels = arrayfun(@(x) numel(SelectedEEG(x).chanlocs), 1:numel(SelectedEEG));
        [~, minSetIdx] = min(nChannels);

        for i=1:numel(SelectedEEG)
            if i == minSetIdx
                continue
            end
            
            [LocalToGlobal, ~] = MakeResampleMatrices(SelectedEEG(i).chanlocs, SelectedEEG(minSetIdx).chanlocs);
            
            for class=SelectedEEG(i).msinfo.ClustPar.MinClasses:SelectedEEG(i).msinfo.ClustPar.MaxClasses
                SelectedEEG(i).msinfo.MSMaps(class).Maps = SelectedEEG(i).msinfo.MSMaps(class).Maps*LocalToGlobal';
                SelectedEEG(i).chanlocs = SelectedEEG(minSetIdx).chanlocs;
            end
        end
    end

    %% Display GUI and export shared variances
    if compWithin
        nClasses = 0;
    end

    MapCollection    = [];
    CLabelCollection = [];    
    if compWithin
        for i = MinClasses:MaxClasses
            MapCollection = [MapCollection; SelectedEEG.msinfo.MSMaps(i).Maps];
            for j = 1:i  
                CLabelCollection  = [CLabelCollection,sprintf("%s (%i)",SelectedEEG.msinfo.MSMaps(i).Labels{j},i)];
            end
        end
    else
        for i=1:numel(SelectedEEG)
            MapCollection = [MapCollection; SelectedEEG(i).msinfo.MSMaps(nClasses).Maps];
            for j=1:nClasses
                CLabelCollection = [CLabelCollection, sprintf("%s (%s)", SelectedEEG(i).msinfo.MSMaps(nClasses).Labels{j}, SelectedEEG(i).setname)];
            end
        end
    end    
    CorrMat = MyCorr(double(MapCollection)').^2;
    sharedVarTable = array2table(CorrMat * 100,'VariableNames',CLabelCollection,'RowNames',CLabelCollection);

    if ~isempty(Filename)        
        if ~contains(Filename, '.mat')
            writetable(sharedVarTable, Filename, 'WriteRowNames', true);
        else
            save(Filename, 'sharedVarTable');
        end
    end

    if showGUI
        Filenames = CompareMicrostateSolutions(SelectedEEG, nClasses, Filename);
    end

    if ~compWithin
        if isempty(PublishedSets)
            PublishedSetsTxt = '[]';
        else
            PublishedSetsTxt = sprintf('''%s'', ', string(PublishedSets));
            PublishedSetsTxt = ['{' PublishedSetsTxt(1:end-2) '}'];
        end
        if isempty(Filenames)
            com = sprintf('sharedVarTable = pop_CompareMSMaps(ALLEEG, %s, %s, %s, ''Classes'', %i, ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), PublishedSetsTxt, nClasses, showGUI);
        else
            com = sprintf('sharedVarTable = pop_CompareMSMaps(ALLEEG, %s, %s, %s, ''Classes'', %i, ''Filename'', ''%s'', ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), PublishedSetsTxt, nClasses, Filenames{1}, showGUI);
            for i=2:numel(Filenames)
                com = [com newline ...
                    sprintf('sharedVarTable = pop_CompareMSMaps(ALLEEG, %s, %s, %s, ''Classes'', %i, ''Filename'', ''%s'', ''gui'', %i);', ...
                    mat2str(IndividualSets), mat2str(MeanSets), PublishedSetsTxt, nClasses, Filenames{i}, showGUI)];
            end
        end        
    else
        if isempty(Filenames)
            com = sprintf('sharedVarTable = pop_CompareMSMaps(ALLEEG, %s, %s, ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), showGUI);
        else
            com = sprintf('sharedVarTable = pop_CompareMSMaps(ALLEEG, %s, %s, ''Filename'', ''%s'', ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), Filenames{1}, showGUI);
            for i=2:numel(Filenames)
                com = [com newline ...
                    sprintf('sharedVarTable = pop_CompareMSMaps(ALLEEG, %s, %s, ''Filename'', ''%s'', ''gui'', %i);', ...
                    mat2str(IndividualSets), mat2str(MeanSets), Filenames{1}, showGUI)];
            end
        end        
    end
end

function displayedSetsChanged(obj, ~)
    setBox = findobj(obj.Parent, 'Tag', 'SelectedSets');
    if isempty(setBox); return; end
    ud = setBox.UserData;  

    if ud.prevValue == 1
        prevSelection = ud.AllSets(setBox.Value);
    elseif ud.prevValue == 2
        if ~isempty(ud.IndSets)
            prevSelection = ud.IndSets(setBox.Value);
        else
            prevSelection = [];
        end
    elseif ud.prevValue == 3
        if ~isempty(ud.MeanSets)
            prevSelection = ud.MeanSets(setBox.Value);
        else
            prevSelection = [];
        end
    end
    ud.prevValue = obj.Value;

    if obj.Value == 1
        setBox.String = [ud.IndSetnames ud.MeanSetnames];
        prevSet = find(ismember(ud.AllSets, prevSelection));
        defaultSet = find(ismember(ud.AllSets, ud.CurrentSet), 1);
    elseif obj.Value == 2
        setBox.String = ud.IndSetnames;
        prevSet = find(ismember(ud.IndSets, prevSelection));
        defaultSet = find(ismember(ud.IndSets, ud.CurrentSet), 1);
    elseif obj.Value == 3
        setBox.String = ud.MeanSetnames;
        prevSet = find(ismember(ud.MeanSets, prevSelection));
        defaultSet = find(ismember(ud.MeanSets, ud.CurrentSet), 1);
    end

    if isempty(prevSet)
        if isempty(defaultSet);    defaultSet = 1;    end
        setBox.Value = defaultSet;
    else
        setBox.Value = prevSet;
    end

    setBox.UserData = ud;
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