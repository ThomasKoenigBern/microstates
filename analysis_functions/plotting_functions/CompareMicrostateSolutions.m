function Filename = CompareMicrostateSolutions(SelectedEEG, nClasses, Filename)

    CompFigHandle = figure('Units', 'normalized', 'Position', [0.2 0.1 0.6 0.8], ...
        'Name', 'Compare microstate maps', 'NumberTitle', 'off', 'MenuBar', 'none', 'ToolBar', 'none');

    CompFigHandle.UserData.SelectedEEG = SelectedEEG;
    CompFigHandle.UserData.nClasses = nClasses;
    CompFigHandle.UserData.Filename = [];
    
    CompFigHandle.UserData.CompAxis  = subplot('Position',[0.05 0.13 0.67 0.85],'Parent',CompFigHandle);

    if nClasses == 0
        MinClasses = SelectedEEG.msinfo.ClustPar.MinClasses;
        MaxClasses = SelectedEEG.msinfo.ClustPar.MaxClasses;
        choice = sprintf('%i Classes|', MinClasses:MaxClasses);
        choice(end) = [];
        idx = 1:MaxClasses - MinClasses + 1;
    else
        setIDs = string(1:numel(SelectedEEG));
        CompFigHandle.UserData.setIDs = setIDs;
        CompFigHandle.UserData.setnames = {SelectedEEG.setname};

        choice = strcat(setIDs, ': ', {SelectedEEG.setname});
        idx = 1:numel(SelectedEEG);
    end
   
    obj.Value = idx;
    
    CompareMapsSolutionChanged(obj, [], CompFigHandle);
    
    if isempty(Filename)
        CompFigHandle.UserData.wait = 1;
        viewBtnPos = [0.76 0.09 0.22 0.06];
        uicontrol('style', 'pushbutton', 'string', 'Export shared variances', 'Callback', {@ExportCorrs, CompFigHandle}, 'Units', 'normalized', 'Position', [.76 .02 .22 .06]);
    else
        CompFigHandle.UserData.wait = 0;
        viewBtnPos = [.76 .05 .22 .06];
    end
    uicontrol('style', 'listbox', 'string', choice, 'Value', idx,'min',1,'max',10, ...
        'Callback',{@CompareMapsSolutionChanged,CompFigHandle},'Units','normalized','Position',[0.76 0.17 0.22 0.39]);
    uicontrol('style', 'pushbutton', 'string', 'View shared variances', 'Callback',{@CompareMapsSolutionCorrsToggle,CompFigHandle},'Units','normalized','Position',viewBtnPos);
    uicontrol('style', 'pushbutton' , 'string', '-'   ,  'Callback',{@CompareMapsSolutionScale,CompFigHandle,1.2  },'Units','normalized','Position',[0.225  0.02 0.1 0.05]);
    uicontrol('style', 'pushbutton' , 'string', '+'   ,  'Callback',{@CompareMapsSolutionScale,CompFigHandle,1/1.2},'Units','normalized','Position',[0.335  0.02 0.1 0.05]);
    uicontrol('style', 'pushbutton' , 'string', '>|<' ,  'Callback',{@CompareMapsSolutionScale,CompFigHandle,0},'Units','normalized','Position'    ,[0.445  0.02 0.1 0.05]);
    CompFigHandle.CloseRequestFcn = {@CompareMapsSolutionClose,CompFigHandle};

    if isempty(Filename)
        uiwait(CompFigHandle);
    end

    Filename = CompFigHandle.UserData.Filename;

    if isvalid(CompFigHandle)
        delete(CompFigHandle);
    end
end

