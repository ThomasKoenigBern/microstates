setIdx=1;
ResidualEstimator = VA_MakeSplineResidualMatrix(ALLEEG(1).chanlocs);

residuals = zeros(size(ALLEEG(setIdx).data));
for e=1:ALLEEG(setIdx).trials
    residuals(:,:,e) = ResidualEstimator*ALLEEG(setIdx).data(:,:,e);
end

chanResiduals = reshape(residuals, ALLEEG(setIdx).nbchan, []);
chanRMSE = squeeze(sqrt(mean(chanResiduals.^2, 2)));

f = figure;
ax = axes(f);
line = plot(ax, chanRMSE);
line.DataTipTemplate.DataTipRows = dataTipTextRow('Chan:', {ALLEEG(setIdx).chanlocs.labels});