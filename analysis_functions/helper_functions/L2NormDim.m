function out = L2NormDim(in,dim)

rep = ones(numel(size(in)),1);
rep(dim) = size(in,dim);
d = vecnorm(in, 2, dim);
d(d == 0) = 1;
out = in./repmat(d,rep(:)');