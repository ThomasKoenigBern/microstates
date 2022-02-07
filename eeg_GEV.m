function GEV = eeg_GEV(IndSamples, TemplateMaps, ClustLabels)
    % check if IndSamples is 3D (segmented data)
    % if so, combine the last 2 dimensions of the matrix to get a
    % channels x samples instead of channels x samples per segment x
    % segments matrix, and combine the dimensions of ClustLabels to get a
    % samples long vector instead of a samples per segment x segments
    % matrix
    if (numel(size(IndSamples)) == 3)
        nSegments = size(IndSamples, 3);

        % reshape IndSamples
        NewIndSamples = IndSamples(:,:,1);
        for i = 2:nSegments
            NewIndSamples = cat(2, NewIndSamples, IndSamples(:,:,i));
        end
        IndSamples = NewIndSamples;

        % reshape ClustLabels
        NewClustLabels = ClustLabels(:,1);
        for i = 2:nSegments
            NewClustLabels = cat(1, NewClustLabels, ClustLabels(:,i));
        end
        ClustLabels = squeeze(NewClustLabels);
    end
    % Check for zero elements in ClustLabels (in case of truncating)
    zeroIndices = find(~ClustLabels);
    if (size(zeroIndices,1) > 0)
        % remove samples with no microstate assignmnets
        IndSamples(:, zeroIndices') = [];
        % remove clust labels of zero
        ClustLabels(zeroIndices') = [];
    end
    GFP = std(IndSamples);
    IndAssignments = TemplateMaps(:, ClustLabels');
    map_corr = columncorr(IndSamples,IndAssignments);
    GEV = sum((GFP.*map_corr).^2) / sum(GFP.^2);
end

% Adapted from Poulsen et al. MST1.0 toolbox:
function C2 = columncorr(A,B)
    % Fast way to compute correlation of multiple pairs of vectors without
    % computing all pairs as would with corr(A,B). Borrowed from Oli at Stack
    % overflow. Note the resulting coefficients vary slightly from the ones
    % obtained from corr due differences in the order of the calculations.
    % (Differences are of a magnitude of 1e-9 to 1e-17 depending of the tested
    % data).
    
    An=bsxfun(@minus,A,mean(A,1));                 
    Bn=bsxfun(@minus,B,mean(B,1));                 
    An=bsxfun(@times,An,1./sqrt(sum(An.^2,1)));    
    Bn=bsxfun(@times,Bn,1./sqrt(sum(Bn.^2,1)));    
    C2=sum(An.*Bn,1);                            

end