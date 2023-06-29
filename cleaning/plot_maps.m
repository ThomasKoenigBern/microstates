f = uifigure('Position', [10 100 800 700], 'Scrollable', 'on');
pause(2);
% f = figure('Position', [10 100 800 700]);
plotSize = 80;
% sets = [1 2 3 8 9 13 14 16 17 19 21 26 27 28 29 33];
sets = 1:34;
nClasses = 7;
p = uipanel(f, 'Position', [0 0 f.Position(3) plotSize*numel(sets)]);
tl = tiledlayout(p, numel(sets), nClasses, 'TileSpacing', 'tight', 'Padding', 'tight');

for y=1:numel(sets)
    setIdx = sets(y);
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