function test_map()
% Run from the project folder: addpath('tests'); test_map
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root);
[names, codes] = usaStates();
assert(numel(names) == 50 && numel(codes) == 50);

% Boundaries and triangulation.
states = loadStateBoundaries();
assert(numel(states) == 50 && numel(unique({states.Name})) == 50);
assert(norm(lambertUSA(-96, 39)) < 1e-12);
parts = 0;
for i = 1:numel(states)
    for part = states(i).Parts(:)'
        [p, f] = triangulateRing(lambertUSA(part.Lon, part.Lat, -154, 63));
        if ~isempty(f), assert(abs(meshArea(p, f) - polyarea(p(:,1), p(:,2))) < 1e-10); end
        parts = parts + 1;
    end
end
assert(parts == 143);
[p, f] = triangulateRing([0 0; 3 0; 3 1; 1 1; 1 3; 0 3; 0 0]);
assert(size(f, 1) == 4 && meshArea(p, f) == 5);
geo = usaGeometry();
assert(isequal(unique(geo.FaceState)', 1:50) && max(geo.Faces(:)) <= size(geo.Points, 1));
assert(numel(geo.RingStart) == 143);

% Data adapters all land on the same 50-vector.
warnState = warning('off', 'usaData:UnknownKeys');
restore = onCleanup(@() warning(warnState));
bank = usaData(fullfile(root, 'banklist.csv'));
assert(sum(bank) == 563 && bank(10) == 93 && bank(9) == 76 && bank(11) == 1);
expected = zeros(50, 1); expected([5 32 43]) = [3 7 2];
inputs = {containers.Map({'CA', 'New York', 'tx'}, {3, 7, 2}), ...
    struct('CA', 3, 'New_York', 7, 'TX', 2), ...
    {{'CA', 'NY', 'TX'}, [3 7 2]}, ...
    {'California', 3; 'NY', 7; 'Texas', 2}, ...
    struct('State', {'CA', 'NY', 'TX', 'PR'}, 'Value', {3, 7, 2, 9})};
for k = 1:numel(inputs)
    v = usaData(inputs{k});
    v(isnan(v)) = 0;
    assert(isequal(v, expected), sprintf('input %d', k));
end
assert(isequal(usaData({'CA', 'CA', 'NY', 'PR'})([5 32]), [2; 1]));
assert(isequal(usaData(1:50), (1:50)'));
csv = [tempname() '.csv'];
fid = fopen(csv, 'w'); fprintf(fid, 'state,"Revenue ($)"\nCA,"1,000"\nca,500\nNV,2\n'); fclose(fid);
v = usaData(csv, 'ValueColumn', 'Revenue ($)');
delete(csv);
assert(v(5) == 1500 && v(28) == 2 && isnan(v(1)));

% Depth buffering is independent of triangle order.
quad = [0 0; 1 0; 1 1; 0 1];
scene.Vertices = [quad, zeros(4, 1); quad, .2 * ones(4, 1)];
scene.Faces = [1 2 3; 1 3 4; 5 6 7; 5 7 8];
scene.FaceColors = [1 0 0; 1 0 0; 0 1 0; 0 1 0];
scene.Lines = struct('XYZ', {}, 'Color', {});
a = rasterizeMap(scene, [0 0 0], [0 90], [100 100]);
scene.Faces = scene.Faces([3 4 1 2], :); scene.FaceColors = scene.FaceColors([3 4 1 2], :);
b = rasterizeMap(scene, [0 0 0], [0 90], [100 100]);
assert(isequal(a, b) && any(any(a(:,:,2) == 255)) && ~any(any(a(:,:,1) == 255)));
fprintf('PASS: 50 states, 143 parts, areas, data adapters, depth ordering.\n');
end

function a = meshArea(p, f)
u = p(f(:,2), :) - p(f(:,1), :);
v = p(f(:,3), :) - p(f(:,1), :);
a = sum(abs(u(:,1).*v(:,2) - u(:,2).*v(:,1))) / 2;
end
