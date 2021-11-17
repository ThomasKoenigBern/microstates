function PlotElectrode(x,y,r,Label,Gray,zl,fs)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

if (r == 1)
    xc = [x-1 x+1 x+1 x-1 x-1];
    yc = [y-1 y-1 y+1 y+1 y-1];
    patch(xc,yc,ones(size(xc))*zl,[0 0 0]);
    return
end


w = 1:361;

w = w / 180 * pi;

xc = sin(w) .* r + x;
yc = cos(w) .* r + y;

if (zl == Inf)
    zl = 100;
end

plot(xc,yc,'k-','LineWidth',1);
patch(xc,yc,ones(size(xc))*zl+1000,[Gray Gray Gray],'FaceColor',[Gray Gray Gray]);

if isempty(Label)
    return
end

h = text(x,y,ones(size(x))*zl+1002,Label);


set(h,'HorizontalAlignment','center');
set(h,'VerticalAlignment','middle');
if (nargin < 7)
    set(h,'FontSize',r * 0.7);
else
    set(h,'FontSize',fs);
end

set(h,'FontWeight','demi');