function ExportCorrs(obj, ~, fh)
    CorrTable = fh.UserData.CorrelationTable;
    CorrTable.Properties.RowNames = CorrTable.Properties.VariableNames;

    [FName, PName, idx] = uiputfile({'*.csv', 'Comma separated file'; '*.txt', 'Tab delimited file'; '*.xlsx', 'Excel file'; '*.mat', 'Matlab Table'}, 'Save shared variance matrix');
    if FName == 0
        return;
    end
    
    Filename = fullfile(PName, FName);
    if idx < 4
        writetable(CorrTable, Filename, 'WriteRowNames', true);
    else
        save(Filename, 'CorrTable');
    end

    fh.UserData.Filename = [fh.UserData.Filename {Filename}];
end

function CompareMapsSolutionCorrsToggle(~, ~,fh)
    
    if isfield(fh.UserData,'CorrMatFig')
        if isvalid(fh.UserData.CorrMatFig)
            delete(fh.UserData.CorrMatFig);
            return;
        end
    end

    fh.UserData.CorrMatFig = uifigure;

    fh.UserData.CorrMatFig.WindowStyle = "normal";
    fh.UserData.CorrMatFig.Name = "Percent shared variance";
    uitable('Unit','normalized','Position',[0.02 0.02 0.96 0.96],'Parent',fh.UserData.CorrMatFig);
    UpdateCorrTable(fh);
end

function CompareMapsSolutionScale(~, ~,fh, Scaling)
    UserData = fh.UserData;
    FigAxes = UserData;
    if Scaling == 0
        lim = UserData.OrgLim;
        FigAxes.CompAxis.XLim = [-lim lim];
        FigAxes.CompAxis.YLim = [-lim lim];

    else
        FigAxes.CompAxis.XLim = FigAxes.CompAxis.XLim * Scaling;
        FigAxes.CompAxis.YLim = FigAxes.CompAxis.YLim * Scaling;
    end
end

function CompareMapsSolutionClose(~, ~,fh)
    if isfield(fh.UserData,'CorrMatFig')
        if isvalid(fh.UserData.CorrMatFig)
            delete(fh.UserData.CorrMatFig);
        end
    end

    if fh.UserData.wait
        uiresume(fh);
    else
        delete(fh);
    end
end

function UpdateCorrTable(fh)
    UserData = fh.UserData;
    if ~isfield(UserData,'CorrMatFig')
        return;
    end
    
    if ~isvalid(UserData.CorrMatFig)
        return;
    end
    UserData.CorrMatFig.Children.Data = UserData.CorrelationTable;
    removeStyle(UserData.CorrMatFig.Children);    
    [row,col] = find(UserData.HitMatrix | eye(size(UserData.HitMatrix,1)));
    tblStyle = uistyle('BackgroundColor',[0.6 1.0 0.6],'FontWeight','bold');
    addStyle(UserData.CorrMatFig.Children,tblStyle,'cell',[row,col]);
end

