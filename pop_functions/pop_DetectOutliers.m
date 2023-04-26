
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
    if matches('Classes', p.UsingDefaults)
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
    'Position', [.15 .1 .7 .8], 'HandleVisibility', 'on');

    horzLayout = uigridlayout(fig_h, [2 1]);
    horzLayout.RowHeight = {'1x', 150};
    vertLayout = uigridlayout(horzLayout, [1 3]);
    vertLayout.ColumnWidth = {120, '1x', 450};
    vertLayout.ColumnSpacing = 0;
    vertLayout.Padding = [0 0 0 0];
    btnLayout = uigridlayout(vertLayout, [7 1]);
    btnLayout.Padding = [0 0 0 0];
    btnLayout.RowHeight = {'1.2x', 30, 30, 30, 30, 30, '1x'};
    
    axLayout = uigridlayout(vertLayout, [2 1]);
    axLayout.RowHeight = {70, '1x'};
    axLayout.Padding = [0 0 0 0];
    
    selectLayout = uigridlayout(axLayout, [2 4]);
    selectLayout.ColumnWidth = {'1x', 200, 200, '1x'};
    selectLayout.Padding = [0 0 0 0];
    
    procedureLabel = uilabel(selectLayout, 'Text', 'Select outlier detection procedure', 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    procedureLabel.Layout.Row = 1;
    procedureLabel.Layout.Column = 2;
    ud.selProcedure = uidropdown(selectLayout, 'Items', {'Bad channel detection', 'Bad topography detection'}, 'ItemsData', 1:2, 'ValueChangedFcn', {@procedureChanged, fig_h});
    ud.selProcedure.Layout.Row = 1;
    ud.selProcedure.Layout.Column = 3;
    
    selMapLabel = uilabel(selectLayout, 'Text', 'Select map', 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    selMapLabel.Layout.Row = 2;
    selMapLabel.Layout.Column = 2;
    MapLabels = unique(AllLabels);
    ud.selMap = uidropdown(selectLayout, 'Items', MapLabels, 'ItemsData', 2:numel(MapLabels)+1, 'ValueChangedFcn', {@mapChanged, fig_h});
    ud.selMap.Layout.Row = 2;
    ud.selMap.Layout.Column = 3;
    
    ud.outlierPlot = axes(axLayout);
    ud.outlierPlot.ButtonDownFcn = {@axisClicked, fig_h};
    
    ud.setnames = {SelectedEEG.setname};
    opts = {'Keep', 'Exclude'};
    % Find indices with missing maps and populate table data
    tblData = [ud.setnames', repmat(" ", numel(SelectedSets), numel(MapLabels))];
    ud.setsTable = uitable(vertLayout, 'Data', tblData, 'RowName', [], 'RowStriping', 'off', ...
        'ColumnName', [{'Subject'}, MapLabels], 'ColumnFormat', [ {[]} repmat({opts}, 1, numel(MapLabels)) ], 'Fontweight', 'bold', ...
        'Multiselect', 'off', 'CellEditCallback', {@cellChanged, fig_h}, 'SelectionChangedFcn', {@selectionChanged, fig_h});
    
    autoBtn = uibutton(btnLayout, 'Text', 'Auto select', 'ButtonPushedFcn', {@autoSelect, fig_h});
    autoBtn.Layout.Row = 2;
    editLayout = uigridlayout(btnLayout, [1 2]);
    editLayout.Padding = [0 0 0 0];
    editLayout.ColumnWidth = {75, '1x'};
    ud.editLabel = uilabel(editLayout, 'Text', 'No. of MADs');
    ud.editBox = uieditfield(editLayout, 'Value', '3');
    ud.keepBtn = uibutton(btnLayout, 'Text', 'Keep', 'Enable', 'off', 'ButtonPushedFcn', {@keep, fig_h});
    ud.keepBtn.Layout.Row = 5;
    ud.excludeBtn = uibutton(btnLayout, 'Text', 'Exclude', 'Enable', 'off', 'ButtonPushedFcn', {@exclude, fig_h});
    
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
    
    % Store RMSE values and MDS coordinates for each map
    ResidualEstimator = VA_MakeSplineResidualMatrix(SelectedEEG(1).chanlocs);
    Centering = eye(numel(SelectedSets)) - 1/numel(SelectedSets);
    ud.RMSE = nan(nClasses, numel(SelectedSets));
    ud.points = nan(nClasses, numel(SelectedSets), 2);
    for c=1:nClasses
        Maps = double(cell2mat(arrayfun(@(x) ud.MSMaps(x).Maps(c,:), 1:numel(SelectedSets), 'UniformOutput', false)'));
        Residual = ResidualEstimator*Maps';
        RMSE = sqrt(mean(Residual.^2, 1));
        ud.RMSE(c,:) = RMSE;
    
        data = Centering*Maps;
        cov = data*data';
        [v,d] = eigs(cov,2);
        ud.points(c,:,:) = v;
    end
    
    ud.currentIdx = [];
    ud.highlightPoints = [];
    ud.dataTip = [];
    
    fig_h.UserData = ud;
    
    mapChanged(ud.selMap, [], fig_h);

end

function updatePlot(fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    % Get indices of different set categories
    excludeIdx = strcmp(ud.setsTable.Data(:,mapCol), "Exclude");    % sets to plot in red
    keepIdx = strcmp(ud.setsTable.Data(:,mapCol), "Keep");          % sets to plot in green
    reviewIdx = strcmp(ud.setsTable.Data(:,mapCol), "Review");      % sets to plot in yellow

    cla(ud.outlierPlot);
    hold(ud.outlierPlot, 'on');

    if ud.selProcedure.Value == 1
        % Plot RMSE of all sets as a line plot
        plot(ud.outlierPlot, 1:size(ud.RMSE,2), ud.RMSE(mapCol-1,:), '-k');        

        % Plot RMSE of all sets as points
        ud.scatter = scatter(ud.outlierPlot, 1:size(ud.RMSE,2), ud.RMSE(mapCol-1,:), 10, 'black', 'filled');

        % Axis formatting
        axis(ud.outlierPlot, 'normal');        
        axis(ud.outlierPlot, 'padded');
        ud.outlierPlot.XAxisLocation = 'bottom';
        ud.outlierPlot.YAxisLocation = 'left';
        ud.outlierPlot.XAxis.Color = [0 0 0];
        ud.outlierPlot.YAxis.Color = [0 0 0];
    else                               
        % Plot MDS coordinates of all sets as points
        ud.scatter = scatter(ud.outlierPlot, ud.points(mapCol-1,:,1), ud.points(mapCol-1,:,2), 10, 'black', 'filled');  
    
        % Axis formatting
        axis(ud.outlierPlot, 'equal');
        axis(ud.outlierPlot, 'square');
        ud.max = max(abs(ud.points)*1.1, [], 'all');
        axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
        ud.outlierPlot.XAxisLocation = 'origin';
        ud.outlierPlot.YAxisLocation = 'origin';
        ud.outlierPlot.XAxis.Color = [.6 .6 .6];
        ud.outlierPlot.YAxis.Color = [.6 .6 .6];
    end

    hold(ud.outlierPlot, 'off');    

    ud.scatter.SizeData = repmat(10, size(ud.points,2), 1);
    ud.scatter.CData = repmat([0 0 0], size(ud.points,2), 1);    
    % Highlight categorized sets    
    ud.scatter.SizeData(excludeIdx | keepIdx | reviewIdx) = 25;
    if any(excludeIdx); ud.scatter.CData(excludeIdx,:) = repmat([1 0 0], sum(excludeIdx), 1);           end
    if any(keepIdx);    ud.scatter.CData(keepIdx, :) = repmat([0 1 0], sum(keepIdx), 1);                end
    if any(reviewIdx);  ud.scatter.CData(reviewIdx, :) = repmat([.929 .694 .125], sum(reviewIdx), 1);   end

    ud.scatter.ButtonDownFcn = {@axisClicked, fig_h};
    row = dataTipTextRow('Subject', ud.setnames);
    ud.scatter.DataTipTemplate.DataTipRows = row;
    ud.scatter.DataTipTemplate.Interpreter = 'none';

    % Disable buttons
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'off';
    
    fig_h.UserData = ud;
end

function axisClicked(~, event, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;
    
    % Get the coordinates of where the user clicked
    x = event.IntersectionPoint(1);
    y = event.IntersectionPoint(2);

    if ud.selProcedure.Value == 1
        coords(:,1) = (1:size(ud.RMSE,2))' - x;
        coords(:,2) = ud.RMSE(mapCol-1,:)' - y;
    else
        coords(:,1) = ud.points(mapCol-1,:,1) - x;
        coords(:,2) = ud.points(mapCol-1,:,2) - y;
    end

    coords = L2NormDim(coords,1);
    [~, ud.currentIdx] = min(sum(coords.^2, 2));

    fig_h.UserData = ud;

    highlightSets(fig_h);
end

function autoSelect(~, ~, fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    if ud.selProcedure.Value == 1
        scale = str2double(ud.editBox.Value);

        % Find median and median absolute deviation
        med = median(ud.RMSE(mapCol-1,:));
        MAD = mad(ud.RMSE(mapCol-1,:),1);

        % Calculate distance from median and determine outliers
        dist = (ud.RMSE(mapCol-1,:)-med)/MAD;
        outliers = dist > scale;
    else
        pval = str2double(ud.editBox.Value);    

        % Consider Mahalanobis distances of all points        
        points = squeeze(ud.points(mapCol-1,:,:));
    
        % Calculate robust Mahalanobis distance using Fast-MCD
        [~, ~, dist] = robustcov(points, "Method", "fmcd", "OutlierFraction", 0.25);
    
        % Calculate critical distance and compare with all points
        outliers = dist > sqrt(chi2inv(1 - pval, 2));
    end    

    if any(outliers)
        excludeIdx = strcmp(ud.setsTable.Data(:,mapCol), "Exclude");
        keepIdx = strcmp(ud.setsTable.Data(:,mapCol), "Keep");
        outlierIdx = find(outliers(:) & ~excludeIdx & ~keepIdx);

        % Change color of points corresponding to outlier sets to yellow
        % for review and show datatips
        ud.scatter.CData(outlierIdx,:) = repmat([.929 .694 .125], numel(outlierIdx), 1);
        ud.scatter.SizeData(outlierIdx) = 25;        

        % Update table to show outlier sets as "Review"
        ud.setsTable.Data(outlierIdx, mapCol) = "Review";
        tblStyle = uistyle('BackgroundColor', [.929 .694 .125]);
        addStyle(ud.setsTable, tblStyle, 'cell', [outlierIdx repmat(mapCol, numel(outlierIdx), 1)]);
    else
        msgbox('No outliers detected.');
    end

    % Disable buttons
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'off';

    % Hide map and clear selection
    ud.MapPanel.Visible = 'off';
    ud.setsTable.Selection = [];
    if ~isempty(ud.highlightPoints);    delete(ud.highlightPoints);   end
    if ~isempty(ud.dataTip);         delete(ud.dataTip);        end

    ud.currentIdx = outlierIdx;
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

    if event.Selection(2) ~= ud.selMap.Value && event.Selection(2) ~= 1
        tbl.Selection = event.PreviousSelection;
        return;
    end

    ud.currentIdx = event.Selection(1);
    fig_h.UserData = ud;
    highlightSets(fig_h);
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

    fig_h.UserData = ud;
end

function highlightSets(fig_h)
    ud = fig_h.UserData;

    mapCol = ud.selMap.Value;

    if ud.selProcedure.Value == 1
        x = ud.currentIdx;
        y = ud.RMSE(mapCol-1,ud.currentIdx);
    else
        x = ud.points(mapCol-1,ud.currentIdx,1);
        y = ud.points(mapCol-1,ud.currentIdx,2);
    end                  

    hold(ud.outlierPlot, 'on');
    if ~isempty(ud.dataTip);            delete(ud.dataTip);         end
    if ~isempty(ud.highlightPoints);    delete(ud.highlightPoints); end

    % Highlight the selected set(s)
    ud.highlightPoints = scatter(ud.outlierPlot, x, y, 80, [1 1 0], 'LineWidth', 2.5);
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
        X = cell2mat({ud.chanlocs.X});
        Y = cell2mat({ud.chanlocs.Y});
        Z = cell2mat({ud.chanlocs.Z});
        Background = ud.MSMaps(ud.currentIdx).ColorMap(mapCol-1,:);
        dspCMap3(ud.MapAxes, double(ud.MSMaps(ud.currentIdx).Maps(mapCol-1,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);
        title(ud.MapAxes, ud.MSMaps(ud.currentIdx).Labels{mapCol-1},'FontSize', 9, 'Interpreter','none');
        ud.MapAxes.Position = [0 0 .9 .9];
        ud.MapPanel.Visible = 'on';
     end        

    fig_h.UserData = ud;
end

function procedureChanged(src, event, fig_h)
    ud = fig_h.UserData;

    % Change threshold label and edit field
    if src.Value == 1
        ud.editLabel.Text = 'No. of MADs';
        ud.editBox.Value = '3';
    else
        ud.editLabel.Text = 'p value';
        ud.editBox.Value = '0.05';
    end

    % Hide map and clear selection
    ud.MapPanel.Visible = 'off';
    ud.setsTable.Selection = [];

    % Update plot
    updatePlot(fig_h);
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

    % Hide map and clear selection
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
