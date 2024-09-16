function RaguDSPMap(map,ChanPos,mode,varargin)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

h = gca;
pos = getpixelposition(h);
msize = max(pos(3:4)) / 1000;

%set(h,'XTickLabel',[],'YTickLabel',[],'FontSize',1);

switch mode
    case 1
        s = ceil(5 / numel(map) / msize);
        varargin = [varargin,{'Resolution',s,'NoExtrapolation','NoScale'}];
        dspQMap(map,ChanPos,varargin);
    case 2
        s = ceil(10 / numel(map) / msize);
        if (s > 10)
            s = 10;
        end
%        varargin = [varargin,{'Resolution',s,'NoExtrapolation','NoScale'}];
        varargin = [varargin,{'Resolution',s,'NoScale'}];
        
        dspCMap(map,ChanPos,varargin);
end

ud.Map = map;
ud.Channel = ChanPos;
ud.Style = mode;
ud.varargin = varargin;

if vararginmatch(varargin,'tValue')
    ud.tValue = varargin{vararginmatch(varargin,'tValue')+1};
end

hcmenu = uicontextmenu;

uimenu(hcmenu, 'Label', 'Plot map',             'Callback', {@PlotAMap,0,0},'UserData',ud);
uimenu(hcmenu, 'Label', 'Plot map (with nose)', 'Callback', {@PlotAMap,2,0},'UserData',ud);
uimenu(hcmenu, 'Label', 'Plot map (with nose and electrodes)', 'Callback', {@PlotAMap,3,0},'UserData',ud);
uimenu(hcmenu, 'Label', '3D Map',               'Callback', {@ThreeDMap,0},'UserData',ud);

if vararginmatch(varargin,'tValue')
    uimenu(hcmenu, 'Label', 'Plot t-map',             'Callback', {@PlotAMap,0,1},'UserData',ud);
    uimenu(hcmenu, 'Label', 'Plot t-map (with nose)', 'Callback', {@PlotAMap,2,1},'UserData',ud);
    uimenu(hcmenu, 'Label', 'Plot t-map (with nose and electrodes)', 'Callback', {@PlotAMap,3,1},'UserData',ud);
    uimenu(hcmenu, 'Label', 'Plot 3D t-map',          'Callback', {@ThreeDMap,1},'UserData',ud);
end

uimenu(hcmenu, 'Label', 'Export map', 'Callback', {@ExportAMap,0},'UserData',ud);

if vararginmatch(varargin,'tValue')
    uimenu(hcmenu, 'Label', 'Export t-map', 'Callback', {@ExportAMap,1},'UserData',ud);
end


children = get(h,'Children');
 
for kid = 1:numel(children)
    set(children(kid),'uicontextmenu',hcmenu);
end



function ExportAMap(obj,eventdata,DoT)

ud = get(obj,'UserData');
name = '*';

if isfield(ud,'Name')
    name = strtrim(ud.Name(:)');
end


[fn, pn] = uiputfile([name '.txt'], 'Save map to textfile');

if fn == 0 
    return
end

fp = fopen([pn fn],'wt');
for i = 1:numel(ud.Channel)
    if isfield(ud.Channel(1),'Name')
        fprintf(fp,'\t%s',ud.Channel(i).Name);
    else
        fprintf(fp,'\t%C03i',i);
    end
end

fprintf(fp,'\n%s',name);

switch DoT
    case 0
    for i = 1:numel(ud.Channel)
        fprintf(fp,'\t%f',ud.Map(i));
    end
    case 1
    for i = 1:numel(ud.Channel)
        fprintf(fp,'\t%f',ud.tValue(i));
    end
end

fclose(fp);


function ThreeDMap(obj,eventdata,DoT)

PlotAMap(obj,eventdata,1,DoT)


function PlotAMap(obj,eventdata,MapType,DoT)

if nargin < 3
    MapType = 0;
end

if nargin < 4
    DoT = 0;
end

h = figure;
set(h,'Color',[1 1 1]);
ud = get(obj,'UserData');

if MapType == 1
    ud.Style = 3;
end

subplot('Position',[0.1 0.15 0.8 0.8]);

units = get(h,'Units');

set(h,'Units','pixels');
pos = get(h,'OuterPosition');

s =ceil(500/min(pos(3:4)));
set(h,'Units',units);

if vararginmatch(ud.varargin,'Resolution')
    ud.varargin{vararginmatch(ud.varargin,'Resolution')+1} = s;
end

if vararginmatch(ud.varargin,'Title')
    tit = ud.varargin{vararginmatch(ud.varargin,'Title')+1};
    if (DoT == 1)
        tit = [tit ' (t-Map)'];
    end
    
    set(h,'Name',tit);
end
if DoT == 0
    v = ud.Map;
else
    v = ud.tValue;
end

if isnumeric(ud.varargin{1})
    if DoT == 1
        CStep = 1;
        ud.varargin{1} = 1;
    else
        CStep = ud.varargin{1};
    end
else
    if DoT == 1
        CStep = 1;
        ud.varargin{vararginmatch(ud.varargin,'Step')+1} = 1;
    else
        CStep = ud.varargin{vararginmatch(ud.varargin,'Step')+1};
    end
end


if MapType == 2
    index = [];
    for i = 1:numel(ud.varargin)
        if strcmp(ud.varargin{i},'NoExtrapolation')
            index = [index i];
        end
    end    
    ud.varargin(index) = [];
    ud.varargin = [ud.varargin 'ShowNose' 15];
end

if MapType == 3
    index = [];
    for i = 1:numel(ud.varargin)
        if strcmp(ud.varargin{i},'NoExtrapolation')
            index = [index i];
        end
    end    
    ud.varargin(index) = [];
    ud.varargin = [ud.varargin 'ShowNose' 15 'Label' '*','LabelSize',3, 'LabelColor' [0 0 0]];
end



switch ud.Style
    case 1
        dspQMap(v,ud.Channel,ud.varargin);
    case 2
        dspCMap(v,ud.Channel,ud.varargin);
    case 3
        dsp3DMap(v,ud.Channel,ud.varargin);
end

subplot('Position',[0.3 0.05 0.4 0.05]);
if isnumeric(CStep)
    dspCMapColorbar(CStep,'br');
else
    dspCMapColorbar(max(abs(v(:)))/8,'br');
end