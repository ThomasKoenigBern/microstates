% pop_ShowIndMSMaps() - Display microstate maps, with the option to display
% only certain cluster solutions. To plot individual maps in their own 
% windows, right-click a map and select "Plot map in new window."
%
% Usage:
%   >> [fig_h, com] = pop_ShowIndMSMaps(ALLEEG, 
%       SelectedSets, 'key1', value1, 'key2', value2, ...)
%
% The figure with plotted maps can also be generated but not displayed.
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
%   -> Array of set indices of ALLEEG to plot. If multiple are chosen, a
%   tab will be opened for each.
%
% Key, Value inputs (optional):
%   "Classes"
%   -> Array of class numbers indicating which cluster solutions to plot.
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
function [fig_h, com] = pop_ShowIndMSMaps(AllEEG, varargin)

    %% Set defaults for outputs
    com = '';
    fig_h = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_ShowIndMSMaps';
    p.FunctionName = funcName;
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
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    AvailableSets = find(and(and(~isEmpty, ~HasDyn), HasMS));
    
    if isempty(AvailableSets)
        errordlg2(['No valid sets for plotting found.'], 'Plot microstate maps error');
        return;
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
            errorMessage = ['The following sets are invalid: ' invalidSetsTxt ...
                '. Make sure you have not selected empty sets, dynamics sets, or sets ' ...
                'without microstate maps.'];
            errordlg2(errorMessage, 'Plot microstate maps error');
            return;
        end
    % Otherwise, prompt user to provide sets    
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        if isempty(defaultSets);    defaultSets = 1;    end        
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        
        [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1], 'geomvert', [1 1 1 4], 'uilist', ...
            {{ 'Style', 'text'    , 'string', 'Choose sets for plotting'} ...
            { 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'} ...
            { 'Style', 'text'    , 'string', 'If multiple are chosen, a tab will be created for each'} ...
            { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
            'title', 'Plot microstate maps');

        if isempty(res);    return; end

        SelectedSets = AvailableSets(outstruct.SelectedSets);
    end

    SelectedEEG = AllEEG(SelectedSets);

    % Prompt user to provide class range to display if necessary
    AllMinClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MinClasses, 1:numel(SelectedEEG));
    AllMaxClasses = arrayfun(@(x) SelectedEEG(x).msinfo.ClustPar.MaxClasses, 1:numel(SelectedEEG));
    MinClasses = min(AllMinClasses);
    MaxClasses = max(AllMaxClasses);
    if contains('Classes', p.UsingDefaults)
        classRange = MinClasses:MaxClasses;
        classChoices = sprintf('%i Classes|', classRange);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1 1], 'geomvert', [1 1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select classes to display'} ...
              {'Style', 'text', 'string' 'Use ctrlshift for multiple selection'} ...
              {'Style', 'listbox', 'string', classChoices, 'Min', 0, 'Max', 2, 'Value', 1:numel(classRange), 'Tag', 'Classes'}}, ...
              'title', 'Plot microstate maps');
        
        if isempty(res); return; end

        Classes = classRange(outstruct.Classes);
    else
        if any(Classes < MinClasses) || any(Classes > MaxClasses)
            invalidClasses = Classes(or((Classes < MinClasses), (Classes > MaxClasses)));
            invalidClassesTxt = sprintf('%i, ', invalidClasses);
            invalidClassesTxt = invalidClassesTxt(1:end-2);
            errorMessage = sprintf(['The following specified cluster solutions to plot are invalid: %s' ...
                '. Valid class numbers are in the range %i-%i.'], invalidClassesTxt, MinClasses, MaxClasses);
            errordlg2(errorMessage, 'Plot microstate maps error');
            return;
        end
    end        

    % Compute initial figure size and whether scrolling is needed
    % (for larger number of solutions/maps)
    expVarWidth = 0;
    minGridHeight = 60;
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

    ud.minPanelWidth = expVarWidth + minGridWidth*nCols;
    ud.minPanelHeight = minGridHeight*nRows;

    if Visible
        figVisible = 'on';
    else
        figVisible = 'off';
    end

    ud.Scroll = false;
    % Use scrolling and uifigure for large number of maps
    if ud.minPanelWidth > figSize(3) || ud.minPanelHeight > (figSize(4) - tabHeight)
        ud.Scroll = true; 
        fig_h = uifigure('Name', 'Microstate maps', 'Units', 'pixels', ...
            'Position', figSize, 'Visible', figVisible);
        if ud.minPanelWidth < fig_h.Position(3)
            ud.minPanelWidth = fig_h.Position(3) - 50;
        end
        if ud.minPanelHeight < fig_h.Position(4) - tabHeight
            ud.minPanelHeight = fig_h.Position(4) - tabHeight;
        end
    % Otherwise use a normal figure (faster rendering) 
    else
        fig_h = figure('ToolBar', 'none', 'MenuBar', 'figure', 'NumberTitle', 'off', ...
            'Name', 'Microstate maps', 'Position', figSize, 'Visible', figVisible);            
    end
    gridWidth = fig_h.Position(3)/nCols;
    gridHeight = (fig_h.Position(4) - tabHeight)/nRows;            
    if gridHeight - gridWidth > 100
        heightDiff = fig_h.Position(4) - gridWidth*nRows - 200;
        fig_h.Position(2) = fig_h.Position(2) + .5*heightDiff;
        fig_h.Position(4) = gridWidth*nRows + 200;
        ud.minPanelHeight = fig_h.Position(4) - tabHeight - 30;
    end
    if ud.Scroll
        fig_h.Resize = 'off';
    end
    tabGroup = uitabgroup(fig_h, 'Units', 'normalized', 'Position', [0 0 1 1]);

    for i=1:numel(SelectedEEG)   
        ud.Visible = Visible;   
        ud.AllMaps   = SelectedEEG(i).msinfo.MSMaps;
        ud.chanlocs  = SelectedEEG(i).chanlocs;
        ud.ClustPar  = SelectedEEG(i).msinfo.ClustPar;
        ud.wasSorted = false;
        ud.SelectedSet = SelectedSets;
        ud.com = '';
        if isfield(SelectedEEG(i).msinfo,'children')
            ud.Children = SelectedEEG(i).msinfo.children;
        else
            ud.Children = [];
        end           
        ud.Edit = false;
        
        for j = ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses    
            if isfield(ud.AllMaps(j),'Labels')
                if ~isempty(ud.AllMaps(j).Labels)
                    continue
                end
            end 
            % Fill in generic labels if dataset does not have them
            for k = 1:j
                ud.AllMaps(j).Labels{k} = sprintf('MS_%i.%i',j,k);
            end
            ud.Labels(j,1:j) = ud.AllMaps(j).Labels(1:j);
        end
              
        % Add graphics components
        setTab = uitab(tabGroup, 'Title', ['Microstate maps of ' SelectedEEG(i).setname]);
        tabGroup.SelectedTab = setTab;
        ud.MapPanel = uipanel(setTab, 'Units', 'normalized', 'Position', [0 0 1 1], 'BorderType', 'none');   
        if ud.Scroll
            ud.MapPanel.Scrollable = 'on';
            ud.TilePanel = uipanel(ud.MapPanel, 'Units', 'pixels', 'Position', [0 0 ud.minPanelWidth ud.minPanelHeight], 'BorderType', 'none');
        end
        set(setTab,'userdata',ud);               
        PlotMSMaps(setTab, Classes);        
    end    
    
    com = sprintf('fig_h = pop_ShowIndMSMaps(%s, %s, ''Classes'', %s, ''Visible'', %i);', inputname(1), mat2str(SelectedSets), mat2str(Classes), Visible);
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