function [covariance, spCorr] = MyCorr(in1,in2)

nO = size(in1,1);
Centering = eye(nO) - 1/nO;

in1 = Centering * in1;

if nargin < 2
    in2 = in1;
else
    in2 = Centering * in2;
end

covar = in1' * in2;
var1 = diag(in1' * in1);
var2 = diag(in2' * in2);

covariance = covar./sqrt(var1*var2');

% Spatial correlation values calculated using equations for diss and
% spatial correlation from Murray 2008 paper
pre_diss = nan(1,size(in1,2));
for j = 1:size(in1,2)       % from 1 to nMaps
    pre_diss(j) = 0;
    gfp1 = std(in1(j,:));
    gfp2 = std(in2(j,:));
    for i = 1:nO    % from 1 to num of electrodes
        pre_diss(j) = pre_diss(j) + (((in1(i,j)/gfp1) - (in2(i,j)/gfp2)).^2);
    end
end
diss = pre_diss / nO;

spCorr = (1-(diss).^2)/2;

