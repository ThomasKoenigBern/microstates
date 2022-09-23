  function [SortedMaps,SortOrder, Communality, Polarity] = ArrangeMapsBasedOnMean(in, MeanMap,RespectPolarity, flags)

    if ismatrix(in)
        in = shiftdim(in,-1);
    end
  
    if nargin < 4
        flags = '';
    end
  
    in = NormDim(in,3);
    SortedMaps = in;

    [nSubjects,nMapsToSort,nChannels] = size(in);
    nTemplateMaps = size(MeanMap,1);
    if nMapsToSort < nTemplateMaps
        PatchToAdd = zeros(nSubjects,(nTemplateMaps-nMapsToSort),nChannels);
        in = cat(2,in,PatchToAdd);
    end

    if nTemplateMaps < nMapsToSort
        PatchToAdd = zeros((nMapsToSort - nTemplateMaps),nChannels);
        MeanMap = cat(1,MeanMap,PatchToAdd);
    end
    
    Communality = nan(nSubjects,nMapsToSort);
    Polarity    = ones(nSubjects,nMapsToSort);
    
    if nSubjects > 1
        fprintf(1,'Sorting %i maps of %i subjects.\n',nMapsToSort,nSubjects);
    end
  
    if nargin < 3
        RespectPolarity = false;
    end

    ExtMeanMap(1,:,:) = MeanMap;
    SortOrder = nan(nSubjects,max(nMapsToSort,nTemplateMaps));
    
    for n = 1:nSubjects
		MapsToSort = in(n,:,:);
       
        if (nMapsToSort > nTemplateMaps) || (nMapsToSort < 7) || (license('test','optimization_toolbox') == false) || isempty(which('intlinprog')) % Full permutations for small n or absent optimzation toolbox
            [SwappedMaps,Assignment, pol] = SwapMaps(MapsToSort,ExtMeanMap,RespectPolarity);
        else        % linear prgramming for larger problems
            [SwappedMaps,Assignment,pol] = SwapMaps2(MapsToSort,ExtMeanMap,RespectPolarity);
        end
        
        if nTemplateMaps == nMapsToSort
            Polarity(n,:) = pol;
            if ~isempty(SwappedMaps)
                SortedMaps(n,:,:) = SwappedMaps;
            end
            SortOrder(n,:) = Assignment;
            Communality(n,:) = diag(MyCorr(squeeze(SortedMaps(n,:,:))',squeeze(ExtMeanMap)'))';

        elseif nTemplateMaps > nMapsToSort
            MapsToKeep = Assignment <= nMapsToSort;
            Polarity(n,:) = pol(MapsToKeep);
            if ~isempty(SwappedMaps)
                SortedMaps(n,:,:) = SwappedMaps(MapsToKeep,:);
            end
            SortOrder(n,:) = Assignment;
            
            d = diag(MyCorr(SwappedMaps',squeeze(ExtMeanMap)'))';
            Communality(n,:) = d(MapsToKeep);
        else    % TK tested the code below 10.2.2022, seems to be ok
            pol(isnan(pol)) = 1;
            Polarity(n,:) = pol;
            if ~isempty(SwappedMaps)
                SortedMaps(n,:,:) = SwappedMaps;
            end
            SortOrder(n,:) = Assignment;
            
            d = diag(MyCorr(squeeze(SortedMaps(n,:,:))',squeeze(ExtMeanMap)'))';
            Communality(n,:) = d(1:nMapsToSort);
        end

    end
    if ~RespectPolarity
        Communality = abs(Communality);
    end
end
