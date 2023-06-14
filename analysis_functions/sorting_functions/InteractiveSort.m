function [EEGout, CurrentSet, childIdx, childEEG, com] = InteractiveSort(AllEEG, SelectedSet)
    
    EEGout = AllEEG(SelectedSet);
    CurrentSet = SelectedSet;
    childIdx = [];
    childEEG = [];
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
    
    ud.minPanelWidth = expVarWidth + minGridWidth*nCols;
    ud.minPanelHeight = minGridHeight*nRows;
    
    ud.Scroll = false;
    % Use scrolling and uifigure for large number of maps
    if ud.minPanelWidth > figSize1(3)*mapPanelNormWidth || ud.minPanelHeight > figSize1(4)*mapPanelNormHeight
        ud.Scroll = true;
        fig_h = uifigure('Name', ['Microstate maps of ' AllEEG(SelectedSet).setname], 'Units', 'pixels', ...
            'Position', figSize2, 'MenuBar', 'none', 'ToolBar', 'none');
        if ud.minPanelWidth < fig_h.Position(3) - 20
            ud.minPanelWidth = fig_h.Position(3) - 50;
        end
        selPanelHeight = 175;       % combined height of button area and padding
        if ud.minPanelHeight < fig_h.Position(4) - selPanelHeight
            ud.minPanelHeight = fig_h.Position(4) - selPanelHeight - 30;
        end
    % Otherwise use a normal figure (faster rendering) 
    else
        fig_h = figure('NumberTitle', 'off', 'Name', ['Microstate maps of ' AllEEG(SelectedSet).setname], ...
            'Position', figSize1, 'MenuBar', 'figure', 'ToolBar', 'none');
    end           
    
    ud.MSMaps = AllEEG(SelectedSet).msinfo.MSMaps;
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
    
    for j = ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses    
        if isfield(ud.MSMaps(j),'Labels')
            if ~isempty(ud.MSMaps(j).Labels)
                continue
            end
        end 
        % Fill in generic labels if dataset does not have them
        for k = 1:j
            ud.MSMaps(j).Labels{k} = sprintf('MS_%i.%i',j,k);
        end
    end
    
    global MSTEMPLATE;
    [ud.MeanIdx, ud.MeanNames] = FindParentSets(AllEEG, ud.SelectedSet);
    [ud.TemplateNames, ud.TemplateDisplayNames, templateIdx] = getTemplateNames();
    meanMinClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MinClasses, ud.MeanIdx);
    tempMinClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MinClasses, templateIdx);
    meanMaxClasses = arrayfun(@(x) AllEEG(x).msinfo.ClustPar.MaxClasses, ud.MeanIdx);
    tempMaxClasses = arrayfun(@(x) MSTEMPLATE(x).msinfo.ClustPar.MaxClasses, templateIdx);
    ud.TemplateMinClasses = [ud.ClustPar.MinClasses meanMinClasses tempMinClasses];
    ud.TemplateMaxClasses = [ud.ClustPar.MaxClasses meanMaxClasses tempMaxClasses];
    
    % Build figure
    fig_h.UserData = ud;
    if ud.Scroll
        buildUIFig(fig_h, AllEEG);
    else
        buildFig(fig_h, AllEEG);
    end
    fig_h.CloseRequestFcn = {@figClose, fig_h};                            
    PlotMSMaps2(fig_h, fig_h.UserData.MapPanel, ud.MSMaps(ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses), ...
        ud.chanlocs, 'ShowExpVar', 1);
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
            AllEEG(SelectedSet).msinfo.MSMaps = ud.MSMaps;
            EEGout = AllEEG(SelectedSet);
            EEGout.saved = 'no';
            CurrentSet = SelectedSet;
            com = ud.com;
    
            sortCom = '';
            if hasChildren            
                childIdx = FindChildSets(AllEEG, SelectedSet);
                if strcmp(selection, 'Clear dependent sorting')
                    AllEEG = ClearDataSortedByParent(AllEEG, AllEEG(SelectedSet).msinfo.children);
                    childEEG = AllEEG(childIdx);
                elseif strcmp(selection, 'Sort dependent sets by this set')                    
                    if ~isempty(childIdx)
                        IgnorePolarity = AllEEG(SelectedSet).msinfo.ClustPar.IgnorePolarity;
                        Classes = AllEEG(SelectedSet).msinfo.ClustPar.MinClasses:AllEEG(SelectedSet).msinfo.ClustPar.MaxClasses;
                        [~, childEEG, childIdx, sortCom] = pop_SortMSMaps(AllEEG, childIdx, 'TemplateSet', SelectedSet, ...
                            'IgnorePolarity', IgnorePolarity, 'Classes', Classes);
                    else
                        disp('Could not find dependent sets for resorting');
                    end
                end
                for s=1:numel(childIdx)
                    childEEG(s).saved = 'no';
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
        Actions = [Actions '3) Use stepwise sorting to reorder all solutions by selected template solution'];
    end
    ud.ActChoice = uicontrol(panel1, 'Style', 'popupmenu','String', Actions, 'Units','Normalized','Position', [.2 .8 .785 .15], 'Callback',{@ActionChangedCallback,fig_h});
    
    uicontrol(panel1, 'Style', 'Text', 'String', 'Solution(s) to sort', 'Units', 'normalized', 'Position', [.005 .05 .2 .4], 'HorizontalAlignment', 'left');    
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uicontrol(panel1, 'Style', 'listbox','String', AvailableClassesText, 'Units','Normalized','Position', [.2 .05 .785 .65], 'Callback',{@solutionChanged, fig_h}, 'Min', 0, 'Max', 1);
    
    ud.OrderTxt = uicontrol(panel2, 'Style', 'Text', 'String', 'Sort Order (negative to flip polarity)', 'Units', 'normalized', 'Position', [.01 .6 .34 .32], 'HorizontalAlignment', 'left');
    ud.OrderEdit = uicontrol(panel2, 'Style', 'edit', 'String', "", 'Units', 'normalized', 'Position', [.35 .78 .64 .18]);    
    
    ud.LabelsTxt = uicontrol(panel2, 'Style', 'Text', 'String', 'New Labels', 'Units', 'normalized', 'Position', [.01 .38 .2 .23], 'HorizontalAlignment', 'left');
    ud.LabelsEdit = uicontrol(panel2, 'Style', 'Edit', 'String', "", 'Units', 'normalized', 'Position', [.35 .45 .64 .18]);

    ud.SelTemplateLabel = uicontrol(panel2, 'Style', 'Text', 'String', 'Select template set', 'Units', 'normalized', 'Position', [.01 .6 .3 .3], 'Visible', 'off', 'HorizontalAlignment', 'left');    
    ud.SelTemplate = uicontrol(panel2, 'Style', 'popupmenu', 'String', ['Own' ud.MeanNames ud.TemplateDisplayNames], 'Units', 'normalized', 'Position', [.31 .82 .68 .1], 'Visible', 'off', 'Callback', {@templateSetChanged, fig_h});

    ud.SelClassesLabel = uicontrol(panel2, 'Style', 'Text', 'String', 'Select template solution', 'Units', 'normalized', 'Position', [.01 .38 .3 .26], 'Visible', 'off', 'HorizontalAlignment', 'left');
    ud.SelClasses = uicontrol(panel2, 'Style', 'popupmenu', 'String', '', 'Units', 'normalized', 'Position', [.31 .56 .68 .1], 'Visible', 'off', 'HorizontalAlignment', 'left');
    
    ud.IgnorePolarity = uicontrol(panel2, 'Style', 'checkbox', 'String', ' Ignore Polarity', 'Value', 1, 'Units', 'normalized', 'Position', [.01 .27 .99 .15], 'Visible', 'off');
    
    uicontrol(panel2, 'Style', 'pushbutton', 'String', 'Sort', 'Units', 'normalized', 'Position', [.01 .01 .98 .2], 'Callback', {@Sort, fig_h, AllEEG});
    
    ud.Info    = uicontrol(fig_h, 'Style', 'pushbutton','String', 'Info'    , 'Units','Normalized','Position', [.9 .14 .09 .06], 'Callback', {@MapInfo, fig_h});                
    ud.Compare = uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Compare', 'Units','Normalized','Position', [.9 .0725 .09 .06], 'Callback', {@CompareCallback, fig_h, AllEEG});
    ud.Done    = uicontrol(fig_h, 'Style', 'pushbutton', 'String', 'Save'  , 'Units','Normalized','Position', [.9 .005 .09 .06], 'Callback', {@figClose,fig_h});
    
    fig_h.UserData = ud;

    solutionChanged([], [], fig_h);
