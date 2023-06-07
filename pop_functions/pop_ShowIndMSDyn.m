% pop_ShowIndMSDyn() Plots temporal dynamics of a selected dataset over
% time. Global field power is plotted on the y axis and different
% microstate class assignments represented by different colors.If multiple 
% sets are selected to plot, they will be plotted in separate tabs.
% pop_FitMSMaps() must be used before calling this function to extract
% temporal parameters.
%
% Usage:
%   >> pop_ShowIndMSDyn(ALLEEG, SelectedSets, 'key1', value1)
%
% Specify the number of classes in the fitting solution using the "Classes" 
% argument.
% Ex:
%   >> fig_h = pop_ShowMSParameters(ALLEEG, 1:5, 'Classes', 4);
%
% Graphical interface:
%
%   "Choose sets to plot"
%   -> Select sets whose temporal parameters should be plotted
%   -> Command line equivalent: "SelectedSets"
%
%   "Select number of classes"   
%   -> Select which fitting solution should be used
%   -> Command line equivalent: "Classes"
%
% Inputs:
%
%   "ALLEEG" (required)
%   -> ALLEEG structure array containing all EEG sets loaded into EEGLAB
%
%   "SelectedSets" (optional)
%   -> Array of set indices of ALLEEG for which temporal parameters will be
%   plotted. Selected sets must contain temporal parameters in the "MSStats"
%   field of "msinfo" (obtained from calling pop_FitMSMaps). If sets
%   are not provided, a GUI will appear to choose sets.
%
% Key, Value inputs (optional):
%
%   "Classes"
%   -> Scalar integer value indicating the fitting solution whose
%   associated temporal parameters will be plotted.
%
% Outputs:
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

