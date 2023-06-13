% pop_CompareMSMaps() - Interactively compare microstate topographies
% within or across datasets. Allows for comparison of microstate
% topographies across cluster solutions within one dataset, or comparison
% of one cluster solution across multiple datasets. Generates an
% interactive GUI for exploring how similar different microstate
% topographies are and viewing shared variances between topographies.
%
% Usage:
%   >> [EEG, CURRENTSET, com] = pop_CompareMSMaps(ALLEEG,
%       IndividualSets, MeanSets, PublishedSets,  'key1', value1, 'key2', 
%       value2, ...)
%
% To compare microstate topographies across cluster solutions within one
% dataset, pass in the index or name of one dataset within ALLEEG.
% Ex:
%   >> [EEG, CURRENTSET] = pop_CompareMSMaps(ALLEEG, 1, [], [])
%
% To compare microstate topographies of one cluster solution across
% multiple datasets, pass in the indices or names of datasets to compare,
% along with the number of classes to compare across sets.
% Ex:
%   >> [EEG, CURRENTSET] = pop_CompareMSMaps(ALLEEG, 1:5, 6,
%       'Koenig2002', 'Classes', 4)
%
% To generate the shared variance matrix for all microstate topographies of
% the chosen sets to compare without displaying the GUI, use the "Filename"
% and "gui" parameters.
% Ex:
%   >> [EEG, CURRENTSET] = pop_CompareMSMaps(ALLEEG, 1, [], [],
%       'Filename', 'microstates/results/sharedvars.csv', 'gui', 0)
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
%   -> Array of individual set indices of ALLEEG to compare. Use this
%   argument to specify any sets contained in ALLEEG that do not have child
%   sets (e.g. not averaged across other sets). If comparing within a
%   dataset, only one dataset can be chosen between both individual and
%   mean sets.
%
%   "MeanSets" (optional)
%   -> Array of mean set indices or mean set names in ALLEEG to compare. If
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
%   "EEG" 
%   -> EEG structure array of selected sets chosen for comparison
% 
%   "CURRENTSET"
%   -> The indices of the EEGs chosen for comparison
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
function [EEGout, CurrentSet, com] = pop_CompareMSMaps(AllEEG, varargin)
    
    com = '';
    global EEG;
    global CURRENTSET;
    global MSTEMPLATE;
    global guiOpts;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_CompareMSMaps';
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addParameter(p, 'IndividualSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', '<=', numel(AllEEG)}));
    addParameter(p, 'MeanSets', [], @(x) validateattributes(x, {'char', 'string', 'cell', 'numeric'}, {}));
    addParameter(p, 'PublishedSets', [], @(x) validateattributes(x, {'char', 'string', 'cell', 'numeric'}, {}));
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
            validateattributes(MeanSets, {'numeric'}, {'integer', 'vector', 'positive', '<=', numel(AllEEG)}, funcName, 'MeanSets');
        else
            MeanSets = convertStringsToChars(MeanSets);
            if isa(MeanSets, 'char')
                MeanSets = {MeanSets};
            end
            invalidSets = ~cellfun(@(x) ischar(x) || isstring(x), MeanSets);
            if any(invalidSets)
                invalidSetsTxt = sprintf('%i, ', find(inValidSets));
                invalidSetsTxt(end) = [];
                errorMessage = ['The following elements of MeanSets are invalid: ' invalidSetsTxt ...
                    '. Expected all elements to be strings or chars.'];
                errordlg2(errorMessage, 'Compare microstate maps error');
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
            errorMessage = ['The following elements of PublishedSets are invalid: ' invalidSetsTxt ...
                '. Expected all elements to be strings or chars.'];
            errordlg2(errorMessage, 'Compare microstate maps error');
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
        errordlg2('No valid sets for comparing found.', 'Compare microstate maps error');
        return;
    end

    % Validate individual sets
    if ~isempty(IndividualSets)
        IndividualSets = unique(IndividualSets, 'stable');
        isValid = ismember(IndividualSets, AvailableIndSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', IndividualSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following individual sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, dynamics sets, ' ...
                'or sets without microstate maps.'];
            errordlg2(errorMessage, 'Compare microstate maps error');
            return;
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
                errorMessage = ['The following mean sets are invalid: ' invalidSetsTxt ...
                    '. Make sure you have not selected an individual set or a dynamics set.'];
                errordlg2(errorMessage, 'Compare microstate maps error');
                return;
            end
        else
            isValid = ismember(MeanSets, MeanSetnames);
            if any(~isValid)
                invalidSetsTxt = sprintf('%s, ', MeanSets(~isValid));
                invalidSetsTxt = invalidSetsTxt(1:end-2);
                errorMessage = ['The following mean sets are invalid: ' invalidSetsTxt ...
                    '. Make sure you have not selected an individual set or a dynamics set.'];
                errordlg2(errorMessage, 'Compare microstate maps error');
                return;
            else
                % if MeanSets is a string array/cell array of char vectors,
                % convert to integers
                MeanSets = AvailableMeanSets(ismember(AvailableMeanSets, MeanSets));
            end
        end
    end

    % Validate PublishedSets
    [publishedSetnames, publishedDisplayNames, sortOrder] = getTemplateNames();
    if ~isempty(PublishedSets)
        PublishedSets = unique(PublishedSets, 'stable');
        isValid = ismember(PublishedSets, publishedSetnames);
        if any(~isValid)
            invalidSetsTxt = sprintf('%s, ', PublishedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following published template sets could not be found: ' ...
                invalidSetsTxt '.'];
            errordlg2(errorMessage, 'Compare microstate maps error');
            return;
        else
            % get template set integers
            PublishedSetIndices = sortOrder(ismember(publishedSetnames, PublishedSets));
        end
    else
        PublishedSetIndices = [];
    end

    %% User input
    SelectedSets = [IndividualSets(:); MeanSets(:); PublishedSetIndices(:)];
    if isempty(SelectedSets)
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
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', 'Pick an individual or mean set for comparing solutions.'}} ...
                {{ 'Style', 'text', 'string', 'Only one set can be chosen.'}}];
            guiGeom = [guiGeom 1 1];
            guiGeomV = [guiGeomV 1 1];
            defaultIndSets = 1;
            defaultMeanSets = 1;
            maxSelect = 1;
        else
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', 'Pick any number of sets for comparing maps.'}} ...
                {{ 'Style', 'text', 'string', 'Sets can be chosen from any category.'}}];
            guiGeom = [guiGeom 1 1];
            guiGeomV = [guiGeomV 1 1];
            maxSelect = 2;
            defaultIndSets = 1 + find(ismember(AvailableIndSets, CurrentSet));
            defaultMeanSets = 1 + find(ismember(AvailableMeanSets, CurrentSet));
        end
        
        % Individual set selection
        AvailableIndSetnames = ['None' {AllEEG(AvailableIndSets).setname}];
        guiElements = [guiElements, ...
            {{ 'Style', 'text', 'string', 'Individual sets'}} ...
            {{ 'Style', 'listbox', 'string', AvailableIndSetnames, 'Value', defaultIndSets, 'Min', 0, 'Max', maxSelect, 'tag', 'IndividualSets'}}];
        guiGeom = [guiGeom 1 1];
        guiGeomV = [guiGeomV 1 4];

        % Mean set selection
        AvailableMeanSetnames = ['None' MeanSetnames];
        guiElements = [guiElements, ...
            {{ 'Style', 'text', 'string', 'Mean sets'}} ...
            {{ 'Style', 'listbox', 'string', AvailableMeanSetnames, 'Value', defaultMeanSets, 'Min', 0, 'Max', maxSelect, 'tag', 'MeanSets'}}];
        guiGeom = [guiGeom 1 1];
        guiGeomV = [guiGeomV 1 4];

        % Published set selection
        if ~compWithin
            AvailablePublishedSetnames = ['None', publishedDisplayNames];
            guiElements = [guiElements, ...
                {{ 'Style', 'text', 'string', 'Published sets'}} ...
                {{ 'Style', 'listbox', 'string', AvailablePublishedSetnames, 'Min', 0, 'Max', maxSelect, 'tag', 'PublishedSets'}}];
            guiGeom = [guiGeom 1 1];
            guiGeomV = [guiGeomV 1 4];
        end

        [res,~,~,outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements,...
             'title','Compare microstate maps');

        if isempty(res); return; end

        if compWithin
            if outstruct.IndividualSets == 1 && outstruct.MeanSets == 1
                errordlg2('You must select one set of microstate maps.', 'Compare microstate maps error');
                return;
            elseif outstruct.IndividualSets > 1 && outstruct.MeanSets > 1
                errordlg2('You may only select one set of microstate maps.', 'Compare microstate maps error');
                return;
            elseif outstruct.IndividualSets > 1
                IndividualSets = AvailableIndSets(outstruct.IndividualSets-1);
            else
                MeanSets = AvailableMeanSets(outstruct.MeanSets-1);
            end
        else
            indSelected = ~(numel(outstruct.IndividualSets) == 1 && ismember(1, outstruct.IndividualSets));
            meanSelected = ~(numel(outstruct.MeanSets) == 1 && ismember(1, outstruct.MeanSets));
            publishedSelected = ~(numel(outstruct.PublishedSets) == 1 && ismember(1, outstruct.PublishedSets));
            if ~indSelected && ~meanSelected && ~publishedSelected
                errordlg2('You must select at least one set of microstate maps.', 'Compare microstate maps error');
                return;
            end
            if indSelected
                IndividualSets = AvailableIndSets(outstruct.IndividualSets(outstruct.IndividualSets ~= 1) - 1);
            end
            if meanSelected
                MeanSets = AvailableMeanSets(outstruct.MeanSets(outstruct.MeanSets ~= 1) - 1);
            end
            if publishedSelected
                PublishedSetIndices = sortOrder(outstruct.PublishedSets(outstruct.PublishedSets ~= 1) - 1);
            end
        end
    elseif numel(SelectedSets) == 1
        compWithin = 1;
    else
        compWithin = 0;
    end

    SelectedEEG = [];
    if ~isempty(IndividualSets)
        SelectedEEG = pop_newset(SelectedEEG, AllEEG(IndividualSets), numel(SelectedEEG), 'gui', 'off');
    end
    if ~isempty(MeanSets)
        SelectedEEG = pop_newset(SelectedEEG, AllEEG(MeanSets), numel(SelectedEEG), 'gui', 'off');
    end
    nonpublishedSets = 1:numel(SelectedEEG);
    if ~isempty(PublishedSetIndices)
        publishedSets = MSTEMPLATE(PublishedSetIndices);
        SelectedEEG = pop_newset(SelectedEEG, publishedSets, numel(SelectedEEG), 'gui', 'off');
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
                errordlg2(errorMessage, 'Compare microstate maps error');
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
                errordlg2(errorMessage, 'Compare microstate maps error');
                return;
            else
                error(errorMessage);
            end
        end

        % Check for consistent labels