end

function buildUIFig(fig_h, AllEEG)
    ud = fig_h.UserData;

    warning('off', 'MATLAB:hg:uicontrol:StringMustBeNonEmpty');
    
    ud.FigLayout = uigridlayout(fig_h, [3 1]);
    ud.FigLayout.RowHeight = {15, '1x', 120};
    
    if isempty(ud.Children)
        uilabel(ud.FigLayout, 'Text', 'Left: total explained variance per solution. Subtitles: individual explained variance per map.');
    else
        uilabel(ud.FigLayout, 'Text', 'Left: mean shared variance per solution across maps. Subtitles: mean shared variance between individual and mean maps.');
    end                    
    
    OuterPanel = uipanel(ud.FigLayout);    
    OuterPanel.Scrollable = 'on';
    ud.MapPanel = uipanel(OuterPanel, 'Units', 'pixels', 'Position', [0 0 ud.minPanelWidth ud.minPanelHeight], 'BorderType', 'none');
    
    vertLayout = uigridlayout(ud.FigLayout, [1 2]);
    vertLayout.Padding = [0 0 0 0];
    vertLayout.ColumnWidth = {'1x', 150};
    ud.SortLayout = uigridlayout(vertLayout, [4 4]);
    ud.SortLayout.Padding = [0 0 0 0];
    ud.SortLayout.ColumnWidth = {110, '1x', 210, '1x'};
    ud.SortLayout.RowSpacing = 5;
    
    uilabel(ud.SortLayout, 'Text', 'Sorting procedure');
    Actions = {'1) Reorder maps in selected solution manually by map index','2) Reorder maps in selected solution(s) based on template set'};               
    if (ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses) >= 1
        Actions = [Actions '3) Use stepwise sorting to reorder all solutions by selected template solution'];
    end
    ud.ActChoice = uidropdown(ud.SortLayout, 'Items', Actions, 'ItemsData', 1:numel(Actions), 'ValueChangedFcn', {@ActionChangedCallback, fig_h});
    
    classLabel = uilabel(ud.SortLayout, 'Text', 'Solution(s) to sort');
    classLabel.Layout.Row = [2 4];
    classLabel.Layout.Column = 1;
    AvailableClassesText = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uilistbox(ud.SortLayout, 'Items', AvailableClassesText, 'ItemsData', 1:length(AvailableClassesText), 'ValueChangedFcn', {@solutionChanged, fig_h}, 'Multiselect', 'off');
    ud.ClassList.Layout.Row = [2 4];
    ud.ClassList.Layout.Column = 2;
    
    ud.Label1 = uilabel(ud.SortLayout, 'Text', 'Sort Order (negative to flip polarity)');
    ud.Label1.Layout.Row = 1;
    ud.Label1.Layout.Column = 3;
    ud.Edit1 = uieditfield(ud.SortLayout);
    ud.Edit1.Layout.Row = 1;
    ud.Edit1.Layout.Column = 4;
    
    ud.Label2 = uilabel(ud.SortLayout, 'Text', 'New Labels');
    ud.Label2.Layout.Row = 2;
    ud.Label2.Layout.Column = 3;
    ud.Edit2 = uieditfield(ud.SortLayout);
    ud.Edit2.Layout.Row = 2;
    ud.Edit2.Layout.Column = 4;
    
    ud.IgnorePolarity = uicheckbox(ud.SortLayout, 'Text', 'Ignore Polarity', 'Value', true, 'Visible', 'off');
    ud.IgnorePolarity.Layout.Row = 3;
    ud.IgnorePolarity.Layout.Column = [3 4];
    
    sortBtn = uibutton(ud.SortLayout, 'Text', 'Sort', 'ButtonPushedFcn', {@Sort,fig_h, AllEEG});
    sortBtn.Layout.Row = 4;
    sortBtn.Layout.Column = [3 4];
    
    btnLayout = uigridlayout(vertLayout, [3 1]);
    btnLayout.Padding = [0 0 0 0];
    btnLayout.RowSpacing = 7;
    ud.Info = uibutton(btnLayout, 'Text', 'Info', 'ButtonPushedFcn', {@MapInfo, fig_h});
    ud.Compare = uibutton(btnLayout, 'Text', 'Compare', 'ButtonPushedFcn', {@CompareCallback, fig_h, AllEEG});
    ud.Done = uibutton(btnLayout, 'Text', 'Save', 'ButtonPushedFcn', {@figClose, fig_h});
    
    fig_h.UserData = ud;
    
    solutionChanged([], [], fig_h);
