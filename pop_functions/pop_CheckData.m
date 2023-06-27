% pop_CheckData() Perform data quality evaluation to detect dirty clusters
% due to bad channels in the EEG data.
%
% Usage:
%   >> setsTable = pop_CheckData(ALLEEG, SelectedSets)
%
% Graphical interface:
%
%   "Choose sets for data quality check"
%   -> Select sets for data quality evaluation
%   -> Command line equivalent: "SelectedSets"
%
%   "Enter max number of classes to use for clustering"
%   -> Enter the maximum number of microstate classes you would like to use
%   in your analysis
%   -> Command line equivalent: "Classes"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG to evaluate for data quality. If not 
%   provided, a GUI will appear to choose sets.
%
%   "Classes" (optional)
%   -> Integer indicating the maximum number of classes to be identified in
%   your analysis. If not provided, a GUI will appear to enter the number
%   of classes.
%
% Outputs:
%
%   "setsTable" 
%   -> MATLAB table containing sets marked to Review, Keep, or Exclude as
%   selected in the interactive GUI.
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

function [setsTable, com] = pop_CheckData(AllEEG, varargin)

    com = '';
    setsTable = [];
    global MSTEMPLATE;

    guiElements = {};
    guiGeom = {};
    guiGeomV = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_CheckData';
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addOptional(p, 'Classes', 7, @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    nClasses = p.Results.Classes;

    %% SelectedSets validation
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    isPublished = arrayfun(@(x) isPublishedSet(AllEEG(x), {MSTEMPLATE.setname}), 1:numel(AllEEG));
    AvailableSets = find(~isEmpty & ~HasChildren & ~HasDyn & ~isPublished);
    if isempty(AvailableSets)
        if matches('SelectedSets', p.UsingDefaults)
            errorDlg2('No valid sets found for data quality check.', 'Data quality check error');
            return;
        else
            error('No valid sets found for data quality check.');
        end
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, mean sets, or dynamics sets.']);
        end
    % Otherwise, add set selection gui elements
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};

        guiElements = [guiElements ...
            {{ 'Style', 'text'    , 'string', 'Choose sets for data quality check', 'fontweight', 'bold'}} ...
            {{ 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'}} ...
            {{ 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}];
        guiGeom = [guiGeom 1 1 1];
        guiGeomV = [guiGeomV 1 1 4];        
    end

    %% Add class gui elements if not provided
    if matches('Classes', p.UsingDefaults)
        guiElements = [guiElements ...
            {{ 'Style', 'text', 'string', ''}} ...
            {{ 'Style', 'text', 'string', 'Enter max number of classes'}} ...
            {{ 'Style', 'edit', 'string', int2str(nClasses), 'tag', 'Classes'}}];
        guiGeom = [guiGeom 1 [1 1]];
        guiGeomV = [guiGeomV 1 1];
    end


    %% Prompt user for necessary parameters
    if ~isempty(guiElements)
        [res, ~, ~, outstruct] = inputgui('geometry', guiGeom, 'geomvert', guiGeomV, 'uilist', guiElements, ...
            'title', 'Data quality check');
        
        if isempty(res);    return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);
        nClasses = str2double(outstruct.Classes);
        
        if numel(SelectedSets) < 1
            errordlg2('You must select at least one dataset','Data quality check error');
            return;
        end
    end

    %% Cluster
    % Quick clustering parameters
    ClustPar.UseAAHC = 0;
    ClustPar.MinClasses = nClasses;
    ClustPar.MaxClasses = nClasses;
    ClustPar.Restarts = 5;
    ClustPar.MaxMaps = inf;
    ClustPar.GFPPeaks = 1;
    ClustPar.IgnorePolarity = 1;
    ClustPar.Normalize = 1;
%     SelectedEEG = pop_FindMSMaps(AllEEG, SelectedSets, 'ClustPar', ClustPar);
    SelectedEEG = AllEEG(SelectedSets);

    %% Compute residuals       
    classRMSE = zeros(numel(SelectedSets), nClasses);
    ud.MSMaps = [];
    for i=1:numel(SelectedSets)
        ExpVar = SelectedEEG(i).msinfo.MSMaps(nClasses).ExpVar;
        [ExpVar, sortOrder] = sort(ExpVar, 'descend');
        Maps = SelectedEEG(i).msinfo.MSMaps(nClasses).Maps(sortOrder,:);
        SelectedEEG(i).msinfo.MSMaps(nClasses).Maps = Maps;
        SelectedEEG(i).msinfo.MSMaps(nClasses).ExpVar = ExpVar;
        ud.MSMaps = [ud.MSMaps SelectedEEG(i).msinfo.MSMaps(nClasses)];

        ResidualEstimator = VA_MakeSplineResidualMatrix(SelectedEEG(i).chanlocs);
        Residual = ResidualEstimator*Maps';
        classRMSE(i,:) = sqrt(mean(Residual.^2, 1));        
    end
    maxRMSE = max(classRMSE, [], 2);

    %% Build GUI   
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
    if maxSubjWidth < 60;   maxSubjWidth = 60;  end
    if maxSubjWidth > 200;  maxSubjWidth = 200; end
    colWidth = 100;
    tblWidth = maxSubjWidth + colWidth;
    
    fig_h = uifigure('Name', 'Data quality check', 'Units', 'pixels', 'Position', figSize, ...
        'HandleVisibility', 'on', 'CloseRequestFcn', 'uiresume()');
    
    horzLayout = uigridlayout(fig_h, [2 1]);
    horzLayout.RowHeight = {'1x', 150};
    vertLayout = uigridlayout(horzLayout, [1 2]);
    vertLayout.ColumnWidth = {'1x', tblWidth};
    vertLayout.ColumnSpacing = 0;
    vertLayout.Padding = [0 0 0 0];
    
    axLayout = uigridlayout(vertLayout, [2 1]);
    axLayout.RowHeight = {110, '1x'};
    axLayout.Padding = [0 0 0 0];       
    
    selectLayout = uigridlayout(axLayout, [3 8]);
    selectLayout.ColumnWidth = {'1x', 65, 40, 40, 105, 40, 125, '1x'};
    selectLayout.Padding = [0 0 0 0];
    
    ud.outlierPlot = axes(axLayout);
    ud.outlierPlot.ButtonDownFcn = {@axisClicked, fig_h};
    
    autoBtn = uibutton(selectLayout, 'Text', 'Auto select', 'ButtonPushedFcn', {@autoSelect, fig_h});
    autoBtn.Layout.Row = 2;
    autoBtn.Layout.Column = [2 3];
    ud.editLabel = uilabel(selectLayout);
    ud.editLabel.Text = 'Threshold';
    ud.editLabel.Layout.Row = 3;
    ud.editLabel.Layout.Column = 2;
    ud.editBox = uieditfield(selectLayout);
    ud.editBox.Value = '0.04';
    ud.editBox.Layout.Row = 3;
    ud.editBox.Layout.Column = 3;
    
    ud.keepBtn = uibutton(selectLayout, 'Text', 'Keep', 'Enable', 'off', 'ButtonPushedFcn', {@keep, fig_h});
    ud.keepBtn.Layout.Row = 1;
    ud.keepBtn.Layout.Column = 5;
    ud.excludeBtn = uibutton(selectLayout, 'Text', 'Exclude', 'Enable', 'off', 'ButtonPushedFcn', {@exclude, fig_h});
    ud.excludeBtn.Layout.Row = 2;
    ud.excludeBtn.Layout.Column = 5;
    ud.clearBtn = uibutton(selectLayout, 'Text', 'Clear all', 'ButtonPushedFcn', {@clearAll, fig_h});
    ud.clearBtn.Layout.Row = 3;
    ud.clearBtn.Layout.Column = 5;
    
    ud.viewBtn = uibutton(selectLayout, 'Text', 'View RMSE values', 'ButtonPushedFcn', {@viewRMSE, fig_h});
    ud.viewBtn.Layout.Row = 1;
    ud.viewBtn.Layout.Column = 7;
    ud.exportRMSEBtn = uibutton(selectLayout, 'Text', 'Export RMSE values', 'ButtonPushedFcn', {@exportRMSE, fig_h});
    ud.exportRMSEBtn.Layout.Row = 2;
    ud.exportRMSEBtn.Layout.Column = 7;
    ud.exportTblBtn = uibutton(selectLayout, 'Text', 'Export table', 'ButtonPushedFcn', {@exportTable, fig_h});
    ud.exportTblBtn.Layout.Row = 3;
    ud.exportTblBtn.Layout.Column = 7;
    
    ud.setnames = {SelectedEEG.setname};
    opts = {'Keep', 'Exclude', 'Clear'};
    tblData = [ud.setnames', repmat(" ", numel(SelectedSets), 1)];
    ud.setsTable = uitable(vertLayout, 'Data', tblData, 'RowName', [], 'RowStriping', 'off', 'ColumnEditable', [false true], ...
        'ColumnName', {'Dataset', 'Status'}, 'ColumnFormat', {[], opts}, 'ColumnWidth', {maxSubjWidth colWidth}, 'Fontweight', 'bold', ...
        'Multiselect', 'off', 'CellEditCallback', {@cellChanged, fig_h}, 'SelectionChangedFcn', {@selectionChanged, fig_h});
    
    ud.MapPanel = uipanel(horzLayout, 'BorderType', 'none', 'Visible', 'off');
    ud.MapPanel.Layout.Row = 2;
    
    ud.chanlocs = SelectedEEG(1).chanlocs;
    
    ud.currentIdx = [];
    ud.highlightPoints = [];
    ud.dataTip = []; 
    ud.Filename = [];
    
    % Plot RMSE values
    hold(ud.outlierPlot, 'on');
    plot(ud.outlierPlot, 1:length(SelectedSets), maxRMSE, '-k');
    ud.scatter = scatter(ud.outlierPlot, 1:length(SelectedSets), maxRMSE, 10, 'black', 'filled');
    
    hold(ud.outlierPlot, 'off'); 
    
    % Axis formatting        
    xlabel(ud.outlierPlot, 'Datasets');
    ylabel(ud.outlierPlot, 'Maximum RMSE of Channel Residuals');
    axis(ud.outlierPlot, 'normal');     
    axis(ud.outlierPlot, 'padded');
    
    ud.scatter.SizeData = repmat(10, length(SelectedSets), 1);
    ud.scatter.CData = repmat([0 0 0], length(SelectedSets), 1);
    
    ud.scatter.ButtonDownFcn = {@axisClicked, fig_h};
    row = dataTipTextRow('Dataset:', ud.setnames);
    ud.scatter.DataTipTemplate.DataTipRows = row;
    ud.scatter.DataTipTemplate.Interpreter = 'none';
    
    fig_h.UserData = ud;

    uiwait();    
    setsTable = table(ud.setsTable.Data(:,1), ud.setsTable.Data(:,2), 'VariableNames', {'Dataset', 'Status'});
    delete(fig_h);

    com = sprintf('setsTable = pop_CheckData(%s, %s)', inputname(1), mat2str(SelectedSets));
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

    excludeIdx = strcmp(ud.setsTable.Data(:,2), "Exclude");
    keepIdx = strcmp(ud.setsTable.Data(:,2), "Keep");

    threshold = str2double(ud.editBox.Value);
    % Find all points higher than threshold
    outliers = ud.scatter.YData > threshold;
    outliers = find(outliers(:) & ~excludeIdx & ~keepIdx);

    if any(outliers)        
        % Change color of points corresponding to outlier sets to yellow
        % for review and show datatips
        ud.scatter.CData(outliers,:) = repmat([.929 .694 .125], numel(outliers), 1);
        ud.scatter.SizeData(outliers) = 25;        

        % Update table to show outlier sets as "Review"
        ud.setsTable.Data(outliers, 2) = "Review";
        tblStyle = uistyle('BackgroundColor', [.929 .694 .125]);
        addStyle(ud.setsTable, tblStyle, 'cell', [outliers repmat(2, numel(outliers), 1)]);
    else
        msgbox('No dirty datasets detected.');
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
        case 'Clear'
            clear([], [], fig_h);
    end
end

function selectionChanged(~, event, fig_h)
    ud = fig_h.UserData;

    ud.currentIdx = event.Selection(1);
    fig_h.UserData = ud;
    highlightSets(fig_h);
end

function exclude(~, ~, fig_h)
    ud = fig_h.UserData;

    % Update table
    ud.setsTable.Data(ud.currentIdx, 2) = 'Exclude';
    tblStyle = uistyle('BackgroundColor', [.97 .46 .46]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.currentIdx 2]);

    % Update buttons
    ud.keepBtn.Enable = 'on';
    ud.excludeBtn.Enable = 'off';

    % Update plot
    ud.scatter.CData(ud.currentIdx,:) = [1 0 0];
    ud.scatter.SizeData(ud.currentIdx) = 25;

    % Remove datatip
    delete(ud.dataTip);

    fig_h.UserData = ud;
end

function keep(~, ~, fig_h)
    ud = fig_h.UserData;

    % Update table
    ud.setsTable.Data(ud.currentIdx, 2) = 'Keep';
    tblStyle = uistyle('BackgroundColor', [.77 .96 .79]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.currentIdx 2]);

    % Update buttons   
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'on';

    % Update plot
    ud.scatter.CData(ud.currentIdx,:) = [0 1 0];
    ud.scatter.SizeData(ud.currentIdx) = 25;

    % Remove datatip
    delete(ud.dataTip);

    fig_h.UserData = ud;
end

function clear(~, ~, fig_h)
    ud = fig_h.UserData;

    % Update table
    ud.setsTable.Data(ud.currentIdx, 2) = " ";
    tblStyle = uistyle('BackgroundColor', [1 1 1]);
    addStyle(ud.setsTable, tblStyle, 'cell', [ud.currentIdx 2]);

    % Update buttons   
    ud.keepBtn.Enable = 'on';
    ud.excludeBtn.Enable = 'on';

    % Update plot
    ud.scatter.CData(ud.currentIdx,:) = [0 0 0];
    ud.scatter.SizeData(ud.currentIdx) = 10;

    fig_h.UserData = ud;
end

function clearAll(~, ~, fig_h)
    ud = fig_h.UserData;

    % Update table
    ud.setsTable.Data(:, 2) = " ";
    tblStyle = uistyle('BackgroundColor', [1 1 1]);
    addStyle(ud.setsTable, tblStyle, 'column', 2);
    
    % Update buttons   
    ud.keepBtn.Enable = 'off';
    ud.excludeBtn.Enable = 'off';

    % Update plot
    ud.scatter.CData(markedIdx,:) = repmat([0 0 0], numel(markedIdx), 1);
    ud.scatter.SizeData(markedIdx) = 10;

    % Hide maps and clear selection
    ud.MapPanel.Visible = 'off';
    ud.setsTable.Selection = [];
    if ~isempty(ud.highlightPoints);    delete(ud.highlightPoints);   end
    if ~isempty(ud.dataTip);            delete(ud.dataTip);           end

    fig_h.UserData = ud;
end

function viewRMSE(~, ~, fig_h)
    ud = fig_h.UserData;
    RMSEfig = uifigure('Name', 'Maximum RMSE of channel residuals');
    RMSEtable = uitable(RMSEfig, 'Unit','normalized','Position',[0.02 0.02 0.96 0.96]);
    RMSEtable.Data = table(ud.setsTable.Data(:,1), ud.scatter.YData', 'VariableNames', {'Dataset', 'Max RMSE'});
end

function exportRMSE(~, ~, fig_h)
    ud = fig_h.UserData;
    RMSEtable = table(ud.setsTable.Data(:,1), ud.scatter.YData', 'VariableNames', {'Dataset', 'Max RMSE'});
    
    [FName, PName, idx] = uiputfile({'*.csv', 'Comma separated file'; '*.txt', 'Tab delimited file'; '*.xlsx', 'Excel file'; '*.mat', 'Matlab Table'}, 'Save max RMSE values');
    if FName == 0
        return;
    end
    
    Filename = fullfile(PName, FName);
    if idx < 4
        writetable(RMSEtable, Filename);
    else
        save(Filename, 'RMSEtable');
    end

    ud.Filename = [ud.Filename {Filename}];
    fig_h.UserData = ud;
end

function exportTable(~, ~, fig_h)
    ud = fig_h.UserData;
    setsTable = table(ud.setsTable.Data(:,1), ud.setsTable.Data(:,2), 'VariableNames', {'Dataset', 'Status'});

    [FName, PName, idx] = uiputfile({'*.csv', 'Comma separated file'; '*.txt', 'Tab delimited file'; '*.xlsx', 'Excel file'; '*.mat', 'Matlab Table'}, 'Save annotations');
    if FName == 0
        return;
    end
    
    Filename = fullfile(PName, FName);
    if idx < 4
        writetable(setsTable, Filename);
    else
        save(Filename, 'setsTable');
    end
end

function highlightSets(fig_h)
    ud = fig_h.UserData;

    x = ud.currentIdx;
    y = ud.scatter.YData(ud.currentIdx);

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
        if strcmp(ud.setsTable.Data(ud.currentIdx,2), "Keep")
            ud.keepBtn.Enable = 'off';
            ud.excludeBtn.Enable = 'on';
        elseif strcmp(ud.setsTable.Data(ud.currentIdx,2), "Exclude")
            ud.keepBtn.Enable = 'on';
            ud.excludeBtn.Enable = 'off';
        else
            ud.keepBtn.Enable = 'on';
            ud.excludeBtn.Enable = 'on';
        end

        % Select set in table
        ud.setsTable.Selection = [ud.currentIdx 2];
        scroll(ud.setsTable, 'row', ud.currentIdx);
    
        % Plot maps of selected set    
        PlotMSMaps2(fig_h, ud.MapPanel, ud.MSMaps(ud.currentIdx), ud.chanlocs, ...
            'Background', 0, 'Label', 0, 'ShowExpVar', 1);
        ud.MapPanel.Visible = 'on';
     end        

    fig_h.UserData = ud;
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