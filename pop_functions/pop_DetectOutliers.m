
function [EEGout, CurrentSet, com] = pop_DetectOutliers(AllEEG, varargin)
    
    com = '';
    global EEG;
    global CURRENTSET;
    global MSTEMPLATE;
    EEGout = EEG;
    CurrentSet = CURRENTSET;

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_DetectOutliers';
    p.FunctionName = funcName;
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    nClasses = p.Results.Classes;

    %% Selected sets validation
    % Make sure there are individual sets available for outlier detection
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    isPublishedSet = arrayfun(@(x) matches(AllEEG(x).setname, {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasChildren & ~HasDyn & ~isEmpty & ~isPublishedSet);
    
    if isempty(AvailableSets)
        errordlg2(['No valid sets for outlier detection found.'], 'Outlier detection error');
        return;
    end

    % Validate selected sets
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            errorMessage = ['The following sets cannot be included in outlier detection: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, or dynamics sets.'];
            errordlg2(errorMessage, 'Outlier detection error');
            return;
        end
    % Otherwise, prompt user to select sets
    else
        defaultSets = find(ismember(AvailableSets, CurrentSet));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res, ~, ~, outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', { ...
            { 'Style', 'text'    , 'string', 'Choose sets for outlier detection'} ...
            { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
            { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
            'title', 'Outlier detection');
        
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
        errorMessage = ['No overlap in microstate classes found between all selected sets.'];
        errordlg2(errorMessage, 'Outlier detection error');
        return;
    end
    if contains('Classes', p.UsingDefaults)
        classRange = MinClasses:MaxClasses;
        classChoices = sprintf('%i Classes|', classRange);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select number of classes for outlier detection'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 1, 'Tag', 'Classes'}}, ...
              'title', 'Sort microstate maps');
        
        if isempty(res); return; end

        nClasses = classRange(outstruct.Classes);
    else
        if (nClasses < MinClasses) || (nClasses > MaxClasses)
            errorMessage = sprintf(['The specified number of classes %i is invalid.' ...
                '. Valid class numbers are in the range %i-%i.'], nClasses, MinClasses, MaxClasses);
            errordlg2(errorMessage, 'Outlier detection error');
            return;
        end
    end

    %% Check for consistent sorting across sets
    % First check if any datasets remain unsorted
    SortModes = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).SortMode, 1:numel(SelectedEEG), 'UniformOutput', false);
    if any(strcmp(SortModes, 'none'))
        errorMessage = ['Some datasets remain unsorted. Please sort all ' ...
            'sets according to the same template before performing outlier detection.'];
        errordlg2(errorMessage, 'Outlier detection error');
        return;
    end

    % Then check if there is inconsistency in sorting across datasets
    SortedBy = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).SortedBy, 1:numel(SelectedEEG), 'UniformOutput', false);
    emptyIdx = arrayfun(@(x) isempty(SortedBy{x}), 1:numel(SortedBy));
    SortedBy(emptyIdx) = [];
    if any(contains(SortedBy, '->'))
        multiSortedBys = cellfun(@(x) x(1:strfind(x, '->')-1), SortedBy(contains(SortedBy, '->')), 'UniformOutput', false);
        SortedBy(contains(SortedBy, '->')) = multiSortedBys;
    end
    if ~numel(unique(SortedBy)) > 1
        errorMessage = ['Sorting information differs across datasets. Please sort all ' ...
            'sets according to the same template before performing outlier detection.'];
        errordlg2(errorMessage, 'Outlier detection error');
        return;
    end

    % Check for unassigned labels
    Colors = cell2mat(arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).ColorMap, 1:numel(SelectedEEG), 'UniformOutput', false)');
    if any(arrayfun(@(x) all(Colors(x,:) == [.75 .75 .75]), 1:size(Colors,1)))
        errorMessage = ['Some maps do not have assigned labels. For all maps to be assigned a label, each set must either be ' ...
            'manually sorted and assigned new labels, or sorted by a template set with equal (ideally) or greater number of maps. Please ' ...
            're-sort sets such that all maps have a label before performing outlier detection.'];
        errordlg2(errorMessage, 'Outlier detection error');
        return;
    end

    % Check for consistent labels 
    AllLabels = {};
    for set=1:numel(SelectedEEG)                 
        AllLabels = [AllLabels SelectedEEG(set).msinfo.MSMaps(nClasses).Labels];
    end 
    if numel(unique(AllLabels)) > nClasses
        errorMessage = ['Map labels are inconsistent across cluster solutions. This can occur when sorting is performed using a ' ...
            'template set with a greater number of maps than the solution being sorted. To achieve consistency, maps should ideally be manually sorted ' ...
            'and assigned the same set of labels, or sorted using a template set with an equal number of maps. Please re-sort sets to achieve consistency ' ...
            'before performing outlier detection.'];
        errordlg2(errorMessage, 'Outlier detection error');
        return;
    end        

    EEGout = SelectedEEG;
    CurrentSet = SelectedSets;

    %% Create outlier detection GUI
    
    fig_h = uifigure('Name', 'Outlier detection', 'Units', 'normalized', ...
    'Position', [.2 .1 .6 .8], 'HandleVisibility', 'on');
        
    vertLayout1 = uigridlayout(fig_h, [1 2]);
    vertLayout1.ColumnWidth = {'1x', 300};
    vertLayout1.ColumnSpacing = 0;
    horzLayout = uigridlayout(vertLayout1, [2 1]);
    horzLayout.RowHeight = {'1x', 150};
    horzLayout.Padding = [0 0 0 0];
    vertLayout2 = uigridlayout(horzLayout, [1 2]);
    vertLayout2.ColumnWidth = {115, '1x'};
    btnLayout = uigridlayout(vertLayout2, [12 1]);
    btnLayout.Padding = [0 0 0 0];
    btnLayout.RowHeight = {'1x', 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, '1x'};
    
    ud.outlierPlot = axes(vertLayout2);
    axis(ud.outlierPlot, 'equal');
    axis(ud.outlierPlot, 'tight');
    axis(ud.outlierPlot, 'square');
    
    setLayout = uigridlayout(vertLayout1, [2 1]);
    setLayout.RowHeight = {30, '1x'};
    setLayout.Padding = [0 0 0 0];
    
    mapSelectLayout = uigridlayout(setLayout, [1 2]);
    mapSelectLayout.ColumnWidth = {80, '1x'};
    mapSelectLayout.Padding = [0 0 0 0];
    uilabel(mapSelectLayout, 'Text', 'Select map', 'FontWeight', 'bold');
    
    % Get unique map labels
    MapLabels = unique(AllLabels);
    ud.selMap = uidropdown(mapSelectLayout, 'Items', MapLabels, 'ItemsData', 2:numel(MapLabels)+1, 'ValueChangedFcn', {@mapChanged, fig_h});
    
    setnames = {SelectedEEG.setname};
    opts = {'Keep', 'Exclude', 'Highlight'};
    % Find indices with missing maps and populate table data
    tblData = [setnames', repmat(" ", numel(SelectedSets), numel(MapLabels))];
    ud.setsTable = uitable(setLayout, 'Data', tblData, 'RowName', [], 'RowStriping', 'off', ...
        'ColumnName', [{'Subject'}, MapLabels], 'ColumnFormat', [ {[]} repmat({opts}, 1, numel(MapLabels)) ], 'Fontweight', 'bold', ...
        'Multiselect', 'off', 'CellEditCallback', {@cellChanged, fig_h}, 'SelectionChangedFcn', {@selectionChanged, fig_h});
    
    manualBtn = uibutton(btnLayout, 'Text', 'Manual select next', 'ButtonPushedFcn', {@manualSelectNext, fig_h});
    manualBtn.Layout.Row = 2;
    autoBtn = uibutton(btnLayout, 'Text', 'Auto select next', 'ButtonPushedFcn', {@autoSelectNextFMCD, fig_h});
    allBtn = uibutton(btnLayout, 'Text', 'Auto select all', 'ButtonPushedFcn', {@autoSelectAllFMCD, fig_h});
    pLayout = uigridlayout(btnLayout, [1 2]);
    pLayout.Padding = [0 0 0 0];
    pLayout.ColumnWidth = {40, '1x'};
    pLabel = uilabel(pLayout, 'Text', 'p value');
    ud.pEdit = uieditfield(pLayout, 'Value', '0.05');
    ud.keepBtn = uibutton(btnLayout, 'Text', 'Keep', 'Enable', 'off', 'ButtonPushedFcn', {@keep, fig_h});
    ud.keepBtn.Layout.Row = 7;
    ud.excludeBtn = uibutton(btnLayout, 'Text', 'Exclude', 'Enable', 'off', 'ButtonPushedFcn', {@exclude, fig_h});
    plusBtn = uibutton(btnLayout, 'Text', '+');
    plusBtn.Layout.Row = 10;
    minusBtn = uibutton(btnLayout, 'Text', '-');
    
    ud.MapPanel = uipanel(horzLayout, 'BorderType', 'none', 'Visible', 'off');
    ud.MapPanel.Layout.Row = 2;
    ud.MapAxes = axes(ud.MapPanel, 'Position', [0 0 .9 .8]);
    
    ud.chanlocs = SelectedEEG(1).chanlocs;
    ud.MSMaps = [];
    ud.nClasses = nClasses;
    ud.nChan = SelectedEEG(1).nbchan;
    % Extract microstate maps of the specified solution from all selected sets
    for i=1:numel(SelectedSets)
        if SelectedEEG(i).nbchan ~= ud.nChan
            errordlg2('Number of channels differs between selected datasets', 'Outlier detection error');
            return;
        end
        ud.MSMaps = [ud.MSMaps SelectedEEG(i).msinfo.MSMaps(ud.nClasses)];
    end
    
    fig_h.UserData = ud;
    
    mapChanged(ud.selMap, [], fig_h);
end

function updatePlot(fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;
    mapLabel = ud.selMap.Items{mapCol-1};

    % Get data from the sets that have not been excluded yet and sets that
    % have been marked to keep for the currently selected map
    setIdx = find(~strcmp(ud.setsTable.Data(:,mapCol), "Exclude"));     % set indices to plot   
    keepIdx = strcmp(ud.setsTable.Data(setIdx,mapCol), "Keep");         % set indices to plot in green
    
    data = nan(numel(setIdx), ud.nChan);
    for i=1:numel(setIdx)
        mapIdx = find(strcmp(ud.MSMaps(setIdx(i)).Labels, mapLabel));
        data(i,:) = ud.MSMaps(setIdx(i)).Maps(mapIdx, :);
    end
    
    Centering = eye(size(data,1)) - 1/size(data,1);
    data = Centering*data;
    cov = data*data';
    [v,d] = eigs(cov,2);
    ud.points = v;

    cla(ud.outlierPlot);
    % Plot unexamined sets in black and sets marked to keep in green
    hold(ud.outlierPlot, 'on');
    plot(ud.outlierPlot, v(~keepIdx,1), v(~keepIdx,2), '+k');
    plot(ud.outlierPlot, v(keepIdx,1), v(keepIdx,2), '+g');
    hold(ud.outlierPlot, 'off');

    ud.max = max(abs(v)*1.1, [], 'all');
    axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
    axis(ud.outlierPlot, 'square');
    ud.outlierPlot.XAxisLocation = 'origin';
    ud.outlierPlot.YAxisLocation = 'origin';

    % Store original points before anything is excluded
    if size(ud.points,1) == size(ud.MSMaps,2)
        ud.ur_points(mapCol-1,:,:) = ud.points;
    end
    
    fig_h.UserData = ud;
end

function  manualSelectNext(src, event, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;
    mapLabel = ud.selMap.Items{mapCol-1};

    set(0, 'CurrentFigure', fig_h);
    [x,y] = ginput(1);

    coords(:,1) = ud.points(:,1) - x;
    coords(:,2) = ud.points(:,2) - y;
    [~, idx] = min(sum(coords.^2, 2));

    setIdx = find(~strcmp(ud.setsTable.Data(:,mapCol), "Exclude"));     % set indices to plot   
    keepIdx = strcmp(ud.setsTable.Data(setIdx,mapCol), "Keep");         % set indices to plot in green
    ud.ToExclude = setIdx(idx);

    % Update plot
    cla(ud.outlierPlot);
    hold(ud.outlierPlot, 'on')
    plot(ud.outlierPlot, ud.points(~keepIdx,1), ud.points(~keepIdx,2), '+k');
    plot(ud.outlierPlot, ud.points(keepIdx,1), ud.points(keepIdx,2), '+g');
    axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
    axis(ud.outlierPlot, 'square');
    ud.outlierPlot.XAxisLocation = 'origin';
    ud.outlierPlot.YAxisLocation = 'origin';
    
    if strcmp(ud.setsTable.Data(setIdx(idx),mapCol), "Keep")
        color = 'g';
    else
        color = 'r';
    end
    plot(ud.outlierPlot, ud.points(idx,1), ud.points(idx,2), 'or', 'MarkerFaceColor', color);
    hold(ud.outlierPlot, 'off')

    % Update buttons
    if ~strcmp(ud.setsTable.Data(setIdx(idx),mapCol), "Keep")
        ud.keepBtn.Enable = 'on';
    else
        ud.keepBtn.Enable = 'off';
    end
    ud.excludeBtn.Enable = 'on';

    % Select set in table
    ud.setsTable.Selection = [setIdx(idx) mapCol];
    scroll(ud.setsTable, 'row', setIdx(idx));

    % Plot map of selected set    
    mapIdx = find(strcmp(ud.MSMaps(setIdx(idx)).Labels, mapLabel));
    X = cell2mat({ud.chanlocs.X});
    Y = cell2mat({ud.chanlocs.Y});
    Z = cell2mat({ud.chanlocs.Z});
    Background = ud.MSMaps(setIdx(idx)).ColorMap(mapIdx,:);
    dspCMap3(ud.MapAxes, double(ud.MSMaps(setIdx(idx)).Maps(mapIdx,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
    title(ud.MapAxes, ud.MSMaps(setIdx(idx)).Labels{mapIdx},'FontSize', 9, 'Interpreter','none');
    ud.MapAxes.Position = [0 0 .9 .9];
    ud.MapPanel.Visible = 'on';

    fig_h.UserData = ud;
end

function autoSelectNext(src, event, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;
    mapLabel = ud.selMap.Items{mapCol-1};

    pval = str2double(ud.pEdit.Value);
    % Only consider Mahalanobis distances for unexamined sets (not marked
    % to keep or exclude)
    setIdx = find(~strcmp(ud.setsTable.Data(:,mapCol), "Exclude"));     % set indices to plot   
    keepIdx = strcmp(ud.setsTable.Data(setIdx,mapCol), "Keep");         % set indices to plot in green
    points = ud.points(~keepIdx, :);
    dist = mahal(points, points);

    % But include sets marked to keep in ACR computation
    n = numel(setIdx);
    critDist = ACR(2, n, pval);
    [maxDist, idx] = max(dist);

    setIdx = setIdx(~keepIdx);
    ud.ToExclude = setIdx(idx);

    if maxDist > critDist
        % Update plot
        cla(ud.outlierPlot);
        hold(ud.outlierPlot, 'on')
        plot(ud.outlierPlot, ud.points(~keepIdx,1), ud.points(~keepIdx,2), '+k');
        plot(ud.outlierPlot, ud.points(keepIdx,1), ud.points(keepIdx,2), '+g');
        axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
        axis(ud.outlierPlot, 'square');
        ud.outlierPlot.XAxisLocation = 'origin';
        ud.outlierPlot.YAxisLocation = 'origin';
                    
        plot(ud.outlierPlot, points(idx,1), points(idx,2), 'or', 'MarkerFaceColor', 'r');
        hold(ud.outlierPlot, 'off')

        % Update buttons
        ud.keepBtn.Enable = 'on';
        ud.excludeBtn.Enable = 'on';

        % Select set in table
        ud.setsTable.Selection = [setIdx(idx) mapCol];
        scroll(ud.setsTable, 'row', setIdx(idx));

        % Plot map of selected set    
        mapIdx = find(strcmp(ud.MSMaps(setIdx(idx)).Labels, mapLabel));
        X = cell2mat({ud.chanlocs.X});
        Y = cell2mat({ud.chanlocs.Y});
        Z = cell2mat({ud.chanlocs.Z});
        Background = ud.MSMaps(setIdx(idx)).ColorMap(mapIdx,:);
        dspCMap3(ud.MapAxes, double(ud.MSMaps(setIdx(idx)).Maps(mapIdx,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
        title(ud.MapAxes, ud.MSMaps(setIdx(idx)).Labels{mapIdx},'FontSize', 9, 'Interpreter','none');
        ud.MapAxes.Position = [0 0 .9 .9];
        ud.MapPanel.Visible = 'on';

        fig_h.UserData = ud;
    else
        msgbox('No (further) outliers detected.');
    end
end

function autoSelectNextFMCD(src, event, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;
    mapLabel = ud.selMap.Items{mapCol-1};

    pval = str2double(ud.pEdit.Value);
    [~,p] = size(ud.points); % p = dims

    % Pre-calculate indices for plotting
    excludeIdx = strcmp(ud.setsTable.Data(:,mapCol), "Exclude");
    keepIdx = strcmp(ud.setsTable.Data(:,mapCol), "Keep");
    setIdx = find(~excludeIdx);  % sets indices to plot
    plotKeepIdx = strcmp(ud.setsTable.Data(setIdx,mapCol), "Keep");      % set indices to plot in green
    
    % Consider Mahalanobis distances of all points
    points = squeeze(ud.ur_points(mapCol-1,:,:));

    % Calculate robust Mahalanobis distance using Fast-MCD
    [~, ~, dist] = robustcov(points, "Method", "fmcd", "OutlierFraction", 0.25);

    % Calculate critical distance and compare with furthest point that has
    % not been marked to keep or exclude
    critDist = sqrt(chi2inv(1 - pval, p));
    maxDist = 0;
    maxIdx = 0;
    for idx = 1:numel(dist)
        if dist(idx) > maxDist && ~excludeIdx(idx) && ~keepIdx(idx)
            maxDist = dist(idx);
            maxIdx = idx;
        end
    end

    if maxDist > critDist
        ud.ToExclude = maxIdx;

        % Update plot
        cla(ud.outlierPlot);
        hold(ud.outlierPlot, 'on')
        plot(ud.outlierPlot, ud.points(~plotKeepIdx,1), ud.points(~plotKeepIdx,2), '+k');
        plot(ud.outlierPlot, ud.points(plotKeepIdx,1), ud.points(plotKeepIdx,2), '+g');
        axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
        axis(ud.outlierPlot, 'square');
        ud.outlierPlot.XAxisLocation = 'origin';
        ud.outlierPlot.YAxisLocation = 'origin';
                    
        plot(ud.outlierPlot, ud.points(find(setIdx==maxIdx),1), ud.points(find(setIdx==maxIdx),2), 'or', 'MarkerFaceColor', 'r');
        hold(ud.outlierPlot, 'off')

        % Update buttons
        ud.keepBtn.Enable = 'on';
        ud.excludeBtn.Enable = 'on';

        % Select set in table
        ud.setsTable.Selection = [maxIdx mapCol];
        scroll(ud.setsTable, 'row', maxIdx);

        % Plot map of selected set    
        mapIdx = find(strcmp(ud.MSMaps(maxIdx).Labels, mapLabel));
        X = cell2mat({ud.chanlocs.X});
        Y = cell2mat({ud.chanlocs.Y});
        Z = cell2mat({ud.chanlocs.Z});
        Background = ud.MSMaps(maxIdx).ColorMap(mapIdx,:);
        dspCMap3(ud.MapAxes, double(ud.MSMaps(maxIdx).Maps(mapIdx,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
        title(ud.MapAxes, ud.MSMaps(maxIdx).Labels{mapIdx},'FontSize', 9, 'Interpreter','none');
        ud.MapAxes.Position = [0 0 .9 .9];
        ud.MapPanel.Visible = 'on';

        fig_h.UserData = ud;
    else
        msgbox('No (further) outliers detected.');
    end
end

function autoSelectAllFMCD(src, event, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    pval = str2double(ud.pEdit.Value);
    [~,p] = size(ud.points); % p = dims

    % Consider Mahalanobis distances of all points
    excludeIdx = strcmp(ud.setsTable.Data(:,mapCol), "Exclude");
    keepIdx = strcmp(ud.setsTable.Data(:,mapCol), "Keep");
    points = squeeze(ud.ur_points(mapCol-1,:,:));

    % Calculate robust Mahalanobis distance using Fast-MCD
    [~, ~, dist] = robustcov(points, "Method", "fmcd", "OutlierFraction", 0.25);

    % Calculate critical distance and compare with all points
    outliers = dist > sqrt(chi2inv(1 - pval, p));

    for idx = 1:numel(outliers)
        if outliers(idx) && ~excludeIdx(idx) && ~keepIdx(idx)
            % Outlier detected
            ud.ToExclude = idx;
            fig_h.UserData = ud;
            highlight(src, event, fig_h);
            ud = fig_h.UserData;
        end
    end

    fig_h.UserData = ud;
end


function cellChanged(tbl, event, fig_h)
    if strcmp(event.EditData, 'Keep')
        tblStyle = uistyle('BackgroundColor', [.77 .96 .79]);            
    elseif strcmp(event.EditData, 'Exclude')
        tblStyle = uistyle('BackgroundColor', [.97 .46 .46]);
    elseif strcmp(event.EditData, 'Highlight')
        tblStyle = uistyle('BackgroundColor', [.99 .99 .59]);
    end
    addStyle(tbl, tblStyle, 'cell', event.Indices);

    % Update the plot
    updatePlot(fig_h);
    ud = fig_h.UserData;

    % Update buttons
    if strcmp(event.EditData, 'Keep')
        ud.keepBtn.Enable = 'off';
        ud.excludeBtn.Enable = 'on';
    else
        ud.keepBtn.Enable = 'on';
        ud.excludeBtn.Enable = 'off';        
    end

    % Highlight set if it is marked to keep
    if strcmp(event.EditData, 'Keep')
        mapCol = ud.selMap.Value;
        setIdx = find(~strcmp(ud.setsTable.Data(:,mapCol), "Exclude"));     % set indices to plot   
        plotIdx = find(setIdx == event.Indices(1));
        hold(ud.outlierPlot, 'on');
        plot(ud.outlierPlot, ud.points(plotIdx,1), ud.points(plotIdx,2), 'or', 'MarkerFaceColor', 'g');
        hold(ud.outlierPlot, 'off');
    end
end

function selectionChanged(tbl, event, fig_h)
    ud = fig_h.UserData;

    if event.Selection(2) ~= ud.selMap.Value && event.Selection(2) ~= 1
        tbl.Selection = event.PreviousSelection;
        return;
    end

    mapCol = ud.selMap.Value;
    mapLabel = ud.selMap.Items{mapCol-1};

    setIdx = find(~strcmp(ud.setsTable.Data(:,mapCol), "Exclude"));     % set indices to plot   
    keepIdx = strcmp(ud.setsTable.Data(setIdx,mapCol), "Keep");         % set indices to plot in green
    idx = event.Selection(1);    
    plotIdx = find(setIdx == idx);

    ud.ToExclude = idx;

    % Update plot
    cla(ud.outlierPlot);
    hold(ud.outlierPlot, 'on')
    plot(ud.outlierPlot, ud.points(~keepIdx,1), ud.points(~keepIdx,2), '+k');
    plot(ud.outlierPlot, ud.points(keepIdx,1), ud.points(keepIdx,2), '+g');
    axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
    axis(ud.outlierPlot, 'square');
    ud.outlierPlot.XAxisLocation = 'origin';
    ud.outlierPlot.YAxisLocation = 'origin';

    % Highlight set marker if set is not already excluded
    if ~isempty(plotIdx)
        if strcmp(ud.setsTable.Data(idx,mapCol), "Keep")
            color = 'g';
        else
            color = 'r';
        end
        plot(ud.outlierPlot, ud.points(plotIdx,1), ud.points(plotIdx,2), 'or', 'MarkerFaceColor', color);
        hold(ud.outlierPlot, 'off')
    end

    % Update buttons
    if ~strcmp(ud.setsTable.Data(idx,2), "Keep")
        ud.keepBtn.Enable = 'on';
    else
        ud.keepBtn.Enable = 'off';
    end

    if ~strcmp(ud.setsTable.Data(idx,2), "Exclude")
        ud.excludeBtn.Enable = 'on';
    else
        ud.excludeBtn.Enable = 'off';
    end

    % Plot map of selected set    
    mapIdx = find(strcmp(ud.MSMaps(setIdx(idx)).Labels, mapLabel));
    X = cell2mat({ud.chanlocs.X});
    Y = cell2mat({ud.chanlocs.Y});
    Z = cell2mat({ud.chanlocs.Z});
    Background = ud.MSMaps(setIdx(idx)).ColorMap(mapIdx,:);
    dspCMap3(ud.MapAxes, double(ud.MSMaps(setIdx(idx)).Maps(mapIdx,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
    title(ud.MapAxes, ud.MSMaps(setIdx(idx)).Labels{mapIdx},'FontSize', 9, 'Interpreter','none');
    ud.MapAxes.Position = [0 0 .9 .9];
    ud.MapPanel.Visible = 'on';

    fig_h.UserData = ud;
end

function exclude(src, event, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    % Update table
    ud.setsTable.Data(ud.ToExclude, mapCol) = 'Exclude';
    tblStyle = uistyle('BackgroundColor', [.97 .46 .46]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.ToExclude mapCol]);

    % Update buttons
    ud.keepBtn.Enable = 'on';
    ud.excludeBtn.Enable = 'off';

    fig_h.UserData = ud;

    % Update plot
    updatePlot(fig_h);
end

function keep(src, event, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    % Update table
    ud.setsTable.Data(ud.ToExclude, mapCol) = 'Keep';
    tblStyle = uistyle('BackgroundColor', [.77 .96 .79]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.ToExclude mapCol]);

    % Update buttons   
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'on';

    fig_h.UserData = ud;

    % Update plot
    updatePlot(fig_h);
    ud = fig_h.UserData;

    % Highlight set
    setIdx = find(~strcmp(ud.setsTable.Data(:,mapCol), "Exclude"));     % set indices to plot   
    plotIdx = find(setIdx == ud.ToExclude);
    hold(ud.outlierPlot, 'on');
    plot(ud.outlierPlot, ud.points(plotIdx,1), ud.points(plotIdx,2), 'or', 'MarkerFaceColor', 'g');
    hold(ud.outlierPlot, 'off');
end

function highlight(src, event, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    % Update table
    ud.setsTable.Data(ud.ToExclude, mapCol) = 'Highlight';
    tblStyle = uistyle('BackgroundColor', [.99 .99 .59]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.ToExclude mapCol]);

    % Update buttons   
    ud.keepBtn.Enable = 'on';
    ud.excludeBtn.Enable = 'on';

    fig_h.UserData = ud;
end

function mapChanged(src, event, fig_h)
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
    keepIdx = find(strcmp(ud.setsTable.Data(:, mapCol), "Keep"));
    addStyle(ud.setsTable, keepStyle, 'cell', [keepIdx repmat(mapCol, numel(keepIdx), 1)]);
    excludeIdx = find(strcmp(ud.setsTable.Data(:, mapCol), "Exclude"));
    addStyle(ud.setsTable, excludeStyle, 'cell', [excludeIdx repmat(mapCol, numel(excludeIdx), 1)]);

    % Make only the column of the currently selected map editable
    editable = false(1, numel(src.Items)+1);
    editable(mapCol) = true;
    ud.setsTable.ColumnEditable = editable;

    scroll(ud.setsTable, 'column', mapCol);
    ud.MapPanel.Visible = 'off';
    ud.setsTable.Selection = [];

    updatePlot(fig_h);
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
