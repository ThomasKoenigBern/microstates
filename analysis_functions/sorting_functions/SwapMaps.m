function [Result,Assignment, Polarity] = SwapMaps(MapsToSwap,MeanMap,RespectPolarity, chanloc)
    
    if nargin < 4
        chanloc = [];
    end
    
    [~,nMaps,nChannels] = size(MeanMap);
    permutations = fliplr(perms(1:nMaps));
    nPerms = size(permutations,1);
    PermutedMaps = zeros(nPerms,nMaps,nChannels);
 
    for p = 1:nPerms
        PermutedMaps(p,:,:) = MapsToSwap(1,permutations(p,:),:);
    end
    [PermFit,sgn] = GetMapSeriesOverallFit(PermutedMaps,MeanMap,RespectPolarity,chanloc);

    if isempty(chanloc)
        [~,idx] = max(PermFit);
    else
        [~,idx] = min(PermFit);
    end
%    Polarity = sgn(idx,:);
%    Polarity(Polarity == 0) = 1;    
    
    if idx == 1
        Result = [];
        Polarity = sign(diag(MyCorr(squeeze(MapsToSwap)',squeeze(MeanMap)')))';    

    else
        Result = squeeze(PermutedMaps(idx,:,:));
        Polarity = sign(diag(MyCorr(squeeze(Result)',squeeze(MeanMap)')))';
    end
    Assignment = permutations(idx,:);
 end
