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
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG to evaluate for data quality. If not 
%   provided, a GUI will appear to choose sets.
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

    [~,nogui] = eegplugin_microstatelab;

    if nogui == true
        error("This function needs a GUI to work");
    end

    com = '';
    setsTable = [];
    global MSTEMPLATE;

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_CheckData';
    
    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));

    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;

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
    % Otherwise, prompt user to select sets
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res, ~, ~, outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', {
                { 'Style', 'text'    , 'string', 'Choose sets for data quality check', 'fontweight', 'bold'} ...
                { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
                { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                'title', 'Data quality check');
        
        if isempty(res);    return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one dataset','Data quality check error');
            return;
        end
    end

    %% Cluster
    % Quick clustering parameters
    nClasses = 10;
    ClustPar.UseAAHC = 0;
    ClustPar.MinClasses = nClasses;
    ClustPar.MaxClasses = nClasses;
    ClustPar.Restarts = 5;
    ClustPar.MaxMaps = inf;
    ClustPar.GFPPeaks = 1;
    ClustPar.IgnorePolarity = 1;
    ClustPar.Normalize = 1;
    SelectedEEG = pop_FindMSMaps(AllEEG, SelectedSets, 'ClustPar', ClustPar);

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
    fig_h = uifigure('Name', 'Data quality check', 'HandleVisibility', 'on', ...
        'Units', 'normalized', 'Position', [.1 .1 .8 .8], 'CloseRequestFcn', 'uiresume()');

    horzLayout = uigridlayout(fig_h, [2 1]);
    horzLayout.RowHeight = {'1x', 150};
    vertLayout = uigridlayout(horzLayout, [1 2]);
    vertLayout.ColumnWidth = {'1x', 300};
    vertLayout.ColumnSpacing = 0;
    vertLayout.Padding = [0 0 0 0];
    
    axLayout = uigridlayout(vertLayout, [2 1]);
    axLayout.RowHeight = {70, '1x'};
    axLayout.Padding = [0 0 0 0];       

    selectLayout = uigridlayout(axLayout, [2 6]);
    selectLayout.ColumnWidth = {'1x', 65, 40, 40, 105, '1x'};
    selectLayout.Padding = [0 0 0 0];

    ud.outlierPlot = axes(axLayout);
    ud.outlierPlot.ButtonDownFcn = {@axisClicked, fig_h};

    autoBtn = uibutton(selectLayout, 'Text', 'Auto select', 'ButtonPushedFcn', {@autoSelect, fig_h});
    autoBtn.Layout.Row = 1;
    autoBtn.Layout.Column = [2 3];
    
    ud.editLabel = uilabel(selectLayout);
    ud.editLabel.Text = 'Threshold';
    ud.editLabel.Layout.Row = 2;
    ud.editLabel.Layout.Column = 2;
    ud.editBox = uieditfield(selectLayout);
    ud.editBox.Value = '0.04';
    ud.editBox.Layout.Row = 2;
    ud.editBox.Layout.Column = 3;
    
    ud.keepBtn = uibutton(selectLayout, 'Text', 'Keep', 'Enable', 'off', 'ButtonPushedFcn', {@keep, fig_h});
    ud.keepBtn.Layout.Row = 1;
    ud.keepBtn.Layout.Column = 5;
    ud.excludeBtn = uibutton(selectLayout, 'Text', 'Exclude', 'Enable', 'off', 'ButtonPushedFcn', {@exclude, fig_h});
    ud.excludeBtn.Layout.Row = 2;
    ud.excludeBtn.Layout.Column = 5;

    ud.setnames = {SelectedEEG.setname};
    opts = {'Keep', 'Exclude'};
    tblData = [ud.setnames', repmat(" ", numel(SelectedSets), 1)];
    ud.setsTable = uitable(vertLayout, 'Data', tblData, 'RowName', [], 'RowStriping', 'off', ...
        'ColumnName', {'Dataset', 'Status'}, 'ColumnFormat', {[], opts}, 'Fontweight', 'bold', ...
        'Multiselect', 'off', 'CellEditCallback', {@cellChanged, fig_h}, 'SelectionChangedFcn', {@selectionChanged, fig_h});
    
    ud.MapPanel = uipanel(horzLayout, 'BorderType', 'none', 'Visible', 'off');
    ud.MapPanel.Layout.Row = 2;
    
    ud.chanlocs = SelectedEEG(1).chanlocs;

    ud.currentIdx = [];
    ud.highlightPoints = [];
    ud.dataTip = []; 

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
    row = dataTipTextRow('Subject:', ud.setnames);
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