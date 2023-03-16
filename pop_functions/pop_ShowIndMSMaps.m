% pop_ShowIndMSMaps() - Display microstate maps, with the option to edit
% and sort microstate maps in an interactive GUI explorer. To plot
% individual maps in their own windows, right-click a map and select "Plot
% map in new window."
%
% Usage:
%   >> [ALLEEG, EEG, CURRENTSET, fig_h, com] = pop_ShowIndMSMaps(ALLEEG, 
%       SelectedSets, 'key1', value1, 'key2', value2, ...)
%
% When not using edit mode, the figure can be generated but not displayed.
% This option is useful if you would like to save microstate maps in a
% script but avoid each window appearing. To generate an invisible figure,
% set the "Visible" argument to 0.
% Ex:
%   >> [ALLEEG, EEG, CURRENTSET, fig_h] = pop_ShowIndMSMaps(ALLEEG, 1,
%       'Edit', 0, 'Classes', 4:7, 'Visible', 0)
%       saveas(fig_h, 'microstate_maps.png')
%       close(fig_h)
%
% Graphical interface:
%
%   "Choose sets for plotting"
%   -> Select sets to plot. This option only exists for the display version
%   of the function, as only one set can be edited in the interactive GUI
%   version at a time. If multiple sets are selected, a tab will be opened
%   for each.
%   -> Command line equivalent: "SelectedSets"
%
% Inputs:
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Array of set indices of ALLEEG to plot. May be multiple if "Edit" is
%   set to false, otherwise may only be one set. If multiple are chosen, a
%   tab will be opened for each.
%
% Key, Value inputs (optional):
%
%   "Edit"
%   -> 1 = display interactive GUI explorer to edit and sort microstate
%   maps, 0 = display microstate maps in static GUI
%   -> Default = 0
%
%   "Classes"
%   -> Array of class numbers indicating which cluster solutions to plot.
%   Only used if "Edit" is 0. If "Edit" is 0 and class numbers are not
%   provided, a GUI will appear to select the cluster solution(s) to plot.
%
%   "Visible"
%   -> 1 = Show GUI with plotted microstate maps, 0 = keep GUI hidden.
%   Useful for scripting purposes to generate and save figures from the
%   returned figure handle without the figures popping up.
%
% Outputs:
%
%   "ALLEEG" 
%   -> ALLEEG structure array containing all sets loaded in EEGLAB. Will
%   include datasets with cleared sorting information if there are datasets
%   whose sorting was based on the edited set, and the user chooses to save
%   changes in edit mode.
%
%   "EEG"
%   -> EEG structure array containing all sets chosen for plotting/editing
%
%   "CURRENTSET"
%   -> Indices of the plotted/edited datasets
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
function [AllEEG, EEGout, CurrentSet, fig_h, com] = pop_ShowIndMSMaps(AllEEG, varargin)

    %% Set defaults for outputs
    com = '';
    global MSTEMPLATE;
    global EEG;
    global CURRENTSET;
    EEGout = EEG;
    CurrentSet = CURRENTSET;
    fig_h = [];

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_ShowIndMSMaps';
    p.FunctionName = funcName;
    p.StructExpand = false;

    addRequired(p, 'AllEEG',  @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));    
    addParameter(p, 'Edit', false, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector'}));
    addParameter(p, 'Visible', true, @(x) validateattributes(x, {'logical', 'numeric'}, {'binary', 'scalar'}));
    parse(p, AllEEG, varargin{:});

    AllEEG = p.Results.AllEEG;
    SelectedSets = p.Results.SelectedSets;
    Edit = p.Results.Edit;
    Classes = p.Results.Classes;
    Visible = p.Results.Visible;

    %% SelectedSets validation
    if numel(SelectedSets) > 1 && Edit
        errordlg2('Editing microstate maps is only supported for one dataset at a time.', ...
            'Plot microstate maps error');
        return;
    end

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
        SelectedSets = unique(SelectedSets);
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid) && ~Edit
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
        if Edit
            [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
                {{ 'Style', 'text'   , 'string', 'Choose set for editing'} ...
                { 'Style', 'listbox' , 'string', AvailableSetnames, 'tag', SelectedSets }}, ...
                'title', 'Edit and sort microstate maps');
        else
            [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1], 'geomvert', [1 1 1 4], 'uilist', ...
                {{ 'Style', 'text'    , 'string', 'Choose sets for plotting'} ...
                { 'Style', 'text'    , 'string', 'Use ctrlshift for multiple selection'} ...
                { 'Style', 'text'    , 'string', 'If multiple are chosen, a tab will be created for each'} ...
                { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                'title', 'Plot microstate maps');
        end

        if isempty(res);    return; end

        SelectedSets = AvailableSets(outstruct.SelectedSets);
    end

    SelectedEEG = AllEEG(SelectedSets);

    if ~Edit
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
                  'title', 'Sort microstate maps');
            
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
    else
        Classes = SelectedEEG.msinfo.ClustPar.MinClasses:SelectedEEG.msinfo.ClustPar.MaxClasses;
    end

    % Compute initial figure size and whether scrolling is needed
    % (for larger number of solutions/maps)
    if Edit
        minGridHeight = 80;     
        expVarWidth = 55;
        mapPanelNormHeight = .75;
        mapPanelNormWidth = .98;
    else
        expVarWidth = 0;
        minGridHeight = 60;
        tabHeight = 30;
    end
    minGridWidth = 60;
    nRows = numel(Classes);
    nCols = max(Classes);

    % Get usable screen size
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    jframe = javax.swing.JFrame;
    insets = toolkit.getScreenInsets(jframe.getGraphicsConfiguration());
    tempFig = figure('MenuBar', 'none', 'ToolBar', 'none', 'Visible', 'off');
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
    if Edit
        % Use scrolling and uifigure for large number of maps
        if ud.minPanelWidth > figSize(3)*mapPanelNormWidth || ud.minPanelHeight > figSize(4)*mapPanelNormHeight
            ud.Scroll = true;
            fig_h = uifigure('Name', ['Microstate maps of ' SelectedEEG.setname], 'Units', 'pixels', ...
                'Position', figSize, 'Resize', 'off');
            if ud.minPanelWidth < fig_h.Position(3) - 20
                ud.minPanelWidth = fig_h.Position(3) - 50;
            end
            selPanelHeight = 175;       % combined height of button area and padding
            if ud.minPanelHeight < fig_h.Position(4) - selPanelHeight
                ud.minPanelHeight = fig_h.Position(4) - selPanelHeight - 30;
            end
        % Otherwise use a normal figure (faster rendering) 
        else
            fig_h = figure('MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off', 'WindowStyle', 'modal', ...
                'Name', ['Microstate maps of ' SelectedEEG.setname], 'Position', figSize);
        end                    
    else
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
            fig_h = figure('MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off', ...
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
    end

    for i=1:numel(SelectedEEG)   
        ud.Visible = Visible;   
        ud.AllMaps   = SelectedEEG(i).msinfo.MSMaps;
        ud.chanlocs  = SelectedEEG(i).chanlocs;
        ud.setname   = SelectedEEG(i).setname;
        ud.ClustPar  = SelectedEEG(i).msinfo.ClustPar;
        ud.wasSorted = false;
        ud.SelectedSet = SelectedSets;
        ud.com = '';
        if isfield(SelectedEEG(i).msinfo,'children')
            ud.Children = SelectedEEG(i).msinfo.children;
        else
            ud.Children = [];
        end           
        ud.Edit = Edit;
        
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
        if Edit
            set(fig_h,'userdata',ud);
            if ud.Scroll
                buildUIFig(fig_h, AllEEG);
            else
                buildFig(fig_h, AllEEG);
            end
            fig_h.CloseRequestFcn = {@ShowIndMSMapsClose, fig_h};                            
            PlotMSMaps(fig_h, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
        else
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
        if ~isvalid(fig_h)
            return;
        end
    end    
    
    if Edit
        com = sprintf('[ALLEEG, EEG, CURRENTSET] = pop_ShowIndMSMaps(%s, %i, ''Edit'', 1);', inputname(1), SelectedSets);
        
        ActionChangedCallback([],[],fig_h);
        uiwait(fig_h);
        if ~isvalid(fig_h)
            return
        end
        ud = get(fig_h,'Userdata');                
        delete(fig_h);

        if ud.wasSorted == true
            ButtonName = questdlg2('Update dataset and try to clear depending sorting?', 'Microstate template edit', 'Yes', 'No', 'Yes');
            switch ButtonName
                case 'Yes'
                    SelectedEEG.msinfo.MSMaps = ud.AllMaps;                                        
                    SelectedEEG.saved = 'no';
                    EEGout = SelectedEEG;
                    CurrentSet = SelectedSets;

                    if ~isempty(ud.com)
                        com = [com newline ud.com];
                    end

                    if isfield(SelectedEEG.msinfo,'children')
                        AllEEG = ClearDataSortedByParent(AllEEG,SelectedEEG.msinfo.children);
                    end
                otherwise
                    disp('Changes abandoned');
            end
        end
    else
        EEGout = SelectedEEG;
        CurrentSet = SelectedSets;
        com = sprintf('[ALLEEG, EEG, CURRENTSET, fig_h] = pop_ShowIndMSMaps(%s, %s, ''Edit'', 0, ''Classes'', %s, ''Visible'', %i);', inputname(1), mat2str(SelectedSets), mat2str(Classes), Visible);
    end
end

%% GUI LAYOUT %%

function buildFig(fig_h, AllEEG)
    ud = fig_h.UserData;
        
    if ~isempty(ud.Children)
        DynEnable = 'off';
    else
        DynEnable = 'on';
    end
    warning('off', 'MATLAB:hg:uicontrol:StringMustBeNonEmpty');

    if isempty(ud.Children)
        uicontrol(fig_h, 'Style', 'Text', 'String', 'Left: total explained variance per solution. Subtitles: individual explained variance per map.', ...
            'Units', 'normalized', 'Position', [.01 .96 .98 .03], 'HorizontalAlignment', 'left');
    else
        uicontrol(fig_h, 'Style', 'Text', 'String', 'Left: mean shared variance per solution across maps. Subtitles: mean shared variance between individual and mean maps.', ...
            'Units', 'normalized', 'Position', [.01 .96 .98 .03], 'HorizontalAlignment', 'left');
    end
    
    ud.MapPanel = uipanel(fig_h, 'Position', [.01 .21 .98 .75], 'BorderType', 'line');
    
    uicontrol(fig_h, 'Style', 'Text', 'String', 'Select solution', 'Units', 'normalized', 'Position', [.01 .17 .12 .03], 'HorizontalAlignment', 'left');    
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uicontrol(fig_h, 'Style', 'listbox','String', AvailableClassesText, 'Units','Normalized','Position', [.01 .01 0.12 .16], 'Callback',{@solutionChanged, fig_h}, 'Min', 0, 'Max', 1);
    
    Actions = {'1) Reorder clusters in selected solution based on index','2) Reorder clusters in selected solution(s) based on template','3) Use selected solution to reorder all other solutions','4) First 1), then 3)', '5) First 2), then 3)'};               
    ud.ActChoice = uicontrol(fig_h, 'Style', 'popupmenu','String', Actions, 'Units','Normalized','Position', [.14 .16 .65 .04], 'Callback',{@ActionChangedCallback,fig_h});

    ud.OrderTxt = uicontrol(fig_h, 'Style', 'Text', 'String', 'Sort Order (negative to flip polarity)', 'Units', 'normalized', 'Position', [.14 .11 .17 .03], 'HorizontalAlignment', 'left');
    ud.OrderEdit = uicontrol(fig_h, 'Style', 'edit', 'String', "", 'Units', 'normalized', 'Position', [.31 .11 .48 .04]);
    
    ud.SelTemplateLabel = uicontrol(fig_h, 'Style', 'Text', 'String', 'Select template', 'Units', 'normalized', 'Position', [.14 .11 .14 .03], 'Visible', 'off');
    ud.SelTemplate = uicontrol(fig_h, 'Style', 'popupmenu', 'String', "", 'Units', 'normalized', 'Position', [.28 .11 .51 .04], 'Visible', 'off');

    ud.LabelsTxt = uicontrol(fig_h, 'Style', 'Text', 'String', 'New Labels', 'Units', 'normalized', 'Position', [.14 .06 .17 .03], 'HorizontalAlignment', 'left');
    ud.LabelsEdit = uicontrol(fig_h, 'Style', 'Edit', 'String', "", 'Units', 'normalized', 'Position', [.31 .06 .48 .04]);

    ud.IgnorePolarity = uicontrol(fig_h, 'Style', 'checkbox', 'String', ' Ignore Polarity', 'Value', 1, 'Units', 'normalized', 'Position', [.14 .06 .65 .04], 'Visible', 'off');

    uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Sort', 'Units', 'normalized', 'Position', [.14 .01 .65 .04], 'Callback', {@Sort, fig_h, AllEEG});
    
    ud.Info    = uicontrol(fig_h, 'Style', 'pushbutton','String', 'Info'    , 'Units','Normalized','Position', [.8 .155 .19 .045], 'Callback', {@MapInfo, fig_h});                
    ud.ShowDyn = uicontrol(fig_h, 'Style', 'pushbutton','String', 'Dynamics', 'Units','Normalized','Position', [.8 .105 .19 .045], 'Callback', {@ShowDynamics, fig_h, AllEEG}, 'Enable', DynEnable);
    ud.Compare = uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Compare', 'Units','Normalized','Position', [.8 .055 .19 .045], 'Callback', {@CompareCallback, fig_h, AllEEG});
    ud.Done    = uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Close'  , 'Units','Normalized','Position', [.8 .005 .19 .045], 'Callback', {@ShowIndMSMapsClose,fig_h});

    fig_h.UserData = ud;
end

function buildUIFig(fig_h, AllEEG)
    ud = fig_h.UserData;

    if ~isempty(ud.Children)
        DynEnable = 'off';
    else
        DynEnable = 'on';
    end
    warning('off', 'MATLAB:hg:uicontrol:StringMustBeNonEmpty');

    ud.FigLayout = uigridlayout(fig_h, [3 1]);
    ud.FigLayout.RowHeight = {15, '1x', 120};

    if isempty(ud.Children)
        uilabel(ud.FigLayout, 'Text', 'Left: total explained variance per solution. Subtitles: individual explained variance per map.');
    else
        uilabel(ud.FigLayout, 'Text', 'Left: mean shared variance per solution across maps. Subtitles: mean shared variance between individual and mean maps.');
    end                    

    ud.MapPanel = uipanel(ud.FigLayout);

    if ud.Scroll
        ud.MapPanel.Scrollable = 'on';
        ud.TilePanel = uipanel(ud.MapPanel, 'Units', 'pixels', 'Position', [0 0 ud.minPanelWidth ud.minPanelHeight], 'BorderType', 'none');
    end

    SelLayout = uigridlayout(ud.FigLayout, [1 3]);
    SelLayout.Padding = [0 0 0 0];
    SelLayout.ColumnWidth = {90, '1x', 200};

    SolutionLayout = uigridlayout(SelLayout, [2 1]);
    SolutionLayout.Padding = [0 0 0 0];
    SolutionLayout.RowHeight = {15, '1x'};

    uilabel(SolutionLayout, 'Text', 'Select solution');
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uilistbox(SolutionLayout, 'Items', AvailableClassesText, 'ItemsData', ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses, 'ValueChangedFcn', {@solutionChanged, fig_h}, 'Multiselect', 'off');
    
    SortLayout = uigridlayout(SelLayout, [4 1]);
    SortLayout.RowSpacing = 8;
    SortLayout.Padding = [0 0 0 0];

    Actions = {'1) Reorder clusters in selected solution based on index','2) Reorder clusters in selected solution(s) based on template','3) Use selected solution to reorder all other solutions','4) First 1), then 3)', '5) First 2), then 3)'};               
    ud.ActChoice = uidropdown(SortLayout, 'Items', Actions, 'ItemsData', 1:5, 'ValueChangedFcn', {@ActionChangedCallback, fig_h});

    ud.OrderLayout = uigridlayout(SortLayout, [1 2]);
    ud.OrderLayout.Padding = [0 0 0 0];
    ud.OrderLayout.ColumnSpacing = 0;
    ud.OrderLayout.ColumnWidth = {210, '1x'};

    ud.OrderTxt = uilabel(ud.OrderLayout, 'Text', 'Sort Order (negative to flip polarity)');
    ud.OrderEdit = uieditfield(ud.OrderLayout);

    ud.LabelsLayout = uigridlayout(SortLayout, [1 2]);
    ud.LabelsLayout.Padding = [0 0 0 0];
    ud.LabelsLayout.ColumnSpacing = 0;
    ud.LabelsLayout.ColumnWidth = {210, '1x'};

    ud.LabelsTxt = uilabel(ud.LabelsLayout, 'Text', 'New Labels');
    ud.LabelsEdit = uieditfield(ud.LabelsLayout);    

    uibutton(SortLayout, 'Text', 'Sort', 'ButtonPushedFcn', {@Sort,fig_h, AllEEG});

    BtnLayout = uigridlayout(SelLayout, [4 1]);
    BtnLayout.Padding = [0 0 0 0];
    BtnLayout.RowSpacing = 2;
    ud.Info = uibutton(BtnLayout, 'Text', 'Info', 'ButtonPushedFcn', {@MapInfo, fig_h});
    ud.ShowDyn = uibutton(BtnLayout, 'Text', 'Dynamics', 'ButtonPushedFcn', {@ShowDynamics, fig_h, AllEEG}, 'Enable', DynEnable);
    ud.Compare = uibutton(BtnLayout, 'Text', 'Compare maps', 'ButtonPushedFcn', {@CompareCallback, fig_h, AllEEG});
    ud.Done = uibutton(BtnLayout, 'Text', 'Close', 'ButtonPushedFcn', {@ShowIndMSMapsClose, fig_h});

    fig_h.Resize = 'off';

    fig_h.UserData = ud;

    solutionChanged([], [], fig_h);
end

%% GUI CALLBACKS %%

function ShowIndMSMapsClose(~,~,fh)
    ud = fh.UserData;
    
    if isfield(ud,"CompFigHandle")
        if isvalid(ud.CompFigHandle)
            close(ud.CompFigHandle);
        end
    end
    
    if ud.Edit == true
        uiresume(fh);
    else
        delete(fh);
    end

end

function solutionChanged(~, ~, fig)
    ud = fig.UserData;        

    if ud.ActChoice.Value == 1 || ud.ActChoice.Value == 4

        nClasses = ud.ClassList.Value;
        if ~ud.Scroll
            nClasses = ud.ClustPar.MinClasses + nClasses - 1;
        end

        if ud.Scroll
            ud.OrderEdit.Value = sprintf('%i ', 1:nClasses);
        else
            ud.OrderEdit.String = sprintf('%i ', 1:nClasses);
        end
    
        letters = 'A':'Z';
        if ud.Scroll
            ud.LabelsEdit.Value = sprintf('%s ', string(arrayfun(@(x) {letters(x)}, 1:nClasses)));
        else
            ud.LabelsEdit.String = sprintf('%s ', string(arrayfun(@(x) {letters(x)}, 1:nClasses)));
        end
    end
end

function ActionChangedCallback(~,~,fh)
    UserData = fh.UserData;
    switch(UserData.ActChoice.Value)
        case {1,4}
            if UserData.Scroll
                if isfield(UserData, 'SelTemplate')
                    delete(UserData.SelTemplateLabel);
                    delete(UserData.SelTemplate);
                end
    
                if isfield(UserData, 'IgnorePolarity')
                    delete(UserData.IgnorePolarity);
                end
    
                if ~isfield(UserData, 'OrderEdit') || ~isvalid(UserData.OrderEdit)
                    UserData.OrderTxt = uilabel(UserData.OrderLayout, 'Text', 'Sort Order (negative to flip polarity)');
                    UserData.OrderTxt.Layout.Column = 1;
                    UserData.OrderEdit = uieditfield(UserData.OrderLayout);
                    UserData.OrderEdit.Layout.Column = 2;
        
                    UserData.LabelsTxt = uilabel(UserData.LabelsLayout, 'Text', 'New Labels');
                    UserData.LabelsTxt.Layout.Column = 1;
                    UserData.LabelsEdit = uieditfield(UserData.LabelsLayout);
                    UserData.LabelsEdit.Layout.Column = 2;                                           
                end 

                if numel(UserData.ClassList.Value) > 1
                    UserData.ClassList.Value = UserData.ClassList.Value(end);
                end
                UserData.ClassList.Multiselect = 'off';
            else
                UserData.OrderTxt.Visible = 'on';
                UserData.OrderEdit.Visible = 'on';
                UserData.OrderEdit.Enable = 'on';

                UserData.LabelsTxt.Visible = 'on';
                UserData.LabelsEdit.Visible = 'on';
                UserData.LabelsEdit.Enable = 'on';

                UserData.SelTemplateLabel.Visible = 'off';
                UserData.SelTemplate.Visible = 'off';

                UserData.IgnorePolarity.Visible = 'off';
                UserData.IgnorePolarity.Enable = 'off';

                if numel(UserData.ClassList.Value) > 1
                    UserData.ClassList.Value = UserData.ClassList.Value(end);
                end
                UserData.ClassList.Max = 1;
            end
        case {2,5}
            if UserData.Scroll
                if isfield(UserData, 'OrderEdit')
                    delete(UserData.OrderEdit);
                    delete(UserData.OrderTxt);
        
                    delete(UserData.LabelsEdit);
                    delete(UserData.LabelsTxt);
                end
    
                if ~isfield(UserData, 'SelTemplate') || ~isvalid(UserData.SelTemplate)
                    UserData.SelTemplateLabel = uilabel(UserData.OrderLayout, 'Text', 'Select template');
                    UserData.SelTemplateLabel.Layout.Column = 1;
                    [TemplateNames, DisplayNames] = getTemplateNames();
                    UserData.SelTemplate = uidropdown(UserData.OrderLayout, 'Items', DisplayNames, 'ItemsData', TemplateNames);
                    UserData.SelTemplate.Layout.Column = 2;
                end
    
                if ~isfield(UserData, 'IgnorePolarity') || ~isvalid(UserData.IgnorePolarity)
                    UserData.IgnorePolarity = uicheckbox(UserData.LabelsLayout, 'Text', 'Ignore Polarity', 'Value', true);
                    UserData.IgnorePolarity.Layout.Column = 1;
                end

                if UserData.ActChoice.Value == 5
                    if numel(UserData.ClassList.Value) > 1
                        UserData.ClassList.Value = UserData.ClassList.Value(end);
                    end
                    UserData.ClassList.Multiselect = 'off';
                else
                    UserData.ClassList.Multiselect = 'on';
                end
            else
                UserData.OrderTxt.Visible = 'off';
                UserData.OrderEdit.Visible = 'off';
                UserData.OrderEdit.Enable = 'off';
                
                UserData.LabelsTxt.Visible = 'off';
                UserData.LabelsEdit.Visible = 'off';
                UserData.LabelsEdit.Enable = 'off';

                UserData.SelTemplateLabel.Visible = 'on';
                UserData.SelTemplate.Visible = 'on';
                UserData.SelTemplate.Enable = 'on';

                UserData.IgnorePolarity.Visible = 'on';
                UserData.IgnorePolarity.Enable = 'on';
    
                [~, DisplayNames] = getTemplateNames();
                UserData.SelTemplate.String = DisplayNames;

                if UserData.ActChoice.Value == 5
                    if numel(UserData.ClassList.Value) > 1
                        UserData.ClassList.Value = UserData.ClassList.Value(end);
                    end
                    UserData.ClassList.Max = 1;
                else
                    UserData.ClassList.Max = 2;
                end
            end
        
        case 3
            if UserData.Scroll
                if isfield(UserData, 'OrderEdit')
                    delete(UserData.OrderEdit);
                    delete(UserData.OrderTxt);
        
                    delete(UserData.LabelsEdit);
                    delete(UserData.LabelsTxt);
                end
    
                if isfield(UserData, 'SelTemplate')
                    delete(UserData.SelTemplateLabel);
                    delete(UserData.SelTemplate);
                end
    
                if ~isfield(UserData, 'IgnorePolarity') || ~isvalid(UserData.IgnorePolarity)
                    UserData.IgnorePolarity = uicheckbox(UserData.LabelsLayout, 'Text', 'Ignore Polarity', 'Value', true);
                    UserData.IgnorePolarity.Layout.Column = 1;
                end

                if numel(UserData.ClassList.Value) > 1
                    UserData.ClassList.Value = UserData.ClassList.Value(end);
                end
                UserData.ClassList.Multiselect = 'off';
            else
                UserData.OrderTxt.Visible = 'off';
                UserData.OrderEdit.Visible = 'off';
                UserData.OrderEdit.Enable = 'off';

                UserData.LabelsTxt.Visible = 'off';
                UserData.LabelsEdit.Visible = 'off';
                UserData.LabelsEdit.Enable = 'off';

                UserData.SelTemplateLabel.Visible = 'off';
                UserData.SelTemplate.Visible = 'off';
                UserData.SelTemplate.Enable = 'off';

                UserData.IgnorePolarity.Visible = 'on';
                UserData.IgnorePolarity.Enable  = 'on';

                if numel(UserData.ClassList.Value) > 1
                    UserData.ClassList.Value = UserData.ClassList.Value(end);
                end
                UserData.ClassList.Max = 1;
            end
    end

    fh.UserData = UserData;
    solutionChanged([], [], fh);
end

%% SORTING %%
function Sort(~,~,fh, AllEEG)
    UserData = fh.UserData;

    AllEEG(UserData.SelectedSet).msinfo.MSMaps = fh.UserData.AllMaps;
    nClasses = UserData.ClassList.Value;  
    if ~UserData.Scroll
        nClasses = UserData.ClustPar.MinClasses + nClasses - 1;
    end

    if UserData.ActChoice.Value == 1 || UserData.ActChoice.Value == 2
        SortAll = false;
    else
        SortAll = true;
    end

    switch(UserData.ActChoice.Value)
        case {1, 4}
            if UserData.Scroll
                SortOrder = sscanf(UserData.OrderEdit.Value, '%i')';
                NewLabels = split(UserData.LabelsEdit.Value)';
            else
                SortOrder = sscanf(UserData.OrderEdit.String, '%i')';
                NewLabels = split(UserData.LabelsEdit.String)';
            end
            NewLabels = NewLabels(~cellfun(@isempty, NewLabels));

            [EEGout, ~, com] = pop_SortMSTemplates(AllEEG, UserData.SelectedSet, 'TemplateSet', 'manual', 'SortOrder', SortOrder, 'NewLabels', NewLabels, 'Classes', nClasses, 'SortAll', SortAll);
            
        case {2, 5}
            IgnorePolarity = UserData.IgnorePolarity.Value;

            if UserData.Scroll
                TemplateName = UserData.SelTemplate.Value;
            else
                TemplateNames = getTemplateNames();
                TemplateName = TemplateNames{UserData.SelTemplate.Value};
            end

            [EEGout, ~, com] = pop_SortMSTemplates(AllEEG, UserData.SelectedSet, 'IgnorePolarity', IgnorePolarity, 'TemplateSet', TemplateName, 'Classes', nClasses, 'SortAll', SortAll);
            
        case 3
            IgnorePolarity = UserData.IgnorePolarity.Value;

            [EEGout, ~, com] = pop_SortMSTemplates(AllEEG, UserData.SelectedSet, 'IgnorePolarity', IgnorePolarity, 'TemplateSet', 'manual', 'SortOrder', 1:nClasses, 'NewLabels', UserData.AllMaps(nClasses).Labels, 'Classes', nClasses, 'SortAll', true);          
    end

    fh.UserData.AllMaps = EEGout.msinfo.MSMaps;
    if isempty(fh.UserData.com)
        fh.UserData.com = com;
    elseif ~isempty(com)
        fh.UserData.com = [fh.UserData.com newline com];
    end
    fh.UserData.wasSorted = true;

    ActionChangedCallback([], [], fh);

    if SortAll
        PlotMSMaps(fh, UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses);
    else
        PlotMSMaps(fh, nClasses);
    end
end

%% BUTTON CALLBACKS %% 
function MapInfo(~, ~, fh)
    UserData = get(fh,'UserData');    

    choice = arrayfun(@(x) {sprintf('%i Classes', x)}, UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses);
    
    [InfoTxt,InfoTit] = GetInfoText(UserData,1);
    
    inputgui( 'geometry', {[1 1] 1 1}, 'geomvert', [3 1 3],  'uilist', { ...
                { 'Style', 'text', 'string', 'Select model', 'fontweight', 'bold'  } ...
                { 'style', 'listbox', 'string', choice, 'Value', 1, 'Callback',{@MapInfoSolutionChanged,fh} 'Tag','nClassesListBox'}...
                { 'Style', 'text', 'string', InfoTit, 'fontweight', 'bold','Tag','MapInfoTitle'} ...
                { 'Style', 'text', 'string', InfoTxt, 'fontweight', 'normal','Tag','MapInfoTxt'}}, ...
                'title','Microstate info');
end

function MapInfoSolutionChanged(obj,event,fh)
    UserData = fh.UserData;
    TxtToChange = findobj(obj.Parent,'Tag','MapInfoTxt');
    TitToChange = findobj(obj.Parent,'Tag','MapInfoTitle');
    
    [txt,tit] = GetInfoText(UserData,event.Source.Value);

    TxtToChange.String = txt;
    TitToChange.String = tit;
end

function [txt,tit] = GetInfoText(UserData,idx)
    nClasses = idx + UserData.ClustPar.MinClasses -1 ;

    tit = sprintf('Info for %i classes:',nClasses);

    AlgorithmTxt = {'k-means','AAHC'};
    PolarityText = {'considererd','ignored'};
    GFPText      = {'all data', 'GFP peaks only'};
    NormText     = {'not ', ''};
    
    if isinf(UserData.ClustPar.MaxMaps)
            MaxMapsText = 'all';
    else
            MaxMapsText = num2str(UserData.ClustPar.MaxMaps,'%i');
    end
    
    if ~isfield(UserData.ClustPar,'Normalize')
        UserData.ClustPar.Normalize = 1;
    end

    txt = { sprintf('Derived from: %s',UserData.setname) ...
            sprintf('Algorithm used: %s',AlgorithmTxt{UserData.ClustPar.UseAAHC+1})...
            sprintf('Polarity was %s',PolarityText{UserData.ClustPar.IgnorePolarity+1})...
            sprintf('EEG was %snormalized before clustering',NormText{UserData.ClustPar.Normalize+1})...
            sprintf('Extraction was based on %s',GFPText{UserData.ClustPar.GFPPeaks+1})...
            sprintf('Extraction was based on %s maps',MaxMapsText)...
            sprintf('Explained variance: %2.2f%%',sum(UserData.AllMaps(nClasses).ExpVar) * 100) ...
            };
    if isempty(UserData.AllMaps(nClasses).SortedBy)
        txt = [txt, 'Maps are unsorted'];
    else
        txt = [txt sprintf('Sort mode was %s ',UserData.AllMaps(nClasses).SortMode)];
        txt = [txt sprintf('Sorting was based on %s ',UserData.AllMaps(nClasses).SortedBy)];
    end
            
    if ~isempty(UserData.Children)
        childrenTxt = sprintf('%s, ', string(UserData.Children));
        childrenTxt = childrenTxt(1:end-2);
        txt = [txt 'Children: ' childrenTxt];
    end

end

function ShowDynamics(~, ~, fh, AllEEG)
    AllEEG(fh.UserData.SelectedSet).msinfo.MSMaps = fh.UserData.AllMaps;

    [~, ~, com] = pop_ShowIndMSDyn(AllEEG, fh.UserData.SelectedSet, 'TemplateSet', 'own');

    if isempty(fh.UserData.com)
        fh.UserData.com = com;
    elseif ~isempty(com)
        fh.UserData.com = [fh.UserData.com newline com];
    end        
end

function CompareCallback(~, ~, fh, AllEEG)
    AllEEG(fh.UserData.SelectedSet).msinfo.MSMaps = fh.UserData.AllMaps;

    [EEGout, ~, com] = pop_CompareMSTemplates(AllEEG, fh.UserData.SelectedSet, [], []);

    % If the command contains multiple lines, we know sorting occurred
    % within the function, so we should replot the maps
    if contains(com, newline)
        fh.UserData.AllMaps = EEGout.msinfo.MSMaps;
        fh.UserData.wasSorted = true;
        PlotMSMaps(fh, fh.UserData.ClustPar.MinClasses:fh.UserData.ClustPar.MaxClasses);  
        ActionChangedCallback([], [], fh);
    end
    
    if isempty(fh.UserData.com)
        fh.UserData.com = com;
    elseif ~isempty(com)
        fh.UserData.com = [fh.UserData.com newline com];
    end        
end

%% HELPERS %%

function [TemplateNames, DisplayNames, sortOrder] = getTemplateNames()
    global MSTEMPLATE;
    TemplateNames = {MSTEMPLATE.setname};
    minClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, 1:numel(MSTEMPLATE));
    maxClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MaxClasses, 1:numel(MSTEMPLATE));
    [minClasses, sortOrder] = sort(minClasses, 'ascend');
    maxClasses = maxClasses(sortOrder);
    classRangeTxt = string(minClasses);
    diffMaxClasses = maxClasses ~= minClasses;
    classRangeTxt(diffMaxClasses) = sprintf('%s - %s', classRangeTxt(diffMaxClasses), string(maxClasses(diffMaxClasses)));
    TemplateNames = TemplateNames(sortOrder);
    nSubjects = arrayfun(@(x) MSTEMPLATE(x).msinfo.MetaData.nSubjects, sortOrder);
    nSubjects = arrayfun(@(x) sprintf('n=%i', x), nSubjects, 'UniformOutput', false);
    DisplayNames = strcat(classRangeTxt, " maps - ", TemplateNames, " - ", nSubjects);
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