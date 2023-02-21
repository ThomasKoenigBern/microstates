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
    ud.Edit         = true;
    ud.nClasses     = nan;
    ud.com          = '';
    ud.SelectedSet  = SelectedSet;
%     ud.PrevPosition = [0 0 0 0];
    
    fig = uifigure('WindowStyle', 'modal', 'Units', 'pixels', ...
        'Position', [385 174 768 518] ,'Visible', 'off', ...
        'Name', sprintf('Microstate maps of %s', SelectedEEG.setname), ...
        'AutoResizeChildren', 'off', 'SizeChangedFcn', @sizeChanged);
    
    ud.FigLayout = uigridlayout(fig, [3 1]);
    ud.FigLayout.RowHeight = {'1x', 120, 30};
    
    SelLayout = uigridlayout(ud.FigLayout, [1 2]);
    SelLayout.Padding = [0 0 0 0];
    SelLayout.Layout.Row = 2;
    SelLayout.ColumnWidth = {90, '1x'};
    
    AvailableClasses = arrayfun(@(x) {sprintf('%i Classes', x)}, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    ud.ClassList = uilistbox(SelLayout, 'Items', AvailableClasses, ...
        'ItemsData', ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses, ...
        'ValueChangedFcn',{@solutionChanged,fig});
    
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
    
    uibutton(SortLayout, 'Text', 'Sort', 'ButtonPushedFcn', {@ManualSortCallback,fig});
    
    BtnLayout = uigridlayout(ud.FigLayout, [1 3]);
    BtnLayout.ColumnWidth = {'1x', 70, 70};
    BtnLayout.Padding = [0 0 0 5];
    CancelBtn = uibutton(BtnLayout, 'Text', 'Cancel', 'ButtonPushedFcn', {@btnPressed, fig});
    CancelBtn.Layout.Column = 2;
    SaveBtn = uibutton(BtnLayout, 'Text', 'Save', 'ButtonPushedFcn', {@btnPressed, fig});
    SaveBtn.Layout.Column = 3;
    
    fig.UserData = ud;
    
    PlotMSMaps(fig, ud.ClustPar.MinClasses:ud.ClustPar.MaxClasses);
    solutionChanged([], [], fig);
    
    fig.Visible = 'on';
    drawnow limitrate

%     fig.CloseRequestFcn = 'uiresume(fig)';
    uiwait(fig);

    if isvalid(fig)
        ud = fig.UserData;
        delete(fig);     
        SortedMaps = ud.AllMaps;
        com = ud.com;
    end
end

function btnPressed(src, event, fig)
    if strcmp(src.Text, 'Save')
        uiresume(fig);
    else
        delete(fig);
    end
end

function ManualSortCallback(~, ~, fig)
    MSMaps = fig.UserData.AllMaps;
    SortOrder = sscanf(fig.UserData.OrderEdit.Value, '%i')';
    NewLabels = split(fig.UserData.LabelsEdit.Value)';
    NewLabels = NewLabels(~cellfun(@isempty, NewLabels));
    nClasses = fig.UserData.ClassList.Value;
    SortAll = fig.UserData.SortAll.Value;
    ClassRange = fig.UserData.ClustPar.MinClasses:fig.UserData.ClustPar.MaxClasses;
    IgnorePolarity = fig.UserData.IgnorePolarity.Value;
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

    % Validate SortOrder
    sortOrderSign = sign(SortOrder(:)');
    SortOrder = abs(SortOrder(:)');
    if (numel(SortOrder) ~= nClasses)
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    if numel(unique(SortOrder)) ~= nClasses
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    if any(unique(SortOrder) ~= unique(1:nClasses))
        MSMaps = [];
        errordlg2('Invalid manual sort order given','Sort microstate maps error');
        return
    end

    % Validate NewLabels
    if numel(NewLabels) ~= ClassRange
        MSMaps = [];
        errordlg2('Invalid manual map labels given', 'Sort microstate maps error');
        return;
    end

    % Manual sort    
    if ~all(SortOrder == 1:nClasses) && ~all(string(NewLabels) == string(MSMaps(nClasses).Labels))
        MSMaps(nClasses).Maps = MSMaps(nClasses).Maps(SortOrder,:).*repmat(sortOrderSign',1,size(MSMaps(nClasses).Maps,2));
        MSMaps(nClasses).Labels = NewLabels(:)';
        MSMaps(nClasses).ColorMap = lines(nClasses);
        MSMaps(nClasses).ExpVar = MSMaps(nClasses).ExpVar(SortOrder);
        MSMaps(nClasses).SortMode = 'manual';
        MSMaps(nClasses).SortedBy = 'user';
    end

    % Sort all if selected
    if SortAll
        MSMaps = sortAllSolutions(MSMaps, ClassRange, nClasses, IgnorePolarity);
    end

    NewLabelsTxt = sprintf('%s, ', string(NewLabels));
    NewLabelsTxt = ['{' NewLabelsTxt(1:end-2) '}'];
    com = sprintf(['[EEG, CURRENTSET, COM] = pop_SortMSTemplates(ALLEEG, %i, ''IgnorePolarity'', %i, ''TemplateSet'', ''manual'', ''SortOrder'', ' ...
        '%s, ''NewLabels'', %s, ''ClassRange'', %i, ''SortAll'', %i)'], SelectedSet, IgnorePolarity, mat2str(SortOrder), NewLabelsTxt, nClasses, SortAll);
end

function MSMaps = sortAllSolutions(MSMaps, ClassRange, nClasses, IgnorePolarity)    
    for i=ClassRange
        if i == nClasses
            continue
        end

        [SortedMaps, SortOrder, SpatialCorrelation, polarity] = ArrangeMapsBasedOnMean(MSMaps(i).Maps, MSMaps(nClasses).Maps, ~IgnorePolarity);
        MSMaps(i).Maps = squeeze(SortedMaps).*repmat(polarity',1,size(squeeze(SortedMaps), 2));

        [Labels, Colors] = UpdateMicrostateLabels(MSMaps(i).Labels, MSMaps(nClasses).Labels, SortOrder, MSMaps(nClasses).ColorMap);
        MSMaps(i).Labels = Labels(1:i);
        MSMaps(i).ColorMap = Colors(1:i, :);
        MSMaps(i).SortMode = [MSMaps(nClasses).SortMode 'alternate solution in set'];
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

    ud.OrderEdit.Value = sprintf('%i ', 1:nClasses);

    if strcmp(ud.AllMaps(nClasses).SortMode, 'none')
        letters = 'A':'Z';
        ud.LabelsEdit.Value = sprintf('%s ', string(arrayfun(@(x) {letters(x)}, 1:nClasses)));
    else
        ud.LabelsEdit.Value = sprintf('%s ', string(ud.AllMaps(nClasses).Labels));
    end
end

function sizeChanged(fig, ~)

%     uiresume(fig);

    p = fig.UserData.TilePanel;

%     if all(fig.Position == fig.UserData.PrevPosition)
%         return;
%     end

    if fig.UserData.Edit
        expVarWidth = 53;
        minGridHeight = 90;
    else
        expVarWidth = 0;
        minGridHeight = 60;
    end
    minGridWidth = 62;

    nCols = fig.UserData.ClustPar.MaxClasses;
    nRows = fig.UserData.ClustPar.MaxClasses - fig.UserData.ClustPar.MinClasses + 1;

    minPanelWidth = expVarWidth + minGridWidth*nCols;
    minPanelHeight = minGridHeight*nRows;

    p.Units = 'pixels';

    if p.Position(3) > minPanelWidth && p.Position(4) > minPanelHeight
        p.Units = 'normalized';
        p.Position = [0 0 1 1];
        return;
    end

    if p.Position(3) <= minPanelWidth
        p.Position(1:3) = [0 0 minPanelWidth];
    end

    if p.Position(4) <= minPanelHeight
        p.Position(1:2) = [0 0];
        p.Position(4) = minPanelHeight;
    end

%     fig.UserData.PrevPosition = fig.Position;
end