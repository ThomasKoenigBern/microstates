function out = NormDim(in,dim)

rep = ones(numel(size(in)),1);
rep(dim) = size(in,dim);
d = std(in,1,dim);
d(d == 0) = 1;
out = in./repmat(d,rep(:)');