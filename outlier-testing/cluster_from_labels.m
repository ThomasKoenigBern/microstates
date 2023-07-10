setIdx = 1:34;
nClasses = 7;
% CURRENTSET = 22;

FitPar.Classes = nClasses;
tmpEEG = pop_FitMSMaps(ALLEEG, setIdx, 'TemplateSet', 'Custo2017', 'FitPar', FitPar);

fittedMaps = zeros(numel(setIdx), nClasses, tmpEEG(1).nbchan);
for i=1:numel(setIdx)
    AllLabels = tmpEEG(i).msinfo.MSStats(nClasses).MSClass;
    AllLabels = reshape(AllLabels, 1, []);
    
    newRef = eye(tmpEEG(i).nbchan);
    newRef = newRef-1/tmpEEG(i).nbchan;
    data = newRef*reshape(tmpEEG(i).data, tmpEEG(i).nbchan, []);
    data = L2NormDim(data, 1);
        
    for c=1:nClasses
        idx = AllLabels == c;
        clustMembers = data(:, idx);
        cvm = clustMembers*clustMembers';
        [v,~] = eigs(double(cvm), 1);
        fittedMaps(i, c,:) = v';
    end
end

f = uifigure('Position', [10 100 800 700], 'Scrollable', 'on');
pause(2);
plotSize = 80;
nClasses = 7;
p = uipanel(f, 'Position', [0 0 f.Position(3) plotSize*numel(setIdx)]);
tl = tiledlayout(p, numel(setIdx), nClasses, 'TileSpacing', 'tight', 'Padding', 'tight');

colors = getColors(7);
for y=1:numel(setIdx)
    X = cell2mat({ALLEEG(setIdx(y)).chanlocs.X});
    Y = cell2mat({ALLEEG(setIdx(y)).chanlocs.Y});
    Z = cell2mat({ALLEEG(setIdx(y)).chanlocs.Z});    
    for x=1:nClasses
        ax = axes('Parent', tl);
        ax.Layout.Tile = y*nClasses - nClasses + x;
        Background = colors(x,:);
        dspCMap3(ax, double(squeeze(fittedMaps(y,x,:))),[X;Y;Z],'NoScale','Resolution',2,'Background',Background,'ShowNose',15);        
        if x==1
            ylabel(ax, ALLEEG(setIdx(y)).setname, 'Rotation', 0, 'HorizontalAlignment', 'right', 'Interpreter', 'none', 'FontSize', 14);
        end
    end
    drawnow limitrate
end

% MSMaps.Maps = fittedMaps;
% MSMaps.Labels = tmpEEG.msinfo.MSMaps(nClasses).Labels;
% MSMaps.ColorMap = tmpEEG.msinfo.MSMaps(nClasses).ColorMap;
% f = figure;
% p = uipanel(f);
% PlotMSMaps2(f, p, MSMaps, tmpEEG.chanlocs);