function [AllEEG, EEGout, CurrentSet, com] = InteractiveSort(AllEEG, SelectedSet)
    
    EEGout = AllEEG(SelectedSet);
    CurrentSet = SelectedSet;
    com = '';
    Classes = AllEEG(SelectedSet).msinfo.ClustPar.MinClasses:AllEEG(SelectedSet).msinfo.ClustPar.MaxClasses;

    % Compute initial figure size and whether scrolling is needed
    % (for larger number of solutions/maps)
    minGridHeight = 90;     
    minGridWidth = 60;    
    expVarWidth = 55;
    mapPanelNormHeight = .75;
    mapPanelNormWidth = .98;
    nRows = numel(Classes);
    nCols = max(Classes);          

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

    ud.minPanelWidth = expVarWidth + minGridWidth*nCols;
    ud.minPanelHeight = minGridHeight*nRows;

    ud.Scroll = false;
    % Use scrolling and uifigure for large number of maps
    if ud.minPanelWidth > figSize(3)*mapPanelNormWidth || ud.minPanelHeight > figSize(4)*mapPanelNormHeight
        ud.Scroll = true;
        fig_h = uifigure('Name', ['Microstate maps of ' AllEEG(SelectedSet).setname], 'Units', 'pixels', ...
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
        fig_h = figure('NumberTitle', 'off', 'WindowStyle', 'modal', ...
            'Name', ['Microstate maps of ' AllEEG(SelectedSet).setname], 'Position', figSize);
    end           
    if ud.Scroll
        fig_h.Resize = 'off';
    end

    ud.Visible = true;
    ud.AllMaps = AllEEG(SelectedSet).msinfo.MSMaps;
    ud.chanlocs = AllEEG(SelectedSet).chanlocs;
    ud.setname = AllEEG(SelectedSet).setname;
    ud.ClustPar = AllEEG(SelectedSet).msinfo.ClustPar;
    ud.wasSorted = false;
    ud.SelectedSet = SelectedSet;
    ud.com = '';
    if isfield(AllEEG(SelectedSet).msinfo, 'children')
        ud.Children = AllEEG(SelectedSet).msinfo.children;
    else
        ud.Children = [];
    end
    ud.Edit = true;

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

    [ud.MeanIdx, ud.MeanNames] = FindParentSets(AllEEG, ud.SelectedSet);
    [ud.TemplateNames, ud.TemplateDisplayNames] = getTemplateNames();

    % Build figure
    fig_h.UserData = ud;
    if ud.Scroll
        buildUIFig(fig_h, AllEEG);
    else
        buildFig(fig_h, AllEEG);
    end
    fig_h.CloseRequestFcn = {@figClose, fig_h};                            
    PlotMSMaps(fig_h, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    if ~isvalid(fig_h)
        return
    end
    
    uiwait();
    if ~isvalid(fig_h)
        return
    end
    ud = fig_h.UserData;
    delete(fig_h);

    if ud.wasSorted
        hasChildren = ~isempty(ud.Children);
        [yesPressed, selection] = questDlg(hasChildren);

        if yesPressed
            AllEEG(SelectedSet).msinfo.MSMaps = ud.AllMaps;                                        
            AllEEG(SelectedSet).saved = 'no';
            EEGout = AllEEG(SelectedSet);
            CurrentSet = SelectedSet;
            com = ud.com;

            sortCom = '';
            if hasChildren            
                if strcmp(selection, 'Clear dependent sorting')
                    AllEEG = ClearDataSortedByParent(AllEEG, AllEEG(SelectedSet).msinfo.children);
                elseif strcmp(selection, 'Sort dependent sets by this set')
                    childIdx = FindChildSets(AllEEG, SelectedSet);
                    if ~isempty(childIdx)
                        IgnorePolarity = AllEEG(SelectedSet).msinfo.ClustPar.IgnorePolarity;
                        Classes = AllEEG(SelectedSet).msinfo.ClustPar.MinClasses:AllEEG(SelectedSet).msinfo.ClustPar.MaxClasses;
                        [AllEEG, childEEG, childIdx, sortCom] = pop_SortMSTemplates(AllEEG, childIdx, 'TemplateSet', SelectedSet, ...
                            'IgnorePolarity', IgnorePolarity, 'Classes', Classes);
                        AllEEG = eeg_store(AllEEG, childEEG, childIdx);
                    else
                        disp('Could not find dependent sets for resorting');
                    end
                end
            end

            if ~isempty(sortCom)
                com = [com newline sortCom];
            end
        else
            disp('Changes abandoned');
        end                
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
    
    ud.MapPanel = uipanel(fig_h, 'Position', [.01 .21 .98 .75]);
    panel1 = uipanel(fig_h, 'Units', 'normalized', 'Position', [.01 .005 .44 .195]);
    panel2 = uipanel(fig_h, 'Units', 'normalized', 'Position', [.453 .005 .445 .195]);
    
    uicontrol(panel1, 'Style', 'Text', 'String', 'Sorting procedure', 'Units', 'normalized', 'Position', [.005 .6 .2 .33], 'HorizontalAlignment', 'left');
    Actions = {'1) Reorder maps in selected solution manually by map index','2) Reorder maps in selected solution(s) based on template set'};               
    if (ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses) >= 1
        Actions = [Actions '3) Use selected solution to reorder all other solutions','4) First 1), then 3)', '5) First 2), then 3)'];
    end
    ud.ActChoice = uicontrol(panel1, 'Style', 'popupmenu','String', Actions, 'Units','Normalized','Position', [.2 .8 .785 .15], 'Callback',{@ActionChangedCallback,fig_h});
    
    uicontrol(panel1, 'Style', 'Text', 'String', 'Solution(s) to sort', 'Units', 'normalized', 'Position', [.005 .05 .2 .4], 'HorizontalAlignment', 'left');    
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uicontrol(panel1, 'Style', 'listbox','String', AvailableClassesText, 'Units','Normalized','Position', [.2 .05 .785 .65], 'Callback',{@solutionChanged, fig_h}, 'Min', 0, 'Max', 1);
    
    ud.OrderTxt = uicontrol(panel2, 'Style', 'Text', 'String', 'Sort Order (negative to flip polarity)', 'Units', 'normalized', 'Position', [.01 .6 .34 .32], 'HorizontalAlignment', 'left');
    ud.OrderEdit = uicontrol(panel2, 'Style', 'edit', 'String', "", 'Units', 'normalized', 'Position', [.35 .78 .64 .18]);
    
    ud.SelTemplateLabel = uicontrol(panel2, 'Style', 'Text', 'String', 'Select template set', 'Units', 'normalized', 'Position', [.01 .38 .25 .26], 'Visible', 'off', 'HorizontalAlignment', 'left');    
    ud.SelTemplate = uicontrol(panel2, 'Style', 'popupmenu', 'String', [ud.MeanNames ud.TemplateDisplayNames], 'Units', 'normalized', 'Position', [.27 .55 .72 .1], 'Visible', 'off');
    
    ud.LabelsTxt = uicontrol(panel2, 'Style', 'Text', 'String', 'New Labels', 'Units', 'normalized', 'Position', [.01 .38 .2 .23], 'HorizontalAlignment', 'left');
    ud.LabelsEdit = uicontrol(panel2, 'Style', 'Edit', 'String', "", 'Units', 'normalized', 'Position', [.35 .45 .64 .18]);
    
    ud.IgnorePolarity = uicontrol(panel2, 'Style', 'checkbox', 'String', ' Ignore Polarity', 'Value', 1, 'Units', 'normalized', 'Position', [.01 .27 .99 .15], 'Visible', 'off');
    
    uicontrol(panel2, 'Style', 'pushbutton', 'String', 'Sort', 'Units', 'normalized', 'Position', [.01 .01 .98 .2], 'Callback', {@Sort, fig_h, AllEEG});
    
    ud.Info    = uicontrol(fig_h, 'Style', 'pushbutton','String', 'Info'    , 'Units','Normalized','Position', [.9 .155 .09 .045], 'Callback', {@MapInfo, fig_h});                
    ud.ShowDyn = uicontrol(fig_h, 'Style', 'pushbutton','String', 'Dynamics', 'Units','Normalized','Position', [.9 .105 .09 .045], 'Callback', {@ShowDynamics, fig_h, AllEEG}, 'Enable', DynEnable);
    ud.Compare = uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Compare', 'Units','Normalized','Position', [.9 .055 .09 .045], 'Callback', {@CompareCallback, fig_h, AllEEG});
    ud.Done    = uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Close'  , 'Units','Normalized','Position', [.9 .005 .09 .045], 'Callback', {@figClose,fig_h});
    
    fig_h.UserData = ud;

    solutionChanged([], [], fig_h);
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
    
    ud.MapPanel.Scrollable = 'on';
    ud.TilePanel = uipanel(ud.MapPanel, 'Units', 'pixels', 'Position', [0 0 ud.minPanelWidth ud.minPanelHeight], 'BorderType', 'none');
    
    ud.SortLayout = uigridlayout(ud.FigLayout, [4 5]);
    ud.SortLayout.Padding = [0 0 0 0];
    ud.SortLayout.ColumnWidth = {110, '1x', 210, '1x', 150};
    ud.SortLayout.RowSpacing = 5;
    
    uilabel(ud.SortLayout, 'Text', 'Sorting procedure');
    Actions = {'1) Reorder maps in selected solution manually by map index','2) Reorder maps in selected solution(s) based on template set'};               
    if (ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses) >= 1
        Actions = [Actions '3) Use selected solution to reorder all other solutions','4) First 1), then 3)', '5) First 2), then 3)'];
    end
    ud.ActChoice = uidropdown(ud.SortLayout, 'Items', Actions, 'ItemsData', 1:numel(Actions), 'ValueChangedFcn', {@ActionChangedCallback, fig_h});
    
    classLabel = uilabel(ud.SortLayout, 'Text', 'Solution(s) to sort');
    classLabel.Layout.Row = [2 4];
    classLabel.Layout.Column = 1;
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uilistbox(ud.SortLayout, 'Items', AvailableClassesText, 'ItemsData', ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses, 'ValueChangedFcn', {@solutionChanged, fig_h}, 'Multiselect', 'off');
    ud.ClassList.Layout.Row = [2 4];
    ud.ClassList.Layout.Column = 2;
    
    ud.OrderTxt = uilabel(ud.SortLayout, 'Text', 'Sort Order (negative to flip polarity)');
    ud.OrderTxt.Layout.Row = 1;
    ud.OrderTxt.Layout.Column = 3;
    ud.OrderEdit = uieditfield(ud.SortLayout);
    ud.OrderEdit.Layout.Row = 1;
    ud.OrderEdit.Layout.Column = 4;
    
    ud.LabelsTxt = uilabel(ud.SortLayout, 'Text', 'New Labels');
    ud.LabelsTxt.Layout.Row = 2;
    ud.LabelsTxt.Layout.Column = 3;
    ud.LabelsEdit = uieditfield(ud.SortLayout);
    ud.LabelsEdit.Layout.Row = 2;
    ud.LabelsEdit.Layout.Column = 4;
    
    ud.IgnorePolarity = uicheckbox(ud.SortLayout, 'Text', 'Ignore Polarity', 'Value', true, 'Visible', 'off');
    ud.IgnorePolarity.Layout.Row = 3;
    ud.IgnorePolarity.Layout.Column = [3 4];
    
    sortBtn = uibutton(ud.SortLayout, 'Text', 'Sort', 'ButtonPushedFcn', {@Sort,fig_h, AllEEG});
    sortBtn.Layout.Row = 4;
    sortBtn.Layout.Column = [3 4];
    
    ud.Info = uibutton(ud.SortLayout, 'Text', 'Info', 'ButtonPushedFcn', {@MapInfo, fig_h});
    ud.Info.Layout.Row = 1;
    ud.Info.Layout.Column = 5;
    ud.ShowDyn = uibutton(ud.SortLayout, 'Text', 'Dynamics', 'ButtonPushedFcn', {@ShowDynamics, fig_h, AllEEG}, 'Enable', DynEnable);
    ud.ShowDyn.Layout.Row = 2;
    ud.ShowDyn.Layout.Column = 5;
    ud.Compare = uibutton(ud.SortLayout, 'Text', 'Compare maps', 'ButtonPushedFcn', {@CompareCallback, fig_h, AllEEG});
    ud.Compare.Layout.Row = 3;
    ud.Compare.Layout.Column = 5;
    ud.Done = uibutton(ud.SortLayout, 'Text', 'Close', 'ButtonPushedFcn', {@figClose, fig_h});
    ud.Done.Layout.Row = 4;
    ud.Done.Layout.Column = 5;
    
    fig_h.Resize = 'off';
    
    fig_h.UserData = ud;
    
    solutionChanged([], [], fig_h);
end

function [yesPressed, selection] = questDlg(showOptions)
    
    yesPressed = false;
    selection = [];

    questDlg = figure('Name', 'Edit & sort template maps', 'NumberTitle', 'off', ...
        'Color', [.66 .76 1], 'WindowStyle', 'modal', 'MenuBar', 'none', 'ToolBar', 'none');
    questDlg.Position(3:4) = [500 190];
    questDlg.UserData.yesPressed = yesPressed;
    questDlg.UserData.selection = selection;
    questDlg.CloseRequestFcn = 'uiresume()';

    uicontrol(questDlg, 'Style', 'text', 'String', 'Update dataset with sorted maps?', ...
        'Units', 'normalized', 'Position', [.05 .7 .9 .15], 'FontSize', 12, 'BackgroundColor', [.66 .76 1]);
    if showOptions
        questDlg.UserData.bg = uibuttongroup(questDlg, 'Units', 'normalized', 'Position', [.05 .3 .9 .4], 'BackgroundColor', [.66 .76 1], 'BorderType', 'none');
        uicontrol(questDlg.UserData.bg, 'Style', 'radiobutton', 'String', 'Sort dependent sets by this set', 'Units', 'normalized', ...
            'Position', [.05 .5 .9 .4], 'BackgroundColor', [.66 .76 1], 'FontSize', 12);
        uicontrol(questDlg.UserData.bg, 'Style', 'radiobutton', 'String', 'Clear dependent sorting', 'Units', 'normalized', ...
            'Position', [.05 .1 .9 .4], 'BackgroundColor', [.66 .76 1], 'FontSize', 12);
    end
    uicontrol(questDlg, 'Style', 'pushbutton', 'String', 'Yes', 'Units', 'normalized', ...
        'Position', [.25 .1 .2 .17], 'Callback', {@btnPressed, questDlg});
    uicontrol(questDlg, 'Style', 'pushbutton', 'String', 'No', 'Units', 'normalized', ...
        'Position', [.55 .1 .2 .17], 'Callback', {@btnPressed, questDlg});

    uiwait(questDlg);

    yesPressed = questDlg.UserData.yesPressed;
    selection = questDlg.UserData.selection;

    delete(questDlg);
    
    function btnPressed(src, event, fig)
        if strcmp(src.String, 'Yes')
            fig.UserData.yesPressed = true;
        end
         
        if isfield(fig.UserData, 'bg')
            fig.UserData.selection = fig.UserData.bg.SelectedObject.String;
        end

        uiresume(fig);
    end
end

%% GUI CALLBACKS %%

function figClose(~,~,fh)
    ud = fh.UserData;
    
    if isfield(ud,"CompFigHandle")
        if isvalid(ud.CompFigHandle)
            close(ud.CompFigHandle);
        end
    end
    
    uiresume();
end

function solutionChanged(~, ~, fig)
    ud = fig.UserData;        

    if (ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses) >= 1
        if ud.ActChoice.Value ~= 1 && ud.ActChoice.Value ~= 4
            return;
        end
    else
        if ud.ActChoice.Value ~= 1
            return;
        end
    end

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

function ActionChangedCallback(~,~,fh)
    ud = fh.UserData;    
   
    choice = ud.ActChoice.Value;
    if (ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses) >= 1        
        manualSort = (choice == 1) | (choice == 4);
        templateSort = (choice == 2) | (choice == 5);
        showPolarity = choice ~= 1;
        multiSelect = choice == 2;
    else
        manualSort = choice == 1;
        templateSort = ~manualSort;
        showPolarity = templateSort;
        multiSelect = templateSort;
    end

    if manualSort
        ud.OrderTxt.Visible = 'on';
        ud.OrderEdit.Visible = 'on';
        ud.OrderEdit.Enable = 'on';

        if ud.Scroll                      
            if ~isfield(ud, 'LabelsEdit') || ~isvalid(ud.LabelsEdit)   
                ud.LabelsTxt = uilabel(ud.SortLayout, 'Text', 'New Labels');
                ud.LabelsTxt.Layout.Row = 2;
                ud.LabelsTxt.Layout.Column = 3;
                ud.LabelsEdit = uieditfield(ud.SortLayout);
                ud.LabelsEdit.Layout.Row = 2;
                ud.LabelsEdit.Layout.Column = 4;                                           
            end 
        else
            ud.LabelsTxt.Visible = 'on';
            ud.LabelsEdit.Visible = 'on';
            ud.LabelsEdit.Enable = 'on';            
        end        
    else
        ud.OrderTxt.Visible = 'off';
        ud.OrderEdit.Visible = 'off';
        ud.OrderEdit.Enable = 'off';
        
        if ud.Scroll
            if isfield(ud, 'LabelsEdit')
                delete(ud.LabelsEdit);
                delete(ud.LabelsTxt);
            end
        else
            ud.LabelsTxt.Visible = 'off';
            ud.LabelsEdit.Visible = 'off';
            ud.LabelsEdit.Enable = 'off';
        end
    end

    if templateSort
        if ud.Scroll            
            if ~isfield(ud, 'SelTemplate') || ~isvalid(ud.SelTemplate)
                ud.SelTemplateLabel = uilabel(ud.SortLayout, 'Text', 'Select template set');                
                ud.SelTemplateLabel.Layout.Row = 2;
                ud.SelTemplateLabel.Layout.Column = 3;
                ud.SelTemplate = uidropdown(ud.SortLayout, 'Items', [ud.MeanNames ud.TemplateDisplayNames], 'ItemsData', [num2cell(ud.MeanIdx) ud.TemplateNames]);
                ud.SelTemplate.Layout.Row = 2;
                ud.SelTemplate.Layout.Column = 4;
            end            
        else           
            ud.SelTemplateLabel.Visible = 'on';
            ud.SelTemplate.Visible = 'on';
            ud.SelTemplate.Enable = 'on';                     
        end
    else
        if ud.Scroll
            if isfield(ud, 'SelTemplate')
                delete(ud.SelTemplateLabel);
                delete(ud.SelTemplate);
            end
        else
            ud.SelTemplateLabel.Visible = 'off';
            ud.SelTemplate.Visible = 'off';
            ud.SelTemplate.Enable = 'off';            
        end
    end

    if showPolarity
        ud.IgnorePolarity.Visible = 'on';
        ud.IgnorePolarity.Enable = 'on';
    else
        ud.IgnorePolarity.Visible = 'off';
        ud.IgnorePolarity.Enable = 'off';
    end

    if multiSelect
        if ud.Scroll
            ud.ClassList.Multiselect = 'on';
        else
            ud.ClassList.Max = 2;        
        end
    else
        if numel(ud.ClassList.Value) > 1
            ud.ClassList.Value = ud.ClassList.Value(end);
        end
        if ud.Scroll
            ud.ClassList.Multiselect = 'off';
        else
            ud.ClassList.Max = 1;
        end
    end

    fh.UserData = ud;    
    solutionChanged([], [], fh);
end

%% SORTING %%
function Sort(~,~,fh,AllEEG)
    ud = fh.UserData;

    AllEEG(ud.SelectedSet).msinfo.MSMaps = fh.UserData.AllMaps;
    nClasses = ud.ClassList.Value;  
    if ~ud.Scroll
        nClasses = ud.ClustPar.MinClasses + nClasses - 1;
    end

    choice = ud.ActChoice.Value;
    if (ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses) >= 1
        manualSort = (choice == 1) | (choice == 4);
        templateSort = (choice == 2) | (choice == 5);
        SortAll = (choice == 3) | (choice == 4) | (choice == 5);
    else
        manualSort = (choice == 1);
        templateSort = ~manualSort;
        SortAll = false;
    end

    if manualSort
        if ud.Scroll
            SortOrder = sscanf(ud.OrderEdit.Value, '%i')';
            NewLabels = split(ud.LabelsEdit.Value)';
        else
            SortOrder = sscanf(ud.OrderEdit.String, '%i')';
            NewLabels = split(ud.LabelsEdit.String)';
        end
        NewLabels = NewLabels(~cellfun(@isempty, NewLabels));

        [~, EEGout, ~, com] = pop_SortMSTemplates(AllEEG, ud.SelectedSet, 'TemplateSet', 'manual', 'SortOrder', SortOrder, 'NewLabels', NewLabels, 'Classes', nClasses, 'SortAll', SortAll);
    elseif templateSort
        IgnorePolarity = ud.IgnorePolarity.Value;

        if ud.Scroll
            TemplateSet = ud.SelTemplate.Value;
        else
            if ud.SelTemplate.Value <= numel(ud.MeanIdx)
                TemplateSet = ud.MeanIdx(ud.SelTemplate.Value);
            else
                TemplateSet = ud.TemplateNames{ud.SelTemplate.Value - numel(ud.MeanIdx)};
            end
        end

        [~, EEGout, ~, com] = pop_SortMSTemplates(AllEEG, ud.SelectedSet, 'IgnorePolarity', IgnorePolarity, 'TemplateSet', TemplateSet, 'Classes', nClasses, 'SortAll', SortAll);
    else
        IgnorePolarity = ud.IgnorePolarity.Value;

        [~, EEGout, ~, com] = pop_SortMSTemplates(AllEEG, ud.SelectedSet, 'IgnorePolarity', IgnorePolarity, 'TemplateSet', 'manual', 'SortOrder', 1:nClasses, 'NewLabels', ud.AllMaps(nClasses).Labels, 'Classes', nClasses, 'SortAll', true);
    end  

    fh.UserData.AllMaps = EEGout.msinfo.MSMaps;
    if isempty(fh.UserData.com)
        fh.UserData.com = com;
    elseif ~isempty(com)
        fh.UserData.com = [fh.UserData.com newline com];
    end
    fh.UserData.wasSorted = true;

    solutionChanged([], [], fh);

    if SortAll
        PlotMSMaps(fh, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
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
    
    if isempty(fh.UserData.Children)
        [EEGout, ~, com] = pop_CompareMSTemplates(AllEEG, 'IndividualSets', fh.UserData.SelectedSet);
    else
        [EEGout, ~, com] = pop_CompareMSTemplates(AllEEG, 'MeanSets', fh.UserData.SelectedSet);
    end

    % If the command contains sorting function calls, we should replot the maps
    if contains(com, 'pop_Sort')
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
