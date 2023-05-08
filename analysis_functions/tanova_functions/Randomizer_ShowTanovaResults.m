function Randomizer_ShowTanovaResults(out,h)

% Copyright 2009-2019 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License
if (nargin > 1)
    handles = guidata(h);
    if strcmp(get(handles.Options_PartiallEtaSquare ,'Checked'),'on')
        EtaSqTypeToUse = 2;
    else
        EtaSqTypeToUse = 1;
    end
    if strcmp(get(handles.AnalysisSS_Type3 ,'Checked'),'on')
        EtaSqTypeToUse = EtaSqTypeToUse + 2;
    end
else
    EtaSqTypeToUse = 2;
end


if nargin > 1
    handles = guidata(gcf);
    handles.CurrentView = 'TANOVA';
    guidata(gcf,handles);
end
    
if out.DoGFP == 0
    pTanova = out.PTanova;
else
    pTanova = out.GFPPTanova;
end

time = (0:(size(out.V,4)-1)) * out.DeltaX + out.TimeOnset;
axislabel = out.txtX;

axismin = time(out.StartFrame);
axismax = time(out.EndFrame);

Threshold = ones(2,8) * out.Threshold;

if (isfield(out,'CritFDR_p') && out.DoGFP == 0)
    if strcmp(questdlg('Use FDR Threshold?','show TANOVA results','Yes','No','Yes'),'Yes')
        Threshold = out.CritFDR_p;
    end
end    

if nargin < 2
    h = figure(103);
    set(h,'Units','normalized','Position',[0.05 0.05 0.9 0.8],'MenuBar','figure','ToolBar','figure');
    clf

    mymenu = uimenu('Label','Export');
    uimenu(mymenu,'Label','Save as Metafile','Callback',{@SaveFigure,'-dmeta','*.wmf', 'Save figure to Metafile'});
    uimenu(mymenu,'Label','Save as Bitmap','Callback',{@SaveFigure,'-dbitmap','*.bmp', 'Save figure to bitmap'});
    uimenu(mymenu,'Label','Copy as Metafile','Callback',{@SaveFigure,'-dmeta',[], []});
    uimenu(mymenu,'Label','Copy as Bitmap','Callback',{@SaveFigure,'-dbitmap',[], []});
    uimenu(mymenu,'Label','Export to text','Callback',{@ExportFigure,'*.txt', 'Save as textfile',pTanova});
else
    figure(h)
end

bc = 0.7;
bcol = [bc bc bc];

SelDesign = out.Design;
SelDesign(isnan(SelDesign(:,1)),:) = [];

DoF1    = (numel(unique(SelDesign(:,1)))> 1);

if size(SelDesign,2) < 2
    DoF2 = false;
else
    DoF2    = (numel(unique(SelDesign(:,2)))> 1);
end
if out.TwoFactors == 0
    DoF2 = 0;
end

if DoF1 && DoF2
    nc = 4;
elseif DoF1 && ~DoF2
    nc = 2;
else
    nc = 1;
end

if numel(unique(out.IndFeature(~isnan(out.IndFeature))))> 1
    ng = 2;
else
    ng = 1;
end

if (isfield(out,'strF1'))
    strF1 = out.strF1;
else
    strF1 = 'Factor 1';
end

if (isfield(out,'strF2'))
    strF2 = out.strF2;
else
    strF2 = 'Factor 2';
end

t = {'' [out.IndName ' main effect'] strF1 [strF1 ' * ' out.IndName] strF2 [strF2 ' * ' out.IndName] [strF1 ' * ' strF2] [strF1 ' * ' strF2 ' * ' out.IndName]};

hp = zeros(2,4);

%d = get(gcf,'UserData');
d = out;
if ng == 2
    d.MainGroupLabel = 'All';
else
    b = unique(out.IndFeature(~isnan(out.IndFeature)));
    d.MainGroupLabel = char(out.GroupLabels{b(1)});
end

if out.ContBetween == false
    b = unique(out.IndFeature(~isnan(out.IndFeature)));
    d.GLabels = out.GroupLabels(b);
