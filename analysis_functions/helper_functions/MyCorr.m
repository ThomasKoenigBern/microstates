function c = MyCorr(in1,in2)

% Average reference both sets of input maps
nO = size(in1,1);
Centering = eye(nO) - 1/nO;

in1 = Centering * in1;

if nargin < 2
    in2 = in1;
else
    in2 = Centering * in2;
end

% Compute covariance matrix between sets of input maps
covar = in1' * in2;
var1 = diag(in1' * in1);
var2 = diag(in2' * in2);

c = covar./sqrt(var1*var2');     