function CompareMapsSolutionChanged(obj, event, CompFig)
    
    FigAxes = CompFig.UserData;

    MapCollection    = [];
    ColorCollection  = [];
    LabelCollection  = [];
    nClassCollection = [];
    setNumCollection = [];
    CLabelCollection = [];

    if FigAxes.nClasses == 0
        SelectedSolutions = FigAxes.SelectedEEG.msinfo.ClustPar.MinClasses + obj.Value -1;
        for i = SelectedSolutions
            MapCollection     = [MapCollection; FigAxes.SelectedEEG.msinfo.MSMaps(i).Maps];
            ColorCollection   = [ColorCollection; FigAxes.SelectedEEG.msinfo.MSMaps(i).ColorMap];
            for j = 1:i
                LabelCollection   = [LabelCollection FigAxes.SelectedEEG.msinfo.MSMaps(i).Labels(j)];
                nClassCollection  = [nClassCollection i];
                CLabelCollection  = [CLabelCollection,sprintf("%s (%i)",FigAxes.SelectedEEG.msinfo.MSMaps(i).Labels{j},i)];
            end
        end
    else
        SelectedSets = obj.Value;
        for i=SelectedSets
            MapCollection = [MapCollection; FigAxes.SelectedEEG(i).msinfo.MSMaps(FigAxes.nClasses).Maps];
            ColorCollection = [ColorCollection; FigAxes.SelectedEEG(i).msinfo.MSMaps(FigAxes.nClasses).ColorMap];
            for j=1:FigAxes.nClasses
                setNumCollection = [setNumCollection i];
                LabelCollection = [LabelCollection FigAxes.SelectedEEG(i).msinfo.MSMaps(FigAxes.nClasses).Labels(j)];
                CLabelCollection = [CLabelCollection, sprintf("%s (%s)", FigAxes.SelectedEEG(i).msinfo.MSMaps(FigAxes.nClasses).Labels{j}, FigAxes.setnames{i})];
            end
        end
    end    
    MapCollection=double(MapCollection);
    
    ops = statset('Display','off','TolFun',0.01);

    CorrMat = MyCorr(MapCollection').^2;

    pro = mdscale(1-CorrMat,2,'Options',ops,'Criterion','strain');    
  
    cla(FigAxes.CompAxis);
    hold(FigAxes.CompAxis,"on");

    ClassesToDisplay = unique(LabelCollection);
    LegendSubSet = [];

    HitMatrix = false(numel(LabelCollection));
    
%    figure;
%    d = squareform(pdist(pro));
%    plot(d(:),CorrMat(:),'.k')
    
    for i = 1:numel(ClassesToDisplay)
        ItemsToPlot = find(strcmp(ClassesToDisplay{i},LabelCollection));
        nItemsToPlot = numel(ItemsToPlot);
        PlotColor = ColorCollection(ItemsToPlot(1),:);
        
%        clear res;
%        res(:,1) = LabelCollection(ItemsToPlot);
%        res(:,2) = num2cell(nClassCollection(ItemsToPlot))
        
        if nItemsToPlot < 3        
            plot(FigAxes.CompAxis,pro(ItemsToPlot,1),pro(ItemsToPlot,2),'-k');
        else
            xy = pro(ItemsToPlot,:);
            Hull = convhull(xy(:,1),xy(:,2));
            patch(FigAxes.CompAxis,xy(Hull,1),xy(Hull,2),PlotColor,'FaceAlpha',.2);
        end
        ph = plot(FigAxes.CompAxis,pro(ItemsToPlot,1),pro(ItemsToPlot,2),'ok','MarkerFaceColor',PlotColor,'MarkerSize',8);        
        for j = 1:nItemsToPlot
            idx = ItemsToPlot(j);
            if FigAxes.nClasses == 0                
                txt = sprintf(" %i",nClassCollection(idx));                
            else
                txt = [ ' ' FigAxes.setIDs(setNumCollection(idx))];
            end
            text(FigAxes.CompAxis,pro(idx,1),pro(idx,2),txt,'HorizontalAlignment','center', ...
                    'VerticalAlignment','Bottom','Interpreter','none','FontSize', 11, 'FontWeight', 'bold');
            HitMatrix(idx,ItemsToPlot) = true;
        end
        LegendSubSet = [LegendSubSet,ph];
    end
    
    legend(LegendSubSet,ClassesToDisplay,'Interpreter','none','Position',[0.76,0.58,0.22,0.39]);

    axis(FigAxes.CompAxis,'equal');
    axis(FigAxes.CompAxis,'tight');    
    lim = max(abs([FigAxes.CompAxis.XLim FigAxes.CompAxis.YLim]));
    lim = lim * 1.2;
    FigAxes.OrgLim = lim;

    FigAxes.CompAxis.XLim = [-lim lim];
    FigAxes.CompAxis.YLim = [-lim lim];
    
    FigAxes.CorrelationTable = array2table(CorrMat * 100,'VariableNames',CLabelCollection,'RowNames',CLabelCollection);
    FigAxes.HitMatrix = HitMatrix;

    UpdateCorrTable(CompFig);

    CompFig.UserData = FigAxes;    
end
