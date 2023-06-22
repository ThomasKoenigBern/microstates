% pop_DetectOutliers() Perform outlier detection to find atypical
% topographies within individual datasets.
%
% Usage:
%   >> [EEG, CURRENTSET] = pop_DetectOutliers(ALLEEG, SelectedSets,
%       'Classes', Classes)
%
% Graphical interface:
%
%   "Choose sets for outlier detection"
%   -> Select sets to include in outlier detection procedure
%   -> Command line equivalent: "SelectedSets"
%
%   "Select number of classes for outlier detection"
%   -> Select which cluster solution to examine for outliers. Only one
%   cluster solution can be selected for outlier detection at a time.
%   -> Command line equivalent: "Classes"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG to include in outlier detection. If  
%   not provided, a GUI will appear to choose sets.
%
%   "Classes" (optional)
%   -> Integer indicating which cluster solution to examine for outliers
%   across selected datasets. If not provided, a GUI will appear to choose
%   a cluster solution.
%
% Outputs:
%
%   "EEG" 
%   -> EEG structure array, with microstate information removed from sets
%   selected to exclude within the interactive window.
%
%   "CURRENTSET"
%   -> The indices of the EEGs included in outlier detection
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

function [EEGout, CurrentSet, com] = pop_DetectOutliers(AllEEG, varargin)
    
    com = '';
    global CURRENTSET;
    global MSTEMPLATE;
    EEGout = [];
    CurrentSet = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_DetectOutliers';
    
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
    isPublished = arrayfun(@(x) isPublishedSet(AllEEG(x), {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasChildren & ~HasDyn & ~isPublished);
    
    if isempty(AvailableSets)
        errorMessage = ['No valid sets found for outlier detection. Use ' ...
            '"Tools->Identify microstate maps per dataset" to find and store microstate map data.'];
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Outlier detection error');
            return;
        else
            error(errorMessage);
        end
    end

    % Validate selected sets
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets);
        if numel(SelectedSets) < 2
            error('You must select at least two datasets');
        end
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following sets cannot be included in outlier detection: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, dynamics sets, ' ...
                'or sets without microstate maps.']);
        end
    % Otherwise, prompt user to select sets
    else
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res, ~, ~, outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', { ...
            { 'Style', 'text'    , 'string', 'Choose sets for outlier detection', 'fontweight', 'bold'} ...
            { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
            { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
            'title', 'Outlier detection');
        
        if isempty(res);    return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 2
            errordlg2('You must select at least two datasets.','Outlier detection error');
            return;
        end
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
        if matches('SelectedSets', p.UsingDefaults)
            errordlg2(errorMessage, 'Outlier detection error');
            return;
        else
            error(errorMessage);
        end
    end
    if matches('Classes', p.UsingDefaults)
        classRange = MinClasses:MaxClasses;
        classChoices = sprintf('%i Classes|', classRange);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select number of classes for outlier detection'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 1, 'Tag', 'Classes'}}, ...
              'title', 'Outlier detection');
        
        if isempty(res); return; end

        nClasses = classRange(outstruct.Classes);
    else
        if (nClasses < MinClasses) || (nClasses > MaxClasses)
            error('The specified number of classes %i is invalid. Valid class numbers are in the range %i-%i.', ...
                nClasses, MinClasses, MaxClasses);
        end
    end

    %% Check for consistent sorting across sets
    setnames = {SelectedEEG.setname};
    isEmpty = cellfun(@isempty,setnames);
    if any(isEmpty)
        setnames{isEmpty} = '';
    end

    % First check if any datasets remain unsorted
    SortModes = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).SortMode, 1:numel(SelectedEEG), 'UniformOutput', false);
    if matches('none', SortModes)
        unsortedSets = setnames(strcmp(SortModes, 'none'));
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(sprintf('The %i cluster solutions of the following sets remain unsorted. Please sort all sets before proceeding.', nClasses), ...
                'Outlier detection error', unsortedSets);
            return;
        else
            unsortedSetsTxt = sprintf(['%s' newline], string(unsortedSets));
            error(['The %i cluster solutions of the following sets remain unsorted: ' newline unsortedSetsTxt ...
                    'Please sort all sets before proceeding.'], nClasses);
        end
    end

    % Check for unassigned labels
    Colors = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).ColorMap, 1:numel(SelectedEEG), 'UniformOutput', false);
    unlabeled = cellfun(@(x) any(arrayfun(@(y) all(x(y,:) == [.75 .75 .75]), 1:size(x,1))), Colors);
    if any(unlabeled)
        unsortedSets = setnames(unlabeled);
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(sprintf(['The %i cluster solutions of the following sets contain maps without assigned labels. ' ...
                'For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], nClasses), ...
                'Outlier detection error', unsortedSets);
            return;
        else
            unsortedSetsTxt = sprintf(['%s' newline], string(unsortedSets));
            error(['The %i cluster solutions of the following sets contain maps without assigned labels: ' newline unsortedSetsTxt ...
                'For all maps to be assigned a label, each cluster solution must either be manually assigned labels, ' ...
                'or sorted by a template solution with an equal or greater number of maps. Please sort maps accordingly before proceeding.'], nClasses);
        end
    end

    % Check for consistent labels 
    labels = arrayfun(@(x) SelectedEEG(x).msinfo.MSMaps(nClasses).Labels, 1:numel(SelectedEEG), 'UniformOutput', false);
    labels = vertcat(labels{:});
    if any(arrayfun(@(x) numel(unique(labels(:,x))), 1:size(labels,2)) > 1)
        errorMessage = ['Map labels are inconsistent across datasets. Please sort maps such that map labels are identical ' ...
            'across all datasets before proceeding.'];
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Outlier detection error');
            return;
        else
            error(errorMessage);
        end
    end

    EEGout = SelectedEEG;
    CurrentSet = SelectedSets;

    %% Create outlier detection GUI
    MapLabels = {labels{1,:}};

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

    fig_h = uifigure('Name', 'Outlier detection', 'Units', 'pixels', 'Position', figSize, ...
        'HandleVisibility', 'on', 'CloseRequestFcn', @figClose);
    
    if tblWidth > .4*figSize(3)
        tblWidth = floor(.4*figSize(3));        
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
    ud.editLabel.Text = 'p-value';
    ud.editLabel.Layout.Row = 2;
    ud.editLabel.Layout.Column = 5;
    ud.editBox = uieditfield(selectLayout);
    ud.editBox.Value = '0.05';
    ud.editBox.Layout.Row = 2;
    ud.editBox.Layout.Column = 6;
    
    ud.keepBtn = uibutton(selectLayout, 'Text', 'Keep', 'Enable', 'off', 'ButtonPushedFcn', {@keep, fig_h});
    ud.keepBtn.Layout.Row = 1;
    ud.keepBtn.Layout.Column = 8;
    ud.excludeBtn = uibutton(selectLayout, 'Text', 'Exclude', 'Enable', 'off', 'ButtonPushedFcn', {@exclude, fig_h});
    ud.excludeBtn.Layout.Row = 2;
    ud.excludeBtn.Layout.Column = 8;
    
    ud.outlierPlot = axes(axLayout);
    ud.outlierPlot.ButtonDownFcn = {@axisClicked, fig_h};
    
    ud.setnames = {SelectedEEG.setname};
    opts = {'Keep', 'Exclude'};
    tblData = [ud.setnames', repmat(" ", numel(SelectedSets), numel(MapLabels))];
    ud.setsTable = uitable(vertLayout, 'Data', tblData, 'RowName', [], 'RowStriping', 'off', 'ColumnWidth', ['auto' repmat({colWidth}, 1, numel(MapLabels))], ...
        'ColumnName', [{'Subject'}, MapLabels], 'ColumnFormat', [ {[]} repmat({opts}, 1, numel(MapLabels)) ], 'Fontweight', 'bold', ...
        'Multiselect', 'off', 'CellEditCallback', {@cellChanged, fig_h}, 'SelectionChangedFcn', {@selectionChanged, fig_h});
    
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
    
    % Store MDS coordinates for each map
    Centering = eye(numel(SelectedSets)) - 1/numel(SelectedSets);
    ud.points = nan(nClasses, numel(SelectedSets), 2);
    for c=1:nClasses
        Maps = double(cell2mat(arrayfun(@(x) ud.MSMaps(x).Maps(c,:), 1:numel(SelectedSets), 'UniformOutput', false)'));    
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

    uiwait();

    ud = fig_h.UserData;
    delete(fig_h);

    if ~isempty(ud.removeIdx)
        disp('Removing microstate map info from excluded sets...');
        for i=1:numel(ud.removeIdx)
            EEGout(ud.removeIdx(i)).msinfo = [];
        end
    end

    com = sprintf('[EEG CURRENTSET] = pop_DetectOutliers(ALLEEG, %s, ''Classes'', %i);', mat2str(SelectedSets), nClasses);

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

    cla(ud.outlierPlot);
    hold(ud.outlierPlot, 'on');

    % Plot MDS coordinates of all sets as points
    ud.scatter = scatter(ud.outlierPlot, ud.points(mapCol-1,:,1), ud.points(mapCol-1,:,2), 10, 'black', 'filled');  

    % Axis formatting
    axis(ud.outlierPlot, 'tight');
    axis(ud.outlierPlot, 'equal');        
    axis(ud.outlierPlot, 'square');
    ud.max = max(abs(ud.points(mapCol-1,:))*1.1, [], 'all');
    axis(ud.outlierPlot, [-ud.max ud.max -ud.max ud.max]);
    ud.outlierPlot.XAxisLocation = 'origin';
    ud.outlierPlot.YAxisLocation = 'origin';
    ud.outlierPlot.XAxis.Color = [.6 .6 .6];
    ud.outlierPlot.YAxis.Color = [.6 .6 .6];

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
    setIdx = find(~excludeIdx & ~keepIdx);

    pval = str2double(ud.editBox.Value);    

    % Only consider Mahalanobis distances for unexamined sets (not marked
    % to keep or exclude)        
    points = squeeze(ud.points(mapCol-1,~excludeIdx & ~keepIdx,:));
    dist = mahal(points, points);

    % But include sets marked to keep in ACR computation
    n = sum(~excludeIdx);
    critDist = ACR(2, n, pval);
    [maxDist, idx] = max(dist);

    if maxDist > critDist
        outliers = setIdx(idx);
    else
        outliers = [];
    end

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

    % Hide map and clear selection
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

    mapCol = ud.selMap.Value;

    x = ud.points(mapCol-1,ud.currentIdx,1);
    y = ud.points(mapCol-1,ud.currentIdx,2);

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

    % Hide map and clear selection
    ud.MapPanel.Visible = 'off';
    ud.setsTable.Selection = [];

    updatePlot(fig_h);
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
