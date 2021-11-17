%pop_ShowIndMSDyn() Show microstate dynamics over time
%
% Usage:
%   >> [AllEEG, TheEEG, com] = pop_ShowIndMSDyn(AllEEG,TheEEG,UseMean,FitPar, MeanSet)
%
% EEG lab specific:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEGs that may be analysed
%
%   "TheEEG" 
%   -> EEG structure with the EEG to search for templates
%
%   UseMean
%   -> True if a mean cluster center is to be used to quantify the EEG
%   data, false (default) if the template from the data itself is to be used
%
%   "Number of Classes" / FitPar.nClasses 
%   -> Number of clusters to quantify
%
%   "Name of Mean" (GUI)
%   -> EEG dataset containing the mean clusters to be used if UseMean is
%   true, else not relevant
%
%   Meanset (parameter)
%   -> Index of the AllEEG dataset containing the mean clusters to be used 
%      if UseMean is true, else not relevant
%
% Output:
%
%   "AllEEG" 
%   -> AllEEG structure with all the EEG (fitting parameters may be updated)
%
%   "TheEEG" 
%   -> EEG structure with the EEG (fitting parameters may be updated)
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

function [AllEEG, TheEEG, com] = pop_ShowIndMSDyn(AllEEG,TheEEG,UseMean,FitPar, MeanSet)

    com = '';
    
    if numel(TheEEG) > 1
        errordlg2('pop_findMSTemplates() currently supports only a single TheEEG as input');
        return;
    end
    
    if nargin < 3,     UseMean =  false;    end
    if nargin < 4,     FitPar  = [];        end 
    if nargin < 5,     MeanSet = [];        end 

    if UseMean == false && ~isfield(TheEEG,'msinfo')
        errordlg2('The data does not contain microstate maps','Show microstate dynamics');
        return;
    end
    
    if UseMean == true && isempty(MeanSet)
        nonempty = find(cellfun(@(x) isfield(x,'msinfo'), num2cell(AllEEG)));
        HasChildren = cellfun(@(x) isfield(x,'children'), {AllEEG.msinfo});
        nonemptyMean = nonempty(HasChildren);
    
        AvailableMeans = {AllEEG(nonemptyMean).setname};
        res = inputgui( 'geometry', {1 1}, 'geomvert', [1 4], 'uilist', { ...
            { 'Style', 'text', 'string', 'Name of mean', 'fontweight', 'bold'  } ...
            { 'Style', 'listbox', 'string', AvailableMeans, 'tag','SelectSets'}});
     
        if isempty(res)
            return
        end
        MeanSet = nonemptyMean(res{1});
    end
    
    if UseMean == false
        if isfield(TheEEG.msinfo,'FitPar');                params = TheEEG.msinfo.FitPar;
        else params = [];
        end
    else
        if isfield(AllEEG(MeanSet).msinfo,'FitPar');     params = AllEEG(MeanSet).msinfo.FitPar;
        else params = []; %#ok<*SEPEX>
        end
    end
    [FitPar,paramsComplete] = UpdateFitParameters(FitPar,params,{'nClasses','lambda','PeakFit','b','BControl'});

    if nargin < 4 || paramsComplete == false
        if UseMean == false     
            FitPar = SetFittingParameters(TheEEG.msinfo.ClustPar.MinClasses:TheEEG.msinfo.ClustPar.MaxClasses,FitPar);
        else
            FitPar = SetFittingParameters(AllEEG(MeanSet).msinfo.ClustPar.MinClasses:AllEEG(MeanSet).msinfo.ClustPar.MaxClasses,FitPar);
        end
    end
    if isempty(FitPar.nClasses);   return; end
    
    if UseMean == false
        Maps   = TheEEG.msinfo.MSMaps(FitPar.nClasses).Maps;
        cmap   = TheEEG.msinfo.MSMaps(FitPar.nClasses).ColorMap;
    else
        Maps   = AllEEG(MeanSet).msinfo.MSMaps(FitPar.nClasses).Maps;
        cmap   = AllEEG(MeanSet).msinfo.MSMaps(FitPar.nClasses).ColorMap;
        AllEEG(MeanSet).msinfo.FitPar = FitPar;
    end
    TheEEG.msinfo.FitPar = FitPar;
    
    if UseMean == true
        LocalToGlobal = MakeResampleMatrices(TheEEG.chanlocs,AllEEG(MeanSet).chanlocs);
        [MSClass,gfp,fit] = AssignMStates(TheEEG,Maps,FitPar,AllEEG(MeanSet).msinfo.ClustPar.IgnorePolarity,LocalToGlobal);
    else
        [MSClass,gfp,fit] = AssignMStates(TheEEG,Maps,FitPar,TheEEG.msinfo.ClustPar.IgnorePolarity);
    end
    
    if isempty(MSClass)
        return;
    end
    fig_h = figure();
    ud.nClasses = size(Maps,1);
    ud.Sorted = UseMean;
    ud.gfp = gfp;
    ud.Assignment = MSClass;
    ud.cmap = cmap;
    ud.Start  =  0;
    ud.Segment = 1;
    ud.Time   = TheEEG.times;
    ud.XRange = min([10000 ud.Time(end)]);
    ud.event = TheEEG.event;

    ud.MaxY   = 10;
    ud.nSegments = TheEEG.trials;

    set(fig_h,'userdata',ud);
    PlotMSDyn([],[],fig_h);

     if UseMean == true
        set(fig_h, 'Name', ['Microstate dynamics of ' TheEEG.setname ' (Template: ' AllEEG(MeanSet).setname ')'],'NumberTitle','off');
     else
        set(fig_h, 'Name', ['Microstate dynamics of ' TheEEG.setname ' (own template)'],'NumberTitle','off');
     end
  
    uicontrol('Style', 'pushbutton', 'String', '|<<','Units','Normalized','Position', [0.11 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  ,-Inf});
    uicontrol('Style', 'pushbutton', 'String',  '<<','Units','Normalized','Position', [0.21 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  ,-10000 });
	uicontrol('Style', 'pushbutton', 'String',   '<','Units','Normalized','Position', [0.31 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  , -1000 });
    uicontrol('Style', 'pushbutton', 'String', '>'  ,'Units','Normalized','Position', [0.41 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  ,  1000});
    uicontrol('Style', 'pushbutton', 'String', '>>' ,'Units','Normalized','Position', [0.51 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  , 10000 });
    uicontrol('Style', 'pushbutton', 'String', '>>|','Units','Normalized','Position', [0.61 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Move'  , Inf});
    uicontrol('Style', 'pushbutton', 'String', '<>' ,'Units','Normalized','Position', [0.71 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'ScaleX', -1000});
    uicontrol('Style', 'pushbutton', 'String', '><' ,'Units','Normalized','Position', [0.81 0.05 0.08 0.05], 'Callback', {@PlotMSDyn, fig_h, 'ScaleX',  1000});
    uicontrol('Style', 'slider'    ,'Min',ud.Time(1),'Max',ud.Time(end),'Value',ud.Time(1) ,'Units','Normalized','Position', [0.1 0.12 0.8 0.05], 'Callback', {@PlotMSDyn, fig_h, 'Slider',  1});

    uicontrol('Style', 'pushbutton', 'String', '-'   ,'Units','Normalized','Position', [0.91 0.30 0.07 0.2], 'Callback', {@PlotMSDyn, fig_h, 'ScaleY', 1/0.75});
    uicontrol('Style', 'pushbutton', 'String', '+'   ,'Units','Normalized','Position', [0.91 0.50 0.07 0.2], 'Callback', {@PlotMSDyn, fig_h, 'ScaleY',   0.75});

    uicontrol('Style', 'text'      , 'String',sprintf('Explained variance: %3.1f%%',fit * 100),'Units','Normalized','Position', [0.1 0.19 0.8 0.03]);
    
    if UseMean == false
        uicontrol('Style', 'pushbutton', 'String', 'Map' ,'Units','Normalized','Position', [0.91 0.70 0.07 0.2], 'Callback', {@PlotMSMaps, TheEEG,ud.nClasses});
    else
        uicontrol('Style', 'pushbutton', 'String', 'Map' ,'Units','Normalized','Position', [0.91 0.70 0.07 0.2], 'Callback', {@PlotMSMaps, AllEEG(MeanSet),ud.nClasses});
    end    

    
    if UseMean < 2
        com = sprintf('com = pop_ShowIndMSDyn(%s, %s, 0, %s);'    , inputname(1), inputname(2),struct2String(FitPar));
    else
        com = sprintf('com = pop_ShowIndMSDyn(%s, %s, 1, %s, %i);', inputname(1), inputname(2), struct2String(FitPar), MeanSet);
    end
end


function PlotMSMaps(~,~,TheEEG,nClasses)
    pop_ShowIndMSMaps(TheEEG,nClasses);
end

function PlotMSDyn(obj, ~,fh, varargin)

    figure(fh);
    ax = subplot('Position',[0.1 0.3 0.8 0.65]);
    ud = get(fh,'UserData');
    
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
    
    if ud.XRange < 1
        ud.XRange = 1;
    end
    
    if ud.XRange > ud.Time(end) - ud.Time(1)
        ud.XRange = ud.Time(end) - ud.Time(1);
    end
    
    ud.MaxY = ud.MaxY * p.Results.ScaleY;
    
    slider = findobj(fh,'Style','slider');
    set(slider,'Value',ud.Start);
        
    Data2Show = find(ud.Time >= ud.Start & ud.Time <= (ud.Start + ud.XRange));
    Fit = zeros(ud.nClasses,numel(Data2Show));
    for e = 1:numel(ud.event)
        if ~isfield(ud.event(e),'epoch')
            epoch = 1;
        else
            epoch = ud.event(e).epoch;
        end
        if epoch ~= ud.Segment
            continue
        end
    end
    for c = 1:ud.nClasses
        idx = ud.Assignment(Data2Show,ud.Segment) == c;
        Fit(c,idx) = ud.gfp(1,Data2Show(1,idx),ud.Segment);
    end
    
    bar(ud.Time(Data2Show),Fit',1,'stacked','EdgeColor','none');
    colormap(ud.cmap);
    hold on
    axis([ud.Start-0.5 ud.Start+ ud.XRange+0.5 0, ud.MaxY]);
    xtick = num2cell(get(ax,'XTick')/ 1000);
    if (xtick{2} - xtick{1}) >= 1
        labels = cellfun(@(x) sprintf('%1.0f:%02.0f:%02.0f',floor(x/3600),floor(rem(x/60,60)),rem(x,60)),xtick, 'UniformOutput',false);
    else
        labels = cellfun(@(x) sprintf('%1.0f:%02.0f:%02.0f:%03.0f',floor(x/3600),floor(rem(x/60,60)),rem(x,60),rem(x*1000,1000)),xtick, 'UniformOutput',false);
    end
    set(ax,'XTickLabel',labels,'FontSize',7);
    
    title(sprintf('Segment %i of %i (%i classes)',ud.Segment,ud.nSegments,ud.nClasses))
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
        plot([t,t],[0,ud.MaxY],'-k');
        if isnumeric(ud.event(e).type)
            txt = sprintf('%1.0i',ud.event(e).type);
        else
            txt = ud.event(e).type;
        end
        text(t,ud.MaxY,txt, 'Interpreter','none','VerticalAlignment','top','HorizontalAlignment','right','Rotation',90);
    end
    hold off
    set(fh,'UserData',ud);
end

