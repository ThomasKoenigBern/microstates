function [x,y,z] = VAsph2cart(Channel)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

tmp = Channel(1);

if isfield(tmp,'CoordsTheta')
%if exist('Analyzer','var') % Analyzer 2
    for i = 1:numel(Channel)
        Theta(i)  = Channel(i).CoordsTheta;
        Phi(i)    = Channel(i).CoordsPhi;
        Radius(i) = Channel(i).CoordsRadius;
    end
else
    for i = 1:numel(Channel)
        Theta(i)  = Channel(i).Theta;
        Phi(i)    = Channel(i).Phi;
        Radius(i) = Channel(i).Radius;
    end
end

Theta = Theta / 180 * pi;
Phi   = Phi   / 180 * pi;

z = Radius .* cos(Theta);
x = Radius .* cos(Phi) .* sin(Theta);
y = Radius .* sin(Phi) .* sin(Theta);