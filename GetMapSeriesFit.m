function [TheFit,FitSign] = GetMapSeriesFit(IndMaps,Template,RespectPolarity, chanloc)
    nCases = size(IndMaps,1);
    if nargin < 4
        chanloc = [];
    end

    if isempty(chanloc)
        TheFit = mean(IndMaps.*repmat(Template,[nCases,1,1]),3);
        if ~RespectPolarity
            FitSign = sign(TheFit);
            TheFit = abs(TheFit);    
        else
            FitSign = ones(size(TheFit));
        end
    else
        [ns,nm,nc] = size(IndMaps);
        TheFit  = zeros(ns,nm);
        FitSign = zeros(ns,nm);
        for m = 1:nm
            InMap = reshape(IndMaps(:,m,:),ns,nc);
            TMap  = reshape(Template(1,m,:),1,nc);
            [Fit,~,SingleSign] = EMMapDifference(InMap,TMap,chanloc,chanloc, ~RespectPolarity);
            TheFit(:,m)  = Fit;
            FitSign(:,m) = SingleSign;
        end
    end
end