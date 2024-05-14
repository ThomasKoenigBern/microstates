function [c,imap,xm,ym] = dspCMap(map,ChanPos,varargin)
% dspCMaocp - Display topographic scalp maps
% ----------------------------------------
%
% Usage: dspCMap(map,ChanPos,CStep)
%
% map is the 1xN voltage map to display, where N is the number of electrode
%
% ChanPos contains the electrode positions, either as Nx3 xyz coordinates,
% or as structure withRadius, Theta and Phi (Brainvision convention), or as
% labels of the 10-10 system
%
% CStep is the size of a single step in the contourlines, a default is used
% if this is not set
%
% There are a series of options that can be set using parameter/value
% pairs:
%
% 'Colormap':   - 'bw' (Black & White)
%               - 'ww' (White & White; only contourlines)
%               - 'br' (Blue & Red; negative blue, positive red, default
%
% 'Resolution'      controls the resolution of the interpolation
% 'Label'           shows the electrode positions and labels them
% 'Gradient' N      shows vectors with gradients at every N-th grid point
% 'GradientScale'   controls the length of these vectors
% 'NoScale'         whether or not a scale is being shown
% 'LevelList'       sets the levellist
% 'Laplacian'       shows the laplacian instead of the data
% 'Plot'            Plots additional x_points 
% 'Linewidth'       Sets linewidth
% 'NoExtrapolation' Prevents maps to be etrapolated)
%
% MICROSTATELAB: The EEGLAB toolbox for resting-state microstate analysis
% Version 1.0
%
% Authors:
% Thomas Koenig (thomas.koenig@upd.unibe.ch)
% Delara Aryan  (dearyan@chla.usc.edu)
% 
% Copyright (C) 2023 Thomas Koenig and Delara Aryan
%
% If you use this software, please cite as:
% "MICROSTATELAB: The EEGLAB toolbox for resting-state microstate 
% analysis by Thomas Koenig and Delara Aryan"
% In addition, please reference MICROSTATELAB within the Materials and
% Methods section as follows:
% "Analysis was performed using MICROSTATELAB by Thomas Koenig and Delara
% Aryan."

if iscell(ChanPos)
    ChanPos = GetChannelPositionsFromLabels(ChanPos);
end

if isstruct(ChanPos)
    if isfield(ChanPos,'Theta') || isfield(ChanPos,'CoordsTheta')
        [x,y,z] = VAsph2cart(ChanPos);
    else
        x = -cell2mat({ChanPos.Y});
        y =  cell2mat({ChanPos.X});
        z =  cell2mat({ChanPos.Z});
    end
    
else
    if size(ChanPos,1) == 3
        ChanPos = ChanPos';
    end
    x = -ChanPos(:,2)';
    y =  ChanPos(:,1)';
    z =  ChanPos(:,3)';
end

r = sqrt(x.*x + y.*y + z.*z);

x = x ./ r;
y = y ./ r;
z = z ./ r;



if numel(varargin) == 1
    varargin = varargin{1};
end

if (nargin < 2)
    error('Not enough input arguments');
end

if vararginmatch(varargin,'Step')
    CStep = varargin{vararginmatch(varargin,'Step')+1};
else
    CStep = max(abs(map)) / 4;
end

if vararginmatch(varargin,'Axis')
    PlotAxis = varargin{vararginmatch(varargin,'Axis')+1};
else
    PlotAxis = gca;
end

hold(PlotAxis,'off');
cla(PlotAxis);



if vararginmatch(varargin,'NoScale')
    ShowScale = 0;
else
    ShowScale = 1;
end

if vararginmatch(varargin,'ShowNose')
    NoseRadius = varargin{vararginmatch(varargin,'ShowNose')+1};
else
    NoseRadius = 0;
end


if vararginmatch(varargin,'NoExtrapolation')
    NoExPol = 1;
else
    NoExPol  = 0;
end


if vararginmatch(varargin,'Laplacian')
    ShowLap = 1;
    LapFact = varargin{vararginmatch(varargin,'Laplacian')+1};
else
    ShowLap = 0;
end


if vararginmatch(varargin,'Interpolation')
     itype = varargin{vararginmatch(varargin,'Interpolation')+1};
else
    itype = 'v4';
end



if vararginmatch(varargin,'Linewidth')
    MapLineWidth = varargin{vararginmatch(varargin,'Linewidth')+1};
