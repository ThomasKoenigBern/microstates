setIdx = 1:33;
MinClasses = 4;
MaxClasses = 12;
MeanName = 'Mean_EC_2nd_clustering';
nbchan = ALLEEG(setIdx(1)).nbchan;

for c=MinClasses:MaxClasses
    allMaps = zeros(c*numel(setIdx), nbchan);
    for i=setIdx
        allMaps((i*c)-c+1:i*c, :) = ALLEEG(i).msinfo.MSMaps(c).Maps;
    end
    [b_model, ~, ~, exp_var] = eeg_kMeans(allMaps, c, 20, [], 'n');
    msinfo.MSMaps(c).Maps = double(b_model);
    msinfo.MSMaps(c).ExpVar = double(exp_var);
    msinfo.MSMaps(c).ColorMap = repmat([.75 .75 .75], c, 1);
    for j = 1:c
        msinfo.MSMaps(c).Labels{j} = sprintf('MS_%i.%i',c,j);
    end
    msinfo.MSMaps(c).SortMode = 'none';
    msinfo.MSMaps(c).SortedBy = '';
    msinfo.MSMaps(c).SpatialCorrelation= [];
end

EEGout = eeg_emptyset();
EEGout.chanlocs = ALLEEG(setIdx(1)).chanlocs;
EEGout.data = zeros(nbchan,MaxClasses,MaxClasses);
EEGout.msinfo = msinfo;

for n = MinClasses:MaxClasses
    EEGout.data(:,1:n,n) = msinfo.MSMaps(n).Maps';
end

EEGout.setname     = MeanName;
EEGout.nbchan      = size(EEGout.data,1);
EEGout.trials      = size(EEGout.data,3);
EEGout.pnts        = size(EEGout.data,2);
EEGout.srate       = 1;
EEGout.xmin        = 1;
EEGout.times       = 1:EEGout.pnts;
EEGout.xmax        = EEGout.times(end);

[ALLEEG EEG CURRENTSET] = pop_newset(ALLEEG, EEGout, CURRENTSET, 'gui', 'off');
eeglab redraw