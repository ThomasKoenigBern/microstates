function [b_model,exp_var] = eeg_computeHC(eeg,n_mod, IgnorePolarity, Normalize)

% Copyright 2009-2011 Thomas Koenig
% distributed under the terms of the GNU AFFERO General Public License

    if nargin < 3;  IgnorePolarity = false; end
    if nargin < 4;  Normalize = true; end
    [n_frame,n_chan] = size(eeg);

    h = eye(n_chan)-1/n_chan;
    eeg = eeg*h;									% Average reference of data 
        
    if Normalize == true
        eeg = NormDimL2(eeg,2) / sqrt(n_chan);
    end
    
    GEV = sum(eeg.*(NormDimL2(eeg,2) / sqrt(n_chan)),2);
    TotalVar = sum(GEV);
    
    disp('Computing Distances');
    Distances = pdist(eeg,'correlation');
        
    if IgnorePolarity == true
        Distances = 2* Distances - Distances.^2;
    else
        sgn = sign(Distances);
        Distances = (2* Distances - Distances.^2) .* sgn;
    end
    
    disp('Linking');
    lnk = linkage(Distances);
    size(lnk)
    figure(2000);
    dendrogram(lnk,0);
    disp('Getting cluster centers');
    figure(1000);
    for idx = 1:numel(n_mod)
        nClusters = n_mod(idx);
        Assignment = cluster(lnk,'maxclust',nClusters);
        subplot(numel(n_mod),1,idx);
        plot(Assignment);
        ClusterCenter = nan(nClusters,n_chan);
        GEV = zeros(n_frame,1);
        for c = 1:nClusters
            if (IgnorePolarity == true)
                [pc1,~] = eigs(cov(eeg(Assignment == c,:)),1);
                ClusterCenter(c,:) = NormDimL2(pc1',2) / sqrt(n_chan);
            else
                ClusterCenter(c,:) = NormDimL2(mean(eeg(Assignment == c,:),1),2) / sqrt(n_chan);
            end
            GEV(Assignment == c,1) = eeg(Assignment == c,:) * ClusterCenter(c,:)';
        end
        b_model{idx} = ClusterCenter;
        if IgnorePolarity == true
            exp_var(idx) = sum(abs(GEV)) / TotalVar;
        else
            exp_var(idx) = sum(GEV) / TotalVar;
        end
    end
end
