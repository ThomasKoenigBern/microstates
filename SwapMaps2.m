function [Result,Assignment, pol] = SwapMaps2(MapsToSwap,MeanMap,RespectPolarity, chanloc)
    if nargin < 4 
        chanloc = [];
    end
    nMaps = size(MeanMap,2);
    MeanMap    = double(MeanMap);
    MapsToSwap = double(MapsToSwap);
    if isempty(chanloc)
        CorMat = MyCorr(squeeze(MapsToSwap)',squeeze(MeanMap)');
        if ~RespectPolarity == true
            CorMat = abs(CorMat);
        end
        DistMat = 1-CorMat(:);
    else
        [TheFit] = EMMapDifference(MapsToSwap,MeanMap,chanloc,chanloc, ~RespectPolarity);
        DistMat = max(TheFit(:)) - TheFit;
    end
    intcon = 1:numel(DistMat);
    % Now we make a weighting matrix that allows us to constrain the thing
    % to one to one assignments
    A = zeros(2*nMaps,numel(DistMat));
    for m = 1:nMaps
        Am1 = zeros(nMaps);
        Am2 = zeros(nMaps);
        Am1(m,:) = 1;
        Am2(:,m) = 1;
        A(m      ,:) = Am1(:);
        A(m+nMaps,:) = Am2(:);
    end
    lb = zeros(numel(DistMat),1);
    ub = ones(numel(DistMat),1);
    b = ones(2*nMaps,1);
    x = intlinprog(DistMat,intcon,[],[],A,b,lb,ub,optimoptions('intlinprog','Display','off'));
    AssignMatrix = reshape(x,nMaps,nMaps);
    [~,Assignment] = max(AssignMatrix == 1);
    Result = squeeze(MapsToSwap(:,Assignment,:));
    pol = sign(diag(MyCorr(squeeze(Result)',squeeze(MeanMap)')))';    
    if all(Assignment == 1:nMaps)
        Result = [];
    else
        %Result = squeeze(Result .* repmat(pol',1,size(Result,2)));

    end
end
