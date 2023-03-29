function [AllEEG, EEGout, CurrentSet, com] = InteractiveSort(AllEEG, SelectedSet)
    
    EEGout = AllEEG(SelectedSet);
    CurrentSet = SelectedSet;
    com = '';
    Classes = AllEEG(SelectedSet).msinfo.ClustPar.MinClasses:AllEEG(SelectedSet).msinfo.ClustPar.MaxClasses;

    % Compute initial figure size and whether scrolling is needed
    % (for larger number of solutions/maps)
    minGridHeight = 80;     
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
    
    ActionChangedCallback([],[],fig_h,AllEEG);
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
        else
            disp('Changes abandoned');
        end

        sortCom = '';
        if hasChildren            
            if strcmp(selection, 'Clear dependent sorting')
                AllEEG = ClearDataSortedByParent(AllEEG, AllEEG(SelectedSet).msinfo.children);
            elseif strcmp(selection, 'Sort dependent sets by this set')
                childIdx = FindChildSets(AllEEG, SelectedSet);
                IgnorePolarity = AllEEG(SelectedSet).msinfo.ClustPar.IgnorePolarity;
                Classes = AllEEG(SelectedSet).msinfo.ClustPar.MinClasses:AllEEG(SelectedSet).msinfo.ClustPar.MaxClasses;
                [AllEEG, childEEG, childIdx, sortCom] = pop_SortMSTemplates(AllEEG, childIdx, 'TemplateSet', SelectedSet, ...
                    'IgnorePolarity', IgnorePolarity, 'Classes', Classes);
                AllEEG = eeg_store(AllEEG, childEEG, childIdx);
            end
        end

        if ~isempty(sortCom)
            com = [com newline sortCom];
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
    
    ud.MapPanel = uipanel(fig_h, 'Position', [.01 .21 .98 .75], 'BorderType', 'line');
    
    uicontrol(fig_h, 'Style', 'Text', 'String', 'Select solution(s) to sort', 'Units', 'normalized', 'Position', [.01 .17 .12 .03], 'HorizontalAlignment', 'left');    
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uicontrol(fig_h, 'Style', 'listbox','String', AvailableClassesText, 'Units','Normalized','Position', [.01 .01 0.12 .16], 'Callback',{@solutionChanged, fig_h}, 'Min', 0, 'Max', 1);
    
    uicontrol(fig_h, 'Style', 'Text', 'String', 'Choose sorting procedure', 'Units', 'normalized', 'Position', [.14 .155 .17 .04], 'HorizontalAlignment', 'left');
    Actions = {'1) Reorder maps in selected solution manually by map index','2) Reorder maps in selected solution(s) based on template set','3) Use selected solution to reorder all other solutions','4) First 1), then 3)', '5) First 2), then 3)'};               
    ud.ActChoice = uicontrol(fig_h, 'Style', 'popupmenu','String', Actions, 'Units','Normalized','Position', [.31 .16 .48 .04], 'Callback',{@ActionChangedCallback,fig_h,AllEEG});

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
    ud.Done    = uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Close'  , 'Units','Normalized','Position', [.8 .005 .19 .045], 'Callback', {@figClose,fig_h});

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
    SelLayout.ColumnWidth = {150, '1x', 200};

    SolutionLayout = uigridlayout(SelLayout, [2 1]);
    SolutionLayout.Padding = [0 0 0 0];
    SolutionLayout.RowHeight = {15, '1x'};

    uilabel(SolutionLayout, 'Text', 'Select solution(s) to sort');
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uilistbox(SolutionLayout, 'Items', AvailableClassesText, 'ItemsData', ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses, 'ValueChangedFcn', {@solutionChanged, fig_h}, 'Multiselect', 'off');
    
    SortLayout = uigridlayout(SelLayout, [4 1]);
    SortLayout.RowSpacing = 8;
    SortLayout.Padding = [0 0 0 0];

    actLayout = uigridlayout(SortLayout, [1 2]);
    actLayout.Padding = [0 0 0 0];
    actLayout.ColumnSpacing = 0;
    actLayout.ColumnWidth = {210, '1x'};

    uilabel(actLayout, 'Text', 'Choose sorting procedure');
    Actions = {'1) Reorder maps in selected solution manually by map index','2) Reorder maps in selected solution(s) based on template set','3) Use selected solution to reorder all other solutions','4) First 1), then 3)', '5) First 2), then 3)'};               
    ud.ActChoice = uidropdown(actLayout, 'Items', Actions, 'ItemsData', 1:5, 'ValueChangedFcn', {@ActionChangedCallback, fig_h, AllEEG});

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
    ud.Done = uibutton(BtnLayout, 'Text', 'Close', 'ButtonPushedFcn', {@figClose, fig_h});

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

