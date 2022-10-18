function [c,imap,xm,ym,chandle] = dspCMap(map,ChanPos,varargin)
% dspCMap - Display topographic scalp maps
% ----------------------------------------
% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License
%
% Usage: dspCMap(map,ChanPos,CStep)
%
% map is the 1xN voltage map to display, where N is the number of electrode
%
% ChanPos contains the electrode positions, either as Nx3 xyz coordinates,
% or as structure withRadius, Theta and Phi (Brainvision convention)
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
% 'NTri'            also controls resolution
% 'Label'           shows the electrode positions and labels them
% 'Gradient' N      shows vectors with gradients at every N-th grid point
% 'GradientScale'   controls the length of these vectors
% 'NoScale'         whether or not a scale is being shown
% 'LevelList'       sets the levellist
% 'Laplacian'       shows the laplacian instead of the data
% 'Plot'            Plots additional x_points 
% 'Linewidth'       Sets linewidth
% 'NoExtrapolation' Prevents maps to be etrapolated)


map = double(map);
if isstruct(ChanPos)
    if isfield(ChanPos,'urchan')
        y =  cell2mat({ChanPos.X});
        x = -cell2mat({ChanPos.Y});
        z =  cell2mat({ChanPos.Z});
    else
        [x,y,z] = VAsph2cart(ChanPos);
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

hold off
cla

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

%if (nargin > 2)
%    if isnumeric(varargin{1})
%        CStep = varargin{1};
%    end
%end    


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

%if vararginmatch(varargin,'NTri')
%    Nrecurse = varargin{vararginmatch(varargin,'NTri')+1};
%else
%    Nrecurse = 4;
%end


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

nNegLevels = floor(min(imap(:)) / CStep);
nPosLevels = floor(max(imap(:)) / CStep);

if -nNegLevels > nPosLevels
    nPosLevels = -nNegLevels;
else
    nNegLevels = -nPosLevels;
end


if isempty(ll)
%    ContourLevel = (nNegLevels:nPosLevels) * CStep;
     ContourLevel = (-8*CStep):CStep:(8*CStep);
     ContourLevel = [-inf ContourLevel inf];
else
    ContourLevel = [-inf ll inf];
end

%ContourLevel = (nNegLevels:(nPosLevels-1)) * CStep;

[c,h] = contourf(xm,ym,imap, ContourLevel);
chandle.c = c;
chandle.h = h;

set(h,'LineWidth',MapLineWidth,'LineColor',[0.05 0.05 0.05],'LevelListMode','manual','LevelStepMode','manual');
hold on

hc  = get(h,'Children');

if isempty(ll)
    ll = get(h,'LevelList');
end
LabBkG = 1;

if vararginmatch(varargin,'Background')
    BckCol = varargin{vararginmatch(varargin,'Background')+1};
    set(gca,'Color',BckCol);
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

        colormap(gca,cm);
        contour(xm,ym,imap,ContourLevel(ContourLevel < 0),'LineColor',[0.99 0.99 0.99],'LineWidth',2);

    case 'ww'
        disp('The white colormap needs some reprogramming');
        colormap(ones(numel(ll),3));
        LabBkG = 0.9;
        
        contour(xm,ym,imap,[0 0],'LineWidth',MapLineWidth*2,'LineColor',[0 0 0]);

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
        
        colormap(gca,cm);
        
    case 'br'
        caxis([-8*CStep 8*CStep]);
        colormap(gca,bluered);
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
        colormap(gca,cm);
        
        LabBkG = 1;
%        if (ll(1) < 0)
%            contour(xm,ym,imap,[0 0],'LineWidth',MapLineWidth*2,'LineColor',[0 0 0]);
%        end
    otherwise
        error('Colormap not defined');
end

EndContourLevel = ContourLevel(numel(ll));

if EndContourLevel <= ContourLevel(1)
    EndContourLevel = ContourLevel(1) + 1;
        ll = [ll EndContourLevel];
end

if vararginmatch(varargin,'Gradient')
    if (gScale > 0)
        for i = 1:Delta:(sx-Delta)
            for j = 1:Delta:(sy-Delta)
                if ~isnan(Grad1(i,j)) && ~isnan(Grad2(i,j))
                    pos = [(xa(j)+Delta/2*res) (ya(i)+Delta/2*res)];
                    Grad = [Grad1(i,j)- Grad2(i,j) Grad1(i,j)+Grad2(i,j) ];
                    Arrow(pos,-Grad*gScale);
                end
            end
        end
    end
end

% colorbar

if vararginmatch(varargin,'Label')
    Label = varargin{vararginmatch(varargin,'Label')+1};

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
    
     if ~isempty(Label)
        for i = 1:numel(LabelIndex);
            PlotElectrode(pxe(LabelIndex(i)),pye(LabelIndex(i)),LabelSize,Label{i},1,EndContourLevel +100);
        end
    else
        for i = 1:numel(LabelIndex);
            PlotElectrode(pxe(LabelIndex(i)),pye(LabelIndex(i)),LabelSize,[],LabBkG,EndContourLevel +100);
        end
    end
end

if vararginmatch(varargin,'Extrema')

    [mx,maxIdx] = max(map,[],2);
    [mn,minIdx] = min(map,[],2);
    plot([pxG(maxIdx);pxG(minIdx)],[pyG(maxIdx);pyG(minIdx)],'*k');
end


if vararginmatch(varargin,'Centroids')

    posIdx = map > 0;
    negIdx = map < 0;

    cpx = sum(map(posIdx).*pxG(posIdx))./ sum(map(posIdx));
    cpy = sum(map(posIdx).*pyG(posIdx))./ sum(map(posIdx));

    cnx = sum(map(negIdx).*pxG(negIdx))./ sum(map(negIdx));
    cny = sum(map(negIdx).*pyG(negIdx))./ sum(map(negIdx));
    
    plot([cpx cnx],[cpy cny],'*k');
end

if vararginmatch(varargin,'GravityCenter')
    cpx = sum(abs(map).*pxG)./ sum(abs(map));
    cpy = sum(abs(map).*pyG)./ sum(abs(map));
    
    plot(cpx,cpy,'*k');
end


if NoseRadius > 0
    w = 1:361;
    w = w / 180 * pi;
    xc = sin(w) .* NoseRadius;
    yc = cos(w) .* NoseRadius + r_max;
    patch(xc,yc,ones(size(xc))-1000,[1 1 1],'LineWidth',1);
       Ang = [18 20 22 24 26 28] / 180 * pi;
    
    for i = 1:numel(Ang)
        x = sin(Ang(i)) * [1.05 1.1] * r_max;
        y = cos(Ang(i)) * [1.05 1.1] * r_max;
        line( x,y,'LineWidth',1,'Color',[0 0 0]);
        line(-x,y,'LineWidth',1,'Color',[0 0 0]);
    end
    ell_h = ellipse(r_max*0.99,r_max*0.99,[],0,0);
    set(ell_h,'LineWidth',1,'Color',[0 0 0]);
    
end

set(gca,'XLim',[-xmx-15 xmx+15],'YLim',[-ymx-15 ymx+15+NoseRadius],'NextPlot','replace','DataAspectRatio',[1 1 1]);

if vararginmatch(varargin,'Background')
    set(gca,'xtick',[],'ytick',[],'xticklabel',[],'yticklabel',[]);
else
    axis off
end


%freezeColors;
%drawnow