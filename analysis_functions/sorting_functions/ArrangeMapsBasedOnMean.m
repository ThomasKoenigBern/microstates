function [SortedMaps,SortOrder, SpatialCorrelation, Polarity] = ArrangeMapsBasedOnMean(in, MeanMap,RespectPolarity)

    if ~ismatrix(in)
        [nSubjects,nMaps,nChannels] = size(in);
    else
        nSubjects = 1;
        [nMaps,nChannels] = size(in);
    end
    SpatialCorrelation = nan(nSubjects,nMaps);
    Polarity    = ones(nSubjects,nMaps);
    %fprintf(1,'Sorting %i maps of %i subjects.\n',nMaps,nSubjects);

    if ismatrix(in)
        in = shiftdim(in,-1);
    end
  
    if nargin < 4
        flags = '';
    end
  
    % Average reference and normalize input maps and template maps
    newRef = eye(nChannels);
    newRef = newRef - 1/nChannels;
    for i=1:nSubjects
        in(i, :, :) = squeeze(in(i, :, :)) * newRef;
    end
    in = L2NormDim(in, 3);
    SortedMaps = in;

    MeanMap= MeanMap * newRef;
    MeanMap = L2NormDim(MeanMap, 2);

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
       
        if max(nMapsToSort,nTemplateMaps) < 7
            % Full permutations for small n
            [SwappedMaps,Assignment, pol] = SwapMaps(MapsToSort,ExtMeanMap,RespectPolarity);
        else 
            % linear programming for larger problems
            [SwappedMaps,Assignment,pol] = SwapMaps2(MapsToSort,ExtMeanMap,RespectPolarity);
        end
        
        if nTemplateMaps == nMapsToSort
            Polarity(n,:) = pol;
            if ~isempty(SwappedMaps)
                SortedMaps(n,:,:) = SwappedMaps;
            end
            SortOrder(n,:) = Assignment;
            SpatialCorrelation(n,:) = diag(MyCorr(squeeze(SortedMaps(n,:,:))',squeeze(ExtMeanMap)'))';

        elseif nTemplateMaps > nMapsToSort
            MapsToKeep = Assignment <= nMapsToSort;
            Polarity(n,:) = pol(MapsToKeep);
            if ~isempty(SwappedMaps)
                SortedMaps(n,:,:) = SwappedMaps(MapsToKeep,:);
            else
                SwappedMaps = MapsToSort;
            end
            SortOrder(n,:) = Assignment;
            
            d = diag(MyCorr(squeeze(SwappedMaps)',squeeze(ExtMeanMap)'))';
            SpatialCorrelation(n,:) = d(MapsToKeep);
        else    % TK tested the code below 10.2.2022, seems to be ok
            pol(isnan(pol)) = 1;
            Polarity(n,:) = pol;
            if ~isempty(SwappedMaps)
                SortedMaps(n,:,:) = SwappedMaps;
            end
            SortOrder(n,:) = Assignment;
            
            d = diag(MyCorr(squeeze(SortedMaps(n,:,:))',squeeze(ExtMeanMap)'))';
            SpatialCorrelation(n,:) = d(1:nMapsToSort);
        end

    end
    if ~RespectPolarity
        SpatialCorrelation = abs(SpatialCorrelation);
    end
end
