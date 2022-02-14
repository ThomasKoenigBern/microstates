function kl = eeg_krzanowskiLai(eegdata, Winner, Maps)

    distance = 0;
    nMaps = size(Maps,1);
    nTimepoints = size(Winner,2);

    
    % get indices of all 0s, 1s, 2s, ... nMaps into diff arrays
    % using the reindexed arrays, get voltages of each timepoint.
    winner_r = nan(nMaps, nTimepoints);     % first row represents zeros

    for j = 0:nMaps
        i = 1;
        for t = 1:nTimepoints  
            if (Winner(1, t) == j)
                winner_r(j+1, i) = t;
                i = i+1;
            end
        end
    end
    
    % calculate pairwise distances between each of the voltages 
    % https://www.mathworks.com/matlabcentral/answers/124839-calculate-differences-between-all-values-in-vector
    % calculate magnitude of distance vectors using norm() then square it
    % sum up all of these magnitudes. this is distance, or Dr.
    for j = 0:nMaps
        for t1 = 1:nTimepoints
            for t2 = 1:nTimepoints
                % make 
            end
        end
    end

    dispersion = sum(w(q, nMaps, distance));
    
    kl = m_q - m_q1;
end
function dispersions = w(q, nMaps, distance)
    dispersions = nan(1,q);
    for r = 1:q
        dispersions(1,r) = (distance / (2*nMaps));
    end
    
end