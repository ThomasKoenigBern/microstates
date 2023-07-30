function h = RaguTanovaSubplot(nr,nc,r,c,Color)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

r_width  = 0.5 / nc;
r_height = 0.95 / nr;

Position = [(0.05 + (c-1) * r_width) (0.05 + (nr-r) * r_height) (r_width - 0.04) (r_height - 0.08) ];

h = subplot('Position',Position);
cla(h);
set(h,'Tag','subplot');

if nargin > 4
    Position = [(0.022 + (c-1) * r_width) (0.003 + (nr-r) * r_height) (r_width - 0.005) (r_height -0.01) ];
    x1 = Position(1);
    y1 = Position(2);
    x2 = Position(1) + Position(3);
    y2 = Position(2) + Position(4);
    
    ah = annotation('line',[x1 x2],[y1 y1],'Color',Color,'LineWidth',5);
    set(ah,'Tag','subplot');
    
    ah = annotation('line',[x1 x2],[y2 y2],'Color',Color,'LineWidth',5);
    set(ah,'Tag','subplot');
    
    ah = annotation('line',[x1 x1],[y1 y2],'Color',Color,'LineWidth',5);
    set(ah,'Tag','subplot');
    
    ah = annotation('line',[x2 x2],[y1 y2],'Color',Color,'LineWidth',5);
    set(ah,'Tag','subplot');
end
