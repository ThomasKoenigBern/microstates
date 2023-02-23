function [EEGout, CurrentSet, com] = pop_CompareMSTemplates(AllEEG, varargin)
    
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
    funcName = 'pop_CompareMSTemplates';
    p.FunctionName = funcName;
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'IndividualSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addOptional(p, 'MeanSets', [], @(x) validateattributes(x, {'char', 'string', 'cell', 'numeric'}, {'vector'}));
    addOptional(p, 'PublishedSets', [], @(x) validateattributes(x, {'char', 'string', 'cell'}, {'vector'}));
    addParameter(p, 'nClasses', []);
    addParameter(p, 'Filename', '', @(x) validateattributes(x, {'char', 'string'}, {'scalartext'}));
    addParameter(p, 'gui', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));

    parse(p, AllEEG, varargin{:});

    IndividualSets = p.Results.IndividualSets;
    MeanSets = p.Results.MeanSets;
    PublishedSets = p.Results.PublishedSets;
    nClasses = p.Results.nClasses;
    Filename = p.Results.Filename;
    showGUI = p.Results.gui;

    if ~isempty(MeanSets)
        if isnumeric(MeanSets)
            validateattributes(p.Results.MeanSets, {'numeric'}, {'integer', 'vector', 'positive', '<=', numel(AllEEG)}, funcName, 'MeanSets');
        else
            MeanSets = convertStringsToChars(MeanSets);
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
        PublishedSets = convertStringsToChars(PublishedSets);
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
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    AvailableIndSets = find(and(and(and(~HasChildren, ~HasDyn), ~isEmpty), HasMS));
    AvailableMeanSets = find(and(and(and(HasChildren, ~HasDyn), ~isEmpty), HasMS));
    AvailablePublishedSets = 1:numel(MSTEMPLATE);
    AvailableSets = [AvailableIndSets, AvailableMeanSets, AvailablePublishedSets];

    if isempty(AvailableSets)
        errordlg2(['No valid sets for comparing found.'], 'Compare microstate maps error');
    end

    % Validate individual sets
    if ~isempty(IndividualSets)
        IndividualSets = unique(IndividualSets);
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
        MeanSets = unique(MeanSets);
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
        PublishedSets = unique(PublishedSets);
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

    %% If comparing within a dataset, check for consistent sorting across solutions
    if compWithin
        MinClasses = SelectedEEG.msinfo.ClustPar.MinClasses;
        MaxClasses = SelectedEEG.msinfo.ClustPar.MaxClasses;

        % First check if any solutions remain unsorted
        yesPressed = false;
        SortModes = {SelectedEEG.msinfo.MSMaps(MinClasses:MaxClasses).SortMode};
        if any(strcmp(SortModes, 'none')) && guiOpts.showCompWarning1
            warningMessage = ['Some cluster solutions remain unsorted. Would you like to sort' ...
                ' all solutions according to the same template before proceeding?'];
            [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
            if boxChecked;  guiOpts.showCompWarning1 = false;   end
            if yesPressed
                [SelectedEEG, ~, com] = pop_SortMSTemplates(SelectedEEG, 1, 'ClassRange', MinClasses:MaxClasses);
                if isempty(com);    return; end
            elseif ~noPressed
                return;
            end
        end

        % Check if there is inconsistency in sorting across solutions
        SortedBy = {SelectedEEG.msinfo.MSMaps(MinClasses:MaxClasses).SortedBy};
        emptyIdx = cellfun(@isempty, SortedBy);
        SortedBy(emptyIdx) = [];
        if any(contains(SortedBy, '->'))
            multiSortedBys = cellfun(@(x) x(1:strfind(x, '->')-1), SortedBy(contains(SortedBy, '->')), 'UniformOutput', false);
            SortedBy(contains(SortedBy, '->')) = multiSortedBys;
        end
        if ~yesPressed && numel(unique(SortedBy)) > 1 && guiOpts.showCompWarning2
            warningMessage = ['Sorting information differs across cluster solutions. Would you like ' ...
                'to sort all solutions according to the same template before proceeding?'];
            [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
            if boxChecked;  guiOpts.showCompWarning2 = false;   end
            if yesPressed
                [SelectedEEG, ~, com] = pop_SortMSTemplates(SelectedEEG, 1, 'ClassRange', MinClasses:MaxClasses);
                if isempty(com);    return; end
            elseif ~noPressed
                return;
            end
        end

        % Check for unassigned labels
        Colors = cell2mat({SelectedEEG.msinfo.MSMaps(MinClasses:MaxClasses).ColorMap}');
        if any(arrayfun(@(x) all(Colors(x,:) == [.75 .75 .75]), 1:size(Colors,1))) && guiOpts.showCompWarning3
            warningMessage = 'Some maps do not have assigned labels. Are you sure you would like to proceed?';
            [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
            if boxChecked;  guiOpts.showCompWarning3 = false;   end
            if ~yesPressed
                return;
            end
        end

        % Check for consistent labels
        MaxLabels = SelectedEEG.msinfo.MSMaps(MaxClasses).Labels;
        AllLabels = {};
        unmatchedLabels = false;
        for class=MinClasses:MaxClasses
            AllLabels = [AllLabels SelectedEEG.msinfo.MSMaps(class).Labels];
            if ~all(matches(SelectedEEG.msinfo.MSMaps(class).Labels, MaxLabels))
                unmatchedLabels = true;
            end
        end

        if numel(unique(AllLabels)) > MaxClasses
            unmatchedLabels = true;
        end

        if unmatchedLabels && guiOpts.showCompWarning4
            warningMessage = 'Map labels are inconsistent across cluster solutions. Are you sure you would like to proceed?';
            [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
            if boxChecked;  guiOpts.showCompWarning3 = false;   end
            if ~yesPressed
                return;
            end
        end

    end

    %% If comparing across datasets, ask user for number of classes and check for consistent sorting
    if ~compWithin
        % Check for overlap in cluster solutions
        AllMinClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MinClasses, 1:numel(SelectedEEG));
        AllMaxClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MaxClasses, 1:numel(SelectedEEG));
        MinClasses = max(AllMinClasses);
        MaxClasses = min(AllMaxClasses);
        if MaxClasses < MinClasses
            errorMessage = ['No overlap in microstate classes found between all selected sets.'];
            errordlg2(errorMessage, 'Compare microstate maps error');
            return;
        end

        if contains('nClasses', p.UsingDefaults)
            classes = MinClasses:MaxClasses;
            classChoices = sprintf('%i Classes|', classes);
            classChoices(end) = [];
    
            [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
                { {'Style', 'text', 'string', 'Select cluster solution to compare'} ...
                  {'Style', 'listbox', 'string', classChoices, 'Tag', 'nClasses'}}, ...
                  'title', 'Sort microstate maps');
            
            if isempty(res); return; end
    
            nClasses = classes(outstruct.nClasses);
        end

        % Check for consistent sorting across sets
        % First check if any datasets remain unsorted
        yesPressed = false;
        SortModes = arrayfun(@(x) {SelectedEEG(x).msinfo.MSMaps(nClasses).SortMode}', nonpublishedSets);
        if any(strcmp(SortModes, 'none')) && guiOpts.showCompWarning1
            warningMessage = ['Some datasets remain unsorted. Would you like to ' ...
                'sort all sets according to the same template before proceeding?'];
            [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
            if boxChecked;  guiOpts.showCompWarning1 = false;  end
            if yesPressed
                [nonpublishedEEG, ~, com] = pop_SortMSTemplates(SelectedEEG, nonpublishedSets, 'ClassRange', nClasses);
                SelectedEEG(nonpublishedSets) = nonpublishedEEG;
                if isempty(com);    return; end
            elseif ~noPressed
                return;
            end
        end

        % Then check if there is inconsistency in sorting across datasets
        SortedBy = arrayfun(@(x) {SelectedEEG(x).msinfo.MSMaps(nClasses).SortedBy}', nonpublishedSets);
        emptyIdx = cellfun(@isempty, SortedBy);
        SortedBy(emptyIdx) = [];
        if any(contains(SortedBy, '->'))
            multiSortedBys = cellfun(@(x) x(1:strfind(x, '->')-1), SortedBy(contains(SortedBy, '->')), 'UniformOutput', false);
            SortedBy(contains(SortedBy, '->')) = multiSortedBys;
        end

        if ~yesPressed && numel(unique(SortedBy)) > 1 && guiOpts.showCompWarning2
            warningMessage = ['Sorting information differs across datasets. Would you like to ' ...
                'sort all sets according to the same template before proceeding?'];
            [yesPressed, noPressed, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
            if boxChecked;  guiOpts.showCompWarning2 = false;  end
            if yesPressed
                [nonpublishedEEG, ~, com] = pop_SortMSTemplates(SelectedEEG, nonpublishedSets, 'ClassRange', nClasses);
                SelectedEEG(nonpublishedSets) = nonpublishedEEG;
                if isempty(com);    return; end
            elseif ~noPressed
                return;
            end
        end

        % Check for unassigned labels
        Colors = cell2mat(arrayfun(@(x) cell2mat({SelectedEEG(x).msinfo.MSMaps(SelectedEEG(x).msinfo.ClustPar.MinClasses:SelectedEEG(x).msinfo.ClustPar.MaxClasses).ColorMap}'), ...
            1:numel(SelectedEEG), 'UniformOutput', false)');
        if any(arrayfun(@(x) all(Colors(x,:) == [.75 .75 .75]), 1:size(Colors,1))) && guiOpts.showCompWarning3
            warningMessage = 'Some maps do not have assigned labels. Are you sure you would like to proceed?';
            [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
            if boxChecked;  guiOpts.showCompWarning3 = false;   end
            if ~yesPressed
                return;
            end
        end

        % Check for consistent labels        
        for set=1:numel(SelectedEEG)
            AllLabels = {};
            
            for class=MinClasses:MaxClasses
                AllLabels = [AllLabels SelectedEEG(set).msinfo.MSMaps(class).Labels];
            end

            if numel(unique(AllLabels)) > MaxClasses
                unmatchedLabels = true;
            end
        end 

        if unmatchedLabels && guiOpts.showCompWarning4
            warningMessage = 'Map labels are inconsistent across cluster solutions. Are you sure you would like to proceed?';
            [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Compare microstate maps warning');
            if boxChecked;  guiOpts.showCompWarning3 = false;   end
            if ~yesPressed
                return;
            end
        end

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
        %% export variances
    end

    if showGUI
        Filename = CompareMicrostateSolutions(inputEEG, nClasses, Filename);
    end
    
    EEGout = SelectedEEG(nonpublishedSets);
    CurrentSet = [IndividualSets, MeanSets];

    if ~compWithin
        PublishedSetsTxt = sprintf('%s, ', string(PublishedSets));
        PublishedSetsTxt = ['{' PublishedSetsTxt(1:end-2) '}'];
        com = sprintf('[EEG, CURRENTSET, COM] = pop_CompareMSTemplates(%s, %s, %s, %s, ''nClasses'', %i, ''Filename'', ''%s'', ''gui'', %i);', ...
            inputname(1), mat2str(IndividualSets), mat2str(MeanSets), PublishedSetsTxt, nClasses, Filename, showGUI);
    else
        com = sprintf('[EEG, CURRENTSET, COM] = pop_CompareMSTemplates(%s, %s, %s, ''Filename'', ''%s'', ''gui'', %i);', ...
            inputname(1), mat2str(IndividualSets), mat2str(MeanSets), Filename, showGUI);
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