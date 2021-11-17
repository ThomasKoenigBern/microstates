function [LocalToGlobal,GlobalToLocal] = MakeResampleMatrices(chanlocs_local,chanlocs_global)

    [xyz_local ,nelec_local]  = ChanPos2XYZ(chanlocs_local);
    [xyz_global,nelec_global] = ChanPos2XYZ(chanlocs_global);
    warning('off','all');
    LocalToGlobal = splint(xyz_local ,eye(nelec_local) ,xyz_global);
    GlobalToLocal = splint(xyz_global,eye(nelec_global),xyz_local );
    warning('on','all');
end


function [xyz,nelec] = ChanPos2XYZ(chanlocs)

    nelec = numel(chanlocs);

    [x{1:nelec}] = deal(chanlocs.X);
    [y{1:nelec}] = deal(chanlocs.Y);
    [z{1:nelec}] = deal(chanlocs.Z);

    xyz = [cell2mat(x)' cell2mat(y)' cell2mat(z)'];
end