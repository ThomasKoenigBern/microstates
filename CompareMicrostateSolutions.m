function CompareMicrostateSolutions(obj,event,fh)
    UserData = get(fh,'UserData');
    
    CompFigHandle = figure;
    CompAxis = gca;
    fh.UserData.CompFigHandle = CompFigHandle;
    
    CompFigHandle.UserData.CompAxis  = subplot('Position',[0.16 0.21 0.64,0.76],'Parent',CompFigHandle);
    CompFigHandle.UserData.XPMapAxis = subplot('Position',[0.70 0.03 0.10 0.10],'Parent',CompFigHandle);
    CompFigHandle.UserData.XNMapAxis = subplot('Position',[0.16 0.03 0.10 0.10],'Parent',CompFigHandle);
    CompFigHandle.UserData.YPMapAxis = subplot('Position',[0.05 0.21 0.10 0.10],'Parent',CompFigHandle);
    CompFigHandle.UserData.YNMapAxis = subplot('Position',[0.05 0.89 0.10 0.10],'Parent',CompFigHandle);

    choice = '';
    
    for i = UserData.ClustPar.MinClasses:UserData.ClustPar.MaxClasses
        choice = [choice sprintf('%i Classes|',i)];
    end
    idx = 1: UserData.ClustPar.MaxClasses - UserData.ClustPar.MinClasses + 1;
    
    choice(end) = [];
    obj.Value = idx;
    
    CompareMapsSolutionChanged(obj, [],fh,CompFigHandle);
    
    uicontrol('style', 'listbox', 'string', choice, 'Value', idx,'min',1,'max',10, 'Callback',{@CompareMapsSolutionChanged,fh,CompFigHandle},"Unit","normalized", 'Position',[0.82 0.31 0.16 0.3]);
    uicontrol('style', 'togglebutton' , 'string', "Shared variance", 'Min',1,'Max',0, 'Callback',{@CompareMapsSolutionCorrsToggle,CompFigHandle},"Unit","normalized",'Position',[0.82 0.2 0.16 0.1]);
    uicontrol('style', 'pushbutton' , 'string', "Done",  'Callback',{@CompareMapsSolutionClose,CompFigHandle},"Unit","normalized",'Position',[0.82 0.1 0.16 0.1]);
    uicontrol('style', 'pushbutton' , 'string', "-"   ,  'Callback',{@CompareMapsSolutionScale,CompFigHandle,1.2  },"Unit","normalized",'Position',[0.35  0.05 0.1 0.1]);
    uicontrol('style', 'pushbutton' , 'string', "+"   ,  'Callback',{@CompareMapsSolutionScale,CompFigHandle,1/1.2},"Unit","normalized",'Position',[0.45  0.05 0.1 0.1]);
    uicontrol('style', 'pushbutton' , 'string', ">|<"   , 'Callback',{@CompareMapsSolutionScale,CompFigHandle,0},"Unit","normalized",'Position'   ,[0.55  0.05 0.1 0.1]);
    CompFigHandle.CloseRequestFcn = {@CompareMapsSolutionClose,CompFigHandle};
end

function CompareMapsSolutionCorrsToggle(obj, event,fh)
    
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



function CompareMapsSolutionScale(obj, event,fh, Scaling)
    UserData = get(fh,'UserData');
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

function CompareMapsSolutionClose(obj, event,fh)
    if isfield(fh.UserData,'CorrMatFig')
        if isvalid(fh.UserData.CorrMatFig)
            delete(fh.UserData.CorrMatFig);
        end
    end
    delete(fh);
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



function CompareMapsSolutionChanged(obj, event,fh,CompFig)
    
    UserData = get(fh,'UserData');
    FigAxes = CompFig.UserData;

    SelectedSolutions = UserData.ClustPar.MinClasses + obj.Value -1;
    MapCollection    = [];
    ColorCollection  = [];
    LabelCollection  = [];
    nClassCollection = [];
    CLabelCollection = [];
    for i = SelectedSolutions
        MapCollection     = [MapCollection; UserData.AllMaps(i).Maps];
        ColorCollection   = [ColorCollection; UserData.AllMaps(i).ColorMap];
        for j = 1:i
            LabelCollection   = [LabelCollection UserData.AllMaps(i).Labels(j)];
            nClassCollection  = [nClassCollection i];
            CLabelCollection  = [CLabelCollection,sprintf("%s (%i)",UserData.AllMaps(i).Labels{j},i)];
        end
    end
    MapCollection=double(MapCollection);
    
    ops = statset('Display','off','TolFun',0.01);

    CorrMat = corr(MapCollection').^2;

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
        for j = 1:nItemsToPlot
            idx = ItemsToPlot(j);
            txt = sprintf(" %i",nClassCollection(idx));
            text(FigAxes.CompAxis,pro(idx,1),pro(idx,2),txt,'HorizontalAlignment','Center','VerticalAlignment','Bottom','Interpreter','none');
            
            HitMatrix(idx,ItemsToPlot) = true;
        end
        ph = plot(FigAxes.CompAxis,pro(ItemsToPlot,1),pro(ItemsToPlot,2),'ok' ,'MarkerFaceColor',PlotColor,'MarkerSize',10);        
        LegendSubSet = [LegendSubSet,ph];
    end
    
    legend(LegendSubSet,ClassesToDisplay,'Interpreter','none','Position',[0.82,0.62,0.16,0.35]);

    lim = max(abs([FigAxes.CompAxis.XLim FigAxes.CompAxis.YLim]));
    lim = lim * 1.2;
    FigAxes.OrgLim = lim;
    axis(FigAxes.CompAxis,'equal');
    axis(FigAxes.CompAxis,'tight');    

    FigAxes.CompAxis.XLim = [-lim lim];
    FigAxes.CompAxis.YLim = [-lim lim];
    
    CompFig.UserData.CorrelationTable = array2table(CorrMat * 100,'VariableNames',CLabelCollection,'RowNames',CLabelCollection);
    CompFig.UserData.HitMatrix = HitMatrix;

    UpdateCorrTable(CompFig);
    
    ProCentered = pro-repmat(mean(pro,1),size(pro,1),1);
    DimMaps = NormDim(ProCentered'* MapCollection,2);
    
    X = cell2mat({UserData.chanlocs.X});
    Y = cell2mat({UserData.chanlocs.Y});
    Z = cell2mat({UserData.chanlocs.Z});

    axes(FigAxes.XPMapAxis);
    dspCMap( DimMaps(1,:),[X; Y;Z],'NoScale','Resolution',2,'ShowNose',15);

    axes(FigAxes.XNMapAxis);
    dspCMap(-DimMaps(1,:),[X; Y;Z],'NoScale','Resolution',2,'ShowNose',15);

    axes(FigAxes.YPMapAxis);
    dspCMap( DimMaps(2,:),[X; Y;Z],'NoScale','Resolution',2,'ShowNose',15);

    axes(FigAxes.YNMapAxis);
    dspCMap(-DimMaps(2,:),[X; Y;Z],'NoScale','Resolution',2,'ShowNose',15);

    
end