end

function [yesPressed, selection] = questDlg(showOptions)
    
    yesPressed = false;
    selection = [];

    questDlg = figure('Name', 'Edit & sort microstate maps', 'NumberTitle', 'off', ...
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

    if ud.ActChoice.Value ~= 1
        return;
    end

    nClasses = ud.ClustPar.MinClasses + ud.ClassList.Value - 1;

    if ud.Scroll
        ud.Edit1.Value = sprintf('%i ', 1:nClasses);
    else
        ud.OrderEdit.String = sprintf('%i ', 1:nClasses);
    end

    letters = 'A':'Z';
    if ud.Scroll
        ud.Edit2.Value = sprintf('%s ', string(arrayfun(@(x) {letters(x)}, 1:nClasses)));
    else
        ud.LabelsEdit.String = sprintf('%s ', string(arrayfun(@(x) {letters(x)}, 1:nClasses)));
    end
end

function templateSetChanged(~,~,fh)
    ud = fh.UserData;
    
    if ud.Scroll
        templateSetIdx = ud.Edit1.Value;
    else
        templateSetIdx = ud.SelTemplate.Value;
    end
    classRange = ud.TemplateMinClasses(templateSetIdx):ud.TemplateMaxClasses(templateSetIdx);
    classesTxt = arrayfun(@(x) {sprintf('%i classes', x)}, classRange);
    if length(classesTxt) > 1 && ~(templateSetIdx == 1)
        classesTxt = ['All' classesTxt];
    end
    if ud.Scroll
        ud.Edit2.Items = classesTxt;
        ud.Edit2.ItemsData = 1:length(classesTxt);
    else
        ud.SelClasses.String = classesTxt;
        ud.SelClasses.Value = 1;
    end

    fh.UserData = ud;
end

function ActionChangedCallback(~,~,fh)
    ud = fh.UserData;    
   
    choice = ud.ActChoice.Value;
    manualSort = choice == 1;
    if (ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses) >= 1        
        templateSort = (choice == 2) | (choice == 3);
        stepwise = choice == 3;
    else
        templateSort = choice == 2;
        stepwise = false;
    end

    if manualSort      
        if ud.Scroll        
            ud.Label1.Text = 'Sort Order (negative to flip polarity)';
            ud.Label2.Text = 'New Labels';
            ud.Edit1 = uieditfield(ud.SortLayout);
            ud.Edit1.Layout.Row = 1;
            ud.Edit1.Layout.Column = 4;
            ud.Edit2 = uieditfield(ud.SortLayout);
            ud.Edit2.Layout.Row = 2;
            ud.Edit2.Layout.Column = 4;                                           
        else
            ud.OrderTxt.Visible = 'on';
            ud.OrderEdit.Visible = 'on';
            ud.OrderEdit.Enable = 'on';
            ud.LabelsTxt.Visible = 'on';
            ud.LabelsEdit.Visible = 'on';
            ud.LabelsEdit.Enable = 'on';            
        end        

        ud.ClassList.Enable = 'on';
        if numel(ud.ClassList.Value) > 1
            ud.ClassList.Value = ud.ClassList.Value(end); 
        end
        if ud.Scroll
            ud.ClassList.Multiselect = 'off';
        else
            ud.ClassList.Max = 1;
        end

        fh.UserData = ud;    
        solutionChanged([], [], fh);
    elseif ~ud.Scroll
        ud.OrderTxt.Visible = 'off';
        ud.OrderEdit.Visible = 'off';
        ud.OrderEdit.Enable = 'off';  
        ud.LabelsTxt.Visible = 'off';
        ud.LabelsEdit.Visible = 'off';
        ud.LabelsEdit.Enable = 'off';
    end

    if templateSort        
        if ud.Scroll            
            ud.Label1.Text = 'Select template set';
            ud.Label2.Text = 'Select template solution';   
            ud.Edit1 = uidropdown(ud.SortLayout, 'ValueChangedFcn', {@templateSetChanged, fh});
            ud.Edit1.Layout.Row = 1;
            ud.Edit1.Layout.Column = 4;
            ud.Edit2 = uidropdown(ud.SortLayout);
            ud.Edit2.Layout.Row = 2;
            ud.Edit2.Layout.Column = 4;

            tempEdit = 'Edit1';
        else           
            ud.SelTemplateLabel.Visible = 'on';
            ud.SelTemplate.Visible = 'on';            
            ud.SelClassesLabel.Visible = 'on';
            ud.SelClasses.Visible = 'on';
            ud.SelClasses.Enable = 'on';

            tempEdit = 'SelTemplate';
        end
        ud.IgnorePolarity.Visible = 'on';
        ud.IgnorePolarity.Enable = 'on';      

        if ud.Scroll
            ud.ClassList.Multiselect = 'on';
        else
            ud.ClassList.Max = 2;        
        end

        if stepwise
            ud.ClassList.Value = 1:(ud.ClustPar.MaxClasses-ud.ClustPar.MinClasses+1);
            ud.ClassList.Enable = 'off';

            if ud.Scroll
                ud.Edit1.Items = {'Own'};
                ud.Edit1.ItemsData = 1;
            else
                ud.SelTemplate.Value = 1;
                ud.SelTemplate.Enable = 'off';                   
            end
        else        
            ud.ClassList.Enable = 'on';            

            if ud.Scroll
                setnames = ['Own' ud.MeanNames ud.TemplateDisplayNames];
                ud.Edit1.Items = setnames;
                ud.Edit1.ItemsData = 1:numel(setnames);
            end

            ud.(tempEdit).Enable = 'on';            
        end        
        
        fh.UserData = ud;
        templateSetChanged([],[],fh); 
    else
        if ~ud.Scroll
            ud.SelTemplateLabel.Visible = 'off';
            ud.SelTemplate.Visible = 'off';
            ud.SelTemplate.Enable = 'off';  
            ud.SelClassesLabel.Visible = 'off';
            ud.SelClasses.Visible = 'off';
            ud.SelClasses.Enable = 'off';
        end
        ud.IgnorePolarity.Visible = 'off';
        ud.IgnorePolarity.Enable = 'off';
    end        
end

%% SORTING %%
function Sort(~,~,fh,AllEEG)
    ud = fh.UserData;

    AllEEG(ud.SelectedSet).msinfo.MSMaps = fh.UserData.MSMaps;
    nClasses = ud.ClustPar.MinClasses + ud.ClassList.Value - 1;

    choice = ud.ActChoice.Value;
    manualSort = choice == 1;    
    if (ud.ClustPar.MaxClasses - ud.ClustPar.MinClasses) >= 1        
        templateSort = (choice == 2) | (choice == 3);
        stepwise = choice == 3;
    else       
        templateSort = choice == 2;
        stepwise = false;
    end

    if manualSort
        if ud.Scroll
            SortOrder = sscanf(ud.Edit1.Value, '%i')';
            NewLabels = split(ud.Edit2.Value)';
        else
            SortOrder = sscanf(ud.OrderEdit.String, '%i')';
            NewLabels = split(ud.LabelsEdit.String)';
        end
        NewLabels = NewLabels(~cellfun(@isempty, NewLabels));

        [~, EEGout, ~, com] = pop_SortMSMaps(AllEEG, ud.SelectedSet, 'TemplateSet', 'manual', 'SortOrder', SortOrder, 'NewLabels', NewLabels, 'Classes', nClasses);
    elseif templateSort
        IgnorePolarity = ud.IgnorePolarity.Value;

        if ud.Scroll
            templateSetIdx = ud.Edit1.Value;
            classIdx = ud.Edit2.Value;
        else
            templateSetIdx = ud.SelTemplate.Value;
            classIdx = ud.SelClasses.Value;
        end

        if templateSetIdx == 1
            TemplateSet = 'own';
        elseif templateSetIdx <= numel(ud.MeanIdx)+1
            TemplateSet = ud.MeanIdx(templateSetIdx-1);
        else
            TemplateSet = ud.TemplateNames{templateSetIdx - numel(ud.MeanIdx)-1};
        end
        minClasses = ud.TemplateMinClasses(templateSetIdx);
        maxClasses = ud.TemplateMaxClasses(templateSetIdx);
        classRange = minClasses:maxClasses;
        if (templateSetIdx == 1) || (numel(classRange) == 1)
            TemplateClasses = classRange(classIdx);
        else
            if classIdx == 1
                TemplateClasses = 'all';
            else
                TemplateClasses = classRange(classIdx-1);
            end
        end
        
        if ~stepwise
            [~, EEGout, ~, com] = pop_SortMSMaps(AllEEG, ud.SelectedSet, 'TemplateSet', TemplateSet, 'Classes', nClasses, 'TemplateClasses', TemplateClasses, 'IgnorePolarity', IgnorePolarity);
        else
            [~, EEGout, ~, com] = pop_SortMSMaps(AllEEG, ud.SelectedSet, 'TemplateSet', 'own', 'TemplateClasses', TemplateClasses, 'IgnorePolarity', IgnorePolarity, 'Stepwise', 1);
        end               
    end      

    if ~isempty(com)
        fh.UserData.MSMaps = EEGout.msinfo.MSMaps;
        fh.UserData.wasSorted = true;
        PlotMSMaps2(fh, ud.MapPanel, fh.UserData.MSMaps(nClasses), ud.chanlocs, 'ShowExpVar', 1);

        if isempty(fh.UserData.com)
            fh.UserData.com = com;
        else
            fh.UserData.com = [fh.UserData.com newline com];
        end
    end

    solutionChanged([], [], fh);    
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
            sprintf('Extraction was based on %s maps',MaxMapsText) };
    if isempty(UserData.Children)
        txt = [txt sprintf('Explained variance: %2.2f%%',sum(UserData.MSMaps(nClasses).ExpVar) * 100)];
    end
    if isempty(UserData.MSMaps(nClasses).SortedBy)
        txt = [txt, 'Maps are unsorted'];
    else
        txt = [txt sprintf('Sort mode was %s ',UserData.MSMaps(nClasses).SortMode)];
        txt = [txt sprintf('Sorting was based on %s ',UserData.MSMaps(nClasses).SortedBy)];
    end
            
    if ~isempty(UserData.Children)
        childrenTxt = sprintf('%s, ', string(UserData.Children));
        childrenTxt = childrenTxt(1:end-2);
        txt = [txt 'Children: ' childrenTxt];
    end

end

function CompareCallback(~, ~, fh, AllEEG)
    AllEEG(fh.UserData.SelectedSet).msinfo.MSMaps = fh.UserData.MSMaps;
    
    if isempty(fh.UserData.Children)
        [EEGout, ~, com] = pop_CompareMSMaps(AllEEG, 'IndividualSets', fh.UserData.SelectedSet);
    else
        [EEGout, ~, com] = pop_CompareMSMaps(AllEEG, 'MeanSets', fh.UserData.SelectedSet);
    end

    % If the command contains sorting function calls, we should replot the maps
    if contains(com, 'pop_Sort')
        fh.UserData.MSMaps = EEGout.msinfo.MSMaps;
        fh.UserData.wasSorted = true;
        PlotMSMaps2(fh, fh.UserData.MapPanel, fh.UserData.MSMaps(fh.UserData.ClustPar.MinClasses:fh.UserData.ClustPar.MaxClasses), ...
            fh.UserData.chanlocs, 'ShowExpVar', 1);
        ActionChangedCallback([], [], fh);
    end
    
    if isempty(fh.UserData.com)
        fh.UserData.com = com;
    elseif ~isempty(com)
        fh.UserData.com = [fh.UserData.com newline com];
    end        
end