else
    MapLineWidth = 1;
end


if vararginmatch(varargin,'Colormap')
    cmap = varargin{vararginmatch(varargin,'Colormap')+1};
else
    cmap = 'br';
end

if vararginmatch(varargin,'Resolution')
    res = varargin{vararginmatch(varargin,'Resolution')+1};
else
    res = 1;
end

if vararginmatch(varargin,'LabelSize')
    LabelSize = varargin{vararginmatch(varargin,'LabelSize')+1};
else
    LabelSize = 8;
end

if vararginmatch(varargin,'LevelList')
    ll = varargin{vararginmatch(varargin,'LevelList')+1};
else
    ll = [];
end

Theta = acos(z) / pi * 180;
r = sqrt(x.*x + y.* y);
r(r == 0) = 1;

pxG = x./r.*Theta;
pyG = y./r.*Theta;


% No extrapolation
if NoExPol == 1
    xmx = max(abs(pxG));
    ymx = max(abs(pyG));

else
    dist = sqrt(pxG.*pxG + pyG.*pyG);
    r_max = max(dist);
    xmx = r_max;
    ymx = r_max;
end

xa = -xmx:res:xmx;
ya = -ymx:res:ymx;

[xm,ym] = meshgrid(xa,ya);
if ShowLap == 0
    imap = griddata(pxG,pyG,map,xm,ym,itype);
else
    EiCOS = elec_cosines([x',y',z'],[x',y',z']);
    w = real(acos(EiCOS))/pi *180+eye(numel(x));
    w = w.^LapFact;
 
    w = 1./w - eye(numel(x));
    
    lp = w ./ repmat(sum(w,1),numel(x),1);
    lp = -lp + eye(numel(x)); %This laplacian does not work at all, not sharp enough
    imap = griddata(pxG,pyG,map * lp,xm,ym,itype);
end

if NoExPol == 1
    vmap = griddata(pxG,pyG,map,xm,ym,'linear');
    idx = isnan(vmap);
else
    dist = sqrt(xm.*xm + ym.*ym);
    idx = dist > r_max;
end
imap(idx) = NaN;
if vararginmatch(varargin,'Gradient')
    Delta = varargin{vararginmatch(varargin,'Gradient')+1};
        
    sx = size(imap,1);
    sy = size(imap,2);
    Grad1 = imap(1:sx-Delta,1:sy-Delta  ) - imap((Delta+1):sx,(Delta+1):sy);
    Grad2 = imap(1:sx-Delta,(Delta+1):sy) - imap((Delta+1):sx,1:sy-Delta  );
    
    if vararginmatch(varargin,'GradientScale')
        gScale = varargin{vararginmatch(varargin,'GradientScale')+1};
    else
        g = sqrt(Grad1.*Grad1 + Grad2 .* Grad2);
        gScale = 1/max(g(:));
    end
    if (gScale == 0)
        gScale = gScale * Delta * res;
        ypgrad = 0;
        for i = 1:Delta:(sx-Delta)
            ypgrad = ypgrad+1;
            yposgrad(ypgrad) = (ya(i)+Delta/2*res);

            xpgrad = 0;
            for j = 1:Delta:(sy-Delta)
                xpgrad = xpgrad+1;
                xposgrad(xpgrad) = (xa(j)+Delta/2*res);
            
                if ~isnan(Grad1(i,j)) && ~isnan(Grad2(i,j))
                    GradMap(ypgrad,xpgrad) = sqrt((Grad1(i,j)- Grad2(i,j)).^2 + (Grad1(i,j)+Grad2(i,j)).^2);
                else
                    GradMap(ypgrad,xpgrad) = 0;
                end
            end
        end
        imap = griddata(xposgrad,yposgrad,GradMap,xm,ym,'v4');
        imap(idx) = NaN;
    end
end

 

if(isempty(CStep))
    if((ShowLap == 1) || (gScale == 0))
        CStep = max(abs(imap(:))) / 8;
    else
        CStep = max(abs(map)) / 8;
    end
end


if isempty(ll)
%    ContourLevel = (nNegLevels:nPosLevels) * CStep;
     ContourLevel = (-8*CStep):CStep:(8*CStep);
     ContourLevel = [-inf ContourLevel inf];
else
    ContourLevel = [-inf ll inf];
end

