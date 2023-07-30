% pop_ShowIndMSMaps() - Display microstate maps, with the option to display
% only certain cluster solutions. If multiple sets are selected to plot,
% they will be plotted in separate tabs. To plot individual maps in their  
% own windows, right-click a map and select "Plot map in new window."
%
% Usage:
%   >> fig_h = pop_ShowIndMSMaps(ALLEEG, SelectedSets, 'Classes', Classes,
%           'Visible', true/false)
%
% The figure with plotted maps can be generated but not displayed.
% This option is useful if you would like to save microstate maps in a
% script but avoid each window appearing. To generate an invisible figure,
% set the "Visible" argument to 0.
% Ex:
%   >> fig_h = pop_ShowIndMSMaps(ALLEEG, 1, 'Classes', 4:7, 'Visible', 0)
%       saveas(fig_h, 'microstate_maps.png')
%       close(fig_h)
%
% Graphical interface:
%
%   "Choose sets for plotting"
%   -> Select sets to plot. If multiple sets are selected, a tab will be
%   opened for each.
%   -> Command line equivalent: "SelectedSets"
%
% Inputs:
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Vector of set indices of ALLEEG to plot. If multiple are chosen, a
%   tab will be opened for each.
%
% Key, Value inputs (optional):
%   "Classes"
%   -> Vector of class numbers indicating which cluster solutions to plot.
%   If class numbers are not provided, a GUI will appear to select the 
%   cluster solution(s) to plot.
%
%   "Visible"
%   -> 1 = Show GUI with plotted microstate maps, 0 = keep GUI hidden.
%   Useful for scripting purposes to generate and save figures from the
%   returned figure handle without the figures popping up.
%
% Outputs:
%
%   "fig_h"
%   -> Figure handle to window with plotted microstate maps. Useful
%   for scripting purposes to save figures.
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
function [fig_h, com] = pop_ShowIndMSMaps(AllEEG, varargin)

    [~,nogui] = eegplugin_microstatelab;

    if nogui == true
        error("This function needs a GUI");
    end

    %% Set defaults for outputs
    com = '';
    fig_h = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    p.FunctionName = 'pop_ShowIndMSMaps';
    p.StructExpand = false;

    addRequired(p, 'AllEEG',  @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));    
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector'}));
    addParameter(p, 'Visible', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    parse(p, AllEEG, varargin{:});

    AllEEG = p.Results.AllEEG;
    SelectedSets = p.Results.SelectedSets;
    Classes = p.Results.Classes;
    Visible = p.Results.Visible;

    %% SelectedSets validation
    % Make sure there are valid sets for editing/plotting
    HasMS = arrayfun(@(x) hasMicrostates(AllEEG(x)), 1:numel(AllEEG));
    HasDyn = arrayfun(@(x) isDynamicsSet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(HasMS & ~HasDyn);    
    if isempty(AvailableSets)
        errorMessage = ['No valid sets found for plotting. Use ' ...
            '"Tools->Identify microstate maps per dataset" to find and store microstate map data.'];
        if matches('SelectedSets', p.UsingDefaults)
            errorDialog(errorMessage, 'Plot microstate maps error');
            return;
        else
            error(errorMessage);
        end
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        % Check for empty sets, dynamics sets, or any sets without
        % microstate maps
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, dynamics sets, or sets ' ...
                'without microstate maps.']);
        end
    % Otherwise, prompt user to provide sets    
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        
        [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1], 'geomvert', [1 1 1 4], 'uilist', ...
            {{ 'Style', 'text'    , 'string', 'Choose sets for plotting', 'FontWeight', 'bold'} ...
            { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
            { 'Style', 'text'    , 'string', 'If multiple are chosen, a tab will be created for each'} ...
            { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
            'title', 'Plot microstate maps');

        if isempty(res);    return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one dataset','Plot microstate maps error');
            return;
        end
    end

    SelectedEEG = AllEEG(SelectedSets);

    % Prompt user to provide class range to display if necessary
    AllMinClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MinClasses, 1:numel(SelectedEEG));
    AllMaxClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MaxClasses, 1:numel(SelectedEEG));
    MinClasses = min(AllMinClasses);
    MaxClasses = max(AllMaxClasses);
    if matches('Classes', p.UsingDefaults)
        classRange = MinClasses:MaxClasses;
        classChoices = sprintf('%i Classes|', classRange);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select classes to display'} ...
              {'Style', 'text', 'string' 'Use ctrl or shift for multiple selection'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 2, 'Value', 1:numel(classRange), 'Tag', 'Classes'}}, ...
              'title', 'Plot microstate maps');
        
        if isempty(res); return; end

        Classes = classRange(outstruct.Classes);
    else
        if any(Classes < MinClasses) || any(Classes > MaxClasses)
            invalidClasses = Classes(or((Classes < MinClasses), (Classes > MaxClasses)));
            invalidClassesTxt = sprintf('%i, ', invalidClasses);
            invalidClassesTxt = invalidClassesTxt(1:end-2);
            error(['The following specified cluster solutions to plot are invalid: %s' ...
                '. Valid class numbers are in the range %i-%i.'], invalidClassesTxt, MinClasses, MaxClasses);
        end
    end        

    % Compute initial figure size and whether scrolling is needed
    % (for larger number of solutions/maps)
    expVarWidth = 0;
    minGridHeight = 80;
    minGridWidth = 60;    
    tabHeight = 30;
    nRows = numel(Classes);
    nCols = max(Classes);

    % Get usable screen size
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    jframe = javax.swing.JFrame;
    insets = toolkit.getScreenInsets(jframe.getGraphicsConfiguration());
    tempFig = figure('ToolBar', 'none', 'MenuBar', 'figure', 'Position', [-1000 -1000 0 0]);    
    pause(0.2);
    titleBarHeight1 = tempFig.OuterPosition(4) - tempFig.InnerPosition(4) + tempFig.OuterPosition(2) - tempFig.InnerPosition(2);
    tempFig.MenuBar = 'none';
    pause(0.2);
    titleBarHeight2 = tempFig.OuterPosition(4) - tempFig.InnerPosition(4) + tempFig.OuterPosition(2) - tempFig.InnerPosition(2);
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
    figSize1 = screenSize + [insets.left, insets.bottom, -insets.left-insets.right, -titleBarHeight1-insets.bottom-insets.top];
    figSize2 = screenSize + [insets.left, insets.bottom, -insets.left-insets.right, -titleBarHeight2-insets.bottom-insets.top];

    minPanelWidth = expVarWidth + minGridWidth*nCols;
    minPanelHeight = minGridHeight*nRows;

    if Visible
        figVisible = 'on';
    else
        figVisible = 'off';
    end

    Scroll = false;
    % Use scrolling and uifigure for large number of maps
    if minPanelWidth > figSize1(3) || minPanelHeight > (figSize1(4) - tabHeight)
        Scroll = true; 
        fig_h = uifigure('Name', 'Microstate maps', 'Units', 'pixels', ...
            'Position', figSize2, 'Visible', figVisible);
        if minPanelWidth < fig_h.Position(3)
            minPanelWidth = fig_h.Position(3) - 50;
        end
        if minPanelHeight < fig_h.Position(4) - tabHeight
            minPanelHeight = fig_h.Position(4) - tabHeight;
        end
    % Otherwise use a normal figure (faster rendering) 
    else
        fig_h = figure('ToolBar', 'none', 'MenuBar', 'figure', 'NumberTitle', 'off', ...
            'Name', 'Microstate maps', 'Position', figSize1, 'Visible', figVisible);            
    end
    gridWidth = fig_h.Position(3)/nCols;
    gridHeight = (fig_h.Position(4) - tabHeight)/nRows;            
    if gridHeight - gridWidth > 100
        heightDiff = fig_h.Position(4) - gridWidth*nRows - 200;
        fig_h.Position(2) = fig_h.Position(2) + .5*heightDiff;
        fig_h.Position(4) = gridWidth*nRows + 200;
        minPanelHeight = fig_h.Position(4) - tabHeight - 30;
    end
    tabGroup = uitabgroup(fig_h, 'Units', 'normalized', 'Position', [0 0 1 1]);

    for i=1:numel(SelectedEEG) 
        ClassRange = SelectedEEG(i).msinfo.ClustPar.MinClasses:SelectedEEG(i).msinfo.ClustPar.MaxClasses;
        plotClasses = ClassRange(ismember(ClassRange, Classes));
        if isempty(plotClasses)
            warning('%s does not contain any of the selected cluster solutions to plot, skipping...', SelectedEEG(i).setname);
            continue;
        end
        for j = ClassRange
            if isfield(SelectedEEG(i).msinfo.MSMaps(j),'Labels')
                if ~isempty(SelectedEEG(i).msinfo.MSMaps(j).Labels)
                    continue
                end
            end 
            % Fill in generic labels if dataset does not have them
            for k = 1:j
                SelectedEEG(i).msinfo.MSMaps(j).Labels{k} = sprintf('MS_%i.%i',j,k);
            end
        end
              
        % Add graphics components
        setTab = uitab(tabGroup, 'Title', ['Microstate maps of ' SelectedEEG(i).setname]);
        tabGroup.SelectedTab = setTab;          
        if Scroll
            OuterPanel = uipanel(setTab, 'Units', 'normalized', 'Position', [0 0 1 1], 'BorderType', 'none');
            OuterPanel.Scrollable = 'on';
            MapPanel = uipanel(OuterPanel, 'Units', 'pixels', 'Position', [0 0 minPanelWidth minPanelHeight], 'BorderType', 'none');
        else
            MapPanel = uipanel(setTab, 'Units', 'normalized', 'Position', [0 0 1 1], 'BorderType', 'none');
        end        
        PlotMSMaps2(fig_h, MapPanel, SelectedEEG(i).msinfo.MSMaps(plotClasses), SelectedEEG(i).chanlocs, ...
            'ShowProgress', ~Visible | Scroll, 'Setname', SelectedEEG(i).setname);
    end    
    
    com = sprintf('fig_h = pop_ShowIndMSMaps(%s, %s, ''Classes'', %s, ''Visible'', %i);', inputname(1), mat2str(SelectedSets), mat2str(Classes), Visible);
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