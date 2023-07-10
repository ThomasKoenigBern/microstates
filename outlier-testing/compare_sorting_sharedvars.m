nClasses = 4;
setIdx = 1:34;
meanIdx = 81;

labels = 'A':'Z';
labels = arrayfun(@(x) sprintf('%s',labels(x)), 1:nClasses, 'UniformOutput', false);

%% Mean maps
[~, meanSortedEEG] = pop_SortMSMaps(ALLEEG, setIdx, 'TemplateSet', meanIdx, 'IgnorePolarity', 1, 'Classes', 4, 'TemplateClasses', 4);

meanSortedIndMaps = zeros(numel(setIdx), nClasses, ALLEEG(setIdx(1)).nbchan);
for i=1:numel(setIdx)
    meanSortedIndMaps(i,:,:) = meanSortedEEG(i).msinfo.MSMaps(nClasses).Maps;
end

meanMaps(1,:,:) = ALLEEG(meanIdx).msinfo.MSMaps(nClasses).Maps;
meanVars = GetMapSeriesFit(meanSortedIndMaps, meanMaps, 0).^2;

%% Published template maps
TemplateName = 'Koenig2002';
[~, templateSortedEEG] = pop_SortMSMaps(ALLEEG, setIdx, 'TemplateSet', TemplateName, 'IgnorePolarity', 1, 'Classes', 4, 'TemplateClasses', 4);

templateSortedIndMaps = zeros(numel(setIdx), nClasses, ALLEEG(setIdx(1)).nbchan);
for i=1:numel(setIdx)
    templateSortedIndMaps(i,:,:) = templateSortedEEG(i).msinfo.MSMaps(nClasses).Maps;
end

templateMeanMaps = zeros(1,nClasses,ALLEEG(setIdx(1)).nbchan);
for c=1:nClasses
    data = squeeze(templateSortedIndMaps(:,c,:));
    [pc1,~] = eigs(data'*data,1);
    templateMeanMaps(1,c,:) = L2NormDim(pc1',2);
end
templateVars = GetMapSeriesFit(templateSortedIndMaps, templateMeanMaps, 0).^2;

%% Manually sorted 
manualSortedIndMaps = zeros(numel(setIdx), nClasses, ALLEEG(setIdx(1)).nbchan);
for i=1:numel(setIdx)
    manualSortedIndMaps(i,:,:) = manualEEG(i).msinfo.MSMaps(nClasses).Maps;
end

manualMeanMaps = zeros(1,nClasses,ALLEEG(setIdx(1)).nbchan);
for c=1:nClasses
    data = squeeze(manualSortedIndMaps(:,c,:));
    [pc1,~] = eigs(data'*data,1);
    manualMeanMaps(1,c,:) = L2NormDim(pc1',2);
end
manualVars = GetMapSeriesFit(manualSortedIndMaps, manualMeanMaps, 0).^2;

f = figure('Units', 'normalized', 'Position', [.1 .1 .8 .8]);
tl = tiledlayout(f, 3, 4, 'Padding', 'compact', 'TileSpacing', 'compact');

%% Plot histograms
for i=1:4
    nexttile(tl);
    histogram(meanVars(:,i), .1:.1:1);
    title(sprintf('Map %s Shared Vars (Mean)', labels{i}));
end

for i=1:4
    nexttile(tl);
    histogram(templateVars(:,i), .1:.1:1);
    title(sprintf('Map %s Shared Vars (Koenig)', labels{i}));
end

for i=1:4
    nexttile(tl);
    histogram(manualVars(:,i), .1:.1:1);
    title(sprintf('Map %s Shared Vars (Manual)', labels{i}));
end