end

    
d.DSPconds = out.conds;
d.DSPconds(isnan(out.Design(:,1))) = [];
d.ng = ng;
d.nc = nc;
d.titles = t;
d.Averaged = 0;
d.SelDesign = SelDesign;
d.ContBetween = out.ContBetween;
d.axislabel = axislabel;
d.time = time;
d.Threshold = out.Threshold;

ExpVar = nan(2,4,numel(time));
if out.DoGFP == false
    if isfield(d,'TExpVar')
        ExpVar = d.TExpVar{EtaSqTypeToUse};
        d.EffectToShow = out.TEffects;
    end
else
    if isfield(d,'GFPExpVar')
        ExpVar = d.GFPExpVar{EtaSqTypeToUse};
        d.EffectToShow = out.GFPEffects;
    end
end

if size(d.V,4) == 1
    out.MeanInterval = 1;
end

if nc * ng > 1
    ExpVarp = RaguTanovaSubplot(nc,ng,1,1);
else
    ExpVarp = RaguTanovaSubplot(nc+1,ng,1,1);
end

AllExpVar = reshape(ExpVar,[8,size(ExpVar,3)]);

if out.MeanInterval == 1
    ExpVarBars = bar([100*AllExpVar(2:end,:)' ; zeros(1,size(AllExpVar,1)-1)],'stacked','BarWidth',1);
    set(ExpVarp,'XLim',[0.25 1.75]);

else
    ExpVarBars = SmoothStackPlot(time,100*AllExpVar(2:end,:)');
%    ExpVarBars = bar(time,100*AllExpVar(2:end,:)','stacked','BarWidth',1);
    set(ExpVarp,'XLim',[axismin axismax]);
end
%set(ExpVarp,'YLim',[0 axismax]);
title('Cumulative Explained Variance','FontSize',10);
xlabel(d.txtX);
ylabel('% Exp Var.');
if ~out.MeanInterval
    tc = (axismin + axismax) / 2;
    ymax = max(get(ExpVarp,'YLim'));
    lh = patch([tc tc tc tc],[0 0 ymax ymax],[1 1 1 1],'k','EdgeColor','k');
    set(lh,'Tag','Cursor');
end

if out.MeanInterval
    d.Averaged = 1;
    for i = 1:ng
        for j = 1:nc
            if (i * j > 1) || (nc *ng == 1)
                ColIdx = j * 2 + i - 3;
                Col = get(ExpVarBars(ColIdx),'FaceColor');
                if nc * ng == 1
                    hp(i,j) = RaguTanovaSubplot(nc+1,ng,2,1,Col);
                else
                    hp(i,j) = RaguTanovaSubplot(nc,ng,j,i,Col);
                end
                cla(hp(i,j));
                h = bar(0.5,squeeze(pTanova(i,j,1,1)));
                set(h,'BarWidth',1,'EdgeColor',[0 0 0],'FaceColor',[0 0 0]);
                set(h,'Tag','TanovaP','UserData',ExpVar(i,j));
                title([t{2*j+i-2} ': Exp Var = ', sprintf('%4.2f%%',100*ExpVar(i,j)), ', p= ' sprintf('%5.5f',pTanova(i,j))],'Interpreter','none','FontSize',8);
                axis([0 1 0 1]);
                set(hp(i,j),'Tag','subplot','Userdata',t{2*j+i-2});
                xlabel(d.txtX);
                ylabel('p-Value');
            end
        end
    end
else    
    rsig = zeros(ng,nc,size(pTanova,3));
    for i = 1:ng
        for j = 1:nc
            CritDuration = inf;
            if out.DoGFP == 0
                if isfield(out,'CritDuration')
                    CritDuration = out.CritDuration(i,j);
                end
            else
                if(isfield(out,'CritDurationGFP'))
                    CritDuration = out.CritDurationGFP(i,j);
                end
            end
            sig = squeeze(pTanova(i,j,:,1) > out.Threshold);
            rsig(i,j,:) = zeros(size(sig));
            isOn = false;
            for tm = 1:numel(sig)
                if sig(tm) == false
                    if isOn == false
                        tStart = tm;
                    end
                    isOn = true;
                else
                    if isOn == true && (tm - tStart - 1) >= CritDuration
                        rsig(i,j,tStart:(tm-1)) = 1;
                    end
                    isOn = false;
                end
            end
            if isOn == true && (tm - tStart) >= CritDuration
                rsig(i,j,tStart:tm) = 1;
            end
        end
    end
    for i = 1:ng
        for j = 1:nc
            if (i * j > 1) || (nc *ng == 1)
                ColIdx = j * 2 + i - 3;

                Col = get(ExpVarBars(ColIdx),'FaceColor');

                if nc * ng == 1
                    hp(i,j) = RaguTanovaSubplot(nc+1,ng,2,1,Col);
                else
                    hp(i,j) = RaguTanovaSubplot(nc,ng,j,i,Col);
                end
                set(hp(i,j),'Tag','subplot');
                h = bar(time,double(squeeze(pTanova(i,j,:,1) > Threshold(i,j))));
                set(h,'BarWidth',1,'EdgeColor',bcol,'FaceColor',bcol);
                hold on
                if any(rsig(i,j,:) > 0)
                    h = bar(time,squeeze(rsig(i,j,:)));
                    set(h,'BarWidth',1,'EdgeColor',[0 1 0],'FaceColor',[0 1 0]);
                end
                tanh = plot(time,squeeze(pTanova(i,j,:,1)),'-k');
                set(tanh,'Tag','TanovaP','UserData',squeeze(ExpVar(i,j,:)));
                title(t{2*j+i-2},'Interpreter','none','FontSize',10);
                axis([axismin axismax 0 1]);
                tc = (axismin + axismax) / 2;
                lh = patch([tc tc tc tc],[0 0 1 1],[1 1 1 1],'r','EdgeColor','r');
%                lh = plot([tc tc], [0 1],'-r');
                set(lh,'Tag','Cursor');
                set(hp(i,j),'Tag','subplot','Userdata',t{2*j+i-2});
                xlabel(d.txtX);
                ylabel('p-Value');
            end
        end
    end
end


annotation('textbox',[0.022 0.97 0.495 0.02],'String','Tip: Click to select one time point, right click to extend selection, double click to cover significant period, double right click to show explained variance','HorizontalAlignment','center','VerticalAlignment','middle','Tag','Transient','FontSize',8);

EverythingToShow = cell2mat(d.EffectToShow);

d.mdsScaleFactor = max(abs(EverythingToShow(:)));

if isfield(out,'Channel')
    d.Channel = out.Channel;
end

set(gcf,'UserData',d);

if (out.DoGFP == 0)
    uicontrol('Style','pushbutton','String','Zoom','Units','normalized','Position',[0.86 0.21 0.03 0.03],'Callback',{@RescaleMDS,1,true},'Tag','Transient');
    uicontrol('Style','pushbutton','String','+','Units','normalized','Position',[0.86 0.18 0.03 0.03],'Callback',{@RescaleMDS,.75,false},'Tag','Transient');
    uicontrol('Style','pushbutton','String','-','Units','normalized','Position',[0.86 0.15 0.03 0.03],'Callback',{@RescaleMDS,1.5,false},'Tag','Transient');
end

for i = 1:ng
    for j = 1:nc
        if ~strcmp(get(hp(i,j),'Type'),'axes')
            continue
        end
        set(hp(i,j),'ButtonDownFcn',{@ShowTanovaBtCallback, i,j});
        kids = get(hp(i,j),'Children');
        for c = 1:numel(kids)
            set(kids(c),'ButtonDownFcn',{@ShowTanovaBtCallbackKid, i,j});
        end
    end
end
bDone = false;
for i = 1:2
    for j = 1:4
        if(hp(i,j) ~= 0) && bDone == false
            
            ShowTanovaBtCallback(hp(i,j),[], i,j);
            bDone = true;
        end
    end
end

            

function ExportFigure(~, ~,mask,comment,PTanova)

[filename, pathname] = uiputfile(mask,comment);
if isequal(filename,0) || isequal(pathname,0)
    return
end

[fp,err] = fopen(fullfile(pathname, filename),'wt');

if fp == -1
    errordlg(err);
    return
end
    
d = get(gcf,'UserData');

fprintf(fp,'Time');

for i = 1:d.ng
    for j = 1:d.nc
        if (i * j > 1)
            fprintf(fp,'\t%s',d.titles{d.ng*j+i-2});
        end
    end
end


for t = 1:size(PTanova,3)
    fprintf(fp,'\n%5.2f',d.time(t));
    for i = 1:d.ng
        for j = 1:d.nc
            if (i * j > 1)
                fprintf(fp,'\t%4.4f',PTanova(i,j,t,1));
            end
        end
    end
end
    
fclose(fp);





function SaveFigure(~,~ ,Device,mask,comment)

if (isempty(mask))
    print(Device);
else

    [filename, pathname] = uiputfile(mask,comment);
    if isequal(filename,0) || isequal(pathname,0)
        return
    end
    print(Device,fullfile(pathname, filename));
end



function ShowTanovaBtCallbackKid(obj, event, in1,in2)
ph = get(obj,'Parent');
if (ph ~= 0)
    ShowTanovaBtCallback(ph, event, in1,in2)
end



function ShowTanovaBtCallback(obj, event, in1,in2)
    persistent chk
    
    if isempty(event)
        event.Button = 1;
    end
       
    if isempty(chk)
        chk = 1;
        pause(0.5); %Add a delay to distinguish single click from a double click
        if chk == 1
            RealShowTanovaBtCallback(obj, event, in1,in2,'Single');
            chk = [];
        end
    else
        chk = [];
        RealShowTanovaBtCallback(obj, event, in1,in2,'Double');
    end



function RealShowTanovaBtCallback(obj, event, in1,in2,ClickType)


%par = get(obj,'Parent');
%ClickType = get(par,'SelectionType');
pos = get(obj,'CurrentPoint');

%fh = figure(103);
fh = gcf;

tanh = findobj(obj,'Tag','TanovaP');
x = get(tanh,'XData');
y = get(tanh,'YData');
d = get(get(obj,'Parent'),'UserData');
if isempty(x)
    x = 1;
end
delta = abs(x - pos(1,1));

ch = findobj(fh,'Tag','Cursor');
if numel(ch) > 0
    idxOld = find(min(get(ch(1),'XData')) == x);

    switch event.Button
        case 1 % left click
            switch ClickType
                case 'Single' % Place an instant cursor where the user clicked
                    [mn,idx] = min(delta);
                    idx = [idx idx];
                    FaceAlpha = 1;
                case 'Double' % If p < Threshold, select the significant area
                    [mn,tmpidx] = min(delta);
        
                    if y(tmpidx) <= d.Threshold && d.Averaged == 0
                        tmp = find(y(1:tmpidx)   > d.Threshold,1,'last' )+1;
                        if isempty(tmp)
                            idx(1) = 1;
                        else
                            idx(1) = tmp;
                        end
                        tmp = find(y(tmpidx:end) > d.Threshold,1,'first')+ tmpidx - 2;
                        if isempty(tmp)
                            idx(2) = numel(y);
                        else
                            idx(2) = tmp;
                        end
                    else
                        idx = [tmpidx tmpidx];
                    end
                    FaceAlpha = 0.2;
            end
        
        case 3 % right click
            switch ClickType
                case 'Single' % Place an instant cursor where the user clicked
                    [mn,tmpIdx] = min(delta);
            
                    idx(1) = min(tmpIdx,idxOld);
                    idx(2) = max(tmpIdx,idxOld);
        
                    if idx(2) > idx(1)
                        FaceAlpha = 0.2;
                    else
                        FaceAlpha = 1;
                    end
                
                case 'Double'
                
                    tanh = findobj(obj,'Tag','TanovaP');
                    es = get(tanh,'UserData') * 100;
                    oldFig = gcf;
                    Figh = findobj('Tag','ExpVarFigure');
                    if isempty(Figh)
                        newFig = figure();
                        set(newFig,'Tag','ExpVarFigure');
                    else
                        figure(Figh);
                    end
                    plot(x,es,'-k');

                    yLim = get(gca,'YLim');
                    ylabel('Explained Variance');
                    title(get(obj,'UserData'));
                    patch(get(ch(1),'XData'),[yLim(1) yLim(1) yLim(2) yLim(2)],[1 1 1 1],'r','EdgeColor','r','FaceAlpha',0.2);
                    figure(oldFig);
                    return;
            end
    end
else
    idx(1) = d.StartFrame;
    idx(2) = d.StartFrame;
end
if isfield(d,'AutoMin')
    [mn,idx] = min(get(tanh,'YData'));
end
if in1 == 0
%    [~,idx] = get(tanh,'YData')
%    idx = 1;
end

for i = 1:numel(ch)
    set(ch(i),'XData',[x(idx(1)) x(idx(2)) x(idx(2)) x(idx(1))],'FaceAlpha',FaceAlpha);
end

sh = findobj(fh,'Tag','subplot');

for i = 1:numel(sh)
    set(get(sh(i),'Title'),'FontWeight','light');
end

set(get(obj,'Title'),'FontWeight','bold');
if (d.Averaged == 0)
    txt = cell(numel(sh),1);
    for i = 1:numel(sh)
        if isempty(get(sh(i),'UserData'))
            continue;
        end
        tanh = findobj(sh(i),'Tag','TanovaP');
        y = get(tanh,'YData');
        es = get(tanh,'UserData') * 100;
        if (idx(1) == idx(2))
            txt{i} = sprintf('%s: Exp Var = %4.2f%%, p = %5.5f (%1.1f %s)',get(sh(i),'UserData'),es(idx(1)),y(idx(1)),x(idx(1)),d.axislabel);
        else
            txt{i} = sprintf('%s: Mean Exp Var: %4.2f%% (%1.1f - %1.1f %s)',get(sh(i),'UserData'),mean(es(idx(1):idx(2))),x(idx(1)),x(idx(2)),d.axislabel);
        end
        set(get(sh(i),'Title'),'String',txt{i},'Interpreter','none','FontSize',10);
    end
else
    txt = cell(numel(sh),1);
    for i = 1:numel(sh)
        tanh = findobj(sh(i),'Tag','TanovaP');
        es = get(tanh,'UserData') * 100;
        y = get(tanh,'YData');
        txt{i} = sprintf('%s: Exp Var = %4.2f%%, p = %5.5f',get(sh(i),'UserData'),es,y);
        set(get(sh(i),'Title'),'String',txt{i},'Interpreter','none','FontSize',10);
    end
    
end

if in2 == 4
    nLevel1 = max(d.SelDesign(:,1));
    mn = min(d.SelDesign(:,2));
    iDesign = d.SelDesign(:,1) + (nLevel1+1) * (d.SelDesign(:,2)-mn +1);
    idx_map = unique(iDesign);

end


DataToShow = d.EffectToShow{in1,in2};
MapIdx = idx - d.StartFrame + 1;

MapIdx = max(MapIdx,1);
MapIdx = min(MapIdx,size(DataToShow,4));

DataToShow = nanmean(DataToShow(:,:,:,MapIdx(1):MapIdx(2)),4);

ng = size(DataToShow,1);
nc = size(DataToShow,2);

d.lbl = cell(nc,1);

switch in2
    case 1
        d.lbl = {'Main'};
    case 2
        if d.ContF1
            d.lbl{1} = [d.strF1 '+'];
            d.lbl{2} = [d.strF1 '-'];
        else
           [d.lbl{1:nc}] = deal(d.DLabels1.Label);
        end
    case 3
        [d.lbl{1:nc}] = deal(d.DLabels2.Label);
    case 4
        for i = 1:numel(idx_map)
            l1 = rem(idx_map(i),nLevel1+1);
            l2 = (idx_map(i) - l1) / (nLevel1+1) +mn -1;
            [ll1c{1:numel(d.DLabels1)}] = deal(d.DLabels1.Level);
            ll1 = cell2mat(ll1c);
            idx1 = find(ll1 == l1,1);
            [ll2c{1:numel(d.DLabels2)}] = deal(d.DLabels2.Level);
            ll2 = cell2mat(ll2c);
            idx2 = find(ll2 == l2,1);
            d.lbl{i} = sprintf('%s\n%s',d.DLabels1(idx1).Label,d.DLabels2(idx2).Label);
        end
end

mapScale = max(abs(DataToShow(:))) / 5;
%cntlbl2 = {'+','-'};

delete(findall(gcf,'Tag','AnnotationTag'));
subplot(222);
if isfield(d,'Channel') && d.DoGFP == 0
%    disp('Showing mean maps')
    
    dx = 0.38 / nc;
    dy = 0.40 / ng;

    dummy = subplot('Position',[0.6 0.55,dx,dy]);
    set(dummy,'Units','pixel');
    PixPos = get(dummy,'Position');
    set(dummy,'Position',[PixPos(1) PixPos(2) min(PixPos(3:4)) min(PixPos(3:4))]);
    set(dummy,'Units','normalized');
    NormPos = get(dummy,'Position');
    dx = NormPos(3);
    dy = NormPos(4);
    delete(dummy);
   
    xStart = 0.78 - dx * nc / 2;
    yStart = 0.75 + dy * ng / 2;

    for g = 1:ng
        if in1 == 1
            txt = 'All';
        else
            if d.ContBetween == true
                txt = d.IndName;
            else
                txt = char(d.GLabels{g});
            end
        end
        th = annotation('textbox',[xStart-0.03 yStart - g * dy 0.03 dy * 0.9],'String',txt,'LineStyle','none','Tag','AnnotationTag');
        set(th,'HorizontalAlignment','center','VerticalAlignment','middle','Interpreter','none');
    end  
    for c = 1:nc
       th = annotation('textbox',[xStart + (c-1) * dx yStart dx * 0.9 0.02],'String',char(d.lbl{c}),'LineStyle','none','Tag','AnnotationTag');
        set(th,'HorizontalAlignment','center','VerticalAlignment','bottom','Interpreter','none');
    end
   
    for g = 1:ng
        for c = 1:nc
            mh = subplot('Position',[xStart + (c-1) * dx yStart - g * dy dx * 0.9 dy * 0.9]);
            set(mh,'Tag','AnnotationTag');
            dt = squeeze(DataToShow(g,c,:));
            dt = dt(:);
           
            RaguDSPMap(dt,d.Channel,d.MapStyle,'Step',mapScale); % ,'NoScale','Resolution',3);
        end
    end
end

% in2 = up down / within
% in1 = Main / Group

if d.DoGFP == 0
    MDSMaps = DataToShow;
    if d.ContBetween && in1 == 2
        MDSMaps(2,:,:) = -MDSMaps(1,:,:);
    end
    if d.ContF1 && in2 == 2
        MDSMaps(:,2,:) = -MDSMaps(:,1,:);
    end
    if size(MDSMaps,1) * size(MDSMaps,2) > 1
        maps = reshape(MDSMaps,size(MDSMaps,1)*size(MDSMaps,2),size(MDSMaps,3));
        if d.ContF1 == false && d.ContBetween == false
            maps = maps - repmat(nanmean(maps),size(maps,1),1);
        end
% PCA based
        %cov = maps' * maps;

%        opt.disp = 0;
%        [v,de] = eigs(cov,2,'LM',opt);
%    d.pro = maps*v;
        TwoDimsToMap = size(maps,1) > 2;
    
% Matlab MDS    
        ops = statset('Display','off','TolFun',0.01);
%    squareform(pdist(maps,'euclidean'))

        if TwoDimsToMap == true
            d.pro = mdscale(pdist(maps,'euclidean'),2,'Options',ops,'Criterion','strain');
        else
            d.pro = mdscale(pdist(maps,'euclidean'),1,'Options',ops,'Criterion','strain');
            d.pro(:,2) = 0;
        end
    
        v = NormDimL2(maps'*d.pro,1);

        d.pro = reshape(d.pro,size(MDSMaps,1),size(MDSMaps,2),2);
       
        if d.Averaged == 0
            d.timePT = x(idx);
        end
            
        d.in1 = in1;
        d.in2 = in2;
        set(get(obj,'Parent'),'UserData',d);

        sh = ShowMDS(d,false);

        spos = get(sh,'Position');

        col = lines();
        subplot('Position',[0.88 0.15 0.1 0.35]);
        axis off
        cla
        if d.ContBetween == false || in1 == 1
            if ng > 1 && in1 > 1
                hold on
                for g = 1:numel(d.GLabels)
                    text(0,20-g,d.GLabels{g},'Interpreter','none','VerticalAlignment','middle','FontSize',10,'Color',col(g,:));
                end
                hold off
                axis([0 8 0 20]);
                axis off
                hold off
            end
        else
        
            linecolors = lines(size(d.pro,2)*size(d.pro,1));
            hold on
  
            for i = 1:numel(d.lbl)
                plot(1,20-i,'+','Color',linecolors(i,:));
                text(2,20-i,d.lbl{i},'Interpreter','none','VerticalAlignment','middle','FontSize',8,'Color',linecolors(i,:));
               hold on
            end
            axis([0 8 0 20]);
            axis off
        end

        if isfield(d,'Channel')
            dlt = 0.03;
%        disp('Showing MDS maps');
            subplot('Position',[(spos(1)        ) (spos(2)-3*dlt) 2*dlt 2*dlt]);
            RaguDSPMap(-v(:,1),d.Channel,d.MapStyle); %,'NoScale','Resolution',3);
    
            subplot('Position',[(spos(1)+spos(3)-2*dlt) (spos(2)-3*dlt) 2*dlt 2*dlt]);
            RaguDSPMap( v(:,1),d.Channel,d.MapStyle);% ,'NoScale','Resolution',3);

            if TwoDimsToMap == true
                subplot('Position',[(spos(1)-2*dlt) (spos(2)) 2*dlt 2*dlt]);
                RaguDSPMap(-v(:,2),d.Channel,d.MapStyle); % ,'NoScale','Resolution',3);
    
                subplot('Position',[(spos(1)-2*dlt) (spos(2)+spos(4)-2*dlt) 2*dlt 2*dlt]);
                RaguDSPMap( v(:,2),d.Channel,d.MapStyle); % ,'NoScale','Resolution',3);
            else
                subplot('Position',[(spos(1)-2*dlt) (spos(2)) 2*dlt 2*dlt]);
                cla
                axis off
                subplot('Position',[(spos(1)-2*dlt) (spos(2)+spos(4)-2*dlt) 2*dlt 2*dlt]);
                cla
                axis off
            end
        end
    end