%ContourLevel = (nNegLevels:(nPosLevels-1)) * CStep;
[c,h] = contourf(PlotAxis,xm,ym,imap, ContourLevel);

set(h,'LineWidth',MapLineWidth,'LineColor',[0.05 0.05 0.05],'LevelListMode','manual','LevelStepMode','manual');
hold(PlotAxis,'on');
   hc  = get(h,'Children');

if isempty(ll)
    ll = get(h,'LevelList');
end
LabBkG = 1;

if vararginmatch(varargin,'Background')
    BckCol = varargin{vararginmatch(varargin,'Background')+1};
    set(PlotAxis,'Color',BckCol);
end

switch cmap
    case 'bw'

        disp('The black / white colormap needs some reprogramming');
        for i = 1:numel(ll)
            if (ll(i) < 0)
                cm(i,:) = [0 0 0];
            else
                cm(i,:) = [1 1 1];
            end
        end

        colormap(PlotAxis,cm);
        contour(PlotAxis,xm,ym,imap,ContourLevel(ContourLevel < 0),'LineColor',[0.99 0.99 0.99],'LineWidth',2);

    case 'ww'
        disp('The white colormap needs some reprogramming');
        colormap(PlotAxis,ones(numel(ll),3));
        LabBkG = 0.9;
        
        contour(PlotAxis,xm,ym,imap,[0 0],'LineWidth',MapLineWidth*2,'LineColor',[0 0 0]);

    case 'hot'
        disp('The hot colormap needs some reprogramming');
        cntpos = 0;
        for i = 1:numel(ll)
            if (ll(i)) > 0
                cntpos = cntpos+1;
            end
        end

        negpos = numel(ll) - cntpos;
        size(hot(cntpos))
        cm = [zeros(negpos,3);hot(cntpos)];
        
        colormap(PlotAxis,cm);
        
    case 'br'
    
        caxis(PlotAxis,[-8*CStep 8*CStep]);
        colormap(PlotAxis,bluered(16));
        LabBkG = 1;
    case 'rr'
        for i = 1:numel(ll)
            l = ll(i) / CStep / 8;
            l = max([l -1]);
            l = min([l  0.875]);
            if (l < 0)
                cm(i,:) = [1 0.875+l 0.875+l];
            else
                cm(i,:) = [1 0.875-l 0.875-l];
            end
        end
        colormap(PlotAxis,cm);
        
%        LabBkG = 1;
%        if (ll(1) < 0)
%            contour(xm,ym,imap,[0 0],'LineWidth',MapLineWidth*2,'LineColor',[0 0 0]);
%        end
    otherwise
        error('Colormap not defined');
end

EndContourLevel = ContourLevel(numel(ll));

if EndContourLevel <= ContourLevel(1)
    EndContourLevel = ContourLevel(1) + 1;
%        ll = [ll EndContourLevel];
end

if vararginmatch(varargin,'Gradient')
    if (gScale > 0)
        for i = 1:Delta:(sx-Delta)
            for j = 1:Delta:(sy-Delta)
                if ~isnan(Grad1(i,j)) && ~isnan(Grad2(i,j))
                    pos = [(xa(j)+Delta/2*res) (ya(i)+Delta/2*res)];
                    Grad = [Grad1(i,j)- Grad2(i,j) Grad1(i,j)+Grad2(i,j) ];
                    Arrow(PlotAxis,pos,-Grad*gScale);
                end
            end
        end
    end
end

%if verLessThan('matlab','8.0')
%    set(gca,'CLimMode','Manual','CLim',[ContourLevel(1) EndContourLevel]);
%end

% colorbar

if vararginmatch(varargin,'Label')
    Label = varargin{vararginmatch(varargin,'Label')+1};
    if numel(Label) == 1
        Label = [];
    end
    if vararginmatch(varargin,'LabelIndex')
        LabelIndex = varargin{vararginmatch(varargin,'LabelIndex')+1};
    else
        LabelIndex = 1:numel(x);
    end
    
    if ~iscell(Label) && ~isempty(Label)
        Label = cellstr(Label);
    end
    Theta = acos(z) / pi * 180;
    r = sqrt(x.*x + y.* y);
    r(r == 0) = 1;

    pxe = x./r.*Theta;
    pye = y./r.*Theta;
    
    
    if vararginmatch(varargin,'LabelColor')
        LabBkG = varargin{vararginmatch(varargin,'LabelColor')+1};
    else
        LabBkG = [1 1 1];
    end

    
    
    
     if ~isempty(Label)
        for i = 1:numel(LabelIndex)
            PlotElectrode(pxe(LabelIndex(i)),pye(LabelIndex(i)),LabelSize,Label{i},1,EndContourLevel +100,PlotAxis);
        end
    else
        for i = 1:numel(LabelIndex)
            PlotElectrode(pxe(LabelIndex(i)),pye(LabelIndex(i)),LabelSize,[],LabBkG,EndContourLevel +100,PlotAxis);
        end
    end
