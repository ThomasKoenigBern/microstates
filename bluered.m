function h = bluered(m)

if nargin < 1, m = size(get(gcf,'colormap'),1); end

n = fix(1/2*m);
o = m - n - n;

r = [(0:n-1)'/n ;ones(o,1) ; ones(n,1)];
g = [(0:n-1)'/n ;ones(o,1) ; (n-1:-1:0)'/n];
b = [ones(n,1);ones(o,1); (n-1:-1:0)'/n];  

h = [r g b];