else
    subplot(122);
%    gfp = squeeze(std(Mean2Show,1,3));
    gfp = DataToShow;
    bh = bar(gfp);
    bcm = lines(32);
    xlabel('Condition');
    ylabel('GFP');

    for i = 1:numel(bh)
        set(bh(i),'FaceColor',bcm(i,:));
    end
    h = gca;
    
    if size(gfp,1) > 1
        if d.ContBetween == 0
            set(h,'XTickLabel',d.GLabels,'TickLabelInterpreter','none');
        else
            set(h,'XTickLabel',{[d.IndName,'+'],[d.IndName,'-']},'TickLabelInterpreter','none');
        end
        if (size(gfp,2) > 1)
            legend(d.lbl,'Location','SouthOutside','Orientation','horizontal','interpreter','none');
            
        end
    else
        clbl = cell(numel(d.lbl),1);
        for x = 1:numel(d.lbl)
            lbl = d.lbl{x};
            dummy = double(lbl);
            lbl(dummy == 10) = '-';
            clbl{x} = lbl;
        end
        set(h,'XTickLabel',clbl,'XTickLabelRotation',90);
    end
end


function handle = ShowMDS(d,newFig)

if nargin < 2
    newFig = false;
end
if newFig == true
    handle = axes;
else
    handle = subplot('Position',[0.60 0.15 0.25 0.35]);
