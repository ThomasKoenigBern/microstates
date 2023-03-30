
function [AllEEG, EEGout, CurrentSet, com] = pop_DetectOutliers(AllEEG, varargin)
    
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
            { 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'} ...
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
    MinClasses = min(AllMinClasses);
    MaxClasses = max(AllMaxClasses);
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

    %% Create outlier detection GUI

    fig_h = uifigure('Name', 'Outlier detection', 'Units', 'normalized', ...
    'Position', [.2 .1 .6 .8], 'HandleVisibility', 'on');
    
    horzLayout = uigridlayout(fig_h, [2 1]);
    horzLayout.RowHeight = {'1x', 150};
    vertLayout = uigridlayout(horzLayout, [1 3]);
    vertLayout.ColumnWidth = {115, '1x', 200};
    vertLayout.Padding = [0 0 0 0];
    vertLayout.ColumnSpacing = 0;
    btnLayout = uigridlayout(vertLayout, [12 1]);
    btnLayout.Padding = [0 0 0 0];
    btnLayout.RowHeight = {'1x', 30, 30, 30, 30, 30, 30, 30, 30, 30, 30, '1x'};
    
    ud.outlierPlot = axes(vertLayout);
    axis(ud.outlierPlot, 'equal');
    axis(ud.outlierPlot, 'tight');
    axis(ud.outlierPlot, 'square');
    
    setnames = {SelectedEEG.setname};
    opts = {'Keep', 'Exclude'};
    ud.setsTable = uitable(vertLayout, 'Data', [setnames', repmat(" ", numel(SelectedSets), 1)], 'RowName', [], 'SelectionType', 'row', ...
        'ColumnName', {'Subject', 'Status'}, 'ColumnFormat', repmat({opts}, 1, numel(SelectedSets)), 'ColumnEditable', [false true], ...
        'Multiselect', 'off', 'CellEditCallback', {@cellChanged, fig_h}, 'SelectionChangedFcn', {@selectionChanged, fig_h});
    ud.setsTable.Layout.Column = 3;
    
    manualBtn = uibutton(btnLayout, 'Text', 'Manual select next', 'ButtonPushedFcn', {@manualSelectNext, fig_h});
    manualBtn.Layout.Row = 2;
    autoBtn = uibutton(btnLayout, 'Text', 'Auto select next', 'ButtonPushedFcn', {@autoSelectNext, fig_h});
    allBtn = uibutton(btnLayout, 'Text', 'Auto select all');
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
    
    ud.MapPanel = uipanel(horzLayout, 'BorderType', 'none');
    ud.MapPanel.Layout.Row = 2;
    
    % Add fields for plotting
    ud.Edit = false;
    ud.Scroll = false;
    ud.Visible = true;
    ud.chanlocs = SelectedEEG(1).chanlocs;
    ud.MSMaps = cell(1, numel(SelectedSets));
    
    ud.nClasses = nClasses;
    nChan = SelectedEEG(1).nbchan;
    ud.data = nan(numel(SelectedSets), ud.nClasses*nChan);
    % Extract concatenated microstate vectors from all selected sets
    for i=1:numel(SelectedSets)
        if SelectedEEG(i).nbchan ~= nChan
            errordlg2('Number of channels differs between selected datasets', 'Outlier detection error');
            return;
        end
    
        maps = SelectedEEG(i).msinfo.MSMaps(ud.nClasses).Maps;
        ud.data(i,:) = reshape(maps, [1 ud.nClasses*nChan]);   
    
        ud.MSMaps{i} = SelectedEEG(i).msinfo.MSMaps;
    end
    
    fig_h.UserData = ud;
    
    updatePlot(fig_h);

end

function cellChanged(src, event, fig_h)
    ud = fig_h.UserData;

    if strcmp(event.EditData, 'Keep')
        tblStyle = uistyle('BackgroundColor', [.77 .96 .79]);            
    else
        tblStyle = uistyle('BackgroundColor', [.97 .46 .46]);            
    end
    addStyle(src, tblStyle, 'cell', event.Indices);

    % If the set was not previously kept/excluded, update the plot
    if strcmp(event.PreviousData, " ")
        ud.setsTable.Data(event.Indices, 2) = event.EditData;
        fig_h.UserData = ud;
        updatePlot(fig_h);

        % Update buttons
        ud.keepBtn.Enable = 'off';
        ud.excludeBtn.Enable = 'off';

        % Hide maps
        ud.MapPanel.Visible = 'off';        
    end

    ud.setsTable.Selection = [];
end

function selectionChanged(src, event, fig_h)
    ud = fig_h.UserData;

    setIdx = find(strcmp(ud.setsTable.Data(:,2), " "));
    idx = event.Selection;    
    plotIdx = find(setIdx == idx);

    % Update plot if the selected set is not kept/excluded
    if ~isempty(plotIdx)
        cla(ud.outlierPlot);
        plot(ud.outlierPlot, ud.points(:,1), ud.points(:,2), '+k');
        axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
        axis(ud.outlierPlot, 'equal');
        axis(ud.outlierPlot, 'tight');
        axis(ud.outlierPlot, 'square');
    
        hold(ud.outlierPlot, 'on')
        plot(ud.outlierPlot, ud.points(plotIdx,1), ud.points(plotIdx,2), 'or', 'MarkerFaceColor', 'r');
        hold(ud.outlierPlot, 'off')
    end

    % Update buttons
    ud.keepBtn.Enable = 'on';
    ud.excludeBtn.Enable = 'on';

    % Plot microstate maps
    ud.MapPanel.Visible = 'on';
    ud.AllMaps = ud.MSMaps{idx};
    fig_h.UserData = ud;
    PlotMSMaps(fig_h, ud.nClasses);
end

function updatePlot(fig_h)
    ud = fig_h.UserData;

    % Get data from the sets that have not been kept/excluded yet    
    setIdx = strcmp(ud.setsTable.Data(:,2), " ");
    data = ud.data(setIdx,:);
    
    Centering = eye(size(data,1)) - 1/size(data,1);
    data = Centering*data;
    cov = data*data';
    [v,d] = eigs(cov,2);
    ud.points = v;

    cla(ud.outlierPlot);
    plot(ud.outlierPlot, v(:,1), v(:,2), '+k');

    ud.max = max(abs(v)*1.05, [], 'all');
    axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
    axis(ud.outlierPlot, 'equal');
    axis(ud.outlierPlot, 'tight');
    axis(ud.outlierPlot, 'square');

    fig_h.UserData = ud;
end

function  manualSelectNext(src, event, fig_h)
    ud = fig_h.UserData;

    set(0, 'CurrentFigure', fig_h);
    [x,y] = ginput(1);

    coords(:,1) = ud.points(:,1) - x;
    coords(:,2) = ud.points(:,2) - y;
    [~, idx] = min(sum(coords.^2, 2));

    setIdx = find(strcmp(ud.setsTable.Data(:,2), " "));
    ud.ToExclude = setIdx(idx);

    % Update plot
    cla(ud.outlierPlot);
    plot(ud.outlierPlot, ud.points(:,1), ud.points(:,2), '+k');
    axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
    axis(ud.outlierPlot, 'equal');
    axis(ud.outlierPlot, 'tight');
    axis(ud.outlierPlot, 'square');

    hold(ud.outlierPlot, 'on')
    plot(ud.outlierPlot, ud.points(idx,1), ud.points(idx,2), 'or', 'MarkerFaceColor', 'r');
    hold(ud.outlierPlot, 'off')

    % Update buttons
    ud.keepBtn.Enable = 'on';
    ud.excludeBtn.Enable = 'on';

    % Select set in table
    ud.setsTable.Selection = setIdx(idx);
    scroll(ud.setsTable, 'row', setIdx(idx));

    % Plot maps of selected set
    ud.MapPanel.Visible = 'on';
    ud.AllMaps = ud.MSMaps{setIdx(idx)};
    fig_h.UserData = ud;
    PlotMSMaps(fig_h, ud.nClasses);
end

function autoSelectNext(src, event, fig_h)
    ud = fig_h.UserData;

    pval = str2double(ud.pEdit.Value);
    setIdx = find(strcmp(ud.setsTable.Data(:,2), " "));
    dist = mahal(ud.points, ud.points);
    [n,p] = size(ud.points);
    critDist = ACR(p, n, pval);
    [maxDist, idx] = max(dist);

    ud.ToExclude = setIdx(idx);

    if maxDist > critDist
        % Update plot
        cla(ud.outlierPlot);
        plot(ud.outlierPlot, ud.points(:,1), ud.points(:,2), '+k');
        axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
        axis(ud.outlierPlot, 'equal');
        axis(ud.outlierPlot, 'tight');
        axis(ud.outlierPlot, 'square');
    
        hold(ud.outlierPlot, 'on')
        plot(ud.outlierPlot, ud.points(idx,1), ud.points(idx,2), 'or', 'MarkerFaceColor', 'r');
        hold(ud.outlierPlot, 'off')

        % Update buttons
        ud.keepBtn.Enable = 'on';
        ud.excludeBtn.Enable = 'on';

        % Select set in table
        ud.setsTable.Selection = setIdx(idx);
        scroll(ud.setsTable, 'row', setIdx(idx));

        % Plot maps of selected set
        ud.MapPanel.Visible = 'on';
        ud.AllMaps = ud.MSMaps{setIdx(idx)};
        fig_h.UserData = ud;
        PlotMSMaps(fig_h, ud.nClasses);
    else
        msgbox('No (further) outliers detected.');
    end
end

function exclude(src, event, fig_h)
    ud = fig_h.UserData;

    % Update table
    ud.setsTable.Data(ud.ToExclude, 2) = 'Exclude';
    tblStyle = uistyle('BackgroundColor', [.97 .46 .46]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.ToExclude 2]);
    ud.setsTable.Selection = [];

    % Update buttons
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'off';

    % Hide maps
    ud.MapPanel.Visible = 'off';

    fig_h.UserData = ud;

    % Update plot
    updatePlot(fig_h);
end

function keep(src, event, fig_h)
    ud = fig_h.UserData;

    % Update table
    ud.setsTable.Data(ud.ToExclude, 2) = 'Keep';
    tblStyle = uistyle('BackgroundColor', [.77 .96 .79]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.ToExclude 2]);
    ud.setsTable.Selection = [];

    % Update buttons
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'off';

    % Hide maps
    ud.MapPanel.Visible = 'off';

    fig_h.UserData = ud;

    % Update plot
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