function ActionChangedCallback(~,~,fh,AllEEG)
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
                    [MeanSetIdx, MeanNames] = FindParentSets(AllEEG, UserData.SelectedSet);
                    [TemplateNames, TemplateDisplayNames] = getTemplateNames();
                    UserData.SelTemplate = uidropdown(UserData.OrderLayout, 'Items', [MeanNames TemplateDisplayNames], 'ItemsData', [num2cell(MeanSetIdx) TemplateNames]);
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
    
                [~, MeanNames] = FindParentSets(AllEEG, UserData.SelectedSet);
                [~, TemplateDisplayNames] = getTemplateNames();
                UserData.SelTemplate.String = [MeanNames TemplateDisplayNames];

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

            [~, EEGout, ~, com] = pop_SortMSTemplates(AllEEG, UserData.SelectedSet, 'TemplateSet', 'manual', 'SortOrder', SortOrder, 'NewLabels', NewLabels, 'Classes', nClasses, 'SortAll', SortAll);
            
        case {2, 5}
            IgnorePolarity = UserData.IgnorePolarity.Value;

            if UserData.Scroll
                TemplateSet = UserData.SelTemplate.Value;
            else
                MeanIdx = FindParentSets(AllEEG, UserData.SelectedSet);
                TemplateNames = getTemplateNames();
                if UserData.SelTemplate.Value <= numel(MeanIdx)
                    TemplateSet = MeanIdx(UserData.SelTemplate.Value);
                else
                    TemplateSet = TemplateNames{UserData.SelTemplate.Value - numel(MeanIdx)};
                end
            end

            [~, EEGout, ~, com] = pop_SortMSTemplates(AllEEG, UserData.SelectedSet, 'IgnorePolarity', IgnorePolarity, 'TemplateSet', TemplateSet, 'Classes', nClasses, 'SortAll', SortAll);
            
        case 3
            IgnorePolarity = UserData.IgnorePolarity.Value;

            [~, EEGout, ~, com] = pop_SortMSTemplates(AllEEG, UserData.SelectedSet, 'IgnorePolarity', IgnorePolarity, 'TemplateSet', 'manual', 'SortOrder', 1:nClasses, 'NewLabels', UserData.AllMaps(nClasses).Labels, 'Classes', nClasses, 'SortAll', true);          
    end

    fh.UserData.AllMaps = EEGout.msinfo.MSMaps;
    if isempty(fh.UserData.com)
        fh.UserData.com = com;
    elseif ~isempty(com)
        fh.UserData.com = [fh.UserData.com newline com];
    end
    fh.UserData.wasSorted = true;

    ActionChangedCallback([], [], fh, AllEEG);

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
    
    if isempty(fh.UserData.Children)
        [EEGout, ~, com] = pop_CompareMSTemplates(AllEEG, fh.UserData.SelectedSet, [], []);
    else
        [EEGout, ~, com] = pop_CompareMSTemplates(AllEEG, [], fh.UserData.SelectedSet, []);
    end

    % If the command contains sorting function calls, we should replot the maps
    if contains(com, 'pop_Sort')
        fh.UserData.AllMaps = EEGout.msinfo.MSMaps;
        fh.UserData.wasSorted = true;
        PlotMSMaps(fh, fh.UserData.ClustPar.MinClasses:fh.UserData.ClustPar.MaxClasses);  
        ActionChangedCallback([], [], fh, AllEEG);
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
