setIdx = 36;
MinClasses = 8;
MaxClasses = 12;
MeanName = 'Mean_EC_allPeaks';
nbchan = ALLEEG(36).nbchan;
allPeaks = [];

for i=1:33
    for e=1:ALLEEG(i).trials
        gfp = std(ALLEEG(i).data(:,:,e),1,1);
        GFPidx = find([false (gfp(1,1:end-2) < gfp(1,2:end-1) & gfp(1,2:end-1) > gfp(1,3:end)) false]);
        allPeaks = [allPeaks ALLEEG(i).data(:, GFPidx, e)];
    end
end

for nClusters=MinClasses:MaxClasses
    [b_model, ~, ~, exp_var] = eeg_kMeans(allPeaks', nClusters, 20, [], 'n');
    ALLEEG(setIdx).msinfo.MSMaps(nClusters).Maps = double(b_model);
    ALLEEG(setIdx).msinfo.MSMaps(nClusters).ExpVar = double(exp_var);
    ALLEEG(setIdx).msinfo.MSMaps(nClusters).ColorMap = repmat([.75 .75 .75], nClusters, 1);
    for j = 1:nClusters
        ALLEEG(setIdx).msinfo.MSMaps(nClusters).Labels{j} = sprintf('MS_%i.%i',nClusters,j);
    end
    ALLEEG(setIdx).msinfo.MSMaps(nClusters).SortMode = 'none';
    ALLEEG(setIdx).msinfo.MSMaps(nClusters).SortedBy = '';
    ALLEEG(setIdx).msinfo.MSMaps(nClusters).SpatialCorrelation= [];
end

% EEGout = eeg_emptyset();
% EEGout.chanlocs = ALLEEG(setIdx(1)).chanlocs;
% EEGout.data = zeros(numel(EEGout.chanlocs),MaxClasses,MaxClasses);
% EEGout.msinfo = msinfo;

% for n = MinClasses:MaxClasses
%     ALLEEG(setIdx).data(:,1:n,n) = msinfo.MSMaps(n).Maps';
% end

% EEGout.setname     = MeanName;
% EEGout.nbchan      = size(EEGout.data,1);
% EEGout.trials      = size(EEGout.data,3);
% EEGout.pnts        = size(EEGout.data,2);
% EEGout.srate       = 1;
% EEGout.xmin        = 1;
% EEGout.times       = 1:EEGout.pnts;
% EEGout.xmax        = EEGout.times(end);
% 
% [ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEGout, CURRENTSET, 'gui', 'off');
% eeglab redraw