end

col = lines();
hold off

psymb = 'ox+*.sdv^<>phox+*.sdv^<>phox+*.sdv^<>phox+*.sdv^<>phox+*.sdv^<>phox+*.sdv^<>phox+*.sdv^<>phox+*.sdv^<>ph';

% in2 = up down / within
% in1 = Main / Group

switch(d.in1)
    case 1 % Main effects across groups
        gLabel = {'All'};
    case 2 % Group interactions
        if d.ContBetween
            gLabel = {[d.IndName '+_'],[d.IndName '-_']};
        else
            gLabel = d.GLabels;
        end
end

switch(d.in2)
    case 1 % Main effects across condition
        cLabel = {'main'};
    case 2 % Effects of F1s
        if d.ContF1
            cLabel = {[d.strF1 '+'],[d.strF1 '-_']};
        else
            cLabel = {d.DLabels1.Label};
        end
    case 3
        cLabel = {d.DLabels2.Label};
    case 4
        NewDesign = Ragu_SortOutWithinDesign(d.Design',true);
        cLabel = cell(size(NewDesign,2),1);
        for i = 1:size(NewDesign,2)
            cLabel{i} = [d.DLabels1(NewDesign(1,i)).Label '_' d.DLabels2(NewDesign(2,i)).Label];
        end
end

pro_x = d.pro(:,:,1);
pro_y = d.pro(:,:,2);
cla
hold on
if (d.ContBetween == true && d.in1 == 2)
    if d.ContF1 == false || d.in2 ~= 2
        for c = 1:size(pro_x,2)
            plot(pro_x(:,c),pro_y(:,c),'-','Color',col(c,:));
            for g = 1:size(pro_x,1)
                text(pro_x(g,c),pro_y(g,c),[gLabel{g} '_' cLabel{c}],'Interpreter','none','VerticalAlignment','bottom','FontSize',8,'Color',col(c,:));
            end
        end
    else
        plot(pro_x(1,:),pro_y(1,:),'-','Color',col(1,:));
        for c = 1:size(pro_x,2)
            text(pro_x(1,c),pro_y(1,c),[gLabel{c} '_' cLabel{c}],'Interpreter','none','VerticalAlignment','bottom','FontSize',8,'Color',col(1,:));
        end
    end
elseif (d.ContF1 == true && d.in2 == 2)
    for g = 1:size(pro_x,1)
        plot(pro_x(g,:),pro_y(g,:),'-','Color',col(g,:));
        for c = 1:size(pro_x,2)
            text(pro_x(g,c),pro_y(g,c),[gLabel{g} '_' cLabel{c}],'Interpreter','none','VerticalAlignment','bottom','FontSize',8,'Color',col(g,:));
        end
    end
else
    for g = 1:size(pro_x,1)
        for c = 1:size(pro_x,2)
            plot(pro_x(g,c),pro_y(g,c),psymb(c),'Color',col(g,:));
%            text(pro_x(g,c),pro_y(g,c),[gLabel{g} '_' cLabel{c}],'Interpreter','none','VerticalAlignment','bottom','FontSize',8,'Color',col(g,:));
            text(pro_x(g,c),pro_y(g,c),[cLabel{c}],'Interpreter','none','VerticalAlignment','bottom','FontSize',8,'Color',col(g,:));
        end
    end
end
        
axis([-d.mdsScaleFactor d.mdsScaleFactor -d.mdsScaleFactor d.mdsScaleFactor]);


if (d.Averaged == 0)
    if d.timePT(1) == d.timePT(2)
        title(sprintf('MDS at %1.1f %s',d.timePT(1),d.axislabel));
    else
        title(sprintf('MDS from %1.1f to %1.1f %s',d.timePT(1),d.timePT(2),d.axislabel));
    end
else
    title('MDS');
end

hold off

function RescaleMDS(obj,~,fact,newFig)
d = get(get(obj,'Parent'),'UserData');
d.mdsScaleFactor = d.mdsScaleFactor * fact;
set(gcf,'UserData',d);
if newFig == true
    figure
end
ShowMDS(d,newFig);
