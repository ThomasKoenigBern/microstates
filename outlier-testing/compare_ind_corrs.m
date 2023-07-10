setIdx1 = 1:34;
setIdx2 = 83:116;

nClasses = 6;

mapCorrs = zeros(numel(setIdx1), nClasses);
for i=1:numel(setIdx1)
    maps1 = ALLEEG(setIdx1(i)).msinfo.MSMaps(nClasses).Maps;
    maps2 = ALLEEG(setIdx2(i)).msinfo.MSMaps(nClasses).Maps;
    [~,~,spCorr] = ArrangeMapsBasedOnMean(maps1, maps2, 0);
    mapCorrs(i,:) = abs(spCorr);
end

diffSets = find(arrayfun(@(x) any(mapCorrs(x,:) <= .9), 1:34));
% Reorder maps
for i=diffSets
    maps1 = ALLEEG(setIdx1(i)).msinfo.MSMaps(nClasses).Maps;
    maps2 = ALLEEG(setIdx2(i)).msinfo.MSMaps(nClasses).Maps;
    [~,sortOrder] = ArrangeMapsBasedOnMean(maps2, maps1, 0);
    ALLEEG(setIdx2(i)).msinfo.MSMaps(nClasses).Maps = maps2(sortOrder,:);
end
diffSets = reshape([setIdx1(diffSets); setIdx2(diffSets)], 1, []);

% Plot differences
f = figure('Position', [10 90 500 680]);
tl = tiledlayout(f, numel(diffSets), nClasses, 'TileSpacing', 'tight', 'Padding', 'tight');
for y=1:numel(diffSets)
    setIdx = diffSets(y);
    X = cell2mat({ALLEEG(setIdx).chanlocs.X});
    Y = cell2mat({ALLEEG(setIdx).chanlocs.Y});
    Z = cell2mat({ALLEEG(setIdx).chanlocs.Z});
    for x=1:nClasses
        ax = axes('Parent', tl);
        ax.Layout.Tile = y*nClasses - nClasses + x;
        Background = ALLEEG(setIdx).msinfo.MSMaps(nClasses).ColorMap(x,:);
        dspCMap3(ax, double(ALLEEG(setIdx).msinfo.MSMaps(nClasses).Maps(x,:)),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);        
        if x==1
            ylabel(ax, ALLEEG(setIdx).setname, 'Rotation', 0, 'HorizontalAlignment', 'right', 'Interpreter', 'none', 'FontSize', 14);
        end
    end
    drawnow limitrate
end