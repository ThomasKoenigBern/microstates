
function [EEGout, CurrentSet, setsTable, com] = pop_CompareTopos(AllEEG, varargin)

    com = '';
    global EEG;
    global CURRENTSET;
    global MSTEMPLATE;
    global guiOpts;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_CompareTopos';
    p.FunctionName = funcName;
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));
    addParameter(p, 'TemplateSet', '', @(x) validateattributes(x, {'char', 'string', 'numeric'}, {}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    nClasses = p.Results.Classes;
    TemplateSet = p.Results.TemplateSet;

    if isnumeric(TemplateSet)
        validateattributes(TemplateSet, {'numeric'}, {'integer', 'scalar', 'positive', '<=', numel(AllEEG)}, funcName, 'TemplateSet');
    else
        validateattributes(TemplateSet, {'char', 'string'}, {'scalartext'});
    end

    % Make sure there are individual sets available
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    isPublished = arrayfun(@(x) isPublishedSet(AllEEG(x), {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasChildren & ~HasDyn & ~isEmpty & ~isPublished);
    AvailableMeanSets = find(HasMS & HasChildren & ~HasDyn & ~isEmpty & ~isPublished);
    
    if isempty(AvailableSets)
        errorMessage = ['No valid sets found. Use Tools->Identify microstate maps per dataset ' ...
            'before using other functions.'];
        if isempty(SelectedSets)
            errordlg2(errorMessage, 'Compare topographical similarities error');
            return;
        else
            error(errorMessage);
        end
    end

    %% SelectedSets validation
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, or dynamics sets.'];
            error(errorMessage);
        end
    % Otherwise, prompt user to select sets
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res, ~, ~, outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', { ...
            { 'Style', 'text'    , 'string', 'Choose sets for comparison', 'fontweight', 'bold'} ...
            { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
            { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
            'title', 'Compare topographical similarities');
        
        if isempty(res);    return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);
    end

    SelectedEEG = AllEEG(SelectedSets);

    %% Classes validation
    % Prompt user to provide number of classes if necessary
    AllMinClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MinClasses, 1:numel(SelectedEEG));
    AllMaxClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MaxClasses, 1:numel(SelectedEEG));
    MinClasses = max(AllMinClasses);
    MaxClasses = min(AllMaxClasses);
    if MaxClasses < MinClasses
        errorMessage = 'No overlap in microstate classes found between all selected sets.';
        errordlg2(errorMessage, 'Compare topographical similarities error');
        return;
    end
    if matches('Classes', p.UsingDefaults)
        classRange = MinClasses:MaxClasses;
        classChoices = sprintf('%i Classes|', classRange);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select number of classes for comparison'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 1, 'Tag', 'Classes'}}, ...
              'title', 'Compare topographical similarities');
        
        if isempty(res); return; end

        nClasses = classRange(outstruct.Classes);
    else
        if (nClasses < MinClasses) || (nClasses > MaxClasses)
            error(['The specified number of classes %i is invalid.' ...
                ' Valid class numbers are in the range %i-%i.'], nClasses, MinClasses, MaxClasses);
        end
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
        % the mean setnames or published template setnames
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
            else
                error(['The specified template set "%s" could not be found in the ALLEEG ' ...
                    'mean sets or in the microstates/Templates folder.'], TemplateSet);
            end
        end        
    % Otherwise, prompt user to select template set
    else        
        combinedSetnames = [meanSetnames publishedDisplayNames];
        [res, ~, ~, outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 1], 'uilist', ...
            {{ 'Style', 'text', 'string', 'Name of template set', 'fontweight', 'bold'} ...
            { 'Style', 'popupmenu', 'string', combinedSetnames, 'tag', 'TemplateIndex', 'Value', TemplateIndex }}, ...
            'title', 'Compare topographical similarities');
        
        if isempty(res); return; end
        if outstruct.TemplateIndex <= numel(meanSetnames)+1
            TemplateIndex = outstruct.TemplateIndex;
            TemplateSet = AvailableMeanSets(TemplateIndex);
            TemplateName = meanSetnames{TemplateIndex};
        else
            TemplateIndex = outstruct.TemplateIndex - numel(meanSetnames);
            TemplateSet = publishedSetnames{TemplateIndex};
            TemplateName = TemplateSet;
            TemplateIndex = sortOrder(TemplateIndex);
            usingPublished = true;
        end
    end

    if usingPublished
        ChosenTemplate = MSTEMPLATE(TemplateIndex);
    else
        ChosenTemplate = AllEEG(AvailableMeanSets(TemplateIndex));
    end    

    %% Verify template set compatibility
    % Check that the template set contains a cluster solution matching the
    % selected number of classes
    if ChosenTemplate.msinfo.ClustPar.MinClasses > nClasses || ChosenTemplate.msinfo.ClustPar.MaxClasses < nClasses
        errorMessage = sprintf(['Template set "%s" does not contain a %i cluster solution. Select a different template set' ...
            ' or use Tools->Identify group level or grand mean template maps to create a mean set to use as a template.'], TemplateName, nClasses);
        if matches('TemplateSet', p.UsingDefaults)
            errordlg2(errorMessage, 'Compare topographical similarities');
            return;
        else
            error(errorMessage);
        end
    end

    % If the template set chosen is a mean set, make sure it is a parent
    % set of all the selected sets
    if ~usingPublished
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

        if ~isempty(warningSetnames) && guiOpts.showSortWarning
            warningMessage = sprintf(['Template set "%s" is not the parent set of ' ...
                'the following sets. Are you sure you would like to proceed?'], TemplateName);
            [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Compare topographical similarities warning', warningSetnames);
            if boxChecked;  guiOpts.showSortWarning = false;    end
            if ~yesPressed; return;                             end
        end
    end

    %% Check for consistent sorting across sets
    % First check if any datasets remain unsorted
    SortModes = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).SortMode, 1:numel(SelectedEEG), 'UniformOutput', false);
    if any(strcmp(SortModes, 'none'))
        errorMessage = ['Some datasets remain unsorted. Please sort all ' ...
            'sets before proceeding.'];
        errordlg2(errorMessage, 'Compare topographical similarities error');
        return;
    end

    % Then check that selected sets were sorted by the template set
    SortedBy = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).SortedBy, 1:numel(SelectedEEG), 'UniformOutput', false);
    emptyIdx = arrayfun(@(x) isempty(SortedBy{x}), 1:numel(SortedBy));
    SortedBy(emptyIdx) = '';
    if ~all(contains(SortedBy, TemplateName))
        warningMessage = sprintf('Not all selected sets are sorted by the template set "%s." Are you sure you would like to continue?', TemplateName);
        [yesPressed, ~, boxChecked] = warningDialog(warningMessage, 'Compare topographical similarities warning');
        if boxChecked;  guiOpts.showTopoWarning1 = false;    end
        if ~yesPressed; return; end
    end

    % Check for unassigned labels
    Colors = cell2mat(arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).ColorMap, 1:numel(SelectedEEG), 'UniformOutput', false)');
    if any(arrayfun(@(x) all(Colors(x,:) == [.75 .75 .75]), 1:size(Colors,1)))
        errorMessage = ['Some maps do not have assigned labels. For all maps to be assigned a label, each set must either be ' ...
            'manually sorted and assigned new labels, or sorted by a template set with equal (ideally) or greater number of maps. Please ' ...
            'sort sets such that all maps have a label before proceeding.'];
        errordlg2(errorMessage, 'Compare topographical similarities error');
        return;
    end

    % Check for consistent labels 
    unmatched = false;
    for c=1:nClasses
        labels = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).Labels(c), 1:numel(SelectedSets));
        if numel(unique(labels)) > 1
            unmatched = true;
            break;
        end
    end 
    if unmatched
        errorMessage = ['Map labels are inconsistent across cluster solutions. This can occur when sorting is performed using a ' ...
            'template set with a greater number of maps than the solution being sorted. To achieve consistency, maps should ideally be manually sorted ' ...
            'and assigned the same set of labels, or sorted using a template set with an equal number of maps. Please re-sort sets to achieve consistency ' ...
            'before proceeding.'];
        errordlg2(errorMessage, 'Compare topographical similarities error');
        return;
    end            

    EEGout = SelectedEEG;
    CurrentSet = SelectedSets;

    %% Build GUI
    MapLabels = SelectedEEG(1).msinfo.MSMaps(nClasses).Labels;

    % Get usable screen size
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    jframe = javax.swing.JFrame;
    insets = toolkit.getScreenInsets(jframe.getGraphicsConfiguration());
    tempFig = figure('ToolBar', 'none', 'MenuBar', 'none', 'Visible', 'off');
    pause(0.2);
    titleBarHeight = tempFig.OuterPosition(4) - tempFig.InnerPosition(4) + tempFig.OuterPosition(2) - tempFig.InnerPosition(2);
    delete(tempFig);
    % Use the largest monitor available
    monitorPositions = get(0, 'MonitorPositions');
    if size(monitorPositions, 1) > 1
        screenSizes = arrayfun(@(x) monitorPositions(x, 3)*monitorPositions(x,4), 1:size(monitorPositions, 1));
        [~, i] = max(screenSizes);
        screenSize = monitorPositions(i, :);
    else
        screenSize = get(0, 'ScreenSize');
    end
    figSize = screenSize + [insets.left, insets.bottom, -insets.left-insets.right, -titleBarHeight-insets.bottom-insets.top];

    maxSubjWidth = max(cellfun(@length, {SelectedEEG.setname}))*9;
    if maxSubjWidth > 200;  maxSubjWidth = 200; end
    colWidth = 65;
    tblWidth = maxSubjWidth + colWidth*numel(MapLabels);

    fig_h = uifigure('Name', 'Compare topographical similarities', 'HandleVisibility', 'on', 'CloseRequestFcn', @figClose);
    
    if tblWidth > .4*figSize(3)
        tblWidth = floor(.4*figSize(3));
        fig_h.Units = 'pixels';
        fig_h.Position = figSize;
        figWidth = figSize(3);
    else
        fig_h.Units = 'normalized';
        fig_h.Position = [.1 .1 .8 .8];
        figWidth = figSize(3)*.8;
    end

    horzLayout = uigridlayout(fig_h, [2 1]);
    horzLayout.RowHeight = {'1x', 150};
    vertLayout = uigridlayout(horzLayout, [1 2]);
    vertLayout.ColumnWidth = {'1x', tblWidth};
    vertLayout.ColumnSpacing = 0;
    vertLayout.Padding = [0 0 0 0];
    
    axLayout = uigridlayout(vertLayout, [2 1]);
    axLayout.RowHeight = {70, '1x'};
    axLayout.Padding = [0 0 0 0];
    
    selectLayout = uigridlayout(axLayout, [2 9]);
    selectLayout.ColumnWidth = {'1x', 80, 150, 40, 65, 40, 40, 105, '1x'};
    selectLayout.Padding = [0 0 0 0];
    
    selMapLabel = uilabel(selectLayout, 'Text', 'Select map', 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    selMapLabel.Layout.Row = 2;
    selMapLabel.Layout.Column = 2;    
    ud.selMap = uidropdown(selectLayout, 'Items', MapLabels, 'ItemsData', 2:numel(MapLabels)+1, 'ValueChangedFcn', {@mapChanged, fig_h});
    ud.selMap.Layout.Row = 2;
    ud.selMap.Layout.Column = 3;
    
    autoBtn = uibutton(selectLayout, 'Text', 'Auto select', 'ButtonPushedFcn', {@autoSelect, fig_h});
    autoBtn.Layout.Row = 1;
    autoBtn.Layout.Column = [5 6];
    
    ud.editLabel = uilabel(selectLayout);
    ud.editLabel.Text = 'Threshold';
    ud.editLabel.Layout.Row = 2;
    ud.editLabel.Layout.Column = 5;
    ud.editBox = uieditfield(selectLayout);
    ud.editBox.Value = '60';
    ud.editBox.Layout.Row = 2;
    ud.editBox.Layout.Column = 6;
    
    ud.keepBtn = uibutton(selectLayout, 'Text', 'Keep', 'Enable', 'off', 'ButtonPushedFcn', {@keep, fig_h});
    ud.keepBtn.Layout.Row = 1;
    ud.keepBtn.Layout.Column = 8;
    ud.excludeBtn = uibutton(selectLayout, 'Text', 'Exclude', 'Enable', 'off', 'ButtonPushedFcn', {@exclude, fig_h});
    ud.excludeBtn.Layout.Row = 2;
    ud.excludeBtn.Layout.Column = 8;
    
    ud.ax = axes(axLayout);
    ud.ax.ButtonDownFcn = {@axisClicked, fig_h};
    
    ud.setnames = {SelectedEEG.setname};
    opts = {'Keep', 'Exclude'};
    tblData = [ud.setnames', repmat(" ", numel(SelectedSets), numel(MapLabels))];
    ud.setsTable = uitable(vertLayout, 'Data', tblData, 'RowName', [], 'RowStriping', 'off', 'ColumnWidth', ['auto' repmat({colWidth}, 1, numel(MapLabels))], ...
        'ColumnName', [{'Subject'}, MapLabels], 'ColumnFormat', [ {[]} repmat({opts}, 1, numel(MapLabels)) ], 'Fontweight', 'bold', ...
        'Multiselect', 'off', 'CellEditCallback', {@cellChanged, fig_h}, 'SelectionChangedFcn', {@selectionChanged, fig_h});
    
    minGridWidth = 60;
    minPanelWidth = minGridWidth*nClasses;
    if minPanelWidth > (figWidth - 20)
        OuterPanel = uipanel(horzLayout, 'BorderType', 'none');
        OuterPanel.Layout.Row = 2;
        OuterPanel.Scrollable = 'on';
        ud.MapPanel = uipanel(OuterPanel, 'Units', 'pixels', 'Position', [0 0 minPanelWidth OuterPanel.Position(4)], 'BorderType', 'none');
    else
        ud.MapPanel = uipanel(horzLayout, 'BorderType', 'none', 'Visible', 'off');
        ud.MapPanel.Layout.Row = 2;
    end  
    ud.MapPanel.UserData.MapLayout = tiledlayout(ud.MapPanel, 1, nClasses, 'TileSpacing', 'tight', 'Padding', 'tight');
    ud.SingleMapPanel = uipanel(ud.MapPanel, 'Units', 'normalized', 'Position', [0 0 .5 1], 'BorderType', 'none', 'Visible', 'off');
    ud.MapAxes = axes(ud.SingleMapPanel, 'Position', [0 0 .9 .8]);
    
    % Extract maps, channel locations, and correlations for all sets
    ud.MSMaps = [];    
    ud.chanlocs = cell(1, numel(SelectedSets));
    ud.mapVars = zeros(nClasses, numel(SelectedSets));
    for i=1:numel(SelectedSets)
        ud.MSMaps = [ud.MSMaps SelectedEEG(i).msinfo.MSMaps(nClasses)];
        ud.chanlocs{i} = SelectedEEG(i).chanlocs;
        [LocalToGlobal, GlobalToLocal] = MakeResampleMatrices(SelectedEEG(i).chanlocs,ChosenTemplate.chanlocs);
        if SelectedEEG(i).nbchan > ChosenTemplate.nbchan
            setMaps = SelectedEEG(i).msinfo.MSMaps(nClasses).Maps*LocalToGlobal';
            tempMaps = ChosenTemplate.msinfo.MSMaps(nClasses).Maps;
        else
            setMaps = SelectedEEG(i).msinfo.MSMaps(nClasses).Maps;
            tempMaps = ChosenTemplate.msinfo.MSMaps(nClasses).Maps*GlobalToLocal';
        end 
        ud.mapVars(:,i) = (diag(MyCorr(setMaps', tempMaps')).^2)*100;
    end

    ud.currentIdx = [];
    ud.highlightPoints = [];
    ud.dataTip = [];    
    
    fig_h.UserData = ud;
    
    mapChanged(ud.selMap, [], fig_h);

    uiwait();

    ud = fig_h.UserData;
    delete(fig_h);

    if ~isempty(ud.removeIdx)
        disp('Removing microstate map info from excluded sets...');
        for i=1:numel(ud.removeIdx)
            EEGout(ud.removeIdx(i)).msinfo = [];
        end
    end
    
    setsTable = ud.setsTable;
    
    if isnumeric(TemplateSet)
        TemplateSet = int2str(TemplateSet);
    else
        TemplateSet = sprintf("'%s'", TemplateSet);
    end
    com = sprintf('[EEG, CURRENTSET, setsTable] = pop_CompareTopos(%s, %s, ''Classes'', %i, ''TemplateSet'', %s);', inputname(1), mat2str(SelectedSets), nClasses, TemplateSet);
end

function figClose(fig, ~)
    ud = fig.UserData;
    ud.removeIdx = [];
    excludeIdx = find(any(strcmp(ud.setsTable.Data, "Exclude"), 2));
    if ~isempty(excludeIdx)
        selection = questionDialog('Remove microstate map info from excluded sets?', 'Outlier detection', {'Yes', 'No'});
        if strcmp(selection, 'Yes')
            ud.removeIdx = excludeIdx;
        end
    end

    fig.UserData = ud;
    uiresume();
end

function updatePlot(fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    % Get indices of different set categories
    excludeIdx = strcmp(ud.setsTable.Data(:,mapCol), "Exclude");    % sets to plot in red
    keepIdx = strcmp(ud.setsTable.Data(:,mapCol), "Keep");          % sets to plot in green
    reviewIdx = strcmp(ud.setsTable.Data(:,mapCol), "Review");      % sets to plot in orange

    cla(ud.ax);
    hold(ud.ax, 'on');
    % Plot shared variances for current map
    plot(ud.ax, 1:size(ud.mapVars,2), ud.mapVars(mapCol-1,:), '-k');
    ud.scatter = scatter(ud.ax, 1:size(ud.mapVars,2), ud.mapVars(mapCol-1,:), 10, 'black', 'filled');
    hold(ud.ax, 'off');    

    ylim(ud.ax, [0 100]);
    ylabel(ud.ax, 'Shared Variance (%)');
    xlabel(ud.ax, 'Datasets');

    ud.scatter.SizeData = repmat(10, size(ud.mapVars,2), 1);
    ud.scatter.CData = repmat([0 0 0], size(ud.mapVars,2), 1);    
    % Highlight categorized sets    
    ud.scatter.SizeData(excludeIdx | keepIdx | reviewIdx) = 25;
    if any(excludeIdx); ud.scatter.CData(excludeIdx,:) = repmat([1 0 0], sum(excludeIdx), 1);           end
    if any(keepIdx);    ud.scatter.CData(keepIdx, :) = repmat([0 1 0], sum(keepIdx), 1);                end
    if any(reviewIdx);  ud.scatter.CData(reviewIdx, :) = repmat([.929 .694 .125], sum(reviewIdx), 1);   end

    ud.scatter.ButtonDownFcn = {@axisClicked, fig_h};
    row1 = dataTipTextRow('Subject:', ud.setnames);
    sharedVarStr = arrayfun(@(x) sprintf('%2.2f%%', x), ud.scatter.YData, 'UniformOutput', false);
    row2 = dataTipTextRow('Shared variance:', sharedVarStr);
    ud.scatter.DataTipTemplate.DataTipRows = [row1 row2];
    ud.scatter.DataTipTemplate.Interpreter = 'none';

    % Disable buttons
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'off';
    
    fig_h.UserData = ud;
end

function axisClicked(~, event, fig_h)
    ud = fig_h.UserData;
    
    % Get the coordinates of where the user clicked
    x = event.IntersectionPoint(1);
    y = event.IntersectionPoint(2);

    coords(:,1) = ud.scatter.XData' - x;
    coords(:,2) = ud.scatter.YData' - y;

    coords = L2NormDim(coords,1);
    [~, ud.currentIdx] = min(sum(coords.^2, 2));

    fig_h.UserData = ud;

    highlightSets(fig_h);
end

function autoSelect(~, ~, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    excludeIdx = strcmp(ud.setsTable.Data(:,mapCol), "Exclude");
    keepIdx = strcmp(ud.setsTable.Data(:,mapCol), "Keep");

    threshold = str2double(ud.editBox.Value);
    % Find all points lower than threshold
    outliers = ud.scatter.YData < threshold;
    outliers = find(outliers(:) & ~excludeIdx & ~keepIdx);

    if any(outliers)        
        % Change color of points corresponding to outlier sets to yellow
        % for review and show datatips
        ud.scatter.CData(outliers,:) = repmat([.929 .694 .125], numel(outliers), 1);
        ud.scatter.SizeData(outliers) = 25;        

        % Update table to show outlier sets as "Review"
        ud.setsTable.Data(outliers, mapCol) = "Review";
        tblStyle = uistyle('BackgroundColor', [.929 .694 .125]);
        addStyle(ud.setsTable, tblStyle, 'cell', [outliers repmat(mapCol, numel(outliers), 1)]);
    else
        msgbox('No outliers detected.');
    end

    % Disable buttons
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'off';

    % Hide maps and clear selection
    ud.MapPanel.Visible = 'off';
    ud.setsTable.Selection = [];
    if ~isempty(ud.highlightPoints);    delete(ud.highlightPoints);   end
    if ~isempty(ud.dataTip);            delete(ud.dataTip);           end

    ud.currentIdx = outliers;
    fig_h.UserData = ud;

    % Highlight outliers
    highlightSets(fig_h);
end

function cellChanged(~, event, fig_h)
    fig_h.UserData.currentIdx = event.Indices(1);

    switch(event.EditData)
        case 'Keep'
            keep([], [], fig_h);
        case 'Exclude'
            exclude([], [], fig_h);
    end
end

function selectionChanged(tbl, event, fig_h)
    ud = fig_h.UserData;
    setIdx = event.Selection(1);

    if event.Selection(2) ~= ud.selMap.Value && event.Selection(2) ~= 1
        tbl.Selection = event.PreviousSelection;
        return;
    elseif event.Selection(2) == 1
        % Display all maps of the selected dataset
        PlotMSMaps2(fig_h, ud.MapPanel, ud.MSMaps(setIdx), ud.chanlocs{setIdx});
        ud.MapPanel.Visible = 'on';
        ud.MapPanel.UserData.MapLayout.Visible = 'on';
        ud.SingleMapPanel.Visible = 'off';

        % Clear selections
        if ~isempty(ud.highlightPoints);    delete(ud.highlightPoints);   end
        if ~isempty(ud.dataTip);            delete(ud.dataTip);           end
    else
        ud.currentIdx = setIdx;
        fig_h.UserData = ud;
        highlightSets(fig_h);
    end
end

function exclude(~, ~, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    % Update table
    ud.setsTable.Data(ud.currentIdx, mapCol) = 'Exclude';
    tblStyle = uistyle('BackgroundColor', [.97 .46 .46]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.currentIdx mapCol]);

    % Update buttons
    ud.keepBtn.Enable = 'on';
    ud.excludeBtn.Enable = 'off';

    % Update plot
    ud.scatter.CData(ud.currentIdx,:) = [1 0 0];
    ud.scatterSizeData(ud.currentIdx) = 25;

    % Remove datatip
    delete(ud.dataTip);

    fig_h.UserData = ud;
end

function keep(~, ~, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    % Update table
    ud.setsTable.Data(ud.currentIdx, mapCol) = 'Keep';
    tblStyle = uistyle('BackgroundColor', [.77 .96 .79]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.currentIdx mapCol]);

    % Update buttons   
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'on';

    % Update plot
    ud.scatter.CData(ud.currentIdx,:) = [0 1 0];
    ud.scatterSizeData(ud.currentIdx) = 25;

    % Remove datatip
    delete(ud.dataTip);

    fig_h.UserData = ud;
end

function highlightSets(fig_h)
    ud = fig_h.UserData;

    ud.MapPanel.UserData.MapLayout.Visible = 'off';

    mapCol = ud.selMap.Value;

    x = ud.currentIdx;
    y = ud.scatter.YData(ud.currentIdx);

    hold(ud.ax, 'on');
    if ~isempty(ud.dataTip);            delete(ud.dataTip);         end
    if ~isempty(ud.highlightPoints);    delete(ud.highlightPoints); end

    % Highlight the selected set(s)
    ud.highlightPoints = scatter(ud.ax, x, y, 80, [1 1 0], 'LineWidth', 2.5);
    ud.highlightPoints.ButtonDownFcn = {@axisClicked, fig_h};

    if numel(ud.currentIdx) == 1
        % Make datatip
        ud.dataTip = datatip(ud.scatter, x, y);

        % Update buttons    
        if strcmp(ud.setsTable.Data(ud.currentIdx,mapCol), "Keep")
            ud.keepBtn.Enable = 'off';
            ud.excludeBtn.Enable = 'on';
        elseif strcmp(ud.setsTable.Data(ud.currentIdx,mapCol), "Exclude")
            ud.keepBtn.Enable = 'on';
            ud.excludeBtn.Enable = 'off';
        else
            ud.keepBtn.Enable = 'on';
            ud.excludeBtn.Enable = 'on';
        end

        % Select set in table
        ud.setsTable.Selection = [ud.currentIdx mapCol];
        scroll(ud.setsTable, 'row', ud.currentIdx);
    
        % Plot map of selected set    
        X =[ud.chanlocs{ud.currentIdx}.X];
        Y =[ud.chanlocs{ud.currentIdx}.Y];
        Z =[ud.chanlocs{ud.currentIdx}.Z];
        Background = ud.MSMaps(ud.currentIdx).ColorMap(mapCol-1,:);
        dspCMap3(ud.MapAxes, double(ud.MSMaps(ud.currentIdx).Maps(mapCol-1,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
        title(ud.MapAxes, ud.MSMaps(ud.currentIdx).Labels{mapCol-1},'FontSize', 9, 'Interpreter','none');
        ud.MapAxes.Position = [0 0 .9 .8];
        ud.SingleMapPanel.Position = [0 0 .5 1];
        ud.SingleMapPanel.Visible = 'on';
        ud.MapPanel.Visible = 'on';
     end        

    fig_h.UserData = ud;
end

function mapChanged(src, ~, fig_h)
    ud = fig_h.UserData;

    mapCol = src.Value;

    % Set focus on the column corresponding to the currently selected map
    % and gray out the other columns
    unselectedStyle = uistyle('BackgroundColor', [.75 .75 .75], 'FontColor', [.95 .95 .95], 'FontWeight', 'normal');
    selectedStyle = uistyle('BackgroundColor', [1 1 1], 'FontColor', [0 0 0], 'FontWeight', 'bold');
    cols = 2:numel(src.Items)+1;
    addStyle(ud.setsTable, unselectedStyle, 'column', cols(cols ~= mapCol));
    addStyle(ud.setsTable, selectedStyle, 'column', mapCol);

    % Add back coloring to the column of the currently selected map
    keepStyle = uistyle('BackgroundColor', [.77 .96 .79]);
    excludeStyle = uistyle('BackgroundColor', [.97 .46 .46]);
    reviewStyle = uistyle('BackgroundColor', [.929 .694 .125]);
    keepIdx = find(strcmp(ud.setsTable.Data(:, mapCol), "Keep"));
    addStyle(ud.setsTable, keepStyle, 'cell', [keepIdx repmat(mapCol, numel(keepIdx), 1)]);
    excludeIdx = find(strcmp(ud.setsTable.Data(:, mapCol), "Exclude"));
    addStyle(ud.setsTable, excludeStyle, 'cell', [excludeIdx repmat(mapCol, numel(excludeIdx), 1)]);
    reviewIdx = find(strcmp(ud.setsTable.Data(:,mapCol), "Review"));
    addStyle(ud.setsTable, reviewStyle, 'cell', [reviewIdx repmat(mapCol, numel(reviewIdx), 1)]);

    % Make only the column of the currently selected map editable
    editable = false(1, numel(src.Items)+1);
    editable(mapCol) = true;
    ud.setsTable.ColumnEditable = editable;

    scroll(ud.setsTable, 'column', mapCol);

    % Hide maps and clear selection
    ud.MapPanel.Visible = 'off';
    ud.setsTable.Selection = [];

    updatePlot(fig_h);
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

function isPublished = isPublishedSet(in, templateNames)
    isPublished = false;
    if isempty(in.setname)
        return;
    end

    if matches(in.setname, templateNames)
        isPublished = true;
    end
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