function com = pop_ShowIndMSDyn(AllEEG, varargin)

    %% Set defaults for outputs
    global MSTEMPLATE;
    com = '';

    %% Parse inputs and perform initial validation
    p = inputParser;
    funcName = 'pop_ShowIndMSDyn';
    p.FunctionName = funcName;

    addRequired(p, 'AllEEG', @(x) validateattributes(x, {'struct'}, {}));
    addOptional(p, 'SelectedSets', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'vector', '<=', numel(AllEEG)}));
    addParameter(p, 'Classes', [], @(x) validateattributes(x, {'numeric'}, {'integer', 'positive', 'scalar'}));
    
    parse(p, AllEEG, varargin{:});

    SelectedSets = p.Results.SelectedSets;
    nClasses = p.Results.Classes;

    %% SelectedSets validation        
    AvailableSets = find(arrayfun(@(x) hasStats(AllEEG(x)), 1:numel(AllEEG)));
    
    if isempty(AvailableSets)
        errordlg2(['No sets with temporal parameters found. ' ...
            'Use Tools->Backfit template maps to EEG to extract temporal dynamics.'], 'Plot temporal dynamics error');
        return;
    end

    % If the user has provided sets, check their validity
    if ~isempty(SelectedSets)
        SelectedSets = unique(SelectedSets, 'stable');
        isValid = ismember(SelectedSets, AvailableSets);
        if any(~isValid)
            invalidSetsTxt = sprintf('%i, ', SelectedSets(~isValid));
            invalidSetsTxt = invalidSetsTxt(1:end-2);
            error(['The following sets do not contain temporal parameters: %s. ' ...
                'Use pop_FitMSMaps() to extract temporal dynamics first.'], invalidSetsTxt);
        end
    % Otherwise, prompt user to choose sets
    else
        global CURRENTSET;
        defaultSets = find(ismember(AvailableSets, CURRENTSET));
        AvailableSetnames = {AllEEG(AvailableSets).setname};
        [res,~,~,outstruct] = inputgui('geometry', [1 1 1 1], 'geomvert', [1 1 1 4], 'uilist', {
                    { 'Style', 'text'    , 'string', 'Choose sets to plot', 'fontweight', 'bold'} ...
                    { 'Style', 'text'    , 'string', 'Use ctrl or shift for multiple selection'} ...
                    { 'Style', 'text'    , 'string', 'If multiple are chosen, a tab will be created for each.'} ...
                    { 'Style', 'listbox' , 'string', AvailableSetnames, 'Min', 0, 'Max', 2,'Value', defaultSets, 'tag','SelectedSets'}}, ...
                    'title', 'Plot temporal dynamics');

        if isempty(res); return; end
        SelectedSets = AvailableSets(outstruct.SelectedSets);

        if numel(SelectedSets) < 1
            errordlg2('You must select at least one set of microstate maps','Plot temporal dynamics error');
            return;
        end
    end        

    SelectedEEG = AllEEG(SelectedSets);    

    %% Classes validation
    classRanges = arrayfun(@(x) SelectedEEG(x).msinfo.FitPar.Classes, 1:numel(SelectedEEG), 'UniformOutput', false)';
    commonClasses = classRanges{1};
    for i=2:numel(SelectedSets)
        commonClasses = intersect(commonClasses, classRanges{i});
    end

    if isempty(commonClasses)
        errorMessage = 'No overlap in cluster solutions used for fitting found between all selected sets.';
        if ~isempty(p.UsingDefaults)
            errordlg2(errorMessage, 'Plot temporal dynamics error');
        else
            error(errorMessage);
        end
        return;
    end
    if matches('Classes', p.UsingDefaults)
        classChoices = sprintf('%i Classes|', commonClasses);
        classChoices(end) = [];

        [res,~,~,outstruct] = inputgui('geometry', [1 1], 'geomvert', [1 4], 'uilist', ...
            { {'Style', 'text', 'string', 'Select number of classes'} ...
              {'Style', 'listbox', 'string', classChoices, 'Value', 1, 'Tag', 'Classes'}}, ...
              'title', 'Plot temporal dynamics');
        
        if isempty(res); return; end
        nClasses = commonClasses(outstruct.Classes);
    else
        if ~ismember(nClasses, commonClasses)
            classesTxt = sprintf('%i, ', commonClasses);
            classesTxt = classesTxt(1:end-2);
            errorMessage = sprintf(['Not all selected sets to plot contain microstate dynamics information for the %i cluster solution. ' ...
                'Valid class numbers include: %s.'], nClasses, classesTxt);
            if ~isempty(p.UsingDefaults)
                errordlg2(errorMessage, 'Plot temporal dynamics error');
            else
                error(errorMessage);
            end
            return;
        end
    end

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
    fig_h = figure('ToolBar', 'none', 'MenuBar', 'figure', 'NumberTitle', 'off', 'Position', figSize);
    tabGroup = uitabgroup(fig_h, 'Units', 'normalized', 'Position', [0 0 1 1]);

    %% Plot dynamics
    SelectedEEG = AllEEG(SelectedSets);
    HasChildren = arrayfun(@(x) DoesItHaveChildren(AllEEG(x)), 1:numel(AllEEG));
    isEmpty = arrayfun(@(x) isEmptySet(AllEEG(x)), 1:numel(AllEEG));
    meanSets = find(HasChildren & ~isEmpty);
    meanSetnames = {AllEEG(meanSets).setname};
    publishedSetnames = {MSTEMPLATE.setname};
    for s=1:numel(SelectedSets)

        TemplateName = SelectedEEG(s).msinfo.MSStats(nClasses).FittingTemplate;
        showMaps = true;
        if strcmp(TemplateName, '<<own>>')
            ChosenTemplate = SelectedEEG(s);
        else
            % Look for the fitting template in ALLEEG and MSTEMPLATE
            if matches(TemplateName, meanSetnames)
                meanIdx = meanSets(matches(meanSetnames, TemplateName));
                if numel(meanIdx) > 1
                    warning(['Multiple mean sets found that match the fitting template "%s" ' ...
                        'for dataset %i. Template maps will not be displayed.'], TemplateName, SelectedSets(s));
                    showMaps = false;
                else
                    ChosenTemplate = AllEEG(meanIdx);                   
                end
            elseif matches(TemplateName, publishedSetnames)
                ChosenTemplate = MSTEMPLATE(matches(publishedSetnames, TemplateName));
            else
                warning(['Fitting template "%s" for dataset %i could not be found. ' ...
                    'Template maps will not be displayed.'], TemplateName, SelectedSets(s));
                showMaps = false;
            end               
        end

        colors = getColors(nClasses);
        if showMaps                                    
            cmap = ChosenTemplate.msinfo.MSMaps(nClasses).ColorMap;
            unassignedMaps = arrayfun(@(x) all(cmap(x,:) == [.75 .75 .75]), 1:nClasses);        
            if any(unassignedMaps)                
                cmap(unassignedMaps, :) = colors(unassignedMaps, :);
            end
        else
            cmap = colors;
        end
                
        ud.nClasses = nClasses;
        ud.gfp = SelectedEEG(s).msinfo.MSStats(nClasses).GFP;
        ud.Assignment = SelectedEEG(s).msinfo.MSStats(nClasses).MSClass;
        ud.cmap = cmap;
        ud.Start  =  0;
        ud.Segment = 1;
        ud.Time   = SelectedEEG(s).times;
        ud.XRange = min([10000 ud.Time(end)]);
        ud.event = SelectedEEG(s).event;    
        ud.MaxY   = 10;
        ud.nSegments = SelectedEEG(s).trials;
    
        setTab = uitab(tabGroup);
        if ~strcmp(TemplateName, '<<own>>')
            set(setTab, 'Title', ['Microstate dynamics of ' SelectedEEG(s).setname ' (Template: ' TemplateName ')']);
        else
            set(setTab, 'Title', ['Microstate dynamics of ' SelectedEEG(s).setname ' (own template)']);
        end
        tabGroup.SelectedTab = setTab;        

        minGridWidth = 60;
        if showMaps
            ChosenTemplate.msinfo.MSMaps(nClasses).ColorMap = cmap;
            ud.AllMaps = ChosenTemplate.msinfo.MSMaps;
            ud.ClustPar = ChosenTemplate.msinfo.ClustPar;
            ud.chanlocs = ChosenTemplate.chanlocs;
            if figSize(3)*.98/nClasses >= minGridWidth
                ud.ax = axes(setTab, 'Position',[0.05 0.18 0.88 0.59]);
                ud.MapPanel = uipanel(setTab, 'Units', 'normalized', 'Position', [.01 .82 .98 .17], 'BorderType', 'none');               
                ud.Visible = true; 
                ud.Edit = false;
                ud.Scroll = false;
    
                set(setTab,'userdata',ud);
                PlotMSMaps(setTab, nClasses);
            else
                ud.ax = axes(setTab, 'Position', [0.05 0.18 0.88 0.8]);
                uicontrol('Style', 'pushbutton', 'String', 'Maps','Units','Normalized','Position', [0.94 0.64 0.05 0.15], 'Callback', {@PlotMaps, ChosenTemplate, nClasses});                
            end
            minusY = .31; 
            plusY  = .48;
        else
            ud.ax = axes(setTab, 'Position', [.05 .18 .88 .8]);
            minusY = .41;
            plusY = .58;
        end

        uicontrol(setTab, 'Style', 'pushbutton', 'String', '|<<','Units','Normalized','Position', [0.05 0.005 0.08 0.05], 'Callback', {@PlotMSDyn, setTab, 'Move'  ,-Inf});        
        ud.EpochLabel = uicontrol(setTab, 'Style', 'Text', 'String', sprintf('Epoch %i of %i (%i classes)',ud.Segment,ud.nSegments,ud.nClasses), 'Units', 'normalized', 'Position', [.14 .015 .2 .035], 'FontSize', 11, 'FontWeight', 'bold');
        uicontrol(setTab, 'Style', 'pushbutton', 'String', '>>|','Units','Normalized','Position', [0.35 0.005 0.08 0.05], 'Callback', {@PlotMSDyn, setTab, 'Move'  , Inf});
        uicontrol(setTab, 'Style', 'pushbutton', 'String', 'Horz. zoom in' ,'Units','Normalized','Position', [0.61 0.005 0.15 0.05], 'Callback', {@PlotMSDyn, setTab, 'ScaleX', -1000});
        uicontrol(setTab, 'Style', 'pushbutton', 'String', 'Horz. zoom out' ,'Units','Normalized','Position', [0.78 0.005 0.15 0.05], 'Callback', {@PlotMSDyn, setTab, 'ScaleX',  1000});
        uicontrol(setTab, 'Style', 'slider'    ,'Min',ud.Time(1),'Max',ud.Time(end),'Value',ud.Time(1) ,'Units','Normalized','Position', [0.05 0.07 0.88 0.03], ...
            'BackgroundColor', [.6 .6 .6], 'Callback', {@PlotMSDyn, setTab, 'Slider',  1});
    
        uicontrol(setTab, 'Style', 'pushbutton', 'String', '-'   ,'Units','Normalized','Position', [0.94 minusY 0.05 0.15], 'Callback', {@PlotMSDyn, setTab, 'ScaleY', 1/0.75});
        uicontrol(setTab, 'Style', 'pushbutton', 'String', '+'   ,'Units','Normalized','Position', [0.94 plusY  0.05 0.15], 'Callback', {@PlotMSDyn, setTab, 'ScaleY',   0.75});                  

        set(setTab,'userdata',ud);
        PlotMSDyn([], [], setTab);
    end

    com = sprintf('com = pop_ShowIndMSDyn(%s, %s, ''Classes'', %i);', inputname(1), mat2str(SelectedSets), nClasses);
