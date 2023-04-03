function gamma_indices = eeg_gamma (TheEEG, IndSamples, AllClustLabels, ClusterNumbers)
    numClusters = size(AllClustLabels, 1);    
    s_plus = 0;     % s_plus represents the number of times where two 
    % points not clustered together had a larger distance than two points 
    % in the same cluster

    s_minus = 0;
    gamma_indices = nan(numClusters);
    % will only fill in top right section of matrix
%     dist_matrices = zeros(numClusters, numClusters);
    for u = 1:numClusters   % for u representing each cluster
        u_clustNum = ClusterNumbers(u);
        
        uMembers = (AllClustLabels{u} == u);
        uClustMembers = IndSamples(:,uMembers==1);
        uNumSamples = size(uClustMembers, 2); 
        tic
        max_dist = max_dist_within_cluster(u, uNumSamples, AllClustLabels, IndSamples);
        toc
        for v = u+1:numClusters     % for each cluster not equal to u           
            v_clustNum = ClusterNumbers(v);
            vMembers = (AllClustLabels{v} == v);    % not sure why this vMembers list is too long
            vClustMembers = IndSamples(:,(vMembers == 1));  
            vNumSamples = size(vClustMembers, 2);
            
    %         dist_matrices(u,v) = zeros(IndSamples(u), IndSamples(v));
%             this_dist_matrix = nan(uNumSamples, vNumSamples);
            for i = 1:uNumSamples
                for j = 1:vNumSamples
    %                 dist_matrices(u,v) = pdist(TheEEG.msinfo.MSMaps(u_clustNum).Maps(AllClustLabels(u,:,1)), TheEEG.msinfo.MSMaps(v_clustNum).Maps(AllClustLabels(v,:,1)));
                    spCorr = corr(TheEEG.msinfo.MSMaps(u_clustNum, i), TheEEG.msinfo.MSMaps(v_clustNum, j));
                    this_dist = 1 - abs(spCorr);
%                     this_dist_matrix(i, j) = this_dist;
                    if this_dist > max_dist
                        s_plus = s_plus + 1;
                    elseif this_dist < max_dist
                        s_minus = s_minus + 1;
                    end
                end
            end
        end
        gamma_indices(u) = (s_plus-s_minus)/(s_plus+s_minus);
    end


end
function max_dist = max_dist_within_cluster(u, nSamples, AllClustLabels, IndSamples)
    % special case, want to grab max dist
    max_dist = 0;
    for s1 = 1:nSamples  % sample 1
        s1_idx = find(AllClustLabels{u} == u, s1, 'first');

        for s2 = s1+1:nSamples
            s2_idx = find(AllClustLabels{u} == u, s2, 'first');

            % double check method of accessing element of msmaps.
            % want to find corr between s1 and s2 within cluster 3
            spCorr = corr(IndSamples(:, s1_idx(end)), IndSamples(:, s2_idx(end)));
%                     this_dist_matrix(i, j) = 1 - abs(spCorr);
            this_dist = 1-abs(spCorr);
            if this_dist > max_dist
                max_dist = this_dist;
            end
        end
    end
end