end

if vararginmatch(varargin,'Extrema')

    [~,maxIdx] = max(map,[],2);
    [~,minIdx] = min(map,[],2);
    plot(PlotAxis,[pxG(maxIdx);pxG(minIdx)],[pyG(maxIdx);pyG(minIdx)],'*k');
end


if vararginmatch(varargin,'Centroids')

    posIdx = map > 0;
    negIdx = map < 0;

    cpx = sum(map(posIdx).*pxG(posIdx))./ sum(map(posIdx));
    cpy = sum(map(posIdx).*pyG(posIdx))./ sum(map(posIdx));

    cnx = sum(map(negIdx).*pxG(negIdx))./ sum(map(negIdx));
    cny = sum(map(negIdx).*pyG(negIdx))./ sum(map(negIdx));
    
    plot(PlotAxis,[cpx cnx],[cpy cny],'*k');
end

if vararginmatch(varargin,'GravityCenter')
    cpx = sum(abs(map).*pxG)./ sum(abs(map));
    cpy = sum(abs(map).*pyG)./ sum(abs(map));
    
    plot(PlotAxis,cpx,cpy,'*k');
end

if NoExPol == 0
    axh = PlotAxis;
    oldUnits = axh.Units;
    axh.Units = 'pixels';
    nwidth = axh.Position(3);
    axh.Units = oldUnits;
    LineWidth = nwidth / res / 200;
    ang=0:0.01:(2*pi + 0.01); 
    xp=r_max*cos(ang);
    yp=r_max*sin(ang);
    plot(PlotAxis,xp*0.980,yp*0.980,'-k','LineWidth',LineWidth);
end

if NoseRadius > 0
    w = 1:361;
    w = w / 180 * pi;
    xc = sin(w) .* NoseRadius;
    yc = cos(w) .* NoseRadius + r_max;
    patch(PlotAxis,xc,yc,ones(size(xc))-1000,[1 1 1],'LineWidth',2);
    
    Ang = [18 20 22 24 26 28] / 180 * pi;
    
    for i = 1:numel(Ang)
        x = sin(Ang(i)) * [1.05 1.1] * r_max;
        y = cos(Ang(i)) * [1.05 1.1] * r_max;
        line(PlotAxis, x,y,'LineWidth',2,'Color',[0 0 0]);
        line(PlotAxis,-x,y,'LineWidth',2,'Color',[0 0 0]);
    end
    
    
%    ell_h = ellipse(PlotAxis,r_max*0.99,r_max*0.99,[],0,0);
%    set(ell_h,'LineWidth',2,'Color',[0 0 0]);
end


hold(PlotAxis,'off');
if vararginmatch(varargin,'Background')
    set(PlotAxis,'xtick',[],'ytick',[],'xticklabel',[],'yticklabel',[],'Visible','on','XLim',[-xmx-15 xmx+15],'YLim',[-ymx-15 ymx+15+NoseRadius],'DataAspectRatio',[1 1 1]); %,'Color',get(get(PlotAxis,'Parent'),'Color'));
else
    set(PlotAxis,'xtick',[],'ytick',[],'xticklabel',[],'yticklabel',[],'Visible','off','XLim',[-xmx-15 xmx+15],'YLim',[-ymx-15 ymx+15+NoseRadius],'DataAspectRatio',[1 1 1]); %,'Color',get(get(PlotAxis,'Parent'),'Color'));
end
freezeColors(PlotAxis);

tit = get(PlotAxis,'Title');
tit.Visible = 'on';

if vararginmatch(varargin,'Title')
    txt = varargin{vararginmatch(varargin,'Title')+1};
    tit.String = txt;
    tit.Interpreter = 'none';
end