end

function PlotMaps(~, ~, EEG, nClasses)
    pop_ShowIndMSMaps(EEG, 1, 'Classes', nClasses);
end

function PlotMSDyn(obj, ~, setTab, varargin)
   
    ud = get(setTab,'UserData');
    
    p = inputParser;    
    addParameter(p,'Move',0,@isnumeric);
    addParameter(p,'ScaleX',0,@isnumeric);
    addParameter(p,'ScaleY',1,@isnumeric);
    addParameter(p,'Slider',0,@isnumeric);
    parse(p,varargin{:});
    
    MoveX = p.Results.Move;
    if(ud.nSegments > 1) && p.Results.Move == inf
        ud.Segment = min(ud.nSegments,ud.Segment + 1);
         MoveX = 0;    
    end
        
    if(ud.nSegments > 1) && p.Results.Move == -inf
        ud.Segment = max(1,ud.Segment -1);
        MoveX = 0;    
    end
 
    ud.Start = ud.Start + MoveX;
    
    if p.Results.Slider == 1
        ud.Start = obj.Value;
    end
    
    if ud.Start < ud.Time(1)
        ud.Start = ud.Time(1);
    end
    
    if ud.Start + ud.XRange > ud.Time(end)
        ud.Start = ud.Time(end)-ud.XRange;
    end
    
    ud.XRange = ud.XRange+p.Results.ScaleX;
    
    if ud.XRange < 100
        ud.XRange = 100;
    end
    
    if ud.XRange > ud.Time(end) - ud.Time(1)
        ud.XRange = ud.Time(end) - ud.Time(1);
    end
    
    ud.MaxY = ud.MaxY * p.Results.ScaleY;
    
    slider = findobj(setTab,'Style','slider');
    set(slider,'Value',ud.Start);
        
    Data2Show = find(ud.Time >= ud.Start & ud.Time <= (ud.Start + ud.XRange));
    Fit = nan(ud.nClasses,numel(Data2Show));
    for c = 1:ud.nClasses
        idx = ud.Assignment(Data2Show,ud.Segment) == c;        
        idx = [0; idx(1:end-1)] | idx;
        Fit(c,idx) = ud.gfp(Data2Show(1,idx),ud.Segment);
    end
    
    area(ud.ax, ud.Time(Data2Show), Fit', 'LineStyle', 'none');
    colororder(ud.cmap);
    hold(ud.ax, 'on');
    axis(ud.ax, [ud.Start-0.5 ud.Start+ ud.XRange+0.5 0, ud.MaxY]);
    xtick = num2cell(get(ud.ax,'XTick')/ 1000);
    if (xtick{2} - xtick{1}) >= 1
        labels = cellfun(@(x) sprintf('%1.0f:%02.0f:%02.0f',floor(x/3600),floor(rem(x/60,60)),rem(x,60)),xtick, 'UniformOutput',false);
    else
        labels = cellfun(@(x) sprintf('%1.0f:%02.0f:%02.0f:%03.0f',floor(x/3600),floor(rem(x/60,60)),floor(rem(x,60)),rem(x*1000,1000)),xtick, 'UniformOutput',false);
    end
    set(ud.ax,'XTickLabel',labels,'FontSize',10);
    xlabel(ud.ax, 'Latency', 'FontSize', 11);
    ylabel(ud.ax, 'GFP', 'FontSize', 11);
    
    ud.EpochLabel.String = sprintf('Epoch %i of %i (%i classes)',ud.Segment,ud.nSegments,ud.nClasses);
    nPoints = numel(ud.Time);
    dt = ud.Time(2) - ud.Time(1);
    % Show the markers;
    for e = 1:numel(ud.event)
        if ~isfield(ud.event(e),'epoch')
            epoch = 1;
        else
            epoch = ud.event(e).epoch;
        end
        if epoch ~= ud.Segment
            continue
        end
        t = (ud.event(e).latency - (ud.Segment-1) * nPoints)  * dt;
        if t < ud.Start || t > ud.Start + ud.XRange
            continue;
        end
        plot(ud.ax, [t,t],[0,ud.MaxY],'-k');
        if isnumeric(ud.event(e).type)
            txt = sprintf('%1.0i',ud.event(e).type);
        else
            txt = ud.event(e).type;
        end
        text(ud.ax, t,ud.MaxY,txt, 'Interpreter','none','VerticalAlignment','top','HorizontalAlignment','right','Rotation',90);
    end
    hold(ud.ax, 'off');
    set(setTab,'UserData',ud);
end

function hasStats = hasStats(in)
    hasStats = false;

    % check if set includes msinfo
    if ~isfield(in,'msinfo')
        return;
    end
    
    % check if set has MSStats
    if ~isfield(in.msinfo, 'MSStats')
        return;
    else
        hasStats = true;
    end
end

function isEmpty = isEmptySet(in)
    isEmpty = all(cellfun(@(x) isempty(in.(x)), fieldnames(in)));
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

    % search the children of all the mean sets for the child set name
    containsChild = any(arrayfun(@(x) matches(childSetName, AllEEG(x).msinfo.children), SetsToSearch(HasChildren)));

    % if the child cannot be found, search the children of the children
    if ~containsChild
        childSetIndices = unique(cell2mat(arrayfun(@(x) find(matches({AllEEG.setname}, AllEEG(x).msinfo.children)), SetsToSearch(HasChildren), 'UniformOutput', false)));
        containsChild = checkSetForChild(AllEEG, childSetIndices, childSetName);
    end

end