%         labels = {SelectedEEG.msinfo.MSMaps(classes).Labels};
%         labels = horzcat(labels{:});
%         if numel(unique(labels)) > MaxClasses && guiOpts.showCompWarning1
%             if showDlg
%                 [yesPressed, ~, boxChecked] = warningDialog(['Map labels are inconsistent across cluster solutions.' ...
%                     ' Are you sure you would like to proceed?'], 'Compare microstate maps warning');
%                 if boxChecked;  guiOpts.showCompWarning1 = false;   end
%                 if ~yesPressed; return;                             end
%             else
%                 warning('Map labels are inconsistent across cluster solutions.');
%             end
%         end

    %% If comparing across datasets, ask user for number of classes and check for consistent labels
    else
        showDlg = all(matches({'IndividualSets', 'MeanSets', 'PublishedSets'}, p.UsingDefaults));
        setnames = {SelectedEEG(nonpublishedSets).setname};

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
        if any(strcmp(SortModes, 'none'))            
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
        
        % Check for consistent labels
%         labels = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(c).Labels, nonpublishedSets, 'UniformOutput', false);
%         labels = horzcat(labels{:});
%         if numel(unique(labels)) > MaxClasses && guiOpts.showCompWarning2
%             if showDlg
%                 [yesPressed, ~, boxChecked] = warningDialog(['Map labels are inconsistent across datasets.' ...
%                     ' Are you sure you would like to proceed?'], 'Compare microstate maps warning');
%                 if boxChecked;  guiOpts.showCompWarning2 = false;   end
%                 if ~yesPressed; return;                             end
%             else
%                 warning('Map labels are inconsistent across datasets.');
%             end
%         end

    end

    %% Check for different channel numbers and create common set of channels
    inputEEG = SelectedEEG;
    if numel(SelectedEEG) > 1
        nChannels = arrayfun(@(x) numel(SelectedEEG(x).chanlocs), 1:numel(SelectedEEG));
        [~, minSetIdx] = min(nChannels);

        for i=1:numel(inputEEG)
            if i == minSetIdx
                continue
            end
            
            [LocalToGlobal, ~] = MakeResampleMatrices(inputEEG(i).chanlocs, inputEEG(minSetIdx).chanlocs);
            
            for class=inputEEG(i).msinfo.ClustPar.MinClasses:inputEEG(i).msinfo.ClustPar.MaxClasses
                inputEEG(i).msinfo.MSMaps(class).Maps = inputEEG(i).msinfo.MSMaps(class).Maps*LocalToGlobal';
                inputEEG(i).chanlocs = inputEEG(minSetIdx).chanlocs;
            end
        end
    end

    %% Display GUI and export shared variances
    if compWithin
        nClasses = 0;
    end

    if ~isempty(Filename)
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
        CorrTable = array2table(CorrMat * 100,'VariableNames',CLabelCollection,'RowNames',CLabelCollection);

        if ~contains(Filename, '.mat')
            writetable(CorrTable, Filename, 'WriteRowNames', true);
        else
            save(Filename, 'CorrTable');
        end
    end

    if showGUI
        Filenames = CompareMicrostateSolutions(inputEEG, nClasses, Filename);
    end
    
    EEGout = SelectedEEG(nonpublishedSets);
    CurrentSet = [IndividualSets, MeanSets];

    if ~compWithin
        if isempty(PublishedSets)
            PublishedSetsTxt = '[]';
        else
            PublishedSetsTxt = sprintf('''%s'', ', string(PublishedSets));
            PublishedSetsTxt = ['{' PublishedSetsTxt(1:end-2) '}'];
        end
        if isempty(Filenames)
            compCom = sprintf('[EEG, CURRENTSET, COM] = pop_CompareMSMaps(ALLEEG, ''IndividualSets'', %s, ''MeanSets'', %s, ''PublishedSets'', %s, ''Classes'', %i, ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), PublishedSetsTxt, nClasses, showGUI);
        else
            compCom = sprintf('[EEG, CURRENTSET, COM] = pop_CompareMSMaps(ALLEEG, ''IndividualSets'', %s, ''MeanSets'', %s, ''PublishedSets'', %s, ''Classes'', %i, ''Filename'', ''%s'', ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), PublishedSetsTxt, nClasses, Filenames{1}, showGUI);
        end
        if numel(Filenames) > 1
            for i=2:numel(Filenames)
                compCom = [compCom newline ...
                    sprintf('[EEG, CURRENTSET, COM] = pop_CompareMSMaps(ALLEEG, ''IndividualSets'', %s, ''MeanSets'', %s, ''PublishedSets'', %s, ''Classes'', %i, ''Filename'', ''%s'', ''gui'', %i);', ...
                    mat2str(IndividualSets), mat2str(MeanSets), PublishedSetsTxt, nClasses, Filenames{i}, showGUI)];
            end
        end
    else
        if isempty(Filenames)
            compCom = sprintf('[EEG, CURRENTSET, COM] = pop_CompareMSMaps(ALLEEG, ''IndividualSets'', %s, ''MeanSets'', %s, ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), showGUI);
        else
            compCom = sprintf('[EEG, CURRENTSET, COM] = pop_CompareMSMaps(ALLEEG, ''IndividualSets'', %s, ''MeanSets'', %s, ''Filename'', ''%s'', ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), Filenames{1}, showGUI);
        end
        for i=2:numel(Filenames)
            compCom = [compCom newline ...
                sprintf('[EEG, CURRENTSET, COM] = pop_CompareMSMaps(ALLEEG, ''IndividualSets'', %s, ''MeanSets'', %s, ''Filename'', ''%s'', ''gui'', %i);', ...
                mat2str(IndividualSets), mat2str(MeanSets), Filenames{1}, showGUI)];
        end
    end

    if isempty(com)
        com = compCom;
    else
        com = [com newline compCom];
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