function [SortedMaps, com] = pop_ManualSort(AllEEG, SelectedSet, SortOrder, NewLabels, nClasses, SortAll, IgnorePolarity)    
    SortedMaps = [];
    com = '';
    SelectedEEG = AllEEG(SelectedSet);

    % If all parameters are provided, perform manual sorting without GUI
    % and return
    if ~isempty(nClasses) && ~isempty(SortOrder) && ~isempty(NewLabels)
        ClassRange = SelectedEEG.msinfo.ClustPar.MinClasses:SelectedEEG.msinfo.ClustPar.MaxClasses;
        [SortedMaps, com] = ManualSort(SelectedEEG.msinfo.MSMaps, SortOrder, NewLabels, nClasses, SortAll, ClassRange, IgnorePolarity, SelectedSet);
        return;
    end

    % Otherwise show the GUI    
    ud.AllMaps      = SelectedEEG.msinfo.MSMaps;
    ud.chanlocs     = SelectedEEG.chanlocs;
    ud.ClustPar     = SelectedEEG.msinfo.ClustPar;
    ud.Edit         = false;
    ud.Visible      = true;
    ud.com          = '';
    ud.SelectedSet  = SelectedSet;

    % Compute initial figure size and whether scrolling is needed
    minGridSize = 60;
    mapPanelNormHeight = .72;
    mapPanelNormWidth = .98;
    nRows = ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses + 1;
    nCols = ud.ClustPar.MaxClasses;
    ud.minPanelWidth = minGridSize*nCols;
    ud.minPanelHeight = minGridSize*nRows;
    
    % Get usable screen size
    toolkit = java.awt.Toolkit.getDefaultToolkit();
    jframe = javax.swing.JFrame;
    insets = toolkit.getScreenInsets(jframe.getGraphicsConfiguration());
    tempFig = figure('MenuBar', 'none', 'ToolBar', 'none', 'Visible', 'off');
    titleBarHeight = tempFig.OuterPosition(4) - tempFig.InnerPosition(4) + tempFig.OuterPosition(2) - tempFig.InnerPosition(2);
    delete(tempFig);
    figSize = get(0, 'screensize') + [insets.left, insets.bottom, -insets.left-insets.right, -titleBarHeight-insets.bottom-insets.top];
    
    ud.Scroll = false;
    % Use scrolling and uifigure
    if ud.minPanelWidth > figSize(3)*mapPanelNormWidth || ud.minPanelHeight > figSize(4)*mapPanelNormHeight
        ud.Scroll = true;
        fig_h = uifigure('Name', ['Microstate maps of ' SelectedEEG.setname], 'Units', 'pixels', ...
            'Position', figSize, 'Resize', 'off');
        if ud.minPanelWidth < fig_h.Position(3) - 20
            ud.minPanelWidth = fig_h.Position(3) - 50;
        end
        selPanelHeight = 190;       % combined height of button area and padding
        if ud.minPanelHeight < fig_h.Position(4) - selPanelHeight
            ud.minPanelHeight = fig_h.Position(4) - selPanelHeight - 30;
        end

        fig_h.UserData = ud;
        buildUIFig(fig_h)
    % Otherwise use a normal figure (faster rendering) 
    else
        fig_h = figure('MenuBar', 'none', 'ToolBar', 'none', 'NumberTitle', 'off', 'WindowStyle', 'modal', ...
                'Name', ['Microstate maps of ' SelectedEEG.setname], 'Position', figSize);

        fig_h.UserData = ud;
        buildFig(fig_h);
    end
    
    PlotMSMaps(fig_h, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    if ~isvalid(fig_h)
        return;
    end
    solutionChanged([], [], fig_h);
    
    fig_h.CloseRequestFcn = 'uiresume()';
    uiwait();

    if isvalid(fig_h)
        ud = fig_h.UserData;
        delete(fig_h);     
        SortedMaps = ud.AllMaps;
        com = ud.com;
    end
end

function buildFig(fig_h)
    ud = fig_h.UserData;
            
    ud.MapPanel = uipanel(fig_h, 'Position', [.01 .27 .98 .72], 'BorderType', 'line');
    
    uicontrol(fig_h, 'Style', 'Text', 'String', 'Select solution', 'Units', 'normalized', 'Position', [.01 .22 .15 .03], 'HorizontalAlignment', 'left');
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uicontrol(fig_h, 'Style', 'listbox','String', AvailableClassesText, 'Units','Normalized','Position', [.01 .06 0.15 .16], 'Callback',{@solutionChanged, fig_h});
       
    uicontrol(fig_h, 'Style', 'Text', 'String', 'Sort Order (negative to flip polarity)', 'Units', 'normalized', 'Position', [.17 .21 .17 .03], 'HorizontalAlignment', 'left');
    ud.OrderEdit = uicontrol(fig_h, 'Style', 'edit', 'String', "", 'Units', 'normalized', 'Position', [.34 .21 .65 .04]);
        
    uicontrol(fig_h, 'Style', 'Text', 'String', 'New Labels', 'Units', 'normalized', 'Position', [.17 .16 .17 .03], 'HorizontalAlignment', 'left');
    ud.LabelsEdit = uicontrol(fig_h, 'Style', 'Edit', 'String', "", 'Units', 'normalized', 'Position', [.34 .16 .65 .04]);

    ud.IgnorePolarity = uicontrol(fig_h, 'Style', 'checkbox', 'String', ' Ignore Polarity', 'Value', 1, 'Units', 'normalized', 'Position', [.76 .11 .23 .04]);
    ud.SortAll = uicontrol(fig_h, 'Style', 'checkbox', 'String', ' Use selected solution to reorder all other solutions', 'Value', 0, 'Units', 'normalized', 'Position', [.17 .11 .59 .04]);

    uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Sort', 'Units', 'normalized', 'Position', [.17 .06 .82 .04], 'Callback', {@ManualSortCallback,fig_h});
    
    uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Cancel', 'Units', 'normalized', 'Position', [.78 .005 .1 .045], 'Callback', {@btnPressed, fig_h});
    uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Save', 'Units', 'normalized', 'Position', [.89 .005 .1 .045], 'Callback', {@btnPressed, fig_h});

    fig_h.UserData = ud;
end

function buildUIFig(fig_h)
    ud = fig_h.UserData;
    
    ud.FigLayout = uigridlayout(fig_h, [3 1]);
    ud.FigLayout.RowHeight = {'1x', 120, 30};

    ud.MapPanel = uipanel(ud.FigLayout);

    if ud.Scroll
        ud.MapPanel.Scrollable = 'on';
        ud.TilePanel = uipanel(ud.MapPanel, 'Units', 'pixels', 'Position', [0 0 ud.minPanelWidth ud.minPanelHeight], 'BorderType', 'none');
    end
    
    SelLayout = uigridlayout(ud.FigLayout, [1 2]);
    SelLayout.Padding = [0 0 0 0];
    SelLayout.ColumnWidth = {180, '1x'};
    
    SolutionLayout = uigridlayout(SelLayout, [2 1]);
    SolutionLayout.Padding = [0 0 0 0];
    SolutionLayout.RowHeight = {15, '1x'};

    uilabel(SolutionLayout, 'Text', 'Select solution');
    AvailableClasses = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uilistbox(SolutionLayout, 'Items', AvailableClasses, ...
        'ItemsData', ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses, ...
        'ValueChangedFcn',{@solutionChanged,fig_h});
    
    SortLayout = uigridlayout(SelLayout, [4 1]);
    SortLayout.Padding = [0 0 0 0];
    
    OrderLayout = uigridlayout(SortLayout, [1 2]);
    OrderLayout.Padding = [0 0 0 0];
    OrderLayout.ColumnSpacing = 0;
    OrderLayout.ColumnWidth = {210, '1x'};
    uilabel(OrderLayout, 'Text', 'Sort Order (negative to flip polarity)');
    ud.OrderEdit = uieditfield(OrderLayout);
    
    LabelsLayout = uigridlayout(SortLayout, [1 2]);
    LabelsLayout.Padding = [0 0 0 0];
    LabelsLayout.ColumnSpacing = 0;
    LabelsLayout.ColumnWidth = {210, '1x'};
    uilabel(LabelsLayout, 'Text', 'New Labels');
    ud.LabelsEdit = uieditfield(LabelsLayout);
    
    CheckBoxLayout = uigridlayout(SortLayout, [1 2]);
    CheckBoxLayout.Padding = [0 0 0 0];
    CheckBoxLayout.ColumnSpacing = 0;
    CheckBoxLayout.ColumnWidth = {'3x', '1x'};
    ud.SortAll = uicheckbox(CheckBoxLayout, 'Text', ' Use selected solution to reorder all other solutions');
    ud.IgnorePolarity = uicheckbox(CheckBoxLayout, 'Text', ' Ignore Polarity', 'Value', 1);
    
    uibutton(SortLayout, 'Text', 'Sort', 'ButtonPushedFcn', {@ManualSortCallback,fig_h});
    
    BtnLayout = uigridlayout(ud.FigLayout, [1 3]);
    BtnLayout.ColumnWidth = {'1x', 120, 120};
    BtnLayout.Padding = [0 0 0 5];
    CancelBtn = uibutton(BtnLayout, 'Text', 'Cancel', 'ButtonPushedFcn', {@btnPressed, fig_h});
    CancelBtn.Layout.Column = 2;
    SaveBtn = uibutton(BtnLayout, 'Text', 'Save', 'ButtonPushedFcn', {@btnPressed, fig_h});
    SaveBtn.Layout.Column = 3;
    
    fig_h.UserData = ud;
end

function btnPressed(src, ~, fig)
    if fig.UserData.Scroll
        text = src.Text;
    else
        text = src.String;
    end
    if strcmp(text, 'Save')
        uiresume();
    else
        delete(fig);
    end
end

function ManualSortCallback(~, ~, fig)
    MSMaps = fig.UserData.AllMaps;
    if fig.UserData.Scroll
        SortOrder = sscanf(fig.UserData.OrderEdit.Value, '%i')';
        NewLabels = split(fig.UserData.LabelsEdit.Value)';
        NewLabels = NewLabels(~cellfun(@isempty, NewLabels));
        nClasses = fig.UserData.ClassList.Value;        
    else
        SortOrder = sscanf(fig.UserData.OrderEdit.String, '%i')';
        NewLabels = split(fig.UserData.LabelsEdit.String)';
        NewLabels = NewLabels(~cellfun(@isempty, NewLabels));
        nClasses = fig.UserData.ClassList.Value + fig.UserData.ClustPar.MinClasses - 1;
    end
    SortAll = fig.UserData.SortAll.Value;
    IgnorePolarity = fig.UserData.IgnorePolarity.Value;
    ClassRange = fig.UserData.ClustPar.MinClasses:fig.UserData.ClustPar.MaxClasses;    
    SelectedSet = fig.UserData.SelectedSet;

    [MSMaps, com] = ManualSort(MSMaps, SortOrder, NewLabels, nClasses, SortAll, ClassRange, IgnorePolarity, SelectedSet);
    if isempty(MSMaps); return; end
    fig.UserData.AllMaps = MSMaps;
    if isempty(com)
        fig.UserData.com = com;
    else
        fig.UserData.com = [fig.UserData.com newline com];
    end

    if SortAll
        PlotMSMaps(fig, ClassRange);
    else
        PlotMSMaps(fig, nClasses);
    end

    solutionChanged([], [], fig);
end

function [MSMaps, com] = ManualSort(MSMaps, SortOrder, NewLabels, nClasses, SortAll, ClassRange, IgnorePolarity, SelectedSet)
    com = '';
    
    if numel(nClasses) > 1        
        errordlg2('Only one cluster solution can be chosen for manual sorting.', 'Sort microstate maps error');
        return;
    end

    if nClasses > max(ClassRange) || nClasses < min(ClassRange)
        warningMessage = sprintf(['The specified set to sort does not contain a %i microstate solution. Valid ' ...
            ' class numbers to sort are in the range %i-%i.'], nClasses, max(ClassRange), min(ClassRange));
        errordlg2(warningMessage, 'Sort microstate maps error');
        return;
    end

    % Validate SortOrder
    sortOrderSign = sign(SortOrder(:)');
    absSortOrder = abs(SortOrder(:)');
    if (numel(absSortOrder) ~= nClasses)
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    if numel(unique(absSortOrder)) ~= nClasses
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    if any(unique(absSortOrder) ~= unique(1:nClasses))
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    % Validate NewLabels
    if numel(NewLabels) ~= nClasses
        MSMaps = [];
        errordlg2('Invalid manual map labels given', 'Sort microstate maps error');
        return;
    end

    % Manual sort    
    if ~all(SortOrder == 1:nClasses) || ~all(string(NewLabels) == string(MSMaps(nClasses).Labels))
        SortOrder = absSortOrder;
        MSMaps(nClasses).Maps = MSMaps(nClasses).Maps(SortOrder,:).*repmat(sortOrderSign',1,size(MSMaps(nClasses).Maps,2));
        MSMaps(nClasses).Labels = NewLabels(:)';
        MSMaps(nClasses).ColorMap = lines(nClasses);
%         MSMaps(nClasses).ExpVar = MSMaps(nClasses).ExpVar(SortOrder);
        MSMaps(nClasses).SortMode = 'manual';
        MSMaps(nClasses).SortedBy = 'user';
    end

    % Sort all if selected
    if SortAll
        MSMaps = sortAllSolutions(MSMaps, ClassRange, nClasses, IgnorePolarity);
    end

    NewLabelsTxt = sprintf('''%s'', ', string(NewLabels));
    NewLabelsTxt = ['{' NewLabelsTxt(1:end-2) '}'];
    com = sprintf(['[EEG, CURRENTSET] = pop_SortMSTemplates(ALLEEG, %i, ''IgnorePolarity'', %i, ''TemplateSet'', ''manual'', ''Classes'', %i, ''SortOrder'', ' ...
        '%s, ''NewLabels'', %s, ''SortAll'', %i);'], SelectedSet, IgnorePolarity, nClasses, mat2str(SortOrder), NewLabelsTxt, SortAll);
end

function MSMaps = sortAllSolutions(MSMaps, ClassRange, nClasses, IgnorePolarity)    
    % If the template set has unassigned maps, remove them (only base 
    % sorting on assigned maps)
    TemplateMaps = MSMaps(nClasses).Maps;
    nAssignedLabels = sum(~arrayfun(@(x) all(MSMaps(nClasses).ColorMap(x,:) == [.75 .75 .75]), 1:nClasses));
    if nAssignedLabels < nClasses
        TemplateMaps(nAssignedLabels+1:end,:) = [];
    end

    for i=ClassRange
        if i == nClasses
            continue
        end        

        [SortedMaps, SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps, TemplateMaps, ~IgnorePolarity);
        MSMaps(i).Maps = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps), 2));

        [Labels, Colors] = UpdateMicrostateLabels(MSMaps(i).Labels, MSMaps(nClasses).Labels, SortOrder, MSMaps(nClasses).ColorMap);
        MSMaps(i).Labels = Labels(1:i);
        MSMaps(i).ColorMap = Colors(1:i, :);
        MSMaps(i).SortMode = [MSMaps(nClasses).SortMode '->alternate solution in set'];
        MSMaps(i).SortedBy = sprintf('%s->this set (%i classes)', MSMaps(nClasses).SortedBy, nClasses);
        MSMaps(i).SpatialCorrelation = SpatialCorrelation;
        MSMaps(i).ExpVar = MSMaps(i).ExpVar(SortOrder(SortOrder <= i));

        if i > nClasses+1
            [SortedMaps, SortOrder, ~, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps((nClasses+1):end,:), MSMaps(i-1).Maps((nClasses+1):end,:), ~IgnorePolarity);
            MSMaps(i).Maps((nClasses+1):end,:) = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps),2));
            MSMaps(i).Labels((nClasses+1):end) = arrayfun(@(x) sprintf('MS_%i.%i', i, nClasses+x), 1:(i-nClasses), 'UniformOutput', false);
            endExpVar = MSMaps(i).ExpVar((nClasses+1):end);
            MSMaps(i).ExpVar((nClasses+1):end) = endExpVar(SortOrder);
        end
    end
end

function solutionChanged(~, ~, fig)
    ud = fig.UserData;
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