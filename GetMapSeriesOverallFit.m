function [MeanFit,FitSign] = GetMapSeriesOverallFit(IndMaps,Template,RespectPolarity, chanloc)
    if nargin < 4
        chanloc = [];
    end
    if isempty(chanloc)
        [TheFit,FitSign] = GetMapSeriesFit(IndMaps,Template,RespectPolarity);
        MeanFit = mean(TheFit,2);
    else
        [TheFit,FitSign] = GetMapSeriesFit(IndMaps,Template,RespectPolarity,chanloc);
        MeanFit = mean(TheFit,2);

    end
    
end