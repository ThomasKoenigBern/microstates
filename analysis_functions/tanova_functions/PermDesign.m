function [p] = PermDesign(d,NoXing)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

if nargin < 2
    NoXing = false;
end

if ((size(d,2) == 1) || (NoXing == false))
    p = randperm(size(d,1));
else
    [i,j,k] = unique(d);
    d = reshape(k,size(d));
    [i1,j1,k1] = unique(d(:,1));
    [i2,j2,k2] = unique(d(:,2));
        
    l1 = unique(k1);
    l2 = unique(k2);
    l1 = l1(randperm(numel(l1)));
    l2 = l2(randperm(numel(l2)));
    p = l1(k1) + numel(i1) * (l2(k2)-1);
end