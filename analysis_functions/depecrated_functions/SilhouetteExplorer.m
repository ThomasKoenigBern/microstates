function SilhouetteExplorer(TemplateEEG, SortedSet,figh)
    
    if nargin > 2
        figure(figh);
        clf;
    else
        if ~isempty(findobj('Tag','SilhouetteExplorer'))
            figh = figure(findobj('Tag','SilhouetteExplorer'));
        else
            figh = figure();
        end
    end
    
    set(figh,'Tag','SilhouetteExplorer');
    
    ClusterNumbers = TemplateEEG.msinfo.ClustPar.MinClasses:TemplateEEG.msinfo.ClustPar.MaxClasses;

    txt = cellfun(@(x) sprintf('%i Classes',x),num2cell(ClusterNumbers),'UniformOutput',false);
    
    CallSilhouetteExplorer([],[],SortedSet,TemplateEEG,ClusterNumbers,txt)
    
%    uicontrol('Style', 'popup','String', txt,'Units','normalized','Position', [0.05 0.90 0.2 0.05],...
%           'Callback', {@CallSilhouetteExplorer,SortedSet,TemplateEEG,ClusterNumbers,txt});    

end

function SilhouetteExplorerHelp(~,~)
   doc('pop_MS_Silhouette.m'); 
end

   
function CallSilhouetteExplorer(hObject,~,SortedSet,eegout,ClusterNumbers,txt)

    if isempty(hObject)
        index = 1;
    else
        index = get(hObject,'Value');
    end
    nc = ClusterNumbers(index);
    clf
    uicontrol('Style', 'popup','String', txt,'Units','normalized','Position', [0.05 0.90 0.2 0.05],'Value',index,...
           'Callback', {@CallSilhouetteExplorer,SortedSet,eegout,ClusterNumbers,txt});    


   uicontrol('Style', 'pushbutton','String', 'What do I see here?','Units','normalized','Position', [0.05 0.96 0.2 0.02],...
           'Callback', @SilhouetteExplorerHelp);    

       
    nSubjects = numel(SortedSet);

    SortedMaps = cellfun(@(x) SortedSet(x).msinfo.MSMaps(nc).Maps,num2cell(1:nSubjects),'UniformOutput',false);
    [nmaps,nchannels] = size(SortedMaps{1,1});
    SortedMaps = NormDimL2(reshape(cell2mat(SortedMaps),[nmaps,nchannels,nSubjects]),2);
    Clusters = repmat(1:nc,nSubjects,1);
    Subjects = repmat((1:nSubjects)',1,nmaps);
    Clusters = reshape(Clusters,1,nmaps * nSubjects)';
    Subjects = reshape(Subjects,1,nmaps * nSubjects)';
    SortedMapsShifted = shiftdim(SortedMaps,1);
    SortedMapsShifted = reshape(SortedMapsShifted,nchannels,nmaps * nSubjects);
    
    distfun = @(XI,XJ)(1-abs(MyCorr(XI',XJ')));
%    distfun = @(XI,XJ)(EMMapDifference(XI,XJ,eegout.chanlocs,eegout.chanlocs,true));
    s = silhouette(double(SortedMapsShifted'),double(Clusters),distfun);

    diss = 1 - abs(MyCorr(SortedMapsShifted));
    size(diss);
    mds = mdscale(diss,3);

    DoTheSilhouettePlot(s,Clusters,Subjects,eegout,mds, SortedSet);

end

function DoTheBars(s,Clusters,Subjects, sIdx,cIdx,mds,SortedSet,TemplateEEG)
    nClusters = max(Clusters);
    is = 0;

    dy = 0.95 / (nClusters+1);

    for i = 1:nClusters
        subplot('position',[0.65 0.98-i*dy,0.3,dy * 0.7]);
        sc(:,1) = s(Clusters == i);
        sc(:,2) = 0;
        is = sc + is;
        meanSC = mean(sc(:,1));
        si = Subjects(Clusters == i);
        if any(i == cIdx)
            sc(sIdx,2) = sc(sIdx,1);
            sc(sIdx,1) = 0;
        end
        bh = bar(sc,'stacked');
        set(bh,'ButtonDownFcn',{@BarHit,s,Clusters,Subjects,i,si,mds,SortedSet,TemplateEEG});
        
        if meanSC > 0.7
            txt = 'strong';
        elseif meanSC > 0.5
            txt = 'good';
        elseif meanSC > 0.25
            txt = 'weak';
        else
            txt = 'none';
        end
    
        title(sprintf('%f (%s)',meanSC(1),txt));
    
        axis([0 (size(sc,1)+1) -1 1]);
        
    end
    is = is / nClusters;
    subplot('position',[0.65 0.05,0.3,dy * 0.7]);

    bh = bar(is(:,1));
    set(bh,'ButtonDownFcn',{@BarHit,s,Clusters,Subjects,0,si,mds,SortedSet,TemplateEEG});
    axis([0 (size(is,1)+1) -1 1]);

end


function DoTheSilhouettePlot(s,Clusters,Subjects,TemplateEEG,mds,SortedMaps)

    nClusters = max(Clusters);
    
    X = cell2mat({TemplateEEG.chanlocs.X});
    Y = cell2mat({TemplateEEG.chanlocs.Y});
    Z = cell2mat({TemplateEEG.chanlocs.Z});

    dy = 0.95 / (nClusters+1);
    for i = 1:nClusters
        subplot('position',[0.5 0.98- i*dy,0.1,dy * 0.7]);
        dspCMap(TemplateEEG.msinfo.MSMaps(nClusters).Maps(i,:),[X; Y;Z],'NoScale','Resolution',3,'Background',TemplateEEG.msinfo.MSMaps(nClusters).ColorMap(i,:));
        title(sprintf('Class %i',i));
    end
    
    DoTheBars(s,Clusters,Subjects,0,0,mds, SortedMaps,TemplateEEG);
      
    sh = subplot('position',[0.05 0.4,0.42,0.42]);

    colors = lines(nClusters);
    markers = 'ox+*sdv^<>ph';
    
    for i = 1:nClusters
        mdsdata = mds(Clusters == i,:);
        m  = rem(i-1,12)+1;
        plot3(mdsdata(:,1),mdsdata(:,2),mdsdata(:,3),markers(m),'MarkerFaceColor',colors(i,:),'MarkerSize',5);
        hold on
    end
    mx = max(abs([get(sh,'XLim') get(sh,'YLim') get(sh,'ZLim')]));
    axis([-mx mx -mx mx -mx mx]);
    axis vis3d
    hold off
    axis equal
    set(sh,'XGrid','on','YGrid','on','ZGrid','on','Tag','MDSDisplay');
    
    [az,el] = view;

    uicontrol('Style','slider', 'Value',90+az, 'Min',0,'Units','normalized',...
        'Max',90, 'SliderStep',[1 10]./100, 'Position',[0.05 0.30 0.40 0.02], 'Callback',{@slider_callback,1});
    
    uicontrol('Style','slider','Min',0,'Units','normalized',...
        'Max',90, 'Value',90-el, 'SliderStep',[1 10]./100, 'Position',[0.47 0.40 0.02 0.42], 'Callback',{@slider_callback,2});
    end

function slider_callback(hObject,~,d)
    axes(findobj('Tag','MDSDisplay'));
    [az,el] = view;
    if d == 1
        view(90-get(hObject,'Value'),el);
    else
        view(az,90-get(hObject,'Value'));
    end
    
end



function BarHit(~,eventdata,s,Clusters,Subjects,ClusterIndex,SubjectIndex,mds,SortedSet,TemplateEEG)
    SubjectIndex = SubjectIndex(round(eventdata.IntersectionPoint(1)));
    
    nClusters = max(Clusters);
    if ClusterIndex == 0
        ClusterIndex = 1:nClusters;
    end
    
    
    X = cell2mat({SortedSet(SubjectIndex).chanlocs.X});
    Y = cell2mat({SortedSet(SubjectIndex).chanlocs.Y});
    Z = cell2mat({SortedSet(SubjectIndex).chanlocs.Z});
    
    
    dx = 0.4 / nClusters;
    
    for i = 1:numel(ClusterIndex)
        if numel(ClusterIndex) == 1
            subplot('position',[0.05 0.02 0.2 0.2]);
        else
            subplot('position',[0.05 + (i-1) * dx 0.02 dx * 0.9 0.1]);
        end
        dspCMap(SortedSet(SubjectIndex).msinfo.MSMaps(nClusters).Maps(ClusterIndex(i),:),[X; Y;Z],'NoScale','Resolution',3);
        if numel(ClusterIndex) == 1
            title(sprintf('Individual map (%i)',SubjectIndex));
        end
    end
    
    X = cell2mat({TemplateEEG.chanlocs.X});
    Y = cell2mat({TemplateEEG.chanlocs.Y});
    Z = cell2mat({TemplateEEG.chanlocs.Z});
    
    for i = 1:numel(ClusterIndex)
        if numel(ClusterIndex) == 1
            subplot('position',[0.27 0.02 0.2 0.2]);
        else
            subplot('position',[0.05 + (i-1) * dx 0.14 dx * 0.9 0.1]);
        end
        
        dspCMap(TemplateEEG.msinfo.MSMaps(nClusters).Maps(ClusterIndex(i),:),[X; Y;Z],'NoScale','Resolution',3);
        if numel(ClusterIndex) == 1
            title('Template map');
        end
    end
    
    delete(findobj('Tag','MDSHighLight'));
    if numel(ClusterIndex) > 1
        uicontrol('Style','text','String', 'Templates','Units','normalized','Position', [0.05 0.25 0.4 0.02],'Tag','MDSHighLight');
        uicontrol('Style','text','String', sprintf('Individual(%i) maps',SubjectIndex),'Units','normalized','Position', [0.05 0.12 0.4 0.02],'Tag','MDSHighLight');
    end
    

    markers = 'ox+*sdv^<>ph';
    colors = lines(max(Clusters));
    
    DoTheBars(s,Clusters,Subjects,SubjectIndex,ClusterIndex,mds, SortedSet,TemplateEEG);
    
    axes(findobj('Tag','MDSDisplay'));
    
    for i = 1:numel(ClusterIndex)
        caseindex = Clusters == ClusterIndex(i) & Subjects == SubjectIndex;
        mdsdata = mds(caseindex,:);
        
        hold on;
                
        ph = plot3(mdsdata(:,1),mdsdata(:,2),mdsdata(:,3),markers(ClusterIndex(i)),'MarkerEdgeColor',colors(ClusterIndex(i),:),'MarkerFaceColor',colors(ClusterIndex(i),:),'MarkerSize',10,'LineWidth',2);
        set(ph,'Tag','MDSHighLight');
    end
end

