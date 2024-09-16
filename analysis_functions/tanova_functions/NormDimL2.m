function out = NormDimL2(in,dim)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

rep = ones(numel(size(in)),1);
rep(dim) = size(in,dim);
d = sqrt(mean(in.*in,dim));
%d = std(in,1,dim);
d(d == 0) = 1;
out = in./repmat(d